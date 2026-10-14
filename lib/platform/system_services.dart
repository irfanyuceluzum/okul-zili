import 'dart:io';

import 'windows/windows_audio.dart';
import 'windows/windows_idle.dart';

/// Sistemin ses seviyesi; okunamıyorsa [error] dolu gelir.
class VolumeStatus {
  const VolumeStatus({this.level, this.muted = false, this.error});

  /// 0.0–1.0
  final double? level;
  final bool muted;
  final String? error;

  int? get percent => level == null ? null : (level! * 100).round();
}

/// İşletim sistemine bağlı işler. Windows dışında (Mac'te geliştirirken)
/// bunlar hiçbir şey yapmaz.
abstract interface class SystemServices {
  bool get controlsVolume;
  bool get supportsAutostart;

  VolumeStatus readVolume();

  /// Sessiz modu kapatır, seviyeyi en az [percent] yapar. Değişiklik
  /// olduysa true döner. Hata durumunda istisna fırlatır.
  bool ensureAudible(int percent);

  void preventSleep();

  /// Bilgisayarın (tüm sistemin) boşta kaldığı süre; bilinmiyorsa null.
  Duration? idleTime();

  Future<bool> isAutostartEnabled();
  Future<void> setAutostart(bool enabled);

  factory SystemServices.forPlatform() =>
      Platform.isWindows ? WindowsSystemServices() : const NoopSystemServices();
}

class WindowsSystemServices implements SystemServices {
  static const _runKey = r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run';
  static const _valueName = 'OkulZili';

  /// Bilgisayar açılışında başlatıldığını belirten argüman; uygulama bu
  /// durumda pencereyi göstermeden sistem tepsisinde açılır.
  static const autostartArg = '--autostart';

  @override
  bool get controlsVolume => true;

  @override
  bool get supportsAutostart => true;

  @override
  VolumeStatus readVolume() {
    try {
      final v = WindowsAudio.read();
      return VolumeStatus(level: v.level, muted: v.muted);
    } catch (e) {
      return VolumeStatus(error: '$e');
    }
  }

  @override
  bool ensureAudible(int percent) => WindowsAudio.ensureAudible(percent / 100);

  @override
  void preventSleep() => preventSystemSleep();

  @override
  Duration? idleTime() {
    try {
      return systemIdleTime();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> isAutostartEnabled() async {
    final result = await Process.run('reg', ['query', _runKey, '/v', _valueName]);
    return result.exitCode == 0;
  }

  @override
  Future<void> setAutostart(bool enabled) async {
    final args = enabled
        ? [
            'add', _runKey, '/v', _valueName, '/t', 'REG_SZ',
            '/d', '"${Platform.resolvedExecutable}" $autostartArg', '/f',
          ]
        : ['delete', _runKey, '/v', _valueName, '/f'];
    final result = await Process.run('reg', args);
    if (result.exitCode != 0) {
      throw ProcessException('reg', args, '${result.stderr}'.trim(), result.exitCode);
    }
  }
}

class NoopSystemServices implements SystemServices {
  const NoopSystemServices();

  @override
  bool get controlsVolume => false;

  @override
  bool get supportsAutostart => false;

  @override
  VolumeStatus readVolume() => const VolumeStatus();

  @override
  bool ensureAudible(int percent) => false;

  @override
  void preventSleep() {}

  @override
  Duration? idleTime() => null;

  @override
  Future<bool> isAutostartEnabled() async => false;

  @override
  Future<void> setAutostart(bool enabled) async {}
}
