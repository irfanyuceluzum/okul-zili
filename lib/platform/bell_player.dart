import 'package:audioplayers/audioplayers.dart';

import '../data/models/app_config.dart';

abstract interface class BellPlayer {
  /// [loop] true ise [stop] çağrılana kadar tekrar eder (acil durum sireni).
  Future<void> play(BellSound sound, {required int volumePercent, bool loop = false});
  Future<void> stop();
}

class AudioBellPlayer implements BellPlayer {
  final AudioPlayer _player = AudioPlayer(playerId: 'okul-zili');

  @override
  Future<void> play(BellSound sound, {required int volumePercent, bool loop = false}) async {
    await _player.stop();
    await _player.setReleaseMode(loop ? ReleaseMode.loop : ReleaseMode.stop);
    await _player.setVolume(volumePercent.clamp(0, 100) / 100);
    final source = sound.isAsset
        ? AssetSource(sound.path)
        : DeviceFileSource(sound.path);
    await _player.play(source);
  }

  @override
  Future<void> stop() => _player.stop();
}
