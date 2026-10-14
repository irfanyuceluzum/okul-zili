import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:okul_zili/app_controller.dart';
import 'package:okul_zili/core/scheduler/bell_log.dart';
import 'package:okul_zili/data/config_repository.dart';
import 'package:okul_zili/data/default_config.dart';

import 'support/app_harness.dart';

/// Uygulama gün içinde yeniden başlatılınca (güncelleme, çökme) davranış.
void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('okul_zili_yeniden'));
  tearDown(() {
    try {
      tmp.deleteSync(recursive: true);
    } on FileSystemException catch (_) {}
  });

  AppController controllerAt(DateTime now, RecordingPlayer player) => AppController(
        config: createDefaultConfig(),
        repository: ConfigRepository(File('${tmp.path}${Platform.pathSeparator}config.json')),
        player: player,
        now: () => now,
      );

  test('sabah çalan ziller yeniden açılışta "çaldı" görünür; eski biçimli satırlar atlanır', () {
    final c = controllerAt(DateTime(2026, 10, 14, 10, 0), RecordingPlayer());
    File(c.logFilePath).writeAsStringSync([
      '2026-10-13T08:30:00.000\t2026-10-13|assembly@08:30\t08:30\tToplanma\tÇaldı',
      '2026-10-14T08:30:00.000\t2026-10-14|assembly@08:30\t08:30\tToplanma\tÇaldı',
      '2026-10-14T08:38:00.000\t2026-10-14|L1-teacher@08:38\t08:38\t1. ders öğretmen zili\tSusturuldu',
      '2026-10-14T08:40:00.000\t08:40\t1. ders giriş\tÇaldı', // eski biçim
      '2026-10-14T09:00:00.000\t-\t09:00\tElle çalınan zil\tÇaldı',
      '',
    ].join('\n'));

    c.restoreTodayFromLog();
    final today = c.resolver.resolve(DateTime(2026, 10, 14));
    BellOutcome? of(String id) => c.outcomeOf(today, today.bells.firstWhere((b) => b.id == id));
    expect(of('assembly'), BellOutcome.played);
    expect(of('L1-teacher'), BellOutcome.muted);
    expect(of('L1-start'), isNull);
  });

  test('zilden hemen sonra yeniden başlayınca zil ikinci kez çalmaz', () async {
    final player = RecordingPlayer();
    final c = controllerAt(DateTime(2026, 10, 14, 8, 30, 20), player);
    File(c.logFilePath).writeAsStringSync(
        '2026-10-14T08:30:00.000\t2026-10-14|assembly@08:30\t08:30\tToplanma\tÇaldı\n');
    c.start();
    await Future<void>.delayed(Duration.zero);
    expect(player.plays, isEmpty, reason: '08:30 zili 20 sn önce çalmıştı');
    c.dispose();
  });

  test('2 MB\'ı aşan kayıt dosyası kenara alınır', () {
    final c = controllerAt(DateTime(2026, 10, 14, 10, 0), RecordingPlayer());
    File(c.logFilePath).writeAsBytesSync(List.filled(2 * 1024 * 1024 + 1, 65));
    c.restoreTodayFromLog();
    expect(File(c.logFilePath).existsSync(), isFalse);
    expect(File(c.logFilePath.replaceFirst('.log', '.eski.log')).existsSync(), isTrue);
  });
}
