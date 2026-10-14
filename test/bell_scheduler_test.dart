import 'package:flutter_test/flutter_test.dart';
import 'package:okul_zili/core/scheduler/bell_log.dart';
import 'package:okul_zili/core/scheduler/bell_scheduler.dart';
import 'package:okul_zili/core/scheduler/day_schedule.dart';
import 'package:okul_zili/data/default_config.dart';
import 'package:okul_zili/data/models/bell_event.dart';

/// Gerçek saati beklemeden zamanlayıcıyı adım adım sürmek için düzenek.
class _Harness {
  _Harness(this.now) {
    final resolver = ScheduleResolver(createDefaultConfig());
    scheduler = BellScheduler(
      resolveDay: resolver.resolve,
      ring: (bell) async {
        if (failRing) throw Exception('ses aygıtı yok');
        rung.add(bell);
        return null;
      },
      onLog: logs.add,
      now: () => now,
    );
  }

  DateTime now;
  bool failRing = false;
  late final BellScheduler scheduler;
  final rung = <BellEvent>[];
  final logs = <BellLogEntry>[];

  /// Uygulamayı başlatır ama gerçek zamanlayıcıyı hemen durdurur; testte
  /// adımları [tick] ile elle atarız.
  void startAt(DateTime t) {
    now = t;
    scheduler.start();
    scheduler.stop();
  }

  Future<Duration> tickAt(DateTime t) {
    now = t;
    return scheduler.tick();
  }

  List<String> get rungIds => rung.map((b) => b.id).toList();
}

DateTime _wed(int h, int m, [int s = 0]) => DateTime(2026, 10, 14, h, m, s);

void main() {
  test('zil tam zamanında bir kez çalar', () async {
    final h = _Harness(_wed(8, 0));
    h.startAt(_wed(8, 0));

    await h.tickAt(_wed(8, 29, 59));
    expect(h.rung, isEmpty);

    await h.tickAt(_wed(8, 30, 0));
    await h.tickAt(_wed(8, 30, 5));
    await h.tickAt(_wed(8, 30, 20));
    expect(h.rungIds, ['assembly']);
    expect(h.logs.single.outcome, BellOutcome.played);
  });

  test('tolerans içinde geç kalınan zil yine çalar', () async {
    final h = _Harness(_wed(8, 0));
    h.startAt(_wed(8, 0));
    await h.tickAt(_wed(8, 30, 45));
    expect(h.rungIds, ['assembly']);
  });

  test('uyku sonrası tolerans dışındaki ziller çalmaz, kaçırıldı yazılır', () async {
    final h = _Harness(_wed(8, 0));
    h.startAt(_wed(8, 0));
    // Bilgisayar 08:20'de uyudu, 08:38:40'ta uyandı.
    await h.tickAt(_wed(8, 38, 40));
    expect(h.rungIds, ['L1-teacher'], reason: '08:38 zili yalnızca 40 sn gecikti');
    final missed = h.logs.where((l) => l.outcome == BellOutcome.missed);
    expect(missed.map((l) => l.bell.id), ['assembly']);
  });

  test('uygulama açılmadan önceki ziller sessizce atlanır', () async {
    final h = _Harness(_wed(10, 0));
    h.startAt(_wed(10, 0));
    await h.tickAt(_wed(10, 0, 1));
    expect(h.rung, isEmpty);
    expect(h.logs, isEmpty);

    await h.tickAt(_wed(10, 15));
    expect(h.rungIds, ['L2-end']);
  });

  test('susturulmuşken çalmaz, susturma kalkınca sonraki zil çalar', () async {
    final h = _Harness(_wed(8, 0));
    h.startAt(_wed(8, 0));
    h.scheduler.muteUntil(_wed(9, 0));

    await h.tickAt(_wed(8, 30));
    expect(h.rung, isEmpty);
    expect(h.logs.single.outcome, BellOutcome.muted);

    await h.tickAt(_wed(9, 20));
    expect(h.rungIds, ['L1-end']);
  });

  test('çalma hatası kaydedilir ve zil tekrar denenmez', () async {
    final h = _Harness(_wed(8, 0));
    h.startAt(_wed(8, 0));
    h.failRing = true;
    await h.tickAt(_wed(8, 30));
    h.failRing = false;
    await h.tickAt(_wed(8, 30, 10));
    expect(h.rung, isEmpty);
    expect(h.logs.single.outcome, BellOutcome.failed);
  });

  test('ertesi gün aynı ziller yeniden çalar', () async {
    final h = _Harness(_wed(8, 0));
    h.startAt(_wed(8, 0));
    await h.tickAt(_wed(8, 30));
    await h.tickAt(DateTime(2026, 10, 15, 8, 30));
    expect(h.rungIds, ['assembly', 'assembly']);
  });

  test('tatil gününde hiç çalmaz', () async {
    final h = _Harness(DateTime(2026, 10, 29, 8));
    h.startAt(DateTime(2026, 10, 29, 8));
    for (var m = 0; m < 8 * 60; m++) {
      await h.tickAt(DateTime(2026, 10, 29, 8).add(Duration(minutes: m)));
    }
    expect(h.rung, isEmpty);
  });

  test('tüm gün dakika dakika simüle edilince 19 zil sırayla çalar', () async {
    final h = _Harness(_wed(7, 0));
    h.startAt(_wed(7, 0));
    for (var s = 0; s < 9 * 3600; s += 15) {
      await h.tickAt(_wed(7, 0).add(Duration(seconds: s)));
    }
    final expected = ScheduleResolver(createDefaultConfig())
        .resolve(_wed(0, 0))
        .bells
        .map((b) => b.id)
        .toList();
    expect(h.rungIds, expected);
    expect(h.logs.every((l) => l.outcome == BellOutcome.played), isTrue);
  });

  group('bekleme süresi', () {
    test('sıradaki zile 15 sn\'den az varsa tam o ana kadar bekler', () async {
      final h = _Harness(_wed(8, 0));
      h.startAt(_wed(8, 0));
      final delay = await h.tickAt(_wed(8, 29, 52));
      expect(delay.inMilliseconds, inInclusiveRange(8000, 8100));
    });

    test('zil uzaksa en fazla 15 sn bekler', () async {
      final h = _Harness(_wed(8, 0));
      h.startAt(_wed(8, 0));
      expect(await h.tickAt(_wed(8, 0)), const Duration(seconds: 15));
    });
  });

  test('bekletme nedeni varken zil çalmaz ve neden kaydedilir', () async {
    String? reason = 'Acil durum alarmı sürüyor';
    final rung = <BellEvent>[];
    final logs = <BellLogEntry>[];
    var now = _wed(8, 0);
    final scheduler = BellScheduler(
      resolveDay: ScheduleResolver(createDefaultConfig()).resolve,
      ring: (b) async {
        rung.add(b);
        return null;
      },
      onLog: logs.add,
      holdReason: () => reason,
      now: () => now,
    );
    now = _wed(8, 30);
    await scheduler.tick();
    expect(rung, isEmpty);
    expect(logs.single.outcome, BellOutcome.muted);
    expect(logs.single.detail, 'Acil durum alarmı sürüyor');

    reason = null;
    now = _wed(8, 38);
    await scheduler.tick();
    expect(rung.map((b) => b.id), ['L1-teacher']);
  });

  test('elle çalınan zil susturmayı yok sayar', () async {
    final h = _Harness(_wed(10, 0));
    h.scheduler.muteUntil(_wed(23, 0));
    await h.scheduler.ringNow();
    expect(h.rung.single.type, BellType.manual);
    expect(h.logs.single.outcome, BellOutcome.played);
  });
}
