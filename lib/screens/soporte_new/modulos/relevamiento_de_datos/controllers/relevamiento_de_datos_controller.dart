import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:service_met/database/soporte_tecnico/database_helper_relevamiento.dart';
import 'package:service_met/models/service_session.dart' as session;
import 'package:intl/intl.dart';
import 'package:service_met/screens/soporte_new/controllers/base_soporte_controller.dart';
import 'package:service_met/screens/soporte_new/models/campo_estado.dart';
import 'package:service_met/screens/soporte_new/modulos/relevamiento_de_datos/models/relevamiento_de_datos_model.dart';
import 'package:service_met/screens/soporte_new/utils/pruebas_omitidas.dart';

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
      CampoEstado(nombre: 'Entorno'),
      CampoEstado(nombre: 'Nivelación'),
      CampoEstado(nombre: 'Movilización'),
      CampoEstado(nombre: 'Flujo de Pesadas'),
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
      'cubierta_silicona',
      'entorno',
      'nivelacion',
      'movilizacion',
      'flujo_pesas'
    ];
    for (var i = 0; i < keys.length && i < camposEstado.length; i++) {
      camposEstado[i].value = row[keys[i]]?.toString() ?? '';
      camposEstado[i].solutionValue =
          row['${keys[i]}_comentario']?.toString() ?? 'No aplica';
      final fotos = row['${keys[i]}_foto']?.toString() ?? '';
      camposEstado[i].fotos = fotos.isEmpty
          ? []
          : fotos.split(',').where((path) => path.isNotEmpty).toList();
    }
    excentricidad = session.ExcentricidadData(
      tipoPlataforma: row['tipo_plataforma']?.toString(),
      puntosIndicacion: row['puntos_ind']?.toString(),
      carga: row['carga']?.toString(),
    );
    // Todas las posiciones de la prueba, también las vacías: antes se
    // saltaban y las siguientes se corrían de lugar.
    var lastPosition = 0;
    for (var i = 1; i <= 12; i++) {
      if ((row['indicacion$i']?.toString() ?? '').isNotEmpty) lastPosition = i;
    }
    final positionCount =
        lastPosition == 0 ? 0 : (excentricidad.puntosCount ?? lastPosition);
    excentricidad = excentricidad.copyWith(posiciones: [
      for (var i = 1; i <= positionCount && i <= 12; i++)
        session.PosicionData(
          posicion: row['posicion$i']?.toString(),
          indicacion: row['indicacion$i']?.toString() ?? '',
          retorno: row['retorno$i']?.toString(),
        ),
    ]);
    // La repetibilidad se guardaba pero no se leía: al continuar volvía
    // vacía. Una carga, con 3, 5 o 10 mediciones como en la pantalla.
    final repeatLoad = row['repetibilidad1']?.toString() ?? '';
    var lastReading = 0;
    for (var j = 1; j <= 10; j++) {
      if ((row['indicacion1_$j']?.toString() ?? '').isNotEmpty ||
          (row['retorno1_$j']?.toString() ?? '').isNotEmpty) {
        lastReading = j;
      }
    }
    if (repeatLoad.isNotEmpty || lastReading > 0) {
      final readings = lastReading <= 3
          ? 3
          : lastReading <= 5
              ? 5
              : 10;
      String? value(String column) {
        final text = row[column]?.toString() ?? '';
        return text.isEmpty ? null : text;
      }

      repetibilidad = session.RepetibilidadData(cargas: [
        session.CargaRepetibilidad(
          carga: repeatLoad,
          indicaciones: [
            for (var j = 1; j <= readings; j++) value('indicacion1_$j'),
          ],
          retornos: [
            for (var j = 1; j <= readings; j++) value('retorno1_$j'),
          ],
        ),
      ]);
    }
    // Hasta la última carga escrita, en su lugar: antes se saltaban las
    // vacías y las siguientes se corrían de lugar.
    var lastLine = 0;
    for (var i = 1; i <= 12; i++) {
      if ((row['lin$i']?.toString() ?? '').isNotEmpty ||
          (row['ind$i']?.toString() ?? '').isNotEmpty) {
        lastLine = i;
      }
    }
    linealidad = session.LinealidadData(filas: [
      for (var i = 1; i <= lastLine; i++)
        session.FilaLinealidad(
            carga: row['lin$i']?.toString() ?? '',
            indicacion: row['ind$i']?.toString(),
            retorno: row['retorno_lin$i']?.toString()),
    ]);

    // Lo que el técnico eligió con "Realizar ...", si el registro lo guarda.
    final realizadas = PruebasOmitidas.leer(row);
    if (realizadas != null) {
      excentricidadRealizada = realizadas.excentricidad;
      repetibilidadRealizada = realizadas.repetibilidad;
      linealidadRealizada = realizadas.linealidad;
    }
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
      'cubierta_silicona',
      'entorno',
      'nivelacion',
      'movilizacion',
      'flujo_pesas'
    ];
    for (var i = 0; i < keys.length && i < camposEstado.length; i++) {
      data[keys[i]] = camposEstado[i].value;
      data['${keys[i]}_comentario'] = camposEstado[i].solutionValue;
      data['${keys[i]}_foto'] = camposEstado[i].fotos.join(',');
    }
    // Primero quedan vacías las casillas de las tres pruebas y luego se
    // escriben las realizadas: antes una prueba omitida se guardaba (y se
    // subía) igual, y las filas quitadas dejaban sus valores.
    _escribirPruebas(
      data,
      excentricidad: _excentricidadVacia,
      repetibilidad: _repetibilidadVacia,
      linealidad: _linealidadVacia,
    );
    _escribirPruebas(
      data,
      excentricidad: excentricidadRealizada ? excentricidad : null,
      repetibilidad: repetibilidadRealizada ? repetibilidad : null,
      linealidad: linealidadRealizada ? linealidad : null,
    );
    data[PruebasOmitidas.columna] = PruebasOmitidas.escribir((
      excentricidad: excentricidadRealizada,
      repetibilidad: repetibilidadRealizada,
      linealidad: linealidadRealizada,
    ));
    return data;
  }

  /// Pruebas con todas sus casillas vacías, para limpiar las columnas. La
  /// tabla tiene seis posiciones de excentricidad.
  static final _excentricidadVacia = session.ExcentricidadData(
      posiciones: List.filled(6, session.PosicionData()));
  static final _repetibilidadVacia = session.RepetibilidadData(cargas: [
    session.CargaRepetibilidad(
      indicaciones: List.filled(10, null),
      retornos: List.filled(10, null),
    ),
  ]);
  static final _linealidadVacia =
      session.LinealidadData(filas: List.filled(12, session.FilaLinealidad()));

  /// Las pruebas en las columnas planas; null deja la prueba como está en
  /// [data].
  void _escribirPruebas(
    Map<String, dynamic> data, {
    session.ExcentricidadData? excentricidad,
    session.RepetibilidadData? repetibilidad,
    session.LinealidadData? linealidad,
  }) {
    if (excentricidad != null) {
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
    }
    // El esquema histórico de relevamiento admite una carga y diez lecturas.
    if (repetibilidad != null) {
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
    }
    if (linealidad != null) {
      for (var i = 0; i < linealidad.filas.length && i < 12; i++) {
        final p = linealidad.filas[i];
        final n = i + 1;
        data['lin$n'] = p.carga ?? '';
        data['ind$n'] = p.indicacion ?? '';
        data['retorno_lin$n'] = p.retorno ?? '';
      }
    }
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
