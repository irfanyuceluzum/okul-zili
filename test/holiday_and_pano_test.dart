import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okul_zili/app_controller.dart';
import 'package:okul_zili/data/config_repository.dart';
import 'package:okul_zili/data/default_config.dart';
import 'package:okul_zili/data/models/app_config.dart';
import 'package:okul_zili/main.dart';
import 'package:okul_zili/platform/system_services.dart';
import 'package:okul_zili/ui/navigation.dart';

import 'package:okul_zili/ui/widgets.dart';

import 'support/app_harness.dart';

/// Sistem boşta süresini testten ayarlanabilen sahte servis.
class _FakeSystem extends NoopSystemServices {
  Duration? idle;

  @override
  Duration? idleTime() => idle;
}

class _RecordingWindow extends NoopWindowControls {
  int shown = 0;

  @override
  Future<void> showWindow() async => shown++;
}

void main() {
  setUpAll(loadAppFont);

  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('okul_zili_test'));
  tearDown(() {
    try {
      tmp.deleteSync(recursive: true);
    } on FileSystemException catch (_) {}
  });

  late DateTime now;
  late _FakeSystem system;
  late _RecordingWindow window;

  Future<(AppController, ValueNotifier<AppPage>)> pumpApp(WidgetTester tester, {AppConfig? config}) async {
    tester.view.physicalSize = const Size(1280, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    system = _FakeSystem();
    window = _RecordingWindow();
    final controller = AppController(
      config: config ?? createDefaultConfig(),
      repository: ConfigRepository(File('${tmp.path}/config.json')),
      player: SilentPlayer(),
      system: system,
      now: () => now,
    );
    final navigation = ValueNotifier(AppPage.home);
    await tester.pumpWidget(OkulZiliApp(controller: controller, navigation: navigation, windowControls: window));
    await tester.pump();
    return (controller, navigation);
  }

  group('Boşta kalınca pano modu', () {
    setUp(() => now = DateTime(2026, 10, 14, 10, 0));

    testWidgets('3 dakika dolmadan açılmaz, dolunca açılır ve pencere gösterilir', (tester) async {
      final (_, navigation) = await pumpApp(tester);

      now = now.add(const Duration(minutes: 2, seconds: 50));
      await tester.pump(const Duration(seconds: 6));
      expect(navigation.value, AppPage.home);

      now = now.add(const Duration(seconds: 20));
      await tester.pump(const Duration(seconds: 6));
      expect(navigation.value, AppPage.pano);
      expect(window.shown, 1);

      navigation.value = AppPage.home;
      await tester.pump();
    });

    testWidgets('fare hareketi süreyi sıfırlar', (tester) async {
      final (_, navigation) = await pumpApp(tester);

      now = now.add(const Duration(minutes: 2));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(600, 400));
      await mouse.moveTo(const Offset(610, 400));
      await tester.pump();

      now = now.add(const Duration(minutes: 2));
      await tester.pump(const Duration(seconds: 6));
      expect(navigation.value, AppPage.home, reason: 'son hareketten bu yana 2 dk geçti');
      await mouse.removePointer();
    });

    testWidgets('bilgisayar başka programda kullanılıyorsa açılmaz', (tester) async {
      final (_, navigation) = await pumpApp(tester);
      system.idle = const Duration(seconds: 10); // biri Word'de yazıyor
      now = now.add(const Duration(minutes: 10));
      await tester.pump(const Duration(seconds: 6));
      expect(navigation.value, AppPage.home);
    });

    testWidgets('ayar kapalıysa hiç açılmaz', (tester) async {
      final (_, navigation) = await pumpApp(tester, config: createDefaultConfig().copyWith(panoIdleMinutes: 0));
      now = now.add(const Duration(hours: 1));
      await tester.pump(const Duration(seconds: 6));
      expect(navigation.value, AppPage.home);
    });
  });

  group('Tatil ekleme', () {
    setUp(() => now = DateTime(2026, 10, 14, 10, 0));

    Future<void> openCalendar(WidgetTester tester, ValueNotifier<AppPage> navigation) async {
      navigation.value = AppPage.calendar;
      await tester.pumpAndSettle();
    }

    testWidgets('adsız kaydedilmez, ad yazınca tek günlük tatil eklenir', (tester) async {
      final (controller, navigation) = await pumpApp(tester);
      await openCalendar(tester, navigation);

      await tester.tap(find.text('Tatil ekle').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();
      expect(find.text('Tatilin adını yazın'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Öğretmenler toplantısı');
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();

      final added = controller.config.holidays.singleWhere((h) => h.name == 'Öğretmenler toplantısı');
      expect(added.start, DateTime(2026, 10, 14));
      expect(added.end, DateTime(2026, 10, 14));
      expect(controller.resolver.resolve(DateTime(2026, 10, 14)).isSchoolDay, isFalse);
      expect(find.text('Öğretmenler toplantısı'), findsNWidgets(2), reason: 'takvim hücresi ve tatil listesi');
      expect(tester.takeException(), isNull);
    });

    testWidgets('son gün takvimden seçilerek çok günlük tatil eklenir', (tester) async {
      final (controller, navigation) = await pumpApp(tester);
      await openCalendar(tester, navigation);

      await tester.tap(find.text('Tatil ekle').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Ara tatil');
      // İkinci tarih düğmesi "Son gün".
      await tester.tap(find.textContaining('14 Ekim 2026').last);
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(DatePickerDialog), matching: find.text('16')));
      await tester.tap(find.text('Tamam'));
      await tester.pumpAndSettle();
      expect(find.text('3 gün boyunca zil çalmaz.'), findsOneWidget);

      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();

      final added = controller.config.holidays.singleWhere((h) => h.name == 'Ara tatil');
      expect(added.start, DateTime(2026, 10, 14));
      expect(added.end, DateTime(2026, 10, 16));
      expect(find.text('14–16 Ekim 2026 · 3 gün'), findsOneWidget);
    });

    testWidgets('tatil düzenlenir ve silinir', (tester) async {
      final (controller, navigation) = await pumpApp(tester);
      await openCalendar(tester, navigation);

      // Takvim hücresi ya da belirli günler kartı değil, tatil listesindeki satır.
      final row = find.descendant(of: find.widgetWithText(SectionCard, 'Tatiller'), matching: find.text('Cumhuriyet Bayramı'));
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(find.text('Tatili düzenle'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Cumhuriyet Bayramı (tam gün)');
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();
      expect(controller.config.holidays.where((h) => h.name == 'Cumhuriyet Bayramı'), isEmpty);
      expect(controller.config.holidays.where((h) => h.name == 'Cumhuriyet Bayramı (tam gün)'), hasLength(1));
      final count = controller.config.holidays.length;

      await tester.ensureVisible(find.byTooltip('Cumhuriyet Bayramı (tam gün) tatilini sil'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Cumhuriyet Bayramı (tam gün) tatilini sil'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sil'));
      await tester.pumpAndSettle();
      expect(controller.config.holidays, hasLength(count - 1));
      expect(controller.resolver.resolve(DateTime(2026, 10, 29)).isSchoolDay, isTrue);
    });
  });
}
