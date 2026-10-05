import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:service_met/screens/soporte_new/models/campo_estado.dart';
import 'package:service_met/screens/soporte_new/widgets/shared/bulk_estado_toggle.dart';
import 'package:service_met/screens/soporte_new/widgets/shared/campo_inspeccion_widget.dart';
import '../../../../../../theme/app_icons.dart';

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
mixin _AllGoodMixin<T extends StatefulWidget> on State<T> {
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
//  PASO TERMINAL
// ═══════════════════════════════════════════════════════════════════════
class PasoTerminal extends StatefulWidget {
  final List<CampoEstado> campos;
  final void Function(int index, String value, String solutionValue) onChanged;
  final String seca;
  final String codMetrica;

  const PasoTerminal({
    super.key,
    required this.campos,
    required this.onChanged,
    required this.seca,
    required this.codMetrica,
  });

  @override
  State<PasoTerminal> createState() => _PasoTerminalState();
}

class _PasoTerminalState extends State<PasoTerminal> with _AllGoodMixin {
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
//  PASO BALANZA
// ═══════════════════════════════════════════════════════════════════════
class PasoBalanza extends StatefulWidget {
  final List<CampoEstado> campos;
  final void Function(int index, String value, String solutionValue) onChanged;
  final String seca;
  final String codMetrica;

  const PasoBalanza({
    super.key,
    required this.campos,
    required this.onChanged,
    required this.seca,
    required this.codMetrica,
  });

  @override
  State<PasoBalanza> createState() => _PasoBalanzaState();
}

class _PasoBalanzaState extends State<PasoBalanza> with _AllGoodMixin {
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
//  PASO CAJA SUMADORA
// ═══════════════════════════════════════════════════════════════════════
class PasoCajaSumadora extends StatefulWidget {
  final List<CampoEstado> campos;
  final void Function(int index, String value, String solutionValue) onChanged;
  final String seca;
  final String codMetrica;

  const PasoCajaSumadora({
    super.key,
    required this.campos,
    required this.onChanged,
    required this.seca,
    required this.codMetrica,
  });

  @override
  State<PasoCajaSumadora> createState() => _PasoCajaSumadoraState();
}

class _PasoCajaSumadoraState extends State<PasoCajaSumadora>
    with _AllGoodMixin {
  @override
  Widget build(BuildContext context) {
    // Indices 0-3: Plataforma, 4-9: Caja Sumadora (incluye pintado + limpieza profunda)
    final camposPlataforma = widget.campos.sublist(0, 4);
    final camposCaja = widget.campos.sublist(4);

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
          title: 'BALANZA | PLATAFORMA',
          subtitle: 'Inspeccione los componentes de la plataforma',
          icon: AppIcons.cuadro,
          color: Colors.orange,
        ),
        const SizedBox(height: 12),
        ...List.generate(camposPlataforma.length, (i) {
          return CampoInspeccionWidget(
            campoEstado: camposPlataforma[i],
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
          title: 'CAJA SUMADORA',
          subtitle: 'Inspeccione el estado de la caja sumadora',
          icon: AppIcons.electrico,
          color: Colors.amber[700]!,
        ),
        const SizedBox(height: 12),
        ...List.generate(camposCaja.length, (i) {
          final realIndex = i + 4;
          return CampoInspeccionWidget(
            campoEstado: camposCaja[i],
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

// ═══════════════════════════════════════════════════════════════════════
//  PASO ENTORNO
// ═══════════════════════════════════════════════════════════════════════
class PasoEntorno extends StatefulWidget {
  final List<CampoEstado> campos;
  final void Function(int index, String value, String solutionValue) onChanged;
  final String seca;
  final String codMetrica;

  const PasoEntorno({
    super.key,
    required this.campos,
    required this.onChanged,
    required this.seca,
    required this.codMetrica,
  });

  @override
  State<PasoEntorno> createState() => _PasoEntornoState();
}

class _PasoEntornoState extends State<PasoEntorno> with _AllGoodMixin {
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
