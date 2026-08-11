import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:service_met/screens/soporte_new/modulos/ajuste_verificaciones/stac_ajuste_verificaciones.dart';
import 'package:service_met/screens/soporte_new/modulos/diagnostico/stac_diagnostico.dart';
import 'package:service_met/screens/soporte_new/modulos/instalacion/stac_instalacion.dart';
import 'package:service_met/screens/soporte_new/modulos/mnt_correctivo/stac_mnt_correctivo.dart';
import 'package:service_met/screens/soporte_new/modulos/mnt_prv_avanzado/stac_mnt_prv_avanzado.dart';
import 'package:service_met/screens/soporte_new/modulos/mnt_prv_regular/stil_mnt_prv_regular.dart';
import 'package:service_met/screens/soporte_new/modulos/relevamiento_de_datos/stac_relevamiento_de_datos.dart';
import 'package:service_met/screens/soporte_new/modulos/verificaciones_internas/stac_verificaciones_internas.dart';
import 'package:service_met/utils/top_alert.dart';
import 'package:service_met/widgets/service_ui/input_decoration.dart';
import 'package:service_met/widgets/service_ui/service_workspace_layout.dart';
import 'package:service_met/widgets/service_ui/step_indicator.dart';

import 'precarga_controller.dart';
import 'widgets/balanza_step.dart';
import 'widgets/cliente_step.dart';
import 'widgets/planta_step.dart';
import 'widgets/seca_step.dart';
import 'widgets/servicio_incompleto_dialog.dart';
import 'widgets/tipo_servicio_step.dart';

class PrecargaScreenSop extends StatefulWidget {
  final String userName;
  final String? clienteId;
  final String? plantaCodigo;
  final String tableName;
  final String? servicio;
  final String? seca;
  final bool skipToBalanza;

  const PrecargaScreenSop({
    super.key,
    required this.userName,
    this.clienteId,
    this.plantaCodigo,
    this.tableName = 'precarga',
    this.servicio,
    this.seca,
    this.skipToBalanza = false,
  });

  @override
  State<PrecargaScreenSop> createState() => _PrecargaScreenSopState();
}

class _PrecargaScreenSopState extends State<PrecargaScreenSop> {
  late final PrecargaController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PrecargaController();
    _controller.userName = widget.userName;
    _controller.clienteId = widget.clienteId;
    _controller.plantaCodigo = widget.plantaCodigo;
    _initData();
  }

  Future<void> _initData() async {
    await _controller.generateSessionId();

    if (widget.skipToBalanza &&
        widget.servicio != null &&
        widget.seca != null &&
        widget.clienteId != null &&
        widget.plantaCodigo != null) {
      await _controller.presetForNuevaBalanza(
        servicio: widget.servicio!,
        clienteId: widget.clienteId!,
        plantaCodigo: widget.plantaCodigo!,
        seca: widget.seca!,
      );
      return;
    }

    final hasCliente = widget.clienteId != null && widget.clienteId!.isNotEmpty;
    final hasPlanta =
        widget.plantaCodigo != null && widget.plantaCodigo!.isNotEmpty;

    if (hasCliente) {
      _controller.clienteId = widget.clienteId;
      await _controller.loadPlantas();
    }
    if (hasPlanta) {
      _controller.plantaCodigo = widget.plantaCodigo;
      _controller.generateSuggestedSeca();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _validateCurrentStep() {
    final error = _controller.getStepError(_controller.currentStep);
    if (error != null) {
      TopAlert.show(context, error, isError: true);
      return false;
    }
    return true;
  }

  void _goToStep(int step) {
    if (step > _controller.currentStep && !_validateCurrentStep()) return;
    _controller.setStep(step);
  }

  Future<bool> _onWillPop() async {
    final hasData = _controller.selectedCliente != null ||
        _controller.selectedPlanta != null ||
        _controller.selectedSeca != null ||
        _controller.selectedInstrumento != null ||
        _controller.selectedServicio != null;

    if (!hasData) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => ServicioIncompletoDialog(
        onConfirmSalir: () => Navigator.of(ctx).pop(true),
        onContinuar: () => Navigator.of(ctx).pop(false),
      ),
    );

    return result ?? false;
  }

  Future<void> _confirmExit() async {
    final shouldPop = await _onWillPop();
    if (shouldPop && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<bool?> _showOtstDuplicadaDialog(String seca, bool isDark) async {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: Colors.orange[700], size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'OTST ya registrada',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'La OTST "$seca" ya tiene registros previos en el sistema.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Si continua, los nuevos registros se agregaran a esta misma OTST.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar',
                style:
                    TextStyle(color: isDark ? Colors.white60 : Colors.black54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Continuar de todas formas'),
          ),
        ],
      ),
    );
  }

  void _iniciarServicio() {
    if (!_validateCurrentStep()) return;
    _controller.updateStepErrors();

    final hasAllData = _controller.canProceedFromStep(5);
    if (!hasAllData) {
      TopAlert.show(
          context, 'Complete todos los pasos antes de iniciar el servicio',
          isError: true);
      return;
    }

    final destino = _getDestination();
    if (destino == null) {
      TopAlert.show(context, 'Tipo de servicio no reconocido', isError: true);
      return;
    }

    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => destino));
  }

  Widget? _getDestination() {
    final servicio = _controller.selectedServicio;
    final args = (
      sessionId: _controller.sessionId!,
      secaValue: _controller.selectedSeca ?? '',
      nReca: _controller.nReca ?? '',
      codMetrica: _controller.codMetrica ?? '',
      userName: widget.userName,
      clienteId: _controller.clienteId ?? '',
      plantaCodigo: _controller.plantaCodigo ?? '',
      instrumentoData: _controller.selectedInstrumentoData,
    );

    switch (servicio) {
      case 'VERIFICACIONES INTERNAS':
        return StacVerificacionesInternas(
          sessionId: args.sessionId,
          secaValue: args.secaValue,
          nReca: args.nReca,
          codMetrica: args.codMetrica,
          userName: args.userName,
          clienteId: args.clienteId,
          plantaCodigo: args.plantaCodigo,
          clienteNombre:
              _controller.selectedCliente?['nombre']?.toString() ?? '',
          clienteRazonSocial:
              _controller.selectedCliente?['razonsocial']?.toString() ?? '',
          plantaNombre: _controller.selectedPlanta?['nombre']?.toString() ?? '',
          plantaDireccion: _controller.selectedPlanta?['dir']?.toString() ?? '',
          plantaDepartamento:
              _controller.selectedPlanta?['dep']?.toString() ?? '',
          instrumentoData: args.instrumentoData,
        );
      case 'RELEVAMIENTO DE DATOS':
        return StacRelevamientoDeDatos(
          sessionId: args.sessionId,
          secaValue: args.secaValue,
          nReca: args.nReca,
          codMetrica: args.codMetrica,
          userName: args.userName,
          clienteId: args.clienteId,
          plantaCodigo: args.plantaCodigo,
          clienteNombre:
              _controller.selectedCliente?['nombre']?.toString() ?? '',
          clienteRazonSocial:
              _controller.selectedCliente?['razonsocial']?.toString() ?? '',
          plantaNombre: _controller.selectedPlanta?['nombre']?.toString() ?? '',
          plantaDireccion: _controller.selectedPlanta?['dir']?.toString() ?? '',
          plantaDepartamento:
              _controller.selectedPlanta?['dep']?.toString() ?? '',
          instrumentoData: args.instrumentoData,
        );
      case 'MNT PREVENTIVO AVANZADO':
        return StacMntPrvAvanzado(
          sessionId: args.sessionId,
          secaValue: args.secaValue,
          nReca: args.nReca,
          codMetrica: args.codMetrica,
          userName: args.userName,
          clienteId: args.clienteId,
          plantaCodigo: args.plantaCodigo,
          clienteNombre:
              _controller.selectedCliente?['nombre']?.toString() ?? '',
          clienteRazonSocial:
              _controller.selectedCliente?['razonsocial']?.toString() ?? '',
          plantaNombre: _controller.selectedPlanta?['nombre']?.toString() ?? '',
          plantaDireccion: _controller.selectedPlanta?['dir']?.toString() ?? '',
          plantaDepartamento:
              _controller.selectedPlanta?['dep']?.toString() ?? '',
          instrumentoData: args.instrumentoData,
        );
      case 'MNT PREVENTIVO REGULAR':
        return StilMntPrvRegular(
          sessionId: args.sessionId,
          secaValue: args.secaValue,
          nReca: args.nReca,
          codMetrica: args.codMetrica,
          userName: args.userName,
          clienteId: args.clienteId,
          plantaCodigo: args.plantaCodigo,
          clienteNombre:
              _controller.selectedCliente?['nombre']?.toString() ?? '',
          clienteRazonSocial:
              _controller.selectedCliente?['razonsocial']?.toString() ?? '',
          plantaNombre: _controller.selectedPlanta?['nombre']?.toString() ?? '',
          plantaDireccion: _controller.selectedPlanta?['dir']?.toString() ?? '',
          plantaDepartamento:
              _controller.selectedPlanta?['dep']?.toString() ?? '',
          instrumentoData: args.instrumentoData,
        );
      case 'MANTENIMIENTO CORRECTIVO':
        return StacMntCorrectivo(
          sessionId: args.sessionId,
          secaValue: args.secaValue,
          nReca: args.nReca,
          codMetrica: args.codMetrica,
          userName: args.userName,
          clienteId: args.clienteId,
          plantaCodigo: args.plantaCodigo,
          clienteNombre:
              _controller.selectedCliente?['nombre']?.toString() ?? '',
          clienteRazonSocial:
              _controller.selectedCliente?['razonsocial']?.toString() ?? '',
          plantaNombre: _controller.selectedPlanta?['nombre']?.toString() ?? '',
          plantaDireccion: _controller.selectedPlanta?['dir']?.toString() ?? '',
          plantaDepartamento:
              _controller.selectedPlanta?['dep']?.toString() ?? '',
          instrumentoData: args.instrumentoData,
        );
      case 'INSTALACIÓN':
        return StacInstalacion(
          sessionId: args.sessionId,
          secaValue: args.secaValue,
          nReca: args.nReca,
          codMetrica: args.codMetrica,
          userName: args.userName,
          clienteId: args.clienteId,
          plantaCodigo: args.plantaCodigo,
          clienteNombre:
              _controller.selectedCliente?['nombre']?.toString() ?? '',
          clienteRazonSocial:
              _controller.selectedCliente?['razonsocial']?.toString() ?? '',
          plantaNombre: _controller.selectedPlanta?['nombre']?.toString() ?? '',
          plantaDireccion: _controller.selectedPlanta?['dir']?.toString() ?? '',
          plantaDepartamento:
              _controller.selectedPlanta?['dep']?.toString() ?? '',
          instrumentoData: args.instrumentoData,
        );
      case 'DIAGNÓSTICO':
        return StacDiagnostico(
          sessionId: args.sessionId,
          secaValue: args.secaValue,
          nReca: args.nReca,
          codMetrica: args.codMetrica,
          userName: args.userName,
          clienteId: args.clienteId,
          plantaCodigo: args.plantaCodigo,
          clienteNombre:
              _controller.selectedCliente?['nombre']?.toString() ?? '',
          clienteRazonSocial:
              _controller.selectedCliente?['razonsocial']?.toString() ?? '',
          plantaNombre: _controller.selectedPlanta?['nombre']?.toString() ?? '',
          plantaDireccion: _controller.selectedPlanta?['dir']?.toString() ?? '',
          plantaDepartamento:
              _controller.selectedPlanta?['dep']?.toString() ?? '',
          instrumentoData: args.instrumentoData,
        );
      case 'AJUSTE DE VERIFICACIONES':
        return StacAjusteVerificaciones(
          sessionId: args.sessionId,
          secaValue: args.secaValue,
          nReca: args.nReca,
          codMetrica: args.codMetrica,
          userName: args.userName,
          clienteId: args.clienteId,
          plantaCodigo: args.plantaCodigo,
          clienteNombre:
              _controller.selectedCliente?['nombre']?.toString() ?? '',
          clienteRazonSocial:
              _controller.selectedCliente?['razonsocial']?.toString() ?? '',
          plantaNombre: _controller.selectedPlanta?['nombre']?.toString() ?? '',
          plantaDireccion: _controller.selectedPlanta?['dir']?.toString() ?? '',
          plantaDepartamento:
              _controller.selectedPlanta?['dep']?.toString() ?? '',
          instrumentoData: args.instrumentoData,
        );
      default:
        return null;
    }
  }

  List<StepData> _buildSteps() {
    final c = _controller;
    bool accessible(int i) => i <= c.currentStep || c.canProceedFromStep(i - 1);
    return [
      StepData(
          title: 'Servicio',
          subtitle: c.selectedServicio ?? 'Tipo de servicio',
          icon: Icons.build_circle_outlined),
      StepData(
          title: 'Cliente',
          subtitle:
              c.selectedCliente?['nombre']?.toString() ?? 'Seleccione cliente',
          icon: Icons.business,
          isAccessible: accessible(1)),
      StepData(
          title: 'Planta',
          subtitle:
              c.selectedPlanta?['nombre']?.toString() ?? 'Seleccione planta',
          icon: Icons.factory,
          isAccessible: accessible(2)),
      StepData(
          title: 'OTST',
          subtitle: c.selectedSeca ?? c.suggestedSeca ?? 'Confirmar OTST',
          icon: Icons.qr_code,
          isAccessible: accessible(3)),
      StepData(
          title: 'Instrumento',
          subtitle: c.selectedInstrumento ?? 'Seleccione instrumento',
          icon: Icons.scale,
          isAccessible: accessible(4)),
      StepData(
          title: 'Resumen',
          subtitle: 'Confirmar datos',
          icon: Icons.check_circle,
          isAccessible: accessible(5)),
    ];
  }

  List<Widget> _buildStepWidgets() {
    return [
      TipoServicioStep(
        servicios: PrecargaController.serviciosDisponibles,
        selectedServicio: _controller.selectedServicio,
        onServicioSelected: (s) => _controller.selectServicio(s),
      ),
      ClienteStep(
        controller: _controller,
      ),
      PlantaStep(
        controller: _controller,
      ),
      SecaStep(
        controller: _controller,
      ),
      BalanzaStep(
        controller: _controller,
      ),
      _buildResumenStep(),
    ];
  }

  Widget _buildResumenStep() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ServiceStepHeader(
            title: 'Resumen del Servicio',
            subtitle: 'Verifique todos los datos precargados antes de iniciar',
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                _resumenItem(
                    'Tipo Servicio', _controller.selectedServicio, isDark),
                const Divider(height: 16),
                _resumenItem('Cliente',
                    _controller.selectedCliente?['nombre']?.toString(), isDark),
                _resumenItem('Planta',
                    _controller.selectedPlanta?['nombre']?.toString(), isDark),
                _resumenItem('Código OTST', _controller.selectedSeca, isDark),
                const Divider(height: 16),
                _resumenItem(
                    'Instrumento', _controller.selectedInstrumento, isDark),
                _resumenItem('N° Reca', _controller.nReca, isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _resumenItem(String label, String? value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              (value != null && value.isNotEmpty) ? value : '—',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: (value != null && value.isNotEmpty)
                    ? (isDark ? Colors.white : const Color(0xFF1A1A1A))
                    : (isDark ? Colors.white24 : Colors.black26),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          final step = _controller.currentStep;
          final isLastStep = step == PrecargaController.totalSteps - 1;
          final isDark = Theme.of(context).brightness == Brightness.dark;

          String nextLabel = 'Siguiente';
          Color nextColor = const Color(0xFF498054);
          VoidCallback? onNext;

          if (step == 3 && !_controller.secaConfirmed) {
            nextLabel = 'Confirmar OTST';
            nextColor = const Color(0xFF1565C0);
            onNext = () async {
              final seca = _controller.suggestedSeca;
              if (seca == null || seca.isEmpty) return;
              final exists = await _controller.checkSecaExists(seca);
              if (!mounted) return;
              if (exists) {
                final proceed = await _showOtstDuplicadaDialog(seca, isDark);
                if (proceed != true || !mounted) return;
              }
              await _controller.confirmSeca();
            };
          } else if (step == 3 && _controller.secaConfirmed) {
            nextLabel = 'Siguiente';
            nextColor = const Color(0xFF498054);
            onNext = () => _goToStep(step + 1);
          } else if (isLastStep) {
            nextLabel = 'Iniciar Servicio';
            nextColor = const Color(0xFF3e7732);
            onNext = _iniciarServicio;
          } else {
            nextLabel = 'Siguiente';
            nextColor = const Color(0xFF498054);
            onNext = () => _goToStep(step + 1);
          }

          return ServiceWorkspaceLayout(
            title: 'Soporte Técnico',
            steps: _buildSteps(),
            stepWidgets: _buildStepWidgets(),
            currentStep: step,
            onStepTapped: _goToStep,
            nextLabel: nextLabel,
            nextColor: nextColor,
            onNext: onNext,
            onBack: step > 0 ? () => _goToStep(step - 1) : _confirmExit,
            showSaveStatus: false,
          );
        },
      ),
    );
  }
}
