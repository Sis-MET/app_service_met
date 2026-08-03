import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:service_met/database/soporte_tecnico/database_helper_diagnostico_correctivo.dart';
import 'package:service_met/screens/soporte_new/controllers/base_soporte_controller.dart';
import 'package:service_met/screens/soporte_new/models/base_soporte_model.dart';
import 'package:service_met/screens/soporte_new/models/campo_estado.dart';
import '../models/diagnostico_model.dart';

class DiagnosticoController extends BaseSoporteController {
  @override
  String get tableName => 'diagnostico';

  @override
  String get tipoServicio => 'DIAGNÓSTICO';

  final DiagnosticoModel _model;
  final DatabaseHelperDiagnosticoCorrectivo _dbLegacy =
      DatabaseHelperDiagnosticoCorrectivo();

  @override
  BaseSoporteModel get model => _model;

  String reporteFalla = '';
  String evaluacion = '';
  String observaciones = '';
  String accionesTomadas = '';

  String razonSocial = '', dirPlanta = '', depPlanta = '', codPlanta = '', personal = '';
  String infBal = '', categoriaBalanza = '', codInt = '', tipoEquipo = '';
  String marca = '', modelo = '', serie = '', unidades = '', numCeldas = '', ubicacion = '';
  String capMax1 = '', d1 = '', e1 = '', dec1 = '';
  String capMax2 = '', d2 = '', e2 = '', dec2 = '';
  String capMax3 = '', d3 = '', e3 = '', dec3 = '';

  DiagnosticoController({required DiagnosticoModel model}) : _model = model {
    totalSteps = 2;
  }

  Future<void> restoreSession() async {
    final saved = await _dbLegacy.getRegistroDiagnosticoBySeca(
        secaValue, model.sessionId);
    if (saved != null) await loadExistingSession(model.sessionId, saved);
  }

  @override
  Future<void> guardarSesion() async {
    setSaveInProgress();
    try {
      await _dbLegacy.upsertRegistroDiagnostico(_prepareLegacyData());
      setSaveSuccess(true);
    } catch (error) {
      debugPrint('Error guardando diagnostico: $error');
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
      await _dbLegacy.upsertRegistroDiagnostico(_prepareLegacyData());
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
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final all = await _dbLegacy.getAllRegistrosDiagnostico();
    return all.where((row) {
      if (row['otst']?.toString() != seca ||
          (row['reporte']?.toString() ?? '').isEmpty ||
          (row['evaluacion']?.toString() ?? '').isEmpty ||
          (row['comentario_general']?.toString() ?? '').isEmpty ||
          (row['hora_fin']?.toString() ?? '').isEmpty) {
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

  Map<String, dynamic> _prepareLegacyData() => {
        'tipo_servicio': 'DIG.BL',
        'session_id': model.sessionId,
        'otst': secaValue,
        'cod_metrica': model.codMetrica,
        'fecha_servicio': DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
        'cliente': clienteNombre, 'razon_social': razonSocial,
        'planta': plantaNombre, 'dir_planta': dirPlanta,
        'dep_planta': depPlanta, 'cod_planta': codPlanta, 'personal': personal,
        'inf_bal': infBal, 'categoria_balanza': categoriaBalanza,
        'cod_int': codInt, 'tipo_equipo': tipoEquipo, 'marca': marca,
        'modelo': modelo, 'serie': serie, 'unidades': unidades,
        'num_celdas': numCeldas, 'ubicacion': ubicacion,
        'cap_max1': capMax1, 'd1': d1, 'e1': e1, 'dec1': dec1,
        'cap_max2': capMax2, 'd2': d2, 'e2': e2, 'dec2': dec2,
        'cap_max3': capMax3, 'd3': d3, 'e3': e3, 'dec3': dec3,
        'hora_inicio': horaInicio, 'hora_fin': horaFin,
        'reporte': reporteFalla, 'evaluacion': evaluacion,
        'comentario_general': comentarioGeneral,
      };

  bool _isServiceComplete() =>
      reporteFalla.isNotEmpty && evaluacion.isNotEmpty &&
      comentarioGeneral.isNotEmpty && horaFin.isNotEmpty;

  void initCamposEstado() {
    camposEstado.addAll([
      CampoEstado(nombre: 'Falla reportada'),
      CampoEstado(nombre: 'Síntomas observados'),
      CampoEstado(nombre: 'Componentes afectados'),
      CampoEstado(nombre: 'Estado del indicador'),
      CampoEstado(nombre: 'Estado de la plataforma'),
      CampoEstado(nombre: 'Estado de celdas'),
      CampoEstado(nombre: 'Estado del cableado'),
      CampoEstado(nombre: 'Nivelación'),
      CampoEstado(nombre: 'Limpieza general'),
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
      'reporte_falla': reporteFalla,
      'observaciones': observaciones,
      'acciones_tomadas': accionesTomadas,
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
    estadoFisico = data['estado_fisico']?.toString() ?? data['fisico']?.toString() ?? '';
    estadoOperacional = data['estado_operacional']?.toString() ?? data['operacional']?.toString() ?? '';
    estadoMetrologico = data['estado_metrologico']?.toString() ?? data['metrologico']?.toString() ?? '';
    horaInicio = data['hora_inicio']?.toString() ?? '';
    horaFin = data['hora_fin']?.toString() ?? '';
    fechaProxServicio = data['fecha_prox_servicio']?.toString() ?? '';
    reporteFalla = data['reporte_falla']?.toString() ?? data['reporte']?.toString() ?? '';
    evaluacion = data['evaluacion']?.toString() ?? '';
    observaciones = data['observaciones']?.toString() ?? '';
    accionesTomadas = data['acciones_tomadas']?.toString() ?? '';

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
}
