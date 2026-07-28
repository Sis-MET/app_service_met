// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:service_met/providers/balanza_provider.dart';

import 'models/relevamiento_de_datos_model.dart';
import 'controllers/relevamiento_de_datos_controller.dart';
import 'widgets/steps/paso_terminal_plataforma_celdas.dart';
import 'package:service_met/screens/soporte/widgets/shared/paso_entorno_widget.dart';
import 'package:service_met/screens/soporte/widgets/shared/paso_pruebas_finales_widget.dart';
import 'package:service_met/screens/soporte/widgets/shared/paso_estado_final_widget.dart';
import 'package:service_met/screens/soporte/widgets/soporte_stepper_layout.dart';
import 'package:service_met/screens/soporte/widgets/fin_servicio_screen.dart';
import 'utils/constants.dart';

class StacRelevamientoDeDatosScreen extends StatefulWidget {
  final String sessionId;
  final String secaValue;
  final String nReca;
  final String codMetrica;
  final String userName;
  final String clienteId;
  final String plantaCodigo;

  const StacRelevamientoDeDatosScreen({
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
  State<StacRelevamientoDeDatosScreen> createState() =>
      _StacRelevamientoDeDatosScreenState();
}

class _StacRelevamientoDeDatosScreenState
    extends State<StacRelevamientoDeDatosScreen> {
  late RelevamientoDeDatosModel _model;
  late RelevamientoDeDatosController _controller;
  int _currentStep = 0;
  bool _isSaving = false;
  DateTime? _lastPressedTime;
  double? _cachedD1;

  final List<SoporteStepData> _steps = [];

  @override
  void initState() {
    super.initState();
    _initializeModel();
    _controller = RelevamientoDeDatosController(model: _model);
    _initializeSteps();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _loadInitialDataAsync());
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
    final camposEstado = <String, CampoEstado>{};
    for (final campo in [
      ...AppConstants.entornoCampos.keys,
      ...AppConstants.terminalCampos,
      ...AppConstants.plataformaCampos,
      ...AppConstants.celdasCargaCampos,
    ]) {
      camposEstado[campo] = CampoEstado();
    }

    _model = RelevamientoDeDatosModel(
      codMetrica: widget.codMetrica,
      sessionId: widget.sessionId,
      secaValue: widget.secaValue,
      horaInicio: DateFormat('HH:mm:ss').format(DateTime.now()),
      camposEstado: camposEstado,
    );
  }

  Future<void> _loadD1Value() async {
    try {
      _cachedD1 = await _controller.getD1FromDatabase();
      if (_cachedD1 == null && mounted) {
        final balanza =
            Provider.of<BalanzaProvider>(context, listen: false)
                .selectedBalanza;
        _cachedD1 = balanza?.d1 ?? 0.1;
      }
    } catch (_) {
      _cachedD1 = 0.1;
    }
    setState(() {});
  }

  Future<double> _getD1FromCache() async => _cachedD1 ?? 0.1;

  Future<void> _saveCurrentStep() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      if (_currentStep == _steps.length - 1) {
        _model.horaFin = DateFormat('HH:mm:ss').format(DateTime.now());
      }
      await _controller.saveData(context);
    } catch (e) {
      _showSnackBar('Error al guardar: ${e.toString()}', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 3:
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
          _showSnackBar(
              'Por favor seleccione la fecha del próximo servicio',
              isError: true);
          return false;
        }
        if (_model.estadoFisico.isEmpty ||
            _model.estadoOperacional.isEmpty ||
            _model.estadoMetrologico.isEmpty) {
          _showSnackBar(
              'Por favor complete todos los estados finales',
              isError: true);
          return false;
        }
        if (_model.horaFin.isEmpty) {
          _showSnackBar(
              'Por favor registre la hora final del servicio',
              isError: true);
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  Future<void> _goToStep(int step) async {
    if (step > _currentStep && !_validateCurrentStep()) return;
    await _saveCurrentStep();
    setState(() => _currentStep = step);
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
          await _goToStep(_currentStep + 1);
        } else {
          if (_validateCurrentStep()) {
            await _saveCurrentStep();
            if (!mounted) return;
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => FinServicioScreen(
                  sessionId: widget.sessionId,
                  secaValue: widget.secaValue,
                  codMetrica: widget.codMetrica,
                  nReca: widget.nReca,
                  userName: widget.userName,
                  clienteId: widget.clienteId,
                  plantaCodigo: widget.plantaCodigo,
                  tableName: 'relevamiento_de_datos',
                  config: const FinServicioConfig(
                    tableNameDefault: 'relevamiento_de_datos',
                    csvSuffix: 'relevamiento_de_datos',
                    additionalWhere: "AND estado_servicio = 'Completo'",
                    tipoServicio: 'REL.SP',
                  ),
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
      case 0:
        return PasoEntornoWidget(
          secciones: [
            EntornoSection(
              titulo: 'ENTORNO DE INSTALACIÓN',
              subtitulo: 'Inspeccione las condiciones ambientales',
              icono: Icons.domain_outlined,
              color: Colors.blue,
              campos: AppConstants.entornoCampos.keys.toList(),
            ),
          ],
          camposEstado: _model.camposEstado,
          onChanged: _onFieldChanged,
          onAddPhoto: (label, foto) => _controller.agregarFoto(label, foto),
          onRemovePhoto: (label, index) =>
              _controller.eliminarFoto(label, index),
        );
      case 1:
        return PasoTerminalPlataformaCeldas(
          model: _model,
          controller: _controller,
          onChanged: _onFieldChanged,
        );
      case 2:
        return PasoPruebasFinalesWidget(
          pruebas: _model.pruebasFinales,
          horaInicio: _model.horaInicio,
          onChanged: _onFieldChanged,
          getD1FromDatabase: _getD1FromCache,
        );
      case 3:
        return PasoEstadoFinalWidget(
          horaInicio: _model.horaInicio,
          horaFin: _model.horaFin,
          comentarioGeneral: _model.comentarioGeneral,
          recomendacion: _model.recomendacion,
          fechaProxServicio: _model.fechaProxServicio,
          estadoFisico: _model.estadoFisico,
          estadoOperacional: _model.estadoOperacional,
          estadoMetrologico: _model.estadoMetrologico,
          recomendacionesOptions: const [
            'Diagnostico',
            'Mnt Preventivo Regular',
            'Mnt Preventivo Avanzado',
            'Mnt Correctivo',
            'Ajustes Metrológicos',
            'Calibración',
            'Sin recomendación',
          ],
          onComentarioGeneralChanged: (v) {
            _model.comentarioGeneral = v;
            _onFieldChanged();
          },
          onRecomendacionChanged: (v) {
            _model.recomendacion = v;
            _onFieldChanged();
          },
          onFechaProxServicioChanged: (v) {
            _model.fechaProxServicio = v;
            _onFieldChanged();
          },
          onEstadoFisicoChanged: (v) {
            _model.estadoFisico = v;
            _onFieldChanged();
          },
          onEstadoOperacionalChanged: (v) {
            _model.estadoOperacional = v;
            _onFieldChanged();
          },
          onEstadoMetrologicoChanged: (v) {
            _model.estadoMetrologico = v;
            _onFieldChanged();
          },
          onRegistrarHoraFin: () {
            _model.horaFin = DateFormat('HH:mm:ss').format(DateTime.now());
            _onFieldChanged();
          },
        );
      default:
        return const Center(child: Text('Paso no encontrado'));
    }
  }
}
