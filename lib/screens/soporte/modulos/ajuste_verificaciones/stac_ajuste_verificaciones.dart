// ignore_for_file: unused_local_variable, deprecated_member_use, library_private_types_in_public_api, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:service_met/providers/balanza_provider.dart';
import 'package:service_met/screens/soporte/modulos/ajuste_verificaciones/fin_servicio_ajustes_verificaciones.dart';
import 'models/ajuste_verificaciones_model.dart';
import 'controllers/ajuste_verificaciones_controller.dart';

import 'widgets/paso_pruebas_iniciales.dart';
import 'widgets/paso_pruebas_finales.dart';
import 'widgets/paso_estado_final_ajuste.dart';
import 'package:service_met/screens/soporte/widgets/soporte_stepper_layout.dart';

class StacAjusteVerificacionesScreen extends StatefulWidget {
  final String sessionId;
  final String secaValue;
  final String nReca;
  final String codMetrica;
  final String userName;
  final String clienteId;
  final String plantaCodigo;

  const StacAjusteVerificacionesScreen({
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
  _StacAjusteVerificacionesScreenState createState() =>
      _StacAjusteVerificacionesScreenState();
}

class _StacAjusteVerificacionesScreenState
    extends State<StacAjusteVerificacionesScreen> {
  late AjusteVerificacionesModel _model;
  late AjusteVerificacionesController _controller;

  int _currentStep = 0;
  bool _isSaving = false;
  DateTime? _lastPressedTime;
  double? _cachedD1;

  final List<SoporteStepData> _steps = [
    SoporteStepData(
      title: 'Pruebas Iniciales',
      subtitle: 'Metrología Inicial',
      icon: Icons.science_outlined,
    ),
    SoporteStepData(
      title: 'Pruebas Finales',
      subtitle: 'Metrología Final',
      icon: Icons.task_alt_outlined,
    ),
    SoporteStepData(
      title: 'Estado Final',
      subtitle: 'Cierre de Servicio',
      icon: Icons.checklist_rtl_sharp,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initializeModel();
    _controller = AjusteVerificacionesController(model: _model);
    _actualizarHora();
    _loadD1Value();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadD1Value() async {
    try {
      _cachedD1 = await _controller.getD1FromDatabase();
    } catch (e) {
      try {
        final balanza = Provider.of<BalanzaProvider>(context, listen: false)
            .selectedBalanza;
        _cachedD1 = balanza?.d1 ?? 0.1;
      } catch (e) {
        _cachedD1 = 0.1;
      }
    }
    if (mounted) setState(() {});
  }

  Future<double> _getD1FromCache() async {
    return _cachedD1 ?? 0.1;
  }

  void _initializeModel() {
    _model = AjusteVerificacionesModel(
      codMetrica: widget.codMetrica,
      sessionId: widget.sessionId,
      secaValue: widget.secaValue,
      pruebasIniciales: PruebasMetrologicas(),
      pruebasFinales: PruebasMetrologicas(),
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
      debugPrint('✅ Paso $_currentStep guardado');
    } catch (e) {
      debugPrint('❌ Error al guardar paso $_currentStep: $e');
      _showSnackBar('Error al guardar: ${e.toString()}', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  bool _validateCurrentStep() {
    // Validaciones básicas si se requieren
    if (_currentStep == 2) {
      if (_model.horaFin.isEmpty) {
        _showSnackBar(
            'Por favor registre la hora final (Se registrará al finalizar)',
            isError: false);
        // Permitimos continuar porque la hora fin se setea al guardar
      }
    }
    return true;
  }

  Future<void> _goToStep(int step) async {
    if (step > _currentStep && !_validateCurrentStep()) {
      return;
    }

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
      title: 'AJUSTES Y VERIFICACIONES',
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
          await _goToStep(_currentStep + 1);
        } else {
          if (_validateCurrentStep()) {
            await _controller.saveData(context);
            if (!mounted) return;
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => FinServicioAjustesVerificacionesScreen(
                  sessionId: widget.sessionId,
                  secaValue: widget.secaValue,
                  codMetrica: widget.codMetrica,
                  nReca: widget.nReca,
                  userName: widget.userName,
                  clienteId: widget.clienteId,
                  plantaCodigo: widget.plantaCodigo,
                  tableName: 'ajustes_metrologicos',
                ),
              ),
            );
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
        return PasoPruebasIniciales(
          model: _model,
          controller: _controller,
          onChanged: _onFieldChanged,
          getIndicationSuggestions: _controller.getIndicationSuggestions,
          getD1FromDatabase: _getD1FromCache,
        );
      case 1:
        return PasoPruebasFinales(
          model: _model,
          controller: _controller,
          onChanged: _onFieldChanged,
          getIndicationSuggestions: _controller.getIndicationSuggestions,
          getD1FromDatabase: _getD1FromCache,
        );
      case 2:
        return PasoEstadoFinalAjuste(
          model: _model,
          onChanged: _onFieldChanged,
        );
      default:
        return const Center(child: Text('Paso no encontrado'));
    }
  }
}
