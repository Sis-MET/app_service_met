// ignore_for_file: use_build_context_synchronously

import 'dart:convert';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import '../models/servicio_model.dart';
import '../../utils/saf_storage.dart';
import '../../utils/service_exporter.dart';

class ExportHelper {
  static Future<void> exportarServicioDirectamente(
      BuildContext context, ServicioResumen servicio) async {
    try {
      final List<List<dynamic>> csvData = [];

      if (servicio.items.isNotEmpty) {
        csvData.add(servicio.items.first.keys.toList());
      }

      for (var item in servicio.items) {
        csvData.add(item.values.toList());
      }

      final String csv = Csv().encode(csvData);
      final fileName =
          '${servicio.prefijo}_${servicio.codigo}_${DateTime.now().millisecondsSinceEpoch}.csv';

      // Escribe en la carpeta ServiceMET elegida por el técnico; si aún no hay
      // ninguna, recurre al selector estándar de Android. Ninguna de las dos
      // vías requiere permisos de almacenamiento.
      final result = await ServiceExporter.exportDocument(
        codigoServicio: servicio.codigo,
        fileName: fileName,
        mimeType: ServiceExporter.csvMime,
        bytes: Uint8List.fromList(utf8.encode(csv)),
      );
      if (!result.saved) return;

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Archivo exportado: ${result.destination}'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        action: result.canOpen
            ? SnackBarAction(
                label: 'Abrir',
                textColor: Colors.white,
                onPressed: () => SafStorage.openDocument(
                  result.uri!,
                  mimeType: ServiceExporter.csvMime,
                ),
              )
            : null,
      ));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error al exportar: $e'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }
}
