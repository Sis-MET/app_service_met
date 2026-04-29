// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:service_met/screens/soporte/controllers/base_soporte_controller.dart';
import '../../../../../../database/soporte_tecnico/database_helper_verificaciones.dart';
import '../models/verificaciones_internas_model.dart';

class VerificacionesInternasController
    extends BaseSoporteController<VerificacionesInternasModel> {
  Timer? _autoSaveTimer;
  final ValueNotifier<bool> isAutoSaving = ValueNotifier(false);
  final ValueNotifier<bool> lastSaveSuccessful = ValueNotifier(true);

  VerificacionesInternasController({required super.model});

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
      await saveDataToDatabase(context, showMessage: false);
      lastSaveSuccessful.value = true;
    } catch (e) {
      lastSaveSuccessful.value = false;
      debugPrint('Error en auto-guardado (Verific Internas): $e');
    } finally {
      isAutoSaving.value = false;
    }
  }

  Future<void> saveDataToDatabase(BuildContext context,
      {bool showMessage = true}) async {
    try {
      final dbHelper = DatabaseHelperVerificaciones();
      final Map<String, dynamic> dbData = prepareDataForSave();

      dbData['session_id'] = model.sessionId;
      dbData['otst'] = model.secaValue;
      dbData['cod_metrica'] = model.codMetrica;

      await dbHelper.upsertRegistroRelevamiento(dbData);

      if (showMessage && context.mounted) {
        showSnackBar(context, 'Datos guardados exitosamente', isError: false);
      }
    } catch (e) {
      debugPrint('Error al guardar en BD: $e');
      if (showMessage && context.mounted) {
        showSnackBar(context, 'Error al guardar: ${e.toString()}',
            isError: true);
      }
      rethrow;
    }
  }

  Future<void> loadInitialValues() async {
    try {
      final dbHelper = DatabaseHelperVerificaciones();
      final db = await dbHelper.database;
      final results = await db.query(
        'verificaciones_internas',
        where: 'session_id = ? AND otst = ?',
        whereArgs: [model.sessionId, model.secaValue],
        limit: 1,
      );

      if (results.isNotEmpty) {
        final registro = results.first;

        model.horaFin = registro['hora_fin']?.toString() ?? '';
        model.comentarioGeneral =
            registro['comentario_general']?.toString() ?? '';
        model.recomendacion = registro['recomendacion']?.toString() ?? '';
        model.estadoFisico = registro['fisico']?.toString() ?? '';
        model.estadoOperacional = registro['operacional']?.toString() ?? '';
        model.estadoMetrologico = registro['metrologico']?.toString() ?? '';
        model.fechaProxServicio =
            registro['fecha_prox_servicio']?.toString() ?? '';

        // Mapear campos de ESTADO
        final camposMap = {
          'espaciamiento_topes_long': 'Espaciamiento topes longitudinales',
          'espaciamiento_topes_front': 'Espaciamiento topes frontales',
          'limpieza_puente': 'Limpieza del puente de pesaje',
          'limpieza_debajo_puente': 'Limpieza debajo del puente',
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
        final retCeroIniEst =
            registro['retorno_cero_inicial_valoracion']?.toString();
        if (retCeroIniEst != null && retCeroIniEst.isNotEmpty) {
          model.pruebasIniciales.retornoCero.estado = retCeroIniEst;
        }

        _loadExcentricidadData(registro, model.pruebasIniciales, 'inicial');
        _loadRepetibilidadData(registro, model.pruebasIniciales, 'inicial');
        _loadLinealidadData(registro, model.pruebasIniciales, 'inicial');
      }
    } catch (e) {
      debugPrint(
          'Error al cargar initial values en Verificaciones Internas: $e');
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
      // Si "carga_exc_inicial" no existiese usa fallback `carga` pero su map guarda en carga_exc_$tipo
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

  void copiarPruebasInicialesAFinales() {
    model.copiarPruebasInicialesAFinales();
  }

  @override
  Future<void> saveData(BuildContext context) async {
    try {
      await savePhotos(context);

      final dbHelper = DatabaseHelperVerificaciones();
      final Map<String, dynamic> dbData = prepareDataForSave();

      // IDs clave
      dbData['session_id'] = model.sessionId;
      dbData['otst'] = model.secaValue;
      dbData['cod_metrica'] = model.codMetrica;

      await dbHelper.upsertRegistroRelevamiento(dbData);

      if (context.mounted) {
        showSnackBar(context, 'Datos guardados exitosamente', isError: false);
      }
    } catch (e) {
      debugPrint('Error al guardar en BD: $e');
      if (context.mounted) {
        showSnackBar(context, 'Error al guardar datos: ${e.toString()}',
            isError: true);
      }
    }
  }

  bool _isServiceComplete() {
    return model.estadoFisico.isNotEmpty &&
        model.estadoOperacional.isNotEmpty &&
        model.estadoMetrologico.isNotEmpty &&
        model.fechaProxServicio.isNotEmpty &&
        model.horaFin.isNotEmpty;
  }

  @override
  Map<String, dynamic> prepareDataForSave() {
    final data = <String, dynamic>{
      'estado_servicio': _isServiceComplete() ? 'Completo' : 'Pendiente',
      'tipo_servicio': 'VIN.SP',
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

  // Agregar datos de campos de estado
  void _addCamposEstadoData(Map<String, dynamic> data) {
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

    final camposMap = {
      // Inspección Visual (NUEVOS CAMPOS SIMPLIFICADOS)
      'espaciamiento_topes_long': 'Espaciamiento topes longitudinales',
      'espaciamiento_topes_front': 'Espaciamiento topes frontales',
      'limpieza_puente': 'Limpieza del puente de pesaje',
      'limpieza_debajo_puente': 'Limpieza debajo del puente',
    };

    camposMap.forEach((dbKey, modelKey) => addCampo(dbKey, modelKey));
  }

  void _addPruebasMetrologicasData(Map<String, dynamic> data) {
    // Retorno a Cero Inicial
    data['retorno_cero_inicial_valoracion'] =
        model.pruebasIniciales.retornoCero.estado;
    data['estabilizacion_inicial'] =
        model.pruebasIniciales.retornoCero.estabilidad;

    // Pruebas Iniciales
    _addExcentricidadData(
        data, model.pruebasIniciales.excentricidad, 'inicial');
    _addRepetibilidadData(
        data, model.pruebasIniciales.repetibilidad, 'inicial');
    _addLinealidadData(data, model.pruebasIniciales.linealidad, 'inicial');
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
