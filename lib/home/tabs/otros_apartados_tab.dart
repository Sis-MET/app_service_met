// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:service_met/screens/precarga/descarga_de_datos.dart';
import '../../theme/app_colors.dart';

class OtrosApartadosTab extends StatelessWidget {
  final String userName;

  const OtrosApartadosTab({super.key, required this.userName});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        await Future.delayed(const Duration(milliseconds: 500));
      },
      color: Theme.of(context).colorScheme.primary,
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
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Herramientas',
          style: GoogleFonts.poppins(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: cs.onSurface,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Funciones complementarias para tu trabajo',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: cs.onSurface.withOpacity(0.54),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 500.ms).slideY(begin: -0.1);
  }

  Widget _buildServiceCard(
    BuildContext context, {
    required dynamic icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Duration delay,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final accent = cs.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.borderDarkSoft : AppColors.borderLight,
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
              SizedBox(
                width: 32,
                child: Center(
                  child: icon is IconData ? Icon(icon, size: 30, color: accent) : FaIcon(icon, size: 30, color: accent),
                ),
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
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: cs.onSurface.withOpacity(0.54),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: cs.onSurface.withOpacity(0.54),
              ),
            ],
          ),
        ),
      ),
    ).animate(delay: delay).fadeIn().slideX(begin: 0.1);
  }

  Widget _buildInfoSection(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final accent = cs.primary;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : const Color(0xFFF9F9F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.borderDarkSoft : AppColors.borderLight,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FaIcon(FontAwesomeIcons.circleInfo, color: accent, size: 18),
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
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Estas herramientas complementan los servicios principales, permitiendo descargar datos de DataMET y mantener la app actualizada.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: cs.onSurface.withOpacity(0.54),
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
