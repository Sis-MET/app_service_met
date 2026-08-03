import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:service_met/database/soporte_tecnico/database_helper_diagnostico_correctivo.dart';
import 'package:service_met/models/service_session.dart' as session;
import 'package:service_met/screens/soporte_new/controllers/base_soporte_controller.dart';
import 'package:service_met/screens/soporte_new/models/base_soporte_model.dart';
import 'package:service_met/screens/soporte_new/models/campo_estado.dart';
import 'package:service_met/screens/soporte_new/models/shared_metrology_models.dart';
import '../models/mnt_correctivo_model.dart';

class MntCorrectivoController extends BaseSoporteController {
  @override
  String get tableName => 'mnt_correctivo';

  @override
  String get tipoServicio => 'MANTENIMIENTO CORRECTIVO';

  final MntCorrectivoModel _model;
  final DatabaseHelperDiagnosticoCorrectivo _dbLegacy =
      DatabaseHelperDiagnosticoCorrectivo();

  @override
  BaseSoporteModel get model => _model;

  String reporteFalla = '';
  String evaluacion = '';
  String trabajoRealizado = '';
  String repuestosUtilizados = '';

  String razonSocial = '';
  String dirPlanta = '';
  String depPlanta = '';
  String codPlanta = '';
  String personal = '';
  String infBal = '';
  String categoriaBalanza = '';
  String codInt = '';
  String tipoEquipo = '';
  String marca = '';
  String modelo = '';
  String serie = '';
  String unidades = '';
  String numCeldas = '';
  String ubicacion = '';
  String capMax1 = '', d1 = '', e1 = '', dec1 = '';
  String capMax2 = '', d2 = '', e2 = '', dec2 = '';
  String capMax3 = '', d3 = '', e3 = '', dec3 = '';

  String retornoCeroFinal = '';
  String estabilidadFinal = '';
  bool excentricidadRealizada = true;
  bool repetibilidadRealizada = true;
  bool linealidadRealizada = true;
  session.ExcentricidadData excentricidadFinal = session.ExcentricidadData();
  session.RepetibilidadData repetibilidadFinal = session.RepetibilidadData();
  session.LinealidadData linealidadFinal = session.LinealidadData();

  MntCorrectivoController({required MntCorrectivoModel model}) : _model = model {
    totalSteps = 3;
  }

  Future<bool> importDiagnosticoCsv() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (result == null || result.files.single.path == null) return false;

    final rows = await File(result.files.single.path!)
        .openRead()
        .transform(utf8.decoder)
        .transform(const CsvToListConverter(
            fieldDelimiter: ';', textDelimiter: '"'))
        .toList();
    if (rows.length < 2) return false;

    final headers = rows.first.map((value) => value.toString().trim()).toList();
    final codMetricaIndex = headers.indexOf('cod_metrica');
    if (codMetricaIndex == -1) {
      throw const FormatException(
          'El archivo CSV no contiene la columna "cod_metrica".');
    }

    for (final row in rows.skip(1)) {
      if (codMetricaIndex >= row.length ||
          row[codMetricaIndex].toString().trim() != model.codMetrica.trim()) {
        continue;
      }
      final values = <String, String>{};
      for (int index = 0; index < headers.length && index < row.length; index++) {
        values[headers[index]] = row[index].toString().trim();
      }
      reporteFalla = values['reporte'] ?? reporteFalla;
      evaluacion = values['evaluacion'] ?? values['comentario_general'] ?? evaluacion;
      trabajoRealizado = values['trabajo_realizado'] ?? trabajoRealizado;
      markChanged();
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<void> restoreSession() async {
    final saved = await _dbLegacy.getRegistroBySeca(secaValue, model.sessionId);
    if (saved != null) await loadExistingSession(model.sessionId, saved);
  }

  @override
  Future<void> guardarSesion() async {
    setSaveInProgress();
    try {
      await _dbLegacy.upsertRegistroRelevamiento(_prepareLegacyData());
      setSaveSuccess(true);
    } catch (error) {
      debugPrint('Error guardando MNT Correctivo: $error');
      setSaveSuccess(false);
    }
  }

  @override
  Future<void> finalizarServicio({
    required String horaFin,
    required String fechaProxServicio,
  }) async {
    this.horaFin = horaFin;
    this.fechaProxServicio = fechaProxServicio;
    setSaveInProgress();
    try {
      final data = _prepareLegacyData()..['estado_servicio'] = 'Completo';
      await _dbLegacy.upsertRegistroRelevamiento(data);
      setSaveSuccess(true);
    } catch (error) {
      setSaveSuccess(false);
      rethrow;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getRegistrosPorSeca(
    String tableName,
    String seca, {
    bool soloHoy = false,
  }) async {
    final all = await _dbLegacy.getAllRegistrosRelevamiento();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return all.where((row) {
      if (row['otst']?.toString() != seca ||
          row['estado_servicio']?.toString() != 'Completo') {
        return false;
      }
      return !soloHoy ||
          (row['fecha_servicio']?.toString() ?? '').startsWith(today);
    }).map((row) {
      final exportData = Map<String, dynamic>.from(row)
        ..remove('id')
        ..remove('session_id');
      return {...row, 'data': jsonEncode(exportData)};
    }).toList();
  }

  Map<String, dynamic> _prepareLegacyData() {
    final data = <String, dynamic>{
      'session_id': model.sessionId,
      'otst': secaValue,
      'cod_metrica': model.codMetrica,
      'tipo_servicio': 'MCR.BL',
      'estado_servicio': _isServiceComplete() ? 'Completo' : 'Pendiente',
      'fecha_servicio': DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
      'cliente': clienteNombre,
      'razon_social': razonSocial,
      'planta': plantaNombre,
      'dir_planta': dirPlanta,
      'dep_planta': depPlanta,
      'cod_planta': codPlanta,
      'personal': personal,
      'inf_bal': infBal,
      'categoria_balanza': categoriaBalanza,
      'cod_int': codInt,
      'tipo_equipo': tipoEquipo,
      'marca': marca,
      'modelo': modelo,
      'serie': serie,
      'unidades': unidades,
      'num_celdas': numCeldas,
      'ubicacion': ubicacion,
      'cap_max1': capMax1,
      'd1': d1,
      'e1': e1,
      'dec1': dec1,
      'cap_max2': capMax2,
      'd2': d2,
      'e2': e2,
      'dec2': dec2,
      'cap_max3': capMax3,
      'd3': d3,
      'e3': e3,
      'dec3': dec3,
      'hora_inicio': horaInicio,
      'hora_fin': horaFin,
      'reporte': reporteFalla,
      'evaluacion': evaluacion,
      'trabajo_realizado': trabajoRealizado,
      'comentario_general': comentarioGeneral,
      'recomendacion': recomendacion,
      'fecha_prox_servicio': fechaProxServicio,
      'fisico': estadoFisico,
      'operacional': estadoOperacional,
      'metrologico': estadoMetrologico,
      'retorno_cero_final_valoracion': retornoCeroFinal,
      'estabilizacion_final': estabilidadFinal,
    };

    if (excentricidadRealizada) {
      data['tipo_plataforma_final'] = excentricidadFinal.tipoPlataforma ?? '';
      data['puntos_ind_final'] = excentricidadFinal.puntosIndicacion ?? '';
      data['carga_exc_final'] = excentricidadFinal.carga ?? '';
      for (int i = 0; i < excentricidadFinal.posiciones.length && i < 6; i++) {
        final row = excentricidadFinal.posiciones[i];
        final number = i + 1;
        data['posicion_final_$number'] = row.posicion ?? '';
        data['indicacion_final_$number'] = row.indicacion ?? '';
        data['retorno_final_$number'] = row.retorno ?? '';
      }
    }
    if (repetibilidadRealizada && repetibilidadFinal.cargas.isNotEmpty) {
      final row = repetibilidadFinal.cargas.first;
      data['repetibilidad1_final'] = row.carga ?? '';
      for (int i = 0; i < row.indicaciones.length && i < 10; i++) {
        final number = i + 1;
        data['indicacion1_final_$number'] = row.indicaciones[i] ?? '';
        data['retorno1_final_$number'] =
            i < row.retornos.length ? row.retornos[i] ?? '' : '';
      }
    }
    if (linealidadRealizada) {
      for (int i = 0; i < linealidadFinal.filas.length && i < 12; i++) {
        final row = linealidadFinal.filas[i];
        final number = i + 1;
        data['lin_final_$number'] = row.carga ?? '';
        data['ind_final_$number'] = row.indicacion ?? '';
        data['retorno_lin_final_$number'] = row.retorno ?? '';
      }
    }
    return data;
  }

  bool _isServiceComplete() =>
      reporteFalla.isNotEmpty &&
      evaluacion.isNotEmpty &&
      trabajoRealizado.isNotEmpty &&
      comentarioGeneral.isNotEmpty &&
      recomendacion.isNotEmpty &&
      fechaProxServicio.isNotEmpty &&
      estadoFisico.isNotEmpty &&
      estadoOperacional.isNotEmpty &&
      estadoMetrologico.isNotEmpty &&
      horaFin.isNotEmpty;

  void initCamposEstado() {
    camposEstado.addAll([
      CampoEstado(nombre: 'Estructura general'),
      CampoEstado(nombre: 'Plataforma de carga'),
      CampoEstado(nombre: 'Indicador'),
      CampoEstado(nombre: 'Celdas de carga'),
      CampoEstado(nombre: 'Cableado eléctrico'),
      CampoEstado(nombre: 'Conexiones'),
      CampoEstado(nombre: 'Nivelación'),
      CampoEstado(nombre: 'Protecciones'),
      CampoEstado(nombre: 'Limpieza'),
      CampoEstado(nombre: 'Tornillería'),
      CampoEstado(nombre: 'Fallas encontradas'),
      CampoEstado(nombre: 'Componentes reemplazados'),
      CampoEstado(nombre: 'Ajustes realizados'),
    ]);
  }

  @override
  Future<Map<String, dynamic>> buildDataMap() async {
    final map = {
      'comentario_general': comentarioGeneral,
      'recomendacion': recomendacion,
      'estado_fisico': estadoFisico,
      'estado_operacional': estadoOperacional,
      'estado_metrologico': estadoMetrologico,
      'hora_inicio': horaInicio,
      'hora_fin': horaFin,
      'fecha_prox_servicio': fechaProxServicio,
      'retorno_cero_final': retornoCeroFinal,
      'estabilidad_final': estabilidadFinal,
      'pruebas_finales': jsonEncode({
        'excentricidad': _excToMap(excentricidadFinal),
        'repetibilidad': _repToMap(repetibilidadFinal),
        'linealidad': _linToMap(linealidadFinal),
      }),
      'pruebas_realizadas': jsonEncode({
        'excentricidad': excentricidadRealizada,
        'repetibilidad': repetibilidadRealizada,
        'linealidad': linealidadRealizada,
      }),
      'reporte_falla': reporteFalla,
      'evaluacion': evaluacion,
      'trabajo_realizado': trabajoRealizado,
      'repuestos_utilizados': repuestosUtilizados,
    };
    if (camposEstado.isNotEmpty) {
      map['campos_estado'] = jsonEncode(camposEstado.map((c) => {
        'nombre': c.nombre,
        'value': c.value,
        'solutionValue': c.solutionValue,
      }).toList());
    }
    return map;
  }

  @override
  Future<void> loadExistingSession(String sessionId, Map<String, dynamic> data) async {
    comentarioGeneral = data['comentario_general']?.toString() ?? '';
    recomendacion = data['recomendacion']?.toString() ?? '';
    estadoFisico =
        data['estado_fisico']?.toString() ?? data['fisico']?.toString() ?? '';
    estadoOperacional = data['estado_operacional']?.toString() ??
        data['operacional']?.toString() ??
        '';
    estadoMetrologico = data['estado_metrologico']?.toString() ??
        data['metrologico']?.toString() ??
        '';
    horaInicio = data['hora_inicio']?.toString() ?? '';
    horaFin = data['hora_fin']?.toString() ?? '';
    fechaProxServicio = data['fecha_prox_servicio']?.toString() ?? '';
    reporteFalla =
        data['reporte_falla']?.toString() ?? data['reporte']?.toString() ?? '';
    evaluacion = data['evaluacion']?.toString() ?? '';
    trabajoRealizado = data['trabajo_realizado']?.toString() ?? '';
    repuestosUtilizados = data['repuestos_utilizados']?.toString() ?? '';
    retornoCeroFinal = data['retorno_cero_final']?.toString() ??
        data['retorno_cero_final_valoracion']?.toString() ??
        '';
    estabilidadFinal = data['estabilidad_final']?.toString() ??
        data['estabilizacion_final']?.toString() ??
        '';

    if (data['pruebas_finales'] != null) {
      try {
        final pf = jsonDecode(data['pruebas_finales']);
        pruebasFinales = PruebasMetrologicas(
          excentricidad: (pf['excentricidad'] as List).map((e) => Excentricidad(
            posicion: e['posicion'] ?? '', carga: e['carga'] ?? '',
            indicacion1: e['indicacion1'] ?? '', indicacion2: e['indicacion2'] ?? '',
            indicacion3: e['indicacion3'] ?? '', diferencia: e['diferencia'] ?? '',
            error: e['error'] ?? '', errorMaximo: e['errorMaximo'] ?? '',
          )).toList(),
          repetibilidad: (pf['repetibilidad'] as List).map((r) => Repetibilidad(
            carga: r['carga'] ?? '', indicacion1: r['indicacion1'] ?? '',
            indicacion2: r['indicacion2'] ?? '', indicacion3: r['indicacion3'] ?? '',
            diferencia: r['diferencia'] ?? '', errorMaximo: r['errorMaximo'] ?? '',
          )).toList(),
          linealidad: (pf['linealidad'] as List).map((l) => Linealidad(
            carga: l['carga'] ?? '', indicacion1: l['indicacion1'] ?? '',
            indicacion2: l['indicacion2'] ?? '', error: l['error'] ?? '',
            errorMaximo: l['errorMaximo'] ?? '', incertidumbre: l['incertidumbre'] ?? '',
          )).toList(),
        );
      } catch (_) {}
    }

    _restoreSharedMetrologyData(data);
    _restoreFlatMetrologyData(data);

    if (data['campos_estado'] != null) {
      try {
        final decoded = jsonDecode(data['campos_estado']);
        for (int i = 0; i < decoded.length && i < camposEstado.length; i++) {
          camposEstado[i].value = decoded[i]['value'] ?? '';
          camposEstado[i].solutionValue = decoded[i]['solutionValue'] ?? 'No aplica';
        }
      } catch (_) {}
    }
    notifyListeners();
  }

  void _restoreSharedMetrologyData(Map<String, dynamic> data) {
    try {
      final raw = data['pruebas_finales'];
      if (raw is! String) return;
      final pruebas = jsonDecode(raw);
      if (pruebas is! Map) return;

      final excentricidad = pruebas['excentricidad'];
      if (excentricidad is Map) {
        excentricidadFinal = session.ExcentricidadData(
          tipoPlataforma: excentricidad['tipoPlataforma']?.toString(),
          puntosIndicacion: excentricidad['puntosIndicacion']?.toString(),
          carga: excentricidad['carga']?.toString(),
          posiciones: (excentricidad['posiciones'] as List? ?? [])
              .whereType<Map>()
              .map((row) => session.PosicionData(
                    posicion: row['posicion']?.toString(),
                    indicacion: row['indicacion']?.toString(),
                    retorno: row['retorno']?.toString(),
                  ))
              .toList(),
        );
      }

      final repetibilidad = pruebas['repetibilidad'];
      if (repetibilidad is Map) {
        repetibilidadFinal = session.RepetibilidadData(
          nota: repetibilidad['nota']?.toString(),
          cargas: (repetibilidad['cargas'] as List? ?? [])
              .whereType<Map>()
              .map((row) => session.CargaRepetibilidad(
                    carga: row['carga']?.toString(),
                    indicaciones: (row['indicaciones'] as List? ?? [])
                        .map((value) => value?.toString())
                        .toList(),
                    retornos: (row['retornos'] as List? ?? [])
                        .map((value) => value?.toString())
                        .toList(),
                  ))
              .toList(),
        );
      }

      final linealidad = pruebas['linealidad'];
      if (linealidad is Map) {
        linealidadFinal = session.LinealidadData(
          metodo: linealidad['metodo']?.toString(),
          metodoCarga: linealidad['metodoCarga']?.toString(),
          nota: linealidad['nota']?.toString(),
          filas: (linealidad['filas'] as List? ?? [])
              .whereType<Map>()
              .map((row) => session.FilaLinealidad(
                    carga: row['carga']?.toString(),
                    indicacion: row['indicacion']?.toString(),
                    retorno: row['retorno']?.toString(),
                  ))
              .toList(),
        );
      }

      final realizadas = data['pruebas_realizadas'];
      if (realizadas is String) {
        final flags = jsonDecode(realizadas);
        if (flags is Map) {
          excentricidadRealizada = flags['excentricidad'] == true;
          repetibilidadRealizada = flags['repetibilidad'] == true;
          linealidadRealizada = flags['linealidad'] == true;
        }
      }
    } catch (_) {
      // Un registro anterior puede conservar el formato genÃ©rico previo.
    }
  }

  void _restoreFlatMetrologyData(Map<String, dynamic> data) {
    final positions = <session.PosicionData>[];
    for (int i = 1; i <= 6; i++) {
      final position = data['posicion_final_$i']?.toString() ?? '';
      if (position.isEmpty) continue;
      positions.add(session.PosicionData(
        posicion: position,
        indicacion: data['indicacion_final_$i']?.toString() ?? '',
        retorno: data['retorno_final_$i']?.toString() ?? '0',
      ));
    }
    if (positions.isNotEmpty) {
      excentricidadFinal = session.ExcentricidadData(
        tipoPlataforma: data['tipo_plataforma_final']?.toString(),
        puntosIndicacion: data['puntos_ind_final']?.toString(),
        carga: data['carga_exc_final']?.toString(),
        posiciones: positions,
      );
    }

    final carga = data['repetibilidad1_final']?.toString() ?? '';
    if (carga.isNotEmpty) {
      final indicaciones = <String?>[];
      final retornos = <String?>[];
      for (int i = 1; i <= 10; i++) {
        final indicacion = data['indicacion1_final_$i']?.toString() ?? '';
        if (indicacion.isEmpty) continue;
        indicaciones.add(indicacion);
        retornos.add(data['retorno1_final_$i']?.toString() ?? '0');
      }
      repetibilidadFinal = session.RepetibilidadData(cargas: [
        session.CargaRepetibilidad(
          carga: carga,
          indicaciones: indicaciones,
          retornos: retornos,
        ),
      ]);
    }

    final filas = <session.FilaLinealidad>[];
    for (int i = 1; i <= 12; i++) {
      final carga = data['lin_final_$i']?.toString() ?? '';
      if (carga.isEmpty) continue;
      filas.add(session.FilaLinealidad(
        carga: carga,
        indicacion: data['ind_final_$i']?.toString() ?? '',
        retorno: data['retorno_lin_final_$i']?.toString() ?? '0',
      ));
    }
    if (filas.isNotEmpty) linealidadFinal = session.LinealidadData(filas: filas);
  }

  static Map<String, dynamic> _excToMap(session.ExcentricidadData data) => {
        'tipoPlataforma': data.tipoPlataforma,
        'puntosIndicacion': data.puntosIndicacion,
        'carga': data.carga,
        'posiciones': data.posiciones
            .map((row) => {
                  'posicion': row.posicion,
                  'indicacion': row.indicacion,
                  'retorno': row.retorno,
                })
            .toList(),
      };

  static Map<String, dynamic> _repToMap(session.RepetibilidadData data) => {
        'nota': data.nota,
        'cargas': data.cargas
            .map((row) => {
                  'carga': row.carga,
                  'indicaciones': row.indicaciones,
                  'retornos': row.retornos,
                })
            .toList(),
      };

  static Map<String, dynamic> _linToMap(session.LinealidadData data) => {
        'metodo': data.metodo,
        'metodoCarga': data.metodoCarga,
        'nota': data.nota,
        'filas': data.filas
            .map((row) => {
                  'carga': row.carga,
                  'indicacion': row.indicacion,
                  'retorno': row.retorno,
                })
            .toList(),
      };
}
