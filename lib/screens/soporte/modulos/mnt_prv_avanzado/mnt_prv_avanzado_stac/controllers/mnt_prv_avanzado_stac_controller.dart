// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:service_met/screens/soporte/controllers/base_soporte_controller.dart';
import '../../../../../../database/soporte_tecnico/database_helper_mnt_prv_avanzado_stac.dart';
import '../models/mnt_prv_avanzado_stac_model.dart';

class MntPrvAvanzadoStacController extends BaseSoporteController<MntPrvAvanzadoStacModel> {
  Timer? _autoSaveTimer;
  final ValueNotifier<bool> isAutoSaving = ValueNotifier(false);
  final ValueNotifier<bool> lastSaveSuccessful = ValueNotifier(true);

  MntPrvAvanzadoStacController({required super.model});

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
      final dbHelper = DatabaseHelperMntPrvAvanzadoStac();
      final Map<String, dynamic> mntPrvData = prepareDataForSave();

      mntPrvData['session_id'] = model.sessionId;
      mntPrvData['otst'] = model.secaValue;

      await dbHelper.upsertRegistroRelevamiento(mntPrvData);
      lastSaveSuccessful.value = true;
    } catch (e) {
      lastSaveSuccessful.value = false;
      debugPrint('Error en auto-guardado: $e');
    } finally {
      isAutoSaving.value = false;
    }
  }

  void copiarPruebasInicialesAFinales() {
    model.copiarPruebasInicialesAFinales();
  }

  Future<void> loadInitialValues() async {
    try {
      final dbHelper = DatabaseHelperMntPrvAvanzadoStac();
      final db = await dbHelper.database;
      final results = await db.query(
        'mnt_prv_avanzado_stac',
        where: 'session_id = ? AND otst = ?',
        whereArgs: [model.sessionId, model.secaValue],
        limit: 1,
      );

      if (results.isNotEmpty) {
        final registro = results.first;

        // Recuperar campos fijos
        model.horaFin = registro['hora_fin']?.toString() ?? '';
        model.comentarioGeneral =
            registro['comentario_general']?.toString() ?? '';
        model.recomendacion = registro['recomendacion']?.toString() ?? '';
        model.estadoFisico = registro['fisico']?.toString() ?? '';
        model.estadoOperacional = registro['operacional']?.toString() ?? '';
        model.estadoMetrologico = registro['metrologico']?.toString() ?? '';
        model.fechaProxServicio =
            registro['fecha_prox_servicio']?.toString() ?? '';

        // Campos Estado Dinámicos
        final camposMap = {
          'losas_aproximacion': 'Losas de aproximación (daños o grietas)',
          'fundaciones': 'Fundaciones (daños o grietas)',
          'limpieza_perimetro': 'Limpieza de perímetro de balanza',
          'fosa_humedad': 'Fosa libre de humedad',
          'drenaje_libre': 'Drenaje libre',
          'bomba_sumidero': 'Bomba de sumidero funcional',
          'corrosion': 'Corrosión',
          'puente_grietas': 'Puente de pesaje (grietas)',
          'tapas_pernos': 'Tapas superiores y pernos',
          'desgaste_estres': 'Desgaste y estrés',
          'limpieza_puente': 'Limpieza por debajo del puente',
          'estado_rieles': 'Estado rieles laterales',
          'limitadores_long': 'Limitadores Longitudinales',
          'limitadores_trans': 'Limitadores Transversales',
          'cable_homerun': 'Cable home run',
          'cables_celdas': 'Cables de celdas de carga',
          'conexion_celda_cable': 'Conexión entre celda de carga y cable',
          'conectores_celdas': 'Conectores de celdas de carga',
          'conector_terminacion': 'Conector de terminación',
          'caja_union': 'Caja de unión o Sumadora',
          'sistema_proteccion_rayos': 'Sistema de Protección contra Rayos',
          'conexion_malla_tierra': 'Conexión de Malla de Tierra',
          'tension_neutro_tierra': 'Tensión entre neutro y tierra adecuada',
          'estado_strike_shield': 'Estado strike shield',
          'limpieza_conectores': 'Limpieza e inspección conectores',
          'limpieza_estructura':
              'Limpieza e inspección de superficies de acoplamiento de la estructura',
          'bearing_cups': 'Limpieza e inspección de bearing cups',
          'celdas_carga': 'Limpieza e inspección de celdas de carga',
          'lubricacion_celdas': 'Lubricacion celdas de carga',
          'lubricacion_bearing': 'Lubricación bearing cups',
          'protector_goma': 'Protector de goma para celdas',
          'carcasa': 'Carcasa',
          'voltaje_pila': 'Voltaje pila de Boton',
          'estado_teclado': 'Estado del teclado',
          'estado_display': 'Estado del display',
          'registros_predictivo': 'Registros Predictivo solo PDX',
          'alertas_servicio': 'Alertas de servicio MT',
          'estado_prensacables': 'Estado prensacables:',
          'comunicacion_pc': 'Comunicación con PC',
          'balanza_apta':
              'Balanza apta para Verificación Dentro tolerancias NB23001',
        };

        camposMap.forEach((dbKey, modelKey) {
          if (model.camposEstado.containsKey(modelKey)) {
            final estado = registro['${dbKey}_estado']?.toString();
            final solucion = registro['${dbKey}_solucion']?.toString();
            if (estado != null && estado.isNotEmpty) {
              model.camposEstado[modelKey]!.initialValue = estado;
            }
            if (solucion != null && solucion.isNotEmpty) {
              model.camposEstado[modelKey]!.solutionValue = solucion;
            }
          }
        });

        // Pruebas Iniciales
        final retCeroIniVal =
            registro['retorno_cero_inicial_valoracion']?.toString();
        if (retCeroIniVal != null && retCeroIniVal.isNotEmpty) {
          model.pruebasIniciales.retornoCero.estado = retCeroIniVal;
        }

        final estabIni = registro['estabilizacion_inicial']?.toString();
        if (estabIni != null && estabIni.isNotEmpty) {
          model.pruebasIniciales.retornoCero.estabilidad = estabIni;
        }

        _loadExcentricidadData(registro, model.pruebasIniciales, 'inicial');
        _loadRepetibilidadData(registro, model.pruebasIniciales, 'inicial');
        _loadLinealidadData(registro, model.pruebasIniciales, 'inicial');

        // Pruebas Finales
        final retCeroFinVal =
            registro['retorno_cero_final_valoracion']?.toString();
        if (retCeroFinVal != null && retCeroFinVal.isNotEmpty) {
          model.pruebasFinales.retornoCero.estado = retCeroFinVal;
        }

        final estabFin = registro['estabilizacion_final']?.toString();
        if (estabFin != null && estabFin.isNotEmpty) {
          model.pruebasFinales.retornoCero.estabilidad = estabFin;
        }

        _loadExcentricidadData(registro, model.pruebasFinales, 'final');
        _loadRepetibilidadData(registro, model.pruebasFinales, 'final');
        _loadLinealidadData(registro, model.pruebasFinales, 'final');
      }
    } catch (e) {
      debugPrint('Error al cargar initial values en MNT STAC: $e');
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
      // Only handling 1 carga to match table setup
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

  @override
  Future<void> saveData(BuildContext context) async {
    try {
      // Primero guardar fotos si existen
      await savePhotos(context);

      final dbHelper = DatabaseHelperMntPrvAvanzadoStac();
      final Map<String, dynamic> mntPrvData = prepareDataForSave();

      mntPrvData['session_id'] = model.sessionId;
      mntPrvData['otst'] = model.secaValue;

      await dbHelper.upsertRegistroRelevamiento(mntPrvData);

      if (context.mounted) {
        showSnackBar(context, 'Datos guardados exitosamente', isError: false);
      }
    } catch (e) {
      debugPrint('Error al guardar en BD: $e');
      if (context.mounted) {
        showSnackBar(context, 'Error al guardar los datos: ${e.toString()}', isError: true);
      }
    }
  }


  // Método helper para verificar si el servicio está completo
  bool _isServiceComplete() {
    return model.comentarioGeneral.isNotEmpty &&
        model.recomendacion.isNotEmpty &&
        model.estadoFisico.isNotEmpty &&
        model.estadoOperacional.isNotEmpty &&
        model.estadoMetrologico.isNotEmpty &&
        model.horaFin.isNotEmpty &&
        model.fechaProxServicio.isNotEmpty;
  }

  @override
  Map<String, dynamic> prepareDataForSave() {
    final data = <String, dynamic>{
      'estado_servicio': _isServiceComplete() ? 'Completo' : 'Pendiente',
      'session_id': model.sessionId,
      'cod_metrica': model.codMetrica,
      'otst': model.secaValue,
      'tipo_servicio': 'MPA.SP',
      'hora_inicio': model.horaInicio,
      'hora_fin': model.horaFin,
      'comentario_general': model.comentarioGeneral,
      'recomendacion': model.recomendacion,
      'fisico': model.estadoFisico,
      'operacional': model.estadoOperacional,
      'metrologico': model.estadoMetrologico,
      'fecha_prox_servicio': model.fechaProxServicio,
    };

    _addCamposEstadoData(data);
    _addPruebasMetrologicasData(data);

    return data;
  }

  // REFACTORIZADO: Agregar datos de campos de estado
  void _addCamposEstadoData(Map<String, dynamic> data) {
    // Función auxiliar simplificada
    void addCampo(String dbKey, String modelKey) {
      final campo = model.camposEstado[modelKey];
      if (campo != null) {
        data['${dbKey}_estado'] = campo.initialValue;
        data['${dbKey}_solucion'] = campo.solutionValue;
        data['${dbKey}_foto'] = campo.fotos.isNotEmpty
            ? campo.fotos.map((f) => f.path.split('/').last).join(',')
            : '';
      }
    }

    // MAPEO ACTUALIZADO CON NOMBRES DE BD CORRECTOS
    final camposMap = {
      // Lozas y Fundaciones
      'losas_aproximacion': 'Losas de aproximación (daños o grietas)',
      'fundaciones': 'Fundaciones (daños o grietas)',

      // Limpieza y Drenaje
      'limpieza_perimetro': 'Limpieza de perímetro de balanza',
      'fosa_humedad': 'Fosa libre de humedad',
      'drenaje_libre': 'Drenaje libre',
      'bomba_sumidero': 'Bomba de sumidero funcional',

      // Chequeo
      'corrosion': 'Corrosión',
      'puente_grietas': 'Puente de pesaje (grietas)',
      'tapas_pernos': 'Tapas superiores y pernos',
      'desgaste_estres': 'Desgaste y estrés',
      'limpieza_puente': 'Limpieza por debajo del puente',
      'estado_rieles': 'Estado rieles laterales',
      'limitadores_long': 'Limitadores Longitudinales',
      'limitadores_trans': 'Limitadores Transversales',

      // Verificaciones Eléctricas (CORREGIDO)
      'cable_homerun': 'Cable home run',
      'cables_celdas': 'Cables de celdas de carga',
      'conexion_celda_cable': 'Conexión entre celda de carga y cable',
      'conectores_celdas': 'Conectores de celdas de carga',
      'conector_terminacion': 'Conector de terminación',
      'caja_union': 'Caja de unión o Sumadora',

      // Protección contra Rayos
      'sistema_proteccion_rayos': 'Sistema de Protección contra Rayos',
      'conexion_malla_tierra': 'Conexión de Malla de Tierra',
      'tension_neutro_tierra': 'Tensión entre neutro y tierra adecuada',
      'estado_strike_shield': 'Estado strike shield',

      //Verificaciones de Células de Carga (nombres exactos de BD)
      'limpieza_conectores': 'Limpieza e inspección conectores',
      'limpieza_estructura':
          'Limpieza e inspección de superficies de acoplamiento de la estructura',
      'bearing_cups': 'Limpieza e inspección de bearing cups',
      'celdas_carga': 'Limpieza e inspección de celdas de carga',
      'lubricacion_celdas': 'Lubricacion celdas de carga',
      'lubricacion_bearing': 'Lubricación bearing cups',
      'protector_goma': 'Protector de goma para celdas',

      // Terminal
      'carcasa': 'Carcasa',
      'voltaje_pila': 'Voltaje pila de Boton',
      'estado_teclado': 'Estado del teclado',
      'estado_display': 'Estado del display',
      'registros_predictivo': 'Registros Predictivo solo PDX',
      'alertas_servicio': 'Alertas de servicio MT',
      'estado_prensacables': 'Estado prensacables:',
      'comunicacion_pc': 'Comunicación con PC',

      // Calibración
      'balanza_apta':
          'Balanza apta para Verificación Dentro tolerancias NB23001',
    };

    camposMap.forEach((dbKey, modelKey) => addCampo(dbKey, modelKey));
  }

  //MEJORADO: Agregar pruebas metrológicas con null-safety
  void _addPruebasMetrologicasData(Map<String, dynamic> data) {
    // Retorno a Cero y Estabilidad - Inicial
    data['retorno_cero_inicial_valoracion'] =
        model.pruebasIniciales.retornoCero.estado;
    data['estabilizacion_inicial'] =
        model.pruebasIniciales.retornoCero.estabilidad;

    // Retorno a Cero y Estabilidad - Final
    data['retorno_cero_final_valoracion'] =
        model.pruebasFinales.retornoCero.estado;
    data['estabilizacion_final'] = model.pruebasFinales.retornoCero.estabilidad;

    // Excentricidad inicial
    _addExcentricidadData(
        data, model.pruebasIniciales.excentricidad, 'inicial');

    // Repetibilidad inicial
    _addRepetibilidadData(
        data, model.pruebasIniciales.repetibilidad, 'inicial');

    // Linealidad inicial
    _addLinealidadData(data, model.pruebasIniciales.linealidad, 'inicial');

    // Excentricidad final
    _addExcentricidadData(data, model.pruebasFinales.excentricidad, 'final');

    // Repetibilidad final
    _addRepetibilidadData(data, model.pruebasFinales.repetibilidad, 'final');

    // Linealidad final
    _addLinealidadData(data, model.pruebasFinales.linealidad, 'final');
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

        // La base de datos solo soporta hasta 6 etiquetas de posición
        if (num <= 6) {
          data['posicion_${tipo}_$num'] = pos.posicion;
        }

        // La base de datos soporta hasta 12 puntos de indicación y retorno
        if (num <= 12) {
          data['indicacion_${tipo}_$num'] = pos.indicacion;
          data['retorno_${tipo}_$num'] = pos.retorno;
        }
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

  @override
  void agregarFoto(String campo, File foto) {
    super.agregarFoto(campo, foto);
    model.camposEstado[campo]?.agregarFoto(foto);
  }

  @override
  void eliminarFoto(String campo, int index) {
    super.eliminarFoto(campo, index);
    model.camposEstado[campo]?.eliminarFoto(index);
  }

  @override
  void limpiarFotos(String campo) {
    super.limpiarFotos(campo);
    model.camposEstado[campo]?.limpiarFotos();
  }
}
