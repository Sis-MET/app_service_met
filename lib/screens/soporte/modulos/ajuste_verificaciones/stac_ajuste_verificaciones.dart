// ignore_for_file: unused_local_variable, deprecated_member_use, library_private_types_in_public_api, use_build_context_synchronously

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:service_met/provider/balanza_provider.dart';
import 'package:service_met/screens/soporte/modulos/ajuste_verificaciones/fin_servicio_ajustes_verificaciones.dart';
import 'models/ajuste_verificaciones_model.dart';
import 'controllers/ajuste_verificaciones_controller.dart';

import 'widgets/paso_pruebas_iniciales.dart';
import 'widgets/paso_pruebas_finales.dart';
import 'widgets/paso_estado_final_ajuste.dart';
import 'package:service_met/screens/soporte/widgets/balanza_speed_dial.dart';

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
  double? _cachedD1; // ✅ Cachear d1 para evitar múltiples consultas

  final List<StepData> _steps = [
    StepData(
      title: 'Pruebas Iniciales',
      subtitle: 'Metrología Inicial',
      icon: Icons.science_outlined,
    ),
    StepData(
      title: 'Pruebas Finales',
      subtitle: 'Metrología Final',
      icon: Icons.task_alt_outlined,
    ),
    StepData(
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

  Future<void> _saveCurrentStep() async {
    if (_isSaving) return;

    setState(() => _isSaving = true);

    try {
      await _controller.saveDataToDatabase(context, showMessage: false);
      debugPrint('✅ Paso $_currentStep guardado automáticamente');
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
                'AJUSTES Y VERIFICACIONES',
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
        floatingActionButton: const BalanzaSpeedDial(),
        floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
      ),
    );
  }

  Widget _buildProgressBar(bool isDarkMode) {
    final primaryColor = Theme.of(context).primaryColor;
    final step = _steps[_currentStep];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      color: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // Pill con icono + nombre
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: primaryColor.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(step.icon, size: 13, color: primaryColor),
                    const SizedBox(width: 5),
                    Text(
                      step.title,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Subtitle sutil
              Expanded(
                child: Text(
                  step.subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDarkMode ? Colors.white38 : Colors.black38,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Contador
              Text(
                '${_currentStep + 1} / ${_steps.length}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white54 : Colors.black45,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Barra delgada segmentada animada
          Row(
            children: List.generate(_steps.length, (i) {
              final isCompleted = i < _currentStep;
              final isCurrent = i == _currentStep;
              return Expanded(
                child: GestureDetector(
                  onTap: () async {
                    if (i < _currentStep) {
                      await _saveCurrentStep();
                      setState(() => _currentStep = i);
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    height: 3,
                    margin: EdgeInsets.only(left: i == 0 ? 0 : 3),
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? primaryColor
                          : isCurrent
                              ? primaryColor.withOpacity(0.55)
                              : (isDarkMode
                                  ? Colors.white12
                                  : Colors.black.withOpacity(0.08)),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 4),
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
          onChanged: () => setState(() {}),
          getIndicationSuggestions: _controller.getIndicationSuggestions,
          getD1FromDatabase: _getD1FromCache,
        );
      case 1:
        return PasoPruebasFinales(
          model: _model,
          controller: _controller,
          onChanged: () => setState(() {}),
          getIndicationSuggestions: _controller.getIndicationSuggestions,
          getD1FromDatabase: _getD1FromCache,
        );
      case 2:
        return PasoEstadoFinalAjuste(
          model: _model,
          onChanged: () => setState(() {}),
        );
      default:
        return const Center(child: Text('Paso no encontrado'));
    }
  }

  Widget _buildNavigationButtons(bool isDarkMode) {
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
            SizedBox(
              width: 110,
              child: OutlinedButton.icon(
                onPressed: () => _goToStep(_currentStep - 1),
                icon: const Icon(Icons.arrow_back, size: 16),
                label: const Text('ANTERIOR'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey[700],
                  side: BorderSide(color: Colors.grey[400]!),
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
                        if (_validateCurrentStep()) {
                          // Al finalizar, usamos saveData para incluir las fotos
                          await _controller.saveData(context);

                          if (!mounted) return;

                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  FinServicioAjustesVerificacionesScreen(
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
              icon: Icon(
                _currentStep < _steps.length - 1
                    ? Icons.arrow_forward
                    : Icons.check_circle,
              ),
              label: Text(
                _currentStep < _steps.length - 1 ? 'SIGUIENTE' : 'FINALIZAR',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _currentStep < _steps.length - 1
                    ? const Color(0xFF195375)
                    : const Color(0xFF167D1D),
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
