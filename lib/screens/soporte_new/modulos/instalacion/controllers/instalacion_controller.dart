import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:service_met/database/soporte_tecnico/database_helper_instalacion.dart';
import 'package:service_met/models/service_session.dart' as session;
import 'package:service_met/screens/soporte_new/controllers/base_soporte_controller.dart';
import 'package:service_met/screens/soporte_new/models/campo_estado.dart';
import 'package:service_met/screens/soporte_new/modulos/instalacion/models/instalacion_model.dart';

class InstalacionController extends BaseSoporteController {
  @override
  String get tableName => 'instalacion';

  @override
  String get tipoServicio => 'INSTALACIÓN';

  @override
  final InstalacionModel model;

  final DatabaseHelperInstalacion _legacyDb = DatabaseHelperInstalacion();

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

  String retornoCeroInicial = '';
  String estabilidadInicial = '';
  bool excentricidadRealizada = true;
  bool repetibilidadRealizada = true;
  bool linealidadRealizada = true;
  session.ExcentricidadData excentricidadInicial = session.ExcentricidadData();
  session.RepetibilidadData repetibilidadInicial = session.RepetibilidadData();
  session.LinealidadData linealidadInicial = session.LinealidadData();

  static const conditionKeys = [
    'entorno',
    'superficie_apoyo',
    'tension_red',
    'sistema_tierra',
    'comunicacion_pc',
    'movilizacion',
    'vibracion_externa',
    'flujo_pesadas',
  ];

  InstalacionController({required this.model}) {
    totalSteps = 3;
    horaInicio = DateFormat('HH:mm:ss').format(DateTime.now());
  }

  void initCamposEstado() {
    camposEstado
      ..clear()
      ..addAll([
        CampoEstado(nombre: 'Entorno', solutionValue: ''),
        CampoEstado(nombre: 'Superficie de Apoyo', solutionValue: ''),
        CampoEstado(nombre: 'Tensión de Red', solutionValue: ''),
        CampoEstado(nombre: 'Sistema de Tierra', solutionValue: ''),
        CampoEstado(nombre: 'Comunicación PC/Impresora', solutionValue: ''),
        CampoEstado(nombre: 'Movilización', solutionValue: ''),
        CampoEstado(nombre: 'Vibración Externa', solutionValue: ''),
        CampoEstado(nombre: 'Flujo de Pesadas', solutionValue: ''),
      ]);
  }

  Future<void> restoreSession() async {
    final row = await _legacyDb.getRegistroBySeca(secaValue, model.sessionId);
    if (row == null) return;

    clienteNombre = _restoredValue(row, 'cliente', clienteNombre);
    razonSocial = _restoredValue(row, 'razon_social', razonSocial);
    plantaNombre = _restoredValue(row, 'planta', plantaNombre);
    dirPlanta = _restoredValue(row, 'dir_planta', dirPlanta);
    depPlanta = _restoredValue(row, 'dep_planta', depPlanta);
    codPlanta = _restoredValue(row, 'cod_planta', codPlanta);
    personal = _restoredValue(row, 'personal', personal);
    infBal = _restoredValue(row, 'inf_bal', infBal);
    categoriaBalanza =
        _restoredValue(row, 'categoria_balanza', categoriaBalanza);
    codInt = _restoredValue(row, 'cod_int', codInt);
    tipoEquipo = _restoredValue(row, 'tipo_equipo', tipoEquipo);
    marca = _restoredValue(row, 'marca', marca);
    modelo = _restoredValue(row, 'modelo', modelo);
    serie = _restoredValue(row, 'serie', serie);
    unidades = _restoredValue(row, 'unidades', unidades);
    numCeldas = _restoredValue(row, 'num_celdas', numCeldas);
    ubicacion = _restoredValue(row, 'ubicacion', ubicacion);
    capMax1 = _restoredValue(row, 'cap_max1', capMax1);
    d1 = _restoredValue(row, 'd1', d1);
    e1 = _restoredValue(row, 'e1', e1);
    dec1 = _restoredValue(row, 'dec1', dec1);
    capMax2 = _restoredValue(row, 'cap_max2', capMax2);
    d2 = _restoredValue(row, 'd2', d2);
    e2 = _restoredValue(row, 'e2', e2);
    dec2 = _restoredValue(row, 'dec2', dec2);
    capMax3 = _restoredValue(row, 'cap_max3', capMax3);
    d3 = _restoredValue(row, 'd3', d3);
    e3 = _restoredValue(row, 'e3', e3);
    dec3 = _restoredValue(row, 'dec3', dec3);

    horaInicio = row['hora_inicio']?.toString() ?? horaInicio;
    horaFin = row['hora_fin']?.toString() ?? '';
    fechaProxServicio = row['fecha_prox_servicio']?.toString() ?? '';
    comentarioGeneral = row['comentario_general']?.toString() ?? '';
    recomendacion = row['recomendacion']?.toString() ?? '';
    estadoFisico = row['estado_fisico']?.toString() ?? '';
    estadoOperacional = row['estado_operacional']?.toString() ?? '';
    estadoMetrologico = row['estado_metrologico']?.toString() ?? '';
    retornoCeroInicial =
        row['retorno_cero_inicial_valoracion']?.toString() ?? '';
    estabilidadInicial =
        row['retorno_cero_inicial_estabilidad']?.toString() ?? '';

    for (var i = 0; i < conditionKeys.length; i++) {
      camposEstado[i].value =
          row['${conditionKeys[i]}_valor']?.toString() ?? '';
      camposEstado[i].solutionValue =
          row['${conditionKeys[i]}_comentario']?.toString() ?? '';
    }

    final posiciones = <session.PosicionData>[];
    for (var i = 1; i <= 12; i++) {
      final posicion =
          i <= 6 ? row['posicion_inicial_$i']?.toString() ?? '' : '';
      final indicacion = row['indicacion_inicial_$i']?.toString() ?? '';
      final retorno = row['retorno_inicial_$i']?.toString() ?? '';
      if (posicion.isEmpty && indicacion.isEmpty && retorno.isEmpty) continue;
      posiciones.add(session.PosicionData(
        posicion: posicion,
        indicacion: indicacion,
        retorno: retorno,
      ));
    }
    excentricidadInicial = session.ExcentricidadData(
      tipoPlataforma: row['tipo_plataforma_inicial']?.toString(),
      puntosIndicacion: row['puntos_ind_inicial']?.toString(),
      carga: row['carga_exc_inicial']?.toString(),
      posiciones: posiciones,
    );
    excentricidadRealizada = posiciones.isNotEmpty ||
        (excentricidadInicial.tipoPlataforma?.isNotEmpty ?? false) ||
        (excentricidadInicial.carga?.isNotEmpty ?? false);

    final cargaRepetibilidad = row['repetibilidad1_inicial']?.toString() ?? '';
    final indicaciones = <String?>[];
    final retornos = <String?>[];
    var tieneRepetibilidad = cargaRepetibilidad.isNotEmpty;
    for (var i = 1; i <= 10; i++) {
      final indicacion = row['indicacion1_inicial_$i']?.toString() ?? '';
      final retorno = row['retorno1_inicial_$i']?.toString() ?? '';
      if (indicacion.isNotEmpty || retorno.isNotEmpty) {
        tieneRepetibilidad = true;
      }
      indicaciones.add(indicacion);
      retornos.add(retorno);
    }
    repetibilidadInicial = session.RepetibilidadData(
      cargas: tieneRepetibilidad
          ? [
              session.CargaRepetibilidad(
                carga: cargaRepetibilidad,
                indicaciones: indicaciones,
                retornos: retornos,
              )
            ]
          : const [],
    );
    repetibilidadRealizada = tieneRepetibilidad;

    final filas = <session.FilaLinealidad>[];
    for (var i = 1; i <= 12; i++) {
      final carga = row['lin_inicial_$i']?.toString() ?? '';
      final indicacion = row['ind_inicial_$i']?.toString() ?? '';
      final retorno = row['retorno_lin_inicial_$i']?.toString() ?? '';
      if (carga.isEmpty && indicacion.isEmpty && retorno.isEmpty) continue;
      filas.add(session.FilaLinealidad(
        carga: carga,
        indicacion: indicacion,
        retorno: retorno,
      ));
    }
    linealidadInicial = session.LinealidadData(filas: filas);
    linealidadRealizada = filas.isNotEmpty;
    notifyListeners();
  }

  String _restoredValue(
    Map<String, dynamic> row,
    String key,
    String fallback,
  ) {
    final value = row[key]?.toString() ?? '';
    return value.isNotEmpty ? value : fallback;
  }

  @override
  Future<void> guardarSesion() async {
    setSaveInProgress();
    try {
      await _legacyDb.upsertRegistroRelevamiento(_legacyData());
      setSaveSuccess(true);
    } catch (error) {
      debugPrint('Error guardando instalación: $error');
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
      final data = _legacyData()..['estado_servicio'] = 'Completo';
      await _legacyDb.upsertRegistroRelevamiento(data);
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
    final rows = await _legacyDb.getAllRegistrosRelevamiento();
    return rows.where((row) {
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

  Map<String, dynamic> _legacyData() {
    final data = <String, dynamic>{
      'session_id': model.sessionId,
      'otst': secaValue,
      'cod_metrica': model.codMetrica,
      'tipo_servicio': 'INS.BL',
      'estado_servicio': 'Pendiente',
      'fecha_servicio':
          DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
      'hora_inicio': horaInicio,
      'hora_fin': horaFin,
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
      'comentario_general': comentarioGeneral,
      'recomendacion': recomendacion,
      'fecha_prox_servicio': fechaProxServicio,
      'estado_fisico': estadoFisico,
      'estado_operacional': estadoOperacional,
      'estado_metrologico': estadoMetrologico,
      'retorno_cero_inicial_valoracion': retornoCeroInicial,
      'retorno_cero_inicial_estabilidad': estabilidadInicial,
      'tipo_plataforma_inicial': '',
      'puntos_ind_inicial': '',
      'carga_exc_inicial': '',
      'repetibilidad1_inicial': '',
      'linealidad_inicial_cantidad_puntos': 0,
    };

    for (var i = 0; i < conditionKeys.length; i++) {
      data['${conditionKeys[i]}_valor'] = camposEstado[i].value;
      data['${conditionKeys[i]}_comentario'] = camposEstado[i].solutionValue;
    }

    for (var i = 1; i <= 12; i++) {
      if (i <= 6) data['posicion_inicial_$i'] = '';
      data['indicacion_inicial_$i'] = '';
      data['retorno_inicial_$i'] = '';
      data['lin_inicial_$i'] = '';
      data['ind_inicial_$i'] = '';
      data['retorno_lin_inicial_$i'] = '';
    }
    for (var i = 1; i <= 10; i++) {
      data['indicacion1_inicial_$i'] = '';
      data['retorno1_inicial_$i'] = '';
    }

    if (excentricidadRealizada) {
      data['tipo_plataforma_inicial'] =
          excentricidadInicial.tipoPlataforma ?? '';
      data['puntos_ind_inicial'] = excentricidadInicial.puntosIndicacion ?? '';
      data['carga_exc_inicial'] = excentricidadInicial.carga ?? '';
      for (var i = 0;
          i < excentricidadInicial.posiciones.length && i < 12;
          i++) {
        final posicion = excentricidadInicial.posiciones[i];
        final number = i + 1;
        if (number <= 6) {
          data['posicion_inicial_$number'] = posicion.posicion ?? '';
        }
        data['indicacion_inicial_$number'] = posicion.indicacion ?? '';
        data['retorno_inicial_$number'] = posicion.retorno ?? '';
      }
    }

    if (repetibilidadRealizada && repetibilidadInicial.cargas.isNotEmpty) {
      final carga = repetibilidadInicial.cargas.first;
      data['repetibilidad1_inicial'] = carga.carga ?? '';
      for (var i = 0; i < carga.indicaciones.length && i < 10; i++) {
        final number = i + 1;
        data['indicacion1_inicial_$number'] = carga.indicaciones[i] ?? '';
        data['retorno1_inicial_$number'] =
            i < carga.retornos.length ? carga.retornos[i] ?? '' : '';
      }
    }

    if (linealidadRealizada) {
      data['linealidad_inicial_cantidad_puntos'] =
          linealidadInicial.filas.length.clamp(0, 12);
      for (var i = 0; i < linealidadInicial.filas.length && i < 12; i++) {
        final fila = linealidadInicial.filas[i];
        final number = i + 1;
        data['lin_inicial_$number'] = fila.carga ?? '';
        data['ind_inicial_$number'] = fila.indicacion ?? '';
        data['retorno_lin_inicial_$number'] = fila.retorno ?? '';
      }
    }

    return data;
  }
}
