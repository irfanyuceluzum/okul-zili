import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Yazıyı ses dosyasına çevirir; anons dosyası da zil sesleri gibi çalınır
/// (duraklatma, bitiş bildirimi, ses düzeyi aynı yoldan).
abstract interface class SpeechSynthesizer {
  /// [text]'i uzantısız [outBase] yoluna yazar; oluşan dosyanın yolunu döndürür.
  Future<String> synthesize(String text, String outBase);

  /// Bu bilgisayarda Türkçe konuşma sesi var mı; öğrenilemezse null.
  Future<bool?> hasTurkishVoice();
}

/// Windows'ta işletim sisteminin konuşma motoru (PowerShell ile; Türkçe ses
/// varsa o seçilir), macOS'ta `say`. Ek paket gerektirmez.
class SystemSpeechSynthesizer implements SpeechSynthesizer {
  const SystemSpeechSynthesizer();

  static const _timeout = Duration(seconds: 60);

  @override
  Future<String> synthesize(String text, String outBase) async {
    final input = File('$outBase.txt');
    // Metin dosyayla verilir: tırnak ve Türkçe harfler komut satırında bozulmasın.
    input.writeAsStringSync(text, encoding: utf8);
    try {
      if (Platform.isWindows) {
        final out = '$outBase.wav';
        final script = File('$outBase.ps1')..writeAsStringSync(_windowsScript, encoding: utf8);
        try {
          final r = await Process.run('powershell.exe', [
            '-NoProfile',
            '-NonInteractive',
            '-ExecutionPolicy',
            'Bypass',
            '-File',
            script.path,
            input.path,
            out,
          ]).timeout(_timeout);
          _check(r, out);
        } finally {
          _tryDelete(script);
        }
        return out;
      }
      if (Platform.isMacOS) {
        final out = '$outBase.aiff';
        final turkish = await hasTurkishVoice() ?? false;
        final r = await Process.run('say', [if (turkish) ...['-v', 'Yelda'], '-o', out, '-f', input.path]).timeout(_timeout);
        _check(r, out);
        return out;
      }
      throw UnsupportedError('Bu sistemde yazıdan okuma yok');
    } finally {
      _tryDelete(input);
    }
  }

  static void _check(ProcessResult r, String out) {
    if (r.exitCode != 0 || !File(out).existsSync() || File(out).lengthSync() == 0) {
      final detail = '${r.stderr}'.trim().isEmpty ? '${r.stdout}'.trim() : '${r.stderr}'.trim();
      throw Exception('Yazı sese çevrilemedi${detail.isEmpty ? '' : ': $detail'}');
    }
  }

  static void _tryDelete(File f) {
    try {
      if (f.existsSync()) f.deleteSync();
    } catch (_) {}
  }

  @override
  Future<bool?> hasTurkishVoice() async {
    try {
      if (Platform.isWindows) {
        final r = await Process.run('powershell.exe', [
          '-NoProfile',
          '-NonInteractive',
          '-Command',
          _windowsVoicesCommand,
        ]).timeout(_timeout);
        if (r.exitCode != 0) return null;
        return '${r.stdout}'.toLowerCase().split(RegExp(r'\s+')).any((l) => l.startsWith('tr'));
      }
      if (Platform.isMacOS) {
        final r = await Process.run('say', ['-v', '?']).timeout(_timeout);
        return '${r.stdout}'.contains('tr_TR');
      }
    } catch (_) {}
    return null;
  }

  /// Windows 10/11: WinRT konuşma motoru (Türkçe "Tolga" gibi OneCore sesleri
  /// görür); olmazsa eski SAPI motoru. Girdi UTF-8 metin dosyası, çıktı WAV.
  static const _windowsScript = r'''
param([string]$InPath, [string]$OutPath)
$ErrorActionPreference = 'Stop'
$text = [IO.File]::ReadAllText($InPath, [Text.Encoding]::UTF8)
try {
  Add-Type -AssemblyName System.Runtime.WindowsRuntime
  $null = [Windows.Media.SpeechSynthesis.SpeechSynthesizer, Windows.Media.SpeechSynthesis, ContentType = WindowsRuntime]
  $null = [Windows.Storage.Streams.DataReader, Windows.Storage.Streams, ContentType = WindowsRuntime]
  $asTask = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
    $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'
  } | Select-Object -First 1
  function Await($op, [Type]$type) {
    $task = $asTask.MakeGenericMethod($type).Invoke($null, @($op))
    $null = $task.Wait(-1)
    $task.Result
  }
  $synth = New-Object Windows.Media.SpeechSynthesis.SpeechSynthesizer
  $voice = [Windows.Media.SpeechSynthesis.SpeechSynthesizer]::AllVoices | Where-Object { $_.Language -like 'tr*' } | Select-Object -First 1
  if ($voice) { $synth.Voice = $voice }
  $stream = Await ($synth.SynthesizeTextToStreamAsync($text)) ([Windows.Media.SpeechSynthesis.SpeechSynthesisStream])
  $reader = New-Object Windows.Storage.Streams.DataReader($stream)
  $null = Await ($reader.LoadAsync([uint32]$stream.Size)) ([uint32])
  $bytes = New-Object byte[] ([int]$stream.Size)
  $reader.ReadBytes($bytes)
  [IO.File]::WriteAllBytes($OutPath, $bytes)
} catch {
  Add-Type -AssemblyName System.Speech
  $sapi = New-Object System.Speech.Synthesis.SpeechSynthesizer
  $tr = $sapi.GetInstalledVoices() | Where-Object { $_.VoiceInfo.Culture.Name -like 'tr*' } | Select-Object -First 1
  if ($tr) { $sapi.SelectVoice($tr.VoiceInfo.Name) }
  $sapi.SetOutputToWaveFile($OutPath)
  $sapi.Speak($text)
  $sapi.Dispose()
}
''';

  static const _windowsVoicesCommand = r'''
try {
  Add-Type -AssemblyName System.Runtime.WindowsRuntime
  $null = [Windows.Media.SpeechSynthesis.SpeechSynthesizer, Windows.Media.SpeechSynthesis, ContentType = WindowsRuntime]
  [Windows.Media.SpeechSynthesis.SpeechSynthesizer]::AllVoices | ForEach-Object { $_.Language }
} catch {}
try {
  Add-Type -AssemblyName System.Speech
  (New-Object System.Speech.Synthesis.SpeechSynthesizer).GetInstalledVoices() | ForEach-Object { $_.VoiceInfo.Culture.Name }
} catch {}
''';
}
