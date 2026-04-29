// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:service_met/screens/soporte/controllers/base_soporte_controller.dart';
import '../../../../../../database/soporte_tecnico/database_helper_relevamiento.dart';
import '../models/relevamiento_de_datos_model.dart';

class RelevamientoDeDatosController extends BaseSoporteController<RelevamientoDeDatosModel> {
  Timer? _autoSaveTimer;
  final ValueNotifier<bool> isAutoSaving = ValueNotifier(false);
  final ValueNotifier<bool> lastSaveSuccessful = ValueNotifier(true);

  RelevamientoDeDatosController({required super.model});

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
      final dbHelper = DatabaseHelperRelevamiento();
      final Map<String, dynamic> relevamientoData = prepareDataForSave();

      relevamientoData['session_id'] = model.sessionId;
      relevamientoData['otst'] = model.secaValue;

      await dbHelper.upsertRegistroRelevamiento(relevamientoData);
      lastSaveSuccessful.value = true;
    } catch (e) {
      lastSaveSuccessful.value = false;
      debugPrint('Error en auto-guardado (Relevamiento): $e');
    } finally {
      isAutoSaving.value = false;
    }
  }

  Future<void> loadInitialValues() async {
    try {
      final dbHelper = DatabaseHelperRelevamiento();
      final db = await dbHelper.database;
      final results = await db.query(
        'relevamiento_de_datos',
        where: 'session_id = ? AND otst = ?',
        whereArgs: [model.sessionId, model.secaValue],
        limit: 1,
      );

      if (results.isNotEmpty) {
        final registro = results.first;

        model.horaFin = registro['hora_fin']?.toString() ?? '';
        model.comentarioGeneral = registro['comentario_general']?.toString() ?? '';
        model.recomendacion = registro['recomendaciones']?.toString() ?? ''; // En Relevamiento es 'recomendaciones'
        
        // Mapear campos de ESTADO
        final camposMap = {
          'carcasa': 'Carcasa',
          'conector_cables': 'Conector y Cables',
          'alimentacion': 'Alimentación',
          'pantalla': 'Pantalla',
          'teclado': 'Teclado',
          'bracket_columna': 'Bracket y columna',
          'plato_carga': 'Plato de Carga',
          'estructura': 'Estructura',
          'topes_carga': 'Topes de Carga',
          'patas': 'Patas',
          'limpieza': 'Limpieza',
          'bordes_puntas': 'Bordes y puntas',
          'celulas': 'Célula(s)',
          'cables': 'Cable(s)',
          'cubierta_silicona': 'Cubierta de Silicona',
          'entorno': 'Entorno',
          'nivelacion': 'Nivelación',
          'movilizacion': 'Movilización',
          'flujo_pesas': 'Flujo de Pesadas',
        };

        camposMap.forEach((dbKey, modelKey) {
          if (model.camposEstado.containsKey(modelKey)) {
            final estado = registro[dbKey]?.toString();
            final comentario = registro['${dbKey}_comentario']?.toString();
            if (estado != null && estado.isNotEmpty) {
              model.camposEstado[modelKey]!.initialValue = estado;
            }
            if (comentario != null && comentario.isNotEmpty) {
              model.camposEstado[modelKey]!.comentario = comentario;
            }
          }
        });

        // Pruebas Finales (ya que relevamiento no tiene iniciales)
        final retCeroEdo = registro['retorno_cero']?.toString();
        if (retCeroEdo != null && retCeroEdo.isNotEmpty) {
           model.pruebasFinales.retornoCero.estado = retCeroEdo;
        }

        final estCeroEdo = registro['carga_retorno_cero']?.toString();
        if (estCeroEdo != null && estCeroEdo.isNotEmpty) {
           model.pruebasFinales.retornoCero.estabilidad = estCeroEdo;
        }

        model.pruebasFinales.pMaxBruto = registro['p_max_bruto']?.toString() ?? '';
        model.pruebasFinales.pMinNeto = registro['p_min_neto']?.toString() ?? '';

        _loadExcentricidadData(registro, model.pruebasFinales);
        _loadRepetibilidadData(registro, model.pruebasFinales);
        _loadLinealidadData(registro, model.pruebasFinales);
      }
    } catch (e) {
      debugPrint('Error al cargar initial values en Relevamiento: $e');
    }
  }

  void _loadExcentricidadData(Map<String, dynamic> registro, PruebasMetrologicas pruebas) {
    final tipoPlataforma = registro['tipo_plataforma']?.toString();
    if (tipoPlataforma != null && tipoPlataforma.isNotEmpty) {
      pruebas.excentricidad ??= Excentricidad();
      final exc = pruebas.excentricidad!;
      exc.activo = true;
      exc.tipoPlataforma = tipoPlataforma;
      exc.puntosIndicador = registro['puntos_ind']?.toString() ?? '';
      exc.carga = registro['carga']?.toString() ?? '';

      exc.posiciones.clear();
      for (int i = 0; i < 6; i++) {
        final posVal = registro['posicion${i + 1}']?.toString();
        if (posVal != null && posVal.isNotEmpty) {
          exc.posiciones.add(PosicionExcentricidad(
            posicion: posVal,
            indicacion: registro['indicacion${i + 1}']?.toString() ?? '',
            retorno: registro['retorno${i + 1}']?.toString() ?? '0',
          ));
        }
      }
    }
  }

  void _loadRepetibilidadData(Map<String, dynamic> registro, PruebasMetrologicas pruebas) {
    final carga1Str = registro['repetibilidad1']?.toString();
    if (carga1Str != null && carga1Str.isNotEmpty) {
      pruebas.repetibilidad ??= Repetibilidad();
      final rep = pruebas.repetibilidad!;
      rep.activo = true;
      
      rep.cargas.clear();
      final carga1 = CargaRepetibilidad(valor: carga1Str);
      carga1.pruebas.clear();

      for (int j = 0; j < 10; j++) {
        final ind = registro['indicacion1_${j + 1}']?.toString();
        if (ind != null && ind.isNotEmpty) {
          carga1.pruebas.add(PruebaRepetibilidad(
            indicacion: ind,
            retorno: registro['retorno1_${j + 1}']?.toString() ?? '0',
          ));
        }
      }

      if (carga1.pruebas.isNotEmpty) {
        rep.cargas.add(carga1);
        rep.cantidadPruebas = carga1.pruebas.length;
      }
    }
  }

  void _loadLinealidadData(Map<String, dynamic> registro, PruebasMetrologicas pruebas) {
    final lin1Str = registro['lin1']?.toString();
    if (lin1Str != null && lin1Str.isNotEmpty) {
      pruebas.linealidad ??= Linealidad();
      final lin = pruebas.linealidad!;
      lin.activo = true;
      lin.puntos.clear();

      for (int i = 0; i < 12; i++) {
        final ptVal = registro['lin${i + 1}']?.toString();
        if (ptVal != null && ptVal.isNotEmpty) {
          lin.puntos.add(PuntoLinealidad(
            lt: ptVal,
            indicacion: registro['ind${i + 1}']?.toString() ?? '',
            retorno: registro['retorno_lin${i + 1}']?.toString() ?? '0',
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

      final dbHelper = DatabaseHelperRelevamiento();
      final Map<String, dynamic> relevamientoData = prepareDataForSave();

      relevamientoData['session_id'] = model.sessionId;
      relevamientoData['otst'] = model.secaValue;

      await dbHelper.upsertRegistroRelevamiento(relevamientoData);

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
        model.horaFin.isNotEmpty;
  }

  @override
  Map<String, dynamic> prepareDataForSave() {
    final data = <String, dynamic>{
      'estado_servicio': _isServiceComplete() ? 'Completo' : 'Pendiente',
      'session_id': model.sessionId,
      'cod_metrica': model.codMetrica,
      'otst': model.secaValue,
      'tipo_servicio': 'REL.BL',
      'hora_inicio': model.horaInicio,
      'hora_fin': model.horaFin,
      'comentario_general': model.comentarioGeneral,
      'recomendaciones': model.recomendacion,
    };

    _addCamposEstadoData(data);
    _addPruebasMetrologicasData(data);

    return data;
  }

  // ✅ REFACTORIZADO: Agregar datos de campos de estado
  void _addCamposEstadoData(Map<String, dynamic> data) {
    // Función auxiliar simplificada
    void addCampo(String dbKey, String modelKey) {
      final campo = model.camposEstado[modelKey];
      if (campo != null) {
        data[dbKey] = campo.initialValue;
        data['${dbKey}_comentario'] = campo.comentario;
        data['${dbKey}_foto'] = campo.fotos.isNotEmpty
            ? campo.fotos.map((f) => f.path.split('/').last).join(',')
            : '';
      }
    }

    // Mapeo de campos (DB key -> Model key)
    final camposMap = {
      // Terminal
      'carcasa': 'Carcasa',
      'conector_cables': 'Conector y Cables',
      'alimentacion': 'Alimentación',
      'pantalla': 'Pantalla',
      'teclado': 'Teclado',
      'bracket_columna': 'Bracket y columna',

      // Plataforma
      'plato_carga': 'Plato de Carga',
      'estructura': 'Estructura',
      'topes_carga': 'Topes de Carga',
      'patas': 'Patas',
      'limpieza': 'Limpieza',
      'bordes_puntas': 'Bordes y puntas',

      // Celdas de carga
      'celulas': 'Célula(s)',
      'cables': 'Cable(s)',
      'cubierta_silicona': 'Cubierta de Silicona',

      // Entorno (campos de selección)
      'entorno': 'Entorno',
      'nivelacion': 'Nivelación',
      'movilizacion': 'Movilización',
      'flujo_pesas': 'Flujo de Pesadas',
    };

    camposMap.forEach((dbKey, modelKey) => addCampo(dbKey, modelKey));
  }

  // ✅ MEJORADO: Agregar pruebas metrológicas FINALES únicamente
  void _addPruebasMetrologicasData(Map<String, dynamic> data) {
    // Retorno a Cero y Estabilidad - SOLO FINAL (sin sufijo "_final" en BD)
    data['retorno_cero'] = model.pruebasFinales.retornoCero.estado;
    data['carga_retorno_cero'] = model.pruebasFinales.retornoCero.estabilidad;
    data['p_max_bruto'] = model.pruebasFinales.pMaxBruto;
    data['p_min_neto'] = model.pruebasFinales.pMinNeto;

    // Excentricidad final (NO usa sufijo en BD, solo números)
    _addExcentricidadData(data, model.pruebasFinales.excentricidad);

    // Repetibilidad final (NO usa sufijo en BD, solo números)
    _addRepetibilidadData(data, model.pruebasFinales.repetibilidad);

    // Linealidad final (NO usa sufijo en BD)
    _addLinealidadData(data, model.pruebasFinales.linealidad);
  }

  void _addExcentricidadData(Map<String, dynamic> data, Excentricidad? exc) {
    if (exc?.activo ?? false) {
      // BD usa: tipo_plataforma, puntos_ind, carga (sin sufijo)
      data['tipo_plataforma'] = exc!.tipoPlataforma ?? '';
      data['puntos_ind'] = exc.puntosIndicador ?? '';
      data['carga'] = exc.carga;

      // BD usa: posicion1, indicacion1, retorno1, etc. (sin sufijo)
      for (int i = 0; i < exc.posiciones.length; i++) {
        final pos = exc.posiciones[i];
        final num = i + 1;
        data['posicion$num'] = pos.posicion;
        data['indicacion$num'] = pos.indicacion;
        data['retorno$num'] = pos.retorno;
      }
    }
  }

  void _addRepetibilidadData(Map<String, dynamic> data, Repetibilidad? rep) {
    if (rep?.activo ?? false) {
      for (int i = 0; i < rep!.cargas.length; i++) {
        final carga = rep.cargas[i];
        final cargaNum = i + 1;
        // BD usa: repetibilidad1, repetibilidad2, repetibilidad3 (sin sufijo)
        data['repetibilidad$cargaNum'] = carga.valor;

        for (int j = 0; j < carga.pruebas.length; j++) {
          final prueba = carga.pruebas[j];
          final testNum = j + 1;
          // BD usa: indicacion1_1, retorno1_1, etc. (sin sufijo)
          data['indicacion${cargaNum}_$testNum'] = prueba.indicacion;
          data['retorno${cargaNum}_$testNum'] = prueba.retorno;
        }
      }
    }
  }

  void _addLinealidadData(Map<String, dynamic> data, Linealidad? lin) {
    if (lin?.activo ?? false) {
      for (int i = 0; i < lin!.puntos.length; i++) {
        final punto = lin.puntos[i];
        final num = i + 1;
        // BD usa: lin1, ind1, retorno_lin1 (sin sufijo)
        data['lin$num'] = punto.lt;
        data['ind$num'] = punto.indicacion;
        data['retorno_lin$num'] = punto.retorno;
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
