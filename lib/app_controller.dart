import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'core/clock_time.dart';
import 'core/date_utils.dart';
import 'core/password_hash.dart';
import 'core/scheduler/bell_log.dart';
import 'core/scheduler/bell_scheduler.dart';
import 'core/scheduler/day_schedule.dart';
import 'data/config_repository.dart';
import 'data/models/app_config.dart';
import 'data/models/bell_event.dart';
import 'data/models/calendar.dart';
import 'data/models/lock_settings.dart';
import 'data/models/notices.dart';
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
    SoundFolderPicker? pickSoundFolder,
    ConfigFilePicker? pickConfigFile,
    ExportPathPicker? pickExportPath,
    PasswordHasher? passwordHasher,
  })  : _config = config,
        pickAudioFile = pickAudioFile ?? pickAudioFileWithDialog,
        pickSoundFolder = pickSoundFolder ?? pickSoundFolderWithDialog,
        pickConfigFile = pickConfigFile ?? pickConfigFileWithDialog,
        pickExportPath = pickExportPath ?? pickExportPathWithDialog,
        system = system ?? const NoopSystemServices(),
        _hasher = passwordHasher ?? const IsolatePasswordHasher(),
        _now = now ?? DateTime.now {
    _scheduler = BellScheduler(
      resolveDay: (date) => resolver.resolve(date),
      ring: _ring,
      onLog: _onLog,
      holdReason: () => _emergencyActive ? 'Acil durum alarmı sürüyor' : null,
      deferWhile: () => _ceremony != null,
      tolerance: Duration(seconds: config.lateToleranceSeconds),
      now: _now,
    );
    _completedSub = player.completed.listen((_) => _endCeremony());
  }

  static const _fallbackAlarm =
      BellSound(id: 'alarm', name: 'Siren', path: 'sounds/alarm.wav', isAsset: true);

  /// Yüklenen ses çalınamazsa yerine çalan yerleşik zil.
  static const fallbackBell =
      BellSound(id: 'zil', name: 'Klasik zil', path: 'sounds/zil.wav', isAsset: true);

  /// Ses dosyası seçme penceresi (testlerde sahtesiyle değiştirilir).
  final AudioFilePicker pickAudioFile;

  /// Ses paketi klasörü seçme penceresi (testlerde sahtesiyle değiştirilir).
  final SoundFolderPicker pickSoundFolder;

  /// Açılacak ayar dosyasını seçtirir (vazgeçilirse null).
  final ConfigFilePicker pickConfigFile;

  /// Ayarların yazılacağı yolu seçtirir (vazgeçilirse null).
  final ExportPathPicker pickExportPath;

  final ConfigRepository repository;
  final BellPlayer player;
  final SystemServices system;
  final DateTime Function() _now;
  final PasswordHasher _hasher;
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

  /// Şu an çalan tören kaydı (İstiklal Marşı vb.); yoksa null.
  Ceremony? _ceremony;
  Ceremony? get ceremonyPlaying => _ceremony;
  Timer? _ceremonyGuard;
  StreamSubscription<void>? _completedSub;

  /// Kaydın bittiği bildirimi gelmezse (ses sistemi takılırsa) ziller en çok
  /// bu kadar bekletilir.
  static const maxCeremony = Duration(minutes: 5);

  VolumeStatus _volume = const VolumeStatus();
  VolumeStatus get volume => _volume;

  bool? _autostartEnabled;
  bool? get autostartEnabled => _autostartEnabled;

  String? _lastError;

  /// Arayüzde gösterilecek son ciddi hata (ör. ayar kaydedilemedi).
  String? get lastError => _lastError;

  /// Sorunlarda (zil çalınamadı, ses aygıtı, kayıt hatası...) tepsideki
  /// uygulamanın fark edilmesi için bildirim; masaüstü kabuğu atar.
  /// Atanmadan önce gelen bildirimler (ör. açılış uyarısı) kuyrukta bekler
  /// ve atanınca sırayla iletilir.
  void Function(String title, String body)? get onNotice => _onNotice;
  set onNotice(void Function(String title, String body)? value) {
    _onNotice = value;
    if (value == null || _pendingNotices.isEmpty) return;
    final pending = List.of(_pendingNotices);
    _pendingNotices.clear();
    for (final n in pending) {
      _notice(n.$1, n.$2);
    }
  }

  void Function(String title, String body)? _onNotice;
  final List<(String, String)> _pendingNotices = [];

  static const noticeRepeatWindow = Duration(minutes: 10);
  final Map<String, DateTime> _noticeSent = {};

  /// Aynı başlık+gövde [noticeRepeatWindow] içinde ikinci kez gönderilmez.
  /// Not: ses aygıtı hatası 10 dk içinde düzelip aynı metinle yeniden bozulursa
  /// bildirim bilerek bastırılır (tepsi ipucunu yeniden yanıp sönmekten korur).
  /// Süzgeç anahtarı yalnız bildirim gerçekten iletildiğinde işaretlenir.
  void _notice(String title, String body) {
    final handler = _onNotice;
    if (handler == null) {
      if (_pendingNotices.length < 20 && !_pendingNotices.contains((title, body))) {
        _pendingNotices.add((title, body));
      }
      return;
    }
    final key = '$title\n$body';
    final now = _now();
    final last = _noticeSent[key];
    if (last != null && now.difference(last) < noticeRepeatWindow) return;
    _noticeSent.removeWhere((_, t) => now.difference(t) >= noticeRepeatWindow);
    _noticeSent[key] = now;
    try {
      handler(title, body);
    } catch (e, st) {
      ErrorLog.write('bildirim', e, st);
    }
  }

  void start() {
    final warning = repository.lastLoadWarning;
    if (warning != null) {
      final title = warning.contains('tarihli yedek yüklendi')
          ? 'Ayarlar yedekten yüklendi'
          : warning.contains('varsayılan ayarlar')
              ? 'Ayarlar varsayılana döndü'
              : 'Ayar dosyası uyarısı';
      _notice(title, warning);
    }
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
    if (_emergencyActive || _ceremony != null) return;
    await _scheduler.ringNow();
  }

  Future<void> stopSound() async {
    await player.stop();
    _endCeremony();
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
    // Acil durum her şeyden önce gelir; çalan tören kaydı siren ile kesilir.
    _ceremonyGuard?.cancel();
    _ceremony = null;
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

  /// Ana ekrandaki Tören düğmesi: kayıt bir kez çalar. Çalarken programlı
  /// ziller marşı kesmez; bekletilir ve bitince tolerans içindeyse çalar.
  /// Kayıt yoksa ya da çalınamazsa yerine zil çalınmaz, açıklama döner.
  /// Susturma törene uygulanmaz (elle başlatılır).
  Future<String?> startCeremony(Ceremony kind) async {
    if (_emergencyActive) return 'Acil durum alarmı çalarken tören kaydı çalınamaz.';
    final sound = _config.ceremonySound(kind);
    if (sound == null) {
      return '"${kind.label}" kaydı yüklenmemiş. Zil sesleri sayfasında "Ses paketi yükle…" ile yükleyin.';
    }
    if (!sound.isAsset && !File(sound.path).existsSync()) {
      return '"${sound.name}" dosyası bulunamadı. Zil sesleri sayfasında ses paketini yeniden yükleyin.';
    }
    final at = _now();
    final bell = BellEvent(
      id: 'ceremony-${at.millisecondsSinceEpoch}',
      time: ClockTime(at.hour, at.minute),
      type: BellType.special,
      label: kind.label,
    );
    // Önceki bir zilin süreli durdurucusu marşı kesmesin.
    _playId++;
    _ceremony = kind;
    _ceremonyGuard?.cancel();
    _ceremonyGuard = Timer(maxCeremony, _endCeremony);
    notifyListeners();
    _ensureAudible(_config.volumePercent);
    try {
      await player.play(sound, volumePercent: system.controlsVolume ? 100 : _config.volumePercent);
      _onLog(BellLogEntry(at: _now(), bell: bell, outcome: BellOutcome.played));
      return null;
    } catch (e) {
      _endCeremony();
      _onLog(BellLogEntry(at: _now(), bell: bell, outcome: BellOutcome.failed, detail: '$e'));
      return '"${kind.label}" çalınamadı: $e';
    }
  }

  void _endCeremony() {
    if (_ceremony == null) return;
    _ceremonyGuard?.cancel();
    _ceremonyGuard = null;
    _ceremony = null;
    notifyListeners();
  }

  /// Ayarı hemen geçerli kılar ve diske kaydeder; kaydedilemezse false
  /// döner ve uyarı bandında gösterilir (ayar bellekte geçerli kalır).
  /// Şifre kilidi açık ve kilitliyse hiçbir şey değişmeden false döner
  /// ([lockRefused] işaretlenir, [lastError] dolmaz).
  Future<bool> updateConfig(AppConfig config) async {
    if (isLockEnabled && isLocked) {
      _refuseLocked();
      return false;
    }
    return _applyConfig(config);
  }

  /// Kilit denetimi yapmadan ayarı uygular ve kaydeder (iç yol).
  Future<bool> _applyConfig(AppConfig config) async {
    if (config.lock != null) _unlockedAt = _now(); // açık oturum etkinliği
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
      _notice('Ayarlar kaydedilemedi', 'Son değişiklikler kaybolabilir. ($e)');
    }
    notifyListeners();
    return saved;
  }

  // ---- Şifre kilidi ----------------------------------------------------------

  /// Kilit açıkken oturumun açık kalma süresi (son açılıştan / son başarılı kayıttan).
  static const lockTimeout = Duration(minutes: 15);

  static const lockedMessage = 'Ayarlar kilitli. Değiştirmek için önce şifreyle kilidi açın.';

  DateTime? _unlockedAt;

  /// Reddedilen ayar değişikliği oldu mu (arayüz kilit penceresini açsın).
  bool lockRefused = false;

  /// Şifre belirlenmiş mi.
  bool get isLockEnabled => _config.lock != null;

  /// Kilit açıkken: hiç açılmadıysa ya da son açılıştan [lockTimeout] geçtiyse true.
  /// Zamanlayıcı yok; saat sorgulandıkça hesaplanır.
  bool get isLocked {
    if (!isLockEnabled) return false;
    final at = _unlockedAt;
    return at == null || _now().difference(at) >= lockTimeout;
  }

  /// Oturumu hemen kapatır (kilit yoksa etkisizdir).
  void lock() {
    _unlockedAt = null;
    notifyListeners();
  }

  void clearLockRefused() {
    if (!lockRefused) return;
    lockRefused = false;
    notifyListeners();
  }

  void _refuseLocked() {
    lockRefused = true;
    notifyListeners();
  }

  static String _normalizeRecovery(String s) => s.replaceAll(RegExp(r'[\s-]'), '');

  /// [secret] parola ya da kurtarma koduysa true.
  Future<bool> _verifySecret(String secret, LockSettings lock) async {
    if (await _hasher.verify(secret, lock.password)) return true;
    final code = _normalizeRecovery(secret);
    return code.length == 8 && await _hasher.verify(code, lock.recovery);
  }

  /// Parola ya da kurtarma koduyla kilidi açar.
  Future<bool> unlock(String secret) async {
    final lock = _config.lock;
    if (lock == null) return true;
    if (!await _verifySecret(secret, lock)) return false;
    _unlockedAt = _now();
    lockRefused = false;
    notifyListeners();
    return true;
  }

  /// Parolayı belirler/değiştirir ve bir kez gösterilecek yeni kurtarma kodunu
  /// ("1234-5678") döndürür; kod hiçbir yere düz kaydedilmez. Kilit varsa
  /// [current] (parola ya da kurtarma kodu) doğru olmalı, yoksa [StateError];
  /// 4 karakterden kısa parolada [ArgumentError] fırlar. Sonrasında oturum açıktır.
  Future<String> setPassword({String? current, required String newPassword, String? hint}) async {
    final existing = _config.lock;
    if (existing != null) {
      if (current == null || !await _verifySecret(current, existing)) {
        throw StateError('Mevcut parola ya da kurtarma kodu yanlış');
      }
    }
    if (newPassword.length < 4) throw ArgumentError('Parola en az 4 karakter olmalı');
    final rnd = Random.secure();
    final digits = List.generate(8, (_) => rnd.nextInt(10)).join();
    final password = await _hasher.create(newPassword);
    final recovery = await _hasher.create(digits);
    final trimmedHint = hint?.trim();
    final lock = LockSettings(
      password: password,
      hint: trimmedHint == null || trimmedHint.isEmpty ? null : trimmedHint,
      recovery: recovery,
    );
    lockRefused = false;
    await _applyConfig(_config.copyWith(lock: () => lock));
    _unlockedAt = _now();
    notifyListeners();
    return '${digits.substring(0, 4)}-${digits.substring(4)}';
  }

  /// Parola ya da kurtarma kodu doğruysa kilidi tamamen kaldırır.
  Future<bool> removeLock(String secretOrRecovery) async {
    final lock = _config.lock;
    if (lock == null) return true;
    if (!await _verifySecret(secretOrRecovery, lock)) return false;
    _unlockedAt = null;
    lockRefused = false;
    await _applyConfig(_config.copyWith(lock: () => null));
    return true;
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
    if (isLockEnabled && isLocked) {
      _refuseLocked();
      return const [lockedMessage]; // taslak korunur
    }
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
    if (isLockEnabled && isLocked) {
      _refuseLocked();
      return const ReplaceResult(ok: false, error: lockedMessage);
    }
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
    final saved = await updateConfig(loaded.copyWith(lock: () => _config.lock, sounds: sounds));
    if (!saved) {
      warnings.add('Yeni ayar diske kaydedilemedi; uygulama yeniden açılınca eski ayara dönebilir.');
    }
    return ReplaceResult(ok: true, missingSounds: missing, warnings: warnings);
  }

  /// Son geri yükleme/içe aktarma öncesi ayarı geri getirir (bir kez).
  Future<bool> undoReplace() async {
    if (isLockEnabled && isLocked) {
      _refuseLocked();
      return false;
    }
    final previous = _configBeforeReplace;
    if (previous == null) return false;
    _configBeforeReplace = null;
    _scheduleDraft = null;
    // Şifre kilidi bu bilgisayara ait; geri alırken mevcut kilit korunur.
    await updateConfig(previous.copyWith(lock: () => _config.lock));
    return true;
  }

  /// Ayarları [path] dosyasına yazar; hata varsa metni, başarıda null döner.
  Future<String?> exportConfig(String path) async {
    // Uzantı yoksa .json eklenir (büyük/küçük harf duyarsız).
    if (!path.toLowerCase().endsWith('.json')) path = '$path.json';
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
    if (_ceremony != null) return '${_ceremony!.label} çalarken ses dinletilemez';
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

  /// Klasördeki ses dosyalarını tek seferde yükler. Adından tanınanlar
  /// adlandırılır (İstiklal Marşı, saygı duruşu, "Zil sesi N"); tören
  /// kayıtları Tören düğmesine, saygı duruşu kaydı da (okul başka bir ses
  /// seçmediyse) 10 Kasım etkinliğine atanır. Hangi zilde hangi zil sesinin
  /// çalacağına okul karar verir; zil türleri değiştirilmez. Aynı adla önceden
  /// yüklenmiş ve dosyası duran ses yeniden kopyalanmaz.
  Future<SoundPackResult> importSoundPack(String dirPath) async {
    final List<File> files;
    try {
      files = Directory(dirPath)
          .listSync()
          .whereType<File>()
          .where((f) => supportedAudioExtensions.contains(_extensionOf(f.path)))
          .toList()
        // Tanınan ada göre: "Zil sesi 2", "Zil sesi 10"dan önce gelir.
        ..sort((a, b) => _naturalKey(_displayNameOf(a.path)).compareTo(_naturalKey(_displayNameOf(b.path))));
    } catch (e) {
      return SoundPackResult(error: 'Klasör okunamadı: $e');
    }
    if (files.isEmpty) {
      return const SoundPackResult(error: 'Bu klasörde ses dosyası (mp3, wav, m4a, aac, wma) yok.');
    }
    if (isLockEnabled && isLocked) {
      _refuseLocked();
      return const SoundPackResult(error: lockedMessage);
    }

    final sep = Platform.pathSeparator;
    final dir = Directory('${repository.file.parent.path}${sep}sesler')..createSync(recursive: true);
    final sounds = [..._config.sounds];
    final ceremonies = {..._config.ceremonySounds};
    final added = <String>[];
    final kept = <String>[];
    final failed = <String>[];
    var serial = 0;
    for (final file in files) {
      final fileName = file.path.split(RegExp(r'[/\\]')).last;
      final (:name, :ceremony) = recognizeSoundName(fileName);
      final index = sounds.indexWhere((s) => !s.isAsset && s.name == name);
      final String id;
      if (index >= 0 && File(sounds[index].path).existsSync()) {
        id = sounds[index].id;
        kept.add(name);
      } else {
        // Aynı adlı ama dosyası kaybolmuş ses aynı kimlikle yenilenir; ona
        // bağlı ziller ve etkinlikler kendiliğinden düzelir.
        id = index >= 0 ? sounds[index].id : 's${DateTime.now().microsecondsSinceEpoch}${serial++}';
        final dest = '${dir.path}$sep$id.${_extensionOf(file.path)}';
        try {
          file.copySync(dest);
        } catch (e) {
          failed.add(fileName);
          continue;
        }
        final sound = BellSound(id: id, name: name, path: dest);
        if (index >= 0) {
          sounds[index] = sound;
        } else {
          sounds.add(sound);
        }
        added.add(name);
      }
      if (ceremony != null) ceremonies[ceremony] = id;
    }

    // 10 Kasım: siren yerine saygı duruşu + İstiklal Marşı kaydı bir kez çalsın.
    final remembrance = ceremonies[Ceremony.remembrance];
    var eventUpdated = false;
    final events = [
      for (final ev in _config.specialEvents)
        if (remembrance != null &&
            ev.id == '10-kasim' &&
            ev.soundId != remembrance &&
            (ev.soundId == null || ev.soundId == _fallbackAlarm.id))
          () {
            eventUpdated = true;
            return ev.copyWith(soundId: () => remembrance, loopSeconds: () => null);
          }()
        else
          ev,
    ];

    final ok = await updateConfig(_config.copyWith(sounds: sounds, ceremonySounds: ceremonies, specialEvents: events));
    if (!ok) {
      return SoundPackResult(error: lastError ?? 'Ayarlar kaydedilemedi.');
    }
    return SoundPackResult(
      added: added,
      kept: kept,
      failed: failed,
      ceremonies: {for (final e in ceremonies.entries) e.key},
      remembranceEventUpdated: eventUpdated,
    );
  }

  /// Dosya adından sesin görünen adını ve tören türünü çıkarır.
  /// "17153218_istiklalmarsi.mp3" → İstiklal Marşı, "zilsesi4.mp3" → Zil sesi 4.
  static ({String name, Ceremony? ceremony}) recognizeSoundName(String fileName) {
    final dot = fileName.lastIndexOf('.');
    var stem = dot > 0 ? fileName.substring(0, dot) : fileName;
    // Sitelerin eklediği sayısal önek ("17153032_") ada girmesin.
    stem = stem.replaceFirst(RegExp(r'^\d{5,}[_\- ]+'), '');
    final key = _fold(stem).replaceAll(RegExp(r'[_\-.]+'), ' ');
    if (key.contains('saygi')) return (name: Ceremony.remembrance.label, ceremony: Ceremony.remembrance);
    if (key.contains('istiklal')) return (name: Ceremony.anthem.label, ceremony: Ceremony.anthem);
    final bell = RegExp(r'zil ?sesi ?(\d+)').firstMatch(key);
    if (bell != null) return (name: 'Zil sesi ${int.parse(bell.group(1)!)}', ceremony: null);
    return (name: stem.trim().isEmpty ? fileName : stem.trim(), ceremony: null);
  }

  /// Türkçe harfleri sadeleştirip küçük harfe çevirir (karşılaştırma için).
  static String _fold(String s) {
    const map = {'ı': 'i', 'ş': 's', 'ğ': 'g', 'ü': 'u', 'ö': 'o', 'ç': 'c'};
    final lower = s.replaceAll('İ', 'i').replaceAll('I', 'i').toLowerCase();
    return lower.split('').map((c) => map[c] ?? c).join();
  }

  static String _extensionOf(String path) {
    final name = path.split(RegExp(r'[/\\]')).last;
    final dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(dot + 1).toLowerCase() : '';
  }

  static String _displayNameOf(String path) => recognizeSoundName(path.split(RegExp(r'[/\\]')).last).name;

  /// "Zil sesi 10", "Zil sesi 2"den sonra gelsin diye sayılar sıfırla doldurulur.
  static String _naturalKey(String text) =>
      _fold(text).replaceAllMapped(RegExp(r'\d+'), (m) => m.group(0)!.padLeft(8, '0'));

  /// Sesin kullanıldığı yerler (zil türleri ve etkinlikler).
  List<String> soundUsages(String soundId) => [
        for (final e in _config.soundForType.entries)
          if (e.value == soundId) e.key.label,
        for (final ev in _config.specialEvents)
          if (ev.soundId == soundId) ev.name,
        for (final e in _config.ceremonySounds.entries)
          if (e.value == soundId) 'Tören: ${e.key.label}',
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
      ceremonySounds: {
        for (final e in _config.ceremonySounds.entries)
          if (e.value != sound.id) e.key: e.value,
      },
    ));
    try {
      File(sound.path).deleteSync();
    } catch (_) {}
  }

  Future<void> setSoundForType(BellType type, String soundId) =>
      updateConfig(_config.copyWith(soundForType: {..._config.soundForType, type: soundId}));

  /// Tören düğmesinde çalacak kaydı seçer; null ise kaldırır.
  Future<void> setCeremonySound(Ceremony kind, String? soundId) => updateConfig(_config.copyWith(ceremonySounds: {
        for (final e in _config.ceremonySounds.entries)
          if (e.key != kind) e.key: e.value,
        kind: ?soundId,
      }));

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

  // ---- Duyuru ve nöbet ------------------------------------------------------

  /// Duyuruyu ekler ya da aynı kimlikliyi günceller.
  Future<void> saveAnnouncement(Announcement announcement) {
    final exists = _config.announcements.any((a) => a.id == announcement.id);
    return updateConfig(_config.copyWith(announcements: [
      if (exists)
        for (final a in _config.announcements) a.id == announcement.id ? announcement : a
      else ...[..._config.announcements, announcement],
    ]));
  }

  Future<void> deleteAnnouncement(String id) =>
      updateConfig(_config.copyWith(announcements: _config.announcements.where((a) => a.id != id).toList()));

  /// Nöbet çizelgesinin tamamını değiştirir.
  Future<void> setDutyRoster(List<DutyEntry> roster) => updateConfig(_config.copyWith(dutyRoster: List.of(roster)));

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

  @visibleForTesting
  void debugRefreshVolume() => _refreshVolume();

  @visibleForTesting
  void debugLog(BellLogEntry entry) => _onLog(entry);

  /// Zamanlayıcıyı bir kez işletir (testte saati elle ilerletirken).
  @visibleForTesting
  Future<Duration> debugTick() => _scheduler.tick();

  void _refreshVolume() {
    if (!system.controlsVolume) return;
    final v = system.readVolume();
    if (v.level != _volume.level || v.muted != _volume.muted || v.error != _volume.error) {
      final newError = v.error != null && _volume.error == null;
      _volume = v;
      if (newError) _notice('Ses aygıtı sorunu', v.error!);
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
    final what = '${entry.bell.time} ${entry.bell.label}';
    final detail = entry.detail;
    if (entry.outcome == BellOutcome.failed) {
      _notice('Zil çalınamadı', '$what: ${detail ?? 'bilinmeyen hata'}');
    } else if (entry.outcome == BellOutcome.missed) {
      _notice('Zil kaçırıldı', '$what${detail == null ? '' : ' ($detail)'}');
    }
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
    _ceremonyGuard?.cancel();
    _completedSub?.cancel();
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

/// Ses paketi yükleme sonucu.
class SoundPackResult {
  const SoundPackResult({
    this.error,
    this.added = const [],
    this.kept = const [],
    this.failed = const [],
    this.ceremonies = const {},
    this.remembranceEventUpdated = false,
  });

  final String? error;

  /// Yeni yüklenen (ya da kaybolmuş dosyası yenilenen) seslerin adları.
  final List<String> added;

  /// Zaten yüklü olduğu için kopyalanmayanlar.
  final List<String> kept;

  /// Kopyalanamayan dosya adları.
  final List<String> failed;

  /// Tören düğmesinde artık çalınabilen kayıtlar.
  final Set<Ceremony> ceremonies;

  /// 10 Kasım etkinliğinin sesi saygı duruşu kaydına çevrildi mi.
  final bool remembranceEventUpdated;
}
