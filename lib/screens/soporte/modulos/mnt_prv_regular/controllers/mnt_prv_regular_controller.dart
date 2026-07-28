import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:service_met/screens/soporte/controllers/base_soporte_controller.dart';
import 'package:service_met/screens/soporte/models/shared_metrology_models.dart';
import 'package:service_met/screens/soporte/database/database_helper_soporte.dart';
import '../models/mnt_prv_regular_model.dart';

class MntPrvRegularController extends BaseSoporteController<MntPrvRegularModel> {
  Timer? _autoSaveTimer;
  final ValueNotifier<bool> isAutoSaving = ValueNotifier(false);
  final ValueNotifier<bool> lastSaveSuccessful = ValueNotifier(true);

  MntPrvRegularController({required super.model});

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
      final dbHelper = DatabaseHelperSoporte();
      final Map<String, dynamic> data = prepareDataForSave();

      data['session_id'] = model.sessionId;
      data['otst'] = model.secaValue;

      await dbHelper.upsert(tableName, data);
      lastSaveSuccessful.value = true;
    } catch (e) {
      lastSaveSuccessful.value = false;
      debugPrint('Error en auto-guardado (MNT REGULAR): $e');
    } finally {
      isAutoSaving.value = false;
    }
  }

  String get tableName => 'mnt_prv_regular_stil';
  String get tipoServicio => 'MNT.SP';

  void copiarPruebasInicialesAFinales() {
    model.copiarPruebasInicialesAFinales();
  }

  Future<void> loadInitialValues() async {
    try {
      final dbHelper = DatabaseHelperSoporte();
      final result = await dbHelper.getFirst(
        tableName,
        where: 'session_id = ? AND otst = ?',
        whereArgs: [model.sessionId, model.secaValue],
      );

      if (result != null) {
        model.horaFin = result['hora_fin']?.toString() ?? '';
        model.comentarioGeneral = result['comentario_general']?.toString() ?? '';
        model.recomendacion = result['recomendacion']?.toString() ?? '';
        model.estadoFisico = result['estado_fisico']?.toString() ?? '';
        model.estadoOperacional = result['estado_operacional']?.toString() ?? '';
        model.estadoMetrologico = result['estado_metrologico']?.toString() ?? '';
        model.fechaProxServicio = result['fecha_prox_servicio']?.toString() ?? '';

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
            final estado = result['${dbKey}_estado']?.toString();
            final solucion = result['${dbKey}_solucion']?.toString();
            if (estado != null && estado.isNotEmpty) {
              model.camposEstado[modelKey]!.initialValue = estado;
            }
            if (solucion != null && solucion.isNotEmpty) {
              model.camposEstado[modelKey]!.solutionValue = solucion;
            }
          }
        });

        _loadRetornoCero(result, model.pruebasIniciales, 'inicial');
        _loadExcentricidadData(result, model.pruebasIniciales, 'inicial');
        _loadRepetibilidadData(result, model.pruebasIniciales, 'inicial');
        _loadLinealidadData(result, model.pruebasIniciales, 'inicial');

        _loadRetornoCero(result, model.pruebasFinales, 'final');
        _loadExcentricidadData(result, model.pruebasFinales, 'final');
        _loadRepetibilidadData(result, model.pruebasFinales, 'final');
        _loadLinealidadData(result, model.pruebasFinales, 'final');
      }
    } catch (e) {
      debugPrint('Error loading initial values MNT PRV REGULAR: $e');
    }
  }

  void _loadRetornoCero(Map<String, dynamic> registro, PruebasMetrologicas pruebas, String tipo) {
    final estado = registro['retorno_cero_${tipo}_valoracion']?.toString();
    if (estado != null && estado.isNotEmpty) {
      pruebas.retornoCero.estado = estado;
    }
    final estabilidad = registro['retorno_cero_${tipo}_estabilidad']?.toString();
    if (estabilidad != null && estabilidad.isNotEmpty) {
      pruebas.retornoCero.estabilidad = estabilidad;
    }
  }

  void _loadExcentricidadData(Map<String, dynamic> registro, PruebasMetrologicas pruebas, String tipo) {
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
            indicacion: registro['indicacion_${tipo}_${i + 1}']?.toString() ?? '',
            retorno: registro['retorno_${tipo}_${i + 1}']?.toString() ?? '0',
          ));
        }
      }
    }
  }

  void _loadRepetibilidadData(Map<String, dynamic> registro, PruebasMetrologicas pruebas, String tipo) {
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

  void _loadLinealidadData(Map<String, dynamic> registro, PruebasMetrologicas pruebas, String tipo) {
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
            retorno: registro['retorno_lin_${tipo}_${i + 1}']?.toString() ?? '0',
          ));
        }
      }
    }
  }

  Future<void> saveDataToDatabase(BuildContext context, {bool showMessage = false}) async {
    try {
      final dbHelper = DatabaseHelperSoporte();
      final Map<String, dynamic> data = prepareDataForSave();

      data['session_id'] = model.sessionId;
      data['otst'] = model.secaValue;

      await dbHelper.upsert(tableName, data);

      if (showMessage && context.mounted) {
        showSnackBar(context, 'Datos guardados exitosamente', isError: false);
      }
    } catch (e) {
      debugPrint('Error al guardar en BD: $e');
      if (context.mounted) {
        showSnackBar(context, 'Error al guardar los datos: ${e.toString()}', isError: true);
      }
    }
  }

  @override
  Future<void> saveData(BuildContext context) async {
    try {
      await savePhotos(context);
      await saveDataToDatabase(context, showMessage: true);
    } catch (e) {
      if (context.mounted) {
        showSnackBar(context, 'Error al guardar datos: ${e.toString()}', isError: true);
      }
    }
  }

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
      'cod_metrica': model.codMetrica,
      'estado_servicio': _isServiceComplete() ? 'Completo' : 'Pendiente',
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
    addPruebasMetrologicasData(data, model.pruebasIniciales, 'inicial');
    addPruebasMetrologicasData(data, model.pruebasFinales, 'final');

    return data;
  }

  void _addCamposEstadoData(Map<String, dynamic> data) {
    void addCampo(String dbKey, String modelKey) {
      final campo = model.camposEstado[modelKey];
      if (campo != null) {
        data['${dbKey}_estado'] = campo.initialValue;
        data['${dbKey}_solucion'] = campo.solutionValue;
      }
    }

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

    camposMap.forEach((dbKey, modelKey) => addCampo(dbKey, modelKey));
  }

  void addPruebasMetrologicasData(Map<String, dynamic> data, PruebasMetrologicas? pruebas, String tipo) {
    if (pruebas == null) return;

    data['retorno_cero_${tipo}_valoracion'] = pruebas.retornoCero.estado;
    data['retorno_cero_${tipo}_estabilidad'] = pruebas.retornoCero.estabilidad;

    if (pruebas.excentricidad?.activo ?? false) {
      final exc = pruebas.excentricidad!;
      data['tipo_plataforma_$tipo'] = exc.tipoPlataforma ?? '';
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

    if (pruebas.repetibilidad?.activo ?? false) {
      final rep = pruebas.repetibilidad!;
      for (int i = 0; i < rep.cargas.length; i++) {
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

    if (pruebas.linealidad?.activo ?? false) {
      final lin = pruebas.linealidad!;
      for (int i = 0; i < lin.puntos.length; i++) {
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
  @override
  void limpiarFotos(String campo) {
    super.limpiarFotos(campo);
    model.camposEstado[campo]?.limpiarFotos();
  }
}
