import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A file chosen by the user, already read into memory (works the same on Android and web).
class PickedFile {
  const PickedFile({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

/// Opening and saving files. Screens depend on this interface, not on the plugin.
abstract interface class FileService {
  /// Lets the user choose an `.xlsx` file. Returns null when the user cancels.
  Future<PickedFile?> pickSpreadsheet();

  /// Lets the user choose an image (photo of a product). Returns null when the user cancels.
  Future<PickedFile?> pickImage();

  /// Saves [bytes] (web: browser download; Android: system "save as" screen).
  /// Returns false when the user cancels.
  Future<bool> save({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
  });
}

class FilePickerFileService implements FileService {
  const FilePickerFileService();

  @override
  Future<PickedFile?> pickSpreadsheet() async {
    final file = await FilePicker.pickFile(
      dialogTitle: 'Selecione a planilha de vendas',
      type: FileType.custom,
      allowedExtensions: const ['xlsx'],
    );
    if (file == null) return null;

    return PickedFile(name: file.name, bytes: await file.readAsBytes());
  }

  @override
  Future<PickedFile?> pickImage() async {
    final file = await FilePicker.pickFile(
      dialogTitle: 'Selecione a imagem do produto',
      type: FileType.image,
    );
    if (file == null) return null;

    return PickedFile(name: file.name, bytes: await file.readAsBytes());
  }

  @override
  Future<bool> save({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    final uri = await FilePicker.saveFile(
      fileName: fileName,
      bytes: bytes,
      mimeType: mimeType,
    );
    return uri != null;
  }
}

final fileServiceProvider = Provider<FileService>(
  (ref) => const FilePickerFileService(),
);
