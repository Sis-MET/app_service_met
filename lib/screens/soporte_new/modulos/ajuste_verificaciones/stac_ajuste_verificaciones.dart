import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:service_met/models/service_session.dart';
import 'package:service_met/screens/calibracion/widgets/indicator_reader_screen.dart';
import 'package:service_met/screens/soporte_new/modulos/mnt_prv_regular/widgets/steps/paso_pruebas_metrologicas.dart';
import 'package:service_met/screens/soporte_new/utils/balanza_info_helper.dart';
import 'package:service_met/screens/soporte_new/widgets/fin_servicio_screen.dart';
import 'package:service_met/screens/soporte_new/widgets/shared/paso_estado_final_widget.dart';
import 'package:service_met/utils/top_alert.dart';
import 'package:service_met/widgets/service_ui/input_decoration.dart';
import 'package:service_met/widgets/service_ui/nav_pill.dart';
import 'package:service_met/widgets/service_ui/service_app_bar.dart';
import 'package:service_met/widgets/service_ui/service_workspace_layout.dart';
import 'package:service_met/widgets/service_ui/step_indicator.dart';
import 'package:service_met/screens/oportunidades/models/opportunity_service_context.dart';
import 'package:service_met/screens/soporte_new/utils/menu_soporte.dart';
import 'package:service_met/screens/soporte_new/utils/pasos_soporte.dart';
import 'package:service_met/screens/soporte_new/utils/requisitos_pruebas.dart';
import 'package:service_met/screens/soporte_new/utils/salida_servicio.dart';

import 'controllers/ajuste_verificaciones_controller.dart';
import 'models/ajuste_verificaciones_model.dart';
import '../../../../theme/app_icons.dart';

class StacAjusteVerificaciones extends StatefulWidget {
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

  const StacAjusteVerificaciones({
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
  State<StacAjusteVerificaciones> createState() =>
      _StacAjusteVerificacionesState();
}

class _StacAjusteVerificacionesState extends State<StacAjusteVerificaciones> {
  late final AjusteVerificacionesController _controller;
  late final BalanzaInfo _balanzaInfo;
  int _copyTickFinales = 0;
  bool _isLoading = true;

  static const _steps = [
    StepData(
      title: 'Pruebas Iniciales',
      subtitle: 'Metrología inicial',
      icon: AppIcons.laboratorio,
    ),
    StepData(
      title: 'Pruebas Finales',
      subtitle: 'Metrología final',
      icon: AppIcons.tareaLista,
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
      serviceName: 'Ajuste de verificaciones',
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
    _controller = AjusteVerificacionesController(
      model: AjusteVerificacionesModel(
        sessionId: widget.sessionId,
        codMetrica: widget.codMetrica,
        secaValue: widget.secaValue,
      ),
    );
    _controller.secaValue = widget.secaValue;
    _controller.clienteNombre = widget.clienteNombre;
    _controller.plantaNombre = widget.plantaNombre;
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
      debugPrint('Error restaurando ajuste de verificaciones: $error');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Qué le falta al paso [step] para darlo por completo; null si nada. Lo
  /// usan "Siguiente" y el panel ≡ de pasos.
  String? _stepIssue(int step) {
    switch (step) {
      case 0:
        if (_controller.retornoCeroInicial.isEmpty ||
            _controller.estabilidadInicial.isEmpty) {
          return 'Complete retorno a cero y estabilidad de las pruebas iniciales';
        }
        return _faltaEnPruebas(iniciales: true);
      case 1:
        if (_controller.retornoCeroFinal.isEmpty ||
            _controller.estabilidadFinal.isEmpty) {
          return 'Complete retorno a cero y estabilidad de las pruebas finales';
        }
        return _faltaEnPruebas(iniciales: false);
      case 2:
        if (_controller.comentarioGeneral.isEmpty) {
          return 'Complete el comentario general';
        }
        if (_controller.recomendacion.isEmpty) {
          return 'Seleccione una recomendación';
        }
        if (_controller.fechaProxServicio.isEmpty) {
          return 'Seleccione la fecha del próximo servicio';
        }
        if (_controller.estadoFisico.isEmpty ||
            _controller.estadoOperacional.isEmpty ||
            _controller.estadoMetrologico.isEmpty) {
          return 'Complete todos los estados finales';
        }
        if (_controller.horaFin.isEmpty) {
          return 'Registre la hora final del servicio';
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
          tableName: 'ajustes_metrologicos',
          config: const FinServicioConfig(
            tableNameDefault: 'ajustes_metrologicos',
            tipoServicio: 'AJUSTE DE VERIFICACIONES',
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
        appBar:
            ServiceAppBar(title: 'Ajuste de Verificaciones', centerTitle: true),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final isLast = _controller.currentStep == _controller.totalSteps - 1;
        return ServiceWorkspaceLayout(
          title: 'Ajuste de Verificaciones',
          menuActions: _menu.actions,
          exitSuggestion: _menu.exitSuggestion,
          steps: _steps,
          stepWidgets: [
            _buildPaso(
              const ServiceStepHeader(
                title: 'Pruebas Metrológicas Iniciales',
                subtitle: 'Estado del instrumento antes del ajuste',
              ),
              _buildMetrology(esInicial: true),
            ),
            _buildPaso(
              const ServiceStepHeader(
                title: 'Pruebas Metrológicas Finales',
                subtitle: 'Estado del instrumento después del ajuste',
              ),
              _buildMetrology(esInicial: false),
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

  Widget _buildMetrology({required bool esInicial}) {
    return PasoPruebasMetrologicas(
      balanza: _balanzaInfo,
      esInicial: esInicial,
      horaInicio: esInicial ? _controller.horaInicio : null,
      retornoCero: esInicial
          ? _controller.retornoCeroInicial
          : _controller.retornoCeroFinal,
      estabilidad: esInicial
          ? _controller.estabilidadInicial
          : _controller.estabilidadFinal,
      onRetornoCeroChanged: (value) {
        if (esInicial) {
          _controller.retornoCeroInicial = value;
        } else {
          _controller.retornoCeroFinal = value;
        }
        _controller.markChanged();
      },
      onEstabilidadChanged: (value) {
        if (esInicial) {
          _controller.estabilidadInicial = value;
        } else {
          _controller.estabilidadFinal = value;
        }
        _controller.markChanged();
      },
      excentricidadActiva: _controller.excentricidadRealizada,
      repetibilidadActiva: _controller.repetibilidadRealizada,
      linealidadActiva: _controller.linealidadRealizada,
      onExcentricidadActivaChanged: (value) => _controller
          .cambiarPrueba(() => _controller.excentricidadRealizada = value),
      onRepetibilidadActivaChanged: (value) => _controller
          .cambiarPrueba(() => _controller.repetibilidadRealizada = value),
      onLinealidadActivaChanged: (value) => _controller
          .cambiarPrueba(() => _controller.linealidadRealizada = value),
      excentricidad: esInicial
          ? _controller.excentricidadInicial
          : _controller.excentricidadFinal,
      repetibilidad: esInicial
          ? _controller.repetibilidadInicial
          : _controller.repetibilidadFinal,
      linealidad: esInicial
          ? _controller.linealidadInicial
          : _controller.linealidadFinal,
      onExcentricidadChanged: (value) {
        if (esInicial) {
          _controller.excentricidadInicial = value;
        } else {
          _controller.excentricidadFinal = value;
        }
        _controller.markChanged();
      },
      onRepetibilidadChanged: (value) {
        if (esInicial) {
          _controller.repetibilidadInicial = value;
        } else {
          _controller.repetibilidadFinal = value;
        }
        _controller.markChanged();
      },
      onLinealidadChanged: (value) {
        if (esInicial) {
          _controller.linealidadInicial = value;
        } else {
          _controller.linealidadFinal = value;
        }
        _controller.markChanged();
      },
      copyTick: esInicial ? 0 : _copyTickFinales,
      onCopiarDeIniciales: esInicial ? null : _onCopiarFinales,
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
