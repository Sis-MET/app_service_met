// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_design.dart';

class StepData {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isAccessible;

  const StepData({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.isAccessible = true,
  });
}

class StepIndicator extends StatelessWidget {
  final int currentStep;
  final List<StepData> steps;
  final ValueChanged<int>? onStepTapped;

  const StepIndicator({
    super.key,
    required this.currentStep,
    required this.steps,
    this.onStepTapped,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final safeStep = currentStep.clamp(0, steps.length - 1);
    final step = steps[safeStep];
    const primaryColor = AppColors.actionPositive;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: AppDesign.mediumRadius,
        border: Border.all(
          color: isDark
              ? AppColors.borderDarkSoft
              : AppColors.accentYellow.withOpacity(0.22),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentYellow.withOpacity(isDark ? 0.03 : 0.07),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Fila compacta ──────────────────────────────────────────
          Row(
            children: [
              // Pill con icono + nombre del paso
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.accentYellow.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.accentYellow.withOpacity(0.34),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(step.icon, size: 13, color: primaryColor),
                    const SizedBox(width: 5),
                    Text(
                      step.title,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // Subtitle sutil
              Expanded(
                child: Text(
                  step.subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Contador "1 / 4"
              Text(
                '${safeStep + 1} / ${steps.length}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // ── Barra de progreso delgada segmentada ───────────────────
          Row(
            children: List.generate(steps.length, (i) {
              final isCompleted = i < safeStep;
              final isCurrent = i == safeStep;
              final isAccessible = steps[i].isAccessible;

              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (isAccessible && onStepTapped != null) {
                      onStepTapped!(i);
                    }
                  },
                  child: Container(
                    height: 12, // Taller touch area
                    color: Colors.transparent,
                    alignment: Alignment.center,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      height: 3,
                      margin: EdgeInsets.only(left: i == 0 ? 0 : 3),
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? primaryColor
                            : isCurrent
                                ? AppColors.accentYellow
                                : (isAccessible
                                    ? (isDark
                                        ? Colors.white24
                                        : Colors.black.withOpacity(0.15))
                                    : (isDark
                                        ? Colors.white12
                                        : Colors.black.withOpacity(0.05))),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),

          const SizedBox(height: 4),
        ],
      ),
    );
  }
}
