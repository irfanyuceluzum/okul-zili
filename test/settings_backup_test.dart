import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okul_zili/data/default_config.dart';
import 'package:okul_zili/data/models/app_config.dart';
import 'package:okul_zili/data/config_repository.dart';
import 'package:okul_zili/ui/navigation.dart';

import 'support/app_harness.dart';

/// Gerçek dosya G/Ç'si ile sahte saat iç içe: gerçek zaman tanıyıp kareleri
/// sırayla işleterek zincirleme async işin bitmesini bekler.
Future<void> settleIo(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  final now = DateTime(2026, 10, 14, 10, 0);
  late Directory tmp;
  final sep = Platform.pathSeparator;

  setUpAll(loadAppFont);
  setUp(() => tmp = Directory.systemTemp.createTempSync('okul_zili_ayar_ui'));
  tearDown(() {
    try {
      tmp.deleteSync(recursive: true);
    } on FileSystemException catch (_) {}
  });

  File validFile(String name, String school) {
    final f = File('${tmp.path}$sep$name');
    f.writeAsStringSync(ConfigRepository(File('${tmp.path}${sep}x.json'))
        .exportJson(createDefaultConfig().copyWith(schoolName: school)));
    return f;
  }

  testWidgets('bozuk dosya: hata diyaloğu, ayar değişmez', (tester) async {
    final bad = File('${tmp.path}${sep}bozuk.json')..writeAsStringSync('{ yarım');
    final (c, _) = await pumpOkulZili(tester,
        now: now, page: AppPage.settings, pickConfigFile: () async => bad.path);
    final before = c.config.schoolName;
    await tapVisible(tester, find.text('İçe aktar…'));
    expect(find.text('Dosya okunamadı'), findsOneWidget);
    expect(c.config.schoolName, before);
    expect(c.canUndoReplace, isFalse);
  });

  testWidgets('geçerli dosya: özet gösterilir, onayla yüklenir, geri al döndürür', (tester) async {
    final good = validFile('yeni.json', 'Yeni Okul');
    final (c, _) = await pumpOkulZili(tester,
        now: now, page: AppPage.settings, pickConfigFile: () async => good.path);
    final before = c.config.schoolName;
    await tapVisible(tester, find.text('İçe aktar…'));
    expect(find.text('Okul adı: Yeni Okul'), findsOneWidget);
    expect(find.text('Mevcut ayarlar önce yedeklenecek.'), findsOneWidget);
    expect(c.config.schoolName, before);

    await tester.tap(find.text('Yükle'));
    await settleIo(tester);
    await settleIo(tester);
    expect(c.config.schoolName, 'Yeni Okul');
    expect(find.text('Ayarlar yüklendi'), findsOneWidget);

    await tester.tap(find.text('Geri al'));
    await settleIo(tester);
    expect(c.config.schoolName, before);
  });

  testWidgets('özet diyaloğu: kilit etkinse "Şifre kilidi değişmeyecek." satırı', (tester) async {
    final good = validFile('yeni2.json', 'Yeni Okul');
    final (c, _) = await pumpOkulZili(tester,
        now: now, page: AppPage.settings, pickConfigFile: () async => good.path);
    final done = c.setPassword(newPassword: 'gizli1');
    await settleIo(tester);
    await done;
    await tapVisible(tester, find.text('İçe aktar…'));
    expect(find.text('Şifre kilidi değişmeyecek.'), findsOneWidget);
  });

  testWidgets('vazgeçilen seçici hiçbir şey yapmaz', (tester) async {
    final (c, _) = await pumpOkulZili(tester,
        now: now, page: AppPage.settings, pickConfigFile: () async => null, pickExportPath: () async => null);
    final before = c.config.schoolName;
    await tapVisible(tester, find.text('İçe aktar…'));
    await tapVisible(tester, find.text('Dışa aktar…'));
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
    expect(c.config.schoolName, before);
  });

  testWidgets('dışa aktar: sahte yola yazar', (tester) async {
    final out = '${tmp.path}${sep}disari.json';
    await pumpOkulZili(tester, now: now, page: AppPage.settings, pickExportPath: () async => out);
    await tester.ensureVisible(find.text('Dışa aktar…'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dışa aktar…'));
    await settleIo(tester);
    expect(File(out).existsSync(), isTrue);
    expect(find.text('Ayarlar dışa aktarıldı'), findsOneWidget);
  });

  /// Ayar klasörünün yedekler/ altına verilen adlarla yedek koyar, sayfayı yeniden açar.
  Future<void> putBackups(WidgetTester tester, dynamic c, ValueNotifier<AppPage> nav, Map<String, String> byName) async {
    final repo = c.repository as ConfigRepository;
    repo.backupDir.createSync(recursive: true);
    byName.forEach((name, school) {
      File('${repo.backupDir.path}$sep$name')
          .writeAsStringSync(repo.exportJson(createDefaultConfig().copyWith(schoolName: school)));
    });
    nav.value = AppPage.home;
    await tester.pumpAndSettle();
    nav.value = AppPage.settings;
    await tester.pumpAndSettle();
  }

  testWidgets('yedek listesi sıralı; Geri yükle özet gösterir ve yedeği yükler', (tester) async {
    final (c, nav) = await pumpOkulZili(tester, now: now, page: AppPage.settings);
    await putBackups(tester, c, nav, {
      'config-2026-10-14T08-00-00.json': 'Eski Yedek Okulu',
      'config-2026-10-15T09-12-00.json': 'Yeni Yedek Okulu',
    });
    final newest = find.text('2026-10-15 09:12');
    final oldest = find.text('2026-10-14 08:00');
    expect(newest, findsOneWidget);
    expect(oldest, findsOneWidget);
    expect(tester.getTopLeft(newest).dy, lessThan(tester.getTopLeft(oldest).dy));

    await tapVisible(tester, find.text('Geri yükle').first);
    expect(find.text('Okul adı: Yeni Yedek Okulu'), findsOneWidget);
    await tester.tap(find.text('Yükle'));
    await settleIo(tester);
    expect(c.config.schoolName, 'Yeni Yedek Okulu');
  });

  for (final size in const [Size(1280, 820), Size(1024, 640)]) {
    testWidgets('dolu yedek listesi ${size.width.toInt()}x${size.height.toInt()} taşmaz', (tester) async {
      final (c, nav) = await pumpOkulZili(tester, now: now, page: AppPage.settings, size: size);
      await putBackups(tester, c, nav, {
        for (var i = 1; i <= 10; i++) 'config-2026-10-${10 + i}T09-00-00.json': 'Okul $i',
      });
      expect(find.text('Geri yükle'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('bulunamayan sesler adlarıyla bildirilir', (tester) async {
    final f = File('${tmp.path}${sep}sesli.json');
    f.writeAsStringSync(ConfigRepository(File('${tmp.path}${sep}x.json')).exportJson(createDefaultConfig().copyWith(
        schoolName: 'Sesli Okul',
        sounds: [const BellSound(id: 'k', name: 'Kayıp Zil', path: '/yok/dizin/kayip.mp3')])));
    final (c, _) = await pumpOkulZili(tester, now: now, page: AppPage.settings, pickConfigFile: () async => f.path);
    await tapVisible(tester, find.text('İçe aktar…'));
    await tester.tap(find.text('Yükle'));
    await settleIo(tester);
    expect(c.config.schoolName, 'Sesli Okul');
    expect(find.textContaining('Kayıp Zil'), findsOneWidget);
    expect(find.textContaining('klasik zil çalar'), findsOneWidget);
  });

  testWidgets('dışa aktarma hatası metinle bildirilir', (tester) async {
    final bad = '${tmp.path}${sep}yok${sep}klasor${sep}a.json';
    await pumpOkulZili(tester, now: now, page: AppPage.settings, pickExportPath: () async => bad);
    await tester.ensureVisible(find.text('Dışa aktar…'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dışa aktar…'));
    await settleIo(tester);
    expect(find.text('Dışa aktarılamadı'), findsOneWidget);
    expect(find.textContaining('yazılamadı'), findsOneWidget);
  });

  for (final size in const [Size(1280, 820), Size(1024, 640)]) {
    testWidgets('Ayarlar ${size.width.toInt()}x${size.height.toInt()} taşmaz', (tester) async {
      await pumpOkulZili(tester, now: now, page: AppPage.settings, size: size);
      expect(find.text('Yedekler ve taşıma'), findsOneWidget);
      expect(find.textContaining('Henüz yedek yok'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
