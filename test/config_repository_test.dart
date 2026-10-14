import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:okul_zili/data/config_repository.dart';
import 'package:okul_zili/data/default_config.dart';
import 'package:okul_zili/data/models/app_config.dart';

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

  test('tek bozuk kayıt atlanır, geri kalan ayarlar korunur', () async {
    final json = createDefaultConfig().copyWith(schoolName: 'Atatürk Ortaokulu').toJson();
    (json['holidays'] as List).add({'name': 'Bozuk tatil', 'start': '2026-13-45', 'end': 'x'});
    (json['soundForType'] as Map<String, dynamic>)['gelecekSurumTuru'] = 'zil';
    json['volumePercent'] = 80.0; // elle düzenlemede ondalıklı yazılmış
    repo.file.writeAsStringSync(jsonEncode(json));

    final loaded = await repo.load();
    expect(loaded.schoolName, 'Atatürk Ortaokulu');
    expect(loaded.holidays, hasLength(createDefaultConfig().holidays.length));
    expect(loaded.volumePercent, 80);
    expect(repo.lastLoadWarning, contains('1 tatil'));
    expect(backups(), hasLength(1), reason: 'atlanan kayıt yedekte durur');
    expect(backups().single.readAsStringSync(), contains('Bozuk tatil'));
  });

  test('hiç şablon okunamazsa yedeğe döner', () async {
    await repo.save(createDefaultConfig().copyWith(schoolName: 'Yedekteki'));
    await repo.save(createDefaultConfig());
    final json = createDefaultConfig().toJson()..['templates'] = [{'bozuk': true}];
    repo.file.writeAsStringSync(jsonEncode(json));
    final loaded = await repo.load();
    expect(loaded.schoolName, 'Yedekteki');
  });

  test('en fazla ${ConfigRepository.maxBackups} yedek tutulur', () async {
    repo.backupDir.createSync(recursive: true);
    // Eski tarihli yedekler (aralık sınırına takılmasın diye eski zaman damgası).
    for (var i = 0; i < 12; i++) {
      final f = File('${repo.backupDir.path}${Platform.pathSeparator}config-2026-01-${(i + 1).toString().padLeft(2, '0')}T08-00-00.json')
        ..writeAsStringSync(jsonEncode(createDefaultConfig().toJson()));
      f.setLastModifiedSync(DateTime(2026, 1, i + 1));
    }
    await repo.save(createDefaultConfig()); // ana dosya yok: yedek alınmaz
    await repo.save(createDefaultConfig().copyWith(schoolName: 'X')); // yedek alınır ve budanır
    final names = backups().map((f) => f.uri.pathSegments.last).toList()..sort();
    expect(names, hasLength(ConfigRepository.maxBackups));
    expect(names.first, isNot(contains('2026-01-01')), reason: 'en eskiler silinir');
  });

  File fakeBackup(String stamp, {String? content}) {
    repo.backupDir.createSync(recursive: true);
    return File('${repo.backupDir.path}${Platform.pathSeparator}config-$stamp.json')
      ..writeAsStringSync(content ?? jsonEncode(createDefaultConfig().toJson()));
  }

  test('listBackups en yeni başta ve etiketli; okunamayan da listelenir', () {
    fakeBackup('2026-10-14T08-00-00');
    fakeBackup('2026-10-15T09-12-30');
    fakeBackup('2026-10-13T07-05-00', content: 'bozuk{');
    final list = repo.listBackups();
    expect(list.map((b) => b.label), ['2026-10-15 09:12', '2026-10-14 08:00', '2026-10-13 07:05']);
  });

  test('readConfigFile bozuk dosyada fırlatır', () {
    final f = fakeBackup('2026-10-13T07-05-00', content: 'bozuk{');
    expect(() => repo.readConfigFile(f), throwsA(anything));
  });

  test('readConfigFile atlanan kayıtların uyarısını döndürür', () {
    final json = createDefaultConfig().toJson()..['holidays'] = [{'bozuk': true}];
    final f = fakeBackup('2026-10-13T07-05-00', content: jsonEncode(json));
    final (config, warnings) = repo.readConfigFile(f);
    expect(config.templates, isNotEmpty);
    expect(warnings, isNotEmpty);
  });

  test('snapshot 10 dk kuralını atlar', () async {
    await repo.save(createDefaultConfig());
    await repo.save(createDefaultConfig().copyWith(schoolName: 'A')); // 1. yedek
    expect(backups(), hasLength(1));
    repo.snapshot();
    expect(backups().length, greaterThanOrEqualTo(1));
    // Aynı saniyedeki ad çakışması olmasın diye eski damgalı yedek bırakıp yeniden dene.
    for (final b in backups()) {
      b.renameSync('${repo.backupDir.path}${Platform.pathSeparator}config-2026-01-01T00-00-00.json');
    }
    repo.file.setLastModifiedSync(DateTime.now());
    repo.backupDir.listSync().whereType<File>().first.setLastModifiedSync(DateTime.now());
    repo.snapshot(); // yedek yeni olsa da zorla alınır
    expect(backups(), hasLength(2));
  });

  test('göreli yol: save dosyada sesler/x.mp3 yazar, load mutlak döner', () async {
    final sep = Platform.pathSeparator;
    final abs = '${tmp.path}${sep}sesler${sep}x.mp3';
    final base = createDefaultConfig();
    await repo.save(base.copyWith(sounds: [...base.sounds, BellSound(id: 'u1', name: 'X', path: abs)]));
    final raw = jsonDecode(repo.file.readAsStringSync()) as Map<String, dynamic>;
    final saved = (raw['sounds'] as List).cast<Map<String, dynamic>>().firstWhere((s) => s['id'] == 'u1');
    expect(saved['path'], 'sesler/x.mp3');
    expect(repo.exportJson(base.copyWith(sounds: [BellSound(id: 'u1', name: 'X', path: abs)])), contains('"sesler/x.mp3"'));
    final loaded = await repo.load();
    expect(loaded.sounds.firstWhere((s) => s.id == 'u1').path, abs);
  });

  test('sesler dışındaki mutlak yol aynen korunur', () async {
    final sep = Platform.pathSeparator;
    final abs = '${Directory.systemTemp.path}${sep}baska${sep}y.mp3';
    final base = createDefaultConfig();
    await repo.save(base.copyWith(sounds: [...base.sounds, BellSound(id: 'u2', name: 'Y', path: abs)]));
    final raw = jsonDecode(repo.file.readAsStringSync()) as Map<String, dynamic>;
    expect((raw['sounds'] as List).cast<Map<String, dynamic>>().firstWhere((s) => s['id'] == 'u2')['path'], abs);
    final loaded = await repo.load();
    expect(loaded.sounds.firstWhere((s) => s.id == 'u2').path, abs);
  });
}
