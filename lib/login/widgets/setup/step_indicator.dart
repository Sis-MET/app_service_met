// Indicador de pasos del wizard de configuración inicial.
// Muestra el progreso entre el paso de conexión y el de usuario.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:service_met/theme/app_colors.dart';
import '../../../theme/app_icons.dart';

class StepIndicator extends StatelessWidget {
  final int currentStep;
  final bool isDark;

  const StepIndicator({
    super.key,
    required this.currentStep,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final accent = isDark ? Colors.white : AppColors.primary;

    return Row(
      children: [
        Expanded(child: _buildStep(0, 'Conexión', accent)),
        Container(
          height: 3,
          decoration: BoxDecoration(
            color: currentStep >= 1
                ? accent
                : (isDark ? Colors.white24 : Colors.black12),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Expanded(child: _buildStep(1, 'Usuario', accent)),
      ],
    );
  }

  Widget _buildStep(int step, String label, Color accent) {
    final isActive = currentStep == step;
    final isCompleted = currentStep > step;

    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: isCompleted || isActive ? accent : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(
              color: isCompleted || isActive
                  ? accent
                  : (isDark ? Colors.white24 : Colors.black12),
              width: 2,
            ),
          ),
          child: Center(
            child: isCompleted
                ? Icon(AppIcons.listo,
                    color: isDark ? const Color(0xFF292929) : Colors.white,
                    size: 22)
                : Text(
                    '${step + 1}',
                    style: GoogleFonts.inter(
                      color: isActive
                          ? (isDark ? const Color(0xFF292929) : Colors.white)
                          : (isDark ? Colors.white38 : Colors.black38),
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            color:
                isActive ? accent : (isDark ? Colors.white60 : Colors.black54),
          ),
        ),
      ],
    );
  }
}
