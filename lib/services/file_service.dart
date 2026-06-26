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

  /// Gera uma envoltória de amplitude (0..1) para desenhar o waveform.
  /// Lê os bytes do arquivo e calcula a magnitude média por bloco.
  /// Para áudio comprimido é uma aproximação visual estável (não o PCM real),
  /// mas serve bem como guia de corte por tempo.
  Future<List<double>> buildWaveformBars(String path, {int buckets = 120}) async {
    try {
      final file = File(path);
      if (!await file.exists()) return [];
      final bytes = await file.readAsBytes();
      final n = bytes.length;
      if (n == 0) return [];

      // Pula o cabeçalho (até ~1KB) que costuma ser metadado, não áudio.
      final headerSkip = n > 2048 ? 1024 : 0;
      final usable = n - headerSkip;
      final per = (usable / buckets).ceil().clamp(1, usable);
      // Amostra com passo para não varrer arquivos grandes byte a byte.
      final stride = (per / 64).ceil().clamp(1, per);

      final raw = <double>[];
      for (int b = 0; b < buckets; b++) {
        final from = headerSkip + b * per;
        if (from >= n) {
          raw.add(0);
          continue;
        }
        final to = (from + per) < n ? (from + per) : n;
        double sum = 0;
        int cnt = 0;
        for (int i = from; i < to; i += stride) {
          sum += (bytes[i] - 128).abs();
          cnt++;
        }
        raw.add(cnt > 0 ? (sum / cnt) / 128.0 : 0);
      }

      double maxV = 0.0001;
      for (final v in raw) {
        if (v > maxV) maxV = v;
      }
      return raw.map((v) => (v / maxV).clamp(0.05, 1.0)).toList();
    } catch (e) {
      debugPrint('Error building waveform: $e');
      return [];
    }
  }
}
