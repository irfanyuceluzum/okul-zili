import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:okul_zili/platform/speech.dart';

/// Gerçek konuşma motoru: Windows'ta PowerShell betiği (CI'da koşar), macOS'ta `say`.
void main() {
  final supported = Platform.isWindows || Platform.isMacOS;

  test('yazı ses dosyasına çevrilir (Türkçe harfler ve tırnak dahil)', () async {
    final dir = Directory.systemTemp.createTempSync('okul_zili_okuma');
    addTearDown(() {
      try {
        dir.deleteSync(recursive: true);
      } on FileSystemException catch (_) {}
    });
    const synth = SystemSpeechSynthesizer();
    final out = await synth.synthesize('Sayın öğretmenlerimiz, "toplantı" saat on beşte.', '${dir.path}/deneme');
    final bytes = File(out).readAsBytesSync();
    expect(bytes.length, greaterThan(1000));
    // WAV "RIFF", AIFF "FORM" ile başlar.
    expect(String.fromCharCodes(bytes.take(4)), anyOf('RIFF', 'FORM'));
    expect(dir.listSync().where((f) => f.path.endsWith('.txt') || f.path.endsWith('.ps1')), isEmpty,
        reason: 'geçici metin ve betik dosyaları silinir');
    // ignore: avoid_print
    print('Türkçe ses: ${await synth.hasTurkishVoice()}');
  }, skip: supported ? false : 'yalnız Windows ve macOS', timeout: const Timeout(Duration(minutes: 2)));
}
