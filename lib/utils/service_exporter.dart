import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

import 'foto_helper.dart';
import 'saf_storage.dart';

/// Resultado de una exportación.
class ExportResult {
  const ExportResult._({
    required this.saved,
    required this.destination,
    this.uri,
    this.mimeType,
    this.photoCount = 0,
  });

  const ExportResult.cancelled()
      : saved = false,
        destination = '',
        uri = null,
        mimeType = null,
        photoCount = 0;

  /// `false` sólo cuando el técnico canceló el selector.
  final bool saved;

  /// Ruta legible para mostrar en pantalla.
  final String destination;

  /// URI del documento creado, si se puede abrir después.
  final String? uri;

  final String? mimeType;

  /// Fotografías copiadas junto al documento.
  final int photoCount;

  bool get canOpen => uri != null;
}

/// Escribe la documentación de un servicio en la carpeta que el técnico eligió
/// mediante Storage Access Framework, organizada por código de servicio:
///
/// ```
/// <carpeta elegida>/ServiceMET/26-0041-C06-0041-11-005/
///     resumen.pdf
///     registros.csv
///     calibracion_fotos/<cod_metrica>/001.jpg
/// ```
///
/// Si el técnico todavía no ha elegido una carpeta, recurre al selector
/// estándar de Android (`ACTION_CREATE_DOCUMENT`) para guardar el archivo
/// suelto. Ambas rutas son locales y funcionan sin conexión.
class ServiceExporter {
  ServiceExporter._();

  static const csvMime = 'text/csv';
  static const pdfMime = 'application/pdf';

  /// Guarda [bytes] como `ServiceMET/{codigoServicio}/{fileName}`.
  static Future<ExportResult> exportDocument({
    required String codigoServicio,
    required String fileName,
    required String mimeType,
    required Uint8List bytes,
  }) async {
    if (await SafStorage.isConfigured()) {
      final uri = await SafStorage.writeBytes(
        segments: [codigoServicio],
        fileName: fileName,
        mimeType: mimeType,
        bytes: bytes,
      );
      final tree = await SafStorage.savedTree();
      return ExportResult._(
        saved: true,
        destination: _describe(tree, codigoServicio, fileName),
        uri: uri,
        mimeType: mimeType,
      );
    }

    return _saveWithSystemPicker(
      fileName: fileName,
      mimeType: mimeType,
      bytes: bytes,
    );
  }

  /// Guarda el documento y, además, copia las fotografías del servicio a la
  /// misma carpeta. Sólo aplica cuando hay carpeta SAF configurada: el selector
  /// estándar guarda un archivo suelto y no puede recibir la carpeta de fotos.
  static Future<ExportResult> exportServicio({
    required String codigoServicio,
    required String fileName,
    required String mimeType,
    required Uint8List bytes,
  }) async {
    final result = await exportDocument(
      codigoServicio: codigoServicio,
      fileName: fileName,
      mimeType: mimeType,
      bytes: bytes,
    );
    if (!result.saved || !result.canOpen) return result;

    final copiadas = await _copyFotos(codigoServicio);
    return ExportResult._(
      saved: true,
      destination: result.destination,
      uri: result.uri,
      mimeType: result.mimeType,
      photoCount: copiadas,
    );
  }

  /// Copia `ServiceMET/{codigo}/**` del almacenamiento propio a la carpeta SAF,
  /// conservando la jerarquía. Devuelve cuántas fotos se copiaron.
  static Future<int> _copyFotos(String codigoServicio) async {
    final Directory servicioDir;
    try {
      servicioDir = await FotoHelper.getServicioDir(codigoServicio);
    } on FileSystemException {
      return 0;
    }
    if (!await servicioDir.exists()) return 0;

    var copiadas = 0;
    await for (final entity in servicioDir.list(recursive: true)) {
      if (entity is! File) continue;
      final relative = p.split(p.relative(entity.path, from: servicioDir.path));
      if (relative.isEmpty) continue;

      final fileName = relative.removeLast();
      try {
        await SafStorage.copyFile(
          sourcePath: entity.path,
          segments: [codigoServicio, ...relative],
          fileName: fileName,
          mimeType: _mimeForPhoto(fileName),
        );
        copiadas++;
      } on SafUnavailableError {
        rethrow;
      } catch (_) {
        // Una foto ilegible no debe abortar la exportación del resto.
      }
    }
    return copiadas;
  }

  static Future<ExportResult> _saveWithSystemPicker({
    required String fileName,
    required String mimeType,
    required Uint8List bytes,
  }) async {
    final saved = await FilePicker.saveFile(
      dialogTitle: 'Guardar $fileName',
      fileName: fileName,
      bytes: bytes,
    );
    if (saved == null) return const ExportResult.cancelled();
    return ExportResult._(
      saved: true,
      destination: saved,
      mimeType: mimeType,
    );
  }

  static String _describe(SafTree? tree, String codigo, String fileName) {
    final carpeta = tree?.name.isNotEmpty == true ? tree!.name : 'la carpeta';
    return '$carpeta/${SafStorage.rootFolder}/$codigo/$fileName';
  }

  static String _mimeForPhoto(String fileName) {
    final ext = p.extension(fileName).toLowerCase();
    if (ext == '.png') return 'image/png';
    if (ext == '.webp') return 'image/webp';
    return 'image/jpeg';
  }
}
