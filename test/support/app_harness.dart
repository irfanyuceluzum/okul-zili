import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okul_zili/app_controller.dart';
import 'package:okul_zili/core/password_hash.dart';
import 'package:okul_zili/data/config_repository.dart';
import 'package:okul_zili/data/default_config.dart';
import 'package:okul_zili/data/models/app_config.dart';
import 'package:okul_zili/main.dart';
import 'package:okul_zili/platform/audio_file_picker.dart';
import 'package:okul_zili/platform/bell_player.dart';
import 'package:okul_zili/platform/config_file_picker.dart';
import 'package:okul_zili/platform/speech.dart';
import 'package:okul_zili/platform/voice_recorder.dart';
import 'package:okul_zili/ui/navigation.dart';

class SilentPlayer implements BellPlayer {
  @override
  Future<void> play(BellSound sound, {required int volumePercent, bool loop = false}) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Stream<void> get completed => const Stream.empty();
}

/// Yazıyı sese çevirmek yerine küçük bir WAV dosyası yazar; çevrilen metinleri kaydeder.
class FakeSpeech implements SpeechSynthesizer {
  FakeSpeech({this.turkish = true});

  final bool? turkish;
  final spoken = <String>[];

  /// Doluysa çeviri bu tamamlanana kadar bekler (yavaş konuşma motoru).
  Completer<void>? gate;

  /// Doluysa çeviri bu hatayla başarısız olur.
  Object? failWith;

  @override
  Future<String> synthesize(String text, String outBase) async {
    spoken.add(text);
    await gate?.future;
    if (failWith != null) throw failWith!;
    final out = '$outBase.wav';
    File(out).writeAsBytesSync([82, 73, 70, 70, 0, 0, 0, 0]);
    return out;
  }

  @override
  Future<bool?> hasTurkishVoice() async => turkish;
}

/// Mikrofon yerine: başlatınca dosyayı oluşturur, durdurunca yolunu döndürür.
class FakeRecorder implements VoiceRecorder {
  FakeRecorder({this.allowed = true});

  bool allowed;
  String? _path;

  @override
  Future<bool> hasPermission() async => allowed;

  @override
  Future<void> start(String path) async {
    _path = path;
    File(path).writeAsBytesSync([0, 1, 2, 3]);
  }

  @override
  Future<String?> stop() async {
    final path = _path;
    _path = null;
    return path;
  }

  @override
  Future<void> cancel() async {
    final path = _path;
    _path = null;
    if (path != null && File(path).existsSync()) File(path).deleteSync();
  }
}

/// Testlerde isolate'sız, 1000 iterasyonlu hızlı parola hesabı.
class FastPasswordHasher implements PasswordHasher {
  const FastPasswordHasher();

  @override
  Future<PasswordRecord> create(String secret) async => PasswordHash.create(secret, iterations: 1000);

  @override
  Future<bool> verify(String secret, PasswordRecord record) async => PasswordHash.verify(secret, record);
}

/// Hangi sesin, döngüde mi çalındığını ve kaç kez durdurulduğunu kaydeder.
class RecordingPlayer implements BellPlayer {
  final plays = <({String id, bool loop})>[];
  int stops = 0;

  /// Bu kimlikteki ses çalınmak istenince hata fırlatır (bozuk dosya).
  String? failFor;

  @override
  Future<void> play(BellSound sound, {required int volumePercent, bool loop = false}) async {
    if (sound.id == failFor) throw Exception('çözülemeyen ses biçimi');
    plays.add((id: sound.id, loop: loop));
  }

  @override
  Future<void> stop() async => stops++;

  int pauses = 0;
  int resumes = 0;

  @override
  Future<void> pause() async => pauses++;

  @override
  Future<void> resume() async => resumes++;

  final _completed = StreamController<void>.broadcast(sync: true);

  @override
  Stream<void> get completed => _completed.stream;

  /// Çalan sesin kendiliğinden bittiğini taklit eder.
  void finish() => _completed.add(null);
}

/// Ölçüler gerçekçi olsun diye uygulamanın yazı tipini yükler (varsayılan
/// test yazı tipi her harfi kare çizer ve olmayan taşmalar üretir).
Future<void> loadAppFont() async {
  final loader = FontLoader('IBM Plex Sans');
  for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    final bytes = File('assets/fonts/IBMPlexSans-$weight.ttf').readAsBytesSync();
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
}

/// Uygulamayı geçici bir ayar klasörü ve sabit saatle açar.
Future<(AppController, ValueNotifier<AppPage>)> pumpOkulZili(
  WidgetTester tester, {
  required DateTime now,
  AppPage page = AppPage.home,
  AppConfig? config,
  Size size = const Size(1280, 820),
  BellPlayer? player,
  AudioFilePicker? pickAudioFile,
  SoundFolderPicker? pickSoundFolder,
  ConfigFilePicker? pickConfigFile,
  ExportPathPicker? pickExportPath,
  PasswordHasher? passwordHasher,
  SpeechSynthesizer? speech,
  VoiceRecorder? recorder,

  /// Verilirse [now] yerine bu saat kullanılır (testte ileri sarmak için).
  DateTime Function()? clock,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final tmp = Directory.systemTemp.createTempSync('okul_zili_test');
  addTearDown(() {
    // Windows, dosya hâlâ yazılırken klasörü silmeye izin vermez.
    try {
      tmp.deleteSync(recursive: true);
    } on FileSystemException catch (_) {}
  });

  final controller = AppController(
    config: config ?? createDefaultConfig(),
    repository: ConfigRepository(File('${tmp.path}/config.json')),
    player: player ?? SilentPlayer(),
    now: clock ?? () => now,
    pickAudioFile: pickAudioFile,
    pickSoundFolder: pickSoundFolder,
    pickConfigFile: pickConfigFile,
    pickExportPath: pickExportPath,
    passwordHasher: passwordHasher ?? const FastPasswordHasher(),
    speech: speech ?? FakeSpeech(),
    recorder: recorder ?? FakeRecorder(),
  );
  final navigation = ValueNotifier(page);
  await tester.pumpWidget(OkulZiliApp(
    controller: controller,
    navigation: navigation,
    windowControls: const NoopWindowControls(),
  ));
  await tester.pumpAndSettle();
  return (controller, navigation);
}

/// Kaydırıp görünür yaptıktan sonra dokunur.
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}
