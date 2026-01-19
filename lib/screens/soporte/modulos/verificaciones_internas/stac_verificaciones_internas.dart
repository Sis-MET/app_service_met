// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously, deprecated_member_use

import 'dart:ui';
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
import 'widgets/steps/paso_pruebas_finales.dart';
import 'widgets/steps/paso_estado_final.dart';
import 'widgets/steps/paso_generico.dart';

// Pantalla final
import 'fin_servicio_vinternas.dart';

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

  final List<StepData> _steps = [];

  @override
  void initState() {
    super.initState();
    _initializeModel();
    _controller = VerificacionesInternasController(model: _model);
    _actualizarHora();
    _loadD1Value();
    _initializeSteps();
  }

  void _initializeSteps() {
    _steps.addAll([
      StepData(
        title: 'Pruebas Iniciales',
        subtitle: 'Excentricidad, Repetibilidad, Linealidad',
        icon: Icons.science_outlined,
      ),
      StepData(
        title: 'Lozas y Fundaciones',
        subtitle: '2 campos de inspección',
        icon: Icons.foundation_outlined,
      ),
      StepData(
        title: 'Limpieza y Drenaje',
        subtitle: '4 campos de inspección',
        icon: Icons.cleaning_services_outlined,
      ),
      StepData(
        title: 'Chequeo General',
        subtitle: '8 campos de inspección',
        icon: Icons.checklist_outlined,
      ),
      StepData(
        title: 'Verificaciones Eléctricas',
        subtitle: '8 campos de inspección',
        icon: Icons.electrical_services_outlined,
      ),
      StepData(
        title: 'Protección contra Rayos',
        subtitle: '4 campos de inspección',
        icon: Icons.flash_on_outlined,
      ),
      StepData(
        title: 'Verificaciones de Células',
        subtitle: '7 campos de inspección',
        icon: Icons.grain_outlined,
      ),
      StepData(
        title: 'Terminal',
        subtitle: '8 campos de inspección',
        icon: Icons.computer_outlined,
      ),
      StepData(
        title: 'Calibración',
        subtitle: '1 campo de inspección',
        icon: Icons.tune_outlined,
      ),
      StepData(
        title: 'Pruebas Finales',
        subtitle: 'Verificación post-mantenimiento',
        icon: Icons.task_alt_outlined,
      ),
      StepData(
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
      case 0: // Pruebas Iniciales
        return true;

      case 1: // Lozas
      case 2: // Limpieza
      case 3: // Chequeo
      case 4: // Electricas
      case 5: // Rayos
      case 6: // Celulas
      case 7: // Terminal
      case 8: // Calibracion
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

      case 9: // Pruebas Finales
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
        return AppVerificacionesInternasConstants.lozasYFundacionesCampos;
      case 2:
        return AppVerificacionesInternasConstants.limpiezaYDrenajeCampos;
      case 3:
        return AppVerificacionesInternasConstants.chequeoCampos;
      case 4:
        return AppVerificacionesInternasConstants
            .verificacionesElectricasCampos;
      case 5:
        return AppVerificacionesInternasConstants.proteccionRayosCampos;
      case 6:
        return AppVerificacionesInternasConstants.verificacionesCeldasCampos;
      case 7:
        return AppVerificacionesInternasConstants.terminalCampos;
      case 8:
        return AppVerificacionesInternasConstants.calibracionCampos;
      default:
        return [];
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 80,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'VERIFICACIONES INTERNAS',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'CÓDIGO MET: ${widget.codMetrica}',
                style: TextStyle(
                  fontSize: 10,
                  color: isDarkMode ? Colors.white70 : Colors.black54,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          backgroundColor: isDarkMode ? Colors.transparent : Colors.white,
          elevation: 0,
          flexibleSpace: isDarkMode
              ? ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                    child: Container(color: Colors.black.withOpacity(0.1)),
                  ),
                )
              : null,
          centerTitle: true,
          actions: [
            if (_isSaving)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
          ],
        ),
        body: Column(
          children: [
            _buildProgressBar(isDarkMode),
            Expanded(
              child: _buildStepContent(),
            ),
            _buildNavigationButtons(isDarkMode),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.black26 : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                _steps[_currentStep].icon,
                color: Theme.of(context).primaryColor,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Paso ${_currentStep + 1} de ${_steps.length}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDarkMode ? Colors.white70 : Colors.black54,
                      ),
                    ),
                    Text(
                      _steps[_currentStep].title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _steps[_currentStep].subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDarkMode ? Colors.white60 : Colors.black45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: List.generate(_steps.length, (index) {
              final isCompleted = index < _currentStep;
              final isCurrent = index == _currentStep;

              return Expanded(
                child: Container(
                  height: 4,
                  margin: EdgeInsets.only(
                    left: index == 0 ? 0 : 4,
                    right: index == _steps.length - 1 ? 0 : 4,
                  ),
                  decoration: BoxDecoration(
                    color: isCompleted || isCurrent
                        ? Theme.of(context).primaryColor
                        : Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return PasoPruebasIniciales(
          model: _model,
          controller: _controller,
          getD1FromDatabase: _getD1FromCache,
          onChanged: () => setState(() {}),
        );
      case 1:
        return PasoGenerico(
          model: _model,
          controller: _controller,
          onChanged: () => setState(() {}),
          campos: AppVerificacionesInternasConstants.lozasYFundacionesCampos,
          titulo: 'LOZAS Y FUNDACIONES',
          subtitulo: 'Inspeccione el estado de lozas y fundaciones',
          icono: Icons.foundation_outlined,
          color: Colors.brown,
        );
      case 2:
        return PasoGenerico(
          model: _model,
          controller: _controller,
          onChanged: () => setState(() {}),
          campos: AppVerificacionesInternasConstants.limpiezaYDrenajeCampos,
          titulo: 'LIMPIEZA Y DRENAJE',
          subtitulo: 'Inspeccione limpieza y sistema de drenaje',
          icono: Icons.cleaning_services_outlined,
          color: Colors.lightBlue,
        );
      case 3:
        return PasoGenerico(
          model: _model,
          controller: _controller,
          onChanged: () => setState(() {}),
          campos: AppVerificacionesInternasConstants.chequeoCampos,
          titulo: 'CHEQUEO GENERAL',
          subtitulo: 'Inspeccione el estado general del equipo',
          icono: Icons.checklist_outlined,
          color: Colors.teal,
        );
      case 4:
        return PasoGenerico(
          model: _model,
          controller: _controller,
          onChanged: () => setState(() {}),
          campos:
              AppVerificacionesInternasConstants.verificacionesElectricasCampos,
          titulo: 'VERIFICACIONES ELÉCTRICAS',
          subtitulo: 'Inspeccione conexiones y cableado',
          icono: Icons.electrical_services_outlined,
          color: Colors.amber,
        );
      case 5:
        return PasoGenerico(
          model: _model,
          controller: _controller,
          onChanged: () => setState(() {}),
          campos: AppVerificacionesInternasConstants.proteccionRayosCampos,
          titulo: 'PROTECCIÓN CONTRA RAYOS',
          subtitulo: 'Verifique sistema de protección eléctrica',
          icono: Icons.flash_on_outlined,
          color: Colors.orange,
        );
      case 6:
        return PasoGenerico(
          model: _model,
          controller: _controller,
          onChanged: () => setState(() {}),
          campos: AppVerificacionesInternasConstants.verificacionesCeldasCampos,
          titulo: 'VERIFICACIONES DE CÉLULAS DE CARGA',
          subtitulo: 'Inspeccione células y componentes de pesaje',
          icono: Icons.grain_outlined,
          color: Colors.indigo,
        );
      case 7:
        return PasoGenerico(
          model: _model,
          controller: _controller,
          onChanged: () => setState(() {}),
          campos: AppVerificacionesInternasConstants.terminalCampos,
          titulo: 'TERMINAL',
          subtitulo: 'Inspeccione el terminal de pesaje',
          icono: Icons.computer_outlined,
          color: Colors.purple,
        );
      case 8:
        return PasoGenerico(
          model: _model,
          controller: _controller,
          onChanged: () => setState(() {}),
          campos: AppVerificacionesInternasConstants.calibracionCampos,
          titulo: 'CALIBRACIÓN',
          subtitulo: 'Verifique la calibración',
          icono: Icons.tune_outlined,
          color: Colors.green,
        );
      case 9:
        return PasoPruebasFinales(
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

  Widget _buildNavigationButtons(bool isDarkMode) {
    bool isLastStep = _currentStep == _steps.length - 1;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.black26 : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _goToStep(_currentStep - 1),
                icon: const Icon(Icons.arrow_back),
                label: const Text('ANTERIOR'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 12),
          Expanded(
            flex: _currentStep == 0 ? 1 : 2,
            child: ElevatedButton.icon(
              onPressed: _isSaving
                  ? null
                  : () async {
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
              icon: Icon(
                isLastStep ? Icons.check_circle : Icons.arrow_forward,
              ),
              label: Text(
                isLastStep ? 'FINALIZAR' : 'SIGUIENTE',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isLastStep
                    ? const Color(0xFF167D1D)
                    : const Color(0xFF195375),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class StepData {
  final String title;
  final String subtitle;
  final IconData icon;

  StepData({
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}
