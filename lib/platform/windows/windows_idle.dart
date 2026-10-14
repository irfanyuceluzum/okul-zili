import 'dart:ffi';

import 'package:ffi/ffi.dart';

/// Bilgisayara en son fare/klavye ile dokunulmasından bu yana geçen süre
/// (yalnızca bu uygulama değil, tüm sistem).
Duration systemIdleTime() {
  final user32 = DynamicLibrary.open('user32.dll');
  final kernel32 = DynamicLibrary.open('kernel32.dll');
  final getLastInputInfo = user32.lookupFunction<
      Int32 Function(Pointer<_LastInputInfo>),
      int Function(Pointer<_LastInputInfo>)>('GetLastInputInfo');
  final getTickCount =
      kernel32.lookupFunction<Uint32 Function(), int Function()>('GetTickCount');

  return using((arena) {
    final info = arena<_LastInputInfo>();
    info.ref.cbSize = sizeOf<_LastInputInfo>();
    if (getLastInputInfo(info) == 0) {
      throw StateError('GetLastInputInfo başarısız');
    }
    // İki sayaç da 49 günde bir sıfırlanır; fark 32 bitte hesaplanır.
    final elapsed = (getTickCount() - info.ref.dwTime) & 0xFFFFFFFF;
    return Duration(milliseconds: elapsed);
  });
}

final class _LastInputInfo extends Struct {
  @Uint32()
  external int cbSize;
  @Uint32()
  external int dwTime;
}
