import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:service_met/providers/balanza_provider.dart';

import 'models/mnt_prv_avanzado_model.dart';
import 'controllers/mnt_prv_avanzado_controller.dart';
import 'package:service_met/screens/soporte/models/campo_estado.dart';
import 'package:service_met/screens/soporte/widgets/shared/paso_generico_widget.dart';
import 'package:service_met/screens/soporte/widgets/shared/paso_estado_final_widget.dart';
import 'package:service_met/screens/soporte/widgets/soporte_stepper_layout.dart';
import 'mnt_prv_avanzado_stac/fin_servicio_stac.dart';
import 'widgets/steps/paso_pruebas_iniciales_finales.dart';

class StacMntPrvAvanzadoScreen extends StatefulWidget {
  final String sessionId;
  final String secaValue;
  final String nReca;
  final String codMetrica;
  final String userName;
  final String clienteId;
  final String plantaCodigo;

  const StacMntPrvAvanzadoScreen({
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
  State<StacMntPrvAvanzadoScreen> createState() => _StacMntPrvAvanzadoScreenState();
}

class _StacMntPrvAvanzadoScreenState extends State<StacMntPrvAvanzadoScreen> {
  late MntPrvAvanzadoModel _model;
  late MntPrvAvanzadoController _controller;
  int _currentStep = 0;
  bool _isSaving = false;
  DateTime? _lastPressedTime;
  double? _cachedD1;

  static const _lozasCampos = [
    'Losas de aproximación (daños o grietas)',
    'Fundaciones (daños o grietas)',
  ];

  static const _limpiezaCampos = [
    'Limpieza de perímetro de balanza',
    'Fosa libre de humedad',
    'Drenaje libre',
    'Bomba de sumidero funcional',
  ];

  static const _chequeoCampos = [
    'Corrosión',
    'Puente de pesaje (grietas)',
    'Tapas superiores y pernos',
    'Desgaste y estrés',
    'Limpieza por debajo del puente',
    'Estado rieles laterales',
    'Limitadores Longitudinales',
    'Limitadores Transversales',
  ];

  static const _electricasCampos = [
    'Cable home run',
    'Cables de celdas de carga',
    'Conexión entre celda de carga y cable',
    'Conectores de celdas de carga',
    'Conector de terminación',
    'Caja de unión o Sumadora',
  ];

  final List<SoporteStepData> _steps = [];

  @override
  void initState() {
    super.initState();
    _initializeModel();
    _controller = MntPrvAvanzadoController(model: _model);
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
      SoporteStepData(title: 'Lozas', subtitle: '2 campos de inspección', icon: Icons.foundation_outlined),
      SoporteStepData(title: 'Limpieza', subtitle: '4 campos de inspección', icon: Icons.cleaning_services_outlined),
      SoporteStepData(title: 'Chequeo', subtitle: '8 campos de inspección', icon: Icons.checklist_outlined),
      SoporteStepData(title: 'Eléctricas', subtitle: '6 campos de inspección', icon: Icons.electrical_services_outlined),
      SoporteStepData(title: 'Pruebas Finales', subtitle: 'Verificación final', icon: Icons.task_alt_outlined),
      SoporteStepData(title: 'Estado Final', subtitle: 'Conclusión del servicio', icon: Icons.assignment_turned_in_outlined),
    ]);
  }

  void _initializeModel() {
    final camposEstado = <String, CampoEstado>{};
    for (final campo in [..._lozasCampos, ..._limpiezaCampos, ..._chequeoCampos, ..._electricasCampos]) {
      camposEstado[campo] = CampoEstado();
    }
    _model = MntPrvAvanzadoModel(
      codMetrica: widget.codMetrica,
      sessionId: widget.sessionId,
      secaValue: widget.secaValue,
      horaInicio: DateFormat('HH:mm').format(DateTime.now()),
      camposEstado: camposEstado,
    );
  }

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
        for (final campo in _lozasCampos) {
          if (_model.camposEstado[campo]?.initialValue.isEmpty ?? true) {
            _showSnackBar('Por favor complete todos los campos de Lozas', isError: true);
            return false;
          }
        }
        return true;
      case 2:
        for (final campo in _limpiezaCampos) {
          if (_model.camposEstado[campo]?.initialValue.isEmpty ?? true) {
            _showSnackBar('Por favor complete todos los campos de Limpieza', isError: true);
            return false;
          }
        }
        return true;
      case 3:
        for (final campo in _chequeoCampos) {
          if (_model.camposEstado[campo]?.initialValue.isEmpty ?? true) {
            _showSnackBar('Por favor complete todos los campos de Chequeo', isError: true);
            return false;
          }
        }
        return true;
      case 4:
        for (final campo in _electricasCampos) {
          if (_model.camposEstado[campo]?.initialValue.isEmpty ?? true) {
            _showSnackBar('Por favor complete todos los campos Eléctricos', isError: true);
            return false;
          }
        }
        return true;
      case 6:
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
      title: 'MNT PRV AVANZADO STAC',
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
                builder: (context) => FinServicioMntAvaStacScreen(
                  sessionId: widget.sessionId,
                  secaValue: widget.secaValue,
                  codMetrica: widget.codMetrica,
                  nReca: widget.nReca,
                  userName: widget.userName,
                  clienteId: widget.clienteId,
                  plantaCodigo: widget.plantaCodigo,
                  tableName: 'mnt_prv_avanzado_stac',
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
        return PasoGenericoWidget(
          campos: _lozasCampos,
          camposEstado: _model.camposEstado,
          onChanged: _onFieldChanged,
          onAddPhoto: _controller.agregarFoto,
          onRemovePhoto: _controller.eliminarFoto,
          titulo: 'LOZAS Y FUNDACIONES',
          subtitulo: 'Inspeccione el estado de lozas y fundaciones',
          icono: Icons.foundation_outlined,
          color: Colors.brown,
        );
      case 2:
        return PasoGenericoWidget(
          campos: _limpiezaCampos,
          camposEstado: _model.camposEstado,
          onChanged: _onFieldChanged,
          onAddPhoto: _controller.agregarFoto,
          onRemovePhoto: _controller.eliminarFoto,
          titulo: 'LIMPIEZA Y DRENAJE',
          subtitulo: 'Inspeccione limpieza y sistema de drenaje',
          icono: Icons.cleaning_services_outlined,
          color: Colors.lightBlue,
        );
      case 3:
        return PasoGenericoWidget(
          campos: _chequeoCampos,
          camposEstado: _model.camposEstado,
          onChanged: _onFieldChanged,
          onAddPhoto: _controller.agregarFoto,
          onRemovePhoto: _controller.eliminarFoto,
          titulo: 'CHEQUEO GENERAL',
          subtitulo: 'Inspeccione el estado general del equipo',
          icono: Icons.checklist_outlined,
          color: Colors.teal,
        );
      case 4:
        return PasoGenericoWidget(
          campos: _electricasCampos,
          camposEstado: _model.camposEstado,
          onChanged: _onFieldChanged,
          onAddPhoto: _controller.agregarFoto,
          onRemovePhoto: _controller.eliminarFoto,
          titulo: 'VERIFICACIONES ELÉCTRICAS',
          subtitulo: 'Inspeccione conexiones y cableado',
          icono: Icons.electrical_services_outlined,
          color: Colors.amber,
        );
      case 5:
        return PasoPruebasFinales(
          model: _model,
          controller: _controller,
          getD1FromDatabase: _getD1FromCache,
          onChanged: _onFieldChanged,
        );
      case 6:
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
