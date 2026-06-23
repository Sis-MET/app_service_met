// Pantalla de carga para auto-login con animaciones mejoradas
// Diseño corporativo.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:service_met/theme/app_colors.dart';

class AutoLoginLoading extends StatelessWidget {
  final bool isDark;
  final String? savedUserFullName;
  final String? savedUser;

  const AutoLoginLoading({
    super.key,
    required this.isDark,
    this.savedUserFullName,
    this.savedUser,
  });

  @override
  Widget build(BuildContext context) {
    final primary = isDark ? Colors.white : AppColors.primary;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Avatar con glow sutil
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: primary.withOpacity(0.15),
                  blurRadius: 40,
                  spreadRadius: 5,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Icon(
              Icons.person_outline,
              size: 64,
              color: isDark ? Colors.white70 : primary,
            ),
          ).animate().scale(
                duration: 600.ms,
                curve: Curves.easeOutBack,
              ),

          const SizedBox(height: 32),

          Text(
            'Bienvenido de vuelta',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.textPrimaryLight,
            ),
          ).animate().fadeIn(duration: 400.ms, delay: 200.ms),

          const SizedBox(height: 8),

          Text(
            savedUserFullName ?? '@$savedUser',
            style: GoogleFonts.inter(
              fontSize: 16,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ).animate().fadeIn(duration: 400.ms, delay: 300.ms),

          const SizedBox(height: 40),

          // Indicador de carga
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              color: primary,
              strokeWidth: 4,
              strokeCap: StrokeCap.round,
            ),
          ).animate().fadeIn(duration: 300.ms, delay: 400.ms),

          const SizedBox(height: 16),

          Text(
            'Iniciando sesión...',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ).animate().fadeIn(duration: 300.ms, delay: 500.ms),
        ],
      ),
    );
  }
}
