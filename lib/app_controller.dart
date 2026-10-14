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
import 'platform/bell_player.dart';
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
  })  : _config = config,
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

  BellOutcome? outcomeOf(DaySchedule day, BellEvent bell) =>
      _outcomes['${dateKey(day.date)}|${bell.id}'];

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
      final sound = _config.soundById('alarm') ?? _fallbackAlarm;
      await player.play(sound, volumePercent: 100, loop: true);
      _onLog(BellLogEntry(at: _now(), bell: bell, outcome: BellOutcome.played));
    } catch (e) {
      _onLog(BellLogEntry(at: _now(), bell: bell, outcome: BellOutcome.failed, detail: '$e'));
    }
  }

  Future<void> updateConfig(AppConfig config) async {
    _config = config;
    notifyListeners();
    try {
      await repository.save(config);
      _lastError = null;
    } catch (e) {
      _lastError = 'Ayarlar kaydedilemedi: $e';
    }
    notifyListeners();
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

  /// Sonraki (bugün dahil) tatil.
  Holiday? nextHoliday() {
    final today = dateOnly(_now());
    final upcoming = _config.holidays.where((h) => !h.end.isBefore(today)).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    return upcoming.firstOrNull;
  }

  // ---- İç işleyiş ---------------------------------------------------------

  Future<void> _ring(BellEvent bell) async {
    final sound = _config.soundFor(bell);
    if (sound == null) throw StateError('Tanımlı zil sesi yok');
    _ensureAudible(_config.volumePercent);
    // Sistem sesi denetlenebiliyorsa seviye oradan ayarlanır; çalar tam
    // seviyede çalar. Denetlenemiyorsa seviye çalarda uygulanır.
    await player.play(
      sound,
      volumePercent: system.controlsVolume ? 100 : _config.volumePercent,
    );
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

  void _appendLogFile(BellLogEntry entry) {
    final file = File(logFilePath);
    final line = '${entry.at.toIso8601String()}\t${entry.bell.time}\t'
        '${entry.bell.label}\t${entry.outcome.label}'
        '${entry.detail == null ? '' : '\t${entry.detail}'}\n';
    file.writeAsString(line, mode: FileMode.append, flush: true).catchError((_) => file);
  }

  @override
  void dispose() {
    _scheduler.stop();
    _volumeTimer?.cancel();
    super.dispose();
  }
}
