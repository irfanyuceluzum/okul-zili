import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okul_zili/ui/navigation.dart';

import 'support/app_harness.dart';

/// Yazılmış ama kaydedilmemiş metin kaybolmasın.
void main() {
  setUpAll(loadAppFont);

  late DateTime now;
  setUp(() => now = DateTime(2026, 10, 14, 10, 0));

  group('Boşta kalınca pano', () {
    testWidgets('yazı alanında imleç varken panoya geçmez', (tester) async {
      final (_, navigation) = await pumpOkulZili(tester, now: now, clock: () => now, page: AppPage.settings);
      await tester.tap(find.widgetWithText(TextField, 'Okul adı'));
      await tester.enterText(find.widgetWithText(TextField, 'Okul adı'), 'Atatürk Ortaokulu');
      await tester.pump();

      now = now.add(const Duration(minutes: 10));
      await tester.pump(const Duration(seconds: 6));
      expect(navigation.value, AppPage.settings);

      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump(const Duration(seconds: 6));
      expect(navigation.value, AppPage.pano, reason: 'imleç alandan çıkınca boşta kalma işler');
      navigation.value = AppPage.home;
      await tester.pumpAndSettle();
    });

    testWidgets('açık pencere (diyalog) varken panoya geçmez', (tester) async {
      final (_, navigation) = await pumpOkulZili(tester, now: now, clock: () => now, page: AppPage.events);
      await tapVisible(tester, find.byTooltip('10 Kasım saygı duruşu sil'));
      expect(find.text('"10 Kasım saygı duruşu" silinsin mi?'), findsOneWidget);

      now = now.add(const Duration(minutes: 10));
      await tester.pump(const Duration(seconds: 6));
      expect(navigation.value, AppPage.events);
    });
  });

  testWidgets('takvim notu başka güne geçince kendiliğinden kaydedilir', (tester) async {
    final (controller, _) = await pumpOkulZili(tester, now: now, page: AppPage.calendar);
    await tapVisible(tester, find.text('21'));
    await tapVisible(tester, find.text('Zil çalmasın'));
    await tester.enterText(find.widgetWithText(TextField, 'Not (ana ekranda görünür)'), 'Veli toplantısı');
    await tester.pump();

    await tapVisible(tester, find.text('22'));
    expect(controller.overrideOn(DateTime(2026, 10, 21))?.note, 'Veli toplantısı');
  });

  testWidgets('okul adı alandan çıkınca kaydedilir, boşsa uyarı verir', (tester) async {
    final (controller, _) = await pumpOkulZili(tester, now: now, page: AppPage.settings);
    final field = find.widgetWithText(TextField, 'Okul adı');

    await tapVisible(tester, find.text('Kaydet'));
    expect(find.text('Okul adı boş olamaz'), findsOneWidget);

    await tester.tap(field);
    await tester.enterText(field, 'Atatürk Ortaokulu');
    await tester.pump();
    expect(find.text('Okul adı boş olamaz'), findsNothing);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    expect(controller.config.schoolName, 'Atatürk Ortaokulu');
  });
}
