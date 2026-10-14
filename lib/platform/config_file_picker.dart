import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

/// İçe aktarılacak ayar (.json) dosyasını seçtirir; vazgeçilirse null.
typedef ConfigFilePicker = Future<String?> Function();

/// Ayarların yazılacağı dosya yolunu seçtirir; vazgeçilirse null.
typedef ExportPathPicker = Future<String?> Function();

Future<String?> pickConfigFileWithDialog() async {
  final file = await FilePicker.pickFile(
    dialogTitle: 'Ayar dosyasını seçin',
    type: FileType.custom,
    allowedExtensions: const ['json'],
  );
  return file?.path;
}

Future<String?> pickExportPathWithDialog() async {
  // Masaüstünde dosyayı kendimiz yazarız; pencere yalnız yolu seçtirir.
  final uri = await FilePicker.saveFile(
    fileName: 'okul-zili-ayarlar.json',
    bytes: Uint8List.fromList(utf8.encode('{}')),
    dialogTitle: 'Ayarları kaydet',
    type: FileType.custom,
    allowedExtensions: const ['json'],
  );
  return uri?.scheme == 'file' ? uri!.toFilePath() : uri?.path;
}
