import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:service_met/models/service_session.dart';
import 'package:service_met/screens/soporte_new/modulos/instalacion/controllers/instalacion_controller.dart';
import 'package:service_met/screens/soporte_new/modulos/instalacion/models/instalacion_model.dart';
import 'package:service_met/screens/soporte_new/modulos/instalacion/widgets/steps/paso_condiciones_instalacion_widget.dart';
import 'package:service_met/screens/soporte_new/modulos/mnt_prv_regular/widgets/steps/paso_pruebas_metrologicas.dart';
import 'package:service_met/screens/soporte_new/utils/balanza_info_helper.dart';
import 'package:service_met/screens/soporte_new/widgets/fin_servicio_screen.dart';
import 'package:service_met/screens/soporte_new/widgets/shared/paso_estado_final_widget.dart';
import 'package:service_met/utils/top_alert.dart';
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
      icon: Icons.domain_outlined,
    ),
    StepData(
      title: 'Pruebas',
      subtitle: 'Metrología inicial',
      icon: Icons.science_outlined,
    ),
    StepData(
      title: 'Estado Final',
      subtitle: 'Cierre del servicio',
      icon: Icons.assignment_turned_in_outlined,
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
    _balanzaInfo =
        buildCalBalanzaInfo(widget.instrumentoData, widget.codMetrica);
    _loadExistingData();
  }

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

  bool _validateCurrentStep() {
    switch (_controller.currentStep) {
      case 0:
        if (_controller.camposEstado.any((campo) => campo.value.isEmpty)) {
          TopAlert.show(
              context, 'Complete todas las condiciones de instalación',
              isError: true);
          return false;
        }
        return true;
      case 1:
        if (_controller.retornoCeroInicial.isEmpty ||
            _controller.estabilidadInicial.isEmpty) {
          TopAlert.show(context, 'Complete retorno a cero y estabilidad',
              isError: true);
          return false;
        }
        return true;
      case 2:
        if (_controller.comentarioGeneral.isEmpty) {
          TopAlert.show(context, 'Complete el comentario general',
              isError: true);
          return false;
        }
        if (_controller.recomendacion.isEmpty) {
          TopAlert.show(context, 'Seleccione una recomendación', isError: true);
          return false;
        }
        if (_controller.estadoFisico.isEmpty ||
            _controller.estadoOperacional.isEmpty ||
            _controller.estadoMetrologico.isEmpty) {
          TopAlert.show(context, 'Complete todos los estados finales',
              isError: true);
          return false;
        }
        if (_controller.fechaProxServicio.isEmpty ||
            _controller.horaFin.isEmpty) {
          TopAlert.show(
            context,
            'Registre la fecha del próximo servicio y la hora final',
            isError: true,
          );
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  void _onStepTapped(int step) {
    if (step > _controller.currentStep && !_validateCurrentStep()) return;
    setState(() => _controller.currentStep = step);
  }

  void _onAnterior() {
    if (_controller.currentStep > 0) {
      setState(() => _controller.currentStep--);
    }
  }

  void _onSiguiente() {
    if (!_validateCurrentStep()) return;
    if (_controller.currentStep < _controller.totalSteps - 1) {
      setState(() => _controller.currentStep++);
    }
  }

  void _onFinalizar() {
    if (!_validateCurrentStep()) return;
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
            csvSuffix: 'Instalacion',
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
        appBar: ServiceAppBar(title: 'Instalación'),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

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
                onExcentricidadActivaChanged: (value) {
                  _controller.excentricidadRealizada = value;
                  _controller.markChanged();
                },
                onRepetibilidadActivaChanged: (value) {
                  _controller.repetibilidadRealizada = value;
                  _controller.markChanged();
                },
                onLinealidadActivaChanged: (value) {
                  _controller.linealidadRealizada = value;
                  _controller.markChanged();
                },
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
          onStepTapped: _onStepTapped,
          nextLabel: isLast ? 'Finalizar' : 'Siguiente',
          nextColor: isLast ? const Color(0xFF3E7732) : const Color(0xFF498054),
          onNext: isLast ? _onFinalizar : _onSiguiente,
          onBack: _controller.currentStep > 0 ? _onAnterior : null,
          saveStatus: _saveStatus,
          balanzaInfo: buildServiceBalanzaInfo(
              widget.instrumentoData, widget.codMetrica),
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
