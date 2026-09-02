import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:service_met/screens/soporte_new/models/campo_estado.dart';
import 'package:service_met/screens/soporte_new/widgets/shared/bulk_estado_toggle.dart';
import 'package:service_met/screens/soporte_new/widgets/shared/campo_inspeccion_widget.dart';

// ── Section header ────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? color.withOpacity(0.1) : color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}

// ── Mixin para acciones masivas de estado ────────────────────────────
mixin AllGoodMixin<T extends StatefulWidget> on State<T> {
  BulkEstadoMode _bulkMode = BulkEstadoMode.none;

  void setBulkMode(BulkEstadoMode mode, List<CampoEstado> campos) {
    setState(() {
      _bulkMode = mode;
      switch (mode) {
        case BulkEstadoMode.buenEstado:
          applyBulkEstado(campos,
              estado: 'Bueno', solutionLabel: 'En buen estado');
        case BulkEstadoMode.noAplica:
          applyBulkEstado(campos,
              estado: 'No aplica', solutionLabel: 'No aplica');
        case BulkEstadoMode.none:
          break;
      }
    });
  }

  void onFieldChangedExternally() {
    if (_bulkMode != BulkEstadoMode.none) {
      setState(() => _bulkMode = BulkEstadoMode.none);
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  PASO INSPECCION SIMPLE — Una sola sección
// ═══════════════════════════════════════════════════════════════════════
class PasoInspeccionSimple extends StatefulWidget {
  final List<CampoEstado> campos;
  final void Function(int index, String value, String solutionValue) onChanged;
  final String seca;
  final String codMetrica;

  const PasoInspeccionSimple({
    super.key,
    required this.campos,
    required this.onChanged,
    required this.seca,
    required this.codMetrica,
  });

  @override
  State<PasoInspeccionSimple> createState() => _PasoInspeccionSimpleState();
}

class _PasoInspeccionSimpleState extends State<PasoInspeccionSimple>
    with AllGoodMixin {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BulkEstadoToggles(
          mode: _bulkMode,
          onModeChanged: (m) {
            setBulkMode(m, widget.campos);
            _notifyAll();
          },
        ),
        const SizedBox(height: 20),
        ...List.generate(widget.campos.length, (i) {
          return CampoInspeccionWidget(
            campoEstado: widget.campos[i],
            onChanged: (value, solutionValue) {
              onFieldChangedExternally();
              widget.onChanged(i, value, solutionValue);
            },
            seca: widget.seca,
            codMetrica: widget.codMetrica,
          );
        }),
      ],
    );
  }

  void _notifyAll() {
    for (int i = 0; i < widget.campos.length; i++) {
      widget.onChanged(
          i, widget.campos[i].value, widget.campos[i].solutionValue);
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  PASO INSPECCION DOBLE — Dos secciones con headers
// ═══════════════════════════════════════════════════════════════════════
class PasoInspeccionDoble extends StatefulWidget {
  final List<CampoEstado> campos;
  final void Function(int index, String value, String solutionValue) onChanged;
  final String seca;
  final String codMetrica;
  final SeccionData seccion1;
  final SeccionData seccion2;

  const PasoInspeccionDoble({
    super.key,
    required this.campos,
    required this.onChanged,
    required this.seca,
    required this.codMetrica,
    required this.seccion1,
    required this.seccion2,
  });

  @override
  State<PasoInspeccionDoble> createState() => _PasoInspeccionDobleState();
}

class SeccionData {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final int count;

  const SeccionData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.count,
  });
}

class _PasoInspeccionDobleState extends State<PasoInspeccionDoble>
    with AllGoodMixin {
  @override
  Widget build(BuildContext context) {
    final campos1 = widget.campos.sublist(0, widget.seccion1.count);
    final campos2 = widget.campos.sublist(widget.seccion1.count);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BulkEstadoToggles(
          mode: _bulkMode,
          onModeChanged: (m) {
            setBulkMode(m, widget.campos);
            _notifyAll();
          },
        ),
        const SizedBox(height: 20),
        _SectionHeader(
          title: widget.seccion1.title,
          subtitle: widget.seccion1.subtitle,
          icon: widget.seccion1.icon,
          color: widget.seccion1.color,
        ),
        const SizedBox(height: 12),
        ...List.generate(campos1.length, (i) {
          return CampoInspeccionWidget(
            campoEstado: campos1[i],
            onChanged: (value, solutionValue) {
              onFieldChangedExternally();
              widget.onChanged(i, value, solutionValue);
            },
            seca: widget.seca,
            codMetrica: widget.codMetrica,
          );
        }),
        const SizedBox(height: 28),
        _SectionHeader(
          title: widget.seccion2.title,
          subtitle: widget.seccion2.subtitle,
          icon: widget.seccion2.icon,
          color: widget.seccion2.color,
        ),
        const SizedBox(height: 12),
        ...List.generate(campos2.length, (i) {
          final realIndex = i + widget.seccion1.count;
          return CampoInspeccionWidget(
            campoEstado: campos2[i],
            onChanged: (value, solutionValue) {
              onFieldChangedExternally();
              widget.onChanged(realIndex, value, solutionValue);
            },
            seca: widget.seca,
            codMetrica: widget.codMetrica,
          );
        }),
      ],
    );
  }

  void _notifyAll() {
    for (int i = 0; i < widget.campos.length; i++) {
      widget.onChanged(
          i, widget.campos[i].value, widget.campos[i].solutionValue);
    }
  }
}
