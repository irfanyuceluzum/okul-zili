import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okul_zili/app_controller.dart';
import 'package:okul_zili/core/clock_time.dart';
import 'package:okul_zili/data/config_repository.dart';
import 'package:okul_zili/data/default_config.dart';
import 'package:okul_zili/data/models/app_config.dart';
import 'package:okul_zili/data/models/notices.dart';
import 'package:okul_zili/data/models/schedule_template.dart';
import 'package:okul_zili/features/pano/pano_page.dart';
import 'package:okul_zili/ui/navigation.dart';

import 'support/app_harness.dart';

void main() {
  setUpAll(loadAppFont);

  // 2026-10-14 Çarşamba (weekday 3).
  final now = DateTime(2026, 10, 14, 10, 0);
  const marquee = ValueKey('duyuru-metni');

  /// Pano sonsuz animasyon içerdiği için pumpAndSettle kullanılamaz; sayfa doğrudan açılır.
  Future<void> pumpPano(WidgetTester tester, AppConfig config) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final tmp = Directory.systemTemp.createTempSync('okul_zili_test');
    final controller = AppController(
      config: config,
      repository: ConfigRepository(File('${tmp.path}/config.json')),
      player: SilentPlayer(),
      now: () => now,
    );
    addTearDown(() {
      controller.dispose();
      try {
        tmp.deleteSync(recursive: true);
      } on FileSystemException catch (_) {}
    });
    await tester.pumpWidget(MaterialApp(
      home: PanoPage(controller: controller, windowControls: const NoopWindowControls(), onExit: () {}),
    ));
    await tester.pump();
  }

  AppConfig base() => createDefaultConfig();
  DutyEntry duty(int weekday, String place, String teacher) => DutyEntry(weekday: weekday, place: place, teacher: teacher);

  group('Duyuru bandı', () {
    testWidgets('duyuru varken bant ve metin görünür, metin saniyelik yenilemede sıfırlanmadan ilerler', (tester) async {
      await pumpPano(tester, base().copyWith(announcements: [Announcement(id: 'a', text: 'Yarın veli toplantısı var')]));
      expect(find.text('DUYURU'), findsOneWidget);
      expect(find.byKey(marquee), findsOneWidget);

      final x0 = tester.getTopLeft(find.byKey(marquee)).dx;
      await tester.pump(const Duration(seconds: 1));
      final x1 = tester.getTopLeft(find.byKey(marquee)).dx;
      await tester.pump(const Duration(seconds: 1));
      final x2 = tester.getTopLeft(find.byKey(marquee)).dx;
      expect(x1, lessThan(x0));
      expect(x2, lessThan(x1));
      // Animasyon baştan başlasaydı ikinci adım birinciyle aynı olurdu.
      expect((x1 - x2).abs(), closeTo((x0 - x1).abs(), 20));
    });

    testWidgets('birden fazla duyuru " • " ile birleşir', (tester) async {
      await pumpPano(tester, base().copyWith(announcements: [
        Announcement(id: 'a', text: 'Birinci'),
        Announcement(id: 'b', text: 'İkinci'),
      ]));
      expect(find.text('Birinci • İkinci'), findsOneWidget);
    });

    testWidgets('süresi dolmuş ya da kapalı duyuru gösterilmez', (tester) async {
      await pumpPano(tester, base().copyWith(announcements: [
        Announcement(id: 'a', text: 'Eski duyuru', endDate: DateTime(2026, 10, 13)),
        Announcement(id: 'b', text: 'Kapalı duyuru', enabled: false),
      ]));
      expect(find.text('DUYURU'), findsNothing);
      expect(find.textContaining('Eski duyuru'), findsNothing);
      expect(find.textContaining('Kapalı duyuru'), findsNothing);
    });

    testWidgets('bugün biten duyuru hâlâ gösterilir', (tester) async {
      await pumpPano(tester, base().copyWith(announcements: [Announcement(id: 'a', text: 'Bugün son', endDate: DateTime(2026, 10, 14))]));
      expect(find.text('Bugün son'), findsOneWidget);
    });
  });

  group('Nöbetçi kartı', () {
    testWidgets('bugünün nöbetçileri görünür, başka günün nöbetçisi görünmez', (tester) async {
      await pumpPano(tester, base().copyWith(dutyRoster: [
        duty(3, 'Bahçe', 'Ayşe Hoca'),
        duty(3, 'Giriş', 'Mehmet Hoca'),
        duty(4, 'Kantin', 'Fatma Hoca'),
      ]));
      expect(find.text('Bugünün nöbetçileri'), findsOneWidget);
      expect(find.text('Bahçe — Ayşe Hoca'), findsOneWidget);
      expect(find.text('Giriş — Mehmet Hoca'), findsOneWidget);
      expect(find.textContaining('Fatma Hoca'), findsNothing);
    });

    testWidgets('en fazla 6 satır, fazlası "+N kişi daha"', (tester) async {
      await pumpPano(tester, base().copyWith(dutyRoster: [for (var i = 1; i <= 9; i++) duty(3, 'Yer $i', 'Öğr $i')]));
      expect(find.text('Yer 6 — Öğr 6'), findsOneWidget);
      expect(find.text('Yer 7 — Öğr 7'), findsNothing);
      expect(find.text('+3 kişi daha'), findsOneWidget);
    });

    testWidgets('yalnız başka günün nöbeti varsa kart çizilmez', (tester) async {
      await pumpPano(tester, base().copyWith(dutyRoster: [duty(4, 'Kantin', 'Fatma Hoca')]));
      expect(find.text('Bugünün nöbetçileri'), findsNothing);
    });
  });

  testWidgets('duyuru ve nöbet yoksa ne bant ne kart çizilir', (tester) async {
    await pumpPano(tester, base());
    expect(find.text('DUYURU'), findsNothing);
    expect(find.byKey(marquee), findsNothing);
    expect(find.text('Bugünün nöbetçileri'), findsNothing);
    expect(find.text('Panodan çık (Esc)'), findsOneWidget);
  });

  testWidgets('çıkış düğmesi bant varken bandın üstüne binmez', (tester) async {
    await pumpPano(tester, base().copyWith(announcements: [Announcement(id: 'a', text: 'Duyuru')]));
    final button = tester.getRect(find.text('Panodan çık (Esc)'));
    final band = tester.getRect(find.text('DUYURU'));
    expect(button.bottom, lessThan(band.top));
  });

  testWidgets('yoğun gün: 8 ders + 6 nöbetçi + 200 karakterlik duyuru taşmaz', (tester) async {
    final lessons = ScheduleTemplate.generateLessons(
      firstStart: ClockTime.parse('08:00'),
      count: 8,
      lessonMinutes: 40,
      breakMinutes: 10,
    );
    final template = normalDayTemplate.copyWith(lessons: lessons, lunchAfterLesson: () => null);
    await pumpPano(
      tester,
      base().copyWith(
        templates: [template],
        announcements: [Announcement(id: 'a', text: List.filled(40, 'Duyuru').join(' ').substring(0, 200))],
        dutyRoster: [for (var i = 1; i <= 6; i++) duty(3, 'Nöbet yeri numara $i', 'Öğretmen Adı Soyadı $i')],
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    expect(find.text('8. Ders'), findsOneWidget);
    expect(find.text('Bugünün nöbetçileri'), findsOneWidget);
    // Sağ sütun tuvalin içinde ve bandın üstünde kalır.
    final band = tester.getRect(find.text('DUYURU'));
    expect(tester.getRect(find.text('Bugünün nöbetçileri')).bottom, lessThan(band.top));
  });
}
