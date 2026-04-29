// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:service_met/provider/balanza_provider.dart';

// Modelos y Controladores propios
import 'models/verificaciones_internas_model.dart';
import 'controllers/verificaciones_internas_controller.dart';
import 'utils/constants.dart';

// Widgets de pasos
import 'widgets/steps/paso_pruebas_iniciales.dart';
import 'widgets/steps/paso_estado_final.dart';
import 'widgets/steps/paso_generico.dart';

// Pantalla final
import 'fin_servicio_vinternas.dart';
import 'package:service_met/screens/soporte/widgets/soporte_stepper_layout.dart';

class StacVerificacionesInternasScreen extends StatefulWidget {
  final String otst;
  final String codMetrica;
  final String sessionId;
  final String nReca;
  final String userName;
  final int clienteId;
  final String plantaCodigo;

  const StacVerificacionesInternasScreen({
    super.key,
    required this.otst,
    required this.codMetrica,
    required this.sessionId,
    required this.nReca,
    required this.userName,
    required this.clienteId,
    required this.plantaCodigo,
  });

  @override
  State<StacVerificacionesInternasScreen> createState() =>
      _StacVerificacionesInternasScreenState();
}

class _StacVerificacionesInternasScreenState
    extends State<StacVerificacionesInternasScreen> {
  late VerificacionesInternasModel _model;
  late VerificacionesInternasController _controller;
  int _currentStep = 0;
  bool _isSaving = false;
  DateTime? _lastPressedTime;
  double? _cachedD1; // Cachear d1

  final List<SoporteStepData> _steps = [];

  @override
  void initState() {
    super.initState();
    _initializeModel();
    _controller = VerificacionesInternasController(model: _model);
    _actualizarHora();
    _initializeSteps();

    // Trigger async load at start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialDataAsync();
    });
  }

  Future<void> _loadInitialDataAsync() async {
    setState(() => _isSaving = true);
    await _controller.loadInitialValues();
    await _loadD1Value();
    if (mounted) setState(() => _isSaving = false);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _initializeSteps() {
    _steps.addAll([
      SoporteStepData(
        title: 'Inspección Visual',
        subtitle: '4 campos de inspección',
        icon: Icons.visibility_outlined,
      ),
      SoporteStepData(
        title: 'Pruebas Metrológicas',
        subtitle: 'Excentricidad, Repetibilidad, Linealidad',
        icon: Icons.science_outlined,
      ),
      SoporteStepData(
        title: 'Estado Final',
        subtitle: 'Conclusión del servicio',
        icon: Icons.assignment_turned_in_outlined,
      ),
    ]);
  }

  void _initializeModel() {
    final camposEstado = <String, CampoEstado>{};

    // Inicializar TODOS los campos usando constantes
    for (final campo in AppVerificacionesInternasConstants.getAllCampos()) {
      camposEstado[campo] = CampoEstado();
    }

    _model = VerificacionesInternasModel(
      codMetrica: widget.codMetrica,
      sessionId: widget.sessionId,
      secaValue: widget.otst,
      horaInicio: DateFormat('HH:mm').format(DateTime.now()),
      camposEstado: camposEstado,
    );
  }

  void _actualizarHora() {
    if (mounted) {
      setState(() {
        // Solo actualizar si la hora de inicio está vacía (aunque se inicializa en constructor)
        // o si queremos forzar actualización de hora fin en navegación
      });
    }
  }

  // Cargar d1 una sola vez
  Future<void> _loadD1Value() async {
    try {
      _cachedD1 = await _controller.getD1FromDatabase();
      if (_cachedD1 == null) {
        // Intentar obtener del provider si existe
        if (mounted) {
          try {
            final balanza = Provider.of<BalanzaProvider>(context, listen: false)
                .selectedBalanza;
            _cachedD1 = balanza?.d1 ?? 0.1;
          } catch (_) {
            _cachedD1 = 0.1;
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading D1: $e');
      _cachedD1 = 0.1;
    }
    setState(() {});
  }

  Future<double> _getD1FromCache() async {
    return _cachedD1 ?? 0.1;
  }

  Future<void> _saveCurrentStep() async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      // Actualizar hora fin solo al guardar estado final o finalizar
      if (_currentStep == _steps.length - 1) {
        _model.horaFin = DateFormat('HH:mm:ss').format(DateTime.now());
      }

      await _controller.saveDataToDatabase(context, showMessage: false);
    } catch (e) {
      debugPrint('Error saving step: $e');
      _showSnackBar('Error al guardar: ${e.toString()}', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0: // Inspección Visual
        final camposDelPaso =
            AppVerificacionesInternasConstants.inspeccionVisualCampos;
        for (var campo in camposDelPaso) {
          if (_model.camposEstado[campo]?.initialValue == null ||
              _model.camposEstado[campo]!.initialValue.isEmpty) {
            _showSnackBar(
              'Por favor complete todos los campos de inspección',
              isError: true,
            );
            return false;
          }
        }
        return true;

      case 1: // Pruebas Metrológicas
        return true;

      case 2: // Estado Final
        if (_model.comentarioGeneral.isEmpty) {
          _showSnackBar('Por favor complete el Comentario General',
              isError: true);
          return false;
        }
        if (_model.recomendacion.isEmpty) {
          _showSnackBar('Por favor seleccione una Recomendación',
              isError: true);
          return false;
        }
        if (_model.fechaProxServicio.isEmpty) {
          _showSnackBar('Por favor seleccione la fecha del próximo servicio',
              isError: true);
          return false;
        }
        if (_model.estadoFisico.isEmpty ||
            _model.estadoOperacional.isEmpty ||
            _model.estadoMetrologico.isEmpty) {
          _showSnackBar('Por favor complete todos los estados finales',
              isError: true);
          return false;
        }
        if (_model.horaFin.isEmpty) {
          _showSnackBar('Por favor registre la hora final del servicio',
              isError: true);
          return false;
        }
        return true;

      default:
        return true;
    }
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Presione nuevamente para salir. Los datos se guardarán automáticamente.'),
          duration: Duration(seconds: 2),
        ),
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
      title: 'VERIFICACIONES INTERNAS',
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
          // Último paso: finalizar
          if (_validateCurrentStep()) {
            await _saveCurrentStep();
            if (!mounted) return;

            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => FinServicioVinternasScreen(
                  sessionId: widget.sessionId,
                  secaValue: widget.otst,
                  codMetrica: widget.codMetrica,
                  nReca: widget.nReca,
                  userName: widget.userName,
                  clienteId: widget.clienteId.toString(),
                  plantaCodigo: widget.plantaCodigo,
                  tableName: 'verificaciones_internas',
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

  void _onFieldChanged() {
    setState(() {});
    _controller.scheduleAutoSave(context);
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0: // Inspección Visual
        return PasoGenerico(
          model: _model,
          controller: _controller,
          onChanged: _onFieldChanged,
          campos: AppVerificacionesInternasConstants.inspeccionVisualCampos,
          titulo: 'INSPECCIÓN VISUAL',
          subtitulo: 'Inspeccione el estado general del equipo',
          icono: Icons.visibility_outlined,
          color: Colors.blue,
        );

      case 1: // Pruebas Metrológicas
        return PasoPruebasIniciales(
          model: _model,
          controller: _controller,
          getD1FromDatabase: _getD1FromCache,
          onChanged: _onFieldChanged,
        );

      case 2: // Estado Final
        return PasoEstadoFinal(
          model: _model,
          onChanged: _onFieldChanged,
        );

      default:
        return const Center(child: Text('Paso no encontrado'));
    }
  }
}
