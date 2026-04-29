// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../../database/soporte_tecnico/database_helper_diagnostico_correctivo.dart';
import 'package:intl/intl.dart';
import '../models/diagnostico_model.dart';
import 'package:service_met/screens/soporte/controllers/base_soporte_controller.dart';

class DiagnosticoController extends BaseSoporteController<DiagnosticoModel> {
  Timer? _autoSaveTimer;
  final ValueNotifier<bool> isAutoSaving = ValueNotifier(false);
  final ValueNotifier<bool> lastSaveSuccessful = ValueNotifier(true);

  DiagnosticoController({required super.model});

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
      debugPrint('Auto-guardado Diagnóstico OK');
    } catch (e) {
      lastSaveSuccessful.value = false;
      debugPrint('Error en auto-guardado (Diagnóstico): $e');
    } finally {
      isAutoSaving.value = false;
    }
  }

  Future<void> saveDataToDatabase(BuildContext context,
      {bool showMessage = true}) async {
    try {
      final DatabaseHelperDiagnosticoCorrectivo dbHelper =
          DatabaseHelperDiagnosticoCorrectivo();
      final data = prepareDataForSave();
      await dbHelper.upsertRegistroDiagnostico(data);

      if (showMessage && context.mounted) {
        showSnackBar(context, 'Datos guardados exitosamente', isError: false);
      }
    } catch (e) {
      debugPrint('❌ Error saveDataToDatabase (Diagnóstico): $e');
      if (showMessage && context.mounted) {
        showSnackBar(context, 'Error al guardar: $e', isError: true);
      }
      rethrow;
    }
  }

  /// Inicializa datos necesarios
  Future<void> init() async {
    // Cargar hora inicio si está vacía
    if (model.horaInicio.isEmpty) {
      // La hora se setea en el modelo o en la vista al iniciar
    }
  }

  // --- GUARDADO A BASE DE DATOS ---

  @override
  Map<String, dynamic> prepareDataForSave() {
    final Map<String, dynamic> data = {
      'tipo_servicio': 'DIG.BL',
      'session_id': model.sessionId,
      'cod_metrica': model.codMetrica,
      'otst': model.secaValue,
      'fecha_servicio':
          DateFormat('yyyy-MM-dd').format(DateTime.now()), // Para ordenamiento
      'hora_inicio': model.horaInicio,
      'hora_fin': model.horaFin,
      'reporte': model.reporteFalla,
      'evaluacion': model.evaluacion,
      'comentario_general': model.comentarioGeneral,
    };
    return data;
  }

  @override
  Future<void> saveData(BuildContext context) async {
    try {
      // 1. Guardar Fotos
      await savePhotos(context);

      // 2. Guardar Datos BD
      final DatabaseHelperDiagnosticoCorrectivo dbHelper =
          DatabaseHelperDiagnosticoCorrectivo();
      final data = prepareDataForSave();

      await dbHelper.upsertRegistroDiagnostico(data);

      if (context.mounted) {
        showSnackBar(context, 'Datos guardados exitosamente', isError: false);
      }
    } catch (e) {
      debugPrint('Error SAVE DATA: $e');
      if (context.mounted) {
        showSnackBar(context, 'Error al guardar: $e', isError: true);
      }
    }
  }
}
