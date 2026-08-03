import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:service_met/database/soporte_tecnico/database_helper_verificaciones.dart';
import 'package:service_met/screens/soporte_new/controllers/base_soporte_controller.dart';
import 'package:service_met/screens/soporte_new/models/base_soporte_model.dart';
import 'package:service_met/screens/soporte_new/models/campo_estado.dart';
import 'package:service_met/screens/soporte_new/models/shared_metrology_models.dart';
import '../models/verificaciones_internas_model.dart';

class VerificacionesInternasController extends BaseSoporteController {
  @override
  String get tableName => 'verificaciones_internas';

  @override
  String get tipoServicio => 'VERIFICACIONES INTERNAS';

  final VerificacionesInternasModel _model;
  final DatabaseHelperVerificaciones _dbLegacy = DatabaseHelperVerificaciones();

  String razonSocial = '', dirPlanta = '', depPlanta = '', codPlanta = '', personal = '';
  String infBal = '', categoriaBalanza = '', codInt = '', tipoEquipo = '';
  String marca = '', modelo = '', serie = '', unidades = '', numCeldas = '', ubicacion = '';
  String capMax1 = '', d1 = '', e1 = '', dec1 = '';
  String capMax2 = '', d2 = '', e2 = '', dec2 = '';
  String capMax3 = '', d3 = '', e3 = '', dec3 = '';

  @override
  BaseSoporteModel get model => _model;

  VerificacionesInternasController({required VerificacionesInternasModel model})
      : _model = model {
    totalSteps = 4;
    horaInicio = DateFormat('HH:mm').format(DateTime.now());
  }

  void initCamposEstado() {
    camposEstado.addAll([
      CampoEstado(nombre: 'Estructura general'),
      CampoEstado(nombre: 'Plataforma de carga'),
      CampoEstado(nombre: 'Indicador digital'),
      CampoEstado(nombre: 'Celdas de carga'),
      CampoEstado(nombre: 'Cableado eléctrico'),
      CampoEstado(nombre: 'Conexiones eléctricas'),
      CampoEstado(nombre: 'Nivelación del equipo'),
      CampoEstado(nombre: 'Protecciones mecánicas'),
      CampoEstado(nombre: 'Pintura y acabado'),
      CampoEstado(nombre: 'Limpieza general'),
      CampoEstado(nombre: 'Tornillería y fijaciones'),
      CampoEstado(nombre: 'Juntas y sellos'),
      CampoEstado(nombre: 'Guías y rodamientos'),
      CampoEstado(nombre: 'Sistema de transmisión'),
      CampoEstado(nombre: 'Rodillos'),
      CampoEstado(nombre: 'Correas y bandas'),
      CampoEstado(nombre: 'Sistema hidráulico'),
      CampoEstado(nombre: 'Sistema neumático'),
      CampoEstado(nombre: 'Frenos y seguros'),
      CampoEstado(nombre: 'Sensores'),
      CampoEstado(nombre: 'Pantalla y display'),
      CampoEstado(nombre: 'Botones y pulsadores'),
      CampoEstado(nombre: 'Identificación y rotulado'),
    ]);
  }

  void copiarPruebasInicialesAFinales() {
    pruebasFinales = PruebasMetrologicas.fromOther(pruebasIniciales);
    markChanged();
  }

  Future<void> restoreSession() async {
    final saved = await _dbLegacy.getRegistroBySeca(secaValue, model.sessionId);
    if (saved != null) await loadExistingSession(model.sessionId, saved);
  }

  @override
  Future<void> guardarSesion() async {
    setSaveInProgress();
    try {
      await _dbLegacy.upsertRegistroRelevamiento(await _prepareLegacyData());
      setSaveSuccess(true);
    } catch (error) {
      debugPrint('Error guardando verificaciones internas: $error');
      setSaveSuccess(false);
    }
  }

  @override
  Future<void> finalizarServicio({required String horaFin, required String fechaProxServicio}) async {
    this.horaFin = horaFin;
    this.fechaProxServicio = fechaProxServicio;
    setSaveInProgress();
    try {
      final data = await _prepareLegacyData();
      data['estado_servicio'] = 'Completo';
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
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final rows = await _dbLegacy.getAllRegistrosRelevamiento();
    return rows.where((row) {
      if (row['otst']?.toString() != seca ||
          row['estado_servicio']?.toString() != 'Completo') return false;
      return !soloHoy ||
          (row['fecha_servicio']?.toString() ?? '').startsWith(today);
    }).map((row) {
      final exportData = Map<String, dynamic>.from(row)
        ..remove('id')
        ..remove('session_id');
      return {...row, 'data': jsonEncode(exportData)};
    }).toList();
  }

  Future<Map<String, dynamic>> _prepareLegacyData() async {
    final data = await buildDataMap();
    data.addAll({
      'session_id': model.sessionId, 'otst': secaValue,
      'tipo_servicio': 'VIN.SP', 'estado_servicio': 'Pendiente',
      'fecha_servicio': DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
      'razon_social': razonSocial, 'dir_planta': dirPlanta, 'dep_planta': depPlanta,
      'cod_planta': codPlanta, 'personal': personal, 'inf_bal': infBal,
      'categoria_balanza': categoriaBalanza, 'cod_int': codInt,
      'tipo_equipo': tipoEquipo, 'marca': marca, 'modelo': modelo, 'serie': serie,
      'unidades': unidades, 'num_celdas': numCeldas, 'ubicacion': ubicacion,
      'cap_max1': capMax1, 'd1': d1, 'e1': e1, 'dec1': dec1,
      'cap_max2': capMax2, 'd2': d2, 'e2': e2, 'dec2': dec2,
      'cap_max3': capMax3, 'd3': d3, 'e3': e3, 'dec3': dec3,
      'fisico': estadoFisico, 'operacional': estadoOperacional,
      'metrologico': estadoMetrologico,
    });
    data.remove('seca_value');
    data.remove('estado_fisico');
    data.remove('estado_operacional');
    data.remove('estado_metrologico');
    return data;
  }

  @override
  Future<Map<String, dynamic>> buildDataMap() async {
    final map = await super.buildDataMap();
    map['campos_estado'] = jsonEncode(camposEstado.map((c) => {
      'nombre': c.nombre,
      'value': c.value,
      'solutionValue': c.solutionValue,
    }).toList());
    return map;
  }

  @override
  Future<void> loadExistingSession(String sessionId, Map<String, dynamic> data) async {
    await super.loadExistingSession(sessionId, data);
    estadoFisico = data['fisico']?.toString() ?? estadoFisico;
    estadoOperacional = data['operacional']?.toString() ?? estadoOperacional;
    estadoMetrologico = data['metrologico']?.toString() ?? estadoMetrologico;
    if (data['campos_estado'] != null) {
      try {
        final decoded = jsonDecode(data['campos_estado']);
        for (int i = 0; i < decoded.length && i < camposEstado.length; i++) {
          camposEstado[i].value = decoded[i]['value'] ?? '';
          camposEstado[i].solutionValue = decoded[i]['solutionValue'] ?? 'No aplica';
        }
      } catch (_) {}
    }
  }
}
