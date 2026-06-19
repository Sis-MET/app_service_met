// lib/login/widgets/setup/step_indicator.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:service_met/theme/app_colors.dart';

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
    final accent = AppColors.accentYellow;

    return Row(
      children: [
        Expanded(
          child: _buildStep(0, 'Conexión', accent),
        ),
        Container(
          width: 40,
          height: 2,
          color: currentStep >= 1
              ? accent
              : (isDark ? Colors.white24 : Colors.black12),
        ),
        Expanded(
          child: _buildStep(1, 'Usuario', accent),
        ),
      ],
    );
  }

  Widget _buildStep(int step, String label, Color accent) {
    final isActive = currentStep == step;
    final isCompleted = currentStep > step;

    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isCompleted || isActive
                ? accent
                : (isDark ? Colors.white12 : Colors.black12),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, color: Colors.white, size: 20)
                : Text(
                    '${step + 1}',
                    style: GoogleFonts.inter(
                      color: isActive
                          ? Colors.white
                          : (isDark ? Colors.white38 : Colors.black38),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
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
            color: isActive
                ? accent
                : (isDark ? Colors.white60 : Colors.black54),
          ),
        ),
      ],
    );
  }
}
