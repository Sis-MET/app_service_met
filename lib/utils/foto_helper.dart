import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'saf_storage.dart';

/// Almacenamiento local de las fotografías de cada servicio.
///
/// Las fotos se guardan en el almacenamiento específico de la aplicación
/// (`Android/data/bo.metrica.smet/files/ServiceMET`). Ese directorio no exige
/// ningún permiso en ninguna versión de Android, cumple con Scoped Storage y
/// funciona completamente sin conexión, que es como trabajan los técnicos en
/// campo.
///
/// La estructura es `ServiceMET/{codigo_servicio}/{modulo}/{cod_metrica}/`, de
/// modo que exportar un servicio a la carpeta SAF del técnico es copiar una
/// sola carpeta. Ver [SafStorage] y `ServiceExporter`.
class FotoHelper {
  /// Clave usada por versiones anteriores (≤ 6.2.0), cuando las fotos se
  /// escribían en una carpeta pública con MANAGE_EXTERNAL_STORAGE.
  static const _legacyPrefsKey = 'calibracion_fotos_base_path';

  static Directory? _cachedRoot;

  /// Raíz de las fotografías dentro del almacenamiento propio de la app.
  static Future<Directory> _root() async {
    final cached = _cachedRoot;
    if (cached != null && await cached.exists()) return cached;

    Directory? base;
    if (Platform.isAndroid) {
      base = await getExternalStorageDirectory();
    }
    base ??= await getApplicationDocumentsDirectory();

    final root = Directory(p.join(base.path, SafStorage.rootFolder));
    if (!await root.exists()) {
      await root.create(recursive: true);
    }
    _cachedRoot = root;
    return root;
  }

  /// Siempre `true`: el directorio propio de la app no depende de permisos ni
  /// de que el técnico elija una carpeta, así que no queda nada que configurar
  /// antes de abrir la cámara.
  ///
  /// Se conserva porque las cuatro pantallas de captura la consultan. Si el
  /// directorio no se pudiera crear, [saveFoto] lanza [FileSystemException] y
  /// cada pantalla ya muestra su propio mensaje de error.
  static Future<bool> isConfigured(
          {String subDirName = 'calibracion_fotos'}) async =>
      true;

  /// Conservado por compatibilidad. Ya no abre ningún selector: devuelve la
  /// ruta de almacenamiento propio, que no requiere configuración.
  static Future<String?> configure(
      {String subDirName = 'calibracion_fotos'}) async {
    try {
      return (await _root()).path;
    } on FileSystemException {
      return null;
    }
  }

  static Future<String> getBasePath() async {
    try {
      return (await _root()).path;
    } on FileSystemException {
      throw FotoStorageNotConfiguredError();
    }
  }

  /// Carpeta del servicio completo: `ServiceMET/{seca}/`.
  static Future<Directory> getServicioDir(String seca) async {
    final root = await _root();
    final dir = Directory(p.join(root.path, SafStorage.sanitizeSegment(seca)));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<Directory> getBaseDir(
      {String subDirName = 'calibracion_fotos'}) async {
    final root = await _root();
    final dir = Directory(p.join(root.path, subDirName));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<Directory> getInstrumentoDir(String seca, String codMetrica,
      {String subDirName = 'calibracion_fotos'}) async {
    final servicio = await getServicioDir(seca);
    final dir = Directory(p.join(
      servicio.path,
      subDirName,
      SafStorage.sanitizeSegment(codMetrica),
    ));
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

  /// Olvida la ruta pública configurada por versiones ≤ 6.1.1.
  ///
  /// Las fotos de servicios que quedaron en curso durante la actualización
  /// siguen físicamente en el dispositivo, pero al retirar
  /// MANAGE_EXTERNAL_STORAGE el sistema revoca su lectura. Las pantallas de
  /// captura ya comprueban `File.existsSync()` y muestran un marcador de foto
  /// no disponible en lugar de fallar.
  static Future<void> reset() async {
    _cachedRoot = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_legacyPrefsKey);
  }
}

class FotoStorageNotConfiguredError implements Exception {
  @override
  String toString() => 'Almacenamiento de fotos no configurado';
}
