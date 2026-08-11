// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

/// Tarjeta con el interruptor "Realizar prueba" que permite al usuario
/// omitir una prueba metrológica en los módulos de soporte técnico.
class PruebaSkipCard extends StatelessWidget {
  final bool realizada;
  final ValueChanged<bool> onChanged;
  final String nombrePrueba;

  const PruebaSkipCard({
    super.key,
    required this.realizada,
    required this.onChanged,
    required this.nombrePrueba,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const activeColor = Color(0xFF46824B);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: realizada
              ? activeColor.withOpacity(0.45)
              : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: realizada
                  ? activeColor.withOpacity(isDark ? 0.2 : 0.12)
                  : (isDark ? Colors.white12 : const Color(0xFFF0F2F5)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              realizada
                  ? Icons.science_outlined
                  : Icons.do_not_disturb_alt_outlined,
              size: 20,
              color: realizada
                  ? activeColor
                  : (isDark ? Colors.white38 : Colors.black38),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Realizar $nombrePrueba',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  realizada
                      ? 'La prueba se registrará en el reporte'
                      : 'Prueba omitida: no se registrará',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: realizada,
            onChanged: onChanged,
            activeColor: Colors.white,
            activeTrackColor: activeColor,
            inactiveThumbColor: isDark ? Colors.white54 : Colors.black45,
            inactiveTrackColor:
                isDark ? Colors.white24 : const Color(0xFFE2E8F0),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}

/// Estado mostrado cuando el usuario omitió la prueba.
class PruebaOmitidaCard extends StatelessWidget {
  const PruebaOmitidaCard({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.do_not_disturb_alt_outlined,
            size: 44,
            color: isDark ? Colors.white24 : Colors.black26,
          ),
          const SizedBox(height: 12),
          Text(
            'Prueba omitida',
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Active el interruptor superior si desea registrar esta prueba.',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: isDark ? Colors.white38 : Colors.black45,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}

/// Tarjeta con el botón para copiar los valores de la prueba inicial
/// hacia la prueba final.
class PruebaCopiarCard extends StatelessWidget {
  final VoidCallback onCopiar;

  const PruebaCopiarCard({super.key, required this.onCopiar});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        children: [
          Text(
            '¿Desea duplicar los valores iniciales para la prueba final?',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: onCopiar,
            icon: const Icon(Icons.content_copy_rounded, size: 18),
            label: Text(
              'Copiar Inicial a Final',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}

/// Título de sección para separar la prueba inicial de la final.
class PruebaSectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;

  const PruebaSectionTitle({
    super.key,
    required this.title,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        Icon(icon, size: 20, color: isDark ? Colors.white54 : Colors.black54),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Divider(
            color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
            thickness: 1,
          ),
        ),
      ],
    ).animate().fadeIn(duration: 300.ms);
  }
}
