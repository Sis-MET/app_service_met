import 'package:flutter/material.dart';
import 'package:service_met/screens/soporte_new/utils/balanza_info_helper.dart';
import 'package:service_met/screens/soporte_new/widgets/fin_servicio_screen.dart';
import 'package:service_met/screens/soporte_new/modulos/instalacion/controllers/instalacion_controller.dart';
import 'package:service_met/screens/soporte_new/modulos/instalacion/models/instalacion_model.dart';
import 'package:service_met/screens/soporte_new/modulos/instalacion/widgets/steps/paso_condiciones_instalacion_widget.dart';
import 'package:service_met/screens/soporte_new/modulos/instalacion/widgets/steps/paso_pruebas_instalacion_widget.dart';
import 'package:service_met/screens/soporte_new/widgets/shared/paso_estado_final_widget.dart';
import 'package:service_met/widgets/service_ui/input_decoration.dart';
import 'package:service_met/widgets/service_ui/service_app_bar.dart';
import 'package:service_met/widgets/service_ui/service_workspace_layout.dart';
import 'package:service_met/widgets/service_ui/step_indicator.dart';

class StacInstalacion extends StatefulWidget {
  final String sessionId;
  final String secaValue;
  final String nReca;
  final String codMetrica;
  final String userName;
  final String clienteId;
  final String plantaCodigo;
  final Map<String, dynamic>? instrumentoData;

  const StacInstalacion({
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
  State<StacInstalacion> createState() => _StacInstalacionState();
}

class _StacInstalacionState extends State<StacInstalacion> {
  late final InstalacionController _controller;
  late final InstalacionModel _model;

  static const _steps = [
    StepData(
        title: 'Condiciones',
        subtitle: 'De instalación',
        icon: Icons.construction_outlined),
    StepData(
        title: 'Pruebas',
        subtitle: 'De instalación',
        icon: Icons.task_alt_outlined),
    StepData(
        title: 'Estado Final',
        subtitle: 'Conclusión del servicio',
        icon: Icons.assignment_turned_in_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _model = InstalacionModel(
      sessionId: widget.sessionId,
      codMetrica: widget.codMetrica,
    );
    _controller = InstalacionController(model: _model);
    _controller.initCamposEstado();
  }

  void _onStepTapped(int step) {
    setState(() => _controller.currentStep = step);
  }

  void _onAnterior() {
    if (_controller.currentStep > 0) {
      setState(() => _controller.currentStep--);
    }
  }

  void _onSiguiente() {
    if (_controller.currentStep < _controller.totalSteps - 1) {
      setState(() => _controller.currentStep++);
    }
  }

  void _onFinalizar() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FinServicioScreen(
          controller: _controller,
          sessionId: widget.sessionId,
          secaValue: widget.secaValue,
          nReca: widget.nReca,
          codMetrica: widget.codMetrica,
          userName: widget.userName,
          clienteId: widget.clienteId,
          plantaCodigo: widget.plantaCodigo,
          config: const FinServicioConfig(
            tableNameDefault: 'instalacion',
            csvSuffix: 'Instalacion',
            tipoServicio: 'INSTALACIÓN',
          ),
        ),
      ),
    );
  }

  void _onCampoChanged(int index, String value, String solutionValue) {
    if (index < _controller.camposEstado.length) {
      _controller.camposEstado[index].value = value;
      _controller.camposEstado[index].solutionValue = solutionValue;
      _controller.markChanged();
    }
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
        final isLast = _controller.currentStep == _controller.totalSteps - 1;
        return ServiceWorkspaceLayout(
          title: 'Instalación',
          steps: _steps,
          stepWidgets: [
            _buildPaso(
              const ServiceStepHeader(
                title: 'Condiciones de Instalación',
                subtitle: 'Verifique las condiciones del sitio',
              ),
              PasoCondicionesInstalacionWidget(
                campos: _controller.camposEstado,
                onChanged: _onCampoChanged,
              ),
            ),
            _buildPaso(
              const ServiceStepHeader(
                title: 'Pruebas de Instalación',
                subtitle: 'Pruebas metrológicas',
              ),
              PasoPruebasInstalacionWidget(
                pruebasFinales: _controller.pruebasFinales,
                onDataChanged: _controller.markChanged,
              ),
            ),
            _buildPaso(
              const ServiceStepHeader(
                title: 'Estado Final',
                subtitle: 'Conclusión del servicio',
              ),
              PasoEstadoFinalWidget(
                comentarioGeneral: _controller.comentarioGeneral,
                recomendacion: _controller.recomendacion,
                estadoFisico: _controller.estadoFisico,
                estadoOperacional: _controller.estadoOperacional,
                estadoMetrologico: _controller.estadoMetrologico,
                onComentarioGeneralChanged: (v) {
                  _controller.comentarioGeneral = v;
                  _controller.markChanged();
                },
                onRecomendacionChanged: (v) {
                  _controller.recomendacion = v;
                  _controller.markChanged();
                },
                onEstadoFisicoChanged: (v) {
                  _controller.estadoFisico = v;
                  _controller.markChanged();
                },
                onEstadoOperacionalChanged: (v) {
                  _controller.estadoOperacional = v;
                  _controller.markChanged();
                },
                onEstadoMetrologicoChanged: (v) {
                  _controller.estadoMetrologico = v;
                  _controller.markChanged();
                },
                camposEstado: const [],
                onCampoChanged: (i, v, s) {},
              ),
            ),
          ],
          currentStep: _controller.currentStep,
          onStepTapped: _onStepTapped,
          nextLabel: isLast ? 'Finalizar' : 'Siguiente',
          nextColor:
              isLast ? const Color(0xFF3e7732) : const Color(0xFF498054),
          onNext: isLast ? _onFinalizar : _onSiguiente,
          onBack: _controller.currentStep > 0 ? _onAnterior : null,
          saveStatus: _saveStatus,
          balanzaInfo:
              buildServiceBalanzaInfo(widget.instrumentoData, widget.codMetrica),
        );
      },
    );
  }

  Widget _buildPaso(Widget header, Widget content) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          const SizedBox(height: 24),
          content,
        ],
      ),
    );
  }
}
