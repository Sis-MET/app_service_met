// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:service_met/providers/balanza_provider.dart';
import 'package:service_met/screens/soporte/modulos/mnt_prv_regular/mnt_prv_regular_stil/fin_servicio_stil.dart';
import 'package:service_met/screens/soporte/modulos/mnt_prv_regular/mnt_prv_regular_stil/widgets/steps/paso_entorno.dart';
import 'package:service_met/screens/soporte/modulos/mnt_prv_regular/mnt_prv_regular_stil/widgets/steps/paso_estado_final.dart';
import 'package:service_met/screens/soporte/modulos/mnt_prv_regular/mnt_prv_regular_stil/widgets/steps/paso_pruebas_iniciales_finales.dart';
import 'package:service_met/screens/soporte/modulos/mnt_prv_regular/mnt_prv_regular_stil/widgets/steps/paso_terminal_balanza_caja.dart';
import 'controllers/mnt_prv_regular_stil_controller.dart';
import 'models/mnt_prv_regular_stil_model.dart';
import 'package:service_met/screens/soporte/widgets/soporte_stepper_layout.dart';

class StilMntPrvRegularStacScreen extends StatefulWidget {
  final String sessionId;
  final String secaValue;
  final String nReca;
  final String codMetrica;
  final String userName;
  final String clienteId;
  final String plantaCodigo;

  const StilMntPrvRegularStacScreen({
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
  _StilMntPrvRegularStacScreenState createState() =>
      _StilMntPrvRegularStacScreenState();
}

class _StilMntPrvRegularStacScreenState
    extends State<StilMntPrvRegularStacScreen> {
  late MntPrvRegularStilModel _model;
  late MntPrvRegularStilController _controller;

  int _currentStep = 0;
  bool _isSaving = false;
  bool _dataLoaded = false; // Flag para forzar reconstrucción de widgets de pruebas
  DateTime? _lastPressedTime;
  double? _cachedD1; //  Cachear d1 para evitar múltiples consultas

  //  Definición de pasos
  final List<SoporteStepData> _steps = [];

  @override
  void initState() {
    super.initState();
    _initializeModel();
    _controller = MntPrvRegularStilController(model: _model);
    _actualizarHora();
    _loadD1Value();
    _initializeSteps();
    _loadInitialDataAsync();
  }

  Future<void> _loadInitialDataAsync() async {
    await _controller.loadInitialValues();
    if (mounted) {
      setState(() {
        _dataLoaded = true; // Fuerza reconstrucción de widgets con initialValue
      });
    }
  }

  void _initializeSteps() {
    _steps.addAll([
      SoporteStepData(
        title: 'Pruebas Iniciales',
        subtitle: 'Excentricidad, Repetibilidad, Linealidad',
        icon: Icons.science_outlined,
      ),
      SoporteStepData(
        title: 'Entorno de Instalación',
        subtitle: '8 campos de inspección',
        icon: Icons.domain_outlined,
      ),
      SoporteStepData(
        title: 'Terminal de Pesaje',
        subtitle: '10 campos de inspección',
        icon: Icons.computer_outlined,
      ),
      SoporteStepData(
        title: 'Estado de Balanza',
        subtitle: '6 campos de inspección',
        icon: Icons.balance_outlined,
      ),
      SoporteStepData(
        title: 'Caja Sumadora',
        subtitle: '4 campos de inspección',
        icon: Icons.electrical_services_outlined,
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

  void _initializeModel() {
    final camposEstado = {
      // Entorno de instalación
      'Vibración': CampoEstado(),
      'Polvo': CampoEstado(),
      'Temperatura': CampoEstado(),
      'Humedad': CampoEstado(),
      'Mesada': CampoEstado(),
      'Iluminación': CampoEstado(),
      'Limpieza de Fosa': CampoEstado(),
      'Estado de Drenaje': CampoEstado(),

      // Terminal de pesaje
      'Carcasa': CampoEstado(),
      'Teclado Fisico': CampoEstado(),
      'Display Fisico': CampoEstado(),
      'Fuente de poder': CampoEstado(),
      'Bateria operacional': CampoEstado(),
      'Bracket': CampoEstado(),
      'Teclado Operativo': CampoEstado(),
      'Display Operativo': CampoEstado(),
      'Contector de celda': CampoEstado(),
      'Bateria de memoria': CampoEstado(),

      // Estado general de la balanza
      'Limpieza general': CampoEstado(),
      'Golpes al terminal': CampoEstado(),
      'Nivelacion': CampoEstado(),
      'Limpieza receptor': CampoEstado(),
      'Golpes al receptor de carga': CampoEstado(),
      'Encendido': CampoEstado(),

      // Balanza/Plataforma
      'Limitador de movimiento': CampoEstado(),
      'Suspensión': CampoEstado(),
      'Limitador de carga': CampoEstado(),
      'Celda de carga': CampoEstado(),

      // Caja sumadora
      'Tapa de caja sumadora': CampoEstado(),
      'Humedad Interna': CampoEstado(),
      'Estado de prensacables': CampoEstado(),
      'Estado de borneas': CampoEstado(),
    };

    _model = MntPrvRegularStilModel(
      codMetrica: widget.codMetrica,
      sessionId: widget.sessionId,
      secaValue: widget.secaValue,
      camposEstado: camposEstado,
      pruebasIniciales: PruebasMetrologicas(),
      pruebasFinales: PruebasMetrologicas(),
    );
  }

  void _actualizarHora() {
    final ahora = DateTime.now();
    final horaFormateada = DateFormat('HH:mm:ss').format(ahora);
    _model.horaInicio = horaFormateada;
  }

  //  Cargar d1 una sola vez
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
    setState(() {});
  }

  Future<double> _getD1FromCache() async {
    return _cachedD1 ?? 0.1;
  }

  //  Guardar automáticamente al cambiar de paso o interceptar datos
  void _onFieldChanged() {
    setState(() {});
    _controller.scheduleAutoSave(context);
  }

  Future<void> _saveCurrentStep() async {
    if (_isSaving) return;

    setState(() => _isSaving = true);

    try {
      await _controller.flushAutoSave(context);
      debugPrint(' Paso $_currentStep guardado forzosamente');
    } catch (e) {
      debugPrint(' Error al guardar paso $_currentStep: $e');
      _showSnackBar('Error al guardar: ${e.toString()}', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  //  Validar paso actual antes de avanzar
  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0: // Pruebas Iniciales
        // Validar que si hay pruebas activadas, estén completas
        return true; // Por ahora permitir continuar

      case 1: // Entorno
      case 2: // Terminal
      case 3: // Balanza
      case 4: // Caja sumadora
        // Auto-completar los campos que el usuario no tocó con el valor visual por defecto
        final camposDelPaso = _getCamposDelPaso(_currentStep);
        for (var campo in camposDelPaso) {
          if (_model.camposEstado[campo]?.initialValue.isEmpty ?? true) {
            _model.camposEstado[campo]!.initialValue = '4 No aplica';
            _model.camposEstado[campo]!.solutionValue = 'No aplica';
            if (_model.camposEstado[campo]!.comentario.isEmpty) {
              _model.camposEstado[campo]!.comentario = 'Sin comentario';
            }
          }
        }
        return true;

      case 5: // Pruebas Finales
        return true;

      case 6: // Estado Final
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

  List<String> _getCamposDelPaso(int paso) {
    switch (paso) {
      case 1: // Entorno
        return [
          'Vibración',
          'Polvo',
          'Temperatura',
          'Humedad',
          'Mesada',
          'Iluminación',
          'Limpieza de Fosa',
          'Estado de Drenaje'
        ];
      case 2: // Terminal
        return [
          'Carcasa',
          'Teclado Fisico',
          'Display Fisico',
          'Fuente de poder',
          'Bateria operacional',
          'Bracket',
          'Teclado Operativo',
          'Display Operativo',
          'Contector de celda',
          'Bateria de memoria'
        ];
      case 3: // Balanza
        return [
          'Limpieza general',
          'Golpes al terminal',
          'Nivelacion',
          'Limpieza receptor',
          'Golpes al receptor de carga',
          'Encendido'
        ];
      case 4: // Caja sumadora
        return [
          'Limitador de movimiento',
          'Suspensión',
          'Limitador de carga',
          'Celda de carga',
          'Tapa de caja sumadora',
          'Humedad Interna',
          'Estado de prensacables',
          'Estado de borneas'
        ];
      default:
        return [];
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
          // Último paso: finalizar
          if (_validateCurrentStep()) {
            await _saveCurrentStep();

            if (!mounted) return;

            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    FinServicioMntPrvStilScreen(
                  sessionId: widget.sessionId,
                  secaValue: widget.secaValue,
                  codMetrica: widget.codMetrica,
                  nReca: widget.nReca,
                  userName: widget.userName,
                  clienteId: widget.clienteId,
                  plantaCodigo: widget.plantaCodigo,
                  tableName: 'mnt_prv_regular_stil',
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
          key: ValueKey('pruebas_ini_$_dataLoaded'),
          model: _model,
          controller: _controller,
          getIndicationSuggestions: _controller.getIndicationSuggestions,
          getD1FromDatabase: _getD1FromCache,
          onChanged: _onFieldChanged,
        );
      case 1:
        return PasoEntorno(
          model: _model,
          controller: _controller,
          onChanged: _onFieldChanged,
        );
      case 2:
        return PasoTerminal(
          model: _model,
          controller: _controller,
          onChanged: _onFieldChanged,
        );
      case 3:
        return PasoBalanza(
          model: _model,
          controller: _controller,
          onChanged: _onFieldChanged,
        );
      case 4:
        return PasoCajaSumadora(
          model: _model,
          controller: _controller,
          onChanged: _onFieldChanged,
        );
      case 5:
        return PasoPruebasFinales(
          key: ValueKey('pruebas_fin_$_dataLoaded'),
          model: _model,
          controller: _controller,
          getIndicationSuggestions: _controller.getIndicationSuggestions,
          getD1FromDatabase: _getD1FromCache,
          onChanged: _onFieldChanged,
        );
      case 6:
        return PasoEstadoFinal(
          model: _model,
          onChanged: _onFieldChanged,
        );
      default:
        return const Center(child: Text('Paso no encontrado'));
    }
  }
}
