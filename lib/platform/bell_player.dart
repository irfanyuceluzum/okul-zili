import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

import '../data/models/app_config.dart';

abstract interface class BellPlayer {
  /// [loop] true ise [stop] çağrılana kadar tekrar eder (acil durum sireni).
  Future<void> play(BellSound sound, {required int volumePercent, bool loop = false});
  Future<void> stop();
}

class AudioBellPlayer implements BellPlayer {
  final AudioPlayer _player = AudioPlayer(playerId: 'okul-zili');

  /// Komutlar sırayla yürütülür. Aynı anda iki çalma (ör. zil saniyesinde
  /// önizleme) adımları iç içe geçip sesi yanlış döngü kipinde bırakmasın.
  Future<void> _queue = Future.value();

  /// Ses sistemi bir komutta takılırsa sıra kilitlenip sonraki ziller
  /// çalmamazlık etmesin.
  static const _commandTimeout = Duration(seconds: 10);

  Future<void> _enqueue(Future<void> Function() action) {
    final next = _queue.then((_) => action().timeout(_commandTimeout));
    _queue = next.catchError((_) {});
    return next;
  }

  @override
  Future<void> play(BellSound sound, {required int volumePercent, bool loop = false}) => _enqueue(() async {
        await _player.stop();
        await _player.setReleaseMode(loop ? ReleaseMode.loop : ReleaseMode.stop);
        await _player.setVolume(volumePercent.clamp(0, 100) / 100);
        final source = sound.isAsset ? AssetSource(sound.path) : DeviceFileSource(sound.path);
        await _player.play(source);
      });

  @override
  Future<void> stop() => _enqueue(_player.stop);
}
