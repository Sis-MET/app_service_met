import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:service_met/screens/soporte_new/database/database_helper_soporte.dart';
import 'package:service_met/screens/soporte_new/models/base_soporte_model.dart';
import 'package:service_met/screens/soporte_new/models/campo_estado.dart';
import 'package:service_met/screens/soporte_new/models/shared_metrology_models.dart';

abstract class BaseSoporteController extends ChangeNotifier {
  String get tableName;
  String get tipoServicio;
  BaseSoporteModel get model;

  final DatabaseHelperSoporte dbHelper = DatabaseHelperSoporte();

  final bool _isLoading = false;
  bool get isLoading => _isLoading;
  bool _isGuardando = false;
  bool get isGuardando => _isGuardando;

  int currentStep = 0;
  int totalSteps = 1;

  final List<CampoEstado> camposEstado = [];
  PruebasMetrologicas pruebasIniciales = PruebasMetrologicas();
  PruebasMetrologicas pruebasFinales = PruebasMetrologicas();

  String comentarioGeneral = '';
  String recomendacion = '';
  String estadoFisico = '';
  String estadoOperacional = '';
  String estadoMetrologico = '';
  String horaInicio = '';
  String horaFin = '';
  String fechaProxServicio = '';
  String secaValue = '';
  String clienteNombre = '';
  String plantaNombre = '';

  Timer? _autoSaveTimer;
  final ValueNotifier<bool> hasUnsavedChanges = ValueNotifier<bool>(false);

  bool _isSaving = false;
  bool get isSaving => _isSaving;

  bool _lastSaveSuccessful = true;
  bool get lastSaveSuccessful => _lastSaveSuccessful;

  BaseSoporteController();

  void markChanged() {
    hasUnsavedChanges.value = true;
    _autoSaveTimer?.cancel();
    _autoSaveTimer =
        Timer(const Duration(milliseconds: 1500), () => autoSave());
  }

  Future<void> autoSave() async {
    if (!hasUnsavedChanges.value) return;
    await guardarSesion();
    hasUnsavedChanges.value = false;
  }

  Future<void> loadExistingSession(String sessionId, Map<String, dynamic> data) async {
    comentarioGeneral = data['comentario_general']?.toString() ?? '';
    recomendacion = data['recomendacion']?.toString() ?? '';
    estadoFisico = data['estado_fisico']?.toString() ?? '';
    estadoOperacional = data['estado_operacional']?.toString() ?? '';
    estadoMetrologico = data['estado_metrologico']?.toString() ?? '';
    horaInicio = data['hora_inicio']?.toString() ?? '';
    horaFin = data['hora_fin']?.toString() ?? '';
    fechaProxServicio = data['fecha_prox_servicio']?.toString() ?? '';

    if (data['pruebas_iniciales'] != null) {
      try {
        final pi = jsonDecode(data['pruebas_iniciales']);
        pruebasIniciales = PruebasMetrologicas(
          excentricidad: (pi['excentricidad'] as List).map((e) => Excentricidad(
            posicion: e['posicion'] ?? '', carga: e['carga'] ?? '',
            indicacion1: e['indicacion1'] ?? '', indicacion2: e['indicacion2'] ?? '',
            indicacion3: e['indicacion3'] ?? '', diferencia: e['diferencia'] ?? '',
            error: e['error'] ?? '', errorMaximo: e['errorMaximo'] ?? '',
          )).toList(),
          repetibilidad: (pi['repetibilidad'] as List).map((r) => Repetibilidad(
            carga: r['carga'] ?? '', indicacion1: r['indicacion1'] ?? '',
            indicacion2: r['indicacion2'] ?? '', indicacion3: r['indicacion3'] ?? '',
            diferencia: r['diferencia'] ?? '', errorMaximo: r['errorMaximo'] ?? '',
          )).toList(),
          linealidad: (pi['linealidad'] as List).map((l) => Linealidad(
            carga: l['carga'] ?? '', indicacion1: l['indicacion1'] ?? '',
            indicacion2: l['indicacion2'] ?? '', error: l['error'] ?? '',
            errorMaximo: l['errorMaximo'] ?? '', incertidumbre: l['incertidumbre'] ?? '',
          )).toList(),
        );
      } catch (_) {}
    }
    if (data['pruebas_finales'] != null) {
      try {
        final pf = jsonDecode(data['pruebas_finales']);
        pruebasFinales = PruebasMetrologicas(
          excentricidad: (pf['excentricidad'] as List).map((e) => Excentricidad(
            posicion: e['posicion'] ?? '', carga: e['carga'] ?? '',
            indicacion1: e['indicacion1'] ?? '', indicacion2: e['indicacion2'] ?? '',
            indicacion3: e['indicacion3'] ?? '', diferencia: e['diferencia'] ?? '',
            error: e['error'] ?? '', errorMaximo: e['errorMaximo'] ?? '',
          )).toList(),
          repetibilidad: (pf['repetibilidad'] as List).map((r) => Repetibilidad(
            carga: r['carga'] ?? '', indicacion1: r['indicacion1'] ?? '',
            indicacion2: r['indicacion2'] ?? '', indicacion3: r['indicacion3'] ?? '',
            diferencia: r['diferencia'] ?? '', errorMaximo: r['errorMaximo'] ?? '',
          )).toList(),
          linealidad: (pf['linealidad'] as List).map((l) => Linealidad(
            carga: l['carga'] ?? '', indicacion1: l['indicacion1'] ?? '',
            indicacion2: l['indicacion2'] ?? '', error: l['error'] ?? '',
            errorMaximo: l['errorMaximo'] ?? '', incertidumbre: l['incertidumbre'] ?? '',
          )).toList(),
        );
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<Map<String, dynamic>> buildDataMap() async {
    return {
      'seca_value': secaValue,
      'cod_metrica': model.codMetrica,
      'cliente': clienteNombre,
      'planta': plantaNombre,
      'comentario_general': comentarioGeneral,
      'recomendacion': recomendacion,
      'estado_fisico': estadoFisico,
      'estado_operacional': estadoOperacional,
      'estado_metrologico': estadoMetrologico,
      'hora_inicio': horaInicio,
      'hora_fin': horaFin,
      'fecha_prox_servicio': fechaProxServicio,
      'pruebas_iniciales': jsonEncode(pruebasIniciales.toMap()),
      'pruebas_finales': jsonEncode(pruebasFinales.toMap()),
    };
  }

  Future<void> guardarSesion() async {
    _isGuardando = true;
    _isSaving = true;
    notifyListeners();
    try {
      final data = await buildDataMap();
      await dbHelper.upsert(
        tableName,
        model.sessionId,
        data,
        otst: secaValue,
        codMetrica: model.codMetrica,
      );
      _lastSaveSuccessful = true;
    } catch (e) {
      _lastSaveSuccessful = false;
      debugPrint('Error guardando sesion $tableName: $e');
    } finally {
      _isGuardando = false;
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<void> finalizarServicio({
    required String horaFin,
    required String fechaProxServicio,
  }) async {
    this.horaFin = horaFin;
    this.fechaProxServicio = fechaProxServicio;
    await guardarSesion();
    await dbHelper.marcarServicioCompleto(tableName, model.sessionId);
  }

  /// Permite que FinServicioScreen consulte registros sin depender
  /// directamente de DatabaseHelperSoporte. Cada módulo puede overridear
  /// para apuntar a su propia base de datos.
  Future<List<Map<String, dynamic>>> getRegistrosPorSeca(
    String tableName,
    String seca, {
    bool soloHoy = false,
  }) async {
    return dbHelper.getRegistrosPorSeca(tableName, seca, soloHoy: soloHoy);
  }

  Future<void> exportToCsv(String outputPath) async {
    final data = await buildDataMap();
    final buffer = StringBuffer();
    buffer.writeln('Campo;Valor');
    data.forEach((key, value) {
      final str = value is String ? value : jsonEncode(value);
      buffer.writeln('$key;$str');
    });
    final file = File(outputPath);
    await file.writeAsString(buffer.toString());
  }

  Future<void> exportPhotosZip(String outputPath) async {
    // Placeholder - implementar con archive package si es necesario
  }

  void addExcentricidadData(PruebasMetrologicas pruebas, int index, String field, String value) {
    if (index < 0 || index >= pruebas.excentricidad.length) return;
    switch (field) {
      case 'posicion': pruebas.excentricidad[index].posicion = value; break;
      case 'carga': pruebas.excentricidad[index].carga = value; break;
      case 'indicacion1': pruebas.excentricidad[index].indicacion1 = value; break;
      case 'indicacion2': pruebas.excentricidad[index].indicacion2 = value; break;
      case 'indicacion3': pruebas.excentricidad[index].indicacion3 = value; break;
      case 'diferencia': pruebas.excentricidad[index].diferencia = value; break;
      case 'error': pruebas.excentricidad[index].error = value; break;
      case 'errorMaximo': pruebas.excentricidad[index].errorMaximo = value; break;
    }
    markChanged();
  }

  void addRepetibilidadData(PruebasMetrologicas pruebas, int index, String field, String value) {
    if (index < 0 || index >= pruebas.repetibilidad.length) return;
    switch (field) {
      case 'carga': pruebas.repetibilidad[index].carga = value; break;
      case 'indicacion1': pruebas.repetibilidad[index].indicacion1 = value; break;
      case 'indicacion2': pruebas.repetibilidad[index].indicacion2 = value; break;
      case 'indicacion3': pruebas.repetibilidad[index].indicacion3 = value; break;
      case 'diferencia': pruebas.repetibilidad[index].diferencia = value; break;
      case 'errorMaximo': pruebas.repetibilidad[index].errorMaximo = value; break;
    }
    markChanged();
  }

  void addLinealidadData(PruebasMetrologicas pruebas, int index, String field, String value) {
    if (index < 0 || index >= pruebas.linealidad.length) return;
    switch (field) {
      case 'carga': pruebas.linealidad[index].carga = value; break;
      case 'indicacion1': pruebas.linealidad[index].indicacion1 = value; break;
      case 'indicacion2': pruebas.linealidad[index].indicacion2 = value; break;
      case 'error': pruebas.linealidad[index].error = value; break;
      case 'errorMaximo': pruebas.linealidad[index].errorMaximo = value; break;
      case 'incertidumbre': pruebas.linealidad[index].incertidumbre = value; break;
    }
    markChanged();
  }

  void showSuccessSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    super.dispose();
  }
}
