// ignore_for_file: library_private_types_in_public_api, deprecated_member_use, unused_local_variable

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'models/mnt_correctivo_model.dart';
import 'controllers/mnt_correctivo_controller.dart';
import 'widgets/paso_informacion_general.dart';
import 'widgets/paso_pruebas_finales.dart';
import 'widgets/paso_estado_final_mnt_correctivo.dart';
import 'fin_servicio_mntcorrectivo.dart';
import 'package:service_met/screens/soporte/widgets/soporte_stepper_layout.dart';

class StacMntCorrectivoScreen extends StatefulWidget {
  final String sessionId;
  final String secaValue;
  final String nReca;
  final String codMetrica;
  final String userName;
  final String clienteId;
  final String plantaCodigo;

  const StacMntCorrectivoScreen({
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
  _StacMntCorrectivoScreenState createState() =>
      _StacMntCorrectivoScreenState();
}

class _StacMntCorrectivoScreenState extends State<StacMntCorrectivoScreen> {
  late MntCorrectivoModel _model;
  late MntCorrectivoController _controller;

  int _currentStep = 0;
  bool _isSaving = false;
  bool _isLoading = true;
  DateTime? _lastPressedTime;

  // Definición de pasos
  final List<SoporteStepData> _steps = [];

  @override
  void initState() {
    super.initState();
    _model = MntCorrectivoModel(
      sessionId: widget.sessionId,
      secaValue: widget.secaValue,
      nReca: widget.nReca,
      codMetrica: widget.codMetrica,
      userName: widget.userName,
      clienteId: widget.clienteId,
      plantaCodigo: widget.plantaCodigo,
    );
    _model.horaInicio = DateFormat('HH:mm').format(DateTime.now());

    _controller = MntCorrectivoController(model: _model);
    _initializeData();
    _initializeSteps();
  }

  Future<void> _initializeData() async {
    await _controller.init();
    await _controller.loadInitialValues();
    if (mounted) setState(() => _isLoading = false);
  }

  void _onFieldChanged() {
    _controller.scheduleAutoSave(context);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _initializeSteps() {
    _steps.addAll([
      SoporteStepData(
        title: 'Información General',
        subtitle: 'Datos iniciales del servicio',
        icon: Icons.info_outlined,
      ),
      SoporteStepData(
        title: 'Pruebas Finales',
        subtitle: 'Verificación final',
        icon: Icons.task_alt_outlined,
      ),
      SoporteStepData(
        title: 'Estado Final',
        subtitle: 'Conclusión del servicio',
        icon: Icons.assignment_turned_in_outlined,
      ),
    ]);
  }

  // Guardar automáticamente al cambiar de paso
  Future<void> _saveCurrentStep() async {
    if (_isSaving) return;

    setState(() => _isSaving = true);

    try {
      await _controller.saveData(context);
      debugPrint('Paso $_currentStep guardado automáticamente');
    } catch (e) {
      debugPrint('Error al guardar paso $_currentStep: $e');
      _showSnackBar('Error al guardar: ${e.toString()}', isError: true);
    } finally {
      setState(() => _isSaving = false);
    }
  }

  // Validar paso actual antes de avanzar
  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0: // Información General
        if (_model.reporteFalla.isEmpty) {
          _showSnackBar('Por favor complete el reporte de falla',
              isError: true);
          return false;
        }
        return true;

      case 1: // Pruebas Finales
        return true; // Permitir continuar

      case 2: // Estado Final
        if (_model.comentarioGeneral.isEmpty ||
            _model.recomendacion.isEmpty ||
            _model.fechaProxServicio.isEmpty ||
            _model.estadoFisico.isEmpty ||
            _model.estadoOperacional.isEmpty ||
            _model.estadoMetrologico.isEmpty ||
            _model.horaFin.isEmpty) {
          _showSnackBar(
              'Por favor complete todos los campos obligatorios del estado final',
              isError: true);
          return false;
        }
        return true;

      default:
        return true;
    }
  }

  Future<void> _goToStep(int step) async {
    // Validar paso actual antes de avanzar
    if (step > _currentStep && !_validateCurrentStep()) {
      return;
    }

    // Guardar antes de cambiar de paso
    await _saveCurrentStep();

    setState(() {
      _currentStep = step;
    });
  }

  Future<bool> _onWillPop() async {
    final now = DateTime.now();

    if (_lastPressedTime == null ||
        now.difference(_lastPressedTime!) > const Duration(seconds: 2)) {
      _lastPressedTime = now;

      _showSnackBar(
        'Presione nuevamente para salir. Los datos se guardarán automáticamente.',
        isError: false,
      );

      // Guardar antes de salir
      await _saveCurrentStep();

      return false;
    }

    return true;
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: isError ? 3 : 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SoporteStepperLayout(
      title: 'MANTENIMIENTO CORRECTIVO',
      codMetrica: widget.codMetrica,
      steps: _steps,
      currentStep: _currentStep,
      isSaving: _isSaving,
      isLoading: _isLoading,
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
          await _goToStep(_currentStep + 1);
        } else {
          // Finalizar servicio
          if (_validateCurrentStep()) {
            await _saveCurrentStep();
            if (context.mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => FinServicioMntcorrectivoScreen(
                    sessionId: widget.sessionId,
                    secaValue: widget.secaValue,
                    nReca: widget.nReca,
                    codMetrica: widget.codMetrica,
                    userName: widget.userName,
                    clienteId: widget.clienteId,
                    plantaCodigo: widget.plantaCodigo,
                    tableName: 'diagnostico_correctivo', // TODO: verificar si este nombre de tabla es correcto.
                  ),
                ),
              );
            }
          }
        }
      },
      onBack: () => _goToStep(_currentStep - 1),
      onWillPop: _onWillPop,
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return PasoInformacionGeneral(
          model: _model,
          controller: _controller,
          onUpdate: _onFieldChanged,
        );
      case 1:
        return PasoPruebasFinales(
          model: _model,
          controller: _controller,
          onUpdate: _onFieldChanged,
        );
      case 2:
        return PasoEstadoFinalMntCorrectivo(
          model: _model,
          onChanged: _onFieldChanged,
        );
      default:
        return const Center(child: Text('Paso no encontrado'));
    }
  }
}
