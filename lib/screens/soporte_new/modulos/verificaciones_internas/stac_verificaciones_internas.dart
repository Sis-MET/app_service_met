import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:service_met/screens/calibracion/widgets/indicator_reader_screen.dart';
import 'package:service_met/screens/soporte_new/utils/balanza_info_helper.dart';
import 'package:service_met/screens/soporte_new/models/campo_estado.dart';
import 'package:service_met/screens/soporte_new/widgets/fin_servicio_screen.dart';
import 'package:service_met/screens/soporte_new/widgets/shared/bulk_estado_toggle.dart';
import 'package:service_met/screens/soporte_new/widgets/shared/campo_inspeccion_widget.dart';
import 'package:service_met/screens/soporte_new/modulos/mnt_prv_avanzado/widgets/steps/paso_pruebas_metrologicas.dart';
import 'package:service_met/screens/soporte_new/widgets/shared/paso_estado_final_widget.dart';
import 'package:service_met/widgets/service_ui/input_decoration.dart';
import 'package:service_met/widgets/service_ui/nav_pill.dart';
import 'package:service_met/widgets/service_ui/service_app_bar.dart';
import 'package:service_met/widgets/service_ui/service_workspace_layout.dart';
import 'package:service_met/widgets/service_ui/step_indicator.dart';
import 'package:service_met/screens/oportunidades/models/opportunity_service_context.dart';
import 'package:service_met/screens/oportunidades/widgets/opportunity_menu_action.dart';
import 'package:service_met/screens/soporte_new/utils/pasos_soporte.dart';
import 'package:service_met/screens/soporte_new/utils/requisitos_pruebas.dart';
import 'package:service_met/screens/soporte_new/utils/salida_servicio.dart';

import 'controllers/verificaciones_internas_controller.dart';
import 'models/verificaciones_internas_model.dart';

class StacVerificacionesInternas extends StatefulWidget {
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

  const StacVerificacionesInternas({
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
  State<StacVerificacionesInternas> createState() =>
      _StacVerificacionesInternasState();
}

class _StacVerificacionesInternasState
    extends State<StacVerificacionesInternas> {
  late VerificacionesInternasController _controller;
  bool _isLoading = true;
  BulkEstadoMode _bulkEstadoMode = BulkEstadoMode.none;

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
        title: 'Inspección visual',
        subtitle: 'Estado y condiciones',
        icon: Icons.visibility_outlined),
    StepData(
        title: 'Pruebas metrológicas',
        subtitle: 'Excentricidad, repetibilidad y linealidad',
        icon: Icons.science_outlined),
    StepData(
        title: 'Estado final',
        subtitle: 'Cierre del servicio',
        icon: Icons.assignment_turned_in_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _controller = VerificacionesInternasController(
      model: VerificacionesInternasModel(
        sessionId: widget.sessionId,
        codMetrica: widget.codMetrica,
        secaValue: widget.secaValue,
      ),
    );
    _controller.secaValue = widget.secaValue;
    _controller.clienteNombre = widget.clienteNombre;
    _controller.plantaNombre = widget.plantaNombre;
    _controller.initCamposEstado();
    _controller.camposEstado
      ..clear()
      ..addAll([
        CampoEstado(nombre: 'Espaciamiento topes longitudinales'),
        CampoEstado(nombre: 'Espaciamiento topes frontales'),
        CampoEstado(nombre: 'Limpieza del puente de pesaje'),
        CampoEstado(nombre: 'Limpieza debajo del puente'),
      ]);
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
      debugPrint('Error restaurando verificaciones internas: $error');
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
    _controller.tipoEquipo =
        data['tipo_instrumento']?.toString() ?? data['tipo']?.toString() ?? '';
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
      if (_bulkEstadoMode != BulkEstadoMode.none) {
        _bulkEstadoMode = BulkEstadoMode.none;
      }
      setState(() {});
    }
  }

  /// Qué le falta al paso [step] para darlo por completo; null si nada. Lo
  /// usan "Siguiente" y el panel ≡ de pasos.
  String? _stepIssue(int step) {
    switch (step) {
      case 0:
        if (_controller.camposEstado.any((field) => field.value.isEmpty)) {
          return 'Complete el estado de cada punto de la inspección visual';
        }
        if (_controller.retornoCeroInicial.isEmpty ||
            _controller.estabilidadInicial.isEmpty) {
          return 'Complete retorno a cero y estabilidad';
        }
        return null;
      case 1:
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
          tableName: 'verificaciones_internas',
          config: const FinServicioConfig(
            tableNameDefault: 'verificaciones_internas',
            additionalWhere: '',
            tipoServicio: 'VERIFICACIONES INTERNAS',
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
        appBar:
            ServiceAppBar(title: 'Verificaciones Internas', centerTitle: true),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final isLast = _controller.currentStep == _steps.length - 1;
        return ServiceWorkspaceLayout(
          title: 'Verificaciones Internas',
          menuActions: [
            OpportunityMenuAction(
              contextBuilder: () => OpportunityServiceContext.fromSupport(
                serviceName: 'Verificaciones internas',
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
            _buildPasoInspeccion(),
            _buildPasoPruebas(),
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
          onReadIndicator: (ctx) => IndicatorReaderScreen.read(ctx,
              balanza: buildCalBalanzaInfo(
                  widget.instrumentoData, widget.codMetrica)),
          balanzaInfo: buildServiceBalanzaInfo(
              widget.instrumentoData, widget.codMetrica),
        );
      },
    );
  }

  Widget _buildPasoInspeccion() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SingleChildScrollView(
      padding: ServiceNavPill.pagePadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ServiceStepHeader(
            title: 'Inspección',
            subtitle: 'Complete el estado de cada campo de inspección',
          ),
          const SizedBox(height: 24),
          _buildAllGoodCard(),
          const SizedBox(height: 16),
          ..._controller.camposEstado.map((campo) => CampoInspeccionWidget(
                campoEstado: campo,
                onChanged: (value, solutionValue) {
                  _onCampoChanged(
                    _controller.camposEstado.indexOf(campo),
                    value,
                    solutionValue,
                  );
                },
                seca: widget.secaValue,
                codMetrica: widget.codMetrica,
              )),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            value: _controller.retornoCeroInicial.isEmpty
                ? null
                : _controller.retornoCeroInicial,
            decoration: serviceInputDeco('Estado retorno a cero', isDark),
            items: const [
              DropdownMenuItem(value: '1 Bueno', child: Text('1 Bueno')),
              DropdownMenuItem(
                  value: '2 Aceptable', child: Text('2 Aceptable')),
              DropdownMenuItem(value: '3 Malo', child: Text('3 Malo')),
              DropdownMenuItem(
                  value: '4 No aplica', child: Text('4 No aplica')),
            ],
            onChanged: (value) {
              if (value == null) return;
              _controller.retornoCeroInicial = value;
              _onFieldChanged();
            },
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: _controller.estabilidadInicial.isEmpty
                ? null
                : _controller.estabilidadInicial,
            decoration: serviceInputDeco('Estado de estabilización', isDark),
            items: const [
              DropdownMenuItem(value: '1 Bueno', child: Text('1 Bueno')),
              DropdownMenuItem(
                  value: '2 Aceptable', child: Text('2 Aceptable')),
              DropdownMenuItem(value: '3 Malo', child: Text('3 Malo')),
              DropdownMenuItem(
                  value: '4 No aplica', child: Text('4 No aplica')),
            ],
            onChanged: (value) {
              if (value == null) return;
              _controller.estabilidadInicial = value;
              _onFieldChanged();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPasoPruebas() {
    return SingleChildScrollView(
      padding: ServiceNavPill.pagePadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ServiceStepHeader(
            title: 'Pruebas Iniciales',
            subtitle: 'Pruebas metrológicas iniciales',
          ),
          const SizedBox(height: 24),
          PasoPruebasMetrologicas(
            balanza:
                buildCalBalanzaInfo(widget.instrumentoData, widget.codMetrica),
            esInicial: true,
            showRetornoCero: false,
            horaInicio: _controller.horaInicio,
            retornoCero: _controller.retornoCeroInicial,
            estabilidad: _controller.estabilidadInicial,
            onRetornoCeroChanged: (v) {
              _controller.retornoCeroInicial = v;
              _onFieldChanged();
            },
            onEstabilidadChanged: (v) {
              _controller.estabilidadInicial = v;
              _onFieldChanged();
            },
            excentricidadActiva: _controller.excentricidadRealizada,
            repetibilidadActiva: _controller.repetibilidadRealizada,
            linealidadActiva: _controller.linealidadRealizada,
            onExcentricidadActivaChanged: (v) {
              _controller.excentricidadRealizada = v;
              _onFieldChanged();
            },
            onRepetibilidadActivaChanged: (v) {
              _controller.repetibilidadRealizada = v;
              _onFieldChanged();
            },
            onLinealidadActivaChanged: (v) {
              _controller.linealidadRealizada = v;
              _onFieldChanged();
            },
            excentricidad: _controller.excentricidadInicial,
            repetibilidad: _controller.repetibilidadInicial,
            linealidad: _controller.linealidadInicial,
            onExcentricidadChanged: (v) {
              _controller.excentricidadInicial = v;
              _onFieldChanged();
            },
            onRepetibilidadChanged: (v) {
              _controller.repetibilidadInicial = v;
              _onFieldChanged();
            },
            onLinealidadChanged: (v) {
              _controller.linealidadInicial = v;
              _onFieldChanged();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAllGoodCard() {
    return BulkEstadoToggles(
      mode: _bulkEstadoMode,
      onModeChanged: (mode) {
        setState(() {
          _bulkEstadoMode = mode;
          switch (mode) {
            case BulkEstadoMode.buenEstado:
              applyBulkEstado(_controller.camposEstado,
                  estado: 'Bueno', solutionLabel: 'En buen estado');
              _controller.markChanged();
            case BulkEstadoMode.noAplica:
              applyBulkEstado(_controller.camposEstado,
                  estado: 'No aplica', solutionLabel: 'No aplica');
              _controller.markChanged();
            case BulkEstadoMode.none:
              break;
          }
        });
      },
    );
  }

  Widget _buildPasoEstadoFinal() {
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
        ],
      ),
    );
  }
}
