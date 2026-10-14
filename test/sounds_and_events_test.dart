import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okul_zili/app_controller.dart';
import 'package:okul_zili/core/clock_time.dart';
import 'package:okul_zili/core/scheduler/bell_log.dart';
import 'package:okul_zili/data/config_repository.dart';
import 'package:okul_zili/data/default_config.dart';
import 'package:okul_zili/data/models/bell_event.dart';
import 'package:okul_zili/data/models/calendar.dart';
import 'package:okul_zili/ui/navigation.dart';

import 'support/app_harness.dart';

/// Geçici klasörde sahte bir ses dosyası (içeriği önemsiz, çalar sahte).
File _fakeAudio(Directory dir, String name) => File('${dir.path}/$name')..writeAsBytesSync([0, 1, 2, 3]);

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('okul_zili_ses'));
  tearDown(() {
    try {
      tmp.deleteSync(recursive: true);
    } on FileSystemException catch (_) {}
  });

  AppController makeController(RecordingPlayer player) => AppController(
        config: createDefaultConfig(),
        repository: ConfigRepository(File('${tmp.path}/ayar/config.json')..parent.createSync()),
        player: player,
        now: () => DateTime(2026, 10, 19, 8, 0),
      );

  group('Ses yönetimi', () {
    test('yüklenen ses uygulama klasörüne kopyalanır ve listeye eklenir', () async {
      final c = makeController(RecordingPlayer());
      final source = _fakeAudio(tmp, 'Okul Zilimiz.mp3');
      final sound = await c.importSound(source.path);

      expect(sound.name, 'Okul Zilimiz');
      expect(sound.isAsset, isFalse);
      // Windows "\" kullanır; karşılaştırma ayırıcıdan bağımsız olsun.
      String slashes(String p) => p.replaceAll(r'\', '/');
      expect(slashes(sound.path), startsWith('${slashes(tmp.path)}/ayar/sesler/'));
      expect(File(sound.path).existsSync(), isTrue);
      source.deleteSync();
      expect(File(sound.path).existsSync(), isTrue, reason: 'asıl dosya silinse de kopya kalır');
      expect(c.config.sounds.map((s) => s.id), contains(sound.id));
    });

    test('dosyası kaybolan ses yerine klasik zil çalar ve kayda not düşülür', () async {
      final player = RecordingPlayer();
      final c = makeController(player);
      final sound = await c.importSound(_fakeAudio(tmp, 'ozel.wav').path);
      await c.setSoundForType(BellType.manual, sound.id);
      File(sound.path).deleteSync();

      await c.ringNow();
      expect(player.plays.single.id, 'zil');
      expect(c.logs.first.outcome, BellOutcome.played);
      expect(c.logs.first.detail, contains('bulunamadı'));
    });

    test('çalınamayan ses yerine klasik zil çalar', () async {
      final player = RecordingPlayer();
      final c = makeController(player);
      final sound = await c.importSound(_fakeAudio(tmp, 'bozuk.wma').path);
      await c.setSoundForType(BellType.manual, sound.id);
      player.failFor = sound.id;

      await c.ringNow();
      expect(player.plays.single.id, 'zil');
      expect(c.logs.first.detail, contains('çalınamadı'));
    });

    test('silinen sesin yerine klasik zil ve varsayılan etkinlik sesi geçer', () async {
      final c = makeController(RecordingPlayer());
      final sound = await c.importSound(_fakeAudio(tmp, 'marş.mp3').path);
      await c.setSoundForType(BellType.lessonStart, sound.id);
      await c.saveEvent(SpecialEvent(
        id: 'm',
        name: 'İstiklal Marşı',
        time: ClockTime.parse('08:32'),
        recurrence: Recurrence.weekly,
        weekdays: {1},
        soundId: sound.id,
      ));
      expect(c.soundUsages(sound.id), ['Giriş zili', 'İstiklal Marşı']);

      await c.deleteSound(sound);
      expect(c.config.soundForType[BellType.lessonStart], 'zil');
      expect(c.config.specialEvents.singleWhere((e) => e.id == 'm').soundId, isNull);
      expect(File(sound.path).existsSync(), isFalse);
    });

    test('acil durum sesi silinince sirene döner', () async {
      final c = makeController(RecordingPlayer());
      final sound = await c.importSound(_fakeAudio(tmp, 'okul-sireni.wav').path);
      await c.setSoundForType(BellType.emergency, sound.id);
      await c.deleteSound(sound);
      expect(c.config.soundForType[BellType.emergency], 'alarm');
    });

    test('siren çalınamazsa acil durum kipi açık kalmaz, ziller susmaz', () async {
      final player = RecordingPlayer()..failFor = 'alarm';
      final c = makeController(player);
      await c.startEmergency();
      expect(c.emergencyActive, isFalse);
      expect(c.logs.first.outcome, BellOutcome.failed);

      await c.ringNow();
      expect(player.plays.single.id, 'zil', reason: 'acil durum kipi zilleri bekletmiyor');
    });

    test('yerleşik sesler silinmez', () async {
      final c = makeController(RecordingPlayer());
      await c.deleteSound(c.config.soundById('zil')!);
      expect(c.config.soundById('zil'), isNotNull);
    });
  });

  group('Süreli tekrar', () {
    testWidgets('siren süre dolunca durur', (tester) async {
      final player = RecordingPlayer();
      final c = makeController(player);
      await c.previewSound(c.config.soundById('alarm')!, stopAfter: 60);
      expect(player.plays.single.loop, isTrue);
      await tester.pump(const Duration(seconds: 59));
      expect(player.stops, 0);
      await tester.pump(const Duration(seconds: 2));
      expect(player.stops, 1);
    });

    testWidgets('arada başka zil çaldıysa durdurucu onu kesmez', (tester) async {
      final player = RecordingPlayer();
      final c = makeController(player);
      await c.previewSound(c.config.soundById('alarm')!, stopAfter: 10);
      await tester.pump(const Duration(seconds: 5));
      await c.ringNow();
      await tester.pump(const Duration(seconds: 10));
      expect(player.stops, 0);
    });
  });

  group('Zil sesleri sayfası', () {
    setUpAll(loadAppFont);
    final now = DateTime(2026, 10, 14, 10, 0);

    testWidgets('dosya eklenir ve giriş ziline atanır', (tester) async {
      final source = _fakeAudio(tmp, 'Bizim Zil.mp3');
      final (controller, _) = await pumpOkulZili(
        tester,
        now: now,
        page: AppPage.sounds,
        pickAudioFile: () async => source.path,
      );
      expect(tester.takeException(), isNull);

      await tapVisible(tester, find.text('Ses dosyası ekle'));
      expect(find.text('Bizim Zil'), findsOneWidget);
      expect(find.text('Yüklenen'), findsOneWidget);
      final added = controller.config.sounds.singleWhere((s) => s.name == 'Bizim Zil');

      // "Giriş zili" satırındaki seçim kutusu (üçüncü atama satırı).
      await tapVisible(tester, find.byType(DropdownButton<String>).at(2));
      await tester.tap(find.text('Bizim Zil').last);
      await tester.pumpAndSettle();
      expect(controller.config.soundForType[BellType.lessonStart], added.id);
    });

    testWidgets('desteklenmeyen biçim reddedilir', (tester) async {
      final source = _fakeAudio(tmp, 'zil.ogg');
      final (controller, _) = await pumpOkulZili(
        tester,
        now: now,
        page: AppPage.sounds,
        pickAudioFile: () async => source.path,
      );
      final before = controller.config.sounds.length;
      await tapVisible(tester, find.text('Ses dosyası ekle'));
      expect(find.textContaining('desteklenmiyor'), findsOneWidget);
      expect(controller.config.sounds, hasLength(before));
    });
  });

  group('Özel etkinlikler sayfası', () {
    setUpAll(loadAppFont);
    final now = DateTime(2026, 10, 14, 10, 0);

    testWidgets('hazır İstiklal Marşı etkinliği eklenir, kapatılınca çalmaz', (tester) async {
      final (controller, _) = await pumpOkulZili(tester, now: now, page: AppPage.events);
      expect(tester.takeException(), isNull);

      await tapVisible(tester, find.text('İstiklal Marşı · Pazartesi sabah'));
      expect(find.text('Etkinlik ekle'), findsWidgets);
      expect(find.widgetWithText(TextField, '08:32'), findsOneWidget, reason: 'toplanmadan 2 dk sonra');
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();

      final monday = DateTime(2026, 10, 19);
      final bells = controller.resolver.resolve(monday).bells;
      expect(bells.where((b) => b.type == BellType.special).single.time, ClockTime.parse('08:32'));
      expect(controller.resolver.resolve(DateTime(2026, 10, 20)).bells.any((b) => b.type == BellType.special), isFalse);

      // Anahtarı kapat (10 Kasım zaten kapalı; açık olan tek anahtar bu).
      await tapVisible(tester, find.byWidgetPredicate((w) => w is Switch && w.value));
      expect(controller.resolver.resolve(monday).bells.any((b) => b.type == BellType.special), isFalse);
    });

    testWidgets('gün seçilmeden kaydedilmez', (tester) async {
      final (controller, _) = await pumpOkulZili(tester, now: now, page: AppPage.events);
      await tapVisible(tester, find.text('Etkinlik ekle'));
      await tester.enterText(find.widgetWithText(TextField, 'Etkinliğin adı'), 'Öğle anonsu');
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();
      expect(find.text('En az bir gün seçin'), findsOneWidget);

      await tester.tap(find.text('Çar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();
      final saved = controller.config.specialEvents.singleWhere((e) => e.name == 'Öğle anonsu');
      expect(saved.weekdays, {DateTime.wednesday});
    });

    testWidgets('10 Kasım hazır etkinliği mevcut kaydı düzenler', (tester) async {
      final (controller, _) = await pumpOkulZili(tester, now: now, page: AppPage.events);
      await tapVisible(tester, find.text('10 Kasım saygı duruşu').first);
      expect(find.text('Etkinliği düzenle'), findsOneWidget);
      expect(find.text('60 saniye boyunca tekrarla'), findsOneWidget);
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();
      expect(controller.config.specialEvents.where((e) => e.id == '10-kasim'), hasLength(1));
    });
  });
}
