import 'package:flutter/material.dart';
import 'package:service_met/utils/top_alert.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:service_met/models/service_session.dart';
import 'package:service_met/providers/service_session_provider.dart';
import 'package:service_met/home/screens/home_screen.dart';

class ExportacionStep extends StatefulWidget {
  const ExportacionStep({super.key});

  @override
  State<ExportacionStep> createState() => _ExportacionStepState();
}

class _ExportacionStepState extends State<ExportacionStep> {
  String? _emp;
  String? _regla;
  final _indicarCtrl = TextEditingController();
  final _factorCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initFromSession());
  }

  void _initFromSession() {
    final provider = context.read<ServiceSessionProvider>();
    final exp = provider.session?.exportacion;
    if (exp != null) {
      setState(() {
        _emp = exp.emp23001;
        _regla = exp.reglaAceptacion;
        _indicarCtrl.text = exp.indicar ?? '';
        _factorCtrl.text = exp.factorSeguridad ?? '';
      });
    }
  }

  void _saveToProvider() {
    final provider = context.read<ServiceSessionProvider>();
    provider.updateExportacion(ExportacionData(
      emp23001: _emp,
      indicar: _indicarCtrl.text,
      factorSeguridad: _factorCtrl.text,
      reglaAceptacion: _regla,
    ));
  }

  Future<void> _seleccionarOtraBalanza(ServiceSessionProvider provider) async {
    await provider.marcarBalanzaCompleta();
    provider.resetearParaNuevaBalanza();
  }

  Future<void> _exportar(ServiceSessionProvider provider) async {
    _saveToProvider();
    await provider.flushAutoSave();

    final seca = provider.session?.sessionInfo.seca;
    if (seca == null || seca.isEmpty) {
      if (mounted) TopAlert.show(context, 'SECA no disponible', isError: true);
      return;
    }

    final registrosHoy =
        await provider.getRegistrosCompletos(seca, soloHoy: true);
    final registrosTodas =
        await provider.getRegistrosCompletos(seca, soloHoy: false);

    if (!mounted) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final opcion = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.file_download_rounded,
                color: isDark ? Colors.green[300] : Colors.green[700],
                size: 22),
            const SizedBox(width: 8),
            Expanded(
                child: Text('Exportar datos',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? Colors.white
                            : const Color(0xFF1A1A1A)))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¿Qué balanzas desea exportar?',
              style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white70 : Colors.black87),
            ),
            const SizedBox(height: 16),
            _opcionExportacion(
              ctx,
              icon: Icons.today_rounded,
              titulo: 'Solo las de hoy',
              subtitulo: '${registrosHoy.length} balanza(s)',
              isDark: isDark,
              onTap: () => Navigator.pop(ctx, 'hoy'),
            ),
            const SizedBox(height: 12),
            _opcionExportacion(
              ctx,
              icon: Icons.calendar_month_rounded,
              titulo: 'Todas las del SECA',
              subtitulo: '${registrosTodas.length} balanza(s)',
              isDark: isDark,
              onTap: () => Navigator.pop(ctx, 'todas'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar',
                style: TextStyle(
                    color: isDark ? Colors.white60 : Colors.black54)),
          ),
        ],
      ),
    );

    if (opcion == null || !mounted) return;

    final registros =
        opcion == 'hoy' ? registrosHoy : registrosTodas;
    if (registros.isEmpty) {
      TopAlert.show(context, 'No hay registros para exportar', isError: true);
      return;
    }

    final success = await provider.exportToCSV(registros);
    if (!mounted) return;

    if (success) {
      TopAlert.show(context,
          'Exportación exitosa: ${registros.length} balanza(s) exportada(s)',
          isError: false);
      Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()), (r) => false);
    } else {
      TopAlert.show(context, 'Error al exportar CSV', isError: true);
    }
  }

  Widget _opcionExportacion(
    BuildContext ctx, {
    required IconData icon,
    required String titulo,
    required String subtitulo,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF0F2F5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: isDark ? Colors.white54 : Colors.black54, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo,
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF1A1A1A))),
                  const SizedBox(height: 2),
                  Text(subtitulo,
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          color: isDark ? Colors.white60 : Colors.black54)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: isDark ? Colors.white24 : Colors.black26),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _indicarCtrl.dispose();
    _factorCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ServiceSessionProvider>(
      builder: (context, provider, _) {
        final session = provider.session;
        final info = session?.sessionInfo;
        final seca = info?.seca ?? 'Sin SECA';
        final cod = info?.codMetrica ?? 'Sin Codigo';
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(isDark),
              const SizedBox(height: 20),
              _buildResumenCard(seca, cod, isDark),
              const SizedBox(height: 24),
              _sectionHeader('Datos para el Certificado', isDark),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _emp,
                decoration: _deco('EMP NB 23001', isDark),
                dropdownColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                items: ['Sí', 'No']
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
                onChanged: (v) {
                  setState(() => _emp = v);
                  _saveToProvider();
                },
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                    child: TextField(
                        style: GoogleFonts.inter(
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1A1A1A)),
                        controller: _indicarCtrl,
                        onChanged: (_) => _saveToProvider(),
                        keyboardType: TextInputType.number,
                        decoration: _deco('Indicar (%)', isDark))),
                const SizedBox(width: 12),
                Expanded(
                    child: TextField(
                        style: GoogleFonts.inter(
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1A1A1A)),
                        controller: _factorCtrl,
                        onChanged: (_) => _saveToProvider(),
                        keyboardType: TextInputType.number,
                        decoration: _deco('Factor Seguridad', isDark))),
              ]),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _regla,
                decoration: _deco('Regla de Aceptación', isDark),
                dropdownColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                items: ['Ninguna', 'Simple', 'Conservadora']
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
                onChanged: (v) {
                  setState(() => _regla = v);
                  _saveToProvider();
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () => _seleccionarOtraBalanza(provider),
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  label: const Text('SELECCIONAR OTRA BALANZA',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF326677),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ).animate(delay: 300.ms).fadeIn().scale(),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () => _exportar(provider),
                  icon: const Icon(Icons.file_download),
                  label: const Text('FINALIZAR Y EXPORTAR',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3e7732),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ).animate(delay: 400.ms).fadeIn().scale(),
            ],
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
          'Exportación',
          style: GoogleFonts.poppins(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF1A1A1A),
            height: 1.1,
          ),
        ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.2),
        const SizedBox(height: 4),
        Text(
          'Finalización del servicio y descarga de datos',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: isDark ? Colors.white54 : Colors.black45,
            fontWeight: FontWeight.w400,
          ),
        ).animate(delay: 100.ms).fadeIn(duration: 400.ms),
      ],
    );
  }

  Widget _buildResumenCard(String seca, String cod, bool isDark) {
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
          _row('SECA', seca, isDark),
          const SizedBox(height: 8),
          _row('Código Métrica', cod, isDark),
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
          width: 120,
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

  Widget _sectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(title,
          style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1A1A1A))),
    ).animate().fadeIn();
  }

  InputDecoration _deco(String label, bool isDark) => InputDecoration(
        labelText: label,
        labelStyle:
            GoogleFonts.inter(color: isDark ? Colors.white70 : Colors.black87),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                BorderSide(color: isDark ? Colors.white24 : Colors.black26)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                BorderSide(color: isDark ? Colors.white12 : Colors.black12)),
      );
}
