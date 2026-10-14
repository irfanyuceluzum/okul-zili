import 'dart:async';

import '../../data/models/bell_event.dart';
import '../clock_time.dart';
import '../date_utils.dart';
import 'bell_log.dart';
import 'day_schedule.dart';

typedef Now = DateTime Function();

/// Zamanı gelen zilleri çalan motor.
///
/// Sabit aralıklı bir döngü yerine sıradaki zile kadar bekler, ama en fazla
/// [maxSleep] kadar. Her uyanışta saati yeniden okuduğu için sistem saati
/// değişse veya bilgisayar uykudan uyansa bile kayma olmaz.
class BellScheduler {
  BellScheduler({
    required this.resolveDay,
    required this.ring,
    required this.onLog,
    this.holdReason,
    Now? now,
    this.tolerance = const Duration(seconds: 60),
    this.maxSleep = const Duration(seconds: 15),
  }) : _now = now ?? DateTime.now;

  /// Verilen günün programını döndürür. Ayarlar değişince yeni program
  /// bir sonraki kontrolde kendiliğinden kullanılır.
  final DaySchedule Function(DateTime date) resolveDay;

  /// Zili çalar; hata fırlatırsa zil "Hata" olarak kaydedilir. Dönen metin
  /// (ör. "yedek ses çalındı") kayda açıklama olarak eklenir.
  final Future<String?> Function(BellEvent bell) ring;
  final void Function(BellLogEntry entry) onLog;

  /// Null olmayan bir neden dönerse programlı ziller çalınmaz, bu nedenle
  /// "susturuldu" olarak kaydedilir (ör. acil durum alarmı sürerken).
  final String? Function()? holdReason;

  /// Zil saatinden bu kadar sonrasına kadar geç de olsa çalınır.
  /// Ayar değişince [AppController] günceller.
  Duration tolerance;
  final Duration maxSleep;

  final Now _now;
  final Set<String> _handled = {};

  /// Bir zilin o günkü kaydının anahtarı. Saat de anahtarın parçasıdır:
  /// çaldıktan sonra saati ileri alınan zil yeni saatinde yeniden çalar.
  static String keyFor(DateTime day, BellEvent bell) => '${dateKey(day)}|${bell.id}@${bell.time}';
  DateTime? _startedAt;
  DateTime? _mutedUntil;
  Timer? _timer;
  bool _running = false;

  bool get isRunning => _running;

  DateTime? get mutedUntil => _mutedUntil;

  bool isMuted([DateTime? at]) {
    final until = _mutedUntil;
    return until != null && (at ?? _now()).isBefore(until);
  }

  /// Verilen ana kadar zilleri susturur; null verilirse susturma kalkar.
  void muteUntil(DateTime? until) => _mutedUntil = until;

  /// Önceden işlenmiş zilleri bildirir (ör. yeniden başlatmada kayıt
  /// dosyasından): az önce çalmış zil tolerans içinde diye ikinci kez çalmaz.
  void markHandled(Iterable<String> keys) => _handled.addAll(keys);

  /// Program değiştiğinde çağrılır: bugüne sonradan eklenen ve saati çoktan
  /// geçmiş ziller "kaçırıldı" yazılmadan atlanır.
  void scheduleChanged() => _startedAt = _now();

  void start() {
    if (_running) return;
    _running = true;
    _startedAt = _now();
    _loop();
  }

  void stop() {
    _running = false;
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _loop() async {
    if (!_running) return;
    Duration delay;
    try {
      delay = await tick();
    } catch (_) {
      delay = maxSleep;
    }
    if (!_running) return;
    _timer = Timer(delay, _loop);
  }

  /// Zamanı gelmiş zilleri işler ve bir sonraki kontrole kadar beklenecek
  /// süreyi döndürür. Testlerde doğrudan çağrılır.
  Future<Duration> tick() async {
    final now = _now();
    final day = resolveDay(now);
    final dayPrefix = '${dateKey(day.date)}|';
    _handled.removeWhere((k) => !k.startsWith(dayPrefix));

    for (final bell in day.bells) {
      final at = day.timeOf(bell);
      if (at.isAfter(now)) break;

      final key = keyFor(day.date, bell);
      if (!_handled.add(key)) continue;

      // Uygulama açılmadan önce geçmiş ziller sessizce atlanır; bunlar
      // "kaçırıldı" sayılmaz (ör. öğlen başlatılan uygulama).
      final started = _startedAt;
      if (started != null && at.isBefore(started.subtract(tolerance))) {
        continue;
      }

      final late = now.difference(at);
      if (late > tolerance) {
        _log(bell, BellOutcome.missed, key: key,
            detail: '${late.inMinutes} dk gecikme');
      } else if (isMuted(now)) {
        _log(bell, BellOutcome.muted, key: key);
      } else if (holdReason?.call() case final reason?) {
        _log(bell, BellOutcome.muted, key: key, detail: reason);
      } else {
        await _play(bell, key: key);
      }
    }

    for (final bell in day.bells) {
      final at = day.timeOf(bell);
      if (at.isAfter(now)) {
        final untilBell = at.difference(now) + const Duration(milliseconds: 5);
        return untilBell < maxSleep ? untilBell : maxSleep;
      }
    }
    return maxSleep;
  }

  /// Programdan bağımsız olarak hemen zil çalar (susturma yok sayılır).
  Future<void> ringNow({String label = 'Elle çalınan zil'}) async {
    final now = _now();
    final bell = BellEvent(
      id: 'manual-${now.millisecondsSinceEpoch}',
      time: ClockTime(now.hour, now.minute),
      type: BellType.manual,
      label: label,
    );
    await _play(bell);
  }

  Future<void> _play(BellEvent bell, {String? key}) async {
    try {
      final detail = await ring(bell);
      _log(bell, BellOutcome.played, key: key, detail: detail);
    } catch (e) {
      _log(bell, BellOutcome.failed, key: key, detail: '$e');
    }
  }

  void _log(BellEvent bell, BellOutcome outcome, {String? key, String? detail}) {
    onLog(BellLogEntry(
      at: _now(),
      bell: bell,
      outcome: outcome,
      key: key,
      detail: detail,
    ));
  }
}
