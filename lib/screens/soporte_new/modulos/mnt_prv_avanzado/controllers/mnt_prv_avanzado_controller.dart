import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:service_met/database/soporte_tecnico/database_helper_mnt_prv_avanzado_stac.dart';
import 'package:service_met/models/service_session.dart';
import 'package:service_met/screens/soporte_new/controllers/base_soporte_controller.dart';
import 'package:service_met/screens/soporte_new/models/campo_estado.dart';
import 'package:service_met/screens/soporte_new/modulos/mnt_prv_avanzado/models/mnt_prv_avanzado_model.dart';

class MntPrvAvanzadoController extends BaseSoporteController {
  @override
  String get tableName => 'mnt_prv_avanzado_stac';

  @override
  String get tipoServicio => 'MNT PREVENTIVO AVANZADO';

  @override
  final MntPrvAvanzadoModel model;

  // ── Grupos de inspección ────────────────────────────────────────────
  final List<CampoEstado> camposLozas = [];
  final List<CampoEstado> camposLimpieza = [];
  final List<CampoEstado> camposChequeo = [];
  final List<CampoEstado> camposElectricas = [];
  final List<CampoEstado> camposProteccionCeldas = [];
  final List<CampoEstado> camposTerminalCalibracion = [];

  final DatabaseHelperMntPrvAvanzadoStac _dbLegacy =
      DatabaseHelperMntPrvAvanzadoStac();

  // ── Cliente / Planta / Personal ──────────────────────────────────────
  String razonSocial = '';
  String dirPlanta = '';
  String depPlanta = '';
  String codPlanta = '';
  String personal = '';

  // ── Balanza / Instrumento ────────────────────────────────────────────
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

  // ── Retorno a Cero / Estabilidad ────────────────────────────────────
  String retornoCeroInicial = '';
  String estabilidadInicial = '';
  String retornoCeroFinal = '';
  String estabilidadFinal = '';

  // ── Pruebas metrológicas (activo flags) ──────────────────────────────
  bool excentricidadRealizada = true;
  bool repetibilidadRealizada = true;
  bool linealidadRealizada = true;

  // ── Pruebas metrológicas (datos) ─────────────────────────────────────
  ExcentricidadData excentricidadInicial = ExcentricidadData();
  ExcentricidadData excentricidadFinal = ExcentricidadData();
  RepetibilidadData repetibilidadInicial = RepetibilidadData();
  RepetibilidadData repetibilidadFinal = RepetibilidadData();
  LinealidadData linealidadInicial = LinealidadData();
  LinealidadData linealidadFinal = LinealidadData();

  MntPrvAvanzadoController({required this.model}) {
    totalSteps = 9;
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
    // ── Lozas y Fundaciones (2) ──────────────────────────────────────
    camposLozas.clear();
    camposLozas.addAll([
      CampoEstado(nombre: 'Losas de aproximación (daños o grietas)'),
      CampoEstado(nombre: 'Fundaciones (daños o grietas)'),
    ]);

    // ── Limpieza y Drenaje (4) ────────────────────────────────────────
    camposLimpieza.clear();
    camposLimpieza.addAll([
      CampoEstado(nombre: 'Limpieza de perímetro de balanza'),
      CampoEstado(nombre: 'Fosa libre de humedad'),
      CampoEstado(nombre: 'Drenaje libre'),
      CampoEstado(nombre: 'Bomba de sumidero funcional'),
    ]);

    // ── Chequeo General (8) ──────────────────────────────────────────
    camposChequeo.clear();
    camposChequeo.addAll([
      CampoEstado(nombre: 'Corrosión'),
      CampoEstado(nombre: 'Puente de pesaje (grietas)'),
      CampoEstado(nombre: 'Tapas superiores y pernos'),
      CampoEstado(nombre: 'Desgaste y estrés'),
      CampoEstado(nombre: 'Limpieza por debajo del puente'),
      CampoEstado(nombre: 'Estado rieles laterales'),
      CampoEstado(nombre: 'Limitadores Longitudinales'),
      CampoEstado(nombre: 'Limitadores Transversales'),
    ]);

    // ── Verificaciones Eléctricas (6) ─────────────────────────────────
    camposElectricas.clear();
    camposElectricas.addAll([
      CampoEstado(nombre: 'Cable home run'),
      CampoEstado(nombre: 'Cables de celdas de carga'),
      CampoEstado(nombre: 'Conexión entre celda de carga y cable'),
      CampoEstado(nombre: 'Conectores de celdas de carga'),
      CampoEstado(nombre: 'Conector de terminación'),
      CampoEstado(nombre: 'Caja de unión o Sumadora'),
    ]);

    // ── Protección Rayos + Células (11) ───────────────────────────────
    camposProteccionCeldas.clear();
    camposProteccionCeldas.addAll([
      // Protección contra Rayos (4)
      CampoEstado(nombre: 'Sistema de Protección contra Rayos'),
      CampoEstado(nombre: 'Conexión de Malla de Tierra'),
      CampoEstado(nombre: 'Tensión entre neutro y tierra adecuada'),
      CampoEstado(nombre: 'Estado strike shield'),
      // Verificaciones de Células (7)
      CampoEstado(nombre: 'Limpieza e inspección conectores'),
      CampoEstado(
          nombre:
              'Limpieza e inspección de superficies de acoplamiento de la estructura'),
      CampoEstado(nombre: 'Limpieza e inspección de bearing cups'),
      CampoEstado(nombre: 'Limpieza e inspección de celdas de carga'),
      CampoEstado(nombre: 'Lubricacion celdas de carga'),
      CampoEstado(nombre: 'Lubricación bearing cups'),
      CampoEstado(nombre: 'Protector de goma para celdas'),
    ]);

    // ── Terminal + Calibración (9) ────────────────────────────────────
    camposTerminalCalibracion.clear();
    camposTerminalCalibracion.addAll([
      // Terminal (8)
      CampoEstado(nombre: 'Carcasa'),
      CampoEstado(nombre: 'Voltaje pila de Boton'),
      CampoEstado(nombre: 'Estado del teclado'),
      CampoEstado(nombre: 'Estado del display'),
      CampoEstado(nombre: 'Registros Predictivo solo PDX'),
      CampoEstado(nombre: 'Alertas de servicio MT'),
      CampoEstado(nombre: 'Estado prensacables:'),
      CampoEstado(nombre: 'Comunicación con PC'),
      // Calibración (1)
      CampoEstado(
          nombre: 'Balanza apta para Verificación Dentro tolerancias NB23001'),
    ]);
  }

  // ═════════════════════════════════════════════════════════════════════
  //  SAVE PATH
  // ═════════════════════════════════════════════════════════════════════

  @override
  Future<void> guardarSesion() async {
    setSaveInProgress();
    try {
      final data = _prepareDataForSave();
      data['session_id'] = model.sessionId;
      data['otst'] = secaValue;
      await _dbLegacy.upsertRegistroRelevamiento(data);
      setSaveSuccess(true);
    } catch (e) {
      debugPrint('Error guardando sesión $tableName: $e');
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
      final data = _prepareDataForSave();
      data['session_id'] = model.sessionId;
      data['otst'] = secaValue;
      data['estado_servicio'] = 'Completo';
      await _dbLegacy.upsertRegistroRelevamiento(data);
      setSaveSuccess(true);
    } catch (e) {
      debugPrint('Error al finalizar servicio $tableName: $e');
      setSaveSuccess(false);
      rethrow;
    }
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
      'tipo_servicio': 'MPA.SP',
      'cod_metrica': model.codMetrica,
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
      'comentario_general': comentarioGeneral,
      'recomendacion': recomendacion,
      'fisico': estadoFisico,
      'operacional': estadoOperacional,
      'metrologico': estadoMetrologico,
      'fecha_prox_servicio': fechaProxServicio,
      'fecha_servicio': DateFormat('yyyy-MM-dd').format(DateTime.now()),
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
      data['${dbKey}_foto'] = campo.fotos.where((f) => f.isNotEmpty).join(',');
    }

    // Lozas y Fundaciones (2)
    addCampo('losas_aproximacion', camposLozas,
        'Losas de aproximación (daños o grietas)');
    addCampo('fundaciones', camposLozas, 'Fundaciones (daños o grietas)');

    // Limpieza y Drenaje (4)
    addCampo('limpieza_perimetro', camposLimpieza,
        'Limpieza de perímetro de balanza');
    addCampo('fosa_humedad', camposLimpieza, 'Fosa libre de humedad');
    addCampo('drenaje_libre', camposLimpieza, 'Drenaje libre');
    addCampo('bomba_sumidero', camposLimpieza, 'Bomba de sumidero funcional');

    // Chequeo General (8)
    addCampo('corrosion', camposChequeo, 'Corrosión');
    addCampo('puente_grietas', camposChequeo, 'Puente de pesaje (grietas)');
    addCampo('tapas_pernos', camposChequeo, 'Tapas superiores y pernos');
    addCampo('desgaste_estres', camposChequeo, 'Desgaste y estrés');
    addCampo(
        'limpieza_puente', camposChequeo, 'Limpieza por debajo del puente');
    addCampo('estado_rieles', camposChequeo, 'Estado rieles laterales');
    addCampo('limitadores_long', camposChequeo, 'Limitadores Longitudinales');
    addCampo('limitadores_trans', camposChequeo, 'Limitadores Transversales');

    // Verificaciones Eléctricas (6)
    addCampo('cable_homerun', camposElectricas, 'Cable home run');
    addCampo('cables_celdas', camposElectricas, 'Cables de celdas de carga');
    addCampo('conexion_celda_cable', camposElectricas,
        'Conexión entre celda de carga y cable');
    addCampo(
        'conectores_celdas', camposElectricas, 'Conectores de celdas de carga');
    addCampo(
        'conector_terminacion', camposElectricas, 'Conector de terminación');
    addCampo('caja_union', camposElectricas, 'Caja de unión o Sumadora');

    // Protección contra Rayos (4 primeros de camposProteccionCeldas)
    addCampo('sistema_proteccion_rayos', camposProteccionCeldas,
        'Sistema de Protección contra Rayos');
    addCampo('conexion_malla_tierra', camposProteccionCeldas,
        'Conexión de Malla de Tierra');
    addCampo('tension_neutro_tierra', camposProteccionCeldas,
        'Tensión entre neutro y tierra adecuada');
    addCampo(
        'estado_strike_shield', camposProteccionCeldas, 'Estado strike shield');

    // Verificaciones de Células (7 siguientes de camposProteccionCeldas)
    addCampo('limpieza_conectores', camposProteccionCeldas,
        'Limpieza e inspección conectores');
    addCampo('limpieza_estructura', camposProteccionCeldas,
        'Limpieza e inspección de superficies de acoplamiento de la estructura');
    addCampo('bearing_cups', camposProteccionCeldas,
        'Limpieza e inspección de bearing cups');
    addCampo('celdas_carga', camposProteccionCeldas,
        'Limpieza e inspección de celdas de carga');
    addCampo('lubricacion_celdas', camposProteccionCeldas,
        'Lubricacion celdas de carga');
    addCampo('lubricacion_bearing', camposProteccionCeldas,
        'Lubricación bearing cups');
    addCampo('protector_goma', camposProteccionCeldas,
        'Protector de goma para celdas');

    // Terminal (8 primeros de camposTerminalCalibracion)
    addCampo('carcasa', camposTerminalCalibracion, 'Carcasa');
    addCampo(
        'voltaje_pila', camposTerminalCalibracion, 'Voltaje pila de Boton');
    addCampo('estado_teclado', camposTerminalCalibracion, 'Estado del teclado');
    addCampo('estado_display', camposTerminalCalibracion, 'Estado del display');
    addCampo('registros_predictivo', camposTerminalCalibracion,
        'Registros Predictivo solo PDX');
    addCampo('alertas_servicio', camposTerminalCalibracion,
        'Alertas de servicio MT');
    addCampo('estado_prensacables', camposTerminalCalibracion,
        'Estado prensacables:');
    addCampo(
        'comunicacion_pc', camposTerminalCalibracion, 'Comunicación con PC');

    // Calibración (último de camposTerminalCalibracion)
    addCampo('balanza_apta', camposTerminalCalibracion,
        'Balanza apta para Verificación Dentro tolerancias NB23001');
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
    for (int i = 0; i < exc.posiciones.length && i < 10; i++) {
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
  //  LOAD PATH
  // ═════════════════════════════════════════════════════════════════════

  @override
  Future<void> loadExistingSession(
      String sessionId, Map<String, dynamic> data) async {
    await super.loadExistingSession(sessionId, data);

    estadoFisico = data['fisico']?.toString() ?? '';
    estadoOperacional = data['operacional']?.toString() ?? '';
    estadoMetrologico = data['metrologico']?.toString() ?? '';

    razonSocial = data['razon_social']?.toString() ?? '';
    dirPlanta = data['dir_planta']?.toString() ?? '';
    depPlanta = data['dep_planta']?.toString() ?? '';
    codPlanta = data['cod_planta']?.toString() ?? '';
    personal = data['personal']?.toString() ?? '';

    infBal = data['inf_bal']?.toString() ?? '';
    categoriaBalanza = data['categoria_balanza']?.toString() ?? '';
    codInt = data['cod_int']?.toString() ?? '';
    tipoEquipo = data['tipo_equipo']?.toString() ?? '';
    marca = data['marca']?.toString() ?? '';
    modelo = data['modelo']?.toString() ?? '';
    serie = data['serie']?.toString() ?? '';
    unidades = data['unidades']?.toString() ?? '';
    numCeldas = data['num_celdas']?.toString() ?? '';
    ubicacion = data['ubicacion']?.toString() ?? '';
    capMax1 = data['cap_max1']?.toString() ?? '';
    d1 = data['d1']?.toString() ?? '';
    e1 = data['e1']?.toString() ?? '';
    dec1 = data['dec1']?.toString() ?? '';
    capMax2 = data['cap_max2']?.toString() ?? '';
    d2 = data['d2']?.toString() ?? '';
    e2 = data['e2']?.toString() ?? '';
    dec2 = data['dec2']?.toString() ?? '';
    capMax3 = data['cap_max3']?.toString() ?? '';
    d3 = data['d3']?.toString() ?? '';
    e3 = data['e3']?.toString() ?? '';
    dec3 = data['dec3']?.toString() ?? '';

    retornoCeroInicial =
        data['retorno_cero_inicial_valoracion']?.toString() ?? '';
    estabilidadInicial = data['estabilizacion_inicial']?.toString() ?? '';
    retornoCeroFinal = data['retorno_cero_final_valoracion']?.toString() ?? '';
    estabilidadFinal = data['estabilizacion_final']?.toString() ?? '';

    _loadCamposEstadoFromDb(data);

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
        campos[idx].fotos =
            fotosRaw.split(',').where((n) => n.isNotEmpty).toList();
      }
    }

    // Lozas
    loadCampo('losas_aproximacion', camposLozas,
        'Losas de aproximación (daños o grietas)');
    loadCampo('fundaciones', camposLozas, 'Fundaciones (daños o grietas)');

    // Limpieza
    loadCampo('limpieza_perimetro', camposLimpieza,
        'Limpieza de perímetro de balanza');
    loadCampo('fosa_humedad', camposLimpieza, 'Fosa libre de humedad');
    loadCampo('drenaje_libre', camposLimpieza, 'Drenaje libre');
    loadCampo('bomba_sumidero', camposLimpieza, 'Bomba de sumidero funcional');

    // Chequeo
    loadCampo('corrosion', camposChequeo, 'Corrosión');
    loadCampo('puente_grietas', camposChequeo, 'Puente de pesaje (grietas)');
    loadCampo('tapas_pernos', camposChequeo, 'Tapas superiores y pernos');
    loadCampo('desgaste_estres', camposChequeo, 'Desgaste y estrés');
    loadCampo(
        'limpieza_puente', camposChequeo, 'Limpieza por debajo del puente');
    loadCampo('estado_rieles', camposChequeo, 'Estado rieles laterales');
    loadCampo('limitadores_long', camposChequeo, 'Limitadores Longitudinales');
    loadCampo('limitadores_trans', camposChequeo, 'Limitadores Transversales');

    // Eléctricas
    loadCampo('cable_homerun', camposElectricas, 'Cable home run');
    loadCampo('cables_celdas', camposElectricas, 'Cables de celdas de carga');
    loadCampo('conexion_celda_cable', camposElectricas,
        'Conexión entre celda de carga y cable');
    loadCampo(
        'conectores_celdas', camposElectricas, 'Conectores de celdas de carga');
    loadCampo(
        'conector_terminacion', camposElectricas, 'Conector de terminación');
    loadCampo('caja_union', camposElectricas, 'Caja de unión o Sumadora');

    // Protección Rayos
    loadCampo('sistema_proteccion_rayos', camposProteccionCeldas,
        'Sistema de Protección contra Rayos');
    loadCampo('conexion_malla_tierra', camposProteccionCeldas,
        'Conexión de Malla de Tierra');
    loadCampo('tension_neutro_tierra', camposProteccionCeldas,
        'Tensión entre neutro y tierra adecuada');
    loadCampo(
        'estado_strike_shield', camposProteccionCeldas, 'Estado strike shield');

    // Células
    loadCampo('limpieza_conectores', camposProteccionCeldas,
        'Limpieza e inspección conectores');
    loadCampo('limpieza_estructura', camposProteccionCeldas,
        'Limpieza e inspección de superficies de acoplamiento de la estructura');
    loadCampo('bearing_cups', camposProteccionCeldas,
        'Limpieza e inspección de bearing cups');
    loadCampo('celdas_carga', camposProteccionCeldas,
        'Limpieza e inspección de celdas de carga');
    loadCampo('lubricacion_celdas', camposProteccionCeldas,
        'Lubricacion celdas de carga');
    loadCampo('lubricacion_bearing', camposProteccionCeldas,
        'Lubricación bearing cups');
    loadCampo('protector_goma', camposProteccionCeldas,
        'Protector de goma para celdas');

    // Terminal
    loadCampo('carcasa', camposTerminalCalibracion, 'Carcasa');
    loadCampo(
        'voltaje_pila', camposTerminalCalibracion, 'Voltaje pila de Boton');
    loadCampo(
        'estado_teclado', camposTerminalCalibracion, 'Estado del teclado');
    loadCampo(
        'estado_display', camposTerminalCalibracion, 'Estado del display');
    loadCampo('registros_predictivo', camposTerminalCalibracion,
        'Registros Predictivo solo PDX');
    loadCampo('alertas_servicio', camposTerminalCalibracion,
        'Alertas de servicio MT');
    loadCampo('estado_prensacables', camposTerminalCalibracion,
        'Estado prensacables:');
    loadCampo(
        'comunicacion_pc', camposTerminalCalibracion, 'Comunicación con PC');

    // Calibración
    loadCampo('balanza_apta', camposTerminalCalibracion,
        'Balanza apta para Verificación Dentro tolerancias NB23001');
  }

  void _loadExcentricidadFromDb(Map<String, dynamic> data, bool esInicial) {
    final tipo = esInicial ? 'inicial' : 'final';
    final tipoPlataforma = data['tipo_plataforma_$tipo']?.toString() ?? '';
    if (tipoPlataforma.isEmpty) return;

    final posiciones = <PosicionData>[];
    for (int i = 0; i < 10; i++) {
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
    final primeraLin = data['lin_${tipo}_1']?.toString() ?? '';
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
      final data = Map<String, dynamic>.from(r)
        ..remove('id')
        ..remove('session_id');
      result.add({...r, 'data': jsonEncode(data)});
    }
    return result;
  }

  // ═════════════════════════════════════════════════════════════════════
  //  BUILD DATA MAP — para exportToCsv del base
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
      'campos_lozas': jsonEncode(
        camposLozas
            .map((c) => ({
                  'nombre': c.nombre,
                  'value': c.value,
                  'solutionValue': c.solutionValue,
                  'solutionLabel': c.solutionLabel,
                  'fotos': c.fotos,
                }))
            .toList(),
      ),
      'campos_limpieza': jsonEncode(
        camposLimpieza
            .map((c) => ({
                  'nombre': c.nombre,
                  'value': c.value,
                  'solutionValue': c.solutionValue,
                  'solutionLabel': c.solutionLabel,
                  'fotos': c.fotos,
                }))
            .toList(),
      ),
      'campos_chequeo': jsonEncode(
        camposChequeo
            .map((c) => ({
                  'nombre': c.nombre,
                  'value': c.value,
                  'solutionValue': c.solutionValue,
                  'solutionLabel': c.solutionLabel,
                  'fotos': c.fotos,
                }))
            .toList(),
      ),
      'campos_electricas': jsonEncode(
        camposElectricas
            .map((c) => ({
                  'nombre': c.nombre,
                  'value': c.value,
                  'solutionValue': c.solutionValue,
                  'solutionLabel': c.solutionLabel,
                  'fotos': c.fotos,
                }))
            .toList(),
      ),
      'campos_proteccion_celdas': jsonEncode(
        camposProteccionCeldas
            .map((c) => ({
                  'nombre': c.nombre,
                  'value': c.value,
                  'solutionValue': c.solutionValue,
                  'solutionLabel': c.solutionLabel,
                  'fotos': c.fotos,
                }))
            .toList(),
      ),
      'campos_terminal_calibracion': jsonEncode(
        camposTerminalCalibracion
            .map((c) => ({
                  'nombre': c.nombre,
                  'value': c.value,
                  'solutionValue': c.solutionValue,
                  'solutionLabel': c.solutionLabel,
                  'fotos': c.fotos,
                }))
            .toList(),
      ),
    });
    return map;
  }

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
