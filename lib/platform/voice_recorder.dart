import 'package:record/record.dart';

/// Mikrofondan anons kaydı.
abstract interface class VoiceRecorder {
  /// Mikrofon izni var mı (gerekirse ister).
  Future<bool> hasPermission();

  /// [path]'e WAV olarak kaydetmeye başlar.
  Future<void> start(String path);

  /// Kaydı bitirir; dosya yolunu döndürür (kayıt yoksa null).
  Future<String?> stop();

  /// Kaydı bırakır ve dosyayı siler.
  Future<void> cancel();
}

class MicVoiceRecorder implements VoiceRecorder {
  AudioRecorder? _recorder;

  @override
  Future<bool> hasPermission() async {
    final probe = AudioRecorder();
    try {
      return await probe.hasPermission();
    } finally {
      await probe.dispose();
    }
  }

  @override
  Future<void> start(String path) async {
    await cancel();
    final recorder = _recorder = AudioRecorder();
    // Konuşma için tek kanal 22 kHz yeterli; WAV her Windows'ta çalınır.
    await recorder.start(const RecordConfig(encoder: AudioEncoder.wav, sampleRate: 22050, numChannels: 1), path: path);
  }

  @override
  Future<String?> stop() async {
    final recorder = _recorder;
    _recorder = null;
    if (recorder == null) return null;
    try {
      return await recorder.stop();
    } finally {
      await recorder.dispose();
    }
  }

  @override
  Future<void> cancel() async {
    final recorder = _recorder;
    _recorder = null;
    if (recorder == null) return;
    try {
      await recorder.cancel();
    } finally {
      await recorder.dispose();
    }
  }
}
