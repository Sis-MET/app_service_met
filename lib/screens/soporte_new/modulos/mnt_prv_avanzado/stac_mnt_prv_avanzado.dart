import 'package:flutter/material.dart';
import 'package:service_met/screens/soporte_new/utils/balanza_info_helper.dart';
import 'package:service_met/screens/soporte_new/widgets/fin_servicio_screen.dart';
import 'package:service_met/screens/soporte_new/models/campo_estado.dart';
import 'package:service_met/screens/soporte_new/modulos/mnt_prv_avanzado/controllers/mnt_prv_avanzado_controller.dart';
import 'package:service_met/screens/soporte_new/modulos/mnt_prv_avanzado/models/mnt_prv_avanzado_model.dart';
import 'package:service_met/screens/soporte_new/modulos/mnt_prv_avanzado/widgets/steps/paso_terminal_balanza_caja.dart';
import 'package:service_met/screens/soporte_new/widgets/shared/paso_estado_final_widget.dart';
import 'package:service_met/screens/soporte_new/widgets/shared/paso_pruebas_finales_widget.dart';
import 'package:service_met/screens/soporte_new/widgets/shared/paso_pruebas_iniciales_widget.dart';
import 'package:service_met/widgets/service_ui/input_decoration.dart';
import 'package:service_met/widgets/service_ui/service_app_bar.dart';
import 'package:service_met/widgets/service_ui/service_workspace_layout.dart';
import 'package:service_met/widgets/service_ui/step_indicator.dart';

class StacMntPrvAvanzado extends StatefulWidget {
  final String sessionId;
  final String secaValue;
  final String nReca;
  final String codMetrica;
  final String userName;
  final String clienteId;
  final String plantaCodigo;
  final Map<String, dynamic>? instrumentoData;

  const StacMntPrvAvanzado({
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
  State<StacMntPrvAvanzado> createState() => _StacMntPrvAvanzadoState();
}

class _StacMntPrvAvanzadoState extends State<StacMntPrvAvanzado> {
  late final MntPrvAvanzadoController _controller;
  late final MntPrvAvanzadoModel _model;

  static const _steps = [
    StepData(
        title: 'Pruebas Iniciales',
        subtitle: 'Metrológicas',
        icon: Icons.science_outlined),
    StepData(
        title: 'Lozas',
        subtitle: 'Campos de inspección',
        icon: Icons.foundation_outlined),
    StepData(
        title: 'Limpieza',
        subtitle: 'Campos de inspección',
        icon: Icons.cleaning_services_outlined),
    StepData(
        title: 'Chequeo',
        subtitle: 'Campos de inspección',
        icon: Icons.checklist_outlined),
    StepData(
        title: 'Eléctricas',
        subtitle: 'Campos de inspección',
        icon: Icons.electrical_services_outlined),
    StepData(
        title: 'Pruebas Finales',
        subtitle: 'Verificación final',
        icon: Icons.task_alt_outlined),
    StepData(
        title: 'Estado Final',
        subtitle: 'Conclusión del servicio',
        icon: Icons.assignment_turned_in_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _model = MntPrvAvanzadoModel(
      sessionId: widget.sessionId,
      codMetrica: widget.codMetrica,
    );
    _controller = MntPrvAvanzadoController(model: _model);
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
            tableNameDefault: 'mnt_prv_avanzado',
            csvSuffix: 'MntPrvAvanzado',
            tipoServicio: 'MNT PREVENTIVO AVANZADO',
          ),
        ),
      ),
    );
  }

  void _onCampoChanged(
      List<CampoEstado> campos, int index, String value, String solutionValue) {
    if (index < campos.length) {
      campos[index].value = value;
      campos[index].solutionValue = solutionValue;
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
          title: 'Mnt Preventivo Avanzado',
          steps: _steps,
          stepWidgets: [
            _buildPaso(
              const ServiceStepHeader(
                title: 'Pruebas Iniciales',
                subtitle: 'Pruebas metrológicas iniciales',
              ),
              PasoPruebasInicialesWidget(
                pruebasIniciales: _controller.pruebasIniciales,
                onDataChanged: _controller.markChanged,
              ),
            ),
            _buildPaso(
              const ServiceStepHeader(
                title: 'Lozas',
                subtitle: 'Complete el estado de cada campo',
              ),
              PasoTerminalBalanzaCaja(
                title: 'Lozas',
                campos: _controller.camposLozas,
                onChanged: (i, v, s) =>
                    _onCampoChanged(_controller.camposLozas, i, v, s),
                seca: widget.secaValue,
                codMetrica: widget.codMetrica,
              ),
            ),
            _buildPaso(
              const ServiceStepHeader(
                title: 'Limpieza',
                subtitle: 'Complete el estado de cada campo',
              ),
              PasoTerminalBalanzaCaja(
                title: 'Limpieza',
                campos: _controller.camposLimpieza,
                onChanged: (i, v, s) =>
                    _onCampoChanged(_controller.camposLimpieza, i, v, s),
                seca: widget.secaValue,
                codMetrica: widget.codMetrica,
              ),
            ),
            _buildPaso(
              const ServiceStepHeader(
                title: 'Chequeo',
                subtitle: 'Complete el estado de cada campo',
              ),
              PasoTerminalBalanzaCaja(
                title: 'Chequeo',
                campos: _controller.camposChequeo,
                onChanged: (i, v, s) =>
                    _onCampoChanged(_controller.camposChequeo, i, v, s),
                seca: widget.secaValue,
                codMetrica: widget.codMetrica,
              ),
            ),
            _buildPaso(
              const ServiceStepHeader(
                title: 'Eléctricas',
                subtitle: 'Complete el estado de cada campo',
              ),
              PasoTerminalBalanzaCaja(
                title: 'Eléctricas',
                campos: _controller.camposElectricas,
                onChanged: (i, v, s) =>
                    _onCampoChanged(_controller.camposElectricas, i, v, s),
                seca: widget.secaValue,
                codMetrica: widget.codMetrica,
              ),
            ),
            _buildPaso(
              const ServiceStepHeader(
                title: 'Pruebas Finales',
                subtitle: 'Pruebas metrológicas finales',
              ),
              PasoPruebasFinalesWidget(
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
