// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:service_met/screens/soporte/controllers/base_soporte_controller.dart';
import '../../../../../../database/soporte_tecnico/database_helper_mnt_prv_regular_stil.dart';
import '../models/mnt_prv_regular_stil_model.dart';

class MntPrvRegularStilController extends BaseSoporteController<MntPrvRegularStilModel> {
  Timer? _autoSaveTimer;
  final ValueNotifier<bool> isAutoSaving = ValueNotifier(false);
  final ValueNotifier<bool> lastSaveSuccessful = ValueNotifier(true);

  MntPrvRegularStilController({required super.model});

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
      final dbHelper = DatabaseHelperMntPrvRegularStil();
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

  Future<void> loadInitialValues() async {
    try {
      final dbHelper = DatabaseHelperMntPrvRegularStil();
      final registro =
          await dbHelper.getRegistroBySeca(model.secaValue, model.sessionId);

      if (registro != null) {
        model.comentarioGeneral =
            registro['comentario_general']?.toString() ?? '';
        model.recomendacion = registro['recomendacion']?.toString() ?? '';
        model.estadoFisico = registro['estado_fisico']?.toString() ?? '';
        model.estadoOperacional =
            registro['estado_operacional']?.toString() ?? '';
        model.estadoMetrologico =
            registro['estado_metrologico']?.toString() ?? '';

        final hInicio = registro['hora_inicio']?.toString();
        if (hInicio != null && hInicio.isNotEmpty) model.horaInicio = hInicio;

        final hFin = registro['hora_fin']?.toString();
        if (hFin != null && hFin.isNotEmpty) model.horaFin = hFin;

        final proxServ = registro['fecha_prox_servicio']?.toString();
        if (proxServ != null && proxServ.isNotEmpty) {
          model.fechaProxServicio = proxServ;
        }

        // Campos Estado
        final camposMap = {
          'vibracion': 'Vibración',
          'polvo': 'Polvo',
          'temperatura': 'Temperatura',
          'humedad': 'Humedad',
          'mesada': 'Mesada',
          'iluminacion': 'Iluminación',
          'limpieza_fosa': 'Limpieza de Fosa',
          'estado_drenaje': 'Estado de Drenaje',
          'carcasa': 'Carcasa',
          'teclado_fisico': 'Teclado Fisico',
          'display_fisico': 'Display Fisico',
          'fuente_poder': 'Fuente de poder',
          'bateria_operacional': 'Bateria operacional',
          'bracket': 'Bracket',
          'teclado_operativo': 'Teclado Operativo',
          'display_operativo': 'Display Operativo',
          'conector_celda': 'Contector de celda',
          'bateria_memoria': 'Bateria de memoria',
          'limpieza_general': 'Limpieza general',
          'golpes_terminal': 'Golpes al terminal',
          'nivelacion': 'Nivelacion',
          'limpieza_receptor': 'Limpieza receptor',
          'golpes_receptor': 'Golpes al receptor de carga',
          'encendido': 'Encendido',
          'limitador_movimiento': 'Limitador de movimiento',
          'suspension': 'Suspensión',
          'limitador_carga': 'Limitador de carga',
          'celda_carga': 'Celda de carga',
          'tapa_caja': 'Tapa de caja sumadora',
          'humedad_interna': 'Humedad Interna',
          'estado_prensacables': 'Estado de prensacables',
          'estado_borneas': 'Estado de borneas',
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
      debugPrint('Error al cargar initial values en MNT STIL: $e');
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

  void copiarPruebasInicialesAFinales() {
    model.copiarPruebasInicialesAFinales();
  }


  @override
  Future<void> saveData(BuildContext context) async {
    try {
      // Primero guardar fotos si existen
      await savePhotos(context);

      final dbHelper = DatabaseHelperMntPrvRegularStil();
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
      'tipo_servicio': 'MPR.BL',
      'hora_inicio': model.horaInicio,
      'hora_fin': model.horaFin,
      'comentario_general': model.comentarioGeneral,
      'recomendacion': model.recomendacion,
      'estado_fisico': model.estadoFisico,
      'estado_operacional': model.estadoOperacional,
      'estado_metrologico': model.estadoMetrologico,
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

    // Mapeo de campos (DB key -> Model key)
    final camposMap = {
      // Entorno
      'vibracion': 'Vibración',
      'polvo': 'Polvo',
      'temperatura': 'Temperatura',
      'humedad': 'Humedad',
      'mesada': 'Mesada',
      'iluminacion': 'Iluminación',
      'limpieza_fosa': 'Limpieza de Fosa',
      'estado_drenaje': 'Estado de Drenaje',

      // Terminal
      'carcasa': 'Carcasa',
      'teclado_fisico': 'Teclado Fisico',
      'display_fisico': 'Display Fisico',
      'fuente_poder': 'Fuente de poder',
      'bateria_operacional': 'Bateria operacional',
      'bracket': 'Bracket',
      'teclado_operativo': 'Teclado Operativo',
      'display_operativo': 'Display Operativo',
      'conector_celda': 'Contector de celda',
      'bateria_memoria': 'Bateria de memoria',

      // Balanza
      'limpieza_general': 'Limpieza general',
      'golpes_terminal': 'Golpes al terminal',
      'nivelacion': 'Nivelacion',
      'limpieza_receptor': 'Limpieza receptor',
      'golpes_receptor': 'Golpes al receptor de carga',
      'encendido': 'Encendido',

      // Plataforma
      'limitador_movimiento': 'Limitador de movimiento',
      'suspension': 'Suspensión',
      'limitador_carga': 'Limitador de carga',
      'celda_carga': 'Celda de carga',

      // Caja sumadora
      'tapa_caja': 'Tapa de caja sumadora',
      'humedad_interna': 'Humedad Interna',
      'estado_prensacables': 'Estado de prensacables',
      'estado_borneas': 'Estado de borneas',
      'pintado': 'Pintado',
      'limpieza_profunda': 'Limpieza profunda',
    };

    camposMap.forEach((dbKey, modelKey) => addCampo(dbKey, modelKey));
  }

  // MEJORADO: Agregar pruebas metrológicas con null-safety
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
        data['posicion_${tipo}_$num'] = pos.posicion;
        data['indicacion_${tipo}_$num'] = pos.indicacion;
        data['retorno_${tipo}_$num'] = pos.retorno;
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
