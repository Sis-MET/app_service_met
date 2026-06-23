// Tarjeta informativa que explica el paso actual del wizard de configuración.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:service_met/theme/app_colors.dart';

class InfoCard extends StatelessWidget {
  final bool isDark;
  final int currentStep;

  const InfoCard({
    super.key,
    required this.isDark,
    required this.currentStep,
  });

  @override
  Widget build(BuildContext context) {
    final message = currentStep == 0
        ? 'Paso 1 de 2: Conéctate al servidor SQL Server para descargar los datos maestros necesarios.'
        : 'Paso 2 de 2: Ingresa tus credenciales de la aplicación para configurar el acceso automático.';

    final accent = isDark ? Colors.white : AppColors.primary;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accent.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: accent,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: isDark ? Colors.white70 : Colors.black87,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
