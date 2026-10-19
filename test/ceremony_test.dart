import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okul_zili/app_controller.dart';
import 'package:okul_zili/core/scheduler/bell_log.dart';
import 'package:okul_zili/data/config_repository.dart';
import 'package:okul_zili/data/default_config.dart';
import 'package:okul_zili/data/models/app_config.dart';
import 'package:okul_zili/ui/navigation.dart';

import 'support/app_harness.dart';

/// Kullanıcının MEB sitesinden indirdiği paketteki dosya adları.
const _packNames = [
  '1dakikaliksaygidurusuveistiklalmarsi.mp3',
  '17153032_zilsesi2.mp3',
  '17153045_zilsesi3.mp3',
  '17153101_zilsesi4.mp3',
  '17153131_zilsesi6.mp3',
  '17153218_istiklalmarsi.mp3',
  'zilsesi1.mp3',
];

/// Sahte ses paketi klasörü (içerikler önemsiz, çalar sahte). Ses olmayan bir dosya da içerir.
Directory _fakePack(Directory root) {
  final dir = Directory('${root.path}/paket')..createSync();
  for (final name in _packNames) {
    File('${dir.path}/$name').writeAsBytesSync([0, 1, 2, 3]);
  }
  File('${dir.path}/okubeni.txt').writeAsStringSync('ses değil');
  return dir;
}

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('okul_zili_toren'));
  tearDown(() {
    try {
      tmp.deleteSync(recursive: true);
    } on FileSystemException catch (_) {}
  });

  var clock = DateTime(2026, 10, 19, 8, 0);
  AppController makeController(RecordingPlayer player, {AppConfig? config}) => AppController(
        config: config ?? createDefaultConfig(),
        repository: ConfigRepository(File('${tmp.path}/ayar/config.json')..parent.createSync(recursive: true)),
        player: player,
        now: () => clock,
        passwordHasher: const FastPasswordHasher(),
      );

  group('Dosya adından tanıma', () {
    test('kullanıcının paketindeki adlar', () {
      String nameOf(String f) => AppController.recognizeSoundName(f).name;
      Ceremony? kindOf(String f) => AppController.recognizeSoundName(f).ceremony;
      expect(nameOf('1dakikaliksaygidurusuveistiklalmarsi.mp3'), 'Saygı duruşu ve İstiklal Marşı');
      expect(kindOf('1dakikaliksaygidurusuveistiklalmarsi.mp3'), Ceremony.remembrance);
      expect(nameOf('17153218_istiklalmarsi.mp3'), 'İstiklal Marşı');
      expect(kindOf('17153218_istiklalmarsi.mp3'), Ceremony.anthem);
      expect(nameOf('17153032_zilsesi2.mp3'), 'Zil sesi 2');
      expect(kindOf('17153032_zilsesi2.mp3'), isNull);
      expect(nameOf('zilsesi1.mp3'), 'Zil sesi 1');
    });

    test('Türkçe büyük harf, boşluk ve bilinmeyen adlar', () {
      expect(AppController.recognizeSoundName('İSTİKLAL MARŞI.mp3').ceremony, Ceremony.anthem);
      expect(AppController.recognizeSoundName('Saygı Duruşu.wav').ceremony, Ceremony.remembrance);
      expect(AppController.recognizeSoundName('Zil Sesi 10.wav').name, 'Zil sesi 10');
      expect(AppController.recognizeSoundName('20240101_okul-zili.mp3').name, 'okul-zili');
    });
  });

  group('Ses paketi yükleme', () {
    test('sesler adlandırılır, törenler ve 10 Kasım atanır, zil türleri değişmez', () async {
      final c = makeController(RecordingPlayer());
      final typesBefore = Map.of(c.config.soundForType);
      final result = await c.importSoundPack(_fakePack(tmp).path);

      expect(result.error, isNull);
      expect(result.added, [
        'İstiklal Marşı',
        'Saygı duruşu ve İstiklal Marşı',
        'Zil sesi 1',
        'Zil sesi 2',
        'Zil sesi 3',
        'Zil sesi 4',
        'Zil sesi 6',
      ]);
      expect(result.ceremonies, {Ceremony.anthem, Ceremony.remembrance});
      expect(result.remembranceEventUpdated, isTrue);

      final config = c.config;
      for (final s in config.sounds.where((s) => !s.isAsset)) {
        expect(File(s.path).existsSync(), isTrue, reason: s.name);
        expect(s.path, contains('${Platform.pathSeparator}sesler${Platform.pathSeparator}'));
      }
      expect(config.ceremonySound(Ceremony.anthem)!.name, 'İstiklal Marşı');
      expect(config.ceremonySound(Ceremony.remembrance)!.name, 'Saygı duruşu ve İstiklal Marşı');
      final kasim = config.specialEvents.firstWhere((e) => e.id == '10-kasim');
      expect(kasim.soundId, config.ceremonySounds[Ceremony.remembrance]);
      expect(kasim.loopSeconds, isNull, reason: 'kayıt bir kez, tam çalmalı');
      expect(kasim.enabled, isFalse, reason: 'açık/kapalı durumu okulun kararı');
      expect(config.soundForType, typesBefore);
      expect(c.soundUsages(config.ceremonySounds[Ceremony.anthem]!), ['Tören: İstiklal Marşı']);

      // Kayıt diske de yazılır ve geri okunur.
      final reloaded = (await c.repository.load()).ceremonySounds;
      expect(reloaded, config.ceremonySounds);
    });

    test('ikinci yükleme kopya oluşturmaz; dosyası silinen ses aynı kimlikle yenilenir', () async {
      final c = makeController(RecordingPlayer());
      final pack = _fakePack(tmp);
      await c.importSoundPack(pack.path);
      final count = c.config.sounds.length;

      final again = await c.importSoundPack(pack.path);
      expect(again.added, isEmpty);
      expect(again.kept, hasLength(7));
      expect(c.config.sounds, hasLength(count));

      final anthem = c.config.ceremonySound(Ceremony.anthem)!;
      File(anthem.path).deleteSync();
      final repaired = await c.importSoundPack(pack.path);
      expect(repaired.added, ['İstiklal Marşı']);
      expect(c.config.sounds, hasLength(count));
      expect(c.config.ceremonySound(Ceremony.anthem)!.id, anthem.id);
      expect(File(c.config.ceremonySound(Ceremony.anthem)!.path).existsSync(), isTrue);
    });

    test('okulun 10 Kasım için seçtiği başka ses değiştirilmez', () async {
      final c = makeController(RecordingPlayer());
      final mine = await c.importSound((File('${tmp.path}/bizim_siren.mp3')..writeAsBytesSync([1])).path);
      final kasim = c.config.specialEvents.firstWhere((e) => e.id == '10-kasim');
      await c.saveEvent(kasim.copyWith(soundId: () => mine.id));

      final result = await c.importSoundPack(_fakePack(tmp).path);
      expect(result.remembranceEventUpdated, isFalse);
      expect(c.config.specialEvents.firstWhere((e) => e.id == '10-kasim').soundId, mine.id);
    });

    test('ses dosyası olmayan klasör hata verir, ayar değişmez', () async {
      final c = makeController(RecordingPlayer());
      final empty = Directory('${tmp.path}/bos')..createSync();
      File('${empty.path}/not.txt').writeAsStringSync('x');
      final before = c.config.sounds.length;
      final result = await c.importSoundPack(empty.path);
      expect(result.error, contains('ses dosyası'));
      expect(c.config.sounds, hasLength(before));
    });

    test('kilitliyken reddedilir, hiçbir şey kopyalanmaz', () async {
      final c = makeController(RecordingPlayer());
      await c.setPassword(newPassword: 'okul1234');
      c.lock();
      final before = c.config.sounds.length;
      final result = await c.importSoundPack(_fakePack(tmp).path);
      expect(result.error, AppController.lockedMessage);
      expect(c.config.sounds, hasLength(before));
      expect(c.config.ceremonySounds, isEmpty);
      expect(Directory('${tmp.path}/ayar/sesler').existsSync(), isFalse);
    });

    test('ses silinince tören ataması da kalkar', () async {
      final c = makeController(RecordingPlayer());
      await c.importSoundPack(_fakePack(tmp).path);
      await c.deleteSound(c.config.ceremonySound(Ceremony.anthem)!);
      expect(c.config.ceremonySounds.containsKey(Ceremony.anthem), isFalse);
      expect(c.config.ceremonySounds.containsKey(Ceremony.remembrance), isTrue);
    });
  });

  group('Tören çalma', () {
    test('kayıt yüklenmemişse çalmaz, yerine zil de çalmaz', () async {
      final player = RecordingPlayer();
      final c = makeController(player);
      final error = await c.startCeremony(Ceremony.anthem);
      expect(error, contains('yüklenmemiş'));
      expect(player.plays, isEmpty);
      expect(c.ceremonyPlaying, isNull);
    });

    test('dosyası kaybolmuşsa klasik zil çalınmaz, açıklama döner', () async {
      final player = RecordingPlayer();
      final c = makeController(player);
      await c.importSoundPack(_fakePack(tmp).path);
      File(c.config.ceremonySound(Ceremony.anthem)!.path).deleteSync();
      final error = await c.startCeremony(Ceremony.anthem);
      expect(error, contains('bulunamadı'));
      expect(player.plays, isEmpty);
    });

    test('marş çalarken zil bekler, marş bitince tolerans içinde çalar', () async {
      final player = RecordingPlayer();
      final c = makeController(player);
      await c.importSoundPack(_fakePack(tmp).path);
      final day = c.resolver.resolve(DateTime(2026, 10, 19));
      final bell = day.bells.first;
      final at = day.timeOf(bell);

      clock = at.subtract(const Duration(seconds: 30));
      expect(await c.startCeremony(Ceremony.anthem), isNull);
      final anthemId = c.config.ceremonySounds[Ceremony.anthem]!;
      expect(player.plays.single, (id: anthemId, loop: false));
      expect(c.ceremonyPlaying, Ceremony.anthem);
      expect(c.logs.first.bell.label, 'İstiklal Marşı');
      expect(c.logs.first.outcome, BellOutcome.played);

      // Zil saati geldi ama marş sürüyor: çalınmaz, kayda da geçmez.
      clock = at.add(const Duration(seconds: 5));
      expect(await c.debugTick(), const Duration(seconds: 1));
      expect(player.plays, hasLength(1));

      // Marş bitti: zil geç de olsa çalar.
      clock = at.add(const Duration(seconds: 40));
      player.finish();
      expect(c.ceremonyPlaying, isNull);
      await c.debugTick();
      expect(player.plays, hasLength(2));
      expect(c.logs.first.bell.id, bell.id);
      expect(c.logs.first.outcome, BellOutcome.played);
    });

    test('marş toleranstan uzun sürerse zil "kaçırıldı" yazılır', () async {
      final player = RecordingPlayer();
      final c = makeController(player);
      await c.importSoundPack(_fakePack(tmp).path);
      final day = c.resolver.resolve(DateTime(2026, 10, 19));
      final at = day.timeOf(day.bells.first);

      clock = at.subtract(const Duration(seconds: 10));
      await c.startCeremony(Ceremony.remembrance);
      clock = at.add(const Duration(seconds: 90));
      await c.debugTick();
      player.finish();
      await c.debugTick();
      expect(player.plays, hasLength(1));
      expect(c.logs.first.outcome, BellOutcome.missed);
    });

    test('tören çalarken ses dinletme ve elle zil engelli', () async {
      final player = RecordingPlayer();
      final c = makeController(player);
      await c.importSoundPack(_fakePack(tmp).path);
      await c.startCeremony(Ceremony.anthem);
      expect(player.plays, hasLength(1));

      final note = await c.previewSound(c.config.soundById('zil')!);
      expect(note, 'İstiklal Marşı çalarken ses dinletilemez');
      await c.ringNow();
      expect(player.plays, hasLength(1));
      expect(c.ceremonyPlaying, Ceremony.anthem);

      player.finish();
      await c.ringNow();
      expect(player.plays, hasLength(2));
    });

    test('Durdur ve acil durum töreni bitirir', () async {
      final player = RecordingPlayer();
      final c = makeController(player);
      await c.importSoundPack(_fakePack(tmp).path);
      await c.startCeremony(Ceremony.anthem);
      await c.stopSound();
      expect(c.ceremonyPlaying, isNull);

      await c.startCeremony(Ceremony.anthem);
      await c.startEmergency();
      expect(c.ceremonyPlaying, isNull);
      expect(c.emergencyActive, isTrue);
      expect(await c.startCeremony(Ceremony.anthem), contains('Acil durum'));
      await c.stopSound();
    });
  });

  testWidgets('bitiş bildirimi gelmezse ziller en çok 5 dk bekler', (tester) async {
    final player = RecordingPlayer();
    // Yerleşik ses ile: dosya G/Ç'si gerekmez.
    final c = makeController(player, config: createDefaultConfig().copyWith(ceremonySounds: {Ceremony.anthem: 'zil'}));
    addTearDown(c.dispose);
    await c.startCeremony(Ceremony.anthem);
    expect(c.ceremonyPlaying, Ceremony.anthem);
    await tester.pump(AppController.maxCeremony - const Duration(seconds: 1));
    expect(c.ceremonyPlaying, Ceremony.anthem);
    await tester.pump(const Duration(seconds: 2));
    expect(c.ceremonyPlaying, isNull);
  });

  group('Arayüz', () {
    setUpAll(loadAppFont);
    final now = DateTime(2026, 10, 19, 10, 0);

    testWidgets('Tören menüsü: yüklenmemişse uyarı', (tester) async {
      await pumpOkulZili(tester, now: now);
      await tapVisible(tester, find.text('Tören'));
      await tester.tap(find.text('İstiklal Marşı (yüklenmedi)'));
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('Ses paketi yükle'), findsOneWidget);
    });

    testWidgets('Tören menüsü: çalarken bant ve Durdur', (tester) async {
      final player = RecordingPlayer();
      final config = createDefaultConfig().copyWith(ceremonySounds: {Ceremony.anthem: 'gong'});
      final (c, _) = await pumpOkulZili(tester, now: now, config: config, player: player);
      await tapVisible(tester, find.text('Tören'));
      await tester.tap(find.text('İstiklal Marşı'));
      await tester.pump();
      await tester.pump();
      expect(c.ceremonyPlaying, Ceremony.anthem);
      expect(find.textContaining('İstiklal Marşı çalıyor'), findsOneWidget);
      final ringNow = tester.widget<ButtonStyleButton>(
          find.ancestor(of: find.text('Şimdi zil çal'), matching: find.bySubtype<ButtonStyleButton>()));
      expect(ringNow.onPressed, isNull);

      expect(find.text('Töreni durdur'), findsOneWidget);
      await tapVisible(tester, find.text('Töreni durdur'));
      expect(c.ceremonyPlaying, isNull);
      expect(find.text('Tören'), findsOneWidget);
      expect(find.textContaining('çalıyor'), findsNothing);
    });

    testWidgets('Zil sesleri → Ses paketi yükle özet gösterir', (tester) async {
      final pack = _fakePack(tmp);
      final (c, _) = await pumpOkulZili(tester, now: now, page: AppPage.sounds, pickSoundFolder: () async => pack.path);
      await tester.ensureVisible(find.text('Ses paketi yükle…'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ses paketi yükle…'));
      for (var i = 0; i < 100 && find.text('Ses paketi yüklendi').evaluate().isEmpty; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.text('Ses paketi yüklendi'), findsOneWidget);
      expect(find.textContaining('Tören düğmesinden çalınabilir'), findsOneWidget);
      expect(find.textContaining('10 Kasım saygı duruşu etkinliği'), findsOneWidget);
      expect(c.config.ceremonySounds, hasLength(2));
      await tester.tap(find.text('Tamam'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Tören kayıtları'), findsOneWidget);
    });
  });

  test('ceremonySounds JSON: eksik ses kimliği atlanır, eski dosyada alan yok', () {
    final config = createDefaultConfig().copyWith(ceremonySounds: {Ceremony.anthem: 'gong'});
    final json = config.toJson();
    expect(json['ceremonySounds'], {'anthem': 'gong'});
    expect(AppConfig.fromJson(json).ceremonySounds, {Ceremony.anthem: 'gong'});
    json['ceremonySounds'] = {'anthem': 'yok', 'bilinmeyen': 'gong'};
    expect(AppConfig.fromJson(json).ceremonySounds, isEmpty);
    json.remove('ceremonySounds');
    expect(AppConfig.fromJson(json).ceremonySounds, isEmpty);
    expect(createDefaultConfig().toJson().containsKey('ceremonySounds'), isFalse);
  });
}
