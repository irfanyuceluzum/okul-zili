import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okul_zili/app_controller.dart';
import 'package:okul_zili/data/config_repository.dart';
import 'package:okul_zili/data/default_config.dart';
import 'package:okul_zili/data/models/app_config.dart';
import 'package:okul_zili/main.dart';
import 'package:okul_zili/platform/audio_file_picker.dart';
import 'package:okul_zili/platform/bell_player.dart';
import 'package:okul_zili/ui/navigation.dart';

class SilentPlayer implements BellPlayer {
  @override
  Future<void> play(BellSound sound, {required int volumePercent, bool loop = false}) async {}

  @override
  Future<void> stop() async {}
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
