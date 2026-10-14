import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okul_zili/app_controller.dart';
import 'package:okul_zili/data/config_repository.dart';
import 'package:okul_zili/data/default_config.dart';
import 'package:okul_zili/data/models/notices.dart';
import 'package:okul_zili/ui/navigation.dart';

import 'support/app_harness.dart';

void main() {
  final now = DateTime(2026, 10, 15, 14, 30);

  setUpAll(loadAppFont);

  test('denetleyici: duyuru ekler, günceller, siler; nöbet çizelgesini yazar', () async {
    final tmp = Directory.systemTemp.createTempSync('okul_zili_notices');
    final c = AppController(
      config: createDefaultConfig(),
      repository: ConfigRepository(File('${tmp.path}/config.json')),
      player: SilentPlayer(),
    );
    addTearDown(() {
      c.dispose();
      try {
        tmp.deleteSync(recursive: true);
      } on FileSystemException catch (_) {}
    });
    await c.saveAnnouncement(Announcement(id: 'a1', text: 'Bir'));
    await c.saveAnnouncement(Announcement(id: 'a2', text: 'İki'));
    await c.saveAnnouncement(Announcement(id: 'a1', text: 'Bir güncel', enabled: false));
    expect(c.config.announcements.map((a) => '${a.id}/${a.text}/${a.enabled}'), ['a1/Bir güncel/false', 'a2/İki/true']);
    await c.deleteAnnouncement('a1');
    expect(c.config.announcements.map((a) => a.id), ['a2']);
    await c.setDutyRoster(const [DutyEntry(weekday: 2, place: 'Bahçe', teacher: 'A')]);
    expect(c.config.dutyRoster.single.place, 'Bahçe');
  });

  testWidgets('duyuru eklenir', (tester) async {
    final (c, _) = await pumpOkulZili(tester, now: now, page: AppPage.notices);
    await tapVisible(tester, find.text('Duyuru ekle'));
    await tester.enterText(find.byType(TextField), 'Veli toplantısı');
    await tapVisible(tester, find.text('Kaydet'));
    expect(c.config.announcements.single.text, 'Veli toplantısı');
    expect(c.config.announcements.single.endDate, isNull);
    expect(find.text('Süresiz'), findsOneWidget);
  });

  testWidgets('boş metinle kaydedilmez', (tester) async {
    final (c, _) = await pumpOkulZili(tester, now: now, page: AppPage.notices);
    await tapVisible(tester, find.text('Duyuru ekle'));
    await tester.enterText(find.byType(TextField), '   ');
    await tapVisible(tester, find.text('Kaydet'));
    expect(c.config.announcements, isEmpty);
    expect(find.text('Duyuru metnini yazın'), findsOneWidget);
  });

  testWidgets('duyuru silinir (onaylı)', (tester) async {
    final config = createDefaultConfig().copyWith(announcements: [Announcement(id: 'a1', text: 'Silinecek')]);
    final (c, _) = await pumpOkulZili(tester, now: now, page: AppPage.notices, config: config);
    await tapVisible(tester, find.byTooltip('Duyuruyu sil'));
    expect(c.config.announcements, hasLength(1));
    await tapVisible(tester, find.text('Vazgeç'));
    expect(c.config.announcements, hasLength(1));
    await tapVisible(tester, find.byTooltip('Duyuruyu sil'));
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Sil'));
    expect(c.config.announcements, isEmpty);
  });

  testWidgets('anahtarla kapatılır', (tester) async {
    final config = createDefaultConfig().copyWith(announcements: [Announcement(id: 'a1', text: 'Açık')]);
    final (c, _) = await pumpOkulZili(tester, now: now, page: AppPage.notices, config: config);
    await tapVisible(tester, find.byType(Switch).first);
    expect(c.config.announcements.single.enabled, isFalse);
  });

  testWidgets('nöbet satırı eklenir', (tester) async {
    final (c, _) = await pumpOkulZili(tester, now: now, page: AppPage.notices);
    await tapVisible(tester, find.text('Salı için satır ekle'));
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Bahçe');
    await tester.enterText(fields.at(1), 'Ayşe Yılmaz');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    final d = c.config.dutyRoster.single;
    expect((d.weekday, d.place, d.teacher), (2, 'Bahçe', 'Ayşe Yılmaz'));
  });

  testWidgets('nöbet satırı silinir', (tester) async {
    final config = createDefaultConfig().copyWith(dutyRoster: const [
      DutyEntry(weekday: 1, place: 'Bahçe', teacher: 'A'),
      DutyEntry(weekday: 3, place: 'Kantin', teacher: 'B'),
    ]);
    final (c, _) = await pumpOkulZili(tester, now: now, page: AppPage.notices, config: config);
    await tapVisible(tester, find.byTooltip('Pazartesi nöbet satırını sil'));
    expect(c.config.dutyRoster.map((d) => d.place), ['Kantin']);
  });

  testWidgets('yazılan nöbet, sayfadan çıkılırsa da kaydedilir', (tester) async {
    final (c, nav) = await pumpOkulZili(tester, now: now, page: AppPage.notices);
    await tapVisible(tester, find.text('Salı için satır ekle'));
    await tester.enterText(find.byType(TextField).at(0), 'Kantin');
    await tester.enterText(find.byType(TextField).at(1), 'Ali Hoca');
    nav.value = AppPage.logs;
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final d = c.config.dutyRoster.single;
    expect((d.weekday, d.place, d.teacher), (2, 'Kantin', 'Ali Hoca'));
  });

  for (final size in const [Size(1280, 820), Size(1024, 640)]) {
    testWidgets('taşma yok ${size.width.toInt()}x${size.height.toInt()}', (tester) async {
      final config = createDefaultConfig().copyWith(
        announcements: [Announcement(id: 'a1', text: 'Uzun duyuru ' * 15, endDate: DateTime(2026, 10, 20))],
        dutyRoster: const [DutyEntry(weekday: 1, place: 'Bahçe', teacher: 'Ayşe Yılmaz')],
      );
      await pumpOkulZili(tester, now: now, page: AppPage.notices, config: config, size: size);
      expect(tester.takeException(), isNull);
    });
  }
}
