// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_design.dart';
import 'step_indicator.dart';

/// Panel lateral de un servicio con todos sus pasos, que se abre con ≡ en el
/// AppBar (como la lista de conversaciones de la app de Claude).
///
/// Marca los pasos completos, los que quedaron por revisar y el paso actual,
/// y lleva a cualquiera que esté habilitado. Reemplaza a la barra de pasos
/// bajo el AppBar: el espacio queda para el paso.
class ServiceStepsDrawer extends StatelessWidget {
  /// Nombre del servicio, arriba del panel.
  final String title;

  /// Pasos con su progreso. Sin progreso, cuenta como completo todo lo
  /// anterior al paso actual.
  final List<StepData> steps;

  final int currentStep;

  /// Paso elegido, ya con el panel cerrándose. El que la recibe decide si se
  /// puede ir (validar el paso actual, guardar…).
  final ValueChanged<int>? onStepSelected;

  const ServiceStepsDrawer({
    super.key,
    required this.title,
    required this.steps,
    required this.currentStep,
    this.onStepSelected,
  });

  /// "Paso 3 de 11 · SECA", bajo el título del AppBar.
  static String progressLabel(List<StepData> steps, int currentStep) {
    if (steps.isEmpty) return '';
    final safe = currentStep.clamp(0, steps.length - 1);
    return 'Paso ${safe + 1} de ${steps.length} · ${steps[safe].title}';
  }

  StepProgress _progressAt(int index) =>
      steps[index].progress ??
      (index < currentStep ? StepProgress.complete : StepProgress.pending);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = isDark ? Colors.white60 : AppDesign.muted;
    final done = [
      for (var i = 0; i < steps.length; i++) _progressAt(i),
    ].where((p) => p == StepProgress.complete).length;

    return Drawer(
      backgroundColor: theme.scaffoldBackgroundColor,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 19,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                      height: 1.25,
                      color: isDark ? Colors.white : AppDesign.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$done de ${steps.length} pasos completos',
                    style: GoogleFonts.inter(fontSize: 13, color: muted),
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: steps.isEmpty ? 0 : done / steps.length,
                      minHeight: 4,
                      color: AppColors.actionPositive,
                      backgroundColor: isDark
                          ? Colors.white12
                          : Colors.black.withOpacity(0.07),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                itemCount: steps.length,
                itemBuilder: (context, index) => _StepTile(
                  index: index,
                  total: steps.length,
                  step: steps[index],
                  progress: _progressAt(index),
                  current: index == currentStep,
                  onTap: () {
                    Scaffold.maybeOf(context)?.closeDrawer();
                    if (index != currentStep) onStepSelected?.call(index);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  final int index;
  final int total;
  final StepData step;
  final StepProgress progress;
  final bool current;
  final VoidCallback onTap;

  const _StepTile({
    required this.index,
    required this.total,
    required this.step,
    required this.progress,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? Colors.white : AppDesign.ink;
    final muted = isDark ? Colors.white60 : AppDesign.muted;
    // El paso actual nunca se muestra bloqueado: el técnico ya está en él.
    final locked = !step.isAccessible && !current;
    final review = progress == StepProgress.review;

    final detail = locked
        ? 'Complete los pasos anteriores'
        : review
            ? 'Falta completar'
            : step.subtitle;
    final status = locked
        ? 'bloqueado'
        : switch (progress) {
            StepProgress.complete => 'completo',
            StepProgress.review => 'falta completar',
            StepProgress.pending => 'pendiente',
          };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Semantics(
        container: true,
        button: true,
        enabled: !locked,
        selected: current,
        onTap: locked ? null : onTap,
        label: 'Paso ${index + 1} de $total: ${step.title}, $status'
            '${current ? ', paso actual' : ''}',
        excludeSemantics: true,
        child: Material(
          color: current
              ? AppColors.accentYellow.withOpacity(isDark ? 0.13 : 0.18)
              : Colors.transparent,
          borderRadius: AppDesign.smallRadius,
          child: InkWell(
            borderRadius: AppDesign.smallRadius,
            onTap: locked ? null : onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Row(
                children: [
                  _StepBadge(
                    number: index + 1,
                    progress: progress,
                    current: current,
                    locked: locked,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 14.5,
                            fontWeight:
                                current ? FontWeight.w700 : FontWeight.w600,
                            color: locked ? muted : ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          detail,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            color:
                                review && !locked ? AppColors.warning : muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Círculo del paso: check si está completo, "!" si falta completar, candado
/// si todavía no se puede abrir y, si no, su número (con aro dorado en el
/// paso actual).
class _StepBadge extends StatelessWidget {
  final int number;
  final StepProgress progress;
  final bool current;
  final bool locked;

  const _StepBadge({
    required this.number,
    required this.progress,
    required this.current,
    required this.locked,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? Colors.white54 : AppDesign.muted;
    final ring = isDark ? Colors.white24 : Colors.black.withOpacity(0.18);

    Widget circle({
      Color? fill,
      Color? border,
      double borderWidth = 1.4,
      required Widget child,
    }) =>
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: fill,
            shape: BoxShape.circle,
            border: border == null
                ? null
                : Border.all(color: border, width: borderWidth),
          ),
          child: child,
        );

    if (locked) {
      return circle(
        border: ring,
        child: Icon(Icons.lock_outline_rounded, size: 14, color: muted),
      );
    }
    return switch (progress) {
      StepProgress.complete => circle(
          fill: AppColors.actionPositive,
          border: current ? AppColors.accentYellow : null,
          borderWidth: 2,
          child: const Icon(Icons.check_rounded,
              size: 17, color: AppColors.actionPositiveInk),
        ),
      StepProgress.review => circle(
          fill: AppColors.warning.withOpacity(0.14),
          border: AppColors.warning,
          child: const Icon(Icons.priority_high_rounded,
              size: 16, color: AppColors.warning),
        ),
      StepProgress.pending => circle(
          border: current ? AppColors.accentYellow : ring,
          borderWidth: current ? 2 : 1.4,
          child: Text(
            '$number',
            style: GoogleFonts.inter(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: current ? (isDark ? Colors.white : AppDesign.ink) : muted,
            ),
          ),
        ),
    };
  }
}

/// ≡ del AppBar de un servicio: abre [ServiceStepsDrawer].
class ServiceStepsButton extends StatelessWidget {
  static const tooltip = 'Pasos del servicio';

  const ServiceStepsButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      icon: const Icon(Icons.menu_rounded),
      onPressed: () => Scaffold.of(context).openDrawer(),
    );
  }
}
