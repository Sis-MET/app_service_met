import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:service_met/models/service_session.dart';
import 'package:service_met/screens/calibracion/widgets/indicator_reader_screen.dart';
import 'package:service_met/screens/soporte_new/modulos/instalacion/controllers/instalacion_controller.dart';
import 'package:service_met/screens/soporte_new/modulos/instalacion/models/instalacion_model.dart';
import 'package:service_met/screens/soporte_new/modulos/instalacion/widgets/steps/paso_condiciones_instalacion_widget.dart';
import 'package:service_met/screens/soporte_new/modulos/mnt_prv_regular/widgets/steps/paso_pruebas_metrologicas.dart';
import 'package:service_met/screens/soporte_new/utils/balanza_info_helper.dart';
import 'package:service_met/screens/soporte_new/widgets/fin_servicio_screen.dart';
import 'package:service_met/screens/soporte_new/widgets/shared/paso_estado_final_widget.dart';
import 'package:service_met/widgets/service_ui/input_decoration.dart';
import 'package:service_met/widgets/service_ui/service_app_bar.dart';
import 'package:service_met/widgets/service_ui/service_workspace_layout.dart';
import 'package:service_met/widgets/service_ui/step_indicator.dart';
import 'package:service_met/widgets/service_ui/nav_pill.dart';
import 'package:service_met/screens/oportunidades/models/opportunity_service_context.dart';
import 'package:service_met/screens/soporte_new/utils/menu_soporte.dart';
import 'package:service_met/screens/soporte_new/utils/pasos_soporte.dart';
import 'package:service_met/screens/soporte_new/utils/requisitos_pruebas.dart';
import 'package:service_met/screens/soporte_new/utils/salida_servicio.dart';
import '../../../../theme/app_icons.dart';

class StacInstalacion extends StatefulWidget {
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

  const StacInstalacion({
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
  State<StacInstalacion> createState() => _StacInstalacionState();
}

class _StacInstalacionState extends State<StacInstalacion> {
  late final InstalacionController _controller;
  late final InstalacionModel _model;
  late final BalanzaInfo _balanzaInfo;
  bool _isLoading = true;

  static const _steps = [
    StepData(
      title: 'Condiciones',
      subtitle: 'Entorno y montaje',
      icon: AppIcons.empresa,
    ),
    StepData(
      title: 'Pruebas',
      subtitle: 'Metrología inicial',
      icon: AppIcons.laboratorio,
    ),
    StepData(
      title: 'Estado Final',
      subtitle: 'Cierre del servicio',
      icon: AppIcons.formularioCompleto,
    ),
  ];

  static const _recomendacionesOptions = [
    'Diagnostico',
    'Mnt Preventivo Regular',
    'Mnt Preventivo Avanzado',
    'Mnt Correctivo',
    'Ajustes Metrológicos',
    'Calibración',
    'Sin recomendación',
  ];

  /// Menú ⋮: emitir el RIM del instrumento y registrar una oportunidad.
  late final _menu = SoporteMenu(
    controller: _controller,
    userName: widget.userName,
    clienteId: widget.clienteId,
    plantaCodigo: widget.plantaCodigo,
    otst: widget.secaValue,
    contextBuilder: () => OpportunityServiceContext.fromSupport(
      serviceName: 'Instalación',
      otst: widget.secaValue,
      sessionId: widget.sessionId,
      codMetrica: widget.codMetrica,
      userName: widget.userName,
      clienteNombre: widget.clienteNombre,
      clienteRazonSocial: widget.clienteRazonSocial,
      plantaNombre: widget.plantaNombre,
      plantaDepartamento: widget.plantaDepartamento,
      clienteId: widget.clienteId,
      plantaCodigo: widget.plantaCodigo,
      plantaDireccion: widget.plantaDireccion,
      instrumentoData: widget.instrumentoData,
    ),
  );

  @override
  void initState() {
    super.initState();
    _model = InstalacionModel(
      sessionId: widget.sessionId,
      codMetrica: widget.codMetrica,
    );
    _controller = InstalacionController(model: _model);
    _controller.secaValue = widget.secaValue;
    _controller.clienteNombre = widget.clienteNombre;
    _controller.plantaNombre = widget.plantaNombre;
    _controller.initCamposEstado();
    _setContextData();
    _configureRecovery();
    _balanzaInfo =
        buildCalBalanzaInfo(widget.instrumentoData, widget.codMetrica);
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

  void _setContextData() {
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

  Future<void> _loadExistingData() async {
    try {
      await _controller.restoreSession();
    } catch (error) {
      debugPrint('Error restaurando instalación: $error');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Qué le falta al paso [step] para darlo por completo; null si nada. Lo
  /// usan "Siguiente" y el panel ≡ de pasos.
  String? _stepIssue(int step) {
    switch (step) {
      case 0:
        if (_controller.camposEstado.any((campo) => campo.value.isEmpty)) {
          return 'Complete todas las condiciones de instalación';
        }
        return null;
      case 1:
        if (_controller.retornoCeroInicial.isEmpty ||
            _controller.estabilidadInicial.isEmpty) {
          return 'Complete retorno a cero y estabilidad';
        }
        return faltaEnPruebas(
          momento: 'iniciales',
          excentricidadRealizada: _controller.excentricidadRealizada,
          excentricidad: _controller.excentricidadInicial,
          repetibilidadRealizada: _controller.repetibilidadRealizada,
          repetibilidad: _controller.repetibilidadInicial,
          linealidadRealizada: _controller.linealidadRealizada,
          linealidad: _controller.linealidadInicial,
        );
      case 2:
        if (_controller.comentarioGeneral.isEmpty) {
          return 'Complete el comentario general';
        }
        if (_controller.recomendacion.isEmpty) {
          return 'Seleccione una recomendación';
        }
        if (_controller.estadoFisico.isEmpty ||
            _controller.estadoOperacional.isEmpty ||
            _controller.estadoMetrologico.isEmpty) {
          return 'Complete todos los estados finales';
        }
        if (_controller.fechaProxServicio.isEmpty ||
            _controller.horaFin.isEmpty) {
          return 'Registre la fecha del próximo servicio y la hora final';
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

  Future<void> _onFinalizar() async {
    if (!await _pasos.listoParaFinalizar(context) || !mounted) return;
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
          clienteNombre: widget.clienteNombre,
          plantaNombre: widget.plantaNombre,
          config: const FinServicioConfig(
            tableNameDefault: 'instalacion',
            tipoServicio: 'INSTALACIÓN',
          ),
          tableName: 'instalacion',
        ),
      ),
    );
  }

  void _onCampoChanged(int index, String value, String comentario) {
    if (index >= _controller.camposEstado.length) return;
    _controller.camposEstado[index].value = value;
    _controller.camposEstado[index].solutionValue = comentario;
    _controller.markChanged();
  }

  SaveStatus get _saveStatus => _controller.isSaving
      ? SaveStatus.saving
      : (_controller.lastSaveSuccessful
          ? SaveStatus.success
          : SaveStatus.error);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: ServiceAppBar(title: 'Instalación', centerTitle: true),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final isLast = _controller.currentStep == _controller.totalSteps - 1;
        return ServiceWorkspaceLayout(
          title: 'Instalación',
          menuActions: _menu.actions,
          exitSuggestion: _menu.exitSuggestion,
          steps: _steps,
          stepWidgets: [
            _buildPaso(
              const ServiceStepHeader(
                title: 'Condiciones de Instalación',
                subtitle: 'Verifique el entorno y las condiciones de montaje',
              ),
              PasoCondicionesInstalacionWidget(
                campos: _controller.camposEstado,
                onChanged: _onCampoChanged,
                seca: widget.secaValue,
                codMetrica: widget.codMetrica,
              ),
            ),
            _buildPaso(
              const ServiceStepHeader(
                title: 'Pruebas Metrológicas Iniciales',
                subtitle:
                    'Verifique el funcionamiento del instrumento instalado',
              ),
              PasoPruebasMetrologicas(
                balanza: _balanzaInfo,
                esInicial: true,
                horaInicio: _controller.horaInicio,
                retornoCero: _controller.retornoCeroInicial,
                estabilidad: _controller.estabilidadInicial,
                onRetornoCeroChanged: (value) {
                  _controller.retornoCeroInicial = value;
                  _controller.markChanged();
                },
                onEstabilidadChanged: (value) {
                  _controller.estabilidadInicial = value;
                  _controller.markChanged();
                },
                excentricidadActiva: _controller.excentricidadRealizada,
                repetibilidadActiva: _controller.repetibilidadRealizada,
                linealidadActiva: _controller.linealidadRealizada,
                onExcentricidadActivaChanged: (value) =>
                    _controller.cambiarPrueba(
                        () => _controller.excentricidadRealizada = value),
                onRepetibilidadActivaChanged: (value) =>
                    _controller.cambiarPrueba(
                        () => _controller.repetibilidadRealizada = value),
                onLinealidadActivaChanged: (value) => _controller.cambiarPrueba(
                    () => _controller.linealidadRealizada = value),
                excentricidad: _controller.excentricidadInicial,
                repetibilidad: _controller.repetibilidadInicial,
                linealidad: _controller.linealidadInicial,
                onExcentricidadChanged: (value) {
                  _controller.excentricidadInicial = value;
                  _controller.markChanged();
                },
                onRepetibilidadChanged: (value) {
                  _controller.repetibilidadInicial = value;
                  _controller.markChanged();
                },
                onLinealidadChanged: (value) {
                  _controller.linealidadInicial = value;
                  _controller.markChanged();
                },
              ),
            ),
            _buildPaso(
              const ServiceStepHeader(
                title: 'Estado Final',
                subtitle: 'Complete la evaluación y cierre del servicio',
              ),
              PasoEstadoFinalWidget(
                comentarioGeneral: _controller.comentarioGeneral,
                recomendacion: _controller.recomendacion,
                estadoFisico: _controller.estadoFisico,
                estadoOperacional: _controller.estadoOperacional,
                estadoMetrologico: _controller.estadoMetrologico,
                onComentarioGeneralChanged: (value) {
                  _controller.comentarioGeneral = value;
                  _controller.markChanged();
                },
                onRecomendacionChanged: (value) {
                  _controller.recomendacion = value;
                  _controller.markChanged();
                },
                onEstadoFisicoChanged: (value) {
                  _controller.estadoFisico = value;
                  _controller.markChanged();
                },
                onEstadoOperacionalChanged: (value) {
                  _controller.estadoOperacional = value;
                  _controller.markChanged();
                },
                onEstadoMetrologicoChanged: (value) {
                  _controller.estadoMetrologico = value;
                  _controller.markChanged();
                },
                camposEstado: const [],
                onCampoChanged: (index, value, solution) {},
                horaInicio: _controller.horaInicio,
                horaFin: _controller.horaFin,
                onRegistrarHoraFin: () {
                  setState(() {
                    _controller.horaFin =
                        DateFormat('HH:mm:ss').format(DateTime.now());
                    _controller.markChanged();
                  });
                },
                fechaProxServicio: _controller.fechaProxServicio,
                onFechaProxServicioChanged: (value) {
                  setState(() {
                    _controller.fechaProxServicio = value;
                    _controller.markChanged();
                  });
                },
                recomendacionesOptions: _recomendacionesOptions,
                useLegacyEstados: true,
              ),
            ),
          ],
          currentStep: _controller.currentStep,
          onStepTapped: (paso) => _pasos.irA(context, paso),
          stepIssue: _stepIssue,
          nextLabel: isLast ? 'Finalizar' : 'Siguiente',
          nextColor: isLast ? const Color(0xFF3E7732) : const Color(0xFF498054),
          onNext: isLast
              ? _onFinalizar
              : () => _pasos.irA(context, _controller.currentStep + 1),
          onBack: _controller.currentStep > 0
              ? () => _pasos.irA(context, _controller.currentStep - 1)
              : null,
          // Salir es explícito (menú ⋮); Atrás solo retrocede entre pasos.
          onExit: () => salirGuardando(context, _controller),
          saveStatus: _saveStatus,
          onReadIndicator: (ctx) =>
              IndicatorReaderScreen.read(ctx, balanza: _balanzaInfo),
          balanzaInfo: buildServiceBalanzaInfo(
              widget.instrumentoData, widget.codMetrica),
        );
      },
    );
  }

  Widget _buildPaso(Widget header, Widget content) {
    return SingleChildScrollView(
      padding: ServiceNavPill.pagePadding(context),
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
