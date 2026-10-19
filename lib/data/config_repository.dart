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

  static const maxBackups = 10;

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
      final warnings = <String>[];
      final config = _parse(file.readAsStringSync(), warnings);
      if (warnings.isNotEmpty) {
        lastLoadWarning = '${warnings.join(' ')} Ayar dosyasının önceki hâli "yedekler" klasöründe.';
        _backupCurrent(force: true);
      }
      return config;
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
    final text = exportJson(config);
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

  /// Dosyaya yazılacak girintili JSON; ayar klasöründeki `sesler/` altındaki
  /// ses yolları göreli (`sesler/x.mp3`) yazılır.
  String exportJson(AppConfig config) {
    const encoder = JsonEncoder.withIndent('  ');
    final sounds = [
      for (final s in config.sounds)
        s.isAsset ? s : BellSound(id: s.id, name: s.name, path: _toRelative(s.path), isAsset: false),
    ];
    final announcements = [
      for (final a in config.spokenAnnouncements) a.path == null ? a : a.copyWith(path: _toRelative(a.path!)),
    ];
    return encoder.convert(config.copyWith(sounds: sounds, spokenAnnouncements: announcements).toJson());
  }

  String get _soundsPrefix => '${file.parent.path.replaceAll('\\', '/')}/sesler/';

  String _toRelative(String path) {
    final norm = path.replaceAll('\\', '/');
    final prefix = _soundsPrefix;
    final inside = Platform.isWindows
        ? norm.toLowerCase().startsWith(prefix.toLowerCase())
        : norm.startsWith(prefix);
    if (!inside || norm.length == prefix.length) return path;
    return 'sesler/${norm.substring(prefix.length)}';
  }

  String _toAbsolute(String path) {
    final norm = path.replaceAll('\\', '/');
    if (!norm.startsWith('sesler/') || norm.length == 'sesler/'.length) return path;
    final sep = Platform.pathSeparator;
    return '${file.parent.path}$sep${norm.replaceAll('/', sep)}';
  }

  AppConfig _parse(String text, [List<String>? warnings]) {
    final config = AppConfig.fromJson(jsonDecode(text) as Map<String, dynamic>, warnings: warnings);
    final sounds = [
      for (final s in config.sounds)
        s.isAsset ? s : BellSound(id: s.id, name: s.name, path: _toAbsolute(s.path), isAsset: false),
    ];
    final announcements = [
      for (final a in config.spokenAnnouncements) a.path == null ? a : a.copyWith(path: _toAbsolute(a.path!)),
    ];
    return config.copyWith(sounds: sounds, spokenAnnouncements: announcements);
  }

  /// Verilen ayar dosyasını okur; bozuk/geçersizse fırlatır. Atlanan
  /// kayıtların uyarılarını da döndürür.
  (AppConfig, List<String>) readConfigFile(File f) {
    final warnings = <String>[];
    final config = _parse(f.readAsStringSync(), warnings);
    return (config, warnings);
  }

  /// Mevcut okunabilir ayar dosyasını 10 dk kuralını atlayarak yedekler.
  void snapshot() => _backupCurrent(force: true);

  /// Art arda kayıtlar (ör. ses kaydırıcısı) yedekleri aynı dakikanın
  /// kopyalarıyla doldurmasın; yedekler zamana yayılsın.
  static const backupInterval = Duration(minutes: 10);

  /// Mevcut ve okunabilir ayar dosyasını yedekler, eski yedekleri budar.
  void _backupCurrent({bool force = false}) {
    try {
      if (!file.existsSync()) return;
      final newest = _backupFiles().firstOrNull;
      if (!force && newest != null && DateTime.now().difference(newest.lastModifiedSync()) < backupInterval) return;
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

  /// Yedek listesi, en yeni başta. Okunamayan yedekler de listelenir.
  List<BackupInfo> listBackups() => [for (final f in _backupFiles()) BackupInfo(f, _labelOf(f))];

  /// `config-2026-10-15T09-12-30.json` -> "2026-10-15 09:12".
  static String _labelOf(File f) {
    final name = f.uri.pathSegments.last;
    final m = RegExp(r'^config-(\d{4}-\d{2}-\d{2})(?:T(\d{2})-(\d{2}))?').firstMatch(name);
    if (m == null) return name; // biçim dışı ad: ham adla etiketle
    return m.group(2) == null ? m.group(1)! : '${m.group(1)} ${m.group(2)}:${m.group(3)}';
  }

  /// En yeni okunabilir yedek ve tarihi ("2026-10-15 09:12").
  (AppConfig, String)? _loadNewestBackup() {
    for (final f in _backupFiles()) {
      try {
        return (_parse(f.readAsStringSync()), _labelOf(f));
      } catch (_) {
        continue;
      }
    }
    return null;
  }
}

/// Bir ayar yedeği: dosya ve okunur tarih etiketi ("2026-10-15 09:12").
class BackupInfo {
  const BackupInfo(this.file, this.label);

  final File file;
  final String label;
}
