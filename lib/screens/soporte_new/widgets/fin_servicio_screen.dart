import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:service_met/home/screens/home_screen.dart';
import 'package:service_met/screens/soporte_new/controllers/base_soporte_controller.dart';
import 'package:service_met/screens/soporte_new/precarga/precarga_screen.dart';
import 'package:service_met/utils/top_alert.dart';
import 'package:service_met/widgets/service_ui/service_app_bar.dart';
import 'package:service_met/theme/app_colors.dart';
import 'package:service_met/theme/app_design.dart';

class FinServicioConfig {
  final String tableNameDefault;
  final String additionalWhere;
  final String tipoServicio;
  final Color primaryColor;

  const FinServicioConfig({
    this.tableNameDefault = 'soporte_servicio',
    this.additionalWhere = '',
    this.tipoServicio = 'Servicio',
    this.primaryColor = AppColors.actionPositive,
  });
}

class FinServicioScreen extends StatefulWidget {
  final FinServicioConfig config;
  final BaseSoporteController controller;
  final String codMetrica;
  final String secaValue;
  final String clienteNombre;
  final String plantaNombre;
  final String selectedInstrumento;
  final String selectedMarca;
  final String selectedModelo;
  final String selectedCapMax;
  final String selectedDivMin;
  final String sessionId;
  final String nReca;
  final String userName;
  final String clienteId;
  final String plantaCodigo;
  final String tableName;

  const FinServicioScreen({
    super.key,
    required this.config,
    required this.controller,
    this.codMetrica = '',
    this.secaValue = '',
    this.clienteNombre = '',
    this.plantaNombre = '',
    this.selectedInstrumento = '',
    this.selectedMarca = '',
    this.selectedModelo = '',
    this.selectedCapMax = '',
    this.selectedDivMin = '',
    this.sessionId = '',
    this.nReca = '',
    this.userName = '',
    this.clienteId = '',
    this.plantaCodigo = '',
    this.tableName = '',
  });

  @override
  State<FinServicioScreen> createState() => _FinServicioScreenState();
}

class _FinServicioScreenState extends State<FinServicioScreen> {
  bool _isFinalizando = false;
  int _balanzasCount = 0;
  bool _isLoadingSummary = true;

  @override
  void initState() {
    super.initState();
    // Asegurar contexto en el controller (fallback central para todos los módulos)
    if (widget.controller.secaValue.isEmpty) {
      widget.controller.secaValue = widget.secaValue;
    }
    if (widget.controller.clienteNombre.isEmpty) {
      widget.controller.clienteNombre = widget.clienteNombre;
    }
    if (widget.controller.plantaNombre.isEmpty) {
      widget.controller.plantaNombre = widget.plantaNombre;
    }
    _prepareServiceSummary();
  }

  Future<void> _prepareServiceSummary() async {
    // Entrar al resumen no equivale a finalizar. La sesión debe continuar
    // recuperable hasta que el usuario confirme una de las acciones finales.
    await widget.controller.persistRecoveryProgress();
    await _loadBalanzasCount();
  }

  Future<void> _loadBalanzasCount() async {
    final seca = widget.secaValue;
    if (seca.isEmpty) {
      if (mounted) setState(() => _isLoadingSummary = false);
      return;
    }
    try {
      final registros = await widget.controller.getRegistrosPorSeca(
        widget.config.tableNameDefault,
        seca,
      );
      if (mounted) {
        setState(() {
          _balanzasCount = registros.length;
          _isLoadingSummary = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingSummary = false);
    }
  }

  Future<void> _finalizarServicioActual() async {
    await widget.controller.finalizarServicio(
      horaFin: widget.controller.horaFin,
      fechaProxServicio: widget.controller.fechaProxServicio,
    );
  }

  Future<void> _seleccionarOtraBalanza() async {
    final confirm = await _showConfirmDialog(
      title: 'CAMBIAR BALANZA',
      message: '¿Está seguro que desea seleccionar otra balanza?\n\n'
          'El servicio actual se guardará como completado.',
      confirmLabel: 'Sí, cambiar',
    );

    if (confirm != true || !mounted) return;

    try {
      await _finalizarServicioActual();
      await widget.controller.markRecoveryCompleted();

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PrecargaScreenSop(
            tableName: widget.config.tableNameDefault,
            userName: widget.userName,
            clienteId: widget.clienteId,
            plantaCodigo: widget.plantaCodigo,
            servicio: widget.config.tipoServicio,
            seca: widget.secaValue,
            skipToBalanza: true,
          ),
        ),
      );
    } catch (e, st) {
      debugPrint('Error al navegar: $e\n$st');
      if (mounted) {
        TopAlert.show(context, 'Error al navegar: $e', isError: true);
      }
    }
  }

  Future<void> _finalizar() async {
    final confirm = await _showConfirmDialog(
      title: 'Finalizar Servicio',
      message:
          '¿Está seguro que desea finalizar el servicio "${widget.config.tipoServicio}"?\n\n'
          'Se guardarán todos los datos y volverá al inicio.',
      confirmLabel: 'Sí, finalizar',
      isDestructive: false,
    );
    if (confirm != true || !mounted) return;

    setState(() => _isFinalizando = true);

    try {
      await _finalizarServicioActual();
      await widget.controller.markRecoveryCompleted();
      if (!mounted) return;
      TopAlert.show(
        context,
        'Servicio finalizado correctamente',
        isError: false,
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    } catch (e) {
      if (mounted) {
        TopAlert.show(context, 'Error al finalizar servicio: $e',
            isError: true);
      }
    } finally {
      if (mounted) setState(() => _isFinalizando = false);
    }
  }

  Future<bool?> _showConfirmDialog({
    required String title,
    required String message,
    String confirmLabel = 'Confirmar',
    String cancelLabel = 'Cancelar',
    bool isDestructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title,
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: widget.config.primaryColor)),
        content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [const SizedBox(height: 4), Text(message)]),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child:
                Text(cancelLabel, style: const TextStyle(color: Colors.grey)),
          ),
          FilledButton(
            style: isDestructive ? AppDesign.negativeButtonStyle() : null,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  String _titleCase(String s) {
    const lower = {'de', 'del', 'la', 'el', 'y', 'en'};
    return s.toLowerCase().split(' ').map((w) {
      if (w.isEmpty) return w;
      if (lower.contains(w)) return w;
      return w[0].toUpperCase() + w.substring(1);
    }).join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final saveStatus = widget.controller.isSaving
            ? SaveStatus.saving
            : (widget.controller.lastSaveSuccessful
                ? SaveStatus.success
                : SaveStatus.error);

        return Scaffold(
          appBar: ServiceAppBar(
            title: _titleCase(widget.config.tipoServicio),
            actions: [SaveStatusIndicator(status: saveStatus)],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(isDark),
                const SizedBox(height: 20),
                _buildResumenCard(isDark),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: _isFinalizando ? null : _seleccionarOtraBalanza,
                    icon: const Icon(Icons.add_circle_outline_rounded),
                    label: const Text('SELECCIONAR OTRA BALANZA',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ).animate(delay: 300.ms).fadeIn().scale(),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: _isFinalizando ? null : _finalizar,
                    icon: _isFinalizando
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    AppColors.actionPositiveInk)))
                        : const Icon(Icons.check_circle_outline_rounded),
                    label: const Text('FINALIZAR SERVICIO',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ).animate(delay: 400.ms).fadeIn().scale(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Finalización',
          style: GoogleFonts.poppins(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF1A1A1A),
            height: 1.1,
          ),
        ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.2),
        const SizedBox(height: 4),
        Text(
          'Revisa el resumen antes de cerrar el servicio',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: isDark ? Colors.white54 : Colors.black45,
            fontWeight: FontWeight.w400,
          ),
        ).animate(delay: 100.ms).fadeIn(duration: 400.ms),
      ],
    );
  }

  Widget _buildResumenCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.summarize_rounded,
                  color: isDark ? Colors.white54 : Colors.black54, size: 20),
              const SizedBox(width: 10),
              Text(
                'Resumen del Servicio',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _row('OTST', widget.secaValue, isDark),
          const SizedBox(height: 8),
          _row('Balanzas atendidas',
              _isLoadingSummary ? 'Cargando...' : '$_balanzasCount', isDark),
          const SizedBox(height: 8),
          _row('Fecha', DateFormat('dd MMM yyyy').format(DateTime.now()),
              isDark),
        ],
      ),
    ).animate(delay: 200.ms).fadeIn();
  }

  Widget _row(String label, String value, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF1A1A1A),
            ),
          ),
        ),
      ],
    );
  }
}
