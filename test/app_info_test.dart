import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okul_zili/core/app_info.dart';
import 'package:okul_zili/ui/navigation.dart';

import 'support/app_harness.dart';

void main() {
  setUpAll(loadAppFont);
  final now = DateTime(2026, 10, 14, 10, 0);

  test('AppInfo.version pubspec.yaml sürümüyle aynı', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(r'^version:\s*([^+\s]+)', multiLine: true).firstMatch(pubspec);
    expect(match, isNotNull);
    expect(AppInfo.version, match!.group(1));
  });

  test('lisans ve yazı tipi lisansı uygulamayla birlikte paketlenir', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    expect(await rootBundle.loadString('LICENSE'), contains('GNU GENERAL PUBLIC LICENSE'));
    expect(await rootBundle.loadString('assets/fonts/OFL.txt'), contains('SIL OPEN FONT LICENSE'));
  });

  testWidgets('kenar menüsünden Hakkında: geliştirici, sürüm, lisans', (tester) async {
    await pumpOkulZili(tester, now: now);
    await tapVisible(tester, find.text('Sürüm ${AppInfo.version} · Hakkında'));
    expect(find.text('İrfan Yücel ÜZÜM'), findsOneWidget);
    expect(find.text(AppInfo.version), findsOneWidget);
    expect(find.text(AppInfo.sourceUrl), findsOneWidget);
    expect(find.textContaining('GPL-3.0'), findsWidgets);
    expect(find.textContaining('ücretsiz'), findsWidgets);
    expect(find.textContaining('HİÇBİR GARANTİ OLMADAN'), findsOneWidget);

    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String?;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.tap(find.text('Kopyala'));
    await tester.pump();
    await tester.pump();
    expect(copied, AppInfo.sourceUrl);
    expect(find.text('Kopyalandı'), findsOneWidget);

    await tester.tap(find.text('Kapat'));
    await tester.pumpAndSettle();
    expect(find.text('İrfan Yücel ÜZÜM'), findsNothing);
  });

  testWidgets('dar pencerede Hakkında simgesi', (tester) async {
    await pumpOkulZili(tester, now: now, size: const Size(1024, 640));
    await tapVisible(tester, find.byIcon(Icons.info_outline));
    expect(find.text('İrfan Yücel ÜZÜM'), findsOneWidget);
  });

  for (final size in const [Size(1024, 640), Size(1280, 640)]) {
    testWidgets('kilit açıkken ${size.width.toInt()}×640 kenar menüsü taşmaz, Hakkında kaydırınca açılır', (tester) async {
      final (c, _) = await pumpOkulZili(tester, now: now, size: size, passwordHasher: const FastPasswordHasher());
      // Kayıt gerçek dosya G/Ç'si yapar: gerçek bekleme ile kareyi dönüşümlü ilerlet.
      var done = false;
      c.setPassword(newPassword: 'okul1234').whenComplete(() => done = true);
      for (var i = 0; i < 200 && !done; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump();
      }
      await tester.pump(const Duration(milliseconds: 300));
      expect(c.isLockEnabled, isTrue);
      expect(find.text('Kilitle'), size.width >= 1180 ? findsOneWidget : findsNothing);
      expect(tester.takeException(), isNull);
      // Kısa pencerede menü kayar; Hakkında kaydırınca ulaşılır.
      final about = size.width >= 1180 ? find.text('Sürüm ${AppInfo.version} · Hakkında') : find.byIcon(Icons.info_outline);
      await tapVisible(tester, about);
      expect(find.text('İrfan Yücel ÜZÜM'), findsOneWidget);
    });
  }

  testWidgets('Ayarlar → Hakkında ve lisans; lisans metni ve bileşenler açılır', (tester) async {
    await pumpOkulZili(tester, now: now, page: AppPage.settings);
    expect(find.textContaining('Geliştirici: İrfan Yücel ÜZÜM'), findsOneWidget);
    await tapVisible(tester, find.text('Hakkında ve lisans'));
    expect(find.text('İrfan Yücel ÜZÜM'), findsOneWidget);

    await tester.tap(find.text('Lisans metni'));
    for (var i = 0; i < 20 && find.textContaining('GNU GENERAL PUBLIC LICENSE').evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.textContaining('GNU GENERAL PUBLIC LICENSE'), findsOneWidget);
    await tester.tap(find.text('Kapat').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Kullanılan bileşenler'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(LicensePage), findsOneWidget);
  });
}
