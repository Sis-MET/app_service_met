import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:service_met/models/service_session.dart';

import 'package:service_met/screens/soporte_new/utils/balanza_info_helper.dart';
import 'package:service_met/screens/soporte_new/widgets/fin_servicio_screen.dart';
import 'package:service_met/screens/soporte_new/widgets/shared/campo_inspeccion_widget.dart';
import 'package:service_met/screens/soporte_new/widgets/shared/paso_estado_final_widget.dart';
import 'package:service_met/screens/soporte_new/modulos/mnt_prv_regular/widgets/steps/paso_pruebas_metrologicas.dart';
import 'package:service_met/utils/top_alert.dart';
import 'package:service_met/widgets/service_ui/input_decoration.dart';
import 'package:service_met/widgets/service_ui/service_app_bar.dart';
import 'package:service_met/widgets/service_ui/service_workspace_layout.dart';
import 'package:service_met/widgets/service_ui/step_indicator.dart';

import 'controllers/mnt_correctivo_controller.dart';
import 'models/mnt_correctivo_model.dart';

class StacMntCorrectivo extends StatefulWidget {
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

  const StacMntCorrectivo({
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
  State<StacMntCorrectivo> createState() => _StacMntCorrectivoState();
}

class _StacMntCorrectivoState extends State<StacMntCorrectivo> {
  late MntCorrectivoController _controller;
  late final BalanzaInfo _balanzaInfo;
  final int _copyTickFinales = 0;
  int _formRefreshTick = 0;
  bool _isSaving = false;
  bool _isImporting = false;
  bool _isLoading = true;

  static const _steps = [
    StepData(
        title: 'Info General',
        subtitle: 'Reporte y trabajos',
        icon: Icons.info_outline),
    StepData(
        title: 'Pruebas Finales',
        subtitle: 'Metrológicas',
        icon: Icons.task_alt_outlined),
    StepData(
        title: 'Estado Final',
        subtitle: 'Conclusión del servicio',
        icon: Icons.assignment_turned_in_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _controller = MntCorrectivoController(
      model: MntCorrectivoModel(
        sessionId: widget.sessionId,
        codMetrica: widget.codMetrica,
        secaValue: widget.secaValue,
      ),
    );
    _controller.secaValue = widget.secaValue;
    _controller.clienteNombre = widget.clienteNombre;
    _controller.plantaNombre = widget.plantaNombre;
    _controller.horaInicio = DateFormat('HH:mm').format(DateTime.now());
    _balanzaInfo =
        buildCalBalanzaInfo(widget.instrumentoData, widget.codMetrica);
    _setBalanzaData();
    _configureRecovery();
    _controller.initCamposEstado();
    _controller.camposEstado.clear();
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
      debugPrint('Error restaurando Mantenimiento Correctivo: $error');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _setBalanzaData() {
    final instrument = widget.instrumentoData;
    _controller.razonSocial = widget.clienteRazonSocial;
    _controller.dirPlanta = widget.plantaDireccion;
    _controller.depPlanta = widget.plantaDepartamento;
    _controller.codPlanta = widget.plantaCodigo;
    _controller.personal = widget.userName;
    if (instrument == null) return;

    _controller.infBal = instrument['_modifiedFields']?.toString() ?? '';
    _controller.categoriaBalanza = instrument['categoria']?.toString() ??
        instrument['categoria_balanza']?.toString() ??
        '';
    _controller.codInt = instrument['cod_interno']?.toString() ??
        instrument['cod_int']?.toString() ??
        '';
    _controller.tipoEquipo = instrument['tipo_instrumento']?.toString() ??
        instrument['tipo']?.toString() ??
        instrument['instrumento']?.toString() ??
        '';
    _controller.marca = instrument['marca']?.toString() ?? '';
    _controller.modelo = instrument['modelo']?.toString() ?? '';
    _controller.serie = instrument['inf_serie']?.toString() ??
        instrument['serie']?.toString() ??
        '';
    _controller.unidades = instrument['unidad']?.toString() ??
        instrument['unidades']?.toString() ??
        '';
    _controller.numCeldas = instrument['n_celdas']?.toString() ??
        instrument['num_celdas']?.toString() ??
        '';
    _controller.ubicacion = instrument['ubicacion']?.toString() ?? '';
    _controller.capMax1 = instrument['cap_max1']?.toString() ?? '';
    _controller.d1 = instrument['d1']?.toString() ?? '';
    _controller.e1 = instrument['e1']?.toString() ?? '';
    _controller.dec1 = instrument['dec1']?.toString() ?? '';
    _controller.capMax2 = instrument['cap_max2']?.toString() ?? '';
    _controller.d2 = instrument['d2']?.toString() ?? '';
    _controller.e2 = instrument['e2']?.toString() ?? '';
    _controller.dec2 = instrument['dec2']?.toString() ?? '';
    _controller.capMax3 = instrument['cap_max3']?.toString() ?? '';
    _controller.d3 = instrument['d3']?.toString() ?? '';
    _controller.e3 = instrument['e3']?.toString() ?? '';
    _controller.dec3 = instrument['dec3']?.toString() ?? '';
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

  /// Guarda el servicio y devuelve si quedó en el teléfono. Si no, avisa por
  /// qué: antes el fallo no se veía y la pantalla seguía como si nada.
  Future<bool> _saveCurrentStep() async {
    if (_isSaving) return false;
    setState(() => _isSaving = true);
    var saved = false;
    Object? error;
    try {
      await _controller.guardarSesion();
      saved = _controller.lastSaveSuccessful;
    } catch (e) {
      error = e;
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
    if (!saved && mounted) {
      final motivo = _controller.lastSaveError ?? error;
      TopAlert.show(
        context,
        'No se pudo guardar en el teléfono${motivo == null ? '' : ': $motivo'}'
        '\nLo escrito sigue en pantalla; intente de nuevo.',
        isError: true,
      );
    }
    return saved;
  }

  bool _validateCurrentStep() {
    switch (_controller.currentStep) {
      case 0:
        if (_controller.reporteFalla.isEmpty) {
          TopAlert.show(context, 'Complete el reporte de falla', isError: true);
          return false;
        }
        if (_controller.evaluacion.isEmpty ||
            _controller.trabajoRealizado.isEmpty) {
          TopAlert.show(
              context, 'Complete la evaluacion tecnica y el trabajo realizado',
              isError: true);
          return false;
        }
        for (final campo in _controller.camposEstado) {
          if (campo.value.isEmpty) {
            TopAlert.show(context, 'Complete todos los campos de inspección',
                isError: true);
            return false;
          }
        }
        return true;
      case 2:
        if (_controller.comentarioGeneral.isEmpty) {
          TopAlert.show(context, 'Complete el comentario general',
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
        if (_controller.recomendacion.isEmpty ||
            _controller.fechaProxServicio.isEmpty ||
            _controller.horaFin.isEmpty) {
          TopAlert.show(context,
              'Complete la recomendacion, fecha del proximo servicio y hora final',
              isError: true);
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  Future<void> _goToStep(int step) async {
    final adelante = step > _controller.currentStep;
    if (adelante && !_validateCurrentStep()) return;
    final saved = await _saveCurrentStep();
    // Hacia adelante solo con lo escrito guardado. Hacia atrás no se pierde
    // nada: sigue en pantalla y se vuelve a intentar al avanzar.
    if (!saved && adelante) return;
    if (mounted) _controller.setCurrentStep(step);
  }

  Future<void> _finalizar() async {
    if (!_validateCurrentStep()) return;
    if (!await _saveCurrentStep()) return;
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
          tableName: 'mnt_correctivo',
          config: const FinServicioConfig(
            tableNameDefault: 'mnt_correctivo',
            additionalWhere: '',
            tipoServicio: 'MANTENIMIENTO CORRECTIVO',
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
        appBar: ServiceAppBar(title: 'Mantenimiento Correctivo'),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final isLast = _controller.currentStep == _steps.length - 1;
        return ServiceWorkspaceLayout(
          title: 'Mantenimiento Correctivo',
          steps: _steps,
          stepWidgets: [
            _buildPasoInfoGeneral(),
            _buildPasoPruebas(),
            _buildPasoEstadoFinal(),
          ],
          currentStep: _controller.currentStep,
          onStepTapped: (step) => _goToStep(step),
          nextLabel: isLast ? 'Finalizar' : 'Siguiente',
          nextColor: isLast ? const Color(0xFF3e7732) : const Color(0xFF498054),
          onNext: isLast
              ? _finalizar
              : () => _goToStep(_controller.currentStep + 1),
          onBack: _controller.currentStep > 0
              ? () => _goToStep(_controller.currentStep - 1)
              : null,
          saveStatus: _saveStatus,
          balanzaInfo: buildServiceBalanzaInfo(
              widget.instrumentoData, widget.codMetrica),
        );
      },
    );
  }

  Widget _buildPasoInfoGeneral() => _buildModernInfoGeneral();

  Widget _buildLegacyInfoGeneralUnused() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ServiceStepHeader(
            title: 'Información General',
            subtitle: 'Reporte de falla y trabajos realizados',
          ),
          const SizedBox(height: 24),
          TextFormField(
            initialValue: _controller.reporteFalla,
            decoration: serviceInputDeco('Reporte de Falla', isDark),
            maxLines: 3,
            onChanged: (v) {
              _controller.reporteFalla = v;
              _onFieldChanged();
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: _controller.trabajoRealizado,
            decoration: serviceInputDeco('Trabajo Realizado', isDark),
            maxLines: 3,
            onChanged: (v) {
              _controller.trabajoRealizado = v;
              _onFieldChanged();
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: _controller.repuestosUtilizados,
            decoration: serviceInputDeco('Repuestos Utilizados', isDark),
            maxLines: 3,
            onChanged: (v) {
              _controller.repuestosUtilizados = v;
              _onFieldChanged();
            },
          ),
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
        ],
      ),
    );
  }

  Future<void> _importDiagnostico() async {
    setState(() => _isImporting = true);
    try {
      final found = await _controller.importDiagnosticoCsv();
      if (!mounted) return;
      if (found) {
        setState(() => _formRefreshTick++);
        TopAlert.show(context, 'Diagnostico importado correctamente');
      } else {
        TopAlert.show(context,
            'No se encontro un diagnostico para esta balanza en el CSV',
            isError: true);
      }
    } catch (error) {
      if (mounted) {
        TopAlert.show(context, 'No se pudo importar el diagnostico: $error',
            isError: true);
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  Widget _buildModernInfoGeneral() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ServiceStepHeader(
            title: 'Informacion General',
            subtitle: 'Reporte, evaluacion tecnica y trabajo realizado',
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isImporting ? null : _importDiagnostico,
              icon: _isImporting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.upload_file_rounded),
              label: Text(_isImporting
                  ? 'Importando diagnostico...'
                  : 'Importar diagnostico (CSV)'),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            key: ValueKey('reporte_$_formRefreshTick'),
            initialValue: _controller.reporteFalla,
            decoration: serviceInputDeco('Reporte de falla *', isDark),
            maxLines: 4,
            onChanged: (value) {
              _controller.reporteFalla = value;
              _onFieldChanged();
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: ValueKey('evaluacion_$_formRefreshTick'),
            initialValue: _controller.evaluacion,
            decoration: serviceInputDeco(
                'Evaluacion y analisis tecnico de fallas', isDark),
            maxLines: 4,
            onChanged: (value) {
              _controller.evaluacion = value;
              _onFieldChanged();
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: ValueKey('trabajo_$_formRefreshTick'),
            initialValue: _controller.trabajoRealizado,
            decoration: serviceInputDeco('Trabajo realizado', isDark),
            maxLines: 4,
            onChanged: (value) {
              _controller.trabajoRealizado = value;
              _onFieldChanged();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPasoPruebas() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ServiceStepHeader(
            title: 'Pruebas Finales',
            subtitle: 'Pruebas metrológicas finales',
          ),
          const SizedBox(height: 24),
          PasoPruebasMetrologicas(
            balanza: _balanzaInfo,
            esInicial: false,
            retornoCero: _controller.retornoCeroFinal,
            estabilidad: _controller.estabilidadFinal,
            onRetornoCeroChanged: (value) {
              _controller.retornoCeroFinal = value;
              _onFieldChanged();
            },
            onEstabilidadChanged: (value) {
              _controller.estabilidadFinal = value;
              _onFieldChanged();
            },
            excentricidadActiva: _controller.excentricidadRealizada,
            repetibilidadActiva: _controller.repetibilidadRealizada,
            linealidadActiva: _controller.linealidadRealizada,
            onExcentricidadActivaChanged: (value) {
              _controller.excentricidadRealizada = value;
              _onFieldChanged();
            },
            onRepetibilidadActivaChanged: (value) {
              _controller.repetibilidadRealizada = value;
              _onFieldChanged();
            },
            onLinealidadActivaChanged: (value) {
              _controller.linealidadRealizada = value;
              _onFieldChanged();
            },
            excentricidad: _controller.excentricidadFinal,
            repetibilidad: _controller.repetibilidadFinal,
            linealidad: _controller.linealidadFinal,
            onExcentricidadChanged: (data) {
              _controller.excentricidadFinal = data;
              _onFieldChanged();
            },
            onRepetibilidadChanged: (data) {
              _controller.repetibilidadFinal = data;
              _onFieldChanged();
            },
            onLinealidadChanged: (data) {
              _controller.linealidadFinal = data;
              _onFieldChanged();
            },
            copyTick: _copyTickFinales,
          ),
        ],
      ),
    );
  }

  Widget _buildPasoEstadoFinal() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
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
            recomendacionesOptions: const [
              'Diagnostico',
              'Mnt Preventivo Regular',
              'Mnt Preventivo Avanzado',
              'Mnt Correctivo',
              'Ajustes Metrologicos',
              'Calibracion',
              'Sin recomendacion',
            ],
            useLegacyEstados: true,
          ),
        ],
      ),
    );
  }
}
