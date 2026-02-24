// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously, deprecated_member_use

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:service_met/screens/soporte/modulos/instalacion/fin_servicio_instalacion.dart';

import 'controllers/instalacion_controller.dart';
import 'models/instalacion_model.dart';
import 'widgets/steps/paso_condiciones_instalacion.dart';
import 'widgets/steps/paso_pruebas_instalacion.dart';
import 'widgets/steps/paso_estado_final_instalacion.dart';
import 'package:service_met/screens/soporte/widgets/balanza_speed_dial.dart';

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

  final List<InstalacionStepData> _steps = [
    InstalacionStepData(
      title: 'Condiciones',
      subtitle: 'Entorno y montaje',
      icon: Icons.domain_outlined,
    ),
    InstalacionStepData(
      title: 'Pruebas',
      subtitle: 'Metrología Inicial',
      icon: Icons.science_outlined,
    ),
    InstalacionStepData(
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

  Future<void> _saveCurrentStep() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      await _controller.saveDataToDatabase(context, showMessage: false);
      debugPrint('✅ Paso $_currentStep guardado automáticamente');
    } catch (e) {
      debugPrint('❌ Error al guardar paso $_currentStep: $e');
    } finally {
      setState(() => _isSaving = false);
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return WillPopScope(
      onWillPop: () async {
        // Lógica de salida
        await _saveCurrentStep();
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 80,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'INSTALACIÓN',
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
                    child: CircularProgressIndicator(strokeWidth: 2)),
              ),
          ],
        ),
        body: Column(
          children: [
            _buildProgressBar(isDarkMode),
            Expanded(child: _buildStepContent()),
            _buildNavigationButtons(isDarkMode),
          ],
        ),
        floatingActionButton: const BalanzaSpeedDial(),
        floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
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
        return PasoCondicionesInstalacion(
          model: _model,
          controller: _controller,
          onChanged: () => setState(() {}),
        );
      case 1:
        return PasoPruebasInstalacion(
          model: _model,
          controller: _controller,
          onChanged: () => setState(() {}),
        );
      case 2:
        return PasoEstadoFinalInstalacion(
          model: _model,
          controller: _controller,
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
              offset: const Offset(0, -2))
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
                        // FINALIZAR
                        await _saveCurrentStep();
                        if (!mounted) return;
                        _model.horaFin =
                            DateFormat('HH:mm:ss').format(DateTime.now());
                        await _controller.saveData(
                            context); // Guardar final con fotos y todo

                        // Ir a pantalla final (EXISTENTE)
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FinServicioInstalacionScreen(
                              // Asegurarse que este widget exista y acepte los params
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
              icon: Icon(_currentStep < _steps.length - 1
                  ? Icons.arrow_forward
                  : Icons.check_circle),
              label: Text(
                  _currentStep < _steps.length - 1 ? 'SIGUIENTE' : 'FINALIZAR'),
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

class InstalacionStepData {
  final String title;
  final String subtitle;
  final IconData icon;

  InstalacionStepData(
      {required this.title, required this.subtitle, required this.icon});
}
