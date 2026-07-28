import 'package:flutter/material.dart';
import 'package:service_met/screens/soporte/models/campo_estado.dart';
import 'package:service_met/screens/soporte/widgets/shared/all_good_checkbox.dart';
import 'package:service_met/screens/soporte/widgets/shared/campo_inspeccion_widget.dart';

class EntornoSection {
  final String titulo;
  final String subtitulo;
  final IconData icono;
  final Color color;
  final List<String> campos;

  const EntornoSection({
    required this.titulo,
    required this.subtitulo,
    required this.icono,
    required this.color,
    required this.campos,
  });
}

class PasoEntornoWidget extends StatefulWidget {
  final List<EntornoSection> secciones;
  final Map<String, CampoEstado> camposEstado;
  final VoidCallback onChanged;
  final void Function(String label, dynamic foto) onAddPhoto;
  final void Function(String label, int index) onRemovePhoto;

  const PasoEntornoWidget({
    super.key,
    required this.secciones,
    required this.camposEstado,
    required this.onChanged,
    required this.onAddPhoto,
    required this.onRemovePhoto,
  });

  @override
  State<PasoEntornoWidget> createState() => _PasoEntornoWidgetState();
}

class _PasoEntornoWidgetState extends State<PasoEntornoWidget> {
  final Map<int, bool> _sectionAllGood = {};
  final Map<int, Map<String, Map<String, String>>> _backupValues = {};

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < widget.secciones.length; i++) {
      _sectionAllGood[i] = false;
      _backupValues[i] = {};
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < widget.secciones.length; i++) ...[
            if (i > 0) const SizedBox(height: 32),
            _buildSectionHeader(context, widget.secciones[i]),
            AllGoodCheckbox(
              value: _sectionAllGood[i] ?? false,
              onChanged: (value) => _toggleSectionAllGood(i, value),
            ),
            const SizedBox(height: 16),
            ...widget.secciones[i].campos.map((campo) {
              return CampoInspeccionWidget(
                label: campo,
                campo: widget.camposEstado[campo]!,
                onAddPhoto: widget.onAddPhoto,
                onRemovePhoto: widget.onRemovePhoto,
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, EntornoSection section) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode
            ? section.color.withOpacity(0.1)
            : section.color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: section.color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(section.icono, color: section.color, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  section.titulo,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  section.subtitulo,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDarkMode ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _toggleSectionAllGood(int sectionIndex, bool isGood) {
    setState(() {
      _sectionAllGood[sectionIndex] = isGood;
      final section = widget.secciones[sectionIndex];

      if (isGood) {
        for (final campo in section.campos) {
          final campoEstado = widget.camposEstado[campo];
          if (campoEstado != null) {
            _backupValues[sectionIndex]![campo] = {
              'initialValue': campoEstado.initialValue,
              'comentario': campoEstado.comentario,
            };
            campoEstado.initialValue = '1 Bueno';
            campoEstado.comentario = 'En buen estado';
          }
        }
      } else {
        for (final campo in section.campos) {
          final campoEstado = widget.camposEstado[campo];
          final backup = _backupValues[sectionIndex]![campo];
          if (campoEstado != null && backup != null) {
            campoEstado.initialValue =
                backup['initialValue'] ?? '4 No aplica';
            campoEstado.comentario = backup['comentario'] ?? 'Sin comentario';
          }
        }
        _backupValues[sectionIndex]!.clear();
      }

      widget.onChanged();
    });
  }
}
