import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'default_config.dart';
import 'models/app_config.dart';

/// Ayarları uygulama veri klasöründeki `config.json` dosyasında tutar
/// (Windows'ta %APPDATA%\com.okulzili\okul_zili).
///
/// Her kayıttan önce eski dosya `yedekler/` klasörüne kopyalanır (son
/// [maxBackups] sürüm). Ayar dosyası okunamazsa en yeni sağlam yedek, o da
/// yoksa varsayılan ayarlar yüklenir; okuma hiçbir durumda uygulamayı
/// durdurmaz.
class ConfigRepository {
  ConfigRepository(this.file);

  static Future<ConfigRepository> openDefault() async {
    final dir = await getApplicationSupportDirectory();
    await dir.create(recursive: true);
    return ConfigRepository(
      File('${dir.path}${Platform.pathSeparator}config.json'),
    );
  }

  static const maxBackups = 5;

  final File file;

  /// Son yüklemede bir sorun olduysa açıklaması (arayüzde gösterilir).
  String? lastLoadWarning;

  Directory get backupDir => Directory('${file.parent.path}${Platform.pathSeparator}yedekler');

  /// Kayıtlar bu zincirde sırayla yapılır; aynı anda iki kayıt aynı geçici
  /// dosyaya yazıp birbirini bozmasın.
  Future<void> _saving = Future.value();

  Future<AppConfig> load() async {
    lastLoadWarning = null;
    if (!file.existsSync()) {
      // İlk açılış ya da dosya silinmiş: yedek varsa ondan dön.
      final restored = _loadNewestBackup();
      if (restored != null) {
        lastLoadWarning = 'Ayar dosyası bulunamadı; ${restored.$2} tarihli yedek yüklendi.';
        await _trySave(restored.$1);
        return restored.$1;
      }
      final config = createDefaultConfig();
      await _trySave(config);
      return config;
    }

    try {
      return _parse(file.readAsStringSync());
    } catch (e) {
      // Bozuk dosyayı silmeden kenara al (kilitliyse olduğu yerde kalır).
      String moved = '';
      try {
        final backup = '${file.path}.bozuk-${DateTime.now().millisecondsSinceEpoch}';
        file.renameSync(backup);
        moved = ' Okunamayan dosya: $backup';
      } catch (_) {}

      final restored = _loadNewestBackup();
      if (restored != null) {
        lastLoadWarning = 'Ayar dosyası okunamadı; ${restored.$2} tarihli yedek yüklendi.$moved';
        await _trySave(restored.$1);
        return restored.$1;
      }
      lastLoadWarning = 'Ayar dosyası okunamadı ve yedek yok; varsayılan ayarlar yüklendi.$moved';
      final config = createDefaultConfig();
      await _trySave(config);
      return config;
    }
  }

  /// Önce geçici dosyaya yazıp sonra yeniden adlandırır; yazma sırasında
  /// elektrik kesilirse eski ayar dosyası bozulmaz.
  Future<void> save(AppConfig config) {
    final next = _saving.then((_) => _write(config));
    _saving = next.catchError((_) {});
    return next;
  }

  Future<void> _write(AppConfig config) async {
    const encoder = JsonEncoder.withIndent('  ');
    final text = encoder.convert(config.toJson());
    _backupCurrent();
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(text, flush: true);
    await tmp.rename(file.path);
  }

  Future<void> _trySave(AppConfig config) async {
    try {
      await save(config);
    } catch (_) {
      // Kaydedilemese de uygulama bellekteki ayarla çalışmaya devam eder.
    }
  }

  AppConfig _parse(String text) => AppConfig.fromJson(jsonDecode(text) as Map<String, dynamic>);

  /// Art arda kayıtlar (ör. ses kaydırıcısı) yedekleri aynı dakikanın
  /// kopyalarıyla doldurmasın; yedekler zamana yayılsın.
  static const backupInterval = Duration(minutes: 10);

  /// Mevcut ve okunabilir ayar dosyasını yedekler, eski yedekleri budar.
  void _backupCurrent() {
    try {
      if (!file.existsSync()) return;
      final newest = _backupFiles().firstOrNull;
      if (newest != null && DateTime.now().difference(newest.lastModifiedSync()) < backupInterval) return;
      final text = file.readAsStringSync();
      _parse(text); // Bozuk dosya yedeklenmez; sağlam yedekleri ezmesin.
      backupDir.createSync(recursive: true);
      final stamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
      File('${backupDir.path}${Platform.pathSeparator}config-$stamp.json').writeAsStringSync(text, flush: true);
      final backups = _backupFiles();
      for (final old in backups.skip(maxBackups)) {
        old.deleteSync();
      }
    } catch (_) {
      // Yedek alınamaması kaydı engellemez.
    }
  }

  /// Yedekler, en yeni başta.
  List<File> _backupFiles() {
    if (!backupDir.existsSync()) return [];
    return backupDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json') && f.uri.pathSegments.last.startsWith('config-'))
        .toList()
      ..sort((a, b) => b.path.compareTo(a.path));
  }

  /// En yeni okunabilir yedek ve tarihi ("2026-10-15 09:12").
  (AppConfig, String)? _loadNewestBackup() {
    for (final f in _backupFiles()) {
      try {
        final config = _parse(f.readAsStringSync());
        final name = f.uri.pathSegments.last; // config-2026-10-15T09-12-30.json
        final stamp = name.substring('config-'.length, name.length - '.json'.length);
        final parts = stamp.split('T');
        final time = parts.length == 2 ? parts[1].split('-').take(2).join(':') : '';
        return (config, '${parts.first} $time'.trim());
      } catch (_) {
        continue;
      }
    }
    return null;
  }
}
