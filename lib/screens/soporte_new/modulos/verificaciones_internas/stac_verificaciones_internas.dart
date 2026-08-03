import 'package:flutter/material.dart';

import 'package:service_met/screens/soporte_new/utils/balanza_info_helper.dart';
import 'package:service_met/screens/soporte_new/widgets/fin_servicio_screen.dart';
import 'package:service_met/screens/soporte_new/widgets/shared/campo_inspeccion_widget.dart';
import 'package:service_met/screens/soporte_new/widgets/shared/paso_pruebas_iniciales_widget.dart';
import 'package:service_met/screens/soporte_new/widgets/shared/paso_pruebas_finales_widget.dart';
import 'package:service_met/screens/soporte_new/widgets/shared/paso_estado_final_widget.dart';
import 'package:service_met/utils/top_alert.dart';
import 'package:service_met/widgets/service_ui/input_decoration.dart';
import 'package:service_met/widgets/service_ui/service_app_bar.dart';
import 'package:service_met/widgets/service_ui/service_workspace_layout.dart';
import 'package:service_met/widgets/service_ui/step_indicator.dart';

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
  int _currentStep = 0;
  bool _isSaving = false;
  bool _isLoading = true;

  static const _steps = [
    StepData(
        title: 'Inspección',
        subtitle: 'Campos de inspección',
        icon: Icons.visibility),
    StepData(
        title: 'Pruebas Iniciales',
        subtitle: 'Metrológicas',
        icon: Icons.science_outlined),
    StepData(
        title: 'Pruebas Finales',
        subtitle: 'Verificación posterior',
        icon: Icons.task_alt_outlined),
    StepData(
        title: 'Estado Final',
        subtitle: 'Conclusión del servicio',
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
    _setBalanzaData();
    _loadExistingData();
  }

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
    _controller.categoriaBalanza = data['categoria']?.toString() ?? data['categoria_balanza']?.toString() ?? '';
    _controller.codInt = data['cod_interno']?.toString() ?? data['cod_int']?.toString() ?? '';
    _controller.tipoEquipo = data['tipo_instrumento']?.toString() ?? data['tipo']?.toString() ?? '';
    _controller.marca = data['marca']?.toString() ?? '';
    _controller.modelo = data['modelo']?.toString() ?? '';
    _controller.serie = data['inf_serie']?.toString() ?? data['serie']?.toString() ?? '';
    _controller.unidades = data['unidad']?.toString() ?? data['unidades']?.toString() ?? '';
    _controller.numCeldas = data['n_celdas']?.toString() ?? data['num_celdas']?.toString() ?? '';
    _controller.ubicacion = data['ubicacion']?.toString() ?? '';
    _controller.capMax1 = data['cap_max1']?.toString() ?? ''; _controller.d1 = data['d1']?.toString() ?? ''; _controller.e1 = data['e1']?.toString() ?? ''; _controller.dec1 = data['dec1']?.toString() ?? '';
    _controller.capMax2 = data['cap_max2']?.toString() ?? ''; _controller.d2 = data['d2']?.toString() ?? ''; _controller.e2 = data['e2']?.toString() ?? ''; _controller.dec2 = data['dec2']?.toString() ?? '';
    _controller.capMax3 = data['cap_max3']?.toString() ?? ''; _controller.d3 = data['d3']?.toString() ?? ''; _controller.e3 = data['e3']?.toString() ?? ''; _controller.dec3 = data['dec3']?.toString() ?? '';
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

  Future<void> _saveCurrentStep() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      await _controller.guardarSesion();
    } catch (e) {
      if (mounted) {
        TopAlert.show(context, 'Error al guardar: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0:
        for (final campo in _controller.camposEstado) {
          if (campo.value.isEmpty) {
            TopAlert.show(context, 'Complete todos los campos de inspección',
                isError: true);
            return false;
          }
        }
        return true;
      case 3:
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
        return true;
      default:
        return true;
    }
  }

  Future<void> _goToStep(int step) async {
    if (step > _currentStep && !_validateCurrentStep()) return;
    await _saveCurrentStep();
    if (mounted) setState(() => _currentStep = step);
  }

  Future<void> _finalizar() async {
    if (!_validateCurrentStep()) return;
    await _saveCurrentStep();
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
            csvSuffix: 'Vinternas',
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
        appBar: ServiceAppBar(title: 'Verificaciones Internas'),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final isLast = _currentStep == _steps.length - 1;
        return ServiceWorkspaceLayout(
          title: 'Verificaciones Internas',
          steps: _steps,
          stepWidgets: [
            _buildPasoInspeccion(),
            _buildPasoPruebas(),
            _buildPasoPruebasFinales(),
            _buildPasoEstadoFinal(),
          ],
          currentStep: _currentStep,
          onStepTapped: (step) => _goToStep(step),
          nextLabel: isLast ? 'Finalizar' : 'Siguiente',
          nextColor: isLast
              ? const Color(0xFF3e7732)
              : const Color(0xFF498054),
          onNext:
              isLast ? _finalizar : () => _goToStep(_currentStep + 1),
          onBack: _currentStep > 0
              ? () => _goToStep(_currentStep - 1)
              : null,
          saveStatus: _saveStatus,
          balanzaInfo:
              buildServiceBalanzaInfo(widget.instrumentoData, widget.codMetrica),
        );
      },
    );
  }

  Widget _buildPasoInspeccion() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ServiceStepHeader(
            title: 'Inspección',
            subtitle: 'Complete el estado de cada campo de inspección',
          ),
          const SizedBox(height: 24),
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

  Widget _buildPasoPruebas() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ServiceStepHeader(
            title: 'Pruebas Iniciales',
            subtitle: 'Pruebas metrológicas iniciales',
          ),
          const SizedBox(height: 24),
          PasoPruebasInicialesWidget(
            pruebasIniciales: _controller.pruebasIniciales,
            onDataChanged: _onFieldChanged,
          ),
          const SizedBox(height: 16),
          Center(
            child: ElevatedButton.icon(
              onPressed: () {
                _controller.copiarPruebasInicialesAFinales();
                TopAlert.show(
                    context, 'Pruebas iniciales copiadas a finales');
                setState(() {});
              },
              icon: const Icon(Icons.copy),
              label: const Text('Copiar Iniciales a Finales'),
            ),
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
            camposEstado: _controller.camposEstado,
            onCampoChanged: _onCampoChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildPasoPruebasFinales() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ServiceStepHeader(
            title: 'Pruebas Metrológicas Finales',
            subtitle: 'Registros después de la verificación',
          ),
          const SizedBox(height: 24),
          PasoPruebasFinalesWidget(
            pruebasFinales: _controller.pruebasFinales,
            onDataChanged: _onFieldChanged,
          ),
        ],
      ),
    );
  }
}
