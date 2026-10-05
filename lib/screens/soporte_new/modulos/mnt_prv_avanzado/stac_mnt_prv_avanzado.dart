import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:service_met/database/soporte_tecnico/database_helper_mnt_prv_avanzado_stac.dart';
import 'package:service_met/models/service_session.dart';
import 'package:service_met/screens/calibracion/widgets/indicator_reader_screen.dart';
import 'package:service_met/screens/soporte_new/utils/balanza_info_helper.dart';
import 'package:service_met/screens/soporte_new/widgets/fin_servicio_screen.dart';
import 'package:service_met/screens/soporte_new/models/campo_estado.dart';
import 'package:service_met/screens/soporte_new/modulos/mnt_prv_avanzado/controllers/mnt_prv_avanzado_controller.dart';
import 'package:service_met/screens/soporte_new/modulos/mnt_prv_avanzado/models/mnt_prv_avanzado_model.dart';
import 'package:service_met/screens/soporte_new/modulos/mnt_prv_avanzado/widgets/steps/paso_pruebas_metrologicas.dart';
import 'package:service_met/screens/soporte_new/modulos/mnt_prv_avanzado/widgets/steps/paso_terminal_balanza_caja.dart';
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

class StacMntPrvAvanzado extends StatefulWidget {
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

  const StacMntPrvAvanzado({
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
  State<StacMntPrvAvanzado> createState() => _StacMntPrvAvanzadoState();
}

class _StacMntPrvAvanzadoState extends State<StacMntPrvAvanzado> {
  late final MntPrvAvanzadoController _controller;
  late final MntPrvAvanzadoModel _model;
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
        title: 'Lozas y Fundaciones',
        subtitle: 'Campos de inspección',
        icon: AppIcons.cimientos),
    StepData(
        title: 'Limpieza y Drenaje',
        subtitle: 'Campos de inspección',
        icon: AppIcons.limpieza),
    StepData(
        title: 'Chequeo General',
        subtitle: 'Campos de inspección',
        icon: AppIcons.lista),
    StepData(
        title: 'Verif. Eléctricas',
        subtitle: 'Campos de inspección',
        icon: AppIcons.electrico),
    StepData(
        title: 'Protección / Células',
        subtitle: 'Rayos + Células de carga',
        icon: AppIcons.flash),
    StepData(
        title: 'Terminal / Calibración',
        subtitle: 'Terminal + Balanza apta',
        icon: AppIcons.computadora),
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
      serviceName: 'Mantenimiento preventivo avanzado',
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
    _model = MntPrvAvanzadoModel(
      sessionId: widget.sessionId,
      codMetrica: widget.codMetrica,
    );
    _controller = MntPrvAvanzadoController(model: _model);
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
      final dbLegacy = DatabaseHelperMntPrvAvanzadoStac();
      final registro = await dbLegacy.getRegistroBySeca(
        widget.secaValue,
        widget.sessionId,
      );
      if (registro != null && mounted) {
        await _controller.loadExistingSession(widget.sessionId, registro);
      }
    } catch (e) {
      debugPrint('Error cargando datos existentes MNT PRV AVANZADO: $e');
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
        if (!_camposCompletos(_controller.camposLozas)) {
          return 'Complete todos los campos de Lozas y Fundaciones';
        }
        return null;
      case 2:
        if (!_camposCompletos(_controller.camposLimpieza)) {
          return 'Complete todos los campos de Limpieza y Drenaje';
        }
        return null;
      case 3:
        if (!_camposCompletos(_controller.camposChequeo)) {
          return 'Complete todos los campos de Chequeo General';
        }
        return null;
      case 4:
        if (!_camposCompletos(_controller.camposElectricas)) {
          return 'Complete todos los campos de Verif. Eléctricas';
        }
        return null;
      case 5:
        if (!_camposCompletos(_controller.camposProteccionCeldas)) {
          return 'Complete todos los campos de Protección / Células';
        }
        return null;
      case 6:
        if (!_camposCompletos(_controller.camposTerminalCalibracion)) {
          return 'Complete todos los campos de Terminal / Calibración';
        }
        return null;
      case 7:
        if (_controller.retornoCeroFinal.isEmpty) {
          return 'Seleccione Retorno a Cero en Pruebas Finales';
        }
        if (_controller.estabilidadFinal.isEmpty) {
          return 'Seleccione Estabilidad en Pruebas Finales';
        }
        return _faltaEnPruebas(iniciales: false);
      case 8:
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
            tableNameDefault: 'mnt_prv_avanzado',
            tipoServicio: 'MNT PREVENTIVO AVANZADO',
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
            ServiceAppBar(title: 'Mnt Preventivo Avanzado', centerTitle: true),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final isLast = _controller.currentStep == _controller.totalSteps - 1;
        return ServiceWorkspaceLayout(
          title: 'Mnt Preventivo Avanzado',
          menuActions: _menu.actions,
          exitSuggestion: _menu.exitSuggestion,
          steps: _steps,
          stepWidgets: [
            // ── Paso 0: Pruebas Metrológicas Iniciales ───────────
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
            // ── Paso 1: Lozas y Fundaciones ──────────────────────
            _buildPaso(
              const ServiceStepHeader(
                title: 'Lozas y Fundaciones',
                subtitle: 'Complete el estado de cada campo',
              ),
              PasoInspeccionSimple(
                campos: _controller.camposLozas,
                onChanged: (i, v, s) =>
                    _onCampoChanged(_controller.camposLozas, i, v, s),
                seca: widget.secaValue,
                codMetrica: widget.codMetrica,
              ),
            ),
            // ── Paso 2: Limpieza y Drenaje ───────────────────────
            _buildPaso(
              const ServiceStepHeader(
                title: 'Limpieza y Drenaje',
                subtitle: 'Complete el estado de cada campo',
              ),
              PasoInspeccionSimple(
                campos: _controller.camposLimpieza,
                onChanged: (i, v, s) =>
                    _onCampoChanged(_controller.camposLimpieza, i, v, s),
                seca: widget.secaValue,
                codMetrica: widget.codMetrica,
              ),
            ),
            // ── Paso 3: Chequeo General ──────────────────────────
            _buildPaso(
              const ServiceStepHeader(
                title: 'Chequeo General',
                subtitle: 'Complete el estado de cada campo',
              ),
              PasoInspeccionSimple(
                campos: _controller.camposChequeo,
                onChanged: (i, v, s) =>
                    _onCampoChanged(_controller.camposChequeo, i, v, s),
                seca: widget.secaValue,
                codMetrica: widget.codMetrica,
              ),
            ),
            // ── Paso 4: Verificaciones Eléctricas ────────────────
            _buildPaso(
              const ServiceStepHeader(
                title: 'Verificaciones Eléctricas',
                subtitle: 'Complete el estado de cada campo',
              ),
              PasoInspeccionSimple(
                campos: _controller.camposElectricas,
                onChanged: (i, v, s) =>
                    _onCampoChanged(_controller.camposElectricas, i, v, s),
                seca: widget.secaValue,
                codMetrica: widget.codMetrica,
              ),
            ),
            // ── Paso 5: Protección / Células ─────────────────────
            _buildPaso(
              const ServiceStepHeader(
                title: 'Protección contra Rayos y Células',
                subtitle: 'Complete el estado de cada campo',
              ),
              PasoInspeccionDoble(
                campos: _controller.camposProteccionCeldas,
                onChanged: (i, v, s) => _onCampoChanged(
                    _controller.camposProteccionCeldas, i, v, s),
                seca: widget.secaValue,
                codMetrica: widget.codMetrica,
                seccion1: const SeccionData(
                  title: 'PROTECCIÓN CONTRA RAYOS',
                  subtitle: 'Sistema de protección y conexión a tierra',
                  icon: AppIcons.flash,
                  color: Colors.orange,
                  count: 4,
                ),
                seccion2: const SeccionData(
                  title: 'VERIFICACIONES DE CÉLULAS',
                  subtitle: 'Células de carga, lubricación y protectores',
                  icon: AppIcons.suciedad,
                  color: Colors.indigo,
                  count: 7,
                ),
              ),
            ),
            // ── Paso 6: Terminal / Calibración ───────────────────
            _buildPaso(
              const ServiceStepHeader(
                title: 'Terminal y Calibración',
                subtitle: 'Complete el estado de cada campo',
              ),
              PasoInspeccionDoble(
                campos: _controller.camposTerminalCalibracion,
                onChanged: (i, v, s) => _onCampoChanged(
                    _controller.camposTerminalCalibracion, i, v, s),
                seca: widget.secaValue,
                codMetrica: widget.codMetrica,
                seccion1: const SeccionData(
                  title: 'TERMINAL',
                  subtitle: 'Carcasa, display, teclado, pila, etc.',
                  icon: AppIcons.computadora,
                  color: Colors.purple,
                  count: 8,
                ),
                seccion2: const SeccionData(
                  title: 'CALIBRACIÓN',
                  subtitle: 'Balanza apta para verificación NB23001',
                  icon: AppIcons.filtros,
                  color: Colors.green,
                  count: 1,
                ),
              ),
            ),
            // ── Paso 7: Pruebas Metrológicas Finales ─────────────
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
            // ── Paso 8: Estado Final ─────────────────────────────
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
