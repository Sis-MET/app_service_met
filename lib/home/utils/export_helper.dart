// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import '../models/servicio_model.dart';

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

      String csv = Csv().encode(csvData);
      final directory = await getDownloadsDirectory();
      final path = directory?.path;

      if (path == null) {
        throw Exception('No se pudo acceder al directorio de descargas');
      }

      final fileName =
          '${servicio.prefijo}_${servicio.codigo}_${DateTime.now().millisecondsSinceEpoch}.csv';
      final filePath = '$path/$fileName';
      final File file = File(filePath);
      await file.writeAsString(csv);

      OpenFilex.open(filePath);

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Archivo exportado: $fileName'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
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
