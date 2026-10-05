import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:service_met/database/soporte_tecnico/database_helper_mnt_prv_regular_stil.dart';
import 'package:service_met/models/service_session.dart';
import 'package:service_met/screens/calibracion/widgets/indicator_reader_screen.dart';
import 'package:service_met/screens/soporte_new/utils/balanza_info_helper.dart';
import 'package:service_met/screens/soporte_new/widgets/fin_servicio_screen.dart';
import 'package:service_met/screens/soporte_new/models/campo_estado.dart';
import 'package:service_met/screens/soporte_new/modulos/mnt_prv_regular/controllers/mnt_prv_regular_controller.dart';
import 'package:service_met/screens/soporte_new/modulos/mnt_prv_regular/models/mnt_prv_regular_model.dart';
import 'package:service_met/screens/soporte_new/modulos/mnt_prv_regular/widgets/steps/paso_pruebas_metrologicas.dart';
import 'package:service_met/screens/soporte_new/modulos/mnt_prv_regular/widgets/steps/paso_terminal_balanza_caja.dart';
import 'package:service_met/screens/soporte_new/widgets/shared/paso_estado_final_widget.dart';
import 'package:service_met/utils/top_alert.dart';
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

class StilMntPrvRegular extends StatefulWidget {
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

  const StilMntPrvRegular({
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
  State<StilMntPrvRegular> createState() => _StilMntPrvRegularState();
}

class _StilMntPrvRegularState extends State<StilMntPrvRegular> {
  late final MntPrvRegularController _controller;
  late final MntPrvRegularModel _model;
  late final BalanzaInfo _balanzaInfo;
  int _copyTickFinales = 0;
  bool _isLoading = true;

  static const _recomendacionesOptions = [
    'Diagnostico',
    'Mnt Preventivo Regular',
    'Mnt Preventivo Avanzado',
    'Mnt Correctivo',
    'Ajustes Metrológicos',
    'Calibración',
    'Sin recomendación',
  ];

  static const _steps = [
    StepData(
        title: 'Pruebas Iniciales',
        subtitle: 'Excentricidad, Repetibilidad, Linealidad',
        icon: AppIcons.laboratorio),
    StepData(
        title: 'Entorno de Instalación',
        subtitle: 'Vibración, Polvo, Temperatura, Humedad',
        icon: AppIcons.temperatura),
    StepData(
        title: 'Terminal',
        subtitle: 'Campos de inspección',
        icon: AppIcons.computadora),
    StepData(
        title: 'Balanza',
        subtitle: 'Campos de inspección',
        icon: AppIcons.balanza),
    StepData(
        title: 'Caja Sumadora',
        subtitle: 'Campos de inspección',
        icon: AppIcons.electrico),
    StepData(
        title: 'Pruebas Finales',
        subtitle: 'Excentricidad, Repetibilidad, Linealidad',
        icon: AppIcons.tareaLista),
    StepData(
        title: 'Estado Final',
        subtitle: 'Conclusión del servicio',
        icon: AppIcons.formularioCompleto),
  ];

  /// Menú ⋮: emitir el RIM del instrumento y registrar una oportunidad.
  late final _menu = SoporteMenu(
    controller: _controller,
    userName: widget.userName,
    clienteId: widget.clienteId,
    plantaCodigo: widget.plantaCodigo,
    otst: widget.secaValue,
    contextBuilder: () => OpportunityServiceContext.fromSupport(
      serviceName: 'Mantenimiento preventivo regular',
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
    _model = MntPrvRegularModel(
      sessionId: widget.sessionId,
      codMetrica: widget.codMetrica,
    );
    _controller = MntPrvRegularController(model: _model);
    _controller.secaValue = widget.secaValue;
    _controller.clienteNombre = widget.clienteNombre;
    _controller.plantaNombre = widget.plantaNombre;
    _controller.initCamposEstado();
    _setBalanzaData();
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

  void _setBalanzaData() {
    final inst = widget.instrumentoData;
    if (inst == null) return;

    _controller.categoriaBalanza = inst['categoria']?.toString() ??
        inst['categoria_balanza']?.toString() ??
        '';
    _controller.codInt =
        inst['cod_interno']?.toString() ?? inst['cod_int']?.toString() ?? '';
    _controller.tipoEquipo = inst['tipo_instrumento']?.toString() ??
        inst['tipo']?.toString() ??
        inst['instrumento']?.toString() ??
        '';
    _controller.marca = inst['marca']?.toString() ?? '';
    _controller.modelo = inst['modelo']?.toString() ?? '';
    _controller.serie =
        inst['inf_serie']?.toString() ?? inst['serie']?.toString() ?? '';
    _controller.unidades =
        inst['unidad']?.toString() ?? inst['unidades']?.toString() ?? '';
    _controller.numCeldas =
        inst['n_celdas']?.toString() ?? inst['num_celdas']?.toString() ?? '';
    _controller.ubicacion = inst['ubicacion']?.toString() ?? '';
    _controller.capMax1 = inst['cap_max1']?.toString() ?? '';
    _controller.d1 = inst['d1']?.toString() ?? '';
    _controller.e1 = inst['e1']?.toString() ?? '';
    _controller.dec1 = inst['dec1']?.toString() ?? '';
    _controller.capMax2 = inst['cap_max2']?.toString() ?? '';
    _controller.d2 = inst['d2']?.toString() ?? '';
    _controller.e2 = inst['e2']?.toString() ?? '';
    _controller.dec2 = inst['dec2']?.toString() ?? '';
    _controller.capMax3 = inst['cap_max3']?.toString() ?? '';
    _controller.d3 = inst['d3']?.toString() ?? '';
    _controller.e3 = inst['e3']?.toString() ?? '';
    _controller.dec3 = inst['dec3']?.toString() ?? '';
    _controller.infBal = inst['_modifiedFields']?.toString() ?? '';
    _controller.razonSocial = widget.clienteRazonSocial;
    _controller.dirPlanta = widget.plantaDireccion;
    _controller.depPlanta = widget.plantaDepartamento;
    _controller.codPlanta = widget.plantaCodigo;
    _controller.personal = widget.userName;
  }

  Future<void> _loadExistingData() async {
    setState(() => _isLoading = true);
    try {
      final dbLegacy = DatabaseHelperMntPrvRegularStil();
      final registro = await dbLegacy.getRegistroBySeca(
        widget.secaValue,
        widget.sessionId,
      );
      if (registro != null && mounted) {
        await _controller.loadExistingSession(widget.sessionId, registro);
      }
    } catch (e) {
      debugPrint('Error cargando datos existentes MNT PRV REGULAR: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _camposCompletos(List<CampoEstado> campos) {
    return campos.every((c) => c.value.isNotEmpty);
  }

  /// Qué le falta al paso [step] para darlo por completo; null si nada. Lo
  /// usan "Siguiente" y el panel ≡ de pasos.
  String? _stepIssue(int step) {
    switch (step) {
      case 0:
        if (_controller.retornoCeroInicial.isEmpty) {
          return 'Seleccione Retorno a Cero en Pruebas Iniciales';
        }
        if (_controller.estabilidadInicial.isEmpty) {
          return 'Seleccione Estabilidad en Pruebas Iniciales';
        }
        return _faltaEnPruebas(iniciales: true);
      case 1:
        if (!_camposCompletos(_controller.camposEntorno)) {
          return 'Complete todos los campos de Entorno de Instalación';
        }
        return null;
      case 2:
        if (!_camposCompletos(_controller.camposTerminal)) {
          return 'Complete todos los campos de Terminal';
        }
        return null;
      case 3:
        if (!_camposCompletos(_controller.camposBalanza)) {
          return 'Complete todos los campos de Balanza';
        }
        return null;
      case 4:
        if (!_camposCompletos(_controller.camposCajaSumadora)) {
          return 'Complete todos los campos de Caja Sumadora';
        }
        return null;
      case 5:
        if (_controller.retornoCeroFinal.isEmpty) {
          return 'Seleccione Retorno a Cero en Pruebas Finales';
        }
        if (_controller.estabilidadFinal.isEmpty) {
          return 'Seleccione Estabilidad en Pruebas Finales';
        }
        return _faltaEnPruebas(iniciales: false);
      case 6:
        if (_controller.comentarioGeneral.isEmpty) {
          return 'Complete el Comentario General';
        }
        if (_controller.recomendacion.isEmpty) {
          return 'Seleccione una Recomendación';
        }
        if (_controller.fechaProxServicio.isEmpty) {
          return 'Seleccione la Fecha del Próximo Servicio';
        }
        if (_controller.estadoFisico.isEmpty ||
            _controller.estadoOperacional.isEmpty ||
            _controller.estadoMetrologico.isEmpty) {
          return 'Complete todos los estados finales';
        }
        if (_controller.horaFin.isEmpty) {
          return 'Registre la Hora Final del servicio';
        }
        return null;
      default:
        return null;
    }
  }

  String? _faltaEnPruebas({required bool iniciales}) => faltaEnPruebas(
        momento: iniciales ? 'iniciales' : 'finales',
        excentricidadRealizada: _controller.excentricidadRealizada,
        excentricidad: iniciales
            ? _controller.excentricidadInicial
            : _controller.excentricidadFinal,
        repetibilidadRealizada: _controller.repetibilidadRealizada,
        repetibilidad: iniciales
            ? _controller.repetibilidadInicial
            : _controller.repetibilidadFinal,
        linealidadRealizada: _controller.linealidadRealizada,
        linealidad: iniciales
            ? _controller.linealidadInicial
            : _controller.linealidadFinal,
      );

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
            tableNameDefault: 'mnt_prv_regular',
            tipoServicio: 'MNT PREVENTIVO REGULAR',
          ),
        ),
      ),
    );
  }

  void _onCopiarFinales() {
    _controller.copiarPruebasInicialesAFinales();
    setState(() => _copyTickFinales++);
    TopAlert.show(context, 'Datos copiados de pruebas iniciales a finales');
  }

  void _onRegistrarHoraFin() {
    setState(() {
      _controller.horaFin = DateFormat('HH:mm:ss').format(DateTime.now());
      _controller.markChanged();
    });
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
    if (_isLoading) {
      return Scaffold(
        appBar:
            ServiceAppBar(title: 'Mnt Preventivo Regular', centerTitle: true),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final isLast = _controller.currentStep == _controller.totalSteps - 1;
        return ServiceWorkspaceLayout(
          title: 'Mnt Preventivo Regular',
          menuActions: _menu.actions,
          exitSuggestion: _menu.exitSuggestion,
          steps: _steps,
          stepWidgets: [
            // ── Paso 0: Pruebas Metrológicas Iniciales ──────────────
            _buildPaso(
              const ServiceStepHeader(
                title: 'Pruebas Metrológicas Iniciales',
                subtitle: 'Antes del mantenimiento',
              ),
              PasoPruebasMetrologicas(
                balanza: _balanzaInfo,
                esInicial: true,
                horaInicio: _controller.horaInicio,
                retornoCero: _controller.retornoCeroInicial,
                estabilidad: _controller.estabilidadInicial,
                onRetornoCeroChanged: (v) {
                  _controller.retornoCeroInicial = v;
                  _controller.markChanged();
                },
                onEstabilidadChanged: (v) {
                  _controller.estabilidadInicial = v;
                  _controller.markChanged();
                },
                excentricidadActiva: _controller.excentricidadRealizada,
                repetibilidadActiva: _controller.repetibilidadRealizada,
                linealidadActiva: _controller.linealidadRealizada,
                onExcentricidadActivaChanged: (v) {
                  _controller.excentricidadRealizada = v;
                  _controller.markChanged();
                },
                onRepetibilidadActivaChanged: (v) {
                  _controller.repetibilidadRealizada = v;
                  _controller.markChanged();
                },
                onLinealidadActivaChanged: (v) {
                  _controller.linealidadRealizada = v;
                  _controller.markChanged();
                },
                excentricidad: _controller.excentricidadInicial,
                repetibilidad: _controller.repetibilidadInicial,
                linealidad: _controller.linealidadInicial,
                onExcentricidadChanged: (d) {
                  _controller.excentricidadInicial = d;
                  _controller.markChanged();
                },
                onRepetibilidadChanged: (d) {
                  _controller.repetibilidadInicial = d;
                  _controller.markChanged();
                },
                onLinealidadChanged: (d) {
                  _controller.linealidadInicial = d;
                  _controller.markChanged();
                },
              ),
            ),
            // ── Paso 1: Entorno de Instalación ──────────────────────
            _buildPaso(
              const ServiceStepHeader(
                title: 'Entorno de Instalación',
                subtitle: 'Condiciones del entorno del equipo',
              ),
              PasoEntorno(
                campos: _controller.camposEntorno,
                onChanged: (i, v, s) =>
                    _onCampoChanged(_controller.camposEntorno, i, v, s),
                seca: widget.secaValue,
                codMetrica: widget.codMetrica,
              ),
            ),
            // ── Paso 2: Terminal ────────────────────────────────────
            _buildPaso(
              const ServiceStepHeader(
                title: 'Terminal',
                subtitle: 'Complete el estado de cada campo',
              ),
              PasoTerminal(
                campos: _controller.camposTerminal,
                onChanged: (i, v, s) =>
                    _onCampoChanged(_controller.camposTerminal, i, v, s),
                seca: widget.secaValue,
                codMetrica: widget.codMetrica,
              ),
            ),
            // ── Paso 3: Balanza ─────────────────────────────────────
            _buildPaso(
              const ServiceStepHeader(
                title: 'Balanza',
                subtitle: 'Complete el estado de cada campo',
              ),
              PasoBalanza(
                campos: _controller.camposBalanza,
                onChanged: (i, v, s) =>
                    _onCampoChanged(_controller.camposBalanza, i, v, s),
                seca: widget.secaValue,
                codMetrica: widget.codMetrica,
              ),
            ),
            // ── Paso 4: Caja Sumadora ───────────────────────────────
            _buildPaso(
              const ServiceStepHeader(
                title: 'Caja Sumadora',
                subtitle: 'Complete el estado de cada campo',
              ),
              PasoCajaSumadora(
                campos: _controller.camposCajaSumadora,
                onChanged: (i, v, s) =>
                    _onCampoChanged(_controller.camposCajaSumadora, i, v, s),
                seca: widget.secaValue,
                codMetrica: widget.codMetrica,
              ),
            ),
            // ── Paso 5: Pruebas Metrológicas Finales ────────────────
            _buildPaso(
              const ServiceStepHeader(
                title: 'Pruebas Metrológicas Finales',
                subtitle: 'Después del mantenimiento',
              ),
              PasoPruebasMetrologicas(
                balanza: _balanzaInfo,
                esInicial: false,
                retornoCero: _controller.retornoCeroFinal,
                estabilidad: _controller.estabilidadFinal,
                onRetornoCeroChanged: (v) {
                  _controller.retornoCeroFinal = v;
                  _controller.markChanged();
                },
                onEstabilidadChanged: (v) {
                  _controller.estabilidadFinal = v;
                  _controller.markChanged();
                },
                excentricidadActiva: _controller.excentricidadRealizada,
                repetibilidadActiva: _controller.repetibilidadRealizada,
                linealidadActiva: _controller.linealidadRealizada,
                onExcentricidadActivaChanged: (v) {
                  _controller.excentricidadRealizada = v;
                  _controller.markChanged();
                },
                onRepetibilidadActivaChanged: (v) {
                  _controller.repetibilidadRealizada = v;
                  _controller.markChanged();
                },
                onLinealidadActivaChanged: (v) {
                  _controller.linealidadRealizada = v;
                  _controller.markChanged();
                },
                excentricidad: _controller.excentricidadFinal,
                repetibilidad: _controller.repetibilidadFinal,
                linealidad: _controller.linealidadFinal,
                onExcentricidadChanged: (d) {
                  _controller.excentricidadFinal = d;
                  _controller.markChanged();
                },
                onRepetibilidadChanged: (d) {
                  _controller.repetibilidadFinal = d;
                  _controller.markChanged();
                },
                onLinealidadChanged: (d) {
                  _controller.linealidadFinal = d;
                  _controller.markChanged();
                },
                copyTick: _copyTickFinales,
                onCopiarDeIniciales: _onCopiarFinales,
              ),
            ),
            // ── Paso 6: Estado Final ────────────────────────────────
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
                horaInicio: _controller.horaInicio,
                horaFin: _controller.horaFin,
                onRegistrarHoraFin: _onRegistrarHoraFin,
                fechaProxServicio: _controller.fechaProxServicio,
                onFechaProxServicioChanged: (v) {
                  setState(() {
                    _controller.fechaProxServicio = v;
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
          nextColor: isLast ? const Color(0xFF3e7732) : const Color(0xFF498054),
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
