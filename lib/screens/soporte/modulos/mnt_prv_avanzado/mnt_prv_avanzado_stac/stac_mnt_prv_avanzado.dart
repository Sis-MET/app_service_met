// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:service_met/provider/balanza_provider.dart';
import 'package:service_met/screens/soporte/modulos/mnt_prv_avanzado/mnt_prv_avanzado_stac/models/mnt_prv_avanzado_stac_model.dart';
import 'package:service_met/screens/soporte/modulos/mnt_prv_avanzado/mnt_prv_avanzado_stac/utils/constants.dart';
import 'package:service_met/screens/soporte/modulos/mnt_prv_avanzado/mnt_prv_avanzado_stac/widgets/steps/paso_estado_final.dart';
import 'package:service_met/screens/soporte/modulos/mnt_prv_avanzado/mnt_prv_avanzado_stac/widgets/steps/paso_generico.dart';
import 'package:service_met/screens/soporte/modulos/mnt_prv_avanzado/mnt_prv_avanzado_stac/widgets/steps/paso_pruebas_iniciales_finales.dart';
import 'controllers/mnt_prv_avanzado_stac_controller.dart';
import 'fin_servicio_stac.dart';
import 'package:service_met/screens/soporte/widgets/soporte_stepper_layout.dart';

class StacMntPrvAvanzadoStacScreen extends StatefulWidget {
  final String sessionId;
  final String secaValue;
  final String nReca;
  final String codMetrica;
  final String userName;
  final String clienteId;
  final String plantaCodigo;

  const StacMntPrvAvanzadoStacScreen({
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
  _StacMntPrvAvanzadoStacScreenState createState() =>
      _StacMntPrvAvanzadoStacScreenState();
}

class _StacMntPrvAvanzadoStacScreenState
    extends State<StacMntPrvAvanzadoStacScreen> {
  late MntPrvAvanzadoStacModel _model;
  late MntPrvAvanzadoStacController _controller;

  int _currentStep = 0;
  bool _isSaving = false;
  bool _dataLoaded = false; // Flag para forzar reconstrucción de widgets de pruebas
  DateTime? _lastPressedTime;
  double? _cachedD1; // Cachear d1 para evitar múltiples consultas

  // Definición de pasos
  final List<SoporteStepData> _steps = [];

  @override
  void initState() {
    super.initState();
    _initializeModel();
    _controller = MntPrvAvanzadoStacController(model: _model);
    _actualizarHora();
    _loadD1Value();
    _initializeSteps();
    _loadInitialDataAsync();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
        title: 'Lozas y Fundaciones',
        subtitle: '2 campos de inspección',
        icon: Icons.foundation_outlined,
      ),
      SoporteStepData(
        title: 'Limpieza y Drenaje',
        subtitle: '4 campos de inspección',
        icon: Icons.cleaning_services_outlined,
      ),
      SoporteStepData(
        title: 'Chequeo General',
        subtitle: '8 campos de inspección',
        icon: Icons.checklist_outlined,
      ),
      SoporteStepData(
        title: 'Verificaciones Eléctricas',
        subtitle: '8 campos de inspección',
        icon: Icons.electrical_services_outlined,
      ),
      SoporteStepData(
        title: 'Protección contra Rayos',
        subtitle: '4 campos de inspección',
        icon: Icons.flash_on_outlined,
      ),
      SoporteStepData(
        title: 'Verificaciones de Células',
        subtitle: '7 campos de inspección',
        icon: Icons.grain_outlined, // Ícono de célula/componente
      ),
      SoporteStepData(
        title: 'Terminal',
        subtitle: '8 campos de inspección',
        icon: Icons.computer_outlined,
      ),
      SoporteStepData(
        title: 'Calibración',
        subtitle: '1 campo de inspección',
        icon: Icons.tune_outlined,
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
    final camposEstado = <String, CampoEstadoAvanzadoStac>{};

    //Inicializar TODOS los campos usando la lista de constants
    for (final campo in AppStacAvanzadoConstants.getAllCampos()) {
      camposEstado[campo] = CampoEstadoAvanzadoStac();
    }

    _model = MntPrvAvanzadoStacModel(
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

  // Cargar d1 una sola vez
  Future<void> _loadD1Value() async {
    try {
      // Intentar obtener de BD (ahora retorna nullable)
      _cachedD1 = await _controller.getD1FromDatabase();

      // Si es null, buscar en Provider
      if (_cachedD1 == null) {
        final balanza = Provider.of<BalanzaProvider>(context, listen: false)
            .selectedBalanza;
        _cachedD1 = balanza?.d1 ?? 0.1;
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

  // Guardar automáticamente al cambiar de paso o interceptar datos
  void _onFieldChanged() {
    setState(() {});
    _controller.scheduleAutoSave(context);
  }

  Future<void> _saveCurrentStep() async {
    if (_isSaving) return;

    setState(() => _isSaving = true);

    try {
      await _controller.flushAutoSave(context);
      debugPrint('Paso $_currentStep guardado forzosamente');
    } catch (e) {
      debugPrint('Error al guardar paso $_currentStep: $e');
      _showSnackBar('Error al guardar: ${e.toString()}', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // Validar paso actual antes de avanzar
  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0: // Pruebas Iniciales
        // Validar que si hay pruebas activadas, estén completas
        return true; // Por ahora permitir continuar

      case 1: // Entorno
      case 2: // Terminal
      case 3: // Balanza
      case 4: // Caja sumadora
        // Verificar que todos los campos tengan estado seleccionado
        final camposDelPaso = _getCamposDelPaso(_currentStep);
        for (var campo in camposDelPaso) {
          if (_model.camposEstado[campo]?.initialValue == null ||
              _model.camposEstado[campo]!.initialValue.isEmpty) {
            _showSnackBar(
              'Por favor complete todos los campos del estado en: $campo',
              isError: true,
            );
            return false;
          }
        }
        return true;

      case 5: // Pruebas Finales
        return true;

      case 10: // Estado Final
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
      case 1:
        return AppStacAvanzadoConstants.lozasYFundacionesCampos;
      case 2:
        return AppStacAvanzadoConstants.limpiezaYDrenajeCampos;
      case 3:
        return AppStacAvanzadoConstants.chequeoCampos;
      case 4:
        return AppStacAvanzadoConstants.verificacionesElectricasCampos;
      case 5:
        return AppStacAvanzadoConstants.proteccionRayosCampos;
      case 6:
        return AppStacAvanzadoConstants.verificacionesCeldasCampos;
      case 7:
        return AppStacAvanzadoConstants.terminalCampos;
      case 8:
        return AppStacAvanzadoConstants.calibracionCampos;
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
          // Último paso: finalizar
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
          key: ValueKey('pruebas_ini_$_dataLoaded'),
          model: _model,
          controller: _controller,
          getD1FromDatabase: _getD1FromCache,
          onChanged: _onFieldChanged,
        );
      case 1:
        return PasoGenerico(
          model: _model,
          controller: _controller,
          onChanged: _onFieldChanged,
          campos: AppStacAvanzadoConstants.lozasYFundacionesCampos,
          titulo: 'LOZAS Y FUNDACIONES',
          subtitulo: 'Inspeccione el estado de lozas y fundaciones',
          icono: Icons.foundation_outlined,
          color: Colors.brown,
        );
      case 2:
        return PasoGenerico(
          model: _model,
          controller: _controller,
          onChanged: _onFieldChanged,
          campos: AppStacAvanzadoConstants.limpiezaYDrenajeCampos,
          titulo: 'LIMPIEZA Y DRENAJE',
          subtitulo: 'Inspeccione limpieza y sistema de drenaje',
          icono: Icons.cleaning_services_outlined,
          color: Colors.lightBlue,
        );
      case 3:
        return PasoGenerico(
          model: _model,
          controller: _controller,
          onChanged: _onFieldChanged,
          campos: AppStacAvanzadoConstants.chequeoCampos,
          titulo: 'CHEQUEO GENERAL',
          subtitulo: 'Inspeccione el estado general del equipo',
          icono: Icons.checklist_outlined,
          color: Colors.teal,
        );
      case 4:
        return PasoGenerico(
          model: _model,
          controller: _controller,
          onChanged: _onFieldChanged,
          campos: AppStacAvanzadoConstants.verificacionesElectricasCampos,
          titulo: 'VERIFICACIONES ELÉCTRICAS',
          subtitulo: 'Inspeccione conexiones y cableado',
          icono: Icons.electrical_services_outlined,
          color: Colors.amber,
        );
      case 5:
        return PasoGenerico(
          model: _model,
          controller: _controller,
          onChanged: _onFieldChanged,
          campos: AppStacAvanzadoConstants.proteccionRayosCampos,
          titulo: 'PROTECCIÓN CONTRA RAYOS',
          subtitulo: 'Verifique sistema de protección eléctrica',
          icono: Icons.flash_on_outlined,
          color: Colors.orange,
        );
      case 6:
        return PasoGenerico(
          model: _model,
          controller: _controller,
          onChanged: _onFieldChanged,
          campos: AppStacAvanzadoConstants.verificacionesCeldasCampos,
          titulo: 'VERIFICACIONES DE CÉLULAS DE CARGA',
          subtitulo: 'Inspeccione células y componentes de pesaje',
          icono: Icons.grain_outlined,
          color: Colors.indigo,
        );
      case 7:
        return PasoGenerico(
          model: _model,
          controller: _controller,
          onChanged: _onFieldChanged,
          campos: AppStacAvanzadoConstants.terminalCampos,
          titulo: 'TERMINAL',
          subtitulo: 'Inspeccione el terminal de pesaje',
          icono: Icons.computer_outlined,
          color: Colors.purple,
        );
      case 8:
        return PasoGenerico(
          model: _model,
          controller: _controller,
          onChanged: _onFieldChanged,
          campos: AppStacAvanzadoConstants.calibracionCampos,
          titulo: 'CALIBRACIÓN',
          subtitulo: 'Verifique la calibración',
          icono: Icons.tune_outlined,
          color: Colors.green,
        );
      case 9:
        return PasoPruebasFinales(
          key: ValueKey('pruebas_fin_$_dataLoaded'),
          model: _model,
          controller: _controller,
          getD1FromDatabase: _getD1FromCache,
          onChanged: () => setState(() {}),
        );
      case 10:
        return PasoEstadoFinal(
          model: _model,
          onChanged: () => setState(() {}),
        );
      default:
        return const Center(child: Text('Paso no encontrado'));
    }
  }
}
