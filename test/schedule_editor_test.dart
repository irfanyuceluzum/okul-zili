import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okul_zili/app_controller.dart';
import 'package:okul_zili/core/clock_time.dart';
import 'package:okul_zili/core/scheduler/bell_log.dart';
import 'package:okul_zili/core/scheduler/bell_scheduler.dart';
import 'package:okul_zili/core/scheduler/day_schedule.dart';
import 'package:okul_zili/data/config_repository.dart';
import 'package:okul_zili/data/default_config.dart';
import 'package:okul_zili/data/models/app_config.dart';
import 'package:okul_zili/data/models/calendar.dart';
import 'package:okul_zili/data/models/schedule_template.dart';
import 'package:okul_zili/data/schedule_draft.dart';
import 'package:okul_zili/main.dart';
import 'package:okul_zili/platform/bell_player.dart';
import 'package:okul_zili/ui/navigation.dart';
import 'package:okul_zili/ui/time_field.dart';

class _SilentPlayer implements BellPlayer {
  @override
  Future<void> play(BellSound sound, {required int volumePercent, bool loop = false}) async {}

  @override
  Future<void> stop() async {}
}

ClockTime _t(String s) => ClockTime.parse(s);

void main() {
  group('Hızlı doldur hesabı', () {
    test('okulun düzenine benzer program', () {
      final lessons = ScheduleTemplate.generateLessons(
        firstStart: _t('08:40'),
        count: 6,
        lessonMinutes: 40,
        breakMinutes: 15,
        lunchAfter: 4,
        lunchMinutes: 30,
      );
      expect(lessons.map((l) => '$l'), [
        '08:40–09:20', '09:35–10:15', '10:30–11:10', '11:25–12:05', '12:35–13:15', '13:30–14:10',
      ]);
    });

    test('gece yarısını geçerse hata verir', () {
      expect(
        () => ScheduleTemplate.generateLessons(
            firstStart: _t('22:00'), count: 4, lessonMinutes: 40, breakMinutes: 10),
        throwsRangeError,
      );
    });
  });

  group('TimeField.parse', () {
    test('farklı yazımlar', () {
      expect(TimeField.parse('0840'), _t('08:40'));
      expect(TimeField.parse('840'), _t('08:40'));
      expect(TimeField.parse('08.40'), _t('08:40'));
      expect(TimeField.parse('8:40'), _t('08:40'));
      expect(TimeField.parse('13'), _t('13:00'));
      expect(TimeField.parse('2500'), isNull);
      expect(TimeField.parse('08:60'), isNull);
      expect(TimeField.parse(''), isNull);
    });
  });

  group('Taslak doğrulama', () {
    test('aynı adlı şablonlar ve silinen şablonu kullanan özel gün', () {
      final config = createDefaultConfig();
      final draft = ScheduleDraft.fromConfig(config)
        ..add(normalDayTemplate.copyWith(id: 'kopya'));
      expect(draft.validate(const []).single, contains('birden fazla şablon'));

      draft.remove('kopya');
      draft.remove('normal');
      final errors = draft.validate([DateOverride(date: DateTime(2026, 10, 28), templateId: 'normal')]);
      expect(errors, contains('En az bir şablon olmalı.'));
      expect(errors.any((e) => e.contains('28 Ekim')), isTrue);
    });

    test('şablon silinince o günler "zil çalmasın" olur', () {
      final draft = ScheduleDraft.fromConfig(createDefaultConfig())
        ..add(normalDayTemplate.copyWith(id: 'yeni', name: 'Yeni'));
      draft.remove('normal');
      expect([for (var d = 1; d <= 5; d++) draft.weekPlan[d]], everyElement(isNull));
      expect(draft.selectedId, 'yeni');
    });
  });

  test('program değişince geçmişe eklenen zil "kaçırıldı" yazılmaz', () async {
    var config = createDefaultConfig();
    var now = DateTime(2026, 10, 14, 8, 0);
    final logs = <BellLogEntry>[];
    final scheduler = BellScheduler(
      resolveDay: (d) => ScheduleResolver(config).resolve(d),
      ring: (_) async => null,
      onLog: logs.add,
      now: () => now,
    );
    now = DateTime(2026, 10, 14, 10, 0);
    // Saat 10:00'da programa 09:00'da başlayan bir özel etkinlik ekleniyor.
    config = config.copyWith(specialEvents: [
      SpecialEvent(id: 'x', name: 'Anons', time: _t('09:00'), recurrence: Recurrence.weekly, weekdays: {3}),
    ]);
    scheduler.scheduleChanged();
    await scheduler.tick();
    expect(logs.where((l) => l.outcome == BellOutcome.missed), isEmpty);
  });

  group('Düzenleme ekranı', () {
    setUpAll(() async {
      final loader = FontLoader('IBM Plex Sans');
      for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
        final bytes = File('assets/fonts/IBMPlexSans-$weight.ttf').readAsBytesSync();
        loader.addFont(Future.value(ByteData.sublistView(bytes)));
      }
      await loader.load();
    });

    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('okul_zili_test'));
    tearDown(() {
      try {
        tmp.deleteSync(recursive: true);
      } on FileSystemException catch (_) {}
    });

    Future<(AppController, ValueNotifier<AppPage>)> pumpEditor(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1400, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final controller = AppController(
        config: createDefaultConfig(),
        repository: ConfigRepository(File('${tmp.path}/config.json')),
        player: _SilentPlayer(),
        now: () => DateTime(2026, 10, 14, 10, 0),
      );
      final navigation = ValueNotifier(AppPage.program);
      await tester.pumpWidget(OkulZiliApp(
        controller: controller,
        navigation: navigation,
        windowControls: const NoopWindowControls(),
      ));
      await tester.pumpAndSettle();
      return (controller, navigation);
    }

    Finder field(String text) => find.widgetWithText(TextField, text);

    Future<void> tapVisible(WidgetTester tester, Finder finder) async {
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    testWidgets('ders saati değiştirilip kaydedilir', (tester) async {
      final (controller, _) = await pumpEditor(tester);
      expect(tester.takeException(), isNull);

      await tester.enterText(field('10:15'), '1020');
      await tester.pumpAndSettle();
      expect(find.text('Kaydedilmemiş değişiklikler var. Kaydedene kadar ziller eski programla çalar.'), findsOneWidget);
      // Kaydetmeden önce ziller eski programla çalar.
      expect(controller.config.templates.single.lessons[1].end, _t('10:15'));

      await tapVisible(tester, find.text('Kaydet'));
      expect(controller.config.templates.single.lessons[1].end, _t('10:20'));
      expect(controller.scheduleDraft?.dirty ?? false, isFalse);
      final today = controller.resolver.resolve(DateTime(2026, 10, 14));
      expect(today.bells.map((b) => b.time), contains(_t('10:20')));
    });

    testWidgets('çakışan saatlerle kaydedilmez', (tester) async {
      final (controller, _) = await pumpEditor(tester);
      await tester.enterText(field('10:15'), '1040'); // 3. ders 10:35'te başlıyor
      await tester.pumpAndSettle();
      expect(find.text('5 dk üst üste'), findsOneWidget);

      await tapVisible(tester, find.text('Kaydet'));
      expect(find.text('Kaydedilmedi, şunları düzeltin:'), findsOneWidget);
      expect(controller.config.templates.single.lessons[1].end, _t('10:15'));
    });

    testWidgets('hızlı doldur saatleri hesaplar', (tester) async {
      final (controller, _) = await pumpEditor(tester);
      await tapVisible(tester, find.text('Saatleri hesapla'));
      final lessons = controller.scheduleDraft!.selected!.lessons;
      // Varsayılanlar mevcut şablondan: 40 dk ders, 15 dk teneffüs, 4. dersten sonra 30 dk.
      expect(lessons.map((l) => '$l').take(3), ['08:40–09:20', '09:35–10:15', '10:30–11:10']);
      expect(lessons[4].start, _t('12:35'));
      expect(field('10:30'), findsOneWidget, reason: 'tablo da güncellenir');
    });

    testWidgets('haftalık planda cumartesiye şablon atanır', (tester) async {
      final (controller, _) = await pumpEditor(tester);
      await tapVisible(tester, find.text('Zil çalmasın').first);
      await tester.tap(find.text('Normal Gün').last);
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Kaydet'));
      expect(controller.config.weekPlan[DateTime.saturday], 'normal');
      expect(controller.resolver.resolve(DateTime(2026, 10, 17)).isSchoolDay, isTrue);
    });

    testWidgets('kopyadan yeni şablon oluşturulur, kısaltılıp kaydedilir', (tester) async {
      final (controller, _) = await pumpEditor(tester);
      await tapVisible(tester, find.text('Yeni şablon'));
      await tester.enterText(find.widgetWithText(TextField, 'Şablonun adı').last, 'Kısaltılmış Gün');
      await tester.tap(find.text('Oluştur'));
      await tester.pumpAndSettle();
      expect(find.text('Atanmadı'), findsOneWidget);

      // Son iki dersi sil.
      await tapVisible(tester, find.byTooltip('6. dersi sil'));
      await tapVisible(tester, find.byTooltip('5. dersi sil'));
      await tapVisible(tester, find.text('Kaydet'));

      final saved = controller.config.templates.singleWhere((t) => t.name == 'Kısaltılmış Gün');
      expect(saved.lessons, hasLength(4));
      expect(saved.lunchAfterLesson, isNull, reason: 'öğle arası artık son dersten sonra kalırdı');
      expect(controller.config.templates.singleWhere((t) => t.id == 'normal').lessons, hasLength(6));
    });

    testWidgets('vazgeç değişiklikleri geri alır', (tester) async {
      final (controller, _) = await pumpEditor(tester);
      await tester.enterText(field('10:15'), '1020');
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Vazgeç'));
      expect(controller.scheduleDraft?.dirty ?? false, isFalse);
      expect(field('10:15'), findsOneWidget);
    });

    testWidgets('taslak sayfa değişince kaybolmaz', (tester) async {
      final (controller, navigation) = await pumpEditor(tester);
      await tester.enterText(field('10:15'), '1020');
      await tester.pumpAndSettle();

      navigation.value = AppPage.home;
      await tester.pumpAndSettle();
      expect(find.byWidgetPredicate((w) => w is Badge && w.isLabelVisible), findsOneWidget,
          reason: 'menüde kaydedilmemiş değişiklik işareti');

      navigation.value = AppPage.program;
      await tester.pumpAndSettle();
      expect(controller.scheduleDraft!.dirty, isTrue);
      expect(field('10:20'), findsOneWidget);
    });
  });
}
