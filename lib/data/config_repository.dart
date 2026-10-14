import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'default_config.dart';
import 'models/app_config.dart';

/// Ayarları uygulama veri klasöründeki `config.json` dosyasında tutar
/// (Windows'ta %APPDATA%\com.okulzili\okul_zili).
class ConfigRepository {
  ConfigRepository(this.file);

  static Future<ConfigRepository> openDefault() async {
    final dir = await getApplicationSupportDirectory();
    await dir.create(recursive: true);
    return ConfigRepository(
      File('${dir.path}${Platform.pathSeparator}config.json'),
    );
  }

  final File file;

  /// Son yüklemede bir sorun olduysa açıklaması (arayüzde gösterilir).
  String? lastLoadWarning;

  Future<AppConfig> load() async {
    lastLoadWarning = null;
    if (!await file.exists()) {
      final config = createDefaultConfig();
      await save(config);
      return config;
    }
    try {
      final json = jsonDecode(await file.readAsString());
      return AppConfig.fromJson(json as Map<String, dynamic>);
    } catch (e) {
      // Bozuk dosyayı silmeden kenara al; zil yine de varsayılanla çalsın.
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final backup = '${file.path}.bozuk-$stamp';
      await file.rename(backup);
      lastLoadWarning =
          'Ayar dosyası okunamadı, varsayılan ayarlar yüklendi. '
          'Eski dosya: $backup';
      final config = createDefaultConfig();
      await save(config);
      return config;
    }
  }

  /// Önce geçici dosyaya yazıp sonra yeniden adlandırır; yazma sırasında
  /// elektrik kesilirse eski ayar dosyası bozulmaz.
  Future<void> save(AppConfig config) async {
    final tmp = File('${file.path}.tmp');
    const encoder = JsonEncoder.withIndent('  ');
    await tmp.writeAsString(encoder.convert(config.toJson()), flush: true);
    await tmp.rename(file.path);
  }
}
