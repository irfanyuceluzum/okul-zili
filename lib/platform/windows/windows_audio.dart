import 'dart:ffi';

import 'package:ffi/ffi.dart';

/// Windows Core Audio (IAudioEndpointVolume) ile varsayılan hoparlörün
/// ses seviyesini ve sessiz durumunu okur/değiştirir.
///
/// Hazır paketler sessiz modu kapatamadığı için COM arayüzü doğrudan
/// sanal tablo (vtable) üzerinden çağrılır. Her çağrı COM'u kendi içinde
/// başlatıp kapatır; böylece hangi iş parçacığında çalıştığı önemli olmaz.
class WindowsAudio {
  static final _ole32 = DynamicLibrary.open('ole32.dll');

  static final _coInitializeEx = _ole32.lookupFunction<
      Int32 Function(Pointer<Void>, Uint32),
      int Function(Pointer<Void>, int)>('CoInitializeEx');
  static final _coUninitialize =
      _ole32.lookupFunction<Void Function(), void Function()>('CoUninitialize');
  static final _coCreateInstance = _ole32.lookupFunction<
      Int32 Function(Pointer<_Guid>, Pointer<Void>, Uint32, Pointer<_Guid>,
          Pointer<Pointer<Void>>),
      int Function(Pointer<_Guid>, Pointer<Void>, int, Pointer<_Guid>,
          Pointer<Pointer<Void>>)>('CoCreateInstance');

  static const _clsidMMDeviceEnumerator = 'BCDE0395-E52F-467C-8E3D-C4579291692E';
  static const _iidIMMDeviceEnumerator = 'A95664D2-9614-4F35-A746-DE8DB63617E6';
  static const _iidIAudioEndpointVolume = '5CDF2C82-841E-4546-9722-0CF74078229A';

  static const _coinitApartmentThreaded = 0x2;
  static const _clsctxAll = 0x17;
  static const _eRender = 0;
  static const _eMultimedia = 1;

  /// Ses seviyesi (0.0–1.0) ve sessiz durumu.
  static ({double level, bool muted}) read() => _withEndpointVolume((volume) {
        return using((arena) {
          final level = arena<Float>();
          final muted = arena<Int32>();
          _check(_getMasterVolumeLevelScalar(volume)(volume, level),
              'GetMasterVolumeLevelScalar');
          _check(_getMute(volume)(volume, muted), 'GetMute');
          return (level: level.value, muted: muted.value != 0);
        });
      });

  /// Sessiz modu kapatır ve seviye [minLevel] altındaysa ona yükseltir.
  /// Bir şey değiştiyse true döner.
  static bool ensureAudible(double minLevel) => _withEndpointVolume((volume) {
        return using((arena) {
          var changed = false;
          final muted = arena<Int32>();
          _check(_getMute(volume)(volume, muted), 'GetMute');
          if (muted.value != 0) {
            _check(_setMute(volume)(volume, 0, nullptr), 'SetMute');
            changed = true;
          }
          final level = arena<Float>();
          _check(_getMasterVolumeLevelScalar(volume)(volume, level),
              'GetMasterVolumeLevelScalar');
          if (level.value + 0.005 < minLevel) {
            _check(
                _setMasterVolumeLevelScalar(volume)(
                    volume, minLevel.clamp(0.0, 1.0), nullptr),
                'SetMasterVolumeLevelScalar');
            changed = true;
          }
          return changed;
        });
      });

  static T _withEndpointVolume<T>(T Function(Pointer<Void> volume) body) {
    final initHr = _coInitializeEx(nullptr, _coinitApartmentThreaded);
    // S_OK (0) ve S_FALSE (1) dengelenmeli; RPC_E_CHANGED_MODE ise COM
    // zaten başka kipte açık demektir, kapatmamalıyız.
    final mustUninit = initHr == 0 || initHr == 1;
    try {
      return using((arena) {
        final enumeratorOut = arena<Pointer<Void>>();
        _check(
          _coCreateInstance(
            _guid(arena, _clsidMMDeviceEnumerator),
            nullptr,
            _clsctxAll,
            _guid(arena, _iidIMMDeviceEnumerator),
            enumeratorOut,
          ),
          'CoCreateInstance(MMDeviceEnumerator)',
        );
        final enumerator = enumeratorOut.value;
        try {
          final deviceOut = arena<Pointer<Void>>();
          _check(
            _getDefaultAudioEndpoint(enumerator)(
                enumerator, _eRender, _eMultimedia, deviceOut),
            'GetDefaultAudioEndpoint',
          );
          final device = deviceOut.value;
          try {
            final volumeOut = arena<Pointer<Void>>();
            _check(
              _activate(device)(device, _guid(arena, _iidIAudioEndpointVolume),
                  _clsctxAll, nullptr, volumeOut),
              'IMMDevice.Activate',
            );
            final volume = volumeOut.value;
            try {
              return body(volume);
            } finally {
              _release(volume);
            }
          } finally {
            _release(device);
          }
        } finally {
          _release(enumerator);
        }
      });
    } finally {
      if (mustUninit) _coUninitialize();
    }
  }

  static void _check(int hr, String what) {
    if (hr < 0) {
      final code = (hr & 0xFFFFFFFF).toRadixString(16).toUpperCase();
      // 0x80070490: varsayılan ses aygıtı yok (hoparlör takılı değil).
      if (code == '80070490') throw const WindowsAudioException('Ses aygıtı bulunamadı');
      throw WindowsAudioException('$what başarısız (0x$code)');
    }
  }

  // ---- COM sanal tablo çağrıları ------------------------------------------

  static Pointer<IntPtr> _vtable(Pointer<Void> obj) =>
      obj.cast<Pointer<IntPtr>>().value;

  static Pointer<NativeFunction<T>> _slot<T extends Function>(
          Pointer<Void> obj, int index) =>
      Pointer<NativeFunction<T>>.fromAddress(_vtable(obj)[index]);

  static void _release(Pointer<Void> obj) {
    if (obj == nullptr) return;
    _slot<Uint32 Function(Pointer<Void>)>(obj, 2)
        .asFunction<int Function(Pointer<Void>)>()(obj);
  }

  // IMMDeviceEnumerator::GetDefaultAudioEndpoint (4)
  static int Function(Pointer<Void>, int, int, Pointer<Pointer<Void>>)
      _getDefaultAudioEndpoint(Pointer<Void> obj) => _slot<
                  Int32 Function(
                      Pointer<Void>, Int32, Int32, Pointer<Pointer<Void>>)>(
              obj, 4)
          .asFunction();

  // IMMDevice::Activate (3)
  static int Function(
          Pointer<Void>, Pointer<_Guid>, int, Pointer<Void>, Pointer<Pointer<Void>>)
      _activate(Pointer<Void> obj) => _slot<
              Int32 Function(Pointer<Void>, Pointer<_Guid>, Uint32,
                  Pointer<Void>, Pointer<Pointer<Void>>)>(obj, 3)
          .asFunction();

  // IAudioEndpointVolume::SetMasterVolumeLevelScalar (7)
  static int Function(Pointer<Void>, double, Pointer<_Guid>)
      _setMasterVolumeLevelScalar(Pointer<Void> obj) => _slot<
              Int32 Function(Pointer<Void>, Float, Pointer<_Guid>)>(obj, 7)
          .asFunction();

  // IAudioEndpointVolume::GetMasterVolumeLevelScalar (9)
  static int Function(Pointer<Void>, Pointer<Float>)
      _getMasterVolumeLevelScalar(Pointer<Void> obj) =>
          _slot<Int32 Function(Pointer<Void>, Pointer<Float>)>(obj, 9)
              .asFunction();

  // IAudioEndpointVolume::SetMute (14)
  static int Function(Pointer<Void>, int, Pointer<_Guid>) _setMute(
          Pointer<Void> obj) =>
      _slot<Int32 Function(Pointer<Void>, Int32, Pointer<_Guid>)>(obj, 14)
          .asFunction();

  // IAudioEndpointVolume::GetMute (15)
  static int Function(Pointer<Void>, Pointer<Int32>) _getMute(
          Pointer<Void> obj) =>
      _slot<Int32 Function(Pointer<Void>, Pointer<Int32>)>(obj, 15)
          .asFunction();

  static Pointer<_Guid> _guid(Arena arena, String text) {
    final hex = text.replaceAll('-', '');
    final guid = arena<_Guid>();
    guid.ref
      ..data1 = int.parse(hex.substring(0, 8), radix: 16)
      ..data2 = int.parse(hex.substring(8, 12), radix: 16)
      ..data3 = int.parse(hex.substring(12, 16), radix: 16);
    for (var i = 0; i < 8; i++) {
      guid.ref.data4[i] = int.parse(hex.substring(16 + i * 2, 18 + i * 2), radix: 16);
    }
    return guid;
  }
}

final class _Guid extends Struct {
  @Uint32()
  external int data1;
  @Uint16()
  external int data2;
  @Uint16()
  external int data3;
  @Array(8)
  external Array<Uint8> data4;
}

class WindowsAudioException implements Exception {
  const WindowsAudioException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Bilgisayarın boşta kalınca uyku moduna geçmesini engeller (ekranın
/// kapanmasına izin verir). Uygulama açık kaldığı sürece geçerlidir.
void preventSystemSleep() {
  final kernel32 = DynamicLibrary.open('kernel32.dll');
  final setThreadExecutionState = kernel32.lookupFunction<
      Uint32 Function(Uint32), int Function(int)>('SetThreadExecutionState');
  const esContinuous = 0x80000000;
  const esSystemRequired = 0x00000001;
  setThreadExecutionState(esContinuous | esSystemRequired);
}
