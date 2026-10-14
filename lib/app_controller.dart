import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'core/clock_time.dart';
import 'core/date_utils.dart';
import 'core/scheduler/bell_log.dart';
import 'core/scheduler/bell_scheduler.dart';
import 'core/scheduler/day_schedule.dart';
import 'data/config_repository.dart';
import 'data/models/app_config.dart';
import 'data/models/bell_event.dart';
import 'data/models/calendar.dart';
import 'data/schedule_draft.dart';
import 'platform/audio_file_picker.dart';
import 'platform/bell_player.dart';
import 'platform/config_file_picker.dart';
import 'platform/error_log.dart';
import 'platform/system_services.dart';

/// Ayarları, zamanlayıcıyı, ses çaları ve işletim sistemi servislerini bir
/// araya getirir; arayüz bunu dinler.
class AppController extends ChangeNotifier {
  AppController({
    required AppConfig config,
    required this.repository,
    required this.player,
    SystemServices? system,
    DateTime Function()? now,
    AudioFilePicker? pickAudioFile,
    ConfigFilePicker? pickConfigFile,
    ExportPathPicker? pickExportPath,
  })  : _config = config,
        pickAudioFile = pickAudioFile ?? pickAudioFileWithDialog,
        pickConfigFile = pickConfigFile ?? pickConfigFileWithDialog,
        pickExportPath = pickExportPath ?? pickExportPathWithDialog,
        system = system ?? const NoopSystemServices(),
        _now = now ?? DateTime.now {
    _scheduler = BellScheduler(
      resolveDay: (date) => resolver.resolve(date),
      ring: _ring,
      onLog: _onLog,
      holdReason: () => _emergencyActive ? 'Acil durum alarmı sürüyor' : null,
      tolerance: Duration(seconds: config.lateToleranceSeconds),
      now: _now,
    );
  }

  static const _fallbackAlarm =
      BellSound(id: 'alarm', name: 'Siren', path: 'sounds/alarm.wav', isAsset: true);

  /// Yüklenen ses çalınamazsa yerine çalan yerleşik zil.
  static const fallbackBell =
      BellSound(id: 'zil', name: 'Klasik zil', path: 'sounds/zil.wav', isAsset: true);

  /// Ses dosyası seçme penceresi (testlerde sahtesiyle değiştirilir).
  final AudioFilePicker pickAudioFile;

  /// Açılacak ayar dosyasını seçtirir (vazgeçilirse null).
  final ConfigFilePicker pickConfigFile;

  /// Ayarların yazılacağı yolu seçtirir (vazgeçilirse null).
  final ExportPathPicker pickExportPath;

  final ConfigRepository repository;
  final BellPlayer player;
  final SystemServices system;
  final DateTime Function() _now;
  late final BellScheduler _scheduler;
  Timer? _volumeTimer;

  AppConfig _config;
  AppConfig get config => _config;
  ScheduleResolver get resolver => ScheduleResolver(_config);

  DateTime now() => _now();

  // ---- Kayıtlar -----------------------------------------------------------

  static const _maxLogEntries = 300;
  final List<BellLogEntry> _logs = [];

  /// En yeni kayıt başta olacak şekilde.
  List<BellLogEntry> get logs => List.unmodifiable(_logs.reversed);

  /// "gün|zil kimliği" → sonuç; bugünkü listede durum göstermek için.
  final Map<String, BellOutcome> _outcomes = {};

  BellOutcome? outcomeOf(DaySchedule day, BellEvent bell) => _outcomes[BellScheduler.keyFor(day.date, bell)];

  // ---- Durum --------------------------------------------------------------

  bool get isMuted => _scheduler.isMuted();
  DateTime? get mutedUntil => _scheduler.mutedUntil;

  bool _emergencyActive = false;
  bool get emergencyActive => _emergencyActive;

  VolumeStatus _volume = const VolumeStatus();
  VolumeStatus get volume => _volume;

  bool? _autostartEnabled;
  bool? get autostartEnabled => _autostartEnabled;

  String? _lastError;

  /// Arayüzde gösterilecek son ciddi hata (ör. ayar kaydedilemedi).
  String? get lastError => _lastError;

  void start() {
    system.preventSleep();
    restoreTodayFromLog();
    _scheduler.start();
    _refreshVolume();
    _volumeTimer = Timer.periodic(const Duration(seconds: 5), (_) => _refreshVolume());
    refreshAutostart();
  }

  // ---- Eylemler -----------------------------------------------------------

  /// Acil durum alarmı çalarken zil çalınmaz; alarmı kesmesin.
  Future<void> ringNow() async {
    if (_emergencyActive) return;
    await _scheduler.ringNow();
  }

  Future<void> stopSound() async {
    await player.stop();
    if (_emergencyActive) {
      _emergencyActive = false;
      notifyListeners();
    }
  }

  /// Zilleri [until] anına kadar susturur.
  void muteUntil(DateTime until) {
    _scheduler.muteUntil(until);
    notifyListeners();
  }

  void muteForToday() {
    final n = _now();
    muteUntil(DateTime(n.year, n.month, n.day + 1));
  }

  /// Şu anki ders ya da teneffüs bitene kadar; o an bir dönem yoksa 1 saat.
  /// Dönemin sonundaki zil de susar.
  void muteUntilPeriodEnd() {
    final n = _now();
    final end = resolver.resolve(n).statusAt(n).endsAt;
    muteUntil((end ?? n.add(const Duration(hours: 1))).add(const Duration(seconds: 30)));
  }

  void unmute() {
    _scheduler.muteUntil(null);
    notifyListeners();
  }

  Future<void> startEmergency() async {
    _emergencyActive = true;
    notifyListeners();
    final bell = BellEvent(
      id: 'emergency-${_now().millisecondsSinceEpoch}',
      time: ClockTime(_now().hour, _now().minute),
      type: BellType.emergency,
      label: 'Acil durum alarmı',
    );
    try {
      _ensureAudible(100);
      // Eski ayar dosyalarında acil durum türüne ses atanmamış olabilir;
      // o zaman ilk ses (klasik zil) değil siren çalsın.
      final sound = (_config.soundForType.containsKey(BellType.emergency) ? _config.soundFor(bell) : null) ??
          _config.soundById('alarm') ??
          _fallbackAlarm;
      final note = await _playWithFallback(sound, loop: true);
      _onLog(BellLogEntry(at: _now(), bell: bell, outcome: BellOutcome.played, detail: note));
    } catch (e) {
      // Siren çalınamadıysa acil durum kipi açık kalmasın; yoksa günün tüm
      // zilleri "susturuldu" olurdu.
      _emergencyActive = false;
      _onLog(BellLogEntry(at: _now(), bell: bell, outcome: BellOutcome.failed, detail: '$e'));
    }
  }

  /// Ayarı hemen geçerli kılar ve diske kaydeder; kaydedilemezse false
  /// döner ve uyarı bandında gösterilir (ayar bellekte geçerli kalır).
  Future<bool> updateConfig(AppConfig config) async {
    _config = config;
    _scheduler
      ..tolerance = Duration(seconds: config.lateToleranceSeconds)
      ..scheduleChanged();
    notifyListeners();
    var saved = true;
    try {
      await repository.save(config);
      _lastError = null;
    } catch (e, st) {
      saved = false;
      _lastError = 'Ayarlar kaydedilemedi; uygulama yeniden açılınca son değişiklikler kaybolabilir. ($e)';
      ErrorLog.write('ayar kaydı', e, st);
    }
    notifyListeners();
    return saved;
  }

  Future<void> refreshAutostart() async {
    if (!system.supportsAutostart) return;
    try {
      _autostartEnabled = await system.isAutostartEnabled();
    } catch (_) {
      _autostartEnabled = null;
    }
    notifyListeners();
  }

  Future<void> setAutostart(bool enabled) async {
    try {
      await system.setAutostart(enabled);
      _lastError = null;
    } catch (e) {
      _lastError = 'Otomatik başlatma ayarlanamadı: $e';
    }
    await refreshAutostart();
  }

  // ---- Ders programı taslağı ----------------------------------------------

  ScheduleDraft? _scheduleDraft;

  /// Kaydedilmemiş program değişiklikleri; sayfalar arası geçişte korunur.
  ScheduleDraft? get scheduleDraft => _scheduleDraft;

  /// Düzenlenecek taslak. Değişiklik yapılmamışsa her seferinde güncel
  /// ayarlardan yeniden kurulur (seçili şablon korunur).
  ScheduleDraft editSchedule() {
    final current = _scheduleDraft;
    if (current != null && current.dirty) return current;
    final fresh = ScheduleDraft.fromConfig(_config);
    if (current != null && fresh.byId(current.selectedId) != null) fresh.selectedId = current.selectedId;
    return _scheduleDraft = fresh;
  }

  /// Taslak değişince arayüzün (ve menüdeki işaretin) yenilenmesi için.
  void scheduleDraftChanged() => notifyListeners();

  void discardScheduleDraft() {
    _scheduleDraft = null;
    notifyListeners();
  }

  /// Taslağı kaydeder; sorun varsa kaydetmeden sorunları döndürür.
  Future<List<String>> saveScheduleDraft() async {
    final draft = _scheduleDraft;
    if (draft == null) return const [];
    final errors = draft.validate(_config.overrides);
    if (errors.isNotEmpty) return errors;
    _scheduleDraft = null;
    final saved = await updateConfig(_config.copyWith(templates: draft.templates, weekPlan: {...draft.weekPlan}));
    if (!saved) {
      // Taslak kaybolmasın; kişi Kaydet'e tekrar basabilsin.
      _scheduleDraft = draft..dirty = true;
      notifyListeners();
      return const ['Program diske kaydedilemedi. Ziller yeni programla çalıyor ama uygulama yeniden açılınca '
          'eski programa dönebilir. Kaydet\'e tekrar basın.'];
    }
    return const [];
  }

  /// Tatili ekler; [replacing] verilirse onun yerine koyar (düzenleme).
  Future<void> saveHoliday(Holiday holiday, {Holiday? replacing}) {
    final list = [..._config.holidays.where((h) => !identical(h, replacing)), holiday]
      ..sort((a, b) => a.start.compareTo(b.start));
    return updateConfig(_config.copyWith(holidays: list));
  }

  Future<void> deleteHoliday(Holiday holiday) => updateConfig(
      _config.copyWith(holidays: _config.holidays.where((h) => !identical(h, holiday)).toList()));

  // ---- Yedekten geri yükleme / ayar dosyası alma-verme ---------------------

  AppConfig? _configBeforeReplace;

  /// Son geri yükleme/içe aktarmadan önceki ayar var mı ([undoReplace] için).
  bool get canUndoReplace => _configBeforeReplace != null;

  Future<ReplaceResult> restoreBackup(BackupInfo backup) => _replaceFrom(backup.file);

  Future<ReplaceResult> importConfigFile(String path) => _replaceFrom(File(path));

  /// Dosya okunamazsa hiçbir şey değişmez. Okunursa önce mevcut ayar yedeklenir,
  /// kaydedilmemiş program taslağı atılır, sonra yeni ayar uygulanır.
  Future<ReplaceResult> _replaceFrom(File source) async {
    final AppConfig loaded;
    final List<String> warnings;
    try {
      final read = repository.readConfigFile(source);
      loaded = read.$1;
      warnings = [...read.$2];
    } catch (e) {
      return ReplaceResult(ok: false, error: 'Dosya okunamadı; ayarlar değişmedi. Bozuk ya da bu uygulamanın ayar dosyası değil. ($e)');
    }
    repository.snapshot();
    _scheduleDraft = null;
    final before = _config;

    final sep = Platform.pathSeparator;
    final soundsDir = '${repository.file.parent.path}${sep}sesler';
    final missing = <String>[];
    final sounds = <BellSound>[];
    for (final s in loaded.sounds) {
      if (s.isAsset || File(s.path).existsSync()) {
        sounds.add(s);
        continue;
      }
      final fileName = s.path.split(RegExp(r'[/\\]')).last;
      final alt = '$soundsDir$sep$fileName';
      if (fileName.isNotEmpty && File(alt).existsSync()) {
        sounds.add(BellSound(id: s.id, name: s.name, path: alt));
      } else {
        missing.add(s.name);
        sounds.add(s);
      }
    }

    _configBeforeReplace = before;
    final saved = await updateConfig(loaded.copyWith(sounds: sounds));
    if (!saved) {
      warnings.add('Yeni ayar diske kaydedilemedi; uygulama yeniden açılınca eski ayara dönebilir.');
    }
    return ReplaceResult(ok: true, missingSounds: missing, warnings: warnings);
  }

  /// Son geri yükleme/içe aktarma öncesi ayarı geri getirir (bir kez).
  Future<bool> undoReplace() async {
    final previous = _configBeforeReplace;
    if (previous == null) return false;
    _configBeforeReplace = null;
    _scheduleDraft = null;
    await updateConfig(previous);
    return true;
  }

  /// Ayarları [path] dosyasına yazar; hata varsa metni, başarıda null döner.
  Future<String?> exportConfig(String path) async {
    try {
      await File(path).writeAsString(repository.exportJson(_config), flush: true);
      return null;
    } catch (e) {
      return 'Ayarlar dosyaya yazılamadı: $e';
    }
  }

  // ---- Zil sesleri ---------------------------------------------------------

  /// Sesi dinletir (zil çalarkenki seviyede). Yedek ses çalındıysa nedenini
  /// döndürür.
  Future<String?> previewSound(BellSound sound, {int? stopAfter}) async {
    if (_emergencyActive) return 'Acil durum alarmı çalarken ses dinletilemez';
    _ensureAudible(_config.volumePercent);
    return _playWithFallback(sound, loop: stopAfter != null, stopAfter: stopAfter);
  }

  /// Ses dosyasını uygulamanın klasörüne kopyalayıp listeye ekler; böylece
  /// USB bellek çıkarılsa ya da asıl dosya silinse de zil çalar.
  Future<BellSound> importSound(String sourcePath) async {
    final sep = Platform.pathSeparator;
    final dir = Directory('${repository.file.parent.path}${sep}sesler')..createSync(recursive: true);
    final fileName = sourcePath.split(RegExp(r'[/\\]')).last;
    final dot = fileName.lastIndexOf('.');
    final ext = dot > 0 ? fileName.substring(dot).toLowerCase() : '';
    final id = 's${DateTime.now().microsecondsSinceEpoch}';
    final dest = '${dir.path}$sep$id$ext';
    File(sourcePath).copySync(dest);
    final sound = BellSound(id: id, name: dot > 0 ? fileName.substring(0, dot) : fileName, path: dest);
    await updateConfig(_config.copyWith(sounds: [..._config.sounds, sound]));
    return sound;
  }

  /// Sesin kullanıldığı yerler (zil türleri ve etkinlikler).
  List<String> soundUsages(String soundId) => [
        for (final e in _config.soundForType.entries)
          if (e.value == soundId) e.key.label,
        for (final ev in _config.specialEvents)
          if (ev.soundId == soundId) ev.name,
      ];

  Future<void> renameSound(BellSound sound, String name) => updateConfig(_config.copyWith(sounds: [
        for (final s in _config.sounds)
          s.id == sound.id ? BellSound(id: s.id, name: name, path: s.path, isAsset: s.isAsset) : s,
      ]));

  /// Yüklenen sesi siler; kullanıldığı zil türleri klasik zile, etkinlikler
  /// varsayılan etkinlik sesine döner. Yerleşik sesler silinmez.
  Future<void> deleteSound(BellSound sound) async {
    if (sound.isAsset) return;
    await updateConfig(_config.copyWith(
      sounds: _config.sounds.where((s) => s.id != sound.id).toList(),
      soundForType: {
        for (final e in _config.soundForType.entries)
          e.key: e.value != sound.id
              ? e.value
              : e.key == BellType.emergency
                  ? _fallbackAlarm.id
                  : fallbackBell.id,
      },
      specialEvents: [
        for (final ev in _config.specialEvents) ev.soundId == sound.id ? ev.copyWith(soundId: () => null) : ev,
      ],
    ));
    try {
      File(sound.path).deleteSync();
    } catch (_) {}
  }

  Future<void> setSoundForType(BellType type, String soundId) =>
      updateConfig(_config.copyWith(soundForType: {..._config.soundForType, type: soundId}));

  // ---- Özel etkinlikler ----------------------------------------------------

  /// Etkinliği ekler ya da aynı kimlikliyi günceller.
  Future<void> saveEvent(SpecialEvent event) {
    final exists = _config.specialEvents.any((e) => e.id == event.id);
    return updateConfig(_config.copyWith(specialEvents: [
      if (exists)
        for (final e in _config.specialEvents) e.id == event.id ? event : e
      else ...[..._config.specialEvents, event],
    ]));
  }

  Future<void> deleteEvent(String id) =>
      updateConfig(_config.copyWith(specialEvents: _config.specialEvents.where((e) => e.id != id).toList()));

  Future<void> setEventEnabled(String id, bool enabled) => updateConfig(_config.copyWith(specialEvents: [
        for (final e in _config.specialEvents) e.id == id ? e.copyWith(enabled: enabled) : e,
      ]));

  /// Etkinliğin sesini şimdi çalar (deneme).
  Future<String?> testEvent(SpecialEvent event) {
    final bell = event.toBellEvent();
    return previewSound(_config.soundFor(bell) ?? fallbackBell, stopAfter: event.loopSeconds);
  }

  /// [date] gününün özel programını ayarlar; [override] null ise kaldırır ve
  /// gün haftalık plana (ya da tatile) göre işler.
  Future<void> setDayOverride(DateTime date, DateOverride? override) {
    final list = [
      ..._config.overrides.where((o) => !isSameDay(o.date, date)),
      ?override,
    ]..sort((a, b) => a.date.compareTo(b.date));
    return updateConfig(_config.copyWith(overrides: list));
  }

  DateOverride? overrideOn(DateTime date) =>
      _config.overrides.where((o) => isSameDay(o.date, date)).firstOrNull;

  Holiday? holidayOn(DateTime date) => _config.holidays.where((h) => h.contains(date)).firstOrNull;

  /// Sonraki (bugün dahil) tatil.
  Holiday? nextHoliday() {
    final today = dateOnly(_now());
    final upcoming = _config.holidays.where((h) => !h.end.isBefore(today)).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    return upcoming.firstOrNull;
  }

  // ---- İç işleyiş ---------------------------------------------------------

  Future<String?> _ring(BellEvent bell) async {
    _ensureAudible(_config.volumePercent);
    return _playWithFallback(
      _config.soundFor(bell) ?? fallbackBell,
      loop: bell.loopSeconds != null,
      stopAfter: bell.loopSeconds,
    );
  }

  /// Her çalmada artar; süreli tekrarın durdurucusu yalnızca kendi çalmasını
  /// durdursun, arada başlayan başka bir zili kesmesin.
  int _playId = 0;

  /// Sesi çalar. Yüklenen dosya yoksa ya da çalınamazsa zil sessiz kalmasın
  /// diye yerleşik zil çalınır; bu durumda açıklama döner.
  Future<String?> _playWithFallback(BellSound sound, {bool loop = false, int? stopAfter}) async {
    final id = ++_playId;
    // Sistem sesi denetlenebiliyorsa seviye oradan ayarlanır; çalar tam
    // seviyede çalar. Denetlenemiyorsa seviye çalarda uygulanır.
    final volume = system.controlsVolume ? 100 : _config.volumePercent;
    String? note;
    var toPlay = sound;
    if (!sound.isAsset && !File(sound.path).existsSync()) {
      note = '"${sound.name}" dosyası bulunamadı, klasik zil çalındı';
      toPlay = fallbackBell;
    }
    try {
      await player.play(toPlay, volumePercent: volume, loop: loop);
    } catch (e) {
      if (toPlay.isAsset) rethrow;
      note = '"${sound.name}" çalınamadı, klasik zil çalındı';
      await player.play(fallbackBell, volumePercent: volume, loop: loop);
    }
    if (stopAfter != null) {
      Timer(Duration(seconds: stopAfter), () {
        if (_playId == id) player.stop();
      });
    }
    return note;
  }

  /// Zil çalmadan önce sistem sesini açar. Başarısız olursa zil yine çalınır;
  /// yalnızca kayda not düşülür.
  void _ensureAudible(int percent) {
    if (!system.controlsVolume) return;
    try {
      system.ensureAudible(percent);
    } catch (e) {
      debugPrint('[Zil] Sistem sesi ayarlanamadı: $e');
    }
    _refreshVolume();
  }

  void _refreshVolume() {
    if (!system.controlsVolume) return;
    final v = system.readVolume();
    if (v.level != _volume.level || v.muted != _volume.muted || v.error != _volume.error) {
      _volume = v;
      notifyListeners();
    }
  }

  void _onLog(BellLogEntry entry) {
    _logs.add(entry);
    if (_logs.length > _maxLogEntries) _logs.removeAt(0);
    final key = entry.key;
    if (key != null) {
      final dayPrefix = '${key.split('|').first}|';
      _outcomes.removeWhere((k, _) => !k.startsWith(dayPrefix));
      _outcomes[key] = entry.outcome;
    }
    debugPrint('[Zil] $entry');
    _appendLogFile(entry);
    notifyListeners();
  }

  /// Kayıtları ayar dosyasının yanındaki metin dosyasına da yazar; okul
  /// bilgisayarında geçmişe dönük sorun incelemek için.
  String get logFilePath =>
      '${repository.file.parent.path}${Platform.pathSeparator}zil_kayitlari.log';

  /// Yazmalar sıraya konur: Windows aynı dosyanın aynı anda iki kez
  /// açılmasına izin vermeyebilir ve satır kaybolur.
  Future<void> _logWrite = Future.value();

  /// Kayıt dosyası bu boyutu aşınca eskisi "zil_kayitlari.eski.log" olur.
  static const _maxLogBytes = 2 * 1024 * 1024;

  /// Satır biçimi: zaman, anahtar ("gün|kimlik@saat" ya da "-"), saat, ad,
  /// sonuç[, açıklama] — sekmeyle ayrılmış.
  void _appendLogFile(BellLogEntry entry) {
    final file = File(logFilePath);
    final line = '${entry.at.toIso8601String()}\t${entry.key ?? '-'}\t${entry.bell.time}\t'
        '${entry.bell.label}\t${entry.outcome.label}'
        '${entry.detail == null ? '' : '\t${entry.detail}'}\n';
    _logWrite = _logWrite.then((_) async {
      try {
        await file.writeAsString(line, mode: FileMode.append, flush: true);
      } catch (e) {
        debugPrint('[Zil] Kayıt dosyasına yazılamadı: $e');
      }
    });
  }

  /// Açılışta bugünkü zil sonuçlarını kayıt dosyasından geri yükler; böylece
  /// yeniden başlatma sonrası sabah çalmış ziller "Uygulama kapalıydı"
  /// görünmez. Dosya çok büyümüşse eskisini kenara alır.
  @visibleForTesting
  void restoreTodayFromLog() {
    try {
      final file = File(logFilePath);
      if (!file.existsSync()) return;
      if (file.lengthSync() > _maxLogBytes) {
        file.renameSync(logFilePath.replaceFirst(RegExp(r'\.log$'), '.eski.log'));
        return;
      }
      final today = dateKey(_now());
      for (final line in file.readAsLinesSync()) {
        if (!line.startsWith(today)) continue;
        final f = line.split('\t');
        if (f.length < 5 || !f[1].contains('|')) continue; // eski biçim ya da elle çalınan zil
        final outcome = BellOutcome.values.where((o) => o.label == f[4]).firstOrNull;
        if (outcome != null) _outcomes[f[1]] = outcome;
      }
      _scheduler.markHandled(_outcomes.keys);
    } catch (e, st) {
      ErrorLog.write('kayıt dosyası okuma', e, st);
    }
  }

  @override
  void dispose() {
    _scheduler.stop();
    _volumeTimer?.cancel();
    super.dispose();
  }
}

/// Yedekten geri yükleme / ayar dosyası içe aktarma sonucu.
class ReplaceResult {
  const ReplaceResult({required this.ok, this.error, this.missingSounds = const [], this.warnings = const []});

  final bool ok;
  final String? error;

  /// Dosyası bulunamayan seslerin adları (çalarken klasik zil çalar).
  final List<String> missingSounds;
  final List<String> warnings;
}
