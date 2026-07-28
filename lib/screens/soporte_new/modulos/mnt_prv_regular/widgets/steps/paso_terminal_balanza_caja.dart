import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:service_met/screens/soporte_new/models/campo_estado.dart';
import 'package:service_met/screens/soporte_new/widgets/shared/campo_inspeccion_widget.dart';

// ── All Good toggle card ──────────────────────────────────────────────
class _AllGoodCard extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _AllGoodCard({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const activeColor = Color(0xFF46824B);

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
              value ? Icons.check_circle_outline_rounded : Icons.checklist_rounded,
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
                  'Todo en buen estado',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value
                      ? 'Todos los campos marcados como "1 Bueno"'
                      : 'Active para aplicar "Buen Estado" a todos los campos',
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

// ── Mixin para AllGood toggle ─────────────────────────────────────────
mixin _AllGoodMixin<T extends StatefulWidget> on State<T> {
  bool _isAllGood = false;

  void toggleAllGood(bool value, List<CampoEstado> campos) {
    setState(() {
      _isAllGood = value;
      if (value) {
        for (final c in campos) {
          c.value = 'Bueno';
          c.solutionLabel = 'En buen estado';
          c.solutionValue = 'No aplica';
        }
      }
    });
  }

  void onFieldChangedExternally() {
    if (_isAllGood) {
      setState(() => _isAllGood = false);
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  PASO TERMINAL
// ═══════════════════════════════════════════════════════════════════════
class PasoTerminal extends StatefulWidget {
  final List<CampoEstado> campos;
  final void Function(int index, String value, String solutionValue) onChanged;
  final void Function(String label, String foto) onAddPhoto;
  final void Function(int index) onRemovePhoto;

  const PasoTerminal({
    super.key,
    required this.campos,
    required this.onChanged,
    required this.onAddPhoto,
    required this.onRemovePhoto,
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
        _AllGoodCard(
          value: _isAllGood,
          onChanged: (v) {
            toggleAllGood(v, widget.campos);
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
            onAddPhoto: widget.onAddPhoto,
            onRemovePhoto: widget.onRemovePhoto,
          );
        }),
      ],
    );
  }

  void _notifyAll() {
    for (int i = 0; i < widget.campos.length; i++) {
      widget.onChanged(i, widget.campos[i].value, widget.campos[i].solutionValue);
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  PASO BALANZA
// ═══════════════════════════════════════════════════════════════════════
class PasoBalanza extends StatefulWidget {
  final List<CampoEstado> campos;
  final void Function(int index, String value, String solutionValue) onChanged;
  final void Function(String label, String foto) onAddPhoto;
  final void Function(int index) onRemovePhoto;

  const PasoBalanza({
    super.key,
    required this.campos,
    required this.onChanged,
    required this.onAddPhoto,
    required this.onRemovePhoto,
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
        _AllGoodCard(
          value: _isAllGood,
          onChanged: (v) {
            toggleAllGood(v, widget.campos);
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
            onAddPhoto: widget.onAddPhoto,
            onRemovePhoto: widget.onRemovePhoto,
          );
        }),
      ],
    );
  }

  void _notifyAll() {
    for (int i = 0; i < widget.campos.length; i++) {
      widget.onChanged(i, widget.campos[i].value, widget.campos[i].solutionValue);
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  PASO CAJA SUMADORA
// ═══════════════════════════════════════════════════════════════════════
class PasoCajaSumadora extends StatefulWidget {
  final List<CampoEstado> campos;
  final void Function(int index, String value, String solutionValue) onChanged;
  final void Function(String label, String foto) onAddPhoto;
  final void Function(int index) onRemovePhoto;

  const PasoCajaSumadora({
    super.key,
    required this.campos,
    required this.onChanged,
    required this.onAddPhoto,
    required this.onRemovePhoto,
  });

  @override
  State<PasoCajaSumadora> createState() => _PasoCajaSumadoraState();
}

class _PasoCajaSumadoraState extends State<PasoCajaSumadora> with _AllGoodMixin {
  @override
  Widget build(BuildContext context) {
    // Indices 0-3: Plataforma, 4-7: Caja Sumadora
    final camposPlataforma = widget.campos.sublist(0, 4);
    final camposCaja = widget.campos.sublist(4, 8);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AllGoodCard(
          value: _isAllGood,
          onChanged: (v) {
            toggleAllGood(v, widget.campos);
            _notifyAll();
          },
        ),
        const SizedBox(height: 20),
        _SectionHeader(
          title: 'BALANZA | PLATAFORMA',
          subtitle: 'Inspeccione los componentes de la plataforma',
          icon: Icons.square_outlined,
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
            onAddPhoto: widget.onAddPhoto,
            onRemovePhoto: widget.onRemovePhoto,
          );
        }),
        const SizedBox(height: 28),
        _SectionHeader(
          title: 'CAJA SUMADORA',
          subtitle: 'Inspeccione el estado de la caja sumadora',
          icon: Icons.electrical_services_outlined,
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
            onAddPhoto: widget.onAddPhoto,
            onRemovePhoto: widget.onRemovePhoto,
          );
        }),
      ],
    );
  }

  void _notifyAll() {
    for (int i = 0; i < widget.campos.length; i++) {
      widget.onChanged(i, widget.campos[i].value, widget.campos[i].solutionValue);
    }
  }
}
