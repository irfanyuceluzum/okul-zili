import 'package:file_picker/file_picker.dart';

/// Ses dosyası seçme penceresini açar; vazgeçilirse null döner.
typedef AudioFilePicker = Future<String?> Function();

/// Windows'ta Media Foundation'ın varsayılan olarak çalabildiği biçimler.
const supportedAudioExtensions = ['mp3', 'wav', 'm4a', 'aac', 'wma'];

Future<String?> pickAudioFileWithDialog() async {
  final file = await FilePicker.pickFile(
    dialogTitle: 'Zil sesi seçin',
    type: FileType.custom,
    allowedExtensions: supportedAudioExtensions,
  );
  return file?.path;
}

/// Ses paketinin (ör. İstiklal Marşı, zil sesleri) bulunduğu klasörü seçtirir.
typedef SoundFolderPicker = Future<String?> Function();

Future<String?> pickSoundFolderWithDialog() =>
    FilePicker.getDirectoryPath(dialogTitle: 'Ses dosyalarının bulunduğu klasörü seçin');
