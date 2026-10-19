import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:okul_zili/app_controller.dart';
import 'package:okul_zili/data/config_repository.dart';
import 'package:okul_zili/data/default_config.dart';
import 'package:okul_zili/data/models/bell_event.dart';
import 'package:okul_zili/ui/navigation.dart';

import 'support/app_harness.dart';

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('okul_zili_dinle'));
  tearDown(() {
    try {
      tmp.deleteSync(recursive: true);
    } on FileSystemException catch (_) {}
  });

  AppController makeController(RecordingPlayer player) => AppController(
        config: createDefaultConfig(),
        repository: ConfigRepository(File('${tmp.path}/ayar/config.json')..parent.createSync(recursive: true)),
        player: player,
        now: () => DateTime(2026, 10, 19, 10, 0),
        passwordHasher: const FastPasswordHasher(),
      );

  group('Dinleme: oynat / duraklat / durdur', () {
    test('duraklat, sürdür ve bitince durum kalkar', () async {
      final player = RecordingPlayer();
      final c = makeController(player);
      final gong = c.config.soundById('gong')!;
      await c.previewSound(gong);
      expect(c.previewingSoundId, 'gong');
      expect(c.previewPaused, isFalse);

      await c.pausePreview();
      expect(player.pauses, 1);
      expect(c.previewPaused, isTrue);
      await c.resumePreview();
      expect(player.resumes, 1);
      expect(c.previewPaused, isFalse);

      player.finish();
      expect(c.previewingSoundId, isNull);
    });

    test('durdur ve zil dinlemeyi bitirir', () async {
      final player = RecordingPlayer();
      final c = makeController(player);
      await c.previewSound(c.config.soundById('gong')!);
      await c.stopSound();
      expect(c.previewingSoundId, isNull);

      await c.previewSound(c.config.soundById('gong')!);
      await c.ringNow();
      expect(c.previewingSoundId, isNull, reason: 'zil dinlenen sesi keser');
    });

    test('dinleme yokken duraklat/sürdür bir şey yapmaz', () async {
      final player = RecordingPlayer();
      final c = makeController(player);
      await c.pausePreview();
      await c.resumePreview();
      expect(player.pauses + player.resumes, 0);
    });
  });

  group('Hazır seslerin silinmesi', () {
    test('seçilen yedek ses zillere atanır, acil durum sirende kalır', () async {
      final c = makeController(RecordingPlayer());
      await c.deleteSound(c.config.soundById('zil')!, replacementId: 'gong');
      expect(c.config.soundForType[BellType.lessonStart], 'gong');
      expect(c.config.soundForType[BellType.emergency], 'alarm');
    });

    test('hiç ses kalmasa da zil ve acil durum yerleşik seslerle çalar', () async {
      final player = RecordingPlayer();
      final c = makeController(player);
      for (final id in ['zil', 'gong', 'alarm']) {
        await c.deleteSound(c.config.soundById(id)!);
      }
      expect(c.config.sounds, isEmpty);
      expect(c.config.soundForType, isEmpty);
      await c.ringNow();
      expect(player.plays.last.id, 'zil');
      await c.startEmergency();
      expect(player.plays.last, (id: 'alarm', loop: true));
      await c.stopSound();
    });

    test('siren silinince acil durum yine siren çalar (ilk ses değil)', () async {
      final player = RecordingPlayer();
      final c = makeController(player);
      await c.deleteSound(c.config.soundById('alarm')!);
      await c.startEmergency();
      expect(player.plays.last.id, 'alarm');
      await c.stopSound();
    });

    test('kilitliyken silinmez, yüklenen sesin dosyası da yerinde kalır', () async {
      final c = makeController(RecordingPlayer());
      final sound = await c.importSound((File('${tmp.path}/bizim.mp3')..writeAsBytesSync([1])).path);
      await c.setPassword(newPassword: 'okul1234');
      c.lock();
      await c.deleteSound(sound);
      expect(c.config.soundById(sound.id), isNotNull);
      expect(File(sound.path).existsSync(), isTrue);
    });
  });

  group('Arayüz', () {
    setUpAll(loadAppFont);
    final now = DateTime(2026, 10, 19, 10, 0);

    testWidgets('sesin yanında oynat, duraklat, sürdür, durdur', (tester) async {
      final player = RecordingPlayer();
      await pumpOkulZili(tester, now: now, page: AppPage.sounds, player: player);
      await tapVisible(tester, find.byTooltip('Ding-dong dinle'));
      expect(player.plays.last.id, 'gong');
      await tapVisible(tester, find.byTooltip('Ding-dong duraklat'));
      expect(player.pauses, 1);
      await tapVisible(tester, find.byTooltip('Ding-dong sürdür'));
      expect(player.resumes, 1);
      await tapVisible(tester, find.byTooltip('Ding-dong durdur'));
      expect(find.byTooltip('Ding-dong dinle'), findsOneWidget);
    });

    testWidgets('hazır ses yedek seçilerek silinir ve geri getirilir', (tester) async {
      final (c, _) = await pumpOkulZili(tester, now: now, page: AppPage.sounds);
      await tapVisible(tester, find.byTooltip('Ding-dong sil'));
      expect(find.text('Bu zillerde yerine çalacak ses:'), findsOneWidget);
      expect(find.textContaining('Hazır sesleri geri getir'), findsOneWidget);
      await tapVisible(tester, find.text('Sil'));
      expect(c.config.soundById('gong'), isNull);
      expect(c.config.soundForType[BellType.teacher], 'zil');

      await tapVisible(tester, find.text('Hazır sesleri geri getir'));
      expect(c.config.soundById('gong'), isNotNull);
      expect(find.text('Hazır sesleri geri getir'), findsNothing);
    });
  });
}
