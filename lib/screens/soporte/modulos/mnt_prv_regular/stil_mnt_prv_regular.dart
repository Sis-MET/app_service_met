import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:service_met/providers/balanza_provider.dart';

import 'models/mnt_prv_regular_model.dart';
import 'controllers/mnt_prv_regular_controller.dart';
import 'package:service_met/screens/soporte/models/campo_estado.dart';
import 'package:service_met/screens/soporte/widgets/shared/paso_entorno_widget.dart';
import 'package:service_met/screens/soporte/widgets/shared/paso_estado_final_widget.dart';
import 'package:service_met/screens/soporte/widgets/soporte_stepper_layout.dart';
import 'package:service_met/screens/soporte/widgets/fin_servicio_screen.dart';
import 'widgets/steps/paso_pruebas_iniciales_finales.dart';
import 'widgets/steps/paso_terminal_balanza_caja.dart';

class StilMntPrvRegularScreen extends StatefulWidget {
  final String sessionId;
  final String secaValue;
  final String nReca;
  final String codMetrica;
  final String userName;
  final String clienteId;
  final String plantaCodigo;

  const StilMntPrvRegularScreen({
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
  State<StilMntPrvRegularScreen> createState() => _StilMntPrvRegularScreenState();
}

class _StilMntPrvRegularScreenState extends State<StilMntPrvRegularScreen> {
  late MntPrvRegularModel _model;
  late MntPrvRegularController _controller;
  int _currentStep = 0;
  bool _isSaving = false;
  DateTime? _lastPressedTime;
  double? _cachedD1;

  final List<SoporteStepData> _steps = [];

  @override
  void initState() {
    super.initState();
    _initializeModel();
    _controller = MntPrvRegularController(model: _model);
    _initializeSteps();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInitialDataAsync());
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
      SoporteStepData(title: 'Pruebas Iniciales', subtitle: 'Excentricidad, Repetibilidad, Linealidad', icon: Icons.science_outlined),
      SoporteStepData(title: 'Entorno', subtitle: '8 campos de inspección', icon: Icons.domain_outlined),
      SoporteStepData(title: 'Terminal', subtitle: '10 campos de inspección', icon: Icons.computer_outlined),
      SoporteStepData(title: 'Balanza', subtitle: '6 campos de inspección', icon: Icons.balance_outlined),
      SoporteStepData(title: 'Caja Sumadora', subtitle: '8 campos de inspección', icon: Icons.electrical_services_outlined),
      SoporteStepData(title: 'Estado Final', subtitle: 'Conclusión del servicio', icon: Icons.assignment_turned_in_outlined),
    ]);
  }

  void _initializeModel() {
    final camposEstado = <String, CampoEstado>{};
    for (final campo in _entornoCampos) {
      camposEstado[campo] = CampoEstado();
    }
    for (final campo in _terminalCampos) {
      camposEstado[campo] = CampoEstado();
    }
    for (final campo in _balanzaCampos) {
      camposEstado[campo] = CampoEstado();
    }
    for (final campo in _cajaSumadoraCampos) {
      camposEstado[campo] = CampoEstado();
    }
    _model = MntPrvRegularModel(
      codMetrica: widget.codMetrica,
      sessionId: widget.sessionId,
      secaValue: widget.secaValue,
      horaInicio: DateFormat('HH:mm').format(DateTime.now()),
      camposEstado: camposEstado,
    );
  }

  static const _entornoCampos = [
    'Vibración', 'Polvo', 'Temperatura', 'Humedad',
    'Mesada', 'Iluminación', 'Limpieza de Fosa', 'Estado de Drenaje',
  ];

  static const _terminalCampos = [
    'Carcasa', 'Teclado Fisico', 'Display Fisico', 'Fuente de poder',
    'Bateria operacional', 'Bracket', 'Teclado Operativo', 'Display Operativo',
    'Contector de celda', 'Bateria de memoria',
  ];

  static const _balanzaCampos = [
    'Limpieza general', 'Golpes al terminal', 'Nivelacion',
    'Limpieza receptor', 'Golpes al receptor de carga', 'Encendido',
  ];

  static const _cajaSumadoraCampos = [
    'Limitador de movimiento', 'Suspensión', 'Limitador de carga', 'Celda de carga',
    'Tapa de caja sumadora', 'Humedad Interna', 'Estado de prensacables', 'Estado de borneas',
  ];

  final _entornoSections = [
    const EntornoSection(
      titulo: 'ENTORNO DE INSTALACIÓN',
      subtitulo: 'Inspeccione las condiciones ambientales y de instalación',
      icono: Icons.domain_outlined,
      color: Colors.blue,
      campos: ['Vibración', 'Polvo', 'Temperatura', 'Humedad', 'Mesada', 'Iluminación', 'Limpieza de Fosa', 'Estado de Drenaje'],
    ),
  ];

  Future<void> _loadD1Value() async {
    try {
      _cachedD1 = await _controller.getD1FromDatabase();
      if (_cachedD1 == null && mounted) {
        final balanza = Provider.of<BalanzaProvider>(context, listen: false).selectedBalanza;
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
      await _controller.saveDataToDatabase(context, showMessage: false);
    } catch (e) {
      _showSnackBar('Error al guardar: ${e.toString()}', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 1:
        for (final campo in _entornoCampos) {
          if (_model.camposEstado[campo]?.initialValue.isEmpty ?? true) {
            _showSnackBar('Por favor complete todos los campos de Entorno', isError: true);
            return false;
          }
        }
        return true;
      case 2:
        for (final campo in _terminalCampos) {
          if (_model.camposEstado[campo]?.initialValue.isEmpty ?? true) {
            _showSnackBar('Por favor complete todos los campos de Terminal', isError: true);
            return false;
          }
        }
        return true;
      case 3:
        for (final campo in _balanzaCampos) {
          if (_model.camposEstado[campo]?.initialValue.isEmpty ?? true) {
            _showSnackBar('Por favor complete todos los campos de Balanza', isError: true);
            return false;
          }
        }
        return true;
      case 4:
        for (final campo in _cajaSumadoraCampos) {
          if (_model.camposEstado[campo]?.initialValue.isEmpty ?? true) {
            _showSnackBar('Por favor complete todos los campos de Caja Sumadora', isError: true);
            return false;
          }
        }
        return true;
      case 5:
        if (_model.comentarioGeneral.isEmpty) {
          _showSnackBar('Por favor complete el Comentario General', isError: true);
          return false;
        }
        if (_model.recomendacion.isEmpty) {
          _showSnackBar('Por favor seleccione una Recomendación', isError: true);
          return false;
        }
        if (_model.fechaProxServicio.isEmpty) {
          _showSnackBar('Por favor seleccione la fecha del próximo servicio', isError: true);
          return false;
        }
        if (_model.estadoFisico.isEmpty || _model.estadoOperacional.isEmpty || _model.estadoMetrologico.isEmpty) {
          _showSnackBar('Por favor complete todos los estados finales', isError: true);
          return false;
        }
        if (_model.horaFin.isEmpty) {
          _showSnackBar('Por favor registre la hora final del servicio', isError: true);
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
    if (_lastPressedTime == null || now.difference(_lastPressedTime!) > const Duration(seconds: 2)) {
      _lastPressedTime = now;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Presione nuevamente para salir. Los datos se guardarán automáticamente.'), duration: Duration(seconds: 2)),
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

  void _onFieldChanged() {
    setState(() {});
    _controller.scheduleAutoSave(context);
  }

  @override
  Widget build(BuildContext context) {
    return SoporteStepperLayout(
      title: 'MNT PRV REGULAR STIL',
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
                  tableName: 'mnt_prv_regular_stil',
                  config: const FinServicioConfig(
                    tableNameDefault: 'mnt_prv_regular_stil',
                    csvSuffix: 'mnt_prv_regular_stil',
                    additionalWhere: "AND estado_servicio = 'Completo'",
                    tipoServicio: 'MNT.SP',
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

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return PasoPruebasIniciales(
          model: _model,
          controller: _controller,
          getD1FromDatabase: _getD1FromCache,
          onChanged: _onFieldChanged,
        );
      case 1:
        return PasoEntornoWidget(
          secciones: _entornoSections,
          camposEstado: _model.camposEstado,
          onChanged: _onFieldChanged,
          onAddPhoto: (label, foto) => _controller.agregarFoto(label, foto),
          onRemovePhoto: _controller.eliminarFoto,
        );
      case 2:
        return PasoTerminal(
          camposEstado: _model.camposEstado,
          onChanged: _onFieldChanged,
          onAddPhoto: _controller.agregarFoto,
          onRemovePhoto: _controller.eliminarFoto,
        );
      case 3:
        return PasoBalanza(
          camposEstado: _model.camposEstado,
          onChanged: _onFieldChanged,
          onAddPhoto: _controller.agregarFoto,
          onRemovePhoto: _controller.eliminarFoto,
        );
      case 4:
        return PasoCajaSumadora(
          camposEstado: _model.camposEstado,
          onChanged: _onFieldChanged,
          onAddPhoto: _controller.agregarFoto,
          onRemovePhoto: _controller.eliminarFoto,
        );
      case 5:
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
            'Diagnostico', 'Mnt Preventivo Regular', 'Mnt Preventivo Avanzado',
            'Mnt Correctivo', 'Ajustes Metrológicos', 'Calibración', 'Sin recomendación',
          ],
          onComentarioGeneralChanged: (v) { _model.comentarioGeneral = v; _onFieldChanged(); },
          onRecomendacionChanged: (v) { _model.recomendacion = v; _onFieldChanged(); },
          onFechaProxServicioChanged: (v) { _model.fechaProxServicio = v; _onFieldChanged(); },
          onEstadoFisicoChanged: (v) { _model.estadoFisico = v; _onFieldChanged(); },
          onEstadoOperacionalChanged: (v) { _model.estadoOperacional = v; _onFieldChanged(); },
          onEstadoMetrologicoChanged: (v) { _model.estadoMetrologico = v; _onFieldChanged(); },
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
