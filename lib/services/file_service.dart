import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';

class FileService {
  static final FileService instance = FileService._internal();
  FileService._internal();

  Future<bool> _requestStoragePermission() async {
    if (await Permission.storage.isGranted) return true;
    if (await Permission.storage.isPermanentlyDenied) {
      await openAppSettings();
      return false;
    }
    final status = await Permission.storage.request();
    return status.isGranted;
  }

  Future<String?> pickAndCopyImage() async {
    // For Android 13+ photos permission is better, but storage covers many cases
    // await _requestStoragePermission(); // Uncomment if needed

    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty || result.files.first.path == null) {
      return null;
    }

    final pickedFile = result.files.first;
    final appDir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory(p.join(appDir.path, 'images'));
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }

    final extension = p.extension(pickedFile.name);
    final newFileName = 'img_${DateTime.now().millisecondsSinceEpoch}$extension';
    final newPath = p.join(imagesDir.path, newFileName);

    try {
      await File(pickedFile.path!).copy(newPath);
      return newPath;
    } catch (e) {
      debugPrint('Error copying image: $e');
      return null;
    }
  }

  Future<String?> pickAndCopyAudio() async {
    // await _requestStoragePermission();

    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty || result.files.first.path == null) {
      return null;
    }

    final pickedFile = result.files.first;
    final appDir = await getApplicationDocumentsDirectory();
    final audioDir = Directory(p.join(appDir.path, 'audio'));
    if (!await audioDir.exists()) {
      await audioDir.create(recursive: true);
    }

    final extension = p.extension(pickedFile.name);
    final newFileName = 'aud_${DateTime.now().millisecondsSinceEpoch}$extension';
    final newPath = p.join(audioDir.path, newFileName);

    try {
      await File(pickedFile.path!).copy(newPath);
      return newPath;
    } catch (e) {
      debugPrint('Error copying audio: $e');
      return null;
    }
  }

  Future<void> deleteFile(String? path) async {
    if (path == null) return;
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Error deleting file: $e');
    }
  }
}
