import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:okul_zili/app_controller.dart';
import 'package:okul_zili/core/clock_time.dart';
import 'package:okul_zili/core/scheduler/bell_log.dart';
import 'package:okul_zili/data/config_repository.dart';
import 'package:okul_zili/data/default_config.dart';
import 'package:okul_zili/data/models/bell_event.dart';
import 'package:okul_zili/platform/system_services.dart';

import 'support/app_harness.dart';

class _VolSystem extends NoopSystemServices {
  _VolSystem();
  String? error;

  @override
  bool get controlsVolume => true;

  @override
  VolumeStatus readVolume() => VolumeStatus(level: 0.5, error: error);
}

void main() {
  late Directory tmp;
  late DateTime now;
  late List<(String, String)> notices;
  late _VolSystem system;
  late AppController c;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('okul_zili_bildirim');
    now = DateTime(2026, 3, 2, 9, 0);
    notices = [];
    system = _VolSystem();
    c = AppController(
      config: createDefaultConfig(),
      repository: ConfigRepository(File('${tmp.path}/config.json')),
      player: SilentPlayer(),
      system: system,
      now: () => now,
    );
    c.onNotice = (t, b) => notices.add((t, b));
  });
  tearDown(() {
    c.dispose();
    try {
      tmp.deleteSync(recursive: true);
    } on FileSystemException catch (_) {}
  });

  const bell = BellEvent(
      id: 'x', time: ClockTime(9, 0), type: BellType.lessonStart, label: '1. ders');

  Future<void> ring(BellOutcome o, {String? detail}) async {
    c.debugLog(BellLogEntry(at: now, bell: bell, outcome: o, detail: detail));
  }

  test('failed ve missed bildirim üretir; played ve muted üretmez', () async {
    await ring(BellOutcome.played);
    await ring(BellOutcome.muted);
    expect(notices, isEmpty);
    await ring(BellOutcome.failed, detail: 'ses yok');
    await ring(BellOutcome.missed, detail: 'geç kaldı');
    expect(notices.map((n) => n.$1), ['Zil çalınamadı', 'Zil kaçırıldı']);
    expect(notices[0].$2, '09:00 1. ders: ses yok');
    expect(notices[1].$2, '09:00 1. ders (geç kaldı)');
  });

  test('aynı bildirim 10 dakika içinde tek, sonra yeniden', () async {
    await ring(BellOutcome.failed, detail: 'a');
    now = now.add(const Duration(minutes: 9));
    await ring(BellOutcome.failed, detail: 'a');
    expect(notices, hasLength(1));
    now = now.add(const Duration(minutes: 2));
    await ring(BellOutcome.failed, detail: 'a');
    expect(notices, hasLength(2));
  });

  test('ses hatası null->dolu tek bildirim; düzelip bozulunca yeniden', () {
    c.start();
    system.error = 'aygıt yok';
    for (var i = 0; i < 20; i++) {
      now = now.add(const Duration(seconds: 5));
      c.debugRefreshVolume();
    }
    expect(notices.where((n) => n.$1 == 'Ses aygıtı sorunu'), hasLength(1));
    system.error = null;
    c.debugRefreshVolume();
    system.error = 'aygıt yok';
    now = now.add(const Duration(minutes: 11));
    c.debugRefreshVolume();
    expect(notices.where((n) => n.$1 == 'Ses aygıtı sorunu'), hasLength(2));
  });

  test('ses hatası 10 dk içinde düzelip yeniden bozulursa bastırılır', () {
    c.start();
    system.error = 'aygıt yok';
    c.debugRefreshVolume();
    system.error = null;
    c.debugRefreshVolume();
    system.error = 'aygıt yok';
    now = now.add(const Duration(minutes: 1));
    c.debugRefreshVolume();
    expect(notices.where((n) => n.$1 == 'Ses aygıtı sorunu'), hasLength(1));
  });

  test('açılış uyarısı start() sonrası onNotice atanınca tek sefer iletilir', () {
    final repo = ConfigRepository(File('${tmp.path}/config2.json'))
      ..lastLoadWarning = 'Ayar dosyası okunamadı; 2026-03-01 tarihli yedek yüklendi.';
    final late = AppController(
      config: createDefaultConfig(),
      repository: repo,
      player: SilentPlayer(),
      system: const NoopSystemServices(),
      now: () => now,
    );
    addTearDown(late.dispose);
    late.start();
    final got = <(String, String)>[];
    late.onNotice = (t, b) => got.add((t, b));
    expect(got, hasLength(1));
    expect(got.single.$1, 'Ayarlar yedekten yüklendi');
    late.onNotice = (t, b) => got.add((t, b));
    expect(got, hasLength(1));
  });

  test('kayıt hatasında bildirim', () async {
    final bad = AppController(
      config: createDefaultConfig(),
      repository: ConfigRepository(File('${tmp.path}/yok/alt/config.json')),
      player: SilentPlayer(),
      system: const NoopSystemServices(),
      now: () => now,
    );
    addTearDown(bad.dispose);
    final got = <String>[];
    bad.onNotice = (t, b) => got.add(t);
    expect(await bad.updateConfig(createDefaultConfig()), isFalse);
    expect(got, ['Ayarlar kaydedilemedi']);
  });

  test('onNotice null iken çökmez', () async {
    c.onNotice = null;
    await ring(BellOutcome.failed, detail: 'a');
    expect(notices, isEmpty);
  });
}
