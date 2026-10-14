import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:okul_zili/data/config_repository.dart';
import 'package:okul_zili/data/default_config.dart';

void main() {
  late Directory tmp;
  late ConfigRepository repo;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('okul_zili_ayar');
    repo = ConfigRepository(File('${tmp.path}${Platform.pathSeparator}config.json'));
  });
  tearDown(() {
    try {
      tmp.deleteSync(recursive: true);
    } on FileSystemException catch (_) {}
  });

  List<File> backups() => repo.backupDir.existsSync() ? repo.backupDir.listSync().whereType<File>().toList() : [];

  test('ilk açılışta varsayılan ayar yazılır, uyarı yok', () async {
    final config = await repo.load();
    expect(config.templates.single.id, 'normal');
    expect(repo.lastLoadWarning, isNull);
    expect(repo.file.existsSync(), isTrue);
  });

  test('bozuk ayar dosyasında en yeni sağlam yedek yüklenir', () async {
    await repo.save(createDefaultConfig().copyWith(schoolName: 'Eski Okul'));
    await repo.save(createDefaultConfig().copyWith(schoolName: 'Atatürk Ortaokulu'));
    expect(backups(), hasLength(1), reason: 'ilk kayıtta yedeklenecek dosya yoktu');

    repo.file.writeAsStringSync('{ yarım json');
    final loaded = await repo.load();

    expect(loaded.schoolName, 'Eski Okul', reason: 'yedek, son kayıttan önceki hâl');
    expect(repo.lastLoadWarning, contains('yedek yüklendi'));
    expect(tmp.listSync().any((f) => f.path.contains('config.json.bozuk-')), isTrue, reason: 'bozuk dosya silinmez');
    expect(jsonDecode(repo.file.readAsStringSync())['schoolName'], 'Eski Okul', reason: 'yedek ana dosyaya geri yazılır');
  });

  test('bozuk dosya ve yedek yoksa varsayılana döner, uygulama durmaz', () async {
    repo.file.writeAsStringSync('bozuk');
    final loaded = await repo.load();
    expect(loaded.templates, isNotEmpty);
    expect(repo.lastLoadWarning, contains('varsayılan'));
  });

  test('ayar dosyası silinmişse yedekten döner', () async {
    await repo.save(createDefaultConfig().copyWith(schoolName: 'A'));
    await repo.save(createDefaultConfig().copyWith(schoolName: 'B'));
    repo.file.deleteSync();
    final loaded = await repo.load();
    expect(loaded.schoolName, 'A');
    expect(repo.lastLoadWarning, contains('bulunamadı'));
  });

  test('aynı anda yapılan kayıtlar birbirini bozmaz, sonuncusu kalır', () async {
    final saves = [
      for (var i = 0; i < 8; i++) repo.save(createDefaultConfig().copyWith(schoolName: 'Okul $i')),
    ];
    await Future.wait(saves);
    final text = repo.file.readAsStringSync();
    expect(jsonDecode(text)['schoolName'], 'Okul 7');
    expect(File('${repo.file.path}.tmp').existsSync(), isFalse);
  });

  test('bozuk dosya yedeklenmez; sağlam yedekler korunur', () async {
    await repo.save(createDefaultConfig().copyWith(schoolName: 'Sağlam'));
    repo.file.writeAsStringSync('bozuk');
    await repo.save(createDefaultConfig().copyWith(schoolName: 'Yeni'));
    expect(backups(), isEmpty, reason: 'tek önceki dosya bozuktu');
  });

  test('en fazla ${ConfigRepository.maxBackups} yedek tutulur', () async {
    repo.backupDir.createSync(recursive: true);
    // Eski tarihli yedekler (aralık sınırına takılmasın diye eski zaman damgası).
    for (var i = 0; i < 7; i++) {
      final f = File('${repo.backupDir.path}${Platform.pathSeparator}config-2026-01-0${i + 1}T08-00-00.json')
        ..writeAsStringSync(jsonEncode(createDefaultConfig().toJson()));
      f.setLastModifiedSync(DateTime(2026, 1, i + 1));
    }
    await repo.save(createDefaultConfig()); // ana dosya yok: yedek alınmaz
    await repo.save(createDefaultConfig().copyWith(schoolName: 'X')); // yedek alınır ve budanır
    final names = backups().map((f) => f.uri.pathSegments.last).toList()..sort();
    expect(names, hasLength(ConfigRepository.maxBackups));
    expect(names.first, isNot(contains('2026-01-01')), reason: 'en eskiler silinir');
  });
}
