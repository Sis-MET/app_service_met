import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:service_met/database/soporte_tecnico/database_helper_mnt_prv_regular_stil.dart';
import 'package:service_met/models/service_session.dart';
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

class StilMntPrvRegular extends StatefulWidget {
  final String sessionId;
  final String secaValue;
  final String nReca;
  final String codMetrica;
  final String userName;
  final String clienteId;
  final String plantaCodigo;
  final String clienteNombre;
  final String plantaNombre;
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
    this.plantaNombre = '',
    this.instrumentoData,
  });

  @override
  State<StilMntPrvRegular> createState() => _StilMntPrvRegularState();
}

class _StilMntPrvRegularState extends State<StilMntPrvRegular> {
  late final MntPrvRegularController _controller;
  late final MntPrvRegularModel _model;
  late final BalanzaInfo _balanzaInfo;
  final ImagePicker _picker = ImagePicker();
  int _copyTickFinales = 0;

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
        title: 'Terminal',
        subtitle: 'Campos de inspección',
        icon: Icons.computer_outlined),
    StepData(
        title: 'Balanza',
        subtitle: 'Campos de inspección',
        icon: Icons.balance_outlined),
    StepData(
        title: 'Caja Sumadora',
        subtitle: 'Campos de inspección',
        icon: Icons.electrical_services_outlined),
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
    _model = MntPrvRegularModel(
      sessionId: widget.sessionId,
      codMetrica: widget.codMetrica,
    );
    _controller = MntPrvRegularController(model: _model);
    _controller.secaValue = widget.secaValue;
    _controller.clienteNombre = widget.clienteNombre;
    _controller.plantaNombre = widget.plantaNombre;
    _controller.initCamposEstado();
    _balanzaInfo =
        buildCalBalanzaInfo(widget.instrumentoData, widget.codMetrica);
    _loadExistingData();
  }

  Future<void> _loadExistingData() async {
    try {
      final dbLegacy = DatabaseHelperMntPrvRegularStil();
      final registro = await dbLegacy.getUltimoRegistroPorSeca(
          widget.secaValue);
      if (registro != null && mounted) {
        await _controller.loadExistingSession(
            widget.sessionId, registro);
      }
    } catch (e) {
      debugPrint('Error cargando datos existentes MNT PRV REGULAR: $e');
    }
  }

  bool _camposCompletos(List<CampoEstado> campos) {
    return campos.every((c) => c.value.isNotEmpty);
  }

  bool _validateCurrentStep() {
    switch (_controller.currentStep) {
      case 1:
        if (!_camposCompletos(_controller.camposTerminal)) {
          TopAlert.show(
              context, 'Complete todos los campos de Terminal',
              isError: true);
          return false;
        }
        return true;
      case 2:
        if (!_camposCompletos(_controller.camposBalanza)) {
          TopAlert.show(
              context, 'Complete todos los campos de Balanza',
              isError: true);
          return false;
        }
        return true;
      case 3:
        if (!_camposCompletos(_controller.camposCajaSumadora)) {
          TopAlert.show(
              context, 'Complete todos los campos de Caja Sumadora',
              isError: true);
          return false;
        }
        return true;
      case 5:
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
            tableNameDefault: 'mnt_prv_regular',
            csvSuffix: 'MntPrvRegular',
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
    _controller.horaFin = DateFormat('HH:mm:ss').format(DateTime.now());
    _controller.markChanged();
  }

  Future<void> _addPhoto(String label, String foto) async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.gallery);
    if (photo != null && mounted) {
      _model.addPhoto(label, File(photo.path));
      _controller.markChanged();
    }
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
          title: 'Mnt Preventivo Regular',
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
            // ── Paso 1: Terminal ────────────────────────────────────
            _buildPaso(
              const ServiceStepHeader(
                title: 'Terminal',
                subtitle: 'Complete el estado de cada campo',
              ),
              PasoTerminal(
                campos: _controller.camposTerminal,
                onChanged: (i, v, s) =>
                    _onCampoChanged(_controller.camposTerminal, i, v, s),
                onAddPhoto: _addPhoto,
                onRemovePhoto: (_) {},
              ),
            ),
            // ── Paso 2: Balanza ─────────────────────────────────────
            _buildPaso(
              const ServiceStepHeader(
                title: 'Balanza',
                subtitle: 'Complete el estado de cada campo',
              ),
              PasoBalanza(
                campos: _controller.camposBalanza,
                onChanged: (i, v, s) =>
                    _onCampoChanged(_controller.camposBalanza, i, v, s),
                onAddPhoto: _addPhoto,
                onRemovePhoto: (_) {},
              ),
            ),
            // ── Paso 3: Caja Sumadora ───────────────────────────────
            _buildPaso(
              const ServiceStepHeader(
                title: 'Caja Sumadora',
                subtitle: 'Complete el estado de cada campo',
              ),
              PasoCajaSumadora(
                campos: _controller.camposCajaSumadora,
                onChanged: (i, v, s) =>
                    _onCampoChanged(_controller.camposCajaSumadora, i, v, s),
                onAddPhoto: _addPhoto,
                onRemovePhoto: (_) {},
              ),
            ),
            // ── Paso 4: Pruebas Metrológicas Finales ────────────────
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
            // ── Paso 5: Estado Final ────────────────────────────────
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
