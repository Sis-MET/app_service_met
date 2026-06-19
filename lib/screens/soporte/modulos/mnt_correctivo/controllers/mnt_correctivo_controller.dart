// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:service_met/screens/soporte/controllers/base_soporte_controller.dart';
import '../models/mnt_correctivo_model.dart';
import '../../../../../database/soporte_tecnico/database_helper_diagnostico_correctivo.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';

class MntCorrectivoController extends BaseSoporteController<MntCorrectivoModel> {
  Timer? _autoSaveTimer;
  final ValueNotifier<bool> isAutoSaving = ValueNotifier(false);
  final ValueNotifier<bool> lastSaveSuccessful = ValueNotifier(true);

  MntCorrectivoController({required super.model});

  void dispose() {
    _autoSaveTimer?.cancel();
    isAutoSaving.dispose();
    lastSaveSuccessful.dispose();
  }

  void scheduleAutoSave(BuildContext context) {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(milliseconds: 1500), () {
      _autoSave(context);
    });
  }

  Future<void> flushAutoSave(BuildContext context) async {
    _autoSaveTimer?.cancel();
    await _autoSave(context);
  }

  Future<void> _autoSave(BuildContext context) async {
    if (isAutoSaving.value) return;
    isAutoSaving.value = true;

    try {
      final dbHelper = DatabaseHelperDiagnosticoCorrectivo();
      final data = prepareDataForSave();
      await dbHelper.upsertRegistroRelevamiento(data);
      lastSaveSuccessful.value = true;
    } catch (e) {
      lastSaveSuccessful.value = false;
      debugPrint('Error en auto-guardado (Mnt Correctivo): $e');
    } finally {
      isAutoSaving.value = false;
    }
  }

  Future<void> loadInitialValues() async {
    try {
      final dbHelper = DatabaseHelperDiagnosticoCorrectivo();
      final db = await dbHelper.database;
      final results = await db.query(
        'diagnostico_correctivo',
        where: 'session_id = ? AND otst = ?',
        whereArgs: [model.sessionId, model.secaValue],
        limit: 1,
      );

      if (results.isNotEmpty) {
        final registro = results.first;

        model.horaFin = registro['hora_fin']?.toString() ?? '';
        model.reporteFalla = registro['reporte']?.toString() ?? '';
        model.evaluacion = registro['evaluacion']?.toString() ?? '';
        model.trabajoRealizado =
            registro['trabajo_realizado']?.toString() ?? '';

        // Estado Final
        model.comentarioGeneral =
            registro['comentario_general']?.toString() ?? '';
        model.recomendacion = registro['recomendacion']?.toString() ?? '';
        model.fechaProxServicio =
            registro['fecha_prox_servicio']?.toString() ?? '';
        model.estadoFisico = registro['fisico']?.toString() ?? '';
        model.estadoOperacional = registro['operacional']?.toString() ?? '';
        model.estadoMetrologico = registro['metrologico']?.toString() ?? '';

        // Pruebas Finales - Retorno Cero
        final retCeroFinEst =
            registro['retorno_cero_final_valoracion']?.toString();
        if (retCeroFinEst != null && retCeroFinEst.isNotEmpty) {
          model.pruebasFinales.retornoCero.estado = retCeroFinEst;
        }
        final estabFinEst = registro['estabilizacion_final']?.toString();
        if (estabFinEst != null && estabFinEst.isNotEmpty) {
          model.pruebasFinales.retornoCero.estabilidad = estabFinEst;
        }

        _loadExcentricidadData(registro, model.pruebasFinales, 'final');
        _loadRepetibilidadData(registro, model.pruebasFinales, 'final');
        _loadLinealidadData(registro, model.pruebasFinales, 'final');
      }
    } catch (e) {
      debugPrint('Error loading initial values (Mnt Correctivo): $e');
    }
  }

  void _loadExcentricidadData(
      Map<String, dynamic> registro, PruebasMetrologicas pruebas, String tipo) {
    final tipoPlataforma = registro['tipo_plataforma_$tipo']?.toString();
    if (tipoPlataforma != null && tipoPlataforma.isNotEmpty) {
      pruebas.excentricidad ??= Excentricidad();
      final exc = pruebas.excentricidad!;
      exc.activo = true;
      exc.tipoPlataforma = tipoPlataforma;
      exc.puntosIndicador = registro['puntos_ind_$tipo']?.toString() ?? '';
      exc.carga = registro['carga_exc_$tipo']?.toString() ?? '';

      exc.posiciones.clear();
      for (int i = 0; i < 6; i++) {
        final posVal = registro['posicion_${tipo}_${i + 1}']?.toString();
        if (posVal != null && posVal.isNotEmpty) {
          exc.posiciones.add(PosicionExcentricidad(
            posicion: posVal,
            indicacion:
                registro['indicacion_${tipo}_${i + 1}']?.toString() ?? '',
            retorno: registro['retorno_${tipo}_${i + 1}']?.toString() ?? '0',
          ));
        }
      }
    }
  }

  void _loadRepetibilidadData(
      Map<String, dynamic> registro, PruebasMetrologicas pruebas, String tipo) {
    final carga1Str = registro['repetibilidad1_$tipo']?.toString();
    if (carga1Str != null && carga1Str.isNotEmpty) {
      pruebas.repetibilidad ??= Repetibilidad();
      final rep = pruebas.repetibilidad!;
      rep.activo = true;

      rep.cargas.clear();
      final carga1 = CargaRepetibilidad(valor: carga1Str);
      carga1.pruebas.clear();

      for (int j = 0; j < 10; j++) {
        final ind = registro['indicacion1_${tipo}_${j + 1}']?.toString();
        if (ind != null && ind.isNotEmpty) {
          carga1.pruebas.add(PruebaRepetibilidad(
            indicacion: ind,
            retorno: registro['retorno1_${tipo}_${j + 1}']?.toString() ?? '0',
          ));
        }
      }

      if (carga1.pruebas.isNotEmpty) {
        rep.cargas.add(carga1);
        rep.cantidadPruebas = carga1.pruebas.length;
      }
    }
  }

  void _loadLinealidadData(
      Map<String, dynamic> registro, PruebasMetrologicas pruebas, String tipo) {
    final lin1Str = registro['lin_${tipo}_1']?.toString();
    if (lin1Str != null && lin1Str.isNotEmpty) {
      pruebas.linealidad ??= Linealidad();
      final lin = pruebas.linealidad!;
      lin.activo = true;
      lin.puntos.clear();

      for (int i = 0; i < 12; i++) {
        final ptVal = registro['lin_${tipo}_${i + 1}']?.toString();
        if (ptVal != null && ptVal.isNotEmpty) {
          lin.puntos.add(PuntoLinealidad(
            lt: ptVal,
            indicacion: registro['ind_${tipo}_${i + 1}']?.toString() ?? '',
            retorno:
                registro['retorno_lin_${tipo}_${i + 1}']?.toString() ?? '0',
          ));
        }
      }
    }
  }

  Future<void> init() async {
    await getD1FromDatabase();
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

    // 1. Reporte de falla
    if (data.containsKey('reporte') && getVal('reporte').isNotEmpty) {
      model.reporteFalla = getVal('reporte');
    }

    // 2. Evaluación (prioridad: 'evaluacion', fallback: 'comentario_general')
    if (data.containsKey('evaluacion') && getVal('evaluacion').isNotEmpty) {
      model.evaluacion = getVal('evaluacion');
    } else if (data.containsKey('comentario_general')) {
      model.evaluacion = getVal('comentario_general');
    }

    // 3. Trabajo Realizado
    if (data.containsKey('trabajo_realizado') &&
        getVal('trabajo_realizado').isNotEmpty) {
      model.trabajoRealizado = getVal('trabajo_realizado');
    }

    debugPrint('  reporte: ${model.reporteFalla}');
    debugPrint('  evaluacion: ${model.evaluacion}');
    debugPrint('  trabajoRealizado: ${model.trabajoRealizado}');
  }

  // --- SAVE ---
  @override
  Future<void> saveData(BuildContext context) async {
    try {
      await savePhotos(context);
      final DatabaseHelperDiagnosticoCorrectivo dbHelper =
          DatabaseHelperDiagnosticoCorrectivo();
      final data = prepareDataForSave();
      await dbHelper
          .upsertRegistroRelevamiento(data); // Método existente en el helper

      if (context.mounted) {
        showSnackBar(context, 'Datos guardados exitosamente', isError: false);
      }
    } catch (e) {
      debugPrint('Error saving: $e');
      if (context.mounted) {
        showSnackBar(context, 'Error guardando: $e', isError: true);
      }
    }
  }

  bool _isServiceComplete() {
    return model.evaluacion.isNotEmpty &&
        model.trabajoRealizado.isNotEmpty &&
        model.reporteFalla.isNotEmpty &&
        model.comentarioGeneral.isNotEmpty &&
        model.recomendacion.isNotEmpty &&
        model.fechaProxServicio.isNotEmpty &&
        model.estadoFisico.isNotEmpty &&
        model.estadoMetrologico.isNotEmpty &&
        model.estadoOperacional.isNotEmpty &&
        model.horaFin.isNotEmpty;
  }

  @override
  Map<String, dynamic> prepareDataForSave() {
    // Lógica similar a Diagnostico pero con Pruebas Finales e Inspección
    final data = <String, dynamic>{
      'session_id': model.sessionId,
      'cod_metrica': model.codMetrica,
      'otst': model.secaValue,
      'estado_servicio': _isServiceComplete() ? 'Completo' : 'Pendiente',
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
      for (int i = 0; i < rep!.cargas.length; i++) {
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
