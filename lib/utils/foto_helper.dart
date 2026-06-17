import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

class FotoHelper {
  static const _prefsKey = 'calibracion_fotos_base_path';
  static const _subdirName = 'calibracion_fotos';

  static Future<bool> isConfigured() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_prefsKey);
    if (path == null || path.isEmpty) return false;
    return Directory(path).existsSync();
  }

  static Future<String?> configure() async {
    final path = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Seleccione o cree la carpeta ServiceMET',
    );
    if (path == null) return null;

    final dir = Directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final fotosDir = Directory(p.join(path, _subdirName));
    if (!await fotosDir.exists()) {
      await fotosDir.create(recursive: true);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, path);
    return path;
  }

  static Future<Directory> getBaseDir() async {
    final prefs = await SharedPreferences.getInstance();
    final basePath = prefs.getString(_prefsKey);
    if (basePath == null || basePath.isEmpty) {
      throw FotoStorageNotConfiguredError();
    }
    final dir = Directory(p.join(basePath, _subdirName));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<Directory> getInstrumentoDir(
      String seca, String codMetrica) async {
    final base = await getBaseDir();
    final dir = Directory(p.join(base.path, seca, codMetrica));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<String> saveFoto(
      String seca, String codMetrica, String sourcePath) async {
    final dir = await getInstrumentoDir(seca, codMetrica);
    final existing = await dir.list().toList();
    final nextIndex = existing.length + 1;
    final ext = p.extension(sourcePath);
    final fileName =
        '${nextIndex.toString().padLeft(3, '0')}${ext.isNotEmpty ? ext : '.jpg'}';
    final destPath = p.join(dir.path, fileName);
    await File(sourcePath).copy(destPath);
    return destPath;
  }

  static Future<void> deleteFoto(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }
}

class FotoStorageNotConfiguredError implements Exception {
  @override
  String toString() => 'Almacenamiento de fotos no configurado';
}
