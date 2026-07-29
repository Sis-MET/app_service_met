import 'dart:convert';

import 'package:intl/intl.dart';
import 'package:service_met/database/soporte_tecnico/database_helper_mnt_prv_regular_stil.dart';
import 'package:service_met/models/service_session.dart';
import 'package:service_met/screens/soporte_new/controllers/base_soporte_controller.dart';
import 'package:service_met/screens/soporte_new/models/campo_estado.dart';
import 'package:service_met/screens/soporte_new/modulos/mnt_prv_regular/models/mnt_prv_regular_model.dart';

class MntPrvRegularController extends BaseSoporteController {
  @override
  String get tableName => 'mnt_prv_regular';

  @override
  String get tipoServicio => 'MNT PREVENTIVO REGULAR';

  @override
  final MntPrvRegularModel model;

  final List<CampoEstado> camposTerminal = [];
  final List<CampoEstado> camposBalanza = [];
  final List<CampoEstado> camposCajaSumadora = [];

  final DatabaseHelperMntPrvRegularStil _dbLegacy =
      DatabaseHelperMntPrvRegularStil();

  // ── Retorno a Cero / Estabilidad ────────────────────────────────────
  String retornoCeroInicial = '';
  String estabilidadInicial = '';
  String retornoCeroFinal = '';
  String estabilidadFinal = '';

  // ── Pruebas metrológicas (opcionales) ────────────────────────────────
  bool excentricidadRealizada = true;
  bool repetibilidadRealizada = true;
  bool linealidadRealizada = true;

  ExcentricidadData excentricidadInicial = ExcentricidadData();
  ExcentricidadData excentricidadFinal = ExcentricidadData();
  RepetibilidadData repetibilidadInicial = RepetibilidadData();
  RepetibilidadData repetibilidadFinal = RepetibilidadData();
  LinealidadData linealidadInicial = LinealidadData();
  LinealidadData linealidadFinal = LinealidadData();

  MntPrvRegularController({required this.model}) {
    totalSteps = 6;
    if (horaInicio.isEmpty) {
      horaInicio = DateFormat('HH:mm').format(DateTime.now());
    }
  }

  void copiarPruebasInicialesAFinales() {
    retornoCeroFinal = retornoCeroInicial;
    estabilidadFinal = estabilidadInicial;
    excentricidadFinal = excentricidadInicial;
    repetibilidadFinal = repetibilidadInicial;
    linealidadFinal = linealidadInicial;
    markChanged();
  }

  void initCamposEstado() {
    camposTerminal.clear();
    camposTerminal.addAll([
      CampoEstado(nombre: 'Carcasa'),
      CampoEstado(nombre: 'Teclado Fisico'),
      CampoEstado(nombre: 'Display Fisico'),
      CampoEstado(nombre: 'Fuente de poder'),
      CampoEstado(nombre: 'Bateria operacional'),
      CampoEstado(nombre: 'Bracket'),
      CampoEstado(nombre: 'Teclado Operativo'),
      CampoEstado(nombre: 'Display Operativo'),
      CampoEstado(nombre: 'Contector de celda'),
      CampoEstado(nombre: 'Bateria de memoria'),
    ]);

    camposBalanza.clear();
    camposBalanza.addAll([
      CampoEstado(nombre: 'Limpieza general'),
      CampoEstado(nombre: 'Golpes al terminal'),
      CampoEstado(nombre: 'Nivelacion'),
      CampoEstado(nombre: 'Limpieza receptor'),
      CampoEstado(nombre: 'Golpes al receptor de carga'),
      CampoEstado(nombre: 'Encendido'),
    ]);

    camposCajaSumadora.clear();
    camposCajaSumadora.addAll([
      CampoEstado(nombre: 'Limitador de movimiento'),
      CampoEstado(nombre: 'Suspensión'),
      CampoEstado(nombre: 'Limitador de carga'),
      CampoEstado(nombre: 'Celda de carga'),
      CampoEstado(nombre: 'Tapa de caja sumadora'),
      CampoEstado(nombre: 'Humedad Interna'),
      CampoEstado(nombre: 'Estado de prensacables'),
      CampoEstado(nombre: 'Estado de borneas'),
    ]);
  }

  // ═════════════════════════════════════════════════════════════════════
  //  SAVE PATH — Escribe a la tabla plana del módulo antiguo
  // ═════════════════════════════════════════════════════════════════════

  @override
  Future<void> guardarSesion() async {
    try {
      final data = _prepareDataForSave();
      data['session_id'] = model.sessionId;
      data['otst'] = secaValue;
      await _dbLegacy.upsertRegistroRelevamiento(data);
    } catch (_) {}
  }

  @override
  Future<void> finalizarServicio({
    required String horaFin,
    required String fechaProxServicio,
  }) async {
    this.horaFin = horaFin;
    this.fechaProxServicio = fechaProxServicio;
    final data = _prepareDataForSave();
    data['session_id'] = model.sessionId;
    data['otst'] = secaValue;
    data['estado_servicio'] = 'Completo';
    await _dbLegacy.upsertRegistroRelevamiento(data);
  }

  bool _isServiceComplete() {
    return comentarioGeneral.isNotEmpty &&
        recomendacion.isNotEmpty &&
        estadoFisico.isNotEmpty &&
        estadoOperacional.isNotEmpty &&
        estadoMetrologico.isNotEmpty &&
        horaFin.isNotEmpty &&
        fechaProxServicio.isNotEmpty;
  }

  Map<String, dynamic> _prepareDataForSave() {
    final data = <String, dynamic>{
      'estado_servicio': _isServiceComplete() ? 'Completo' : 'Pendiente',
      'tipo_servicio': 'MPR.BL',
      'cod_metrica': model.codMetrica,
      'cliente': clienteNombre,
      'planta': plantaNombre,
      'hora_inicio': horaInicio,
      'hora_fin': horaFin,
      'comentario_general': comentarioGeneral,
      'recomendacion': recomendacion,
      'estado_fisico': estadoFisico,
      'estado_operacional': estadoOperacional,
      'estado_metrologico': estadoMetrologico,
      'fecha_prox_servicio': fechaProxServicio,
      'fecha_servicio': DateTime.now().toIso8601String(),
    };

    _addCamposEstadoData(data);
    _addPruebasMetrologicasData(data);

    return data;
  }

  void _addCamposEstadoData(Map<String, dynamic> data) {
    void addCampo(String dbKey, List<CampoEstado> campos, String modelKey) {
      final idx = campos.indexWhere((c) => c.nombre == modelKey);
      if (idx < 0) return;
      final campo = campos[idx];
      data['${dbKey}_estado'] = campo.value;
      data['${dbKey}_solucion'] = campo.solutionValue;
      data['${dbKey}_foto'] = campo.fotos
          .where((f) => f.isNotEmpty)
          .join(',');
    }

    // Terminal (10)
    addCampo('carcasa', camposTerminal, 'Carcasa');
    addCampo('teclado_fisico', camposTerminal, 'Teclado Fisico');
    addCampo('display_fisico', camposTerminal, 'Display Fisico');
    addCampo('fuente_poder', camposTerminal, 'Fuente de poder');
    addCampo('bateria_operacional', camposTerminal, 'Bateria operacional');
    addCampo('bracket', camposTerminal, 'Bracket');
    addCampo('teclado_operativo', camposTerminal, 'Teclado Operativo');
    addCampo('display_operativo', camposTerminal, 'Display Operativo');
    addCampo('conector_celda', camposTerminal, 'Contector de celda');
    addCampo('bateria_memoria', camposTerminal, 'Bateria de memoria');
    // Balanza (6)
    addCampo('limpieza_general', camposBalanza, 'Limpieza general');
    addCampo('golpes_terminal', camposBalanza, 'Golpes al terminal');
    addCampo('nivelacion', camposBalanza, 'Nivelacion');
    addCampo('limpieza_receptor', camposBalanza, 'Limpieza receptor');
    addCampo('golpes_receptor', camposBalanza, 'Golpes al receptor de carga');
    addCampo('encendido', camposBalanza, 'Encendido');
    // Caja Sumadora (8)
    addCampo('limitador_movimiento', camposCajaSumadora, 'Limitador de movimiento');
    addCampo('suspension', camposCajaSumadora, 'Suspensión');
    addCampo('limitador_carga', camposCajaSumadora, 'Limitador de carga');
    addCampo('celda_carga', camposCajaSumadora, 'Celda de carga');
    addCampo('tapa_caja', camposCajaSumadora, 'Tapa de caja sumadora');
    addCampo('humedad_interna', camposCajaSumadora, 'Humedad Interna');
    addCampo('estado_prensacables', camposCajaSumadora, 'Estado de prensacables');
    addCampo('estado_borneas', camposCajaSumadora, 'Estado de borneas');
  }

  void _addPruebasMetrologicasData(Map<String, dynamic> data) {
    data['retorno_cero_inicial_valoracion'] = retornoCeroInicial;
    data['estabilizacion_inicial'] = estabilidadInicial;
    data['retorno_cero_final_valoracion'] = retornoCeroFinal;
    data['estabilizacion_final'] = estabilidadFinal;

    if (excentricidadRealizada) {
      _addExcentricidadData(data, excentricidadInicial, 'inicial');
      _addExcentricidadData(data, excentricidadFinal, 'final');
    }
    if (repetibilidadRealizada) {
      _addRepetibilidadData(data, repetibilidadInicial, 'inicial');
      _addRepetibilidadData(data, repetibilidadFinal, 'final');
    }
    if (linealidadRealizada) {
      _addLinealidadData(data, linealidadInicial, 'inicial');
      _addLinealidadData(data, linealidadFinal, 'final');
    }
  }

  void _addExcentricidadData(
      Map<String, dynamic> data, ExcentricidadData exc, String tipo) {
    data['tipo_plataforma_$tipo'] = exc.tipoPlataforma ?? '';
    data['puntos_ind_$tipo'] = exc.puntosIndicacion ?? '';
    data['carga_exc_$tipo'] = exc.carga ?? '';
    for (int i = 0; i < exc.posiciones.length && i < 6; i++) {
      final p = exc.posiciones[i];
      final n = i + 1;
      data['posicion_${tipo}_$n'] = p.posicion ?? '';
      data['indicacion_${tipo}_$n'] = p.indicacion ?? '';
      data['retorno_${tipo}_$n'] = p.retorno ?? '';
    }
  }

  void _addRepetibilidadData(
      Map<String, dynamic> data, RepetibilidadData rep, String tipo) {
    if (rep.cargas.isEmpty) return;
    final c = rep.cargas[0];
    data['repetibilidad1_$tipo'] = c.carga ?? '';
    for (int j = 0; j < c.indicaciones.length && j < 10; j++) {
      final n = j + 1;
      data['indicacion1_${tipo}_$n'] = c.indicaciones[j] ?? '';
      data['retorno1_${tipo}_$n'] =
          (c.retornos.length > j ? c.retornos[j] : '') ?? '';
    }
  }

  void _addLinealidadData(
      Map<String, dynamic> data, LinealidadData lin, String tipo) {
    for (int i = 0; i < lin.filas.length && i < 12; i++) {
      final f = lin.filas[i];
      final n = i + 1;
      data['lin_${tipo}_$n'] = f.carga ?? '';
      data['ind_${tipo}_$n'] = f.indicacion ?? '';
      data['retorno_lin_${tipo}_$n'] = f.retorno ?? '';
    }
  }

  // ═════════════════════════════════════════════════════════════════════
  //  LOAD PATH — Lee de la tabla plana del módulo antiguo
  // ═════════════════════════════════════════════════════════════════════

  @override
  Future<void> loadExistingSession(
      String sessionId, Map<String, dynamic> data) async {
    await super.loadExistingSession(sessionId, data);

    // Retorno a Cero / Estabilidad
    retornoCeroInicial =
        data['retorno_cero_inicial_valoracion']?.toString() ?? '';
    estabilidadInicial = data['estabilizacion_inicial']?.toString() ?? '';
    retornoCeroFinal =
        data['retorno_cero_final_valoracion']?.toString() ?? '';
    estabilidadFinal = data['estabilizacion_final']?.toString() ?? '';

    // Campos Estado de las columnas planas
    _loadCamposEstadoFromDb(data);

    // Pruebas metrológicas desde columnas planas
    _loadExcentricidadFromDb(data, true);
    _loadRepetibilidadFromDb(data, true);
    _loadLinealidadFromDb(data, true);
    _loadExcentricidadFromDb(data, false);
    _loadRepetibilidadFromDb(data, false);
    _loadLinealidadFromDb(data, false);

    notifyListeners();
  }

  void _loadCamposEstadoFromDb(Map<String, dynamic> data) {
    void loadCampo(String dbKey, List<CampoEstado> campos, String modelKey) {
      final idx = campos.indexWhere((c) => c.nombre == modelKey);
      if (idx < 0) return;
      final estado = data['${dbKey}_estado']?.toString() ?? '';
      final solucion = data['${dbKey}_solucion']?.toString() ?? '';
      if (estado.isNotEmpty) campos[idx].value = estado;
      if (solucion.isNotEmpty) campos[idx].solutionValue = solucion;
      final fotosRaw = data['${dbKey}_foto']?.toString() ?? '';
      if (fotosRaw.isNotEmpty) {
        campos[idx].fotos = fotosRaw
            .split(',')
            .where((n) => n.isNotEmpty)
            .toList();
      }
    }

    // Terminal
    loadCampo('carcasa', camposTerminal, 'Carcasa');
    loadCampo('teclado_fisico', camposTerminal, 'Teclado Fisico');
    loadCampo('display_fisico', camposTerminal, 'Display Fisico');
    loadCampo('fuente_poder', camposTerminal, 'Fuente de poder');
    loadCampo('bateria_operacional', camposTerminal, 'Bateria operacional');
    loadCampo('bracket', camposTerminal, 'Bracket');
    loadCampo('teclado_operativo', camposTerminal, 'Teclado Operativo');
    loadCampo('display_operativo', camposTerminal, 'Display Operativo');
    loadCampo('conector_celda', camposTerminal, 'Contector de celda');
    loadCampo('bateria_memoria', camposTerminal, 'Bateria de memoria');
    // Balanza
    loadCampo('limpieza_general', camposBalanza, 'Limpieza general');
    loadCampo('golpes_terminal', camposBalanza, 'Golpes al terminal');
    loadCampo('nivelacion', camposBalanza, 'Nivelacion');
    loadCampo('limpieza_receptor', camposBalanza, 'Limpieza receptor');
    loadCampo('golpes_receptor', camposBalanza, 'Golpes al receptor de carga');
    loadCampo('encendido', camposBalanza, 'Encendido');
    // Caja Sumadora
    loadCampo('limitador_movimiento', camposCajaSumadora,
        'Limitador de movimiento');
    loadCampo('suspension', camposCajaSumadora, 'Suspensión');
    loadCampo('limitador_carga', camposCajaSumadora, 'Limitador de carga');
    loadCampo('celda_carga', camposCajaSumadora, 'Celda de carga');
    loadCampo(
        'tapa_caja', camposCajaSumadora, 'Tapa de caja sumadora');
    loadCampo(
        'humedad_interna', camposCajaSumadora, 'Humedad Interna');
    loadCampo('estado_prensacables', camposCajaSumadora,
        'Estado de prensacables');
    loadCampo('estado_borneas', camposCajaSumadora, 'Estado de borneas');
  }

  void _loadExcentricidadFromDb(Map<String, dynamic> data, bool esInicial) {
    final tipo = esInicial ? 'inicial' : 'final';
    final tipoPlataforma = data['tipo_plataforma_$tipo']?.toString() ?? '';
    if (tipoPlataforma.isEmpty) return;

    final posiciones = <PosicionData>[];
    for (int i = 0; i < 6; i++) {
      final n = i + 1;
      final pos = data['posicion_${tipo}_$n']?.toString() ?? '';
      if (pos.isEmpty) continue;
      posiciones.add(PosicionData(
        posicion: pos,
        indicacion: data['indicacion_${tipo}_$n']?.toString() ?? '',
        retorno: data['retorno_${tipo}_$n']?.toString() ?? '',
      ));
    }

    final exc = ExcentricidadData(
      tipoPlataforma: tipoPlataforma,
      puntosIndicacion: data['puntos_ind_$tipo']?.toString() ?? '',
      carga: data['carga_exc_$tipo']?.toString() ?? '',
      posiciones: posiciones,
    );

    if (esInicial) {
      excentricidadInicial = exc;
      excentricidadRealizada = posiciones.isNotEmpty;
    } else {
      excentricidadFinal = exc;
    }
  }

  void _loadRepetibilidadFromDb(Map<String, dynamic> data, bool esInicial) {
    final tipo = esInicial ? 'inicial' : 'final';
    final cargaVal = data['repetibilidad1_$tipo']?.toString() ?? '';
    if (cargaVal.isEmpty) return;

    final indicaciones = <String?>[];
    final retornos = <String?>[];
    for (int j = 0; j < 10; j++) {
      final n = j + 1;
      final ind = data['indicacion1_${tipo}_$n']?.toString() ?? '';
      if (ind.isEmpty) break;
      indicaciones.add(ind);
      retornos.add(data['retorno1_${tipo}_$n']?.toString() ?? '');
    }

    final rep = RepetibilidadData(
      cargas: [
        CargaRepetibilidad(
          carga: cargaVal,
          indicaciones: indicaciones,
          retornos: retornos,
        ),
      ],
    );

    if (esInicial) {
      repetibilidadInicial = rep;
      repetibilidadRealizada = indicaciones.isNotEmpty;
    } else {
      repetibilidadFinal = rep;
    }
  }

  void _loadLinealidadFromDb(Map<String, dynamic> data, bool esInicial) {
    final tipo = esInicial ? 'inicial' : 'final';
    final primeraLin =
        data['lin_${tipo}_1']?.toString() ?? '';
    if (primeraLin.isEmpty) return;

    final filas = <FilaLinealidad>[];
    for (int i = 0; i < 12; i++) {
      final n = i + 1;
      final linVal = data['lin_${tipo}_$n']?.toString() ?? '';
      if (linVal.isEmpty) break;
      filas.add(FilaLinealidad(
        carga: linVal,
        indicacion: data['ind_${tipo}_$n']?.toString() ?? '',
        retorno: data['retorno_lin_${tipo}_$n']?.toString() ?? '',
      ));
    }

    final lin = LinealidadData(filas: filas);

    if (esInicial) {
      linealidadInicial = lin;
      linealidadRealizada = filas.isNotEmpty;
    } else {
      linealidadFinal = lin;
    }
  }

  // ═════════════════════════════════════════════════════════════════════
  //  QUERY PATH — Para FinServicioScreen
  // ═════════════════════════════════════════════════════════════════════

  @override
  Future<List<Map<String, dynamic>>> getRegistrosPorSeca(
    String tableName,
    String seca, {
    bool soloHoy = false,
  }) async {
    final all = await _dbLegacy.getAllRegistrosRelevamiento();
    final hoy = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final result = <Map<String, dynamic>>[];
    for (final r in all) {
      if (r['otst']?.toString() != seca) continue;
      if (r['estado_servicio']?.toString() != 'Completo') continue;
      if (soloHoy) {
        final fechaServ = r['fecha_servicio']?.toString() ?? '';
        if (!fechaServ.startsWith(hoy)) continue;
      }
      // Inyectamos un campo 'data' con JSON para que FinServicioScreen
      // pueda exportar CSV con el mismo código que los otros módulos.
      final data =
          Map<String, dynamic>.from(r)..remove('id')..remove('session_id');
      result.add({...r, 'data': jsonEncode(data)});
    }
    return result;
  }

  // ═════════════════════════════════════════════════════════════════════
  //  BUILD DATA MAP — para exportToCsv del BaseSoporteController
  // ═════════════════════════════════════════════════════════════════════

  @override
  Future<Map<String, dynamic>> buildDataMap() async {
    final map = await super.buildDataMap();
    map.addAll({
      'retorno_cero_inicial': retornoCeroInicial,
      'estabilidad_inicial': estabilidadInicial,
      'retorno_cero_final': retornoCeroFinal,
      'estabilidad_final': estabilidadFinal,
      'pruebas_iniciales': jsonEncode({
        'excentricidad': _excToMap(excentricidadInicial),
        'repetibilidad': _repToMap(repetibilidadInicial),
        'linealidad': _linToMap(linealidadInicial),
      }),
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
      'campos_terminal': jsonEncode(
        camposTerminal.map((c) => {
              'nombre': c.nombre,
              'value': c.value,
              'solutionValue': c.solutionValue,
              'solutionLabel': c.solutionLabel,
              'fotos': c.fotos,
            }).toList(),
      ),
      'campos_balanza': jsonEncode(
        camposBalanza.map((c) => {
              'nombre': c.nombre,
              'value': c.value,
              'solutionValue': c.solutionValue,
              'solutionLabel': c.solutionLabel,
              'fotos': c.fotos,
            }).toList(),
      ),
      'campos_caja_sumadora': jsonEncode(
        camposCajaSumadora.map((c) => {
              'nombre': c.nombre,
              'value': c.value,
              'solutionValue': c.solutionValue,
              'solutionLabel': c.solutionLabel,
              'fotos': c.fotos,
            }).toList(),
      ),
    });
    return map;
  }

  // ── Serialización de pruebas metrológicas ────────────────────────────

  static Map<String, dynamic> _linToMap(LinealidadData d) => {
        'metodo': d.metodo,
        'metodoCarga': d.metodoCarga,
        'nota': d.nota,
        'filas': d.filas
            .map((f) => {
                  'carga': f.carga,
                  'indicacion': f.indicacion,
                  'retorno': f.retorno,
                })
            .toList(),
      };

  static Map<String, dynamic> _repToMap(RepetibilidadData d) => {
        'nota': d.nota,
        'cargas': d.cargas
            .map((c) => {
                  'carga': c.carga,
                  'indicaciones': c.indicaciones,
                  'retornos': c.retornos,
                })
            .toList(),
      };

  static Map<String, dynamic> _excToMap(ExcentricidadData d) => {
        'tipoPlataforma': d.tipoPlataforma,
        'puntosIndicacion': d.puntosIndicacion,
        'carga': d.carga,
        'nota': d.nota,
        'posiciones': d.posiciones
            .map((p) => {
                  'posicion': p.posicion,
                  'indicacion': p.indicacion,
                  'retorno': p.retorno,
                })
            .toList(),
      };

}
