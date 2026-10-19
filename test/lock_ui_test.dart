import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okul_zili/app_controller.dart';
import 'package:okul_zili/data/config_repository.dart';
import 'package:okul_zili/data/default_config.dart';
import 'package:okul_zili/main.dart';
import 'package:okul_zili/ui/navigation.dart';

import 'support/app_harness.dart';

class _RecordingWindowControls implements WindowControls {
  int quits = 0;

  @override
  Future<void> setFullScreen(bool fullScreen) async {}

  @override
  Future<void> showWindow() async {}

  @override
  Future<void> requestQuit() async => quits++;
}

void main() {
  setUpAll(loadAppFont);

  final now = DateTime(2026, 9, 14, 10, 0);

  /// Gerçek dosya G/Ç'si testWidgets içinde tamamlanmadığı için gerçek zamanlı çalıştırılır.
  Future<T> real<T>(WidgetTester tester, Future<T> Function() body) async {
    final result = await tester.runAsync(body);
    await tester.pump();
    return result as T;
  }

  /// Sahte saat bölgesinde başlamış (ve önceki kayıtlara sıralı bağlı) işi, gerçek
  /// bekleme ile kare çizimini dönüşümlü yaparak bitirir.
  Future<T> drive<T>(WidgetTester tester, Future<T> future) async {
    var done = false;
    future.whenComplete(() => done = true);
    for (var i = 0; i < 200 && !done; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    return future;
  }

  /// Gerçek G/Ç ile sahte saat iç içe olduğu için pumpAndSettle yerine sınırlı sayıda
  /// "gerçek bekleme + kare" döngüsü kullanılır (dönen gösterge hiç yatışmaz).
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await real(tester, () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await settle(tester);
    await tester.tap(finder);
    await settle(tester);
  }

  Future<AppController> withLock(WidgetTester tester, AppController c, {bool lock = true}) async {
    await drive(tester, c.setPassword(newPassword: 'okul1234'));
    if (lock) c.lock();
    await settle(tester);
    return c;
  }

  Finder field(String label) =>
      find.byWidgetPredicate((w) => w is TextField && w.decoration?.labelText == label);

  final dialogSave = find.descendant(of: find.byType(AlertDialog), matching: find.text('Kaydet'));

  Future<void> unlockWith(WidgetTester tester, String secret) async {
    await tester.enterText(field('Şifre'), secret);
    await tester.tap(find.text('Kilidi aç'));
    await settle(tester);
  }

  testWidgets('kilit yokken menü serbest, kilit simgesi ve Kilitle yok', (tester) async {
    await pumpOkulZili(tester, now: now);
    expect(find.byIcon(Icons.lock), findsNothing);
    expect(find.text('Kilitle'), findsNothing);
    await tester.tap(find.text('Ders programı'));
    await settle(tester);
    expect(find.text('Şifre gerekli'), findsNothing);
  });

  testWidgets('şifre belirle: kurtarma kodu bir kez gösterilir', (tester) async {
    final (c, _) = await pumpOkulZili(tester, now: now, page: AppPage.settings);
    await tapAndSettle(tester, find.text('Şifre belirle'));
    await tester.enterText(field('Yeni şifre'), 'ab');
    await tester.enterText(field('Yeni şifre (tekrar)'), 'ab');
    await tester.tap(dialogSave);
    await settle(tester);
    expect(find.text('Şifre en az 4 karakter olmalı'), findsOneWidget);

    await tester.enterText(field('Yeni şifre'), 'okul1234');
    await tester.enterText(field('Yeni şifre (tekrar)'), 'baska');
    await tester.tap(dialogSave);
    await settle(tester);
    expect(find.text('Şifreler aynı değil'), findsOneWidget);

    await tester.enterText(field('Yeni şifre (tekrar)'), 'okul1234');
    await tester.tap(dialogSave);
    // Şifre özeti ve kayıt yoğun test turunda uzun sürebilir: pencere çıkana kadar bekle.
    for (var i = 0; i < 25 && find.text('Kurtarma kodunuz').evaluate().isEmpty; i++) {
      await settle(tester);
    }
    expect(find.text('Kurtarma kodunuz'), findsOneWidget);
    final code = tester
        .widgetList<SelectableText>(find.byType(SelectableText))
        .map((w) => w.data)
        .firstWhere((d) => RegExp(r'^\d{4}-\d{4}$').hasMatch(d ?? ''), orElse: () => null);
    expect(code, isNotNull);
    expect(c.isLockEnabled, isTrue);
    await tester.tap(find.text('Yazdım, kapat'));
    await settle(tester);
    expect(find.text('Kurtarma kodunuz'), findsNothing);
    expect(find.text('Kilidi kaldır'), findsOneWidget);
  });

  testWidgets('kilitliyken Ders programı şifre ister; yanlışta açılmaz, doğruda açılır', (tester) async {
    final (c, nav) = await pumpOkulZili(tester, now: now);
    await withLock(tester, c);
    expect(find.byIcon(Icons.lock), findsNWidgets(7));

    await tester.tap(find.text('Ders programı'));
    await settle(tester);
    expect(find.text('Şifre gerekli'), findsOneWidget);
    await unlockWith(tester, 'yanlis');
    expect(find.text('Şifre yanlış'), findsOneWidget);
    expect(nav.value, AppPage.home);

    await unlockWith(tester, 'okul1234');
    expect(find.text('Şifre gerekli'), findsNothing);
    expect(nav.value, AppPage.program);
  });

  testWidgets('kurtarma koduyla açılır; ipucu görünür', (tester) async {
    final (c, nav) = await pumpOkulZili(tester, now: now);
    final code = await drive(tester, c.setPassword(newPassword: 'okul1234', hint: 'okulun kuruluş yılı'));
    c.lock();
    await settle(tester);

    await tester.tap(find.text('Ayarlar'));
    await settle(tester);
    await tester.tap(find.text('Şifreyi unuttum'));
    await settle(tester);
    expect(find.text('İpucu: okulun kuruluş yılı'), findsOneWidget);
    expect(find.text('Kurtarma kodunu da buraya yazabilirsiniz.'), findsOneWidget);
    await unlockWith(tester, code);
    expect(nav.value, AppPage.settings);
  });

  testWidgets('Ana ekran, Kayıtlar ve Pano kilitliyken diyalogsuz açılır', (tester) async {
    final (c, nav) = await pumpOkulZili(tester, now: now);
    await withLock(tester, c);

    await tester.tap(find.text('Kayıtlar'));
    await settle(tester);
    expect(nav.value, AppPage.logs);
    await tester.tap(find.text('Ana ekran'));
    await settle(tester);
    expect(nav.value, AppPage.home);
    expect(find.text('Şifre gerekli'), findsNothing);

    // Pano açılınca oturum kilitlenir.
    await drive(tester, c.unlock('okul1234'));
    expect(c.isLocked, isFalse);
    await tester.tap(find.text('Pano modunu aç'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(nav.value, AppPage.pano);
    expect(c.isLocked, isTrue);
    expect(find.text('Şifre gerekli'), findsNothing);
  });

  testWidgets('Kilitle düğmesi oturumu kapatır ve ana ekrana döner', (tester) async {
    final (c, nav) = await pumpOkulZili(tester, now: now, page: AppPage.settings);
    await withLock(tester, c, lock: false);
    expect(c.isLocked, isFalse);
    await tester.tap(find.text('Kilitle'));
    await settle(tester);
    expect(c.isLocked, isTrue);
    expect(nav.value, AppPage.home);
    expect(find.text('Kilitle'), findsNothing);
  });

  testWidgets('kilitliyken tamamen kapat önce şifre ister', (tester) async {
    final windowControls = _RecordingWindowControls();
    final tmp = Directory.systemTemp.createTempSync('okul_zili_test');
    addTearDown(() {
      try {
        tmp.deleteSync(recursive: true);
      } on FileSystemException catch (_) {}
    });
    tester.view.physicalSize = const Size(1280, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = AppController(
      config: createDefaultConfig(),
      repository: ConfigRepository(File('${tmp.path}/config.json')),
      player: SilentPlayer(),
      now: () => now,
      passwordHasher: const FastPasswordHasher(),
    );
    await tester.pumpWidget(OkulZiliApp(
      controller: c,
      navigation: ValueNotifier(AppPage.settings),
      windowControls: windowControls,
    ));
    await settle(tester);
    await withLock(tester, c);

    await tapAndSettle(tester, find.text('Uygulamayı tamamen kapat'));
    expect(find.text('Şifre gerekli'), findsOneWidget);
    expect(windowControls.quits, 0);
    await tester.tap(find.text('Vazgeç'));
    await settle(tester);
    expect(windowControls.quits, 0);

    await tapAndSettle(tester, find.text('Uygulamayı tamamen kapat'));
    await unlockWith(tester, 'yanlis');
    expect(windowControls.quits, 0);
    await unlockWith(tester, 'okul1234');
    expect(windowControls.quits, 1);
  });

  testWidgets('reddedilen değişiklik bildirilir', (tester) async {
    final (c, _) = await pumpOkulZili(tester, now: now);
    await withLock(tester, c);
    await drive(tester, c.updateConfig(c.config.copyWith(schoolName: 'Yeni')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Ayarlar kilitli; değişiklik kaydedilmedi.'), findsOneWidget);
    expect(c.lockRefused, isFalse);
  });

  for (final size in const [Size(1280, 820), Size(1024, 640)]) {
    testWidgets('kilitli ve açık düzen taşmaz ($size)', (tester) async {
      final (c, nav) = await pumpOkulZili(tester, now: now, size: size, page: AppPage.settings);
      await withLock(tester, c, lock: false);
      expect(tester.takeException(), isNull);
      c.lock();
      nav.value = AppPage.home;
      await settle(tester);
      // Dar pencerede yalnızca simgeler görünür; ad ipucunda durur.
      await tester.tap(size.width < 1180 ? find.byTooltip('Ayarlar (kilitli)') : find.text('Ayarlar'));
      await settle(tester);
      expect(find.text('Şifre gerekli'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
