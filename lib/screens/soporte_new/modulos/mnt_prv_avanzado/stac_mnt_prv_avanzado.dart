import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:service_met/database/soporte_tecnico/database_helper_mnt_prv_avanzado_stac.dart';
import 'package:service_met/models/service_session.dart';
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
        icon: Icons.science_outlined),
    StepData(
        title: 'Lozas y Fundaciones',
        subtitle: 'Campos de inspección',
        icon: Icons.foundation_outlined),
    StepData(
        title: 'Limpieza y Drenaje',
        subtitle: 'Campos de inspección',
        icon: Icons.cleaning_services_outlined),
    StepData(
        title: 'Chequeo General',
        subtitle: 'Campos de inspección',
        icon: Icons.checklist_outlined),
    StepData(
        title: 'Verif. Eléctricas',
        subtitle: 'Campos de inspección',
        icon: Icons.electrical_services_outlined),
    StepData(
        title: 'Protección / Células',
        subtitle: 'Rayos + Células de carga',
        icon: Icons.flash_on_outlined),
    StepData(
        title: 'Terminal / Calibración',
        subtitle: 'Terminal + Balanza apta',
        icon: Icons.computer_outlined),
    StepData(
        title: 'Pruebas Finales',
        subtitle: 'Excentricidad, Repetibilidad, Linealidad',
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
    _controller.secaValue = widget.secaValue;
    _controller.clienteNombre = widget.clienteNombre;
    _controller.plantaNombre = widget.plantaNombre;
    _controller.initCamposEstado();
    _setBalanzaData();
    _balanzaInfo =
        buildCalBalanzaInfo(widget.instrumentoData, widget.codMetrica);
    _loadExistingData();
  }

  void _setBalanzaData() {
    final inst = widget.instrumentoData;
    if (inst == null) return;

    _controller.categoriaBalanza =
        inst['categoria']?.toString() ?? inst['categoria_balanza']?.toString() ?? '';
    _controller.codInt = inst['cod_interno']?.toString() ?? inst['cod_int']?.toString() ?? '';
    _controller.tipoEquipo =
        inst['tipo_instrumento']?.toString() ?? inst['tipo']?.toString() ?? inst['instrumento']?.toString() ?? '';
    _controller.marca = inst['marca']?.toString() ?? '';
    _controller.modelo = inst['modelo']?.toString() ?? '';
    _controller.serie = inst['inf_serie']?.toString() ?? inst['serie']?.toString() ?? '';
    _controller.unidades = inst['unidad']?.toString() ?? inst['unidades']?.toString() ?? '';
    _controller.numCeldas = inst['n_celdas']?.toString() ?? inst['num_celdas']?.toString() ?? '';
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
      final registro =
          await dbLegacy.getUltimoRegistroPorSeca(widget.secaValue);
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

  bool _validateCurrentStep() {
    switch (_controller.currentStep) {
      case 0:
        if (_controller.retornoCeroInicial.isEmpty) {
          TopAlert.show(
              context, 'Seleccione Retorno a Cero en Pruebas Iniciales',
              isError: true);
          return false;
        }
        if (_controller.estabilidadInicial.isEmpty) {
          TopAlert.show(
              context, 'Seleccione Estabilidad en Pruebas Iniciales',
              isError: true);
          return false;
        }
        return true;
      case 1:
        if (!_camposCompletos(_controller.camposLozas)) {
          TopAlert.show(
              context, 'Complete todos los campos de Lozas y Fundaciones',
              isError: true);
          return false;
        }
        return true;
      case 2:
        if (!_camposCompletos(_controller.camposLimpieza)) {
          TopAlert.show(
              context, 'Complete todos los campos de Limpieza y Drenaje',
              isError: true);
          return false;
        }
        return true;
      case 3:
        if (!_camposCompletos(_controller.camposChequeo)) {
          TopAlert.show(
              context, 'Complete todos los campos de Chequeo General',
              isError: true);
          return false;
        }
        return true;
      case 4:
        if (!_camposCompletos(_controller.camposElectricas)) {
          TopAlert.show(
              context, 'Complete todos los campos de Verif. Eléctricas',
              isError: true);
          return false;
        }
        return true;
      case 5:
        if (!_camposCompletos(_controller.camposProteccionCeldas)) {
          TopAlert.show(
              context,
              'Complete todos los campos de Protección / Células',
              isError: true);
          return false;
        }
        return true;
      case 6:
        if (!_camposCompletos(_controller.camposTerminalCalibracion)) {
          TopAlert.show(
              context,
              'Complete todos los campos de Terminal / Calibración',
              isError: true);
          return false;
        }
        return true;
      case 7:
        if (_controller.retornoCeroFinal.isEmpty) {
          TopAlert.show(
              context, 'Seleccione Retorno a Cero en Pruebas Finales',
              isError: true);
          return false;
        }
        if (_controller.estabilidadFinal.isEmpty) {
          TopAlert.show(
              context, 'Seleccione Estabilidad en Pruebas Finales',
              isError: true);
          return false;
        }
        return true;
      case 8:
        if (_controller.comentarioGeneral.isEmpty) {
          TopAlert.show(context, 'Complete el Comentario General',
              isError: true);
          return false;
        }
        if (_controller.recomendacion.isEmpty) {
          TopAlert.show(context, 'Seleccione una Recomendación',
              isError: true);
          return false;
        }
        if (_controller.fechaProxServicio.isEmpty) {
          TopAlert.show(
              context, 'Seleccione la Fecha del Próximo Servicio',
              isError: true);
          return false;
        }
        if (_controller.estadoFisico.isEmpty ||
            _controller.estadoOperacional.isEmpty ||
            _controller.estadoMetrologico.isEmpty) {
          TopAlert.show(context, 'Complete todos los estados finales',
              isError: true);
          return false;
        }
        if (_controller.horaFin.isEmpty) {
          TopAlert.show(
              context, 'Registre la Hora Final del servicio',
              isError: true);
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
            tableNameDefault: 'mnt_prv_avanzado',
            csvSuffix: 'MntPrvAvanzado',
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
    _controller.horaFin = DateFormat('HH:mm:ss').format(DateTime.now());
    _controller.markChanged();
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
        appBar: ServiceAppBar(title: 'Mnt Preventivo Avanzado'),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (_controller.hasUnsavedChanges.value) {
          final shouldPop = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Cambios sin guardar'),
              content: const Text(
                  '¿Desea salir? Los cambios no guardados se perderán.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Salir'),
                ),
              ],
            ),
          );
          if (shouldPop == true && context.mounted) {
            Navigator.of(context).pop();
          }
        } else {
          if (context.mounted) Navigator.of(context).pop();
        }
      },
      child: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          final isLast =
              _controller.currentStep == _controller.totalSteps - 1;
          return ServiceWorkspaceLayout(
            title: 'Mnt Preventivo Avanzado',
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
                    subtitle:
                        'Sistema de protección y conexión a tierra',
                    icon: Icons.flash_on_outlined,
                    color: Colors.orange,
                    count: 4,
                  ),
                  seccion2: const SeccionData(
                    title: 'VERIFICACIONES DE CÉLULAS',
                    subtitle:
                        'Células de carga, lubricación y protectores',
                    icon: Icons.grain_outlined,
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
                    subtitle:
                        'Carcasa, display, teclado, pila, etc.',
                    icon: Icons.computer_outlined,
                    color: Colors.purple,
                    count: 8,
                  ),
                  seccion2: const SeccionData(
                    title: 'CALIBRACIÓN',
                    subtitle:
                        'Balanza apta para verificación NB23001',
                    icon: Icons.tune_outlined,
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
                    _controller.fechaProxServicio = v;
                    _controller.markChanged();
                  },
                  recomendacionesOptions: _recomendacionesOptions,
                  useLegacyEstados: true,
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
      ),
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
