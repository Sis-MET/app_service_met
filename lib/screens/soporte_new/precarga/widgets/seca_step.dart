import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:service_met/screens/soporte_new/precarga/precarga_controller.dart';
import 'package:service_met/widgets/service_ui/input_decoration.dart';

class SecaStep extends StatefulWidget {
  final PrecargaController controller;

  const SecaStep({
    super.key,
    required this.controller,
  });

  @override
  State<SecaStep> createState() => _SecaStepState();
}

class _SecaStepState extends State<SecaStep> {
  late final TextEditingController _cotizacionController;

  @override
  void initState() {
    super.initState();
    _cotizacionController = TextEditingController(
      text: widget.controller.cotizacionSuffix,
    );
  }

  @override
  void dispose() {
    _cotizacionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = widget.controller;
    final isConfirmed = c.secaConfirmed;
    final currentSeca = isConfirmed
        ? c.selectedSeca
        : (c.suggestedSeca ?? '${c.plantaCodigo ?? "NNNN-NN"}-S01');

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ServiceStepHeader(
            title: 'Código OTST',
            subtitle: 'Confirmación del código único del servicio (SECA)',
          ),
          const SizedBox(height: 24),
          _buildInfoSummary(c, isDark),
          const SizedBox(height: 24),
          _buildOtstCard(c, isConfirmed, currentSeca, isDark),
          const SizedBox(height: 24),
          _buildFormatInfo(isDark),
        ],
      ),
    );
  }

  Widget _buildInfoSummary(PrecargaController c, bool isDark) {
    return Container(
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  color: isDark ? Colors.white54 : Colors.black54, size: 20),
              const SizedBox(width: 10),
              Text(
                'Resumen de Selección',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _summaryRow(
            'Servicio',
            c.selectedServicio ?? 'N/A',
            isDark,
          ),
          const SizedBox(height: 8),
          _summaryRow(
            'Cliente',
            c.selectedCliente?['nombre']?.toString() ?? 'N/A',
            isDark,
          ),
          const SizedBox(height: 8),
          _summaryRow(
            'Planta',
            c.selectedPlanta?['nombre']?.toString() ?? 'N/A',
            isDark,
          ),
          const SizedBox(height: 8),
          _summaryRow(
            'Cód. Planta',
            c.plantaCodigo ?? 'N/A',
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, bool isDark) {
    return Row(
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

  Widget _buildOtstCard(PrecargaController c, bool isConfirmed,
      String? currentSeca, bool isDark) {
    const accentColor = Color(0xFF46824B);
    final cardColor = isConfirmed
        ? (isDark ? accentColor.withOpacity(0.12) : const Color(0xFFE8F5E9))
        : (isDark ? const Color(0xFF2A2A2A) : Colors.white);

    final borderColor = isConfirmed
        ? accentColor
        : (isDark ? Colors.white12 : const Color(0xFFE2E8F0));

    final year = DateTime.now().year.toString().substring(2);
    final plantCod = c.plantaCodigo ?? 'NNNN-NN';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: isConfirmed ? 1.5 : 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isConfirmed ? 0.05 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        children: [
          Text(
            isConfirmed ? 'OTST (SECA) Confirmada' : 'OTST Sugerida',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: isConfirmed
                  ? (isDark ? Colors.lightGreenAccent : const Color(0xFF1B5E20))
                  : (isDark ? Colors.white54 : Colors.black54),
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 16),
          if (isConfirmed)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                ),
              ),
              child: Text(
                currentSeca ?? '',
                style: GoogleFonts.robotoMono(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                  letterSpacing: 2,
                ),
                textAlign: TextAlign.center,
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.05)
                    : const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$year-$plantCod-',
                    style: GoogleFonts.robotoMono(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                      letterSpacing: 1,
                    ),
                  ),
                  Container(
                    width: 70,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    child: TextField(
                      controller: _cotizacionController,
                      style: GoogleFonts.robotoMono(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? Colors.lightGreenAccent
                            : const Color(0xFF2E7D32),
                        letterSpacing: 1,
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: isDark ? Colors.black26 : Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: isDark
                                ? Colors.white12
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: isDark
                                ? Colors.white12
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: accentColor,
                            width: 2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        hintText: 'S01',
                      ),
                      textAlign: TextAlign.center,
                      maxLength: 3,
                      buildCounter: (context,
                              {required currentLength,
                              required isFocused,
                              maxLength}) =>
                          null,
                      onChanged: (value) {
                        c.setCotizacionSuffix(value);
                      },
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 20),
          if (isConfirmed)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Confirmado y Registrado',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFormatInfo(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF0F2F5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.help_outline_rounded,
              color: isDark ? Colors.white54 : Colors.black54, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Formato del Código OTST (SECA)',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'El código de servicio se compone de:\n'
                  '• Año actual (ej. ${DateTime.now().year.toString().substring(2)})\n'
                  '• Código de planta seleccionada\n'
                  '• Correlativo editable (S01, S02, etc.)',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: isDark ? Colors.white70 : Colors.black87,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
