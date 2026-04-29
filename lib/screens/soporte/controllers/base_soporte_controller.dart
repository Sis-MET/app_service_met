import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:archive/archive.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:service_met/screens/soporte/utils/soporte_metrologia_utils.dart';

/// Interfaz para asegurar que los modelos de soporte tengan propiedades comunes necesarias
abstract class BaseSoporteModel {
  String get sessionId;
  String get codMetrica;
  String get secaValue;
  Map<String, List<File>> get fieldPhotos;
  
  void addPhoto(String campo, File foto) {
    if (!fieldPhotos.containsKey(campo)) {
      fieldPhotos[campo] = [];
    }
    if (fieldPhotos[campo]!.length < 5) {
      fieldPhotos[campo]!.add(foto);
    } else {
      debugPrint('⚠️ Límite de 5 fotos alcanzado para: $campo');
    }
  }

  void removePhoto(String campo, int index) {
    if (fieldPhotos.containsKey(campo) && index < fieldPhotos[campo]!.length) {
      fieldPhotos[campo]!.removeAt(index);
    }
  }

  void clearPhotos(String campo) {
    if (fieldPhotos.containsKey(campo)) {
      fieldPhotos[campo]!.clear();
    }
  }
}

/// Controlador Base para módulos de Soporte Técnico.
/// Centraliza la lógica de:
/// - UI Helpers (Snackbars)
/// - Utilidades Metrológicas (Decimales, d1)
/// - Manejo de Fotos (ZIP, FlutterFileDialog)
abstract class BaseSoporteController<M extends BaseSoporteModel> {
  final M model;

  BaseSoporteController({required this.model});

  // =========================================================================
  // METROLOGÍA
  // =========================================================================

  Future<double> getD1FromDatabase() async {
    return SoporteMetrologiaUtils.getD1FromDatabase(model.sessionId, model.codMetrica);
  }

  Future<double> getDForCarga(double carga) async {
    return SoporteMetrologiaUtils.getDForCarga(model.sessionId, model.codMetrica, carga);
  }

  int getDecimalPlaces(double dValue) {
    return SoporteMetrologiaUtils.getDecimalPlaces(dValue);
  }

  Future<List<String>> getIndicationSuggestions(String cargaText, String currentValue) async {
    final carga = double.tryParse(cargaText.replaceAll(',', '.')) ?? 0.0;
    final dValue = await getDForCarga(carga);
    return SoporteMetrologiaUtils.generateIndicationSuggestions(cargaText, currentValue, dValue);
  }

  // =========================================================================
  // GESTIÓN DE FOTOS Y ARCHIVOS
  // =========================================================================

  void agregarFoto(String campo, File foto) {
    model.addPhoto(campo, foto);
  }

  void eliminarFoto(String campo, int index) {
    model.removePhoto(campo, index);
  }

  void limpiarFotos(String campo) {
    model.clearPhotos(campo);
  }

  void limpiarTodasLasFotos() {
    model.fieldPhotos.clear();
  }

  String sanitizeFileName(String name) {
    return name
        .replaceAll(' ', '_')
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ñ', 'n')
        .replaceAll(RegExp(r'[^\w\.-]'), ''); 
  }

  Future<void> savePhotos(BuildContext context) async {
    bool hasPhotos = model.fieldPhotos.values.any((photos) => photos.isNotEmpty);

    if (hasPhotos) {
      final archive = Archive();
      int totalSize = 0;

      model.fieldPhotos.forEach((label, photos) {
        for (var i = 0; i < photos.length; i++) {
          final file = photos[i];
          if (!file.existsSync()) continue;
          
          final fileSize = file.lengthSync();
          totalSize += fileSize;

          if (fileSize > 5 * 1024 * 1024) {
            debugPrint('⚠️ Foto grande detectada: ${label}_${i + 1} - ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB');
          }

          final safeLabel = sanitizeFileName(label);
          final fileName = '${safeLabel}_${i + 1}.jpg';
          
          archive.addFile(ArchiveFile(
            fileName,
            file.lengthSync(),
            file.readAsBytesSync(),
          ));
        }
      });

      debugPrint('📦 Tamaño total de fotos: ${(totalSize / 1024 / 1024).toStringAsFixed(2)} MB');

      final zipEncoder = ZipEncoder();
      final zipData = zipEncoder.encode(archive);
      final uint8ListData = Uint8List.fromList(zipData);
      final zipFileName = '${model.secaValue}_${model.codMetrica}_fotos_${DateTime.now().millisecondsSinceEpoch}.zip';

      final params = SaveFileDialogParams(
        data: uint8ListData,
        fileName: zipFileName,
        mimeTypesFilter: ['application/zip'],
      );

      try {
        final filePath = await FlutterFileDialog.saveFile(params: params);
        if (filePath != null && context.mounted) {
          showSnackBar(context, 'Fotos guardadas en $filePath', isError: false);
        } else if (context.mounted) {
          showSnackBar(context, 'No se seleccionó ninguna carpeta', isError: true);
        }
      } catch (e) {
        if (context.mounted) {
          showSnackBar(context, 'Error al guardar el archivo ZIP: $e', isError: true);
        }
      }
    }
  }

  // =========================================================================
  // UI HELPERS
  // =========================================================================

  void showSnackBar(BuildContext context, String message, {bool isError = false}) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: isError ? 3 : 2),
      ),
    );
  }

  // =========================================================================
  // ABSTRACT METHODS (Para implementar en cada módulo)
  // =========================================================================

  /// Preparar datos para ser insertados/actualizados en la BD
  Map<String, dynamic> prepareDataForSave();

  /// Lógica final de guardado en base de datos.
  /// Generalmente llama a un DatabaseHelper y luego puede (opcionalmente) llamar a savePhotos.
  Future<void> saveData(BuildContext context);
}
