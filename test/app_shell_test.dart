import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okul_zili/app_controller.dart';
import 'package:okul_zili/data/config_repository.dart';
import 'package:okul_zili/data/default_config.dart';
import 'package:okul_zili/data/models/app_config.dart';
import 'package:okul_zili/main.dart';
import 'package:okul_zili/platform/bell_player.dart';
import 'package:okul_zili/ui/navigation.dart';

class _SilentPlayer implements BellPlayer {
  final played = <String>[];

  @override
  Future<void> play(BellSound sound, {required int volumePercent, bool loop = false}) async =>
      played.add(sound.id);

  @override
  Future<void> stop() async {}
}

void main() {
  // Varsayılan test yazı tipi her harfi kare çizer ve gerçekte olmayan
  // taşmalar üretir; ölçüler gerçekçi olsun diye uygulamanın yazı tipi
  // yüklenir.
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
    // Windows, kayıt dosyası hâlâ yazılırken klasörü silmeye izin vermez;
    // geçici klasör olduğu için silinemezse sorun değil.
    try {
      tmp.deleteSync(recursive: true);
    } on FileSystemException catch (_) {}
  });

  Future<(AppController, ValueNotifier<AppPage>)> pumpApp(
    WidgetTester tester, {
    required Size size,
    required DateTime now,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final controller = AppController(
      config: createDefaultConfig(),
      repository: ConfigRepository(File('${tmp.path}/config.json')),
      player: _SilentPlayer(),
      now: () => now,
    );
    final navigation = ValueNotifier(AppPage.home);
    await tester.pumpWidget(OkulZiliApp(
      controller: controller,
      navigation: navigation,
      windowControls: const NoopWindowControls(),
    ));
    await tester.pump();
    return (controller, navigation);
  }

  for (final size in const [Size(1280, 820), Size(1024, 640)]) {
    group('${size.width.toInt()}×${size.height.toInt()}', () {
      testWidgets('ders sırasında ana ekran', (tester) async {
        await pumpApp(tester, size: size, now: DateTime(2026, 10, 14, 10, 2, 14));
        expect(find.text('2. Ders'), findsOneWidget);
        expect(find.text('TENEFFÜSE KALAN'), findsOneWidget);
        expect(find.text('12:46'), findsOneWidget);
        expect(find.text('Sıradaki'), findsOneWidget);
        expect(find.text('Bugünün zilleri'), findsOneWidget);
      });

      testWidgets('öğle arasında ana ekran', (tester) async {
        await pumpApp(tester, size: size, now: DateTime(2026, 10, 14, 12, 20));
        expect(find.text('Öğle Arası'), findsOneWidget);
        expect(find.text('5. DERSE KALAN'), findsOneWidget);
      });

      testWidgets('tatil gününde ana ekran', (tester) async {
        await pumpApp(tester, size: size, now: DateTime(2026, 10, 29, 10));
        expect(find.text('Cumhuriyet Bayramı'), findsWidgets);
        expect(find.text('Bugün zil çalmayacak'), findsOneWidget);
      });

      testWidgets('tüm sayfalar hatasız açılır', (tester) async {
        final (_, navigation) = await pumpApp(tester, size: size, now: DateTime(2026, 10, 14, 10, 2));
        for (final page in AppPage.values) {
          navigation.value = page;
          await tester.pump();
          final error = tester.takeException();
          expect(error, isNull, reason: '${page.label}: $error');
        }
        navigation.value = AppPage.program;
        await tester.pump();
        expect(find.text('Normal Gün'), findsWidgets);
        navigation.value = AppPage.pano;
        await tester.pump();
        expect(find.text('10:02'), findsOneWidget);
        navigation.value = AppPage.home;
        await tester.pump();
      });
    });
  }

  testWidgets('susturma menüsü ve kaldırma', (tester) async {
    final (controller, _) = await pumpApp(tester, size: const Size(1280, 820), now: DateTime(2026, 10, 14, 10, 2));
    await tester.ensureVisible(find.text('Sustur'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sustur'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bugün boyunca'));
    await tester.pumpAndSettle();
    expect(controller.isMuted, isTrue);
    expect(find.text('Ziller bugün boyunca susturuldu.'), findsOneWidget);

    await tester.ensureVisible(find.text('Susturmayı kaldır').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Susturmayı kaldır').first);
    await tester.pumpAndSettle();
    expect(controller.isMuted, isFalse);
  });

  testWidgets('acil durum düğmesi kısa basışta çalmaz, 2 sn basılı tutunca çalar', (tester) async {
    final (controller, _) = await pumpApp(tester, size: const Size(1280, 820), now: DateTime(2026, 10, 14, 10, 2));
    final button = find.text('Acil durum alarmı');
    await tester.ensureVisible(button);

    final quick = await tester.startGesture(tester.getCenter(button));
    await tester.pump(const Duration(milliseconds: 500));
    await quick.up();
    await tester.pumpAndSettle();
    expect(controller.emergencyActive, isFalse);

    final hold = await tester.startGesture(tester.getCenter(button));
    for (var i = 0; i < 24; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await hold.up();
    await tester.pump();
    expect(controller.emergencyActive, isTrue);
    expect(find.text('Acil durum alarmı çalıyor'), findsOneWidget);

    await tester.ensureVisible(find.text('Alarmı durdur'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alarmı durdur'));
    await tester.pump();
    expect(controller.emergencyActive, isFalse);
  });
}
