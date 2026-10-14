import 'dart:io';

import 'package:flutter/foundation.dart';

/// Beklenmeyen hataları ayar klasöründeki `hata_kayitlari.log` dosyasına
/// yazar. Yayın derlemesinde konsol görünmediği için okul bilgisayarında
/// sorun incelemenin tek yolu budur.
abstract final class ErrorLog {
  static File? _file;

  static void init(Directory dir) {
    _file = File('${dir.path}${Platform.pathSeparator}hata_kayitlari.log');
  }

  static void write(String where, Object error, [StackTrace? stack]) {
    debugPrint('[Hata] $where: $error');
    try {
      _file?.writeAsStringSync(
        '${DateTime.now().toIso8601String()}\t$where\t$error\n${stack ?? ''}\n',
        mode: FileMode.append,
        flush: true,
      );
    } catch (_) {
      // Hata kaydı yazılamıyorsa yapacak bir şey yok; uygulama sürsün.
    }
  }
}
