import 'package:flutter/material.dart';

import 'package:service_met/screens/soporte_new/utils/balanza_info_helper.dart';
import 'package:service_met/screens/soporte_new/widgets/fin_servicio_screen.dart';
import 'package:service_met/screens/soporte_new/widgets/shared/paso_pruebas_iniciales_widget.dart';
import 'package:service_met/screens/soporte_new/widgets/shared/paso_pruebas_finales_widget.dart';
import 'package:service_met/screens/soporte_new/widgets/shared/paso_estado_final_widget.dart';
import 'package:service_met/utils/top_alert.dart';
import 'package:service_met/widgets/service_ui/input_decoration.dart';
import 'package:service_met/widgets/service_ui/service_app_bar.dart';
import 'package:service_met/widgets/service_ui/service_workspace_layout.dart';
import 'package:service_met/widgets/service_ui/step_indicator.dart';

import 'controllers/ajuste_verificaciones_controller.dart';
import 'models/ajuste_verificaciones_model.dart';

class StacAjusteVerificaciones extends StatefulWidget {
  final String sessionId;
  final String secaValue;
  final String nReca;
  final String codMetrica;
  final String userName;
  final String clienteId;
  final String plantaCodigo;
  final Map<String, dynamic>? instrumentoData;

  const StacAjusteVerificaciones({
    super.key,
    required this.sessionId,
    required this.secaValue,
    required this.nReca,
    required this.codMetrica,
    required this.userName,
    required this.clienteId,
    required this.plantaCodigo,
    this.instrumentoData,
  });

  @override
  State<StacAjusteVerificaciones> createState() =>
      _StacAjusteVerificacionesState();
}

class _StacAjusteVerificacionesState extends State<StacAjusteVerificaciones> {
  late AjusteVerificacionesController _controller;
  int _currentStep = 0;
  bool _isSaving = false;

  static const _steps = [
    StepData(
        title: 'Pruebas Iniciales',
        subtitle: 'Metrológicas',
        icon: Icons.science_outlined),
    StepData(
        title: 'Pruebas Finales',
        subtitle: 'Metrológicas',
        icon: Icons.task_alt_outlined),
    StepData(
        title: 'Estado Final',
        subtitle: 'Conclusión del servicio',
        icon: Icons.assignment_turned_in_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AjusteVerificacionesController(
      model: AjusteVerificacionesModel(
        sessionId: widget.sessionId,
        codMetrica: widget.codMetrica,
        secaValue: widget.secaValue,
      ),
    );
    _controller.initCamposEstado();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    _controller.markChanged();
    setState(() {});
  }

  void _onCampoChanged(int index, String value, String solutionValue) {
    if (index < _controller.camposEstado.length) {
      _controller.camposEstado[index].value = value;
      _controller.camposEstado[index].solutionValue = solutionValue;
      _controller.markChanged();
      setState(() {});
    }
  }

  Future<void> _saveCurrentStep() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      await _controller.guardarSesion();
    } catch (e) {
      if (mounted) {
        TopAlert.show(context, 'Error al guardar: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  bool _validateCurrentStep() {
    if (_currentStep == 2) {
      if (_controller.estadoFisico.isEmpty ||
          _controller.estadoOperacional.isEmpty ||
          _controller.estadoMetrologico.isEmpty) {
        TopAlert.show(context, 'Complete todos los estados finales',
            isError: true);
        return false;
      }
    }
    return true;
  }

  Future<void> _goToStep(int step) async {
    if (step > _currentStep && !_validateCurrentStep()) return;
    await _saveCurrentStep();
    if (mounted) setState(() => _currentStep = step);
  }

  Future<void> _finalizar() async {
    if (!_validateCurrentStep()) return;
    await _saveCurrentStep();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => FinServicioScreen(
          controller: _controller,
          sessionId: widget.sessionId,
          secaValue: widget.secaValue,
          nReca: widget.nReca,
          codMetrica: widget.codMetrica,
          userName: widget.userName,
          clienteId: widget.clienteId,
          plantaCodigo: widget.plantaCodigo,
          tableName: 'ajuste_verificaciones',
          config: const FinServicioConfig(
            tableNameDefault: 'ajuste_verificaciones',
            csvSuffix: 'AjusteVerif',
            additionalWhere: '',
            tipoServicio: 'AJUSTE DE VERIFICACIONES',
            primaryColor: Color(0xFF46824B),
          ),
        ),
      ),
    );
  }

  SaveStatus get _saveStatus => _controller.isSaving
      ? SaveStatus.saving
      : (_controller.lastSaveSuccessful
          ? SaveStatus.success
          : SaveStatus.error);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final isLast = _currentStep == _steps.length - 1;
        return ServiceWorkspaceLayout(
          title: 'Ajuste de Verificaciones',
          steps: _steps,
          stepWidgets: [
            _buildPasoPruebasIniciales(),
            _buildPasoPruebasFinales(),
            _buildPasoEstadoFinal(),
          ],
          currentStep: _currentStep,
          onStepTapped: (step) => _goToStep(step),
          nextLabel: isLast ? 'Finalizar' : 'Siguiente',
          nextColor: isLast
              ? const Color(0xFF3e7732)
              : const Color(0xFF498054),
          onNext:
              isLast ? _finalizar : () => _goToStep(_currentStep + 1),
          onBack: _currentStep > 0
              ? () => _goToStep(_currentStep - 1)
              : null,
          saveStatus: _saveStatus,
          balanzaInfo:
              buildServiceBalanzaInfo(widget.instrumentoData, widget.codMetrica),
        );
      },
    );
  }

  Widget _buildPasoPruebasIniciales() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ServiceStepHeader(
            title: 'Pruebas Iniciales',
            subtitle: 'Pruebas metrológicas iniciales',
          ),
          const SizedBox(height: 24),
          PasoPruebasInicialesWidget(
            pruebasIniciales: _controller.pruebasIniciales,
            onDataChanged: _onFieldChanged,
          ),
          const SizedBox(height: 16),
          Center(
            child: ElevatedButton.icon(
              onPressed: () {
                _controller.copiarPruebasInicialesAFinales();
                TopAlert.show(
                    context, 'Pruebas iniciales copiadas a finales');
                setState(() {});
              },
              icon: const Icon(Icons.copy),
              label: const Text('Copiar Iniciales a Finales'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasoPruebasFinales() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ServiceStepHeader(
            title: 'Pruebas Finales',
            subtitle: 'Pruebas metrológicas finales',
          ),
          const SizedBox(height: 24),
          PasoPruebasFinalesWidget(
            pruebasFinales: _controller.pruebasFinales,
            onDataChanged: _onFieldChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildPasoEstadoFinal() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ServiceStepHeader(
            title: 'Estado Final',
            subtitle: 'Conclusión del servicio',
          ),
          const SizedBox(height: 24),
          PasoEstadoFinalWidget(
            comentarioGeneral: _controller.comentarioGeneral,
            recomendacion: _controller.recomendacion,
            estadoFisico: _controller.estadoFisico,
            estadoOperacional: _controller.estadoOperacional,
            estadoMetrologico: _controller.estadoMetrologico,
            onComentarioGeneralChanged: (v) {
              _controller.comentarioGeneral = v;
              _onFieldChanged();
            },
            onRecomendacionChanged: (v) {
              _controller.recomendacion = v;
              _onFieldChanged();
            },
            onEstadoFisicoChanged: (v) {
              _controller.estadoFisico = v;
              _onFieldChanged();
            },
            onEstadoOperacionalChanged: (v) {
              _controller.estadoOperacional = v;
              _onFieldChanged();
            },
            onEstadoMetrologicoChanged: (v) {
              _controller.estadoMetrologico = v;
              _onFieldChanged();
            },
            camposEstado: _controller.camposEstado,
            onCampoChanged: _onCampoChanged,
          ),
        ],
      ),
    );
  }
}
