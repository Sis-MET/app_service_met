// ignore_for_file: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member, deprecated_member_use

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../fin_servicios_controller.dart';

class ExportacionStep extends StatelessWidget {
  const ExportacionStep({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<FinServiciosController>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────
          _SectionHeader(
            icon: Icons.summarize_rounded,
            label: 'Resumen del Servicio',
            color: const Color(0xFF667EEA),
          ),
          const SizedBox(height: 12),
          _ResumenCard(controller: controller, isDark: isDark),

          const SizedBox(height: 24),

          // ── Formulario de exportación ────────────────────────────────
          _SectionHeader(
            icon: Icons.tune_rounded,
            label: 'Datos para el Certificado',
            color: const Color(0xFF667EEA),
          ),
          const SizedBox(height: 12),
          _ExportForm(controller: controller, isDark: isDark),

          const SizedBox(height: 28),

          // ── Acción: Exportar ─────────────────────────────────────────
          _ExportButton(controller: controller),

          const SizedBox(height: 16),

          // ── Divisor ─────────────────────────────────────────────────
          Row(
            children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'o también',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
              ),
              const Expanded(child: Divider()),
            ],
          ),

          const SizedBox(height: 16),

          // ── Acción secundaria: Otra balanza ──────────────────────────
          _OtraBalanzaButton(controller: controller, isDark: isDark),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Widgets internos
// ────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _SectionHeader({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: color,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

class _ResumenCard extends StatelessWidget {
  final FinServiciosController controller;
  final bool isDark;

  const _ResumenCard({required this.controller, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final fecha = DateFormat('dd MMM yyyy • HH:mm').format(DateTime.now());

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF1A2A4A), const Color(0xFF0F1E35)]
              : [const Color(0xFFF0F4FF), const Color(0xFFE8EEFF)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF667EEA).withOpacity(0.25),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Fila principal: SECA + Código
          Row(
            children: [
              Expanded(
                child: _InfoChip(
                  icon: Icons.tag_rounded,
                  label: 'SECA',
                  value: controller.secaValue,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _InfoChip(
                  icon: Icons.qr_code_rounded,
                  label: 'Código',
                  value: controller.codMetrica,
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Fila secundaria: Fecha + Estado
          Row(
            children: [
              Expanded(
                child: _InfoChip(
                  icon: Icons.calendar_today_rounded,
                  label: 'Fecha',
                  value: fecha,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _InfoChip(
                  icon: Icons.verified_rounded,
                  label: 'Estado',
                  value: 'Calibrada',
                  isDark: isDark,
                  highlight: true,
                ),
              ),
            ],
          ),
          // Sticker preview si hay datos
          if (controller.stickerCertificado.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF667EEA).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFF667EEA).withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.workspace_premium_rounded,
                      size: 18, color: Color(0xFF667EEA)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nro. Certificado',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: isDark ? Colors.white54 : Colors.black45,
                          ),
                        ),
                        Text(
                          controller.stickerCertificado,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF667EEA),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isDark;
  final bool highlight;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.isDark,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: highlight ? Colors.green.withOpacity(0.4) : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 14,
            color: highlight
                ? Colors.green
                : isDark
                    ? Colors.white54
                    : Colors.black38,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: highlight
                        ? Colors.green
                        : isDark
                            ? Colors.white
                            : Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExportForm extends StatelessWidget {
  final FinServiciosController controller;
  final bool isDark;

  const _ExportForm({required this.controller, required this.isDark});

  InputDecoration _deco(String label) => InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(fontSize: 13),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark
                ? Colors.white.withOpacity(0.15)
                : Colors.black.withOpacity(0.12),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? Colors.white70 : Colors.black54,
            width: 1.5,
          ),
        ),
        filled: true,
        fillColor: isDark
            ? Colors.white.withOpacity(0.04)
            : Colors.black.withOpacity(0.02),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.07),
        ),
        color: isDark ? Colors.white.withOpacity(0.03) : Colors.white,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // EMP NB 23001
          DropdownButtonFormField<String>(
            decoration: _deco('EMP NB 23001'),
            value: controller.selectedEmp23001,
            hint: Text('Seleccionar', style: GoogleFonts.inter(fontSize: 13)),
            items: ['Sí', 'No']
                .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                .toList(),
            onChanged: (v) {
              controller.selectedEmp23001 = v;
              controller.notifyListeners();
            },
          ),
          const SizedBox(height: 12),
          // Indicar + Factor en fila
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: controller.indicarController,
                  decoration: _deco('Indicar (%)'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                  ],
                  style: GoogleFonts.inter(fontSize: 13),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: controller.factorSeguridadController,
                  decoration: _deco('Factor Seguridad'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                  ],
                  style: GoogleFonts.inter(fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Regla de aceptación
          DropdownButtonFormField<String>(
            decoration: _deco('Regla de Aceptación'),
            value: controller.selectedReglaAceptacion,
            hint: Text('Seleccionar', style: GoogleFonts.inter(fontSize: 13)),
            items: ['Ninguna', 'Simple', 'Conservadora']
                .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                .toList(),
            onChanged: (v) {
              controller.selectedReglaAceptacion = v;
              controller.notifyListeners();
            },
          ),
        ],
      ),
    );
  }
}

class _ExportButton extends StatefulWidget {
  final FinServiciosController controller;

  const _ExportButton({required this.controller});

  @override
  State<_ExportButton> createState() => _ExportButtonState();
}

class _ExportButtonState extends State<_ExportButton> {
  bool _complete = false;

  @override
  void initState() {
    super.initState();
    // Escuchar cambios en los TextFields para recalcular
    widget.controller.indicarController.addListener(_update);
    widget.controller.factorSeguridadController.addListener(_update);
    widget.controller.addListener(_update);
    _update();
  }

  void _update() {
    final c = widget.controller;
    final ok = c.selectedEmp23001 != null &&
        c.indicarController.text.trim().isNotEmpty &&
        c.factorSeguridadController.text.trim().isNotEmpty &&
        c.selectedReglaAceptacion != null;
    if (mounted && ok != _complete) setState(() => _complete = ok);
  }

  @override
  void dispose() {
    widget.controller.indicarController.removeListener(_update);
    widget.controller.factorSeguridadController.removeListener(_update);
    widget.controller.removeListener(_update);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final exporting = widget.controller.isExporting;
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: _complete && !exporting
            ? () async {
                final registros = await widget.controller.prepareExportData();
                if (registros.isNotEmpty && context.mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => _ResumenExportacionScreen(
                        cantidad: registros.length,
                        seca: widget.controller.secaValue,
                        registros: registros,
                        onExport: widget.controller.executeExport,
                      ),
                    ),
                  );
                }
              }
            : null,
        icon: exporting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.file_download_rounded, size: 20),
        label: Text(
          exporting
              ? 'Exportando...'
              : _complete
                  ? 'Generar y Exportar CSV'
                  : 'Complete los campos para continuar',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _complete ? const Color(0xFF2E7D32) : null,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey[300],
          disabledForegroundColor: Colors.grey[600],
          elevation: _complete ? 2 : 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

class _OtraBalanzaButton extends StatelessWidget {
  final FinServiciosController controller;
  final bool isDark;

  const _OtraBalanzaButton({required this.controller, required this.isDark});

  Future<void> _confirmar(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Registrar otra balanza',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: const Text(
            '¿Deseas registrar otra balanza del mismo servicio? Se iniciará un nuevo registro manteniendo los datos del cliente.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await controller.confirmarSeleccionOtraBalanza();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton.icon(
        onPressed: () => _confirmar(context),
        icon: const Icon(Icons.swap_horiz_rounded, size: 16),
        label: Text(
          'Registrar otra balanza',
          style: GoogleFonts.inter(fontSize: 13),
        ),
        style: TextButton.styleFrom(
          foregroundColor: isDark ? Colors.white54 : Colors.black45,
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Pantalla de resumen antes de exportar (sin cambios en lógica)
// ────────────────────────────────────────────────────────────────────────────

class _ResumenExportacionScreen extends StatefulWidget {
  final int cantidad;
  final String seca;
  final List<Map<String, dynamic>> registros;
  final Future<void> Function(List<Map<String, dynamic>>) onExport;

  const _ResumenExportacionScreen({
    required this.cantidad,
    required this.seca,
    required this.registros,
    required this.onExport,
  });

  @override
  _ResumenExportacionScreenState createState() =>
      _ResumenExportacionScreenState();
}

class _ResumenExportacionScreenState extends State<_ResumenExportacionScreen> {
  late Future<Map<String, dynamic>> _resumenFuture;

  @override
  void initState() {
    super.initState();
    _resumenFuture = _generarResumen();
  }

  Future<Map<String, dynamic>> _generarResumen() async {
    final balanzasUnicas = <String, Map<String, dynamic>>{};
    for (final r in widget.registros) {
      final cod = r['cod_metrica']?.toString() ?? 'N/A';
      if (!balanzasUnicas.containsKey(cod)) {
        balanzasUnicas[cod] = {
          'cod_metrica': cod,
          'marca': r['marca']?.toString() ?? 'N/A',
          'modelo': r['modelo']?.toString() ?? 'N/A',
          'cantidad': 0,
        };
      }
      balanzasUnicas[cod]!['cantidad'] =
          (balanzasUnicas[cod]!['cantidad'] as int) + 1;
    }
    return {
      'totalBalanzas': balanzasUnicas.length,
      'totalRegistros': widget.registros.length,
      'balanzas': balanzasUnicas.values.toList(),
      'fecha': DateFormat('dd-MM-yyyy HH:mm').format(DateTime.now()),
      'seca': widget.seca,
    };
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: AppBar(
              toolbarHeight: 70,
              title: Text(
                'RESUMEN DE EXPORTACIÓN',
                style: GoogleFonts.poppins(
                  color: isDark ? Colors.white : Colors.black,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              backgroundColor: isDark
                  ? Colors.black.withOpacity(0.4)
                  : Colors.white.withOpacity(0.7),
              elevation: 0,
              centerTitle: true,
              iconTheme:
                  IconThemeData(color: isDark ? Colors.white : Colors.black),
            ),
          ),
        ),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _resumenFuture,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final res = snap.data!;
          final balanzas = res['balanzas'] as List<Map<String, dynamic>>;
          final totalBalanzas = res['totalBalanzas'] as int;
          final totalRegistros = res['totalRegistros'] as int;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Banner resumen
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2E7D32), Color(0xFF388E3C)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.check_circle_rounded,
                              color: Colors.white, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            'Listo para exportar',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _ResRow('SECA', res['seca']),
                      _ResRow('Fecha / Hora', res['fecha']),
                      _ResRow('Balanzas calibradas', '$totalBalanzas'),
                      _ResRow('Total de registros', '$totalRegistros'),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                Text(
                  'DETALLE DE BALANZAS',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: const Color(0xFF667EEA),
                  ),
                ),
                const SizedBox(height: 10),

                ...balanzas.asMap().entries.map((e) {
                  final i = e.key;
                  final b = e.value;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withOpacity(0.08)
                            : Colors.black.withOpacity(0.07),
                      ),
                      color: isDark
                          ? Colors.white.withOpacity(0.03)
                          : Colors.white,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFF667EEA).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              '${i + 1}',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF667EEA),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                b['cod_metrica'],
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                '${b['marca']} · ${b['modelo']}',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color:
                                      isDark ? Colors.white54 : Colors.black45,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${b['cantidad']} reg.',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.green[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),

                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: () => widget.onExport(widget.registros),
                    icon: const Icon(Icons.file_download_rounded, size: 20),
                    label: Text(
                      'CONFIRMAR Y EXPORTAR CSV',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ResRow extends StatelessWidget {
  final String label;
  final String value;
  const _ResRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: GoogleFonts.inter(fontSize: 13, color: Colors.white70)),
          Text(value,
              style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
        ],
      ),
    );
  }
}
