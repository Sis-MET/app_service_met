import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:service_met/screens/soporte_new/utils/balanza_info_helper.dart';
import 'package:service_met/screens/soporte_new/widgets/fin_servicio_screen.dart';
import 'package:service_met/screens/soporte_new/widgets/shared/paso_estado_final_widget.dart';
import 'package:service_met/widgets/service_ui/input_decoration.dart';
import 'package:service_met/widgets/service_ui/nav_pill.dart';
import 'package:service_met/widgets/service_ui/service_app_bar.dart';
import 'package:service_met/widgets/service_ui/service_workspace_layout.dart';
import 'package:service_met/widgets/service_ui/step_indicator.dart';
import 'package:service_met/screens/oportunidades/models/opportunity_service_context.dart';
import 'package:service_met/screens/oportunidades/widgets/opportunity_menu_action.dart';
import 'package:service_met/screens/soporte_new/utils/pasos_soporte.dart';
import 'package:service_met/screens/soporte_new/utils/salida_servicio.dart';

import 'controllers/diagnostico_controller.dart';
import 'models/diagnostico_model.dart';

class StacDiagnostico extends StatefulWidget {
  final String sessionId;
  final String secaValue;
  final String nReca;
  final String codMetrica;
  final String userName;
  final String clienteId;
  final String plantaCodigo;
  final String clienteNombre;
  final String clienteRazonSocial;
  final String plantaNombre;
  final String plantaDireccion;
  final String plantaDepartamento;
  final Map<String, dynamic>? instrumentoData;

  const StacDiagnostico({
    super.key,
    required this.sessionId,
    required this.secaValue,
    required this.nReca,
    required this.codMetrica,
    required this.userName,
    required this.clienteId,
    required this.plantaCodigo,
    this.clienteNombre = '',
    this.clienteRazonSocial = '',
    this.plantaNombre = '',
    this.plantaDireccion = '',
    this.plantaDepartamento = '',
    this.instrumentoData,
  });

  @override
  State<StacDiagnostico> createState() => _StacDiagnosticoState();
}

class _StacDiagnosticoState extends State<StacDiagnostico> {
  late DiagnosticoController _controller;
  bool _isLoading = true;

  static const _steps = [
    StepData(
        title: 'Info General',
        subtitle: 'Reporte y evaluación',
        icon: Icons.info_outline),
    StepData(
        title: 'Estado Final',
        subtitle: 'Conclusión del servicio',
        icon: Icons.assignment_turned_in_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _controller = DiagnosticoController(
      model: DiagnosticoModel(
        sessionId: widget.sessionId,
        codMetrica: widget.codMetrica,
        secaValue: widget.secaValue,
      ),
    );
    _controller.secaValue = widget.secaValue;
    _controller.clienteNombre = widget.clienteNombre;
    _controller.plantaNombre = widget.plantaNombre;
    _controller.horaInicio = DateFormat('HH:mm').format(DateTime.now());
    _controller.initCamposEstado();
    _controller.camposEstado.clear();
    _setBalanzaData();
    _configureRecovery();
    _loadExistingData();
  }

  void _configureRecovery() => _controller.configureRecovery(
        personal: widget.userName,
        clienteId: widget.clienteId,
        clienteRazonSocial: widget.clienteRazonSocial,
        plantaCodigo: widget.plantaCodigo,
        plantaDireccion: widget.plantaDireccion,
        plantaDepartamento: widget.plantaDepartamento,
        nReca: widget.nReca,
        instrumentoData: widget.instrumentoData,
      );

  Future<void> _loadExistingData() async {
    try {
      await _controller.restoreSession();
    } catch (error) {
      debugPrint('Error restaurando diagnostico: $error');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _setBalanzaData() {
    final data = widget.instrumentoData;
    _controller.razonSocial = widget.clienteRazonSocial;
    _controller.dirPlanta = widget.plantaDireccion;
    _controller.depPlanta = widget.plantaDepartamento;
    _controller.codPlanta = widget.plantaCodigo;
    _controller.personal = widget.userName;
    if (data == null) return;
    _controller.infBal = data['_modifiedFields']?.toString() ?? '';
    _controller.categoriaBalanza = data['categoria']?.toString() ??
        data['categoria_balanza']?.toString() ??
        '';
    _controller.codInt =
        data['cod_interno']?.toString() ?? data['cod_int']?.toString() ?? '';
    _controller.tipoEquipo = data['tipo_instrumento']?.toString() ??
        data['tipo']?.toString() ??
        data['instrumento']?.toString() ??
        '';
    _controller.marca = data['marca']?.toString() ?? '';
    _controller.modelo = data['modelo']?.toString() ?? '';
    _controller.serie =
        data['inf_serie']?.toString() ?? data['serie']?.toString() ?? '';
    _controller.unidades =
        data['unidad']?.toString() ?? data['unidades']?.toString() ?? '';
    _controller.numCeldas =
        data['n_celdas']?.toString() ?? data['num_celdas']?.toString() ?? '';
    _controller.ubicacion = data['ubicacion']?.toString() ?? '';
    _controller.capMax1 = data['cap_max1']?.toString() ?? '';
    _controller.d1 = data['d1']?.toString() ?? '';
    _controller.e1 = data['e1']?.toString() ?? '';
    _controller.dec1 = data['dec1']?.toString() ?? '';
    _controller.capMax2 = data['cap_max2']?.toString() ?? '';
    _controller.d2 = data['d2']?.toString() ?? '';
    _controller.e2 = data['e2']?.toString() ?? '';
    _controller.dec2 = data['dec2']?.toString() ?? '';
    _controller.capMax3 = data['cap_max3']?.toString() ?? '';
    _controller.d3 = data['d3']?.toString() ?? '';
    _controller.e3 = data['e3']?.toString() ?? '';
    _controller.dec3 = data['dec3']?.toString() ?? '';
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

  /// Qué le falta al paso [step] para darlo por completo; null si nada. Lo
  /// usan "Siguiente" y el panel ≡ de pasos.
  String? _stepIssue(int step) {
    switch (step) {
      case 0:
        if (_controller.reporteFalla.isEmpty) {
          return 'Complete el reporte de falla';
        }
        if (_controller.evaluacion.isEmpty) {
          return 'Complete la evaluacion tecnica';
        }
        return null;
      case 1:
        if (_controller.comentarioGeneral.isEmpty) {
          return 'Complete el comentario general';
        }
        if (_controller.horaFin.isEmpty) {
          return 'Registre la hora final del servicio';
        }
        return null;
      default:
        return null;
    }
  }

  /// Adelante solo con lo anterior completo y guardado; ver [PasosSoporte].
  late final _pasos = PasosSoporte(
    controller: _controller,
    total: _steps.length,
    falta: _stepIssue,
  );

  Future<void> _finalizar() async {
    if (!await _pasos.listoParaFinalizar(context)) return;
    if (!mounted) return;
    Navigator.push(
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
          tableName: 'diagnostico',
          config: const FinServicioConfig(
            tableNameDefault: 'diagnostico',
            additionalWhere: '',
            tipoServicio: 'DIAGNÓSTICO',
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
    if (_isLoading) {
      return Scaffold(
        appBar: ServiceAppBar(title: 'Diagnostico', centerTitle: true),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final isLast = _controller.currentStep == _steps.length - 1;
        return ServiceWorkspaceLayout(
          title: 'Diagnóstico',
          menuActions: [
            OpportunityMenuAction(
              contextBuilder: () => OpportunityServiceContext.fromSupport(
                serviceName: 'Diagnóstico',
                otst: widget.secaValue,
                sessionId: widget.sessionId,
                codMetrica: widget.codMetrica,
                userName: widget.userName,
                clienteNombre: widget.clienteNombre,
                clienteRazonSocial: widget.clienteRazonSocial,
                plantaNombre: widget.plantaNombre,
                plantaDepartamento: widget.plantaDepartamento,
                instrumentoData: widget.instrumentoData,
              ),
            ),
          ],
          steps: _steps,
          stepWidgets: [
            _buildPasoInfoGeneral(),
            _buildPasoEstadoFinal(),
          ],
          currentStep: _controller.currentStep,
          onStepTapped: (paso) => _pasos.irA(context, paso),
          stepIssue: _stepIssue,
          nextLabel: isLast ? 'Finalizar' : 'Siguiente',
          nextColor: isLast ? const Color(0xFF3e7732) : const Color(0xFF498054),
          onNext: isLast
              ? _finalizar
              : () => _pasos.irA(context, _controller.currentStep + 1),
          onBack: _controller.currentStep > 0
              ? () => _pasos.irA(context, _controller.currentStep - 1)
              : null,
          // Salir es explícito (menú ⋮); Atrás solo retrocede entre pasos.
          onExit: () => salirGuardando(context, _controller),
          saveStatus: _saveStatus,
          balanzaInfo: buildServiceBalanzaInfo(
              widget.instrumentoData, widget.codMetrica),
        );
      },
    );
  }

  Widget _buildPasoInfoGeneral() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SingleChildScrollView(
      padding: ServiceNavPill.pagePadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ServiceStepHeader(
            title: 'Información General',
            subtitle: 'Reporte de falla y evaluación técnica',
          ),
          const SizedBox(height: 24),
          TextFormField(
            initialValue: _controller.reporteFalla,
            decoration: serviceInputDeco('Reporte de Falla', isDark),
            maxLines: 4,
            onChanged: (v) {
              _controller.reporteFalla = v;
              _onFieldChanged();
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: _controller.evaluacion,
            decoration: serviceInputDeco(
                'Evaluacion y analisis tecnico de fallas', isDark),
            maxLines: 4,
            onChanged: (v) {
              _controller.evaluacion = v;
              _onFieldChanged();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPasoEstadoFinal() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF1E2A20) : Colors.white;
    final mutedColor = isDark ? Colors.white70 : const Color(0xFF627066);

    return SingleChildScrollView(
      padding: ServiceNavPill.pagePadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ServiceStepHeader(
            title: 'Finalizar diagnóstico',
            subtitle: 'Registre la conclusión y la hora de término',
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.white12 : const Color(0xFFE2E8E2),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.login_outlined, color: Color(0xFF46824B)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Hora de inicio',
                          style: TextStyle(color: mutedColor, fontSize: 13)),
                      const SizedBox(height: 3),
                      Text(_controller.horaInicio.isEmpty
                          ? '--:--'
                          : _controller.horaInicio),
                    ],
                  ),
                ),
                const Icon(Icons.logout_outlined, color: Color(0xFF46824B)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Hora de finalización',
                          style: TextStyle(color: mutedColor, fontSize: 13)),
                      const SizedBox(height: 3),
                      Text(_controller.horaFin.isEmpty
                          ? 'Sin registrar'
                          : _controller.horaFin),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'Registrar hora final',
                  onPressed: () {
                    setState(() {
                      _controller.horaFin =
                          DateFormat('HH:mm:ss').format(DateTime.now());
                      _controller.markChanged();
                    });
                  },
                  icon: const Icon(Icons.access_time),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          TextFormField(
            initialValue: _controller.comentarioGeneral,
            decoration: serviceInputDeco('Comentario general', isDark).copyWith(
              helperText: 'Resumen final del diagnóstico realizado',
            ),
            maxLines: 5,
            maxLength: 1000,
            onChanged: (value) {
              _controller.comentarioGeneral = value;
              _onFieldChanged();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGenericEstadoFinalUnused() {
    return SingleChildScrollView(
      padding: ServiceNavPill.pagePadding(context),
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
            camposEstado: const [],
            onCampoChanged: (index, value, solutionValue) {},
            horaInicio: _controller.horaInicio,
            horaFin: _controller.horaFin,
            onRegistrarHoraFin: () {
              setState(() {
                _controller.horaFin =
                    DateFormat('HH:mm:ss').format(DateTime.now());
                _controller.markChanged();
              });
            },
          ),
        ],
      ),
    );
  }
}
