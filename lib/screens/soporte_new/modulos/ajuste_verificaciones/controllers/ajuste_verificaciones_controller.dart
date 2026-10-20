import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:service_met/database/soporte_tecnico/database_helper_ajustes.dart';
import 'package:service_met/models/service_session.dart' as session;
import 'package:service_met/screens/soporte_new/controllers/base_soporte_controller.dart';
import 'package:service_met/screens/soporte_new/utils/pruebas_omitidas.dart';

import '../models/ajuste_verificaciones_model.dart';

class AjusteVerificacionesController extends BaseSoporteController {
  @override
  String get tableName => 'ajustes_metrologicos';

  @override
  String get tipoServicio => 'AJUSTE DE VERIFICACIONES';

  @override
  final AjusteVerificacionesModel model;

  final DatabaseHelperAjustes _legacyDb = DatabaseHelperAjustes();

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
  String retornoCeroFinal = '';
  String estabilidadFinal = '';
  bool excentricidadRealizada = true;
  bool repetibilidadRealizada = true;
  bool linealidadRealizada = true;
  session.ExcentricidadData excentricidadInicial = session.ExcentricidadData();
  session.ExcentricidadData excentricidadFinal = session.ExcentricidadData();
  session.RepetibilidadData repetibilidadInicial = session.RepetibilidadData();
  session.RepetibilidadData repetibilidadFinal = session.RepetibilidadData();
  session.LinealidadData linealidadInicial = session.LinealidadData();
  session.LinealidadData linealidadFinal = session.LinealidadData();

  AjusteVerificacionesController({required this.model}) {
    totalSteps = 3;
    horaInicio = DateFormat('HH:mm:ss').format(DateTime.now());
  }

  void copiarPruebasInicialesAFinales() {
    retornoCeroFinal = retornoCeroInicial;
    estabilidadFinal = estabilidadInicial;
    excentricidadFinal = excentricidadInicial;
    repetibilidadFinal = repetibilidadInicial;
    linealidadFinal = linealidadInicial;
    markChanged();
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
    estadoFisico = row['fisico']?.toString() ?? '';
    estadoOperacional = row['operacional']?.toString() ?? '';
    estadoMetrologico = row['metrologico']?.toString() ?? '';
    retornoCeroInicial =
        row['retorno_cero_inicial_valoracion']?.toString() ?? '';
    estabilidadInicial = row['estabilizacion_inicial']?.toString() ?? '';
    retornoCeroFinal = row['retorno_cero_final_valoracion']?.toString() ?? '';
    estabilidadFinal = row['estabilizacion_final']?.toString() ?? '';

    excentricidadInicial = _restoreExcentricidad(row, 'inicial');
    excentricidadFinal = _restoreExcentricidad(row, 'final');
    repetibilidadInicial = _restoreRepetibilidad(row, 'inicial');
    repetibilidadFinal = _restoreRepetibilidad(row, 'final');
    linealidadInicial = _restoreLinealidad(row, 'inicial');
    linealidadFinal = _restoreLinealidad(row, 'final');

    // Lo que el técnico eligió con "Realizar ...". Un registro anterior a esa
    // columna no lo dice: cuenta como realizada la prueba con algún dato.
    final realizadas = PruebasOmitidas.leer(row);
    excentricidadRealizada = realizadas?.excentricidad ??
        (_hasExcentricidad(excentricidadInicial) ||
            _hasExcentricidad(excentricidadFinal));
    repetibilidadRealizada = realizadas?.repetibilidad ??
        (repetibilidadInicial.cargas.isNotEmpty ||
            repetibilidadFinal.cargas.isNotEmpty);
    linealidadRealizada = realizadas?.linealidad ??
        (linealidadInicial.filas.isNotEmpty ||
            linealidadFinal.filas.isNotEmpty);
    notifyListenersSafely();
  }

  @override
  Future<void> guardarSesion() async {
    setSaveInProgress();
    try {
      await _legacyDb.upsertRegistroRelevamiento(_legacyData());
      setSaveSuccess(true);
    } catch (error) {
      debugPrint('Error guardando ajuste de verificaciones: $error');
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
      'tipo_servicio': 'IBM.BL',
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
      'fisico': estadoFisico,
      'operacional': estadoOperacional,
      'metrologico': estadoMetrologico,
      'retorno_cero_inicial_valoracion': retornoCeroInicial,
      'estabilizacion_inicial': estabilidadInicial,
      'retorno_cero_final_valoracion': retornoCeroFinal,
      'estabilizacion_final': estabilidadFinal,
    };

    _clearMetrologyColumns(data, 'inicial');
    _clearMetrologyColumns(data, 'final');
    data[PruebasOmitidas.columna] = PruebasOmitidas.escribir((
      excentricidad: excentricidadRealizada,
      repetibilidad: repetibilidadRealizada,
      linealidad: linealidadRealizada,
    ));
    if (excentricidadRealizada) {
      _addExcentricidad(data, excentricidadInicial, 'inicial');
      _addExcentricidad(data, excentricidadFinal, 'final');
    }
    if (repetibilidadRealizada) {
      _addRepetibilidad(data, repetibilidadInicial, 'inicial');
      _addRepetibilidad(data, repetibilidadFinal, 'final');
    }
    if (linealidadRealizada) {
      _addLinealidad(data, linealidadInicial, 'inicial');
      _addLinealidad(data, linealidadFinal, 'final');
    }
    return data;
  }

  void _clearMetrologyColumns(Map<String, dynamic> data, String type) {
    data['excentricidad_${type}_tipo_plataforma'] = '';
    data['excentricidad_${type}_carga'] = '';
    data['excentricidad_${type}_cantidad_posiciones'] = '';
    for (var i = 1; i <= 6; i++) {
      data['excentricidad_${type}_pos${i}_numero'] = '';
      data['excentricidad_${type}_pos${i}_indicacion'] = '';
      data['excentricidad_${type}_pos${i}_retorno'] = '';
      data['excentricidad_${type}_pos${i}_error'] = '';
    }
    data['repetibilidad_${type}_cantidad_cargas'] = '';
    data['repetibilidad_${type}_cantidad_pruebas'] = '';
    data['repetibilidad_${type}_carga1_valor'] = '';
    for (var i = 1; i <= 10; i++) {
      data['repetibilidad_${type}_carga1_prueba${i}_indicacion'] = '';
      data['repetibilidad_${type}_carga1_prueba${i}_retorno'] = '';
    }
    data['linealidad_${type}_cantidad_puntos'] = '';
    for (var i = 1; i <= 12; i++) {
      data['linealidad_${type}_punto${i}_lt'] = '';
      data['linealidad_${type}_punto${i}_indicacion'] = '';
      data['linealidad_${type}_punto${i}_retorno'] = '';
      data['linealidad_${type}_punto${i}_error'] = '';
    }
  }

  void _addExcentricidad(
    Map<String, dynamic> data,
    session.ExcentricidadData value,
    String type,
  ) {
    data['excentricidad_${type}_tipo_plataforma'] = value.tipoPlataforma ?? '';
    data['excentricidad_${type}_carga'] = value.carga ?? '';
    data['excentricidad_${type}_cantidad_posiciones'] =
        value.posiciones.length.clamp(0, 6).toString();
    for (var i = 0; i < value.posiciones.length && i < 6; i++) {
      final position = value.posiciones[i];
      final number = i + 1;
      data['excentricidad_${type}_pos${number}_numero'] =
          position.posicion ?? '';
      data['excentricidad_${type}_pos${number}_indicacion'] =
          position.indicacion ?? '';
      data['excentricidad_${type}_pos${number}_retorno'] =
          position.retorno ?? '';
    }
  }

  void _addRepetibilidad(
    Map<String, dynamic> data,
    session.RepetibilidadData value,
    String type,
  ) {
    if (value.cargas.isEmpty) return;
    final load = value.cargas.first;
    final testCount = load.indicaciones.length.clamp(0, 10);
    data['repetibilidad_${type}_cantidad_cargas'] = '1';
    data['repetibilidad_${type}_cantidad_pruebas'] = testCount.toString();
    data['repetibilidad_${type}_carga1_valor'] = load.carga ?? '';
    for (var i = 0; i < testCount; i++) {
      final number = i + 1;
      data['repetibilidad_${type}_carga1_prueba${number}_indicacion'] =
          load.indicaciones[i] ?? '';
      data['repetibilidad_${type}_carga1_prueba${number}_retorno'] =
          i < load.retornos.length ? load.retornos[i] ?? '' : '';
    }
  }

  void _addLinealidad(
    Map<String, dynamic> data,
    session.LinealidadData value,
    String type,
  ) {
    data['linealidad_${type}_cantidad_puntos'] =
        value.filas.length.clamp(0, 12).toString();
    for (var i = 0; i < value.filas.length && i < 12; i++) {
      final row = value.filas[i];
      final number = i + 1;
      data['linealidad_${type}_punto${number}_lt'] = row.carga ?? '';
      data['linealidad_${type}_punto${number}_indicacion'] =
          row.indicacion ?? '';
      data['linealidad_${type}_punto${number}_retorno'] = row.retorno ?? '';
      data['linealidad_${type}_punto${number}_error'] =
          row.error ?? _calculateError(row.carga, row.indicacion);
    }
  }

  session.ExcentricidadData _restoreExcentricidad(
    Map<String, dynamic> row,
    String type,
  ) {
    final positions = <session.PosicionData>[];
    for (var i = 1; i <= 6; i++) {
      final position =
          row['excentricidad_${type}_pos${i}_numero']?.toString() ?? '';
      final indication =
          row['excentricidad_${type}_pos${i}_indicacion']?.toString() ?? '';
      final returnValue =
          row['excentricidad_${type}_pos${i}_retorno']?.toString() ?? '';
      if (position.isEmpty && indication.isEmpty && returnValue.isEmpty) {
        continue;
      }
      positions.add(session.PosicionData(
        posicion: position,
        indicacion: indication,
        retorno: returnValue,
      ));
    }
    return session.ExcentricidadData(
      tipoPlataforma: row['excentricidad_${type}_tipo_plataforma']?.toString(),
      puntosIndicacion:
          row['excentricidad_${type}_cantidad_posiciones']?.toString(),
      carga: row['excentricidad_${type}_carga']?.toString(),
      posiciones: positions,
    );
  }

  session.RepetibilidadData _restoreRepetibilidad(
    Map<String, dynamic> row,
    String type,
  ) {
    final loadValue =
        row['repetibilidad_${type}_carga1_valor']?.toString() ?? '';
    var testCount = int.tryParse(
          row['repetibilidad_${type}_cantidad_pruebas']?.toString() ?? '',
        ) ??
        0;
    if (testCount <= 0 || testCount > 10) {
      for (var i = 1; i <= 10; i++) {
        final indication =
            row['repetibilidad_${type}_carga1_prueba${i}_indicacion']
                    ?.toString() ??
                '';
        final returnValue =
            row['repetibilidad_${type}_carga1_prueba${i}_retorno']
                    ?.toString() ??
                '';
        if (indication.isNotEmpty || returnValue.isNotEmpty) testCount = i;
      }
    }
    final indications = <String?>[];
    final returns = <String?>[];
    var hasData = loadValue.isNotEmpty;
    for (var i = 1; i <= testCount; i++) {
      final indication =
          row['repetibilidad_${type}_carga1_prueba${i}_indicacion']
                  ?.toString() ??
              '';
      final returnValue =
          row['repetibilidad_${type}_carga1_prueba${i}_retorno']?.toString() ??
              '';
      if (indication.isNotEmpty || returnValue.isNotEmpty) hasData = true;
      indications.add(indication);
      returns.add(returnValue);
    }
    return session.RepetibilidadData(
      cargas: hasData
          ? [
              session.CargaRepetibilidad(
                carga: loadValue,
                indicaciones: indications,
                retornos: returns,
              ),
            ]
          : const [],
    );
  }

  session.LinealidadData _restoreLinealidad(
    Map<String, dynamic> row,
    String type,
  ) {
    final rows = <session.FilaLinealidad>[];
    for (var i = 1; i <= 12; i++) {
      final load = row['linealidad_${type}_punto${i}_lt']?.toString() ?? '';
      final indication =
          row['linealidad_${type}_punto${i}_indicacion']?.toString() ?? '';
      final returnValue =
          row['linealidad_${type}_punto${i}_retorno']?.toString() ?? '';
      final error = row['linealidad_${type}_punto${i}_error']?.toString() ?? '';
      if (load.isEmpty &&
          indication.isEmpty &&
          returnValue.isEmpty &&
          error.isEmpty) {
        continue;
      }
      rows.add(session.FilaLinealidad(
        carga: load,
        indicacion: indication,
        retorno: returnValue,
        error: error,
      ));
    }
    return session.LinealidadData(filas: rows);
  }

  bool _hasExcentricidad(session.ExcentricidadData value) {
    return value.posiciones.isNotEmpty ||
        (value.tipoPlataforma?.isNotEmpty ?? false) ||
        (value.carga?.isNotEmpty ?? false);
  }

  String _calculateError(String? load, String? indication) {
    final loadValue = double.tryParse(load?.replaceAll(',', '.') ?? '');
    final indicationValue =
        double.tryParse(indication?.replaceAll(',', '.') ?? '');
    if (loadValue == null || indicationValue == null) return '';
    return (indicationValue - loadValue).toStringAsFixed(2);
  }

  String _restoredValue(
    Map<String, dynamic> row,
    String key,
    String fallback,
  ) {
    final value = row[key]?.toString() ?? '';
    return value.isNotEmpty ? value : fallback;
  }
}
