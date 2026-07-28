import 'dart:io';
import 'package:flutter/material.dart';
import 'package:service_met/screens/soporte/models/campo_estado.dart';
import 'package:service_met/screens/soporte/widgets/shared/all_good_checkbox.dart';
import 'package:service_met/screens/soporte/widgets/shared/campo_inspeccion_widget.dart';

class PasoGenericoWidget extends StatefulWidget {
  final List<String> campos;
  final Map<String, CampoEstado> camposEstado;
  final VoidCallback onChanged;
  final void Function(String label, File foto) onAddPhoto;
  final void Function(String label, int index) onRemovePhoto;
  final String titulo;
  final String subtitulo;
  final IconData icono;
  final Color color;

  const PasoGenericoWidget({
    super.key,
    required this.campos,
    required this.camposEstado,
    required this.onChanged,
    required this.onAddPhoto,
    required this.onRemovePhoto,
    required this.titulo,
    required this.subtitulo,
    required this.icono,
    required this.color,
  });

  @override
  State<PasoGenericoWidget> createState() => _PasoGenericoWidgetState();
}

class _PasoGenericoWidgetState extends State<PasoGenericoWidget> {
  bool _isAllGood = false;

  @override
  void didUpdateWidget(PasoGenericoWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.campos != widget.campos) {
      _isAllGood = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          AllGoodCheckbox(
            value: _isAllGood,
            onChanged: (value) => _toggleAllGood(value),
          ),
          const SizedBox(height: 24),
          ...widget.campos.map((campo) {
            return CampoInspeccionWidget(
              label: campo,
              campo: widget.camposEstado[campo]!,
              onAddPhoto: widget.onAddPhoto,
              onRemovePhoto: widget.onRemovePhoto,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode
            ? widget.color.withOpacity(0.1)
            : widget.color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(widget.icono, color: widget.color, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.titulo,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.subtitulo,
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

  void _toggleAllGood(bool isGood) {
    setState(() {
      _isAllGood = isGood;
      if (isGood) {
        for (final fieldName in widget.campos) {
          final campo = widget.camposEstado[fieldName];
          if (campo != null) {
            campo.initialValue = '1 Bueno';
            campo.comentario = 'En buen estado';
            campo.solutionValue = 'No aplica';
          }
        }
        widget.onChanged();
      }
    });
  }
}
