import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:service_met/screens/soporte_new/utils/balanza_info_helper.dart';
import 'package:service_met/screens/soporte_new/widgets/fin_servicio_screen.dart';
import 'package:service_met/screens/soporte_new/modulos/relevamiento_de_datos/controllers/relevamiento_de_datos_controller.dart';
import 'package:service_met/screens/soporte_new/modulos/relevamiento_de_datos/models/relevamiento_de_datos_model.dart';
import 'package:service_met/screens/soporte_new/modulos/mnt_prv_regular/widgets/steps/paso_terminal_balanza_caja.dart';
import 'package:service_met/screens/soporte_new/widgets/shared/paso_estado_final_widget.dart';
import 'package:service_met/screens/soporte_new/widgets/shared/campo_inspeccion_widget.dart';
import 'package:service_met/screens/soporte_new/modulos/mnt_prv_regular/widgets/steps/paso_pruebas_metrologicas.dart';
import 'package:service_met/widgets/service_ui/input_decoration.dart';
import 'package:service_met/widgets/service_ui/service_app_bar.dart';
import 'package:service_met/widgets/service_ui/service_workspace_layout.dart';
import 'package:service_met/widgets/service_ui/step_indicator.dart';

class StacRelevamientoDeDatos extends StatefulWidget {
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

  const StacRelevamientoDeDatos({
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
  State<StacRelevamientoDeDatos> createState() =>
      _StacRelevamientoDeDatosState();
}

class _StacRelevamientoDeDatosState extends State<StacRelevamientoDeDatos> {
  late final RelevamientoDeDatosController _controller;
  late final RelevamientoDeDatosModel _model;

  static const _steps = [
    StepData(
        title: 'Terminal',
        subtitle: 'Inspección',
        icon: Icons.computer_outlined),
    StepData(
        title: 'Plataforma',
        subtitle: 'Inspección',
        icon: Icons.scale_outlined),
    StepData(
        title: 'Celdas y Entorno',
        subtitle: 'Inspección y condiciones',
        icon: Icons.sensors_outlined),
    StepData(
        title: 'Pruebas Finales',
        subtitle: 'Metrológicas',
        icon: Icons.task_alt_outlined),
    StepData(
        title: 'Estado Final',
        subtitle: 'Conclusión del servicio',
        icon: Icons.assignment_turned_in_outlined),
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

  static const List<List<String>> _entornoOptions = [
    ['Seco', 'Polvoso', 'Muy polvoso', 'Húmedo parcial', 'Húmedo constante'],
    ['Irregular', 'Liso', 'Nivelación correcta', 'Nivelación deficiente'],
    ['Ninguna', 'Dentro el área', 'Fuera del área', 'Fuera del sector'],
    [
      '1 a 10 por día',
      '10 a 50 por día',
      '50 a 100 por día',
      'Más de 100 por día'
    ],
  ];

  @override
  void initState() {
    super.initState();
    _model = RelevamientoDeDatosModel(
      sessionId: widget.sessionId,
      codMetrica: widget.codMetrica,
    );
    _controller = RelevamientoDeDatosController(model: _model);
    _controller.secaValue = widget.secaValue;
    _controller.clienteNombre = widget.clienteNombre;
    _controller.plantaNombre = widget.plantaNombre;
    _controller.initCamposEstado();
    _setBalanzaData();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _controller.restoreSession();
    });
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
          clienteNombre: widget.clienteNombre,
          plantaNombre: widget.plantaNombre,
          config: const FinServicioConfig(
            tableNameDefault: 'relevamiento_de_datos',
            csvSuffix: 'RelevDatos',
            tipoServicio: 'RELEVAMIENTO DE DATOS',
          ),
          tableName: 'relevamiento_de_datos',
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
          title: 'Relevamiento de Datos',
          steps: _steps,
          stepWidgets: [
            _buildPaso(
              const ServiceStepHeader(
                title: 'Terminal',
                subtitle: 'Complete el estado de cada campo',
              ),
              PasoTerminal(
                campos: _controller.camposEstado.sublist(0, 6),
                onChanged: (i, v, s) => _onCampoChanged(i, v, s),
                seca: widget.secaValue,
                codMetrica: widget.codMetrica,
              ),
            ),
            _buildPaso(
              const ServiceStepHeader(
                  title: 'Plataforma',
                  subtitle: 'Complete el estado de cada campo'),
              PasoTerminal(
                campos: _controller.camposEstado.sublist(6, 12),
                onChanged: (i, v, s) => _onCampoChanged(i + 6, v, s),
                seca: widget.secaValue,
                codMetrica: widget.codMetrica,
              ),
            ),
            _buildPaso(
              const ServiceStepHeader(
                  title: 'Celdas y Entorno',
                  subtitle: 'Inspeccione las celdas y condiciones de trabajo'),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PasoTerminal(
                    campos: _controller.camposEstado.sublist(12, 15),
                    onChanged: (i, v, s) => _onCampoChanged(i + 12, v, s),
                    seca: widget.secaValue,
                    codMetrica: widget.codMetrica,
                  ),
                  const SizedBox(height: 28),
                  const ServiceStepHeader(
                    title: 'Condiciones de instalación',
                    subtitle: 'Seleccione la condición que corresponda',
                  ),
                  const SizedBox(height: 12),
                  ...List.generate(4, (index) {
                    final campoIndex = index + 15;
                    return CampoInspeccionWidget(
                      campoEstado: _controller.camposEstado[campoIndex],
                      customOptions: _entornoOptions[index],
                      onChanged: (value, solutionValue) =>
                          _onCampoChanged(campoIndex, value, solutionValue),
                      seca: widget.secaValue,
                      codMetrica: widget.codMetrica,
                    );
                  }),
                ],
              ),
            ),
            _buildPaso(
              const ServiceStepHeader(
                title: 'Pruebas Finales',
                subtitle: 'Pruebas metrológicas finales',
              ),
              PasoPruebasMetrologicas(
                balanza: buildCalBalanzaInfo(
                    widget.instrumentoData, widget.codMetrica),
                esInicial: false,
                retornoCero: _controller.retornoCero,
                estabilidad: _controller.estabilidad,
                onRetornoCeroChanged: (v) {
                  _controller.retornoCero = v;
                  _controller.markChanged();
                },
                onEstabilidadChanged: (v) {
                  _controller.estabilidad = v;
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
                excentricidad: _controller.excentricidad,
                repetibilidad: _controller.repetibilidad,
                linealidad: _controller.linealidad,
                onExcentricidadChanged: (v) {
                  _controller.excentricidad = v;
                  _controller.markChanged();
                },
                onRepetibilidadChanged: (v) {
                  _controller.repetibilidad = v;
                  _controller.markChanged();
                },
                onLinealidadChanged: (v) {
                  _controller.linealidad = v;
                  _controller.markChanged();
                },
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
          onStepTapped: _onStepTapped,
          nextLabel: isLast ? 'Finalizar' : 'Siguiente',
          nextColor: isLast ? const Color(0xFF3e7732) : const Color(0xFF498054),
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
