import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FotoHelper {
  static const _prefsKey = 'calibracion_fotos_base_path';

  static Future<bool> isConfigured(
      {String subDirName = 'calibracion_fotos'}) async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_prefsKey);
    if (path == null || path.isEmpty) return false;

    final directory = Directory(path);
    if (!await directory.exists()) return false;

    // En Android una carpeta puede seguir existiendo aunque el permiso para
    // escribir en ella haya sido revocado. La prueba evita abrir la cámara y
    // descubrir el problema recién después de tomar la fotografía.
    final probe = File(p.join(
      directory.path,
      '.servicemet_write_${DateTime.now().microsecondsSinceEpoch}.tmp',
    ));
    try {
      await probe.writeAsString('ok', flush: true);
      await probe.delete();
      return true;
    } on FileSystemException {
      return false;
    }
  }

  static Future<String?> configure(
      {String subDirName = 'calibracion_fotos'}) async {
    if (Platform.isAndroid && !await _requestAndroidStorageAccess()) {
      return null;
    }

    final path = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Seleccione o cree la carpeta ServiceMET',
    );
    if (path == null) return null;

    final dir = Directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final fotosDir = Directory(p.join(path, subDirName));
    if (!await fotosDir.exists()) {
      await fotosDir.create(recursive: true);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, path);
    return path;
  }

  static Future<bool> _requestAndroidStorageAccess() async {
    if (await Permission.manageExternalStorage.isGranted) return true;

    final manageStatus = await Permission.manageExternalStorage.request();
    if (manageStatus.isGranted) return true;

    // Compatibilidad con versiones de Android anteriores al almacenamiento
    // con alcance (scoped storage).
    final storageStatus = await Permission.storage.request();
    return storageStatus.isGranted;
  }

  static Future<String> getBasePath() async {
    final prefs = await SharedPreferences.getInstance();
    final basePath = prefs.getString(_prefsKey);
    if (basePath == null || basePath.isEmpty) {
      throw FotoStorageNotConfiguredError();
    }
    return basePath;
  }

  static Future<Directory> getBaseDir(
      {String subDirName = 'calibracion_fotos'}) async {
    final basePath = await getBasePath();
    final dir = Directory(p.join(basePath, subDirName));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<Directory> getInstrumentoDir(String seca, String codMetrica,
      {String subDirName = 'calibracion_fotos'}) async {
    final base = await getBaseDir(subDirName: subDirName);
    final dir = Directory(p.join(base.path, seca, codMetrica));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<String> saveFoto(
      String seca, String codMetrica, String sourcePath,
      {String subDirName = 'calibracion_fotos'}) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw const FileSystemException(
        'La cámara no devolvió un archivo de imagen válido',
      );
    }

    final dir =
        await getInstrumentoDir(seca, codMetrica, subDirName: subDirName);
    final existing = await dir
        .list()
        .where((entity) => entity is File)
        .map((entity) => p.basenameWithoutExtension(entity.path))
        .map(int.tryParse)
        .where((index) => index != null)
        .cast<int>()
        .toList();
    final nextIndex = existing.isEmpty
        ? 1
        : existing.reduce((current, next) => current > next ? current : next) +
            1;
    final ext = p.extension(sourcePath);
    final fileName =
        '${nextIndex.toString().padLeft(3, '0')}${ext.isNotEmpty ? ext : '.jpg'}';
    final destPath = p.join(dir.path, fileName);
    await source.copy(destPath);
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
