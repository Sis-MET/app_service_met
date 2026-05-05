// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:service_met/screens/precarga/descarga_de_datos.dart';

class OtrosApartadosTab extends StatelessWidget {
  final String userName;

  const OtrosApartadosTab({super.key, required this.userName});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        await Future.delayed(const Duration(milliseconds: 500));
      },
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF4A90E2)
          : const Color(0xFF04376E),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 30, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Encabezado ──
            _buildHeader(context),
            const SizedBox(height: 40),

            // ── Lista de Herramientas ──
            _buildServiceCard(
              context,
              icon: FontAwesomeIcons.cloudArrowDown,
              title: 'Precarga BD Principal',
              subtitle: 'Descarga de datos de clientes, plantas y equipos desde DataMET',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        DescargaDeDatosScreen(userName: userName),
                  ),
                );
              },
              delay: 300.ms,
            ),

            const SizedBox(height: 30),

            // ── Información ──
            _buildInfoSection(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Herramientas',
          style: GoogleFonts.poppins(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF1A1A1A),
            height: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Funciones complementarias para tu trabajo',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: isDark ? Colors.white54 : Colors.black54,
          ),
        ),
      ],
    ).animate().fadeIn(duration: 500.ms).slideY(begin: -0.1);
  }

  Widget _buildServiceCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Duration delay,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? const Color(0xFF4A90E2) : const Color(0xFF04376E);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, size: 22, color: accent),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: isDark ? Colors.white54 : Colors.black54,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF2A2A2A)
                      : const Color(0xFFF5F5F5),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate(delay: delay).fadeIn().slideX(begin: 0.1);
  }

  Widget _buildInfoSection(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? const Color(0xFF4A90E2) : const Color(0xFF04376E);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF9F9F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(FontAwesomeIcons.circleInfo, color: accent, size: 18),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Herramientas Complementarias',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Estas herramientas complementan los servicios principales, permitiendo descargar datos de DataMET y mantener la app actualizada.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: isDark ? Colors.white54 : Colors.black54,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate(delay: 500.ms).fadeIn().slideY(begin: 0.1);
  }
}
