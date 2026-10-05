import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_design.dart';
import '../data/requisitos_17025.dart';
import '../models/cumplimiento.dart';
import 'calidad_ui.dart';
import '../../../theme/app_icons.dart';

/// Resumen del cumplimiento NB/ISO/IEC 17025 para la pestaña Otros: anillo de
/// avance y una barra por cláusula. Tocar una cláusula abre el tablero
/// filtrado.
class CalidadResumenPanel extends StatelessWidget {
  const CalidadResumenPanel({
    super.key,
    required this.onAbrir,
    this.evaluacion,
  });

  /// Abre el tablero; con cláusula, filtrado por ella.
  final ValueChanged<Clausula?> onAbrir;
  final EvaluacionCumplimiento? evaluacion;

  @override
  Widget build(BuildContext context) {
    final eval = evaluacion ?? evaluacionCumplimiento;
    final resumen = eval.resumen;
    final cs = Theme.of(context).colorScheme;
    final brechas = resumen[EstadoCumplimiento.noCumple] +
        resumen[EstadoCumplimiento.parcial];

    return AppPanel(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          InkWell(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppDesign.radiusLarge),
            ),
            onTap: () => onAbrir(null),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 12, 14),
              child: Row(
                children: [
                  DonutCumplimiento(resumen: resumen, size: 76, grosor: 9),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Cumplimiento NB/ISO/IEC 17025',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${resumen[EstadoCumplimiento.cumple]} de '
                          '${resumen.total} requisitos cumplen · $brechas con '
                          'brechas',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 10,
                          runSpacing: 4,
                          children: [
                            for (final estado in EstadoCumplimiento.values)
                              if (resumen[estado] > 0)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: estado.color,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Flexible(
                                      child: Text(
                                        '${resumen[estado]} ${estado.etiqueta.toLowerCase()}',
                                        style: GoogleFonts.inter(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: cs.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(AppIcons.siguiente),
                ],
              ),
            ),
          ),
          Divider(height: 1, color: cs.outlineVariant),
          for (final clausula in Clausula.values)
            _ClausulaFila(
              clausula: clausula,
              resumen: eval.resumenDe(clausula),
              onTap: () => onAbrir(clausula),
            ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

class _ClausulaFila extends StatelessWidget {
  const _ClausulaFila({
    required this.clausula,
    required this.resumen,
    required this.onTap,
  });

  final Clausula clausula;
  final ResumenCumplimiento resumen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
        child: Row(
          children: [
            SizedBox(
              width: 42,
              child: Text(
                clausula.numero,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w800,
                  color: AppColors.shimmerGold,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    clausula.nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  BarraCumplimiento(resumen: resumen, alto: 6),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${resumen[EstadoCumplimiento.cumple]}/${resumen.total}',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
