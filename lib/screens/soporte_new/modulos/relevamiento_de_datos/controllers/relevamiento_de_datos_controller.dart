import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:service_met/database/soporte_tecnico/database_helper_relevamiento.dart';
import 'package:service_met/models/service_session.dart' as session;
import 'package:intl/intl.dart';
import 'package:service_met/screens/soporte_new/controllers/base_soporte_controller.dart';
import 'package:service_met/screens/soporte_new/models/campo_estado.dart';
import 'package:service_met/screens/soporte_new/modulos/relevamiento_de_datos/models/relevamiento_de_datos_model.dart';

class RelevamientoDeDatosController extends BaseSoporteController {
  @override
  String get tableName => 'relevamiento_de_datos';

  @override
  String get tipoServicio => 'RELEVAMIENTO DE DATOS';

  @override
  final RelevamientoDeDatosModel model;

  String temperatura = '';
  String humedad = '';
  String presion = '';
  String retornoCero = '';
  String estabilidad = '';
  bool excentricidadRealizada = true;
  bool repetibilidadRealizada = true;
  bool linealidadRealizada = true;
  session.ExcentricidadData excentricidad = session.ExcentricidadData();
  session.RepetibilidadData repetibilidad = session.RepetibilidadData();
  session.LinealidadData linealidad = session.LinealidadData();
  final DatabaseHelperRelevamiento _legacyDb = DatabaseHelperRelevamiento();

  // Contexto del cliente, planta y técnico.
  String razonSocial = '';
  String dirPlanta = '';
  String depPlanta = '';
  String codPlanta = '';
  String personal = '';

  // Información de la balanza seleccionada en la precarga.
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

  RelevamientoDeDatosController({required this.model}) {
    totalSteps = 5;
    horaInicio = DateFormat('HH:mm').format(DateTime.now());
  }

  void initCamposEstado() {
    camposEstado.clear();
    camposEstado.addAll([
      CampoEstado(nombre: 'Carcasa'),
      CampoEstado(nombre: 'Conector y Cables'),
      CampoEstado(nombre: 'Alimentación'),
      CampoEstado(nombre: 'Pantalla'),
      CampoEstado(nombre: 'Teclado'),
      CampoEstado(nombre: 'Bracket y columna'),
      CampoEstado(nombre: 'Plato de Carga'),
      CampoEstado(nombre: 'Estructura'),
      CampoEstado(nombre: 'Topes de Carga'),
      CampoEstado(nombre: 'Patas'),
      CampoEstado(nombre: 'Limpieza'),
      CampoEstado(nombre: 'Bordes y puntas'),
      CampoEstado(nombre: 'Célula(s)'),
      CampoEstado(nombre: 'Cable(s)'),
      CampoEstado(nombre: 'Cubierta de Silicona'),
    ]);
  }

  void setTemperatura(String v) {
    temperatura = v;
    markChanged();
  }

  void setHumedad(String v) {
    humedad = v;
    markChanged();
  }

  void setPresion(String v) {
    presion = v;
    markChanged();
  }

  Future<void> restoreSession() async {
    final row = await _legacyDb.getRegistroBySeca(secaValue, model.sessionId);
    if (row == null) return;
    horaInicio = row['hora_inicio']?.toString() ?? horaInicio;
    horaFin = row['hora_fin']?.toString() ?? '';
    fechaProxServicio = row['fecha_prox_servicio']?.toString() ?? '';
    comentarioGeneral = row['comentario_general']?.toString() ?? '';
    recomendacion = row['recomendaciones']?.toString() ?? '';
    retornoCero = row['retorno_cero']?.toString() ?? '';
    estabilidad = row['carga_retorno_cero']?.toString() ?? '';
    const keys = [
      'carcasa',
      'conector_cables',
      'alimentacion',
      'pantalla',
      'teclado',
      'bracket_columna',
      'plato_carga',
      'estructura',
      'topes_carga',
      'patas',
      'limpieza',
      'bordes_puntas',
      'celulas',
      'cables',
      'cubierta_silicona'
    ];
    for (var i = 0; i < keys.length && i < camposEstado.length; i++) {
      camposEstado[i].value = row[keys[i]]?.toString() ?? '';
      camposEstado[i].solutionValue =
          row['${keys[i]}_comentario']?.toString() ?? 'No aplica';
    }
    final positions = <session.PosicionData>[];
    for (var i = 1; i <= 12; i++) {
      final indication = row['indicacion$i']?.toString() ?? '';
      if (indication.isEmpty) continue;
      positions.add(session.PosicionData(
        posicion: row['posicion$i']?.toString(),
        indicacion: indication,
        retorno: row['retorno$i']?.toString(),
      ));
    }
    excentricidad = session.ExcentricidadData(
      tipoPlataforma: row['tipo_plataforma']?.toString(),
      puntosIndicacion: row['puntos_ind']?.toString(),
      carga: row['carga']?.toString(),
      posiciones: positions,
    );
    final lines = <session.FilaLinealidad>[];
    for (var i = 1; i <= 12; i++) {
      final load = row['lin$i']?.toString() ?? '';
      if (load.isEmpty) continue;
      lines.add(session.FilaLinealidad(
          carga: load,
          indicacion: row['ind$i']?.toString(),
          retorno: row['retorno_lin$i']?.toString()));
    }
    linealidad = session.LinealidadData(filas: lines);
    notifyListeners();
  }

  @override
  Future<void> guardarSesion() async {
    setSaveInProgress();
    try {
      await _legacyDb.upsertRegistroRelevamiento(_legacyData());
      setSaveSuccess(true);
    } catch (error) {
      debugPrint('Error guardando relevamiento: $error');
      setSaveSuccess(false);
    }
  }

  @override
  Future<void> finalizarServicio(
      {required String horaFin, required String fechaProxServicio}) async {
    this.horaFin = horaFin;
    this.fechaProxServicio = fechaProxServicio;
    setSaveInProgress();
    try {
      final data = _legacyData()..['estado_servicio'] = 'Balanza Realizada';
      await _legacyDb.upsertRegistroRelevamiento(data);
      setSaveSuccess(true);
    } catch (_) {
      setSaveSuccess(false);
      rethrow;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getRegistrosPorSeca(
      String tableName, String seca,
      {bool soloHoy = false}) async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final rows = await _legacyDb.getAllRegistrosRelevamiento();
    return rows
        .where((row) {
          if (row['otst']?.toString() != seca ||
              row['estado_servicio']?.toString() != 'Balanza Realizada') {
            return false;
          }
          return !soloHoy ||
              (row['fecha_servicio']?.toString() ?? '').startsWith(today);
        })
        .map((row) => {...row, 'data': jsonEncode(row)})
        .toList();
  }

  Map<String, dynamic> _legacyData() {
    final data = <String, dynamic>{
      'session_id': model.sessionId,
      'otst': secaValue,
      'cod_metrica': model.codMetrica,
      'tipo_servicio': 'REL.BL',
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
      'fecha_servicio':
          DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
      'hora_inicio': horaInicio,
      'hora_fin': horaFin,
      'fecha_prox_servicio': fechaProxServicio,
      'comentario_general': comentarioGeneral,
      'recomendaciones': recomendacion,
      'estado_servicio': 'Pendiente',
      'retorno_cero': retornoCero,
      'carga_retorno_cero': estabilidad,
    };
    const keys = [
      'carcasa',
      'conector_cables',
      'alimentacion',
      'pantalla',
      'teclado',
      'bracket_columna',
      'plato_carga',
      'estructura',
      'topes_carga',
      'patas',
      'limpieza',
      'bordes_puntas',
      'celulas',
      'cables',
      'cubierta_silicona'
    ];
    for (var i = 0; i < keys.length && i < camposEstado.length; i++) {
      data[keys[i]] = camposEstado[i].value;
      data['${keys[i]}_comentario'] = camposEstado[i].solutionValue;
      data['${keys[i]}_foto'] = camposEstado[i].fotos.join(',');
    }
    for (var i = 0; i < excentricidad.posiciones.length && i < 12; i++) {
      final p = excentricidad.posiciones[i];
      final n = i + 1;
      if (n <= 6) data['posicion$n'] = p.posicion ?? '';
      data['indicacion$n'] = p.indicacion ?? '';
      data['retorno$n'] = p.retorno ?? '';
    }
    data['tipo_plataforma'] = excentricidad.tipoPlataforma ?? '';
    data['puntos_ind'] = excentricidad.puntosIndicacion ?? '';
    data['carga'] = excentricidad.carga ?? '';
    // El esquema histórico de relevamiento admite una carga y diez lecturas.
    for (var i = 0; i < repetibilidad.cargas.length && i < 1; i++) {
      final carga = repetibilidad.cargas[i];
      final cargaNum = i + 1;
      data['repetibilidad$cargaNum'] = carga.carga ?? '';
      for (var j = 0; j < carga.indicaciones.length && j < 10; j++) {
        final testNum = j + 1;
        data['indicacion${cargaNum}_$testNum'] = carga.indicaciones[j] ?? '';
        data['retorno${cargaNum}_$testNum'] =
            j < carga.retornos.length ? carga.retornos[j] ?? '' : '';
      }
    }
    for (var i = 0; i < linealidad.filas.length && i < 12; i++) {
      final p = linealidad.filas[i];
      final n = i + 1;
      data['lin$n'] = p.carga ?? '';
      data['ind$n'] = p.indicacion ?? '';
      data['retorno_lin$n'] = p.retorno ?? '';
    }
    return data;
  }

  @override
  Future<Map<String, dynamic>> buildDataMap() async {
    final map = await super.buildDataMap();
    map.addAll({
      'temperatura': temperatura,
      'humedad': humedad,
      'presion': presion,
      'campos_estado': jsonEncode(
        camposEstado
            .map((c) => {
                  'nombre': c.nombre,
                  'value': c.value,
                  'solutionValue': c.solutionValue,
                  'solutionLabel': c.solutionLabel,
                  'fotos': c.fotos,
                })
            .toList(),
      ),
    });
    return map;
  }

  @override
  Future<void> loadExistingSession(
      String sessionId, Map<String, dynamic> data) async {
    await super.loadExistingSession(sessionId, data);
    temperatura = data['temperatura']?.toString() ?? '';
    humedad = data['humedad']?.toString() ?? '';
    presion = data['presion']?.toString() ?? '';
    if (data['campos_estado'] != null) {
      try {
        final list = jsonDecode(data['campos_estado']) as List;
        camposEstado.clear();
        for (final item in list) {
          camposEstado.add(CampoEstado(
            nombre: item['nombre'] ?? '',
            value: item['value'] ?? '',
            solutionValue: item['solutionValue'] ?? 'No aplica',
            solutionLabel: item['solutionLabel'] ?? '',
            fotos: (item['fotos'] as List?)?.cast<String>() ?? [],
          ));
        }
      } catch (_) {}
    }
    notifyListeners();
  }
}
