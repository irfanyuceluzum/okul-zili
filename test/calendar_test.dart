import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okul_zili/ui/navigation.dart';

import 'support/app_harness.dart';

void main() {
  setUpAll(loadAppFont);

  // 14 Ekim 2026 Çarşamba
  final now = DateTime(2026, 10, 14, 10, 0);

  testWidgets('ay görünümü günlerin durumunu gösterir', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpOkulZili(tester, now: now, page: AppPage.calendar);

    expect(find.text('Ekim 2026'), findsOneWidget);
    expect(find.bySemanticsLabel('29 Ekim Perşembe, Cumhuriyet Bayramı'), findsOneWidget);
    expect(find.bySemanticsLabel('17 Ekim Cumartesi, zil yok'), findsOneWidget);
    expect(find.text('14 Ekim 2026, Çarşamba'), findsOneWidget, reason: 'bugün seçili gelir');
    expect(find.text('19 zil çalacak'), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('bir güne "zil çalmasın" seçilir, not eklenir, sonra geri alınır', (tester) async {
    final (controller, _) = await pumpOkulZili(tester, now: now, page: AppPage.calendar);

    await tapVisible(tester, find.text('21'));
    expect(find.text('21 Ekim 2026, Çarşamba'), findsOneWidget);

    await tapVisible(tester, find.text('Zil çalmasın'));
    expect(controller.resolver.resolve(DateTime(2026, 10, 21)).isSchoolDay, isFalse);
    expect(find.text('Zil çalmayacak'), findsOneWidget);
    expect(find.text('Zil yok'), findsOneWidget, reason: 'takvim hücresinde');

    await tester.enterText(find.widgetWithText(TextField, 'Not (ana ekranda görünür)'), 'Veli toplantısı');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(controller.overrideOn(DateTime(2026, 10, 21))?.note, 'Veli toplantısı');
    expect(controller.resolver.resolve(DateTime(2026, 10, 21)).offReason, 'Veli toplantısı');

    await tapVisible(tester, find.text('Haftalık plana göre: Normal Gün'));
    expect(controller.overrideOn(DateTime(2026, 10, 21)), isNull);
    expect(controller.resolver.resolve(DateTime(2026, 10, 21)).isSchoolDay, isTrue);
  });

  testWidgets('tatil gününe telafi için program verilir', (tester) async {
    final (controller, _) = await pumpOkulZili(tester, now: now, page: AppPage.calendar);
    await tapVisible(tester, find.text('29').last); // ilki önceki ayın 29 Eylül'ü
    expect(find.text('Tatil: Cumhuriyet Bayramı (zil çalmaz)'), findsOneWidget);

    await tapVisible(tester, find.text('Normal Gün'));
    expect(controller.resolver.resolve(DateTime(2026, 10, 29)).isSchoolDay, isTrue);
    expect(find.text('19 zil çalacak'), findsOneWidget);
  });

  testWidgets('aylar arasında gezilir ve "Bugün" geri getirir', (tester) async {
    await pumpOkulZili(tester, now: now, page: AppPage.calendar);
    await tapVisible(tester, find.byTooltip('Sonraki ay'));
    expect(find.text('Kasım 2026'), findsOneWidget);
    await tapVisible(tester, find.byTooltip('Sonraki ay'));
    await tapVisible(tester, find.byTooltip('Sonraki ay'));
    expect(find.text('Ocak 2027'), findsOneWidget);
    await tapVisible(tester, find.widgetWithText(OutlinedButton, 'Bugün'));
    expect(find.text('Ekim 2026'), findsOneWidget);
  });

  testWidgets('dar pencerede taşma olmaz', (tester) async {
    await pumpOkulZili(tester, now: now, page: AppPage.calendar, size: const Size(1024, 640));
    expect(tester.takeException(), isNull);
  });
}
