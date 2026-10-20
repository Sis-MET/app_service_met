import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:service_met/database/local_database_catalog.dart';
import 'package:service_met/screens/soporte_new/database/database_helper_soporte.dart';
import 'package:service_met/screens/soporte_new/models/base_soporte_model.dart';
import 'package:service_met/screens/soporte_new/models/campo_estado.dart';
import 'package:service_met/screens/soporte_new/models/shared_metrology_models.dart';
import 'package:service_met/services/ubicacion_servicio.dart';

abstract class BaseSoporteController extends ChangeNotifier
    with WidgetsBindingObserver {
  bool _isDisposed = false;
  bool _postFrameNotificationScheduled = false;

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

  String _recoveryPersonal = '';
  Map<String, dynamic> _recoveryRouteData = const {};
  bool _recoveryConfigured = false;

  Timer? _autoSaveTimer;
  final ValueNotifier<bool> hasUnsavedChanges = ValueNotifier<bool>(false);

  bool _isSaving = false;
  bool get isSaving => _isSaving;

  bool _lastSaveSuccessful = true;
  bool get lastSaveSuccessful => _lastSaveSuccessful;

  /// Por qué falló el último guardado, si el módulo lo informó.
  String? _lastSaveError;
  String? get lastSaveError => _lastSaveError;

  // Setters públicos para que los controladores que persisten en la DB
  // legacy puedan actualizar el estado de guardado (indicador en UI).
  void setSaveInProgress() {
    _isSaving = true;
    notifyListenersSafely();
  }

  void setSaveSuccess(bool successful, {Object? error}) {
    _isSaving = false;
    _lastSaveSuccessful = successful;
    _lastSaveError = successful ? null : error?.toString();
    notifyListenersSafely();
    if (successful) unawaited(registrarUbicacion());
  }

  /// Deja en el registro dónde se está haciendo el servicio, si todavía no
  /// lo tiene. Sin GPS o sin permiso no hace nada.
  Future<bool> registrarUbicacion() async {
    final otst = secaValue.trim();
    final sessionId = model.sessionId.trim();
    if (otst.isEmpty || sessionId.isEmpty) return false;
    // [tableName] es la tabla local en unos módulos y la clave del módulo en
    // otros (mnt_correctivo vive en la tabla diagnostico_correctivo).
    final spec = LocalDatabaseCatalog.soporte
        .where((spec) => spec.table == tableName || spec.module == tableName);
    if (spec.isEmpty) return false;
    return RegistroUbicacion.instance.registrar(
      abrir: spec.first.openLive,
      tabla: spec.first.table,
      where: 'otst = ? AND session_id = ?',
      whereArgs: [otst, sessionId],
    );
  }

  /// Notifica inmediatamente fuera de la fase de construcción y difiere la
  /// notificación al final del frame cuando un widget todavía está en build.
  /// Esto evita que el autoguardado intente reconstruir un ListenableBuilder
  /// mientras Flutter mantiene bloqueado el árbol de widgets.
  @protected
  void notifyListenersSafely() {
    if (_isDisposed) return;
    if (SchedulerBinding.instance.schedulerPhase !=
        SchedulerPhase.persistentCallbacks) {
      notifyListeners();
      return;
    }
    if (_postFrameNotificationScheduled) return;
    _postFrameNotificationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _postFrameNotificationScheduled = false;
      if (!_isDisposed) notifyListeners();
    });
  }

  BaseSoporteController();

  void configureRecovery({
    required String personal,
    required String clienteId,
    required String clienteRazonSocial,
    required String plantaCodigo,
    required String plantaDireccion,
    required String plantaDepartamento,
    required String nReca,
    Map<String, dynamic>? instrumentoData,
  }) {
    _recoveryPersonal = personal;
    _recoveryRouteData = {
      'cliente_id': clienteId,
      'cliente_nombre': clienteNombre,
      'cliente_razon_social': clienteRazonSocial,
      'planta_codigo': plantaCodigo,
      'planta_nombre': plantaNombre,
      'planta_direccion': plantaDireccion,
      'planta_departamento': plantaDepartamento,
      'cod_metrica': model.codMetrica,
      'n_reca': nReca,
      'instrumento_data': instrumentoData ?? const <String, dynamic>{},
    };
    if (!_recoveryConfigured) {
      _recoveryConfigured = true;
      WidgetsBinding.instance.addObserver(this);
    }
    unawaited(_initializeRecoverySafely());
  }

  Future<void> _initializeRecoverySafely() async {
    try {
      await initializeRecovery();
    } catch (error) {
      debugPrint('Error inicializando recuperación de $tableName: $error');
    }
  }

  Future<void> initializeRecovery() async {
    if (!_recoveryConfigured) return;
    final saved = await dbHelper.getSessionProgress(tableName, model.sessionId);
    if (saved != null && saved['status']?.toString() == 'in_progress') {
      final restoredStep =
          int.tryParse(saved['current_step']?.toString() ?? '');
      if (restoredStep != null) {
        currentStep = restoredStep.clamp(0, totalSteps - 1);
        notifyListenersSafely();
      }
    }
    await persistRecoveryProgress();
  }

  Future<void> persistRecoveryProgress() async {
    if (!_recoveryConfigured) return;
    await dbHelper.saveSessionProgress(
      moduleKey: tableName,
      sessionId: model.sessionId,
      otst: secaValue,
      personal: _recoveryPersonal,
      currentStep: currentStep,
      totalSteps: totalSteps,
      routeData: _recoveryRouteData,
    );
  }

  void setCurrentStep(int step) {
    if (step < 0 || step >= totalSteps) return;
    currentStep = step;
    notifyListenersSafely();
    unawaited(_persistRecoverySafely());
  }

  Future<void> _persistRecoverySafely() async {
    try {
      await persistRecoveryProgress();
    } catch (error) {
      debugPrint('Error guardando progreso de $tableName: $error');
    }
  }

  Future<void> markRecoveryCompleted() async {
    await dbHelper.markSessionCompleted(tableName, model.sessionId);
  }

  Future<void> markRecoveryAbandoned() async {
    await dbHelper.markSessionAbandoned(tableName, model.sessionId);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_flushForLifecycle().catchError((Object error) {
        debugPrint('Error guardando $tableName al cerrar: $error');
      }));
    }
  }

  Future<void> _flushForLifecycle() async {
    if (hasUnsavedChanges.value) {
      await autoSave();
    }
    await persistRecoveryProgress();
  }

  /// Guarda lo pendiente antes de salir con "Salir (queda guardado)". False
  /// si no se pudo guardar: la pantalla debe avisar antes de cerrar.
  Future<bool> guardarAntesDeSalir() async {
    _autoSaveTimer?.cancel();
    await _flushForLifecycle();
    return !hasUnsavedChanges.value;
  }

  /// Guarda ya lo que está en pantalla, sin esperar al autoguardado, como
  /// al avanzar en la calibración. True si quedó en el teléfono; si no,
  /// [lastSaveError] dice por qué, cuando el módulo lo informa.
  Future<bool> guardarAhora() async {
    _autoSaveTimer?.cancel();
    await guardarSesion();
    if (_lastSaveSuccessful && !_isDisposed) hasUnsavedChanges.value = false;
    return _lastSaveSuccessful;
  }

  void markChanged() {
    hasUnsavedChanges.value = true;
    _autoSaveTimer?.cancel();
    _autoSaveTimer =
        Timer(const Duration(milliseconds: 1500), () => autoSave());
  }

  /// Activa u omite una prueba metrológica con [aplicar] (el interruptor
  /// "Realizar ..."). La pantalla la muestra u oculta en el acto y el cambio
  /// se guarda ya: con [markChanged] solo, nada se redibujaba hasta el
  /// autoguardado, segundo y medio después. True si quedó guardado.
  Future<bool> cambiarPrueba(void Function() aplicar) {
    aplicar();
    hasUnsavedChanges.value = true;
    notifyListenersSafely();
    return guardarAhora();
  }

  Future<void> autoSave() async {
    if (!hasUnsavedChanges.value) return;
    await guardarSesion();
    // Si no se pudo guardar, sigue pendiente: el próximo cambio o el paso a
    // segundo plano lo vuelven a intentar.
    if (_lastSaveSuccessful) hasUnsavedChanges.value = false;
  }

  Future<void> loadExistingSession(
      String sessionId, Map<String, dynamic> data) async {
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
          excentricidad: (pi['excentricidad'] as List)
              .map((e) => Excentricidad(
                    posicion: e['posicion'] ?? '',
                    carga: e['carga'] ?? '',
                    indicacion1: e['indicacion1'] ?? '',
                    indicacion2: e['indicacion2'] ?? '',
                    indicacion3: e['indicacion3'] ?? '',
                    diferencia: e['diferencia'] ?? '',
                    error: e['error'] ?? '',
                    errorMaximo: e['errorMaximo'] ?? '',
                  ))
              .toList(),
          repetibilidad: (pi['repetibilidad'] as List)
              .map((r) => Repetibilidad(
                    carga: r['carga'] ?? '',
                    indicacion1: r['indicacion1'] ?? '',
                    indicacion2: r['indicacion2'] ?? '',
                    indicacion3: r['indicacion3'] ?? '',
                    diferencia: r['diferencia'] ?? '',
                    errorMaximo: r['errorMaximo'] ?? '',
                  ))
              .toList(),
          linealidad: (pi['linealidad'] as List)
              .map((l) => Linealidad(
                    carga: l['carga'] ?? '',
                    indicacion1: l['indicacion1'] ?? '',
                    indicacion2: l['indicacion2'] ?? '',
                    error: l['error'] ?? '',
                    errorMaximo: l['errorMaximo'] ?? '',
                    incertidumbre: l['incertidumbre'] ?? '',
                  ))
              .toList(),
        );
      } catch (_) {}
    }
    if (data['pruebas_finales'] != null) {
      try {
        final pf = jsonDecode(data['pruebas_finales']);
        pruebasFinales = PruebasMetrologicas(
          excentricidad: (pf['excentricidad'] as List)
              .map((e) => Excentricidad(
                    posicion: e['posicion'] ?? '',
                    carga: e['carga'] ?? '',
                    indicacion1: e['indicacion1'] ?? '',
                    indicacion2: e['indicacion2'] ?? '',
                    indicacion3: e['indicacion3'] ?? '',
                    diferencia: e['diferencia'] ?? '',
                    error: e['error'] ?? '',
                    errorMaximo: e['errorMaximo'] ?? '',
                  ))
              .toList(),
          repetibilidad: (pf['repetibilidad'] as List)
              .map((r) => Repetibilidad(
                    carga: r['carga'] ?? '',
                    indicacion1: r['indicacion1'] ?? '',
                    indicacion2: r['indicacion2'] ?? '',
                    indicacion3: r['indicacion3'] ?? '',
                    diferencia: r['diferencia'] ?? '',
                    errorMaximo: r['errorMaximo'] ?? '',
                  ))
              .toList(),
          linealidad: (pf['linealidad'] as List)
              .map((l) => Linealidad(
                    carga: l['carga'] ?? '',
                    indicacion1: l['indicacion1'] ?? '',
                    indicacion2: l['indicacion2'] ?? '',
                    error: l['error'] ?? '',
                    errorMaximo: l['errorMaximo'] ?? '',
                    incertidumbre: l['incertidumbre'] ?? '',
                  ))
              .toList(),
        );
      } catch (_) {}
    }
    notifyListenersSafely();
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
    notifyListenersSafely();
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
      _lastSaveError = null;
    } catch (e) {
      _lastSaveSuccessful = false;
      _lastSaveError = e.toString();
      debugPrint('Error guardando sesion $tableName: $e');
    } finally {
      _isGuardando = false;
      _isSaving = false;
      notifyListenersSafely();
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
    await markRecoveryCompleted();
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

  void addExcentricidadData(
      PruebasMetrologicas pruebas, int index, String field, String value) {
    if (index < 0 || index >= pruebas.excentricidad.length) return;
    switch (field) {
      case 'posicion':
        pruebas.excentricidad[index].posicion = value;
        break;
      case 'carga':
        pruebas.excentricidad[index].carga = value;
        break;
      case 'indicacion1':
        pruebas.excentricidad[index].indicacion1 = value;
        break;
      case 'indicacion2':
        pruebas.excentricidad[index].indicacion2 = value;
        break;
      case 'indicacion3':
        pruebas.excentricidad[index].indicacion3 = value;
        break;
      case 'diferencia':
        pruebas.excentricidad[index].diferencia = value;
        break;
      case 'error':
        pruebas.excentricidad[index].error = value;
        break;
      case 'errorMaximo':
        pruebas.excentricidad[index].errorMaximo = value;
        break;
    }
    markChanged();
  }

  void addRepetibilidadData(
      PruebasMetrologicas pruebas, int index, String field, String value) {
    if (index < 0 || index >= pruebas.repetibilidad.length) return;
    switch (field) {
      case 'carga':
        pruebas.repetibilidad[index].carga = value;
        break;
      case 'indicacion1':
        pruebas.repetibilidad[index].indicacion1 = value;
        break;
      case 'indicacion2':
        pruebas.repetibilidad[index].indicacion2 = value;
        break;
      case 'indicacion3':
        pruebas.repetibilidad[index].indicacion3 = value;
        break;
      case 'diferencia':
        pruebas.repetibilidad[index].diferencia = value;
        break;
      case 'errorMaximo':
        pruebas.repetibilidad[index].errorMaximo = value;
        break;
    }
    markChanged();
  }

  void addLinealidadData(
      PruebasMetrologicas pruebas, int index, String field, String value) {
    if (index < 0 || index >= pruebas.linealidad.length) return;
    switch (field) {
      case 'carga':
        pruebas.linealidad[index].carga = value;
        break;
      case 'indicacion1':
        pruebas.linealidad[index].indicacion1 = value;
        break;
      case 'indicacion2':
        pruebas.linealidad[index].indicacion2 = value;
        break;
      case 'error':
        pruebas.linealidad[index].error = value;
        break;
      case 'errorMaximo':
        pruebas.linealidad[index].errorMaximo = value;
        break;
      case 'incertidumbre':
        pruebas.linealidad[index].incertidumbre = value;
        break;
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
    _isDisposed = true;
    if (_recoveryConfigured) {
      WidgetsBinding.instance.removeObserver(this);
    }
    _autoSaveTimer?.cancel();
    hasUnsavedChanges.dispose();
    super.dispose();
  }
}
