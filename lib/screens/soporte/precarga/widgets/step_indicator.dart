// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

class StepData {
  final String title;
  final String subtitle;
  final IconData icon;

  const StepData({
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}

class StepIndicator extends StatelessWidget {
  final int currentStep;
  final List<StepData> steps;

  const StepIndicator({
    super.key,
    required this.currentStep,
    required this.steps,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final safeStep = currentStep.clamp(0, steps.length - 1);
    final step = steps[safeStep];
    final primaryColor = Theme.of(context).primaryColor;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      color: Colors.transparent,
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
                  color: primaryColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: primaryColor.withOpacity(0.3),
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

              return Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  height: 3,
                  margin: EdgeInsets.only(left: i == 0 ? 0 : 3),
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? primaryColor
                        : isCurrent
                            ? primaryColor.withOpacity(0.55)
                            : (isDark
                                ? Colors.white12
                                : Colors.black.withOpacity(0.08)),
                    borderRadius: BorderRadius.circular(2),
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
