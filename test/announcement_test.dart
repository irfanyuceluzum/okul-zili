import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okul_zili/app_controller.dart';
import 'package:okul_zili/core/clock_time.dart';
import 'package:okul_zili/core/scheduler/bell_log.dart';
import 'package:okul_zili/data/config_repository.dart';
import 'package:okul_zili/data/default_config.dart';
import 'package:okul_zili/data/models/app_config.dart';
import 'package:okul_zili/data/models/calendar.dart';
import 'package:okul_zili/data/models/spoken_announcement.dart';
import 'package:okul_zili/ui/navigation.dart';

import 'support/app_harness.dart';

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('okul_zili_anons'));
  tearDown(() {
    try {
      tmp.deleteSync(recursive: true);
    } on FileSystemException catch (_) {}
  });

  var clock = DateTime(2026, 10, 19, 10, 0);
  late RecordingPlayer player;
  late FakeSpeech speech;
  late FakeRecorder recorder;

  AppController makeController({AppConfig? config}) {
    player = RecordingPlayer();
    speech = FakeSpeech();
    recorder = FakeRecorder();
    return AppController(
      config: config ?? createDefaultConfig(),
      repository: ConfigRepository(File('${tmp.path}/ayar/config.json')..parent.createSync(recursive: true)),
      player: player,
      now: () => clock,
      passwordHasher: const FastPasswordHasher(),
      speech: speech,
      recorder: recorder,
    );
  }

  File fakeAudio(String name) => File('${tmp.path}/$name')..writeAsBytesSync([0, 1, 2, 3]);

  group('Anons ekleme', () {
    test('ses dosyası uygulama klasörüne kopyalanır, diskte göreli yazılır', () async {
      final c = makeController();
      final a = (await c.addAnnouncementFromFile(fakeAudio('toplanti.mp3').path, name: 'Toplantı'))!;
      expect(a.source, AnnouncementSource.file);
      expect(a.path, contains('${Platform.pathSeparator}sesler${Platform.pathSeparator}anons-'));
      expect(File(a.path!).existsSync(), isTrue);
      expect(a.chime, isTrue);

      final json = jsonDecode(File('${tmp.path}/ayar/config.json').readAsStringSync()) as Map<String, dynamic>;
      final saved = (json['spokenAnnouncements'] as List).single as Map<String, dynamic>;
      expect(saved['path'], startsWith('sesler/anons-'));
      final reloaded = (await c.repository.load()).spokenAnnouncements.single;
      expect(reloaded.path, a.path);
    });

    test('mikrofon kaydı anons olur, geçici dosya kalmaz', () async {
      final c = makeController();
      final path = c.newRecordingPath();
      await recorder.start(path);
      final recorded = (await recorder.stop())!;
      final a = (await c.addAnnouncementFromRecording(recorded, name: 'Kayıt', chime: false))!;
      expect(a.source, AnnouncementSource.recording);
      expect(File(recorded).existsSync(), isFalse);
      expect(File(a.path!).existsSync(), isTrue);
      expect(a.path, endsWith('.wav'));
    });

    test('yazıdan okuma ve JSON; içeriği eksik anons atlanır', () async {
      final c = makeController();
      await c.addSpeechAnnouncement(name: 'Duyuru', text: 'Öğretmenler odaya', chime: false);
      final json = c.config.toJson();
      expect(AppConfig.fromJson(json).spokenAnnouncements.single.text, 'Öğretmenler odaya');

      (json['spokenAnnouncements'] as List).add({'id': 'x', 'name': 'Boş', 'source': 'speech', 'text': '  '});
      final warnings = <String>[];
      final parsed = AppConfig.fromJson(json, warnings: warnings);
      expect(parsed.spokenAnnouncements, hasLength(1));
      expect(warnings.single, contains('anons'));
    });

    test('kilitliyken eklenmez, kopyalanan dosya geri silinir', () async {
      final c = makeController();
      await c.setPassword(newPassword: 'okul1234');
      c.lock();
      final a = await c.addAnnouncementFromFile(fakeAudio('x.mp3').path, name: 'X');
      expect(a, isNull);
      expect(c.config.spokenAnnouncements, isEmpty);
      final dir = Directory('${tmp.path}/ayar/sesler');
      expect(dir.listSync().where((f) => f.path.contains('anons-')), isEmpty);
    });
  });

  group('Anons yapma', () {
    test('önce ding-dong, bitince kayıt, bitince son', () async {
      final c = makeController();
      final a = (await c.addAnnouncementFromFile(fakeAudio('a.mp3').path, name: 'Toplantı'))!;
      expect(await c.playAnnouncement(a), isNull);
      expect(player.plays.single.id, 'gong');
      expect(c.announcementPlaying?.id, a.id);

      player.finish();
      await Future<void>.delayed(Duration.zero);
      expect(player.plays.last.id, 'anons-${a.id}');
      expect(c.announcementPlaying?.id, a.id);

      player.finish();
      expect(c.announcementPlaying, isNull);
      expect(c.logs.first.bell.label, 'Anons: Toplantı');
      expect(c.logs.first.outcome, BellOutcome.played);
    });

    test('yazıdan okuma: kayıtta sese çevrilir, çalınca yeniden çevrilmez', () async {
      final c = makeController();
      final a = (await c.addSpeechAnnouncement(name: 'Duyuru', text: 'Merhaba', chime: false))!;
      await Future<void>.delayed(Duration.zero);
      expect(speech.spoken, ['Merhaba']);
      final file = await c.speechFileFor(a);
      expect(file, contains('${Platform.pathSeparator}sesler${Platform.pathSeparator}okuma-${a.id}-'));

      await c.playAnnouncement(a);
      expect(speech.spoken, ['Merhaba'], reason: 'aynı metin önbellekten');
      expect(player.plays.single.id, 'anons-${a.id}');
      player.finish();
      expect(c.announcementPlaying, isNull);
    });

    test('metin değişince eski ses dosyası silinir, yenisi üretilir', () async {
      final c = makeController();
      final a = (await c.addSpeechAnnouncement(name: 'D', text: 'Eski', chime: false))!;
      final old = await c.speechFileFor(a);
      await c.updateSpokenAnnouncement(a.copyWith(text: 'Yeni'));
      await Future<void>.delayed(Duration.zero);
      expect(File(old).existsSync(), isFalse);
      expect(speech.spoken, ['Eski', 'Yeni']);
      await c.deleteSpokenAnnouncement(c.config.spokenAnnouncements.single);
      final left = Directory('${tmp.path}/ayar/sesler').listSync().where((f) => f.path.contains('okuma-'));
      expect(left, isEmpty);
    });

    test('çeviri sürerken durdurulursa sonradan çalmaz', () async {
      final c = makeController(
        config: createDefaultConfig().copyWith(spokenAnnouncements: const [
          SpokenAnnouncement(id: 'y', name: 'Yavaş', source: AnnouncementSource.speech, text: 'Bekle', chime: false),
        ]),
      );
      speech.gate = Completer<void>();
      final playing = c.playAnnouncement(c.config.spokenAnnouncements.single);
      await Future<void>.delayed(Duration.zero);
      expect(c.announcementPlaying?.id, 'y');
      await c.stopSound();
      speech.gate!.complete();
      expect(await playing, isNull);
      expect(player.plays, isEmpty);
      expect(c.announcementPlaying, isNull);
    });

    test('yazı sese çevrilemezse anons yapılmaz, açıklama döner', () async {
      final c = makeController(
        config: createDefaultConfig().copyWith(spokenAnnouncements: const [
          SpokenAnnouncement(id: 'h', name: 'Hatalı', source: AnnouncementSource.speech, text: 'X', chime: false),
        ]),
      );
      speech.failWith = Exception('ses yok');
      expect(await c.playAnnouncement(c.config.spokenAnnouncements.single), contains('ses yok'));
      expect(player.plays, isEmpty);
      expect(c.announcementPlaying, isNull);
      expect(c.logs.first.outcome, BellOutcome.failed);
    });

    test('dosyası kaybolmuşsa anons yapılmaz, yerine zil de çalmaz', () async {
      final c = makeController();
      final a = (await c.addAnnouncementFromFile(fakeAudio('a.mp3').path, name: 'Kayıp'))!;
      File(a.path!).deleteSync();
      expect(await c.playAnnouncement(a), contains('bulunamadı'));
      expect(player.plays, isEmpty);
      expect(c.announcementPlaying, isNull);
    });

    test('anons sürerken zil bekler, ses dinletme ve elle zil engelli', () async {
      final c = makeController();
      final day = c.resolver.resolve(DateTime(2026, 10, 19));
      final bell = day.bells.first;
      final at = day.timeOf(bell);
      // Ayar değişikliği zamanlayıcının başlangıç anını o saate alır; anons zilden önce eklenir.
      clock = at.subtract(const Duration(seconds: 20));
      final a = (await c.addAnnouncementFromFile(fakeAudio('a.mp3').path, name: 'Uzun', chime: false))!;
      await c.playAnnouncement(a);
      clock = at.add(const Duration(seconds: 5));
      expect(await c.debugTick(), const Duration(seconds: 1));
      expect(await c.previewSound(c.config.soundById('zil')!), contains('Anons'));
      await c.ringNow();
      expect(player.plays, hasLength(1));

      clock = at.add(const Duration(seconds: 30));
      player.finish();
      await c.debugTick();
      expect(player.plays.last.id, 'zil');
      expect(c.logs.first.bell.id, bell.id);
    });

    test('duraklat / sürdür', () async {
      final c = makeController();
      final a = (await c.addAnnouncementFromFile(fakeAudio('a.mp3').path, name: 'K', chime: false))!;
      await c.playAnnouncement(a);
      await c.pauseAnnouncement();
      expect(player.pauses, 1);
      expect(c.announcementPaused, isTrue);
      await c.resumeAnnouncement();
      expect(player.resumes, 1);
      expect(c.announcementPaused, isFalse);
    });

    test('acil durum ve tören anonsu keser', () async {
      final c = makeController(config: createDefaultConfig().copyWith(ceremonySounds: {Ceremony.anthem: 'gong'}));
      final s = (await c.addSpeechAnnouncement(name: 'O', text: 'Metin', chime: false))!;
      await c.playAnnouncement(s);
      await c.startEmergency();
      expect(c.announcementPlaying, isNull);
      expect(await c.playAnnouncement(s), contains('Acil durum'));
      await c.stopSound();

      await c.playAnnouncement(s);
      await c.startCeremony(Ceremony.anthem);
      expect(c.announcementPlaying, isNull);
      expect(c.ceremonyPlaying, Ceremony.anthem);
      expect(await c.playAnnouncement(s), contains('çalarken anons yapılamaz'));
    });

    test('zamanlanmış etkinlik anonsu yapar; silinmiş anons "Hata" yazılır', () async {
      final c = makeController();
      final a = (await c.addSpeechAnnouncement(name: 'Teneffüs uyarısı', text: 'Koşmayın', chime: false))!;
      await c.saveEvent(SpecialEvent(
        id: 'uyari',
        name: 'Koridor uyarısı',
        time: const ClockTime(10, 50),
        recurrence: Recurrence.weekly,
        weekdays: {DateTime.monday},
        announcementId: a.id,
      ));
      clock = DateTime(2026, 10, 19, 10, 50, 2);
      await c.debugTick();
      expect(player.plays.last.id, 'anons-${a.id}');
      expect(c.logs.first.bell.label, 'Koridor uyarısı');
      expect(c.logs.first.outcome, BellOutcome.played);
      player.finish();

      // Etkinlik dosyadan okununca anons kimliği korunur.
      final event = (await c.repository.load()).specialEvents.firstWhere((e) => e.id == 'uyari');
      expect(event.announcementId, a.id);
    });

    test('aynı dakikadaki zil anonsu kesmez, anons bitince çalar', () async {
      final c = makeController();
      final day = c.resolver.resolve(DateTime(2026, 10, 19));
      final bell = day.bells.first;
      final at = day.timeOf(bell);
      clock = at.subtract(const Duration(minutes: 5));
      final a = (await c.addSpeechAnnouncement(name: 'Sabah', text: 'Günaydın', chime: false))!;
      await c.speechFileFor(a);
      await c.saveEvent(SpecialEvent(
        id: 'sabah',
        name: 'Sabah anonsu',
        time: bell.time,
        recurrence: Recurrence.weekly,
        weekdays: {DateTime.monday},
        announcementId: a.id,
      ));
      clock = at.add(const Duration(seconds: 2));
      await c.debugTick();
      expect(player.plays.last.id, 'anons-${a.id}', reason: 'anons zil tarafından kesilmedi');
      expect(c.announcementPlaying?.id, a.id);

      player.finish();
      await c.debugTick();
      expect(c.logs.where((l) => l.bell.id == bell.id && l.outcome == BellOutcome.played), hasLength(1));
      expect(c.logs.where((l) => l.bell.label == 'Sabah anonsu' && l.outcome == BellOutcome.played), hasLength(1));
    });

    test('ding-dong çalınamazsa anons yine yapılır', () async {
      final c = makeController();
      final a = (await c.addAnnouncementFromFile(fakeAudio('a.mp3').path, name: 'D'))!;
      player.failFor = 'gong';
      expect(await c.playAnnouncement(a), isNull);
      expect(player.plays.single.id, 'anons-${a.id}');
    });

    test('sese çevrilirken duraklatılırsa bekler, sürdürünce çalar', () async {
      final c = makeController(
        config: createDefaultConfig().copyWith(spokenAnnouncements: const [
          SpokenAnnouncement(id: 'p', name: 'Uzun metin', source: AnnouncementSource.speech, text: 'Metin', chime: false),
        ]),
      );
      speech.gate = Completer<void>();
      final playing = c.playAnnouncement(c.config.spokenAnnouncements.single);
      await Future<void>.delayed(Duration.zero);
      await c.pauseAnnouncement();
      speech.gate!.complete();
      await playing;
      expect(player.plays, isEmpty);
      expect(c.announcementPaused, isTrue);
      await c.resumeAnnouncement();
      expect(player.plays.single.id, 'anons-p');
      expect(c.announcementPaused, isFalse);
    });

    test('anons silinince dosyası silinir, onu yapan etkinlik kapanır', () async {
      final c = makeController();
      final a = (await c.addAnnouncementFromFile(fakeAudio('a.mp3').path, name: 'Sil'))!;
      await c.saveEvent(SpecialEvent(
        id: 'e1',
        name: 'Etkinlik',
        time: const ClockTime(11, 0),
        recurrence: Recurrence.weekly,
        weekdays: {1},
        announcementId: a.id,
      ));
      expect(c.announcementUsages(a.id), ['Etkinlik']);
      await c.deleteSpokenAnnouncement(a);
      expect(c.config.spokenAnnouncements, isEmpty);
      expect(File(a.path!).existsSync(), isFalse);
      final ev = c.config.specialEvents.firstWhere((e) => e.id == 'e1');
      expect(ev.enabled, isFalse);
      expect(ev.announcementId, isNull);
    });
  });

  testWidgets('ding-dong bitişi gelmezse anons en geç 8 sn sonra başlar', (tester) async {
    final c = makeController(
      config: createDefaultConfig().copyWith(spokenAnnouncements: const [
        SpokenAnnouncement(id: 'o', name: 'Okuma', source: AnnouncementSource.speech, text: 'Merhaba'),
      ]),
    );
    addTearDown(c.dispose);
    await c.playAnnouncement(c.config.spokenAnnouncements.single);
    expect(player.plays.single.id, 'gong');
    await tester.pump(AppController.chimeMax + const Duration(milliseconds: 10));
    expect(player.plays.last.id, 'anons-o');
    player.finish();
    expect(c.announcementPlaying, isNull);
  });

  group('Arayüz', () {
    setUpAll(loadAppFont);
    final now = DateTime(2026, 10, 19, 10, 0);

    Future<void> settle(WidgetTester tester, bool Function() until) async {
      for (var i = 0; i < 100 && !until(); i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('Yazıdan okut: ekle, satırda görünür, Türkçe ses uyarısı', (tester) async {
      final (c, _) = await pumpOkulZili(tester, now: now, page: AppPage.announcements, speech: FakeSpeech(turkish: false));
      await tapVisible(tester, find.text('Yazıdan okut'));
      await tester.enterText(find.widgetWithText(TextField, 'Anonsun adı'), 'Toplantı');
      await tester.enterText(find.widgetWithText(TextField, 'Okunacak metin'), 'Toplantı saat on beşte');
      await tester.pump();
      expect(find.textContaining('Türkçe konuşma sesi yüklü değil'), findsOneWidget);
      await tester.tap(find.text('Kaydet'));
      await settle(tester, () => find.text('Yazıdan okunan anons').evaluate().isEmpty);
      expect(c.config.spokenAnnouncements.single.text, 'Toplantı saat on beşte');
      expect(find.text('Yazıdan okuma'), findsOneWidget);
      expect(find.textContaining('Türkçe konuşma sesi yüklü değil'), findsOneWidget);
    });

    testWidgets('Mikrofondan kaydet: başlat, durdur, kaydet', (tester) async {
      final (c, _) = await pumpOkulZili(tester, now: now, page: AppPage.announcements);
      await tapVisible(tester, find.text('Mikrofondan kaydet'));
      await tester.tap(find.text('Kaydı başlat'));
      await settle(tester, () => find.text('Kaydı durdur').evaluate().isNotEmpty);
      await tester.tap(find.text('Kaydı durdur'));
      await settle(tester, () => find.text('Dinle').evaluate().isNotEmpty);
      await tester.enterText(find.widgetWithText(TextField, 'Anonsun adı'), 'Sesli duyuru');
      await tester.tap(find.text('Kaydet'));
      await settle(tester, () => find.text('Mikrofondan anons kaydet').evaluate().isEmpty);
      expect(c.config.spokenAnnouncements.single.source, AnnouncementSource.recording);
      expect(find.text('Mikrofon kaydı'), findsOneWidget);
    });

    testWidgets('mikrofon izni yoksa açıklama gösterilir', (tester) async {
      await pumpOkulZili(tester, now: now, page: AppPage.announcements, recorder: FakeRecorder(allowed: false));
      await tapVisible(tester, find.text('Mikrofondan kaydet'));
      await tester.tap(find.text('Kaydı başlat'));
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('Mikrofona erişilemedi'), findsOneWidget);
    });

    testWidgets('ana ekran Anons menüsü: yapılırken bant ve Anonsu durdur', (tester) async {
      final config = createDefaultConfig().copyWith(spokenAnnouncements: const [
        SpokenAnnouncement(id: 'o', name: 'Koridor', source: AnnouncementSource.speech, text: 'Koşmayın', chime: false),
      ]);
      final player = RecordingPlayer();
      final (c, _) = await pumpOkulZili(tester, now: now, config: config, player: player);
      await tapVisible(tester, find.text('Anons'));
      await tester.tap(find.text('Koridor'));
      await settle(tester, () => player.plays.isNotEmpty);
      expect(player.plays.single.id, 'anons-o');
      expect(find.textContaining('Anons: Koridor. Ziller anons bitince çalar.'), findsOneWidget);
      await tapVisible(tester, find.text('Anonsu durdur'));
      expect(c.announcementPlaying, isNull);
      expect(find.text('Anons'), findsOneWidget);
    });

    testWidgets('anons yoksa menü yol gösterir', (tester) async {
      await pumpOkulZili(tester, now: now);
      await tapVisible(tester, find.text('Anons'));
      expect(find.textContaining('Anonslar sayfasından ekleyin'), findsOneWidget);
    });
  });
}
