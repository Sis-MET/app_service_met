// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/mnt_correctivo_model.dart';
import '../../../../../database/soporte_tecnico/database_helper_diagnostico_correctivo.dart';
import '../../../../../database/soporte_tecnico/database_helper_ajustes.dart'; // Para d1
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';

class MntCorrectivoController {
  final MntCorrectivoModel model;
  double? _cachedD1;

  MntCorrectivoController({required this.model});

  Future<void> init() async {
    await getD1FromDatabase();
  }

  Future<double> getD1FromDatabase() async {
    if (_cachedD1 != null) return _cachedD1!;
    try {
      final dbHelper = DatabaseHelperAjustes();
      final db = await dbHelper.database;
      final List<Map<String, dynamic>> result = await db.query(
        'ajustes_metrologicos',
        columns: ['d1'],
        where: 'cod_metrica = ? AND otst = ?',
        whereArgs: [model.codMetrica, model.secaValue],
        limit: 1,
      );
      if (result.isNotEmpty) {
        final d1 = double.tryParse(result.first['d1'].toString()) ?? 0.0;
        _cachedD1 = d1;
        return d1;
      }
    } catch (e) {
      debugPrint('Error getting d1: $e');
    }
    return 0.0;
  }

  List<String> getIndicationSuggestions(double carga, double d) {
    if (d == 0) return [];
    int decimals = getDecimalPlaces(d);
    return [
      carga.toString(),
      (carga + d).toStringAsFixed(decimals),
      (carga - d).toStringAsFixed(decimals),
    ];
  }

  int getDecimalPlaces(double value) {
    String text = value.toString();
    if (text.contains('.')) return text.split('.')[1].length;
    return 0;
  }

  // --- IMPORTACIÓN CSV ---

  Future<void> importDiagnosticoCsv(
      BuildContext context, VoidCallback onUpdate) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result != null) {
        File file = File(result.files.single.path!);
        final input = file.openRead();
        final fields = await input
            .transform(utf8.decoder)
            .transform(const CsvToListConverter(
                fieldDelimiter: ';', textDelimiter: '"'))
            .toList();

        if (fields.isNotEmpty && fields.length > 1) {
          final headers = fields[0].map((e) => e.toString().trim()).toList();

          // Buscar índice de la columna cod_metrica
          final codMetricaIndex = headers.indexOf('cod_metrica');

          if (codMetricaIndex == -1) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      'El archivo CSV no contiene la columna "cod_metrica"'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
            return;
          }

          // Buscar la fila que coincida con el cod_metrica actual
          Map<String, dynamic>? matchingRow;

          for (int rowIndex = 1; rowIndex < fields.length; rowIndex++) {
            final row = fields[rowIndex];

            if (codMetricaIndex < row.length) {
              final csvCodMetrica =
                  row[codMetricaIndex]?.toString().trim() ?? '';
              final modelCodMetrica = model.codMetrica.trim();

              if (csvCodMetrica == modelCodMetrica) {
                // Encontramos una coincidencia, crear el mapa
                matchingRow = {};
                for (int i = 0; i < headers.length; i++) {
                  if (i < row.length) {
                    matchingRow[headers[i]] = row[i];
                  }
                }
                break; // Tomar la primera coincidencia
              }
            }
          }

          if (matchingRow != null) {
            _populateModelFromCsv(matchingRow);
            onUpdate(); // Actualizar UI

            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      'Datos importados correctamente para balanza: ${model.codMetrica}'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } else {
            // No se encontró coincidencia
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      'La balanza seleccionada (${model.codMetrica}) no coincide con ninguna del CSV importado'),
                  backgroundColor: Colors.orange,
                  duration: const Duration(seconds: 4),
                ),
              );
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error importing CSV: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error al importar: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  void _populateModelFromCsv(Map<String, dynamic> data) {
    debugPrint("--- IMPORTING CSV DATA ---");
    // Helper para obtener string seguro y trim
    String getVal(String key) => data[key]?.toString().trim() ?? '';

    // 1. General
    if (data.containsKey('reporte')) {
      model.reporteFalla = getVal('reporte');
    }

    // Prioridad: 1. evaluacion, 2. comentario_general
    if (data.containsKey('evaluacion') && getVal('evaluacion').isNotEmpty) {
      model.evaluacion = getVal('evaluacion');
    } else if (data.containsKey('comentario_general')) {
      // Fallback para CSVs antiguos o si está vacío
      model.evaluacion = getVal('comentario_general');
    }
  }

  // --- SAVE ---
  Future<void> saveData(BuildContext context) async {
    try {
      final DatabaseHelperDiagnosticoCorrectivo dbHelper =
          DatabaseHelperDiagnosticoCorrectivo();
      final data = _prepareDataForSave();
      await dbHelper
          .upsertRegistroRelevamiento(data); // Método existente en el helper

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Datos guardados exitosamente'),
            backgroundColor: Colors.green),
      );
    } catch (e) {
      debugPrint('Error saving: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error guardando: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Map<String, dynamic> _prepareDataForSave() {
    // Lógica similar a Diagnostico pero con Pruebas Finales e Inspección
    final data = <String, dynamic>{
      'session_id': model.sessionId,
      'cod_metrica': model.codMetrica,
      'otst': model.secaValue,
      'estado_servicio': 'Completo',
      'tipo_servicio': 'MCR.BL',
      'hora_inicio': model.horaInicio,
      'hora_fin': model.horaFin,
      'reporte': model.reporteFalla,
      'evaluacion': model.evaluacion,
      'trabajo_realizado': model.trabajoRealizado, // Nuevo campo

      // Estado Final
      'comentario_general': model.comentarioGeneral,
      'recomendacion': model.recomendacion,
      'fecha_prox_servicio': model.fechaProxServicio,
      'fisico': model.estadoFisico,
      'operacional': model.estadoOperacional,
      'metrologico': model.estadoMetrologico,

      // Pruebas metrológicas finales (Retorno Cero y Estabilidad)
      'retorno_cero_final_valoracion': model.pruebasFinales.retornoCero.estado,
      'estabilizacion_final': model.pruebasFinales.retornoCero.estabilidad,
    };

    // Excentricidad final
    _addExcentricidadData(data, model.pruebasFinales.excentricidad, 'final');

    // Repetibilidad final
    _addRepetibilidadData(data, model.pruebasFinales.repetibilidad, 'final');

    // Linealidad final
    _addLinealidadData(data, model.pruebasFinales.linealidad, 'final');

    return data;
  }

  void _addExcentricidadData(
      Map<String, dynamic> data, Excentricidad? exc, String tipo) {
    if (exc?.activo ?? false) {
      data['tipo_plataforma_$tipo'] = exc!.tipoPlataforma ?? '';
      data['puntos_ind_$tipo'] = exc.puntosIndicador ?? '';
      data['carga_exc_$tipo'] = exc.carga;

      for (int i = 0; i < exc.posiciones.length; i++) {
        final pos = exc.posiciones[i];
        final num = i + 1;
        data['posicion_${tipo}_$num'] = pos.posicion;
        data['indicacion_${tipo}_$num'] = pos.indicacion;
        data['retorno_${tipo}_$num'] = pos.retorno;
      }
    }
  }

  void _addRepetibilidadData(
      Map<String, dynamic> data, Repetibilidad? rep, String tipo) {
    if (rep?.activo ?? false) {
      // Guardar contadores para saber cuántas cargas/rows se usaron
      data['repetibilidad_count_$tipo'] = rep!.cargas.length;
      if (rep.cargas.isNotEmpty) {
        data['repetibilidad_rows_$tipo'] = rep.cargas[0].pruebas.length;
      }

      for (int i = 0; i < rep.cargas.length; i++) {
        final carga = rep.cargas[i];
        final cargaNum = i + 1;
        data['repetibilidad${cargaNum}_$tipo'] = carga.valor;

        for (int j = 0; j < carga.pruebas.length; j++) {
          final prueba = carga.pruebas[j];
          final testNum = j + 1;
          data['indicacion${cargaNum}_${tipo}_$testNum'] = prueba.indicacion;
          data['retorno${cargaNum}_${tipo}_$testNum'] = prueba.retorno;
        }
      }
    }
  }

  void _addLinealidadData(
      Map<String, dynamic> data, Linealidad? lin, String tipo) {
    if (lin?.activo ?? false) {
      for (int i = 0; i < lin!.puntos.length; i++) {
        final punto = lin.puntos[i];
        final num = i + 1;
        data['lin_${tipo}_$num'] = punto.lt;
        data['ind_${tipo}_$num'] = punto.indicacion;
        data['retorno_lin_${tipo}_$num'] = punto.retorno;
      }
    }
  }
}
