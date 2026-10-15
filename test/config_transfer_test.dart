import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:okul_zili/app_controller.dart';
import 'package:okul_zili/data/config_repository.dart';
import 'package:okul_zili/data/default_config.dart';
import 'package:okul_zili/data/models/app_config.dart';

import 'support/app_harness.dart';

void main() {
  late Directory tmp;
  late ConfigRepository repo;
  late AppController controller;
  final sep = Platform.pathSeparator;

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('okul_zili_aktar');
    repo = ConfigRepository(File('${tmp.path}${sep}config.json'));
    final config = createDefaultConfig().copyWith(schoolName: 'Mevcut Okul');
    await repo.save(config);
    controller = AppController(config: config, repository: repo, player: SilentPlayer());
  });
  tearDown(() {
    controller.dispose();
    try {
      tmp.deleteSync(recursive: true);
    } on FileSystemException catch (_) {}
  });

  Future<File> writeConfig(String name, AppConfig c) async {
    final f = File('${tmp.path}$sep$name');
    f.writeAsStringSync(repo.exportJson(c));
    return f;
  }

  test('geri yükleme: config yedektekidir ve öncesi yedeklenmiştir', () async {
    final f = await writeConfig('eski.json', createDefaultConfig().copyWith(schoolName: 'Yedek Okul'));
    final before = repo.listBackups().length;
    final r = await controller.restoreBackup(BackupInfo(f, 'x'));
    expect(r.ok, isTrue);
    expect(controller.config.schoolName, 'Yedek Okul');
    expect(repo.readConfigFile(repo.file).$1.schoolName, 'Yedek Okul');
    final names = repo.listBackups().map((b) => b.file.readAsStringSync());
    expect(names.any((t) => t.contains('Mevcut Okul')), isTrue);
    expect(repo.listBackups().length, greaterThan(before));
  });

  test('bozuk dosyada config değişmez ve ok=false', () async {
    final f = File('${tmp.path}${sep}bozuk.json')..writeAsStringSync('{ yarım');
    final r = await controller.importConfigFile(f.path);
    expect(r.ok, isFalse);
    expect(r.error, isNotEmpty);
    expect(controller.config.schoolName, 'Mevcut Okul');
    expect(await controller.undoReplace(), isFalse);
  });

  test('eksik ses sesler/ altında bulunursa yol düzelir, yoksa missingSounds', () async {
    final base = createDefaultConfig();
    final c = base.copyWith(sounds: [
      ...base.sounds,
      const BellSound(id: 'a', name: 'Bulunan', path: '/yok/dizin/ses1.mp3'),
      const BellSound(id: 'b', name: 'Kayıp', path: '/yok/dizin/ses2.mp3'),
    ]);
    final f = await writeConfig('sesli.json', c);
    final sesler = Directory('${tmp.path}${sep}sesler')..createSync();
    File('${sesler.path}${sep}ses1.mp3').writeAsStringSync('x');

    final r = await controller.importConfigFile(f.path);
    expect(r.ok, isTrue);
    expect(r.missingSounds, ['Kayıp']);
    expect(controller.config.sounds.firstWhere((s) => s.id == 'a').path, '${sesler.path}${sep}ses1.mp3');
    expect(controller.config.sounds.firstWhere((s) => s.id == 'b').path, '/yok/dizin/ses2.mp3');
  });

  test('undoReplace önceki ayarı getirir, yalnız bir kez', () async {
    final f = await writeConfig('yeni.json', createDefaultConfig().copyWith(schoolName: 'Yeni Okul'));
    await controller.importConfigFile(f.path);
    expect(controller.config.schoolName, 'Yeni Okul');
    expect(await controller.undoReplace(), isTrue);
    expect(controller.config.schoolName, 'Mevcut Okul');
    expect(await controller.undoReplace(), isFalse);
  });

  test('exportConfig yazılan dosya aynı okul adını verir', () async {
    final out = '${tmp.path}${sep}disari.json';
    expect(await controller.exportConfig(out), isNull);
    expect(repo.readConfigFile(File(out)).$1.schoolName, 'Mevcut Okul');
    expect(await controller.exportConfig('${tmp.path}${sep}yok${sep}a.json'), isNotNull);
  });

  test('kirli taslak atılır', () async {
    controller.editSchedule().dirty = true;
    expect(controller.scheduleDraft?.dirty, isTrue);
    final f = await writeConfig('y.json', createDefaultConfig().copyWith(schoolName: 'Y'));
    await controller.importConfigFile(f.path);
    expect(controller.scheduleDraft, isNull);
  });

  /// Kendi klasöründe, şifresi 'gizli1' olan (oturumu açık) bir denetleyici.
  Future<AppController> lockedController(String dir) async {
    final d = Directory('${tmp.path}$sep$dir')..createSync();
    final r = ConfigRepository(File('${d.path}${sep}config.json'));
    final cfg = createDefaultConfig().copyWith(schoolName: 'Kilitli Okul');
    await r.save(cfg);
    final lc = AppController(
        config: cfg, repository: r, player: SilentPlayer(), passwordHasher: const FastPasswordHasher());
    await lc.setPassword(newPassword: 'gizli1');
    addTearDown(lc.dispose);
    return lc;
  }

  test('kilitli denetleyicide kilitsiz yedek yüklenince kilit korunur, eski parola çalışır', () async {
    final lc = await lockedController('a');
    final f = await writeConfig('kilitsiz.json', createDefaultConfig().copyWith(schoolName: 'Yedek Okul'));
    final r = await lc.restoreBackup(BackupInfo(f, 'x'));
    expect(r.ok, isTrue);
    expect(lc.config.schoolName, 'Yedek Okul');
    expect(lc.isLockEnabled, isTrue);
    expect(lc.isLocked, isFalse);
    lc.lock();
    expect(await lc.unlock('gizli1'), isTrue);
  });

  test('kilitsiz denetleyicide kilitli dosya içe aktarılınca kilit gelmez', () async {
    final lc = await lockedController('b');
    final f = await writeConfig('kilitli.json', lc.config.copyWith(schoolName: 'Dosya Okulu'));
    expect(repo.readConfigFile(f).$1.lock, isNotNull);
    final r = await controller.importConfigFile(f.path);
    expect(r.ok, isTrue);
    expect(controller.config.schoolName, 'Dosya Okulu');
    expect(controller.isLockEnabled, isFalse);
    expect(repo.readConfigFile(repo.file).$1.lock, isNull);
  });

  test('undoReplace kilidi değiştirmez', () async {
    final lc = await lockedController('c');
    final lockBefore = lc.config.lock;
    final f = await writeConfig('y.json', createDefaultConfig().copyWith(schoolName: 'Yeni'));
    await lc.importConfigFile(f.path);
    expect(await lc.undoReplace(), isTrue);
    expect(lc.config.schoolName, 'Kilitli Okul');
    expect(lc.isLockEnabled, isTrue);
    expect(identical(lc.config.lock, lockBefore), isTrue);

    // Kilitsiz bilgisayarda: içe aktarılan dosyadaki kilit geri almada da gelmez.
    final withLock = await writeConfig('k.json', lc.config);
    await controller.importConfigFile(withLock.path);
    expect(await controller.undoReplace(), isTrue);
    expect(controller.isLockEnabled, isFalse);
  });

  test('dışa aktarma: uzantı yoksa .json eklenir, .JSON aynen kalır', () async {
    expect(await controller.exportConfig('${tmp.path}${sep}ayarlar'), isNull);
    final written = File('${tmp.path}${sep}ayarlar.json');
    expect(written.existsSync(), isTrue);
    expect(repo.readConfigFile(written).$1.schoolName, 'Mevcut Okul');
    expect(File('${tmp.path}${sep}ayarlar').existsSync(), isFalse);

    expect(await controller.exportConfig('${tmp.path}${sep}BUYUK.JSON'), isNull);
    expect(File('${tmp.path}${sep}BUYUK.JSON').existsSync(), isTrue);
    expect(File('${tmp.path}${sep}BUYUK.JSON.json').existsSync(), isFalse);
  });
}
