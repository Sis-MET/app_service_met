import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/campo_estado.dart';
import '../../../../theme/app_icons.dart';

/// Modos del bloque de acciones masivas sobre los campos de inspección.
///
/// Son excluyentes entre sí: activar uno desactiva el otro. Editar un campo a
/// mano vuelve a [none].
enum BulkEstadoMode { none, buenEstado, noAplica }

/// Aplica un estado a todos los [campos] de una vez.
///
/// * `buenEstado`  -> value: "Bueno",     solución/comentario: "No aplica".
/// * `noAplica`    -> value: "No aplica", solución/comentario: "No aplica".
void applyBulkEstado(
  List<CampoEstado> campos, {
  required String estado,
  String solution = 'No aplica',
  String solutionLabel = '',
}) {
  for (final campo in campos) {
    campo.value = estado;
    campo.solutionValue = solution;
    campo.solutionLabel = solutionLabel;
  }
}

/// Tarjeta con un switch para una acción masiva ("Todo en buen estado" /
/// "Marcar todo como No aplica"). Extraída de los `_AllGoodCard` que estaban
/// duplicados en cada módulo.
class BulkEstadoToggleCard extends StatelessWidget {
  final String title;
  final String subtitleActive;
  final String subtitleInactive;
  final IconData activeIcon;
  final IconData inactiveIcon;
  final Color activeColor;
  final bool value;
  final ValueChanged<bool> onChanged;

  const BulkEstadoToggleCard({
    super.key,
    required this.title,
    required this.subtitleActive,
    required this.subtitleInactive,
    required this.value,
    required this.onChanged,
    this.activeIcon = AppIcons.completo,
    this.inactiveIcon = AppIcons.lista,
    this.activeColor = const Color(0xFF46824B),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: value
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
              color: value
                  ? activeColor.withOpacity(isDark ? 0.2 : 0.12)
                  : (isDark ? Colors.white12 : const Color(0xFFF0F2F5)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              value ? activeIcon : inactiveIcon,
              size: 20,
              color: value
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
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value ? subtitleActive : subtitleInactive,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
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

/// Par de tarjetas "buen estado" / "no aplica" listo para usar en un paso de
/// inspección. Mantiene la exclusividad y delega el efecto en [onModeChanged].
class BulkEstadoToggles extends StatelessWidget {
  final BulkEstadoMode mode;
  final ValueChanged<BulkEstadoMode> onModeChanged;
  final String buenEstadoTitle;
  final String noAplicaTitle;

  const BulkEstadoToggles({
    super.key,
    required this.mode,
    required this.onModeChanged,
    this.buenEstadoTitle = 'Todo en buen estado',
    this.noAplicaTitle = 'Marcar todo como No aplica',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        BulkEstadoToggleCard(
          title: buenEstadoTitle,
          subtitleActive: 'Todos los campos marcados como "Bueno"',
          subtitleInactive:
              'Active para aplicar "Buen estado" a todos los campos',
          value: mode == BulkEstadoMode.buenEstado,
          onChanged: (v) => onModeChanged(
            v ? BulkEstadoMode.buenEstado : BulkEstadoMode.none,
          ),
        ),
        const SizedBox(height: 10),
        BulkEstadoToggleCard(
          title: noAplicaTitle,
          subtitleActive: 'Todos los campos marcados como "No aplica"',
          subtitleInactive: 'Active cuando la inspección no corresponde',
          activeIcon: AppIcons.bloquear,
          inactiveIcon: AppIcons.bloquear,
          activeColor: const Color(0xFF6B7280),
          value: mode == BulkEstadoMode.noAplica,
          onChanged: (v) => onModeChanged(
            v ? BulkEstadoMode.noAplica : BulkEstadoMode.none,
          ),
        ),
      ],
    );
  }
}
