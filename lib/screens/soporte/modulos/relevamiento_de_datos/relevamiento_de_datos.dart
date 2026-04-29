// ignore_for_file: library_private_types_in_public_api, deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:service_met/screens/soporte/widgets/soporte_stepper_layout.dart';
import 'package:service_met/screens/soporte/modulos/relevamiento_de_datos/fin_servicio.dart';
import 'package:service_met/screens/soporte/modulos/relevamiento_de_datos/widgets/steps/paso_entorno.dart';
import 'package:service_met/screens/soporte/modulos/relevamiento_de_datos/widgets/steps/paso_estado_final.dart';
import 'package:service_met/screens/soporte/modulos/relevamiento_de_datos/widgets/steps/paso_pruebas_finales.dart';
import 'package:service_met/screens/soporte/modulos/relevamiento_de_datos/widgets/steps/paso_terminal_plataforma_celdas.dart';
import 'controllers/relevamiento_de_datos_controller.dart';
import 'models/relevamiento_de_datos_model.dart';
import 'utils/modelo_helper.dart';

class RelevamientoDeDatosScreen extends StatefulWidget {
  final String sessionId;
  final String secaValue;
  final String nReca;
  final String codMetrica;
  final String userName;
  final String clienteId;
  final String plantaCodigo;

  const RelevamientoDeDatosScreen({
    super.key,
    required this.sessionId,
    required this.secaValue,
    required this.nReca,
    required this.codMetrica,
    required this.userName,
    required this.clienteId,
    required this.plantaCodigo,
  });

  @override
  _RelevamientoDeDatosScreenState createState() =>
      _RelevamientoDeDatosScreenState();
}

class _RelevamientoDeDatosScreenState extends State<RelevamientoDeDatosScreen> {
  late RelevamientoDeDatosModel _model;
  late RelevamientoDeDatosController _controller;

  int _currentStep = 0;
  bool _isSaving = false;
  DateTime? _lastPressedTime;
  double? _cachedD1;

  // Definición de pasos (4 pasos en total)
  final List<SoporteStepData> _steps = [];

  @override
  void initState() {
    super.initState();
    _initializeModel();
    _controller = RelevamientoDeDatosController(model: _model);
    _actualizarHora();
    _loadInitialDataAsync();
    _initializeSteps();
  }

  Future<void> _loadInitialDataAsync() async {
    await _controller.loadInitialValues();
    await _loadD1Value();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _initializeSteps() {
    _steps.addAll([
      SoporteStepData(
        title: 'Entorno',
        subtitle: 'Condiciones de instalación',
        icon: Icons.domain_outlined,
      ),
      SoporteStepData(
        title: 'Inspección',
        subtitle: 'Terminal, Plataforma, Celdas',
        icon: Icons.checklist_outlined,
      ),
      SoporteStepData(
        title: 'Pruebas Finales',
        subtitle: 'Pruebas metrológicas',
        icon: Icons.task_alt_outlined,
      ),
      SoporteStepData(
        title: 'Estado Final',
        subtitle: 'Conclusión del servicio',
        icon: Icons.assignment_turned_in_outlined,
      ),
    ]);
  }

  void _initializeModel() {
    _model = ModeloHelper.inicializarModelo(
      codMetrica: widget.codMetrica,
      sessionId: widget.sessionId,
      secaValue: widget.secaValue,
    );
  }

  void _actualizarHora() {
    final ahora = DateTime.now();
    _model.horaInicio = DateFormat('HH:mm:ss').format(ahora);
  }

  Future<void> _loadD1Value() async {
    _cachedD1 = await _controller.getD1FromDatabase();
    setState(() {});
  }

  Future<double> _getD1FromDatabase() async {
    return _cachedD1 ?? 0.1;
  }

  void _onFieldChanged() {
    setState(() {});
    _controller.scheduleAutoSave(context);
  }

  Future<void> _saveCurrentStep() async {
    if (_isSaving) return;

    setState(() => _isSaving = true);

    try {
      await _controller.flushAutoSave(context);
    } catch (e) {
      debugPrint('Error al guardar paso $_currentStep: $e');
      _showSnackBar('Error al guardar: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  bool _validateCurrentStep() {
    // Validación básica por paso
    switch (_currentStep) {
      case 0: // Entorno
        return true; // Los campos de entorno siempre tienen valor por defecto
      case 1: // Inspección
        return true; // Campos opcionales
      case 2: // Pruebas Finales
        return true; // Pruebas opcionales
      case 3: // Estado Final
        // Validar campos obligatorios
        if (_model.comentarioGeneral.isEmpty) {
          _showSnackBar('Por favor complete el comentario general');
          return false;
        }
        if (_model.recomendacion.isEmpty) {
          _showSnackBar('Por favor seleccione una recomendación');
          return false;
        }
        if (_model.fechaProxServicio.isEmpty) {
          _showSnackBar('Por favor seleccione la fecha del próximo servicio');
          return false;
        }
        if (_model.estadoFisico.isEmpty ||
            _model.estadoOperacional.isEmpty ||
            _model.estadoMetrologico.isEmpty) {
          _showSnackBar('Por favor complete todos los estados finales');
          return false;
        }
        if (_model.horaFin.isEmpty) {
          _showSnackBar('Por favor registre la hora final del servicio');
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  Future<void> _nextStep() async {
    if (!_validateCurrentStep()) return;

    await _saveCurrentStep();

    if (_currentStep < _steps.length - 1) {
      setState(() => _currentStep++);
    }
  }

  Future<void> _previousStep() async {
    await _saveCurrentStep();

    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  Future<void> _finalizarServicio() async {
    if (!_validateCurrentStep()) return;

    setState(() => _isSaving = true);

    try {
      await _controller.saveData(context);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => FinServicioScreen(
              sessionId: widget.sessionId,
              secaValue: widget.secaValue,
              nReca: widget.nReca,
              codMetrica: widget.codMetrica,
              userName: widget.userName,
              clienteId: widget.clienteId,
              plantaCodigo: widget.plantaCodigo,
              tableName: 'relevamiento_de_datos',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error al finalizar el servicio: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<bool> _onWillPop() async {
    final now = DateTime.now();

    if (_lastPressedTime == null ||
        now.difference(_lastPressedTime!) > const Duration(seconds: 2)) {
      _lastPressedTime = now;

      _showSnackBar(
        'Presione nuevamente para salir. Los datos se guardarán automáticamente.',
      );

      // Guardar antes de salir
      await _saveCurrentStep();

      return false;
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    return SoporteStepperLayout(
      title: 'RELEVAMIENTO DE DATOS',
      codMetrica: widget.codMetrica,
      steps: _steps,
      currentStep: _currentStep,
      isSaving: _isSaving,
      isAutoSavingNotifier: _controller.isAutoSaving,
      lastSaveSuccessfulNotifier: _controller.lastSaveSuccessful,
      stepContent: _buildStepContent(),
      onStepTapped: (index) async {
        if (index < _currentStep || _validateCurrentStep()) {
          await _controller.flushAutoSave(context);
          setState(() => _currentStep = index);
        }
      },
      onNext: () async {
        if (_currentStep < _steps.length - 1) {
          await _nextStep();
        } else {
          await _finalizarServicio();
        }
      },
      onBack: _previousStep,
      onWillPop: _onWillPop,
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return PasoEntorno(
          model: _model,
          controller: _controller,
          onChanged: _onFieldChanged,
        );
      case 1:
        return PasoTerminalPlataformaCeldas(
          model: _model,
          controller: _controller,
          onChanged: _onFieldChanged,
        );
      case 2:
        return PasoPruebasFinales(
          model: _model,
          controller: _controller,
          getD1FromDatabase: _getD1FromDatabase,
          onChanged: _onFieldChanged,
        );
      case 3:
        return PasoEstadoFinal(
          model: _model,
          onChanged: _onFieldChanged,
        );
      default:
        return const Center(child: Text('Paso no encontrado'));
    }
  }
}
