import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Carpeta de exportación elegida por el técnico mediante Storage Access
/// Framework en Android o Archivos en iOS.
class SafTree {
  const SafTree({required this.uri, required this.name});

  final String uri;
  final String name;
}

/// Puente hacia Storage Access Framework (Android) y Archivos (iOS).
///
/// Permite escribir la documentación de cada servicio en una carpeta que el
/// técnico elige una sola vez, conservando el acceso mediante un permiso URI
/// persistente o un bookmark de iOS. No requiere permisos de medios y
/// funciona sin conexión: el selector y la escritura son locales.
class SafStorage {
  SafStorage._();

  static const MethodChannel _channel = MethodChannel('bo.metrica.smet/saf');

  static const _uriKey = 'servicemet_saf_tree_uri';
  static const _nameKey = 'servicemet_saf_tree_name';

  /// Carpeta raíz que ServiceMET crea dentro de la ubicación elegida.
  static const rootFolder = 'ServiceMET';

  static bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Pide al técnico que elija la carpeta principal y conserva el permiso.
  ///
  /// Devuelve `null` si cancela el selector.
  static Future<SafTree?> chooseTree() async {
    if (!isSupported) return null;
    final result =
        await _channel.invokeMapMethod<String, dynamic>('pickDirectory');
    if (result == null) return null;

    final uri = result['uri'] as String?;
    if (uri == null || uri.isEmpty) return null;

    final name = (result['name'] as String?) ?? '';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_uriKey, uri);
    await prefs.setString(_nameKey, name);
    return SafTree(uri: uri, name: name);
  }

  /// Carpeta configurada, o `null` si nunca se eligió una.
  static Future<SafTree?> savedTree() async {
    if (!isSupported) return null;
    final prefs = await SharedPreferences.getInstance();
    final uri = prefs.getString(_uriKey);
    if (uri == null || uri.isEmpty) return null;
    return SafTree(uri: uri, name: prefs.getString(_nameKey) ?? '');
  }

  /// Comprueba que la carpeta siga existiendo y que el permiso URI persistente
  /// continúe vigente. El técnico puede revocarlo desde los ajustes del
  /// sistema o borrar la carpeta desde el explorador de archivos.
  static Future<bool> isConfigured() async {
    final tree = await savedTree();
    if (tree == null) return false;
    try {
      final available = await _channel.invokeMethod<bool>(
        'isTreeAvailable',
        {'uri': tree.uri},
      );
      return available ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Olvida la carpeta y libera el permiso URI persistente.
  static Future<void> forget() async {
    final tree = await savedTree();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_uriKey);
    await prefs.remove(_nameKey);
    if (tree == null) return;
    try {
      await _channel.invokeMethod<void>('releaseDirectory', {'uri': tree.uri});
    } on PlatformException {
      // El permiso ya había caducado.
    }
  }

  /// Escribe [bytes] en `ServiceMET/<segments>/<fileName>` dentro de la carpeta
  /// configurada. Devuelve el URI del documento creado.
  ///
  /// Lanza [SafNotConfiguredError] si aún no hay carpeta, y
  /// [SafUnavailableError] si la carpeta dejó de estar disponible.
  static Future<String> writeBytes({
    required List<String> segments,
    required String fileName,
    required String mimeType,
    required Uint8List bytes,
  }) {
    return _write('writeDocument', segments, fileName, mimeType, {
      'bytes': bytes,
    });
  }

  /// Copia el archivo local [sourcePath] a `ServiceMET/<segments>/<fileName>`.
  ///
  /// Se usa para las fotografías: evita cargarlas en memoria del lado Dart.
  static Future<String> copyFile({
    required String sourcePath,
    required List<String> segments,
    required String fileName,
    required String mimeType,
  }) {
    return _write('copyDocument', segments, fileName, mimeType, {
      'sourcePath': sourcePath,
    });
  }

  static Future<String> _write(
    String method,
    List<String> segments,
    String fileName,
    String mimeType,
    Map<String, dynamic> payload,
  ) async {
    final tree = await savedTree();
    if (tree == null) throw SafNotConfiguredError();

    try {
      final uri = await _channel.invokeMethod<String>(method, {
        'treeUri': tree.uri,
        'segments': [rootFolder, ...segments.map(sanitizeSegment)],
        'fileName': sanitizeSegment(fileName),
        'mimeType': mimeType,
        ...payload,
      });
      if (uri == null) throw SafUnavailableError();
      return uri;
    } on PlatformException catch (e) {
      if (e.code == 'tree_unavailable') throw SafUnavailableError();
      rethrow;
    }
  }

  /// Abre un documento exportado con el visor que elija el técnico.
  ///
  /// Devuelve `false` si no hay ninguna aplicación capaz de abrirlo; el archivo
  /// ya quedó guardado, así que no se trata como error de exportación.
  static Future<bool> openDocument(String uri,
      {String mimeType = '*/*'}) async {
    if (!isSupported) return false;
    try {
      final opened = await _channel.invokeMethod<bool>('openDocument', {
        'uri': uri,
        'mimeType': mimeType,
      });
      return opened ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Quita separadores y caracteres que SAF rechaza en nombres de carpeta o
  /// archivo. Los códigos de servicio (`26-0041-C06-0041-11-005`) pasan
  /// intactos.
  static String sanitizeSegment(String value) {
    final cleaned = value.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    return cleaned.isEmpty || cleaned == '.' || cleaned == '..'
        ? 'sin_codigo'
        : cleaned;
  }
}

class SafNotConfiguredError implements Exception {
  @override
  String toString() => 'No se ha configurado la carpeta de ServiceMET';
}

class SafUnavailableError implements Exception {
  @override
  String toString() =>
      'La carpeta de ServiceMET ya no está disponible. Selecciónela nuevamente.';
}
