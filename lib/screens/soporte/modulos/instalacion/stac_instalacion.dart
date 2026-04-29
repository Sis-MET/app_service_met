// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:service_met/screens/soporte/modulos/instalacion/fin_servicio_instalacion.dart';

import 'controllers/instalacion_controller.dart';
import 'models/instalacion_model.dart';
import 'widgets/steps/paso_condiciones_instalacion.dart';
import 'widgets/steps/paso_pruebas_instalacion.dart';
import 'widgets/steps/paso_estado_final_instalacion.dart';
import 'package:service_met/screens/soporte/widgets/soporte_stepper_layout.dart';

class StacInstalacionScreen extends StatefulWidget {
  final String sessionId;
  final String secaValue;
  final String nReca;
  final String codMetrica;
  final String userName;
  final String clienteId;
  final String plantaCodigo;

  const StacInstalacionScreen({
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
  _StacInstalacionScreenState createState() => _StacInstalacionScreenState();
}

class _StacInstalacionScreenState extends State<StacInstalacionScreen> {
  late InstalacionModel _model;
  late InstalacionController _controller;

  int _currentStep = 0;
  bool _isSaving = false;

  final List<SoporteStepData> _steps = [
    SoporteStepData(
      title: 'Condiciones',
      subtitle: 'Entorno y montaje',
      icon: Icons.domain_outlined,
    ),
    SoporteStepData(
      title: 'Pruebas',
      subtitle: 'Metrología Inicial',
      icon: Icons.science_outlined,
    ),
    SoporteStepData(
      title: 'Estado Final',
      subtitle: 'Cierre de servicio',
      icon: Icons.assignment_turned_in_outlined,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initializeModel();
    _controller = InstalacionController(model: _model);
    _actualizarHora();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _initializeModel() {
    final camposCondiciones = {
      'Entorno': CampoEstado(),
      'Superficie de Apoyo': CampoEstado(),
      'Tensión de Red': CampoEstado(),
      'Sistema de Tierra': CampoEstado(),
      'Comunicación PC/Impresora': CampoEstado(),
      'Movilización': CampoEstado(),
      'Vibración Externa': CampoEstado(),
      'Flujo de Pesadas': CampoEstado(),
    };

    _model = InstalacionModel(
      codMetrica: widget.codMetrica,
      sessionId: widget.sessionId,
      secaValue: widget.secaValue,
      camposCondiciones: camposCondiciones,
    );
  }

  void _actualizarHora() {
    final ahora = DateTime.now();
    final horaFormateada = DateFormat('HH:mm:ss').format(ahora);
    _model.horaInicio = horaFormateada;
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
      debugPrint('Paso $_currentStep guardado');
    } catch (e) {
      debugPrint('Error al guardar paso $_currentStep: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _goToStep(int step) async {
    await _saveCurrentStep();
    setState(() {
      _currentStep = step;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SoporteStepperLayout(
      title: 'INSTALACIÓN',
      codMetrica: widget.codMetrica,
      steps: _steps,
      currentStep: _currentStep,
      isSaving: _isSaving,
      isAutoSavingNotifier: _controller.isAutoSaving,
      lastSaveSuccessfulNotifier: _controller.lastSaveSuccessful,
      stepContent: _buildStepContent(),
      onStepTapped: (index) async {
        if (index < _currentStep) {
          await _controller.flushAutoSave(context);
          setState(() => _currentStep = index);
        }
      },
      onNext: () async {
        if (_currentStep < _steps.length - 1) {
          await _goToStep(_currentStep + 1);
        } else {
          // FINALIZAR
          await _saveCurrentStep();
          if (!mounted) return;
          _model.horaFin = DateFormat('HH:mm:ss').format(DateTime.now());
          await _controller.saveData(context);

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => FinServicioInstalacionScreen(
                sessionId: widget.sessionId,
                secaValue: widget.secaValue,
                codMetrica: widget.codMetrica,
                nReca: widget.nReca,
                userName: widget.userName,
                clienteId: widget.clienteId,
                plantaCodigo: widget.plantaCodigo,
                tableName: 'instalacion',
              ),
            ),
          );
        }
      },
      onBack: () => _goToStep(_currentStep - 1),
      onWillPop: () async {
        await _saveCurrentStep();
        return true;
      },
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return PasoCondicionesInstalacion(
          model: _model,
          controller: _controller,
          onChanged: _onFieldChanged,
        );
      case 1:
        return PasoPruebasInstalacion(
          model: _model,
          controller: _controller,
          onChanged: _onFieldChanged,
        );
      case 2:
        return PasoEstadoFinalInstalacion(
          model: _model,
          controller: _controller,
          onChanged: _onFieldChanged,
        );
      default:
        return const Center(child: Text('Paso no encontrado'));
    }
  }
}
