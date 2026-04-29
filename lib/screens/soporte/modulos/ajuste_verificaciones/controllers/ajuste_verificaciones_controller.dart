// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:service_met/database/soporte_tecnico/database_helper_ajustes.dart';
import 'package:service_met/screens/soporte/controllers/base_soporte_controller.dart';

import '../models/ajuste_verificaciones_model.dart';

class AjusteVerificacionesController
    extends BaseSoporteController<AjusteVerificacionesModel> {
  Timer? _autoSaveTimer;
  final ValueNotifier<bool> isAutoSaving = ValueNotifier(false);
  final ValueNotifier<bool> lastSaveSuccessful = ValueNotifier(true);

  AjusteVerificacionesController({required super.model});

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
      debugPrint('Error en auto-guardado (AjusteVerif): $e');
    } finally {
      isAutoSaving.value = false;
    }
  }

  void copiarPruebasInicialesAFinales() {
    // 1. Excentricidad
    Excentricidad? excFinal;
    if (model.pruebasIniciales.excentricidad != null) {
      final initialExc = model.pruebasIniciales.excentricidad!;
      excFinal = Excentricidad(
        activo: initialExc.activo,
        tipoPlataforma: initialExc.tipoPlataforma,
        puntosIndicador: initialExc.puntosIndicador,
        imagenPath: initialExc.imagenPath,
        carga: initialExc.carga,
        // Copiar posiciones pero limpiar resultados
        posiciones: initialExc.posiciones
            .map((pos) => PosicionExcentricidad(
                  posicion: pos.posicion,
                  indicacion: '',
                  retorno: '0',
                ))
            .toList(),
      );
    }

    // 2. Repetibilidad
    Repetibilidad? repFinal;
    if (model.pruebasIniciales.repetibilidad != null) {
      final initialRep = model.pruebasIniciales.repetibilidad!;
      repFinal = Repetibilidad(
        activo: initialRep.activo,
        cantidadCargas: initialRep.cantidadCargas,
        cantidadPruebas: initialRep.cantidadPruebas,
        // Copiar cargas pero limpiar pruebas
        cargas: initialRep.cargas
            .map((carga) => CargaRepetibilidad(
                  valor: carga.valor,
                  pruebas: List.generate(
                    initialRep.cantidadPruebas,
                    (_) => PruebaRepetibilidad(indicacion: '', retorno: '0'),
                  ),
                ))
            .toList(),
      );
    }

    // 3. Linealidad
    Linealidad? linFinal;
    if (model.pruebasIniciales.linealidad != null) {
      final initialLin = model.pruebasIniciales.linealidad!;
      linFinal = Linealidad(
        activo: initialLin.activo,
        ultimaCargaLt: initialLin.ultimaCargaLt,
        carga: initialLin.carga,
        incremento: initialLin.incremento,
        iLsubn: initialLin.iLsubn,
        lsubn: initialLin.lsubn,
        io: initialLin.io,
        ltn: initialLin.ltn,
        // Copiar puntos (LT) pero limpiar indicación y retorno
        puntos: initialLin.puntos
            .map((punto) => PuntoLinealidad(
                  lt: punto.lt,
                  indicacion: '',
                  retorno: '0',
                ))
            .toList(),
      );
    }

    model.pruebasFinales = PruebasMetrologicas(
      retornoCero: RetornoCero(), // Reiniciar Retorno Cero
      excentricidad: excFinal,
      repetibilidad: repFinal,
      linealidad: linFinal,
    );
  }

  @override
  Map<String, dynamic> prepareDataForSave() {
    final data = <String, dynamic>{
      'tipo_servicio': 'IBM.BL',
      'estado_servicio': 'Completo',
      'session_id': model.sessionId,
      'cod_metrica': model.codMetrica,
      'otst': model.secaValue,
      'hora_inicio': model.horaInicio,
      'hora_fin': model.horaFin,

      // V2: Inspección Visual / Verificaciones

      // V2: Estado Final
      'comentario_general': model.comentarioGeneral,
      'recomendacion': model.recomendacion,
      'fecha_prox_servicio': model.fechaProxServicio,
      'fisico': model.estadoFisico,
      'operacional': model.estadoOperacional,
      'metrologico': model.estadoMetrologico,
    };

    // Comentarios
    for (int i = 0; i < model.comentarios.length; i++) {
      if (model.comentarios[i] != null && model.comentarios[i]!.isNotEmpty) {
        data['comentario_${i + 1}'] = model.comentarios[i];
      }
    }

    _addPruebasMetrologicasData(data, model.pruebasIniciales, 'inicial');
    _addPruebasMetrologicasData(data, model.pruebasFinales, 'final');

    return data;
  }

  Future<void> saveDataToDatabase(BuildContext context,
      {bool showMessage = true}) async {
    try {
      final dbHelper = DatabaseHelperAjustes();
      final Map<String, dynamic> data = prepareDataForSave();

      await dbHelper.upsertRegistroRelevamiento(data);

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

  @override
  Future<void> saveData(BuildContext context) async {
    try {
      await savePhotos(context);
      await saveDataToDatabase(context, showMessage: true);
    } catch (e) {
      debugPrint('Error al guardar datos: $e');
      if (context.mounted) {
        showSnackBar(context, 'Error al guardar: ${e.toString()}',
            isError: true);
      }
    }
  }

  void _addPruebasMetrologicasData(
      Map<String, dynamic> data, PruebasMetrologicas pruebas, String tipo) {
    // Retorno a Cero
    data['retorno_cero_${tipo}_valoracion'] = pruebas.retornoCero.estado;
    // Mapeo solicitado: Estabilidad se guarda en la columna de carga
    data['estabilizacion_$tipo'] = pruebas.retornoCero.estabilidad;

    // Excentricidad
    _addExcentricidadData(data, pruebas.excentricidad, tipo);

    // Repetibilidad
    _addRepetibilidadData(data, pruebas.repetibilidad, tipo);

    // Linealidad
    _addLinealidadData(data, pruebas.linealidad, tipo);
  }

  void _addExcentricidadData(
      Map<String, dynamic> data, Excentricidad? exc, String tipo) {
    if (exc?.activo ?? false) {
      data['excentricidad_${tipo}_tipo_plataforma'] = exc!.tipoPlataforma ?? '';
      data['excentricidad_${tipo}_carga'] = exc.carga;

      for (int i = 0; i < exc.posiciones.length && i < 6; i++) {
        final pos = exc.posiciones[i];
        final num = i + 1;

        data['excentricidad_${tipo}_pos${num}_numero'] = pos.posicion;
        data['excentricidad_${tipo}_pos${num}_indicacion'] = pos.indicacion;
        data['excentricidad_${tipo}_pos${num}_retorno'] = pos.retorno;
      }
    }
  }

  void _addRepetibilidadData(
      Map<String, dynamic> data, Repetibilidad? rep, String tipo) {
    if (rep?.activo ?? false) {
      // Campos adicionales de conteo
      data['repetibilidad_${tipo}_cantidad_cargas'] =
          rep!.cantidadCargas.toString();
      data['repetibilidad_${tipo}_cantidad_pruebas'] =
          rep.cantidadPruebas.toString();

      for (int i = 0; i < rep.cargas.length; i++) {
        final carga = rep.cargas[i];
        final cNum = i + 1;
        data['repetibilidad_${tipo}_carga${cNum}_valor'] = carga.valor;

        for (int j = 0; j < carga.pruebas.length; j++) {
          final pNum = j + 1;
          data['repetibilidad_${tipo}_carga${cNum}_prueba${pNum}_indicacion'] =
              carga.pruebas[j].indicacion;
          data['repetibilidad_${tipo}_carga${cNum}_prueba${pNum}_retorno'] =
              carga.pruebas[j].retorno;
        }
      }
    }
  }

  void _addLinealidadData(
      Map<String, dynamic> data, Linealidad? lin, String tipo) {
    if (lin?.activo ?? false) {
      data['linealidad_${tipo}_cantidad_puntos'] =
          lin!.puntos.length.toString();

      for (int i = 0; i < lin.puntos.length; i++) {
        final punto = lin.puntos[i];
        final pNum = i + 1;
        data['linealidad_${tipo}_punto${pNum}_lt'] = punto.lt;
        data['linealidad_${tipo}_punto${pNum}_indicacion'] = punto.indicacion;
        data['linealidad_${tipo}_punto${pNum}_retorno'] = punto.retorno;

        try {
          final ind = double.tryParse(punto.indicacion) ?? 0;
          final lt = double.tryParse(punto.lt) ?? 0;
          data['linealidad_${tipo}_punto${pNum}_error'] =
              (ind - lt).toStringAsFixed(2);
        } catch (_) {}
      }
    }
  }
}
