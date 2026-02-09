// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import '../../controllers/mnt_prv_avanzado_stac_controller.dart';
import '../../models/mnt_prv_avanzado_stac_model.dart';
import '../campo_inspeccion_widget.dart';

class PasoGenerico extends StatefulWidget {
  final MntPrvAvanzadoStacModel model;
  final MntPrvAvanzadoStacController controller;
  final VoidCallback onChanged;
  final List<String> campos;
  final String titulo;
  final String subtitulo;
  final IconData icono;
  final Color color;

  const PasoGenerico({
    super.key,
    required this.model,
    required this.controller,
    required this.onChanged,
    required this.campos,
    required this.titulo,
    required this.subtitulo,
    required this.icono,
    required this.color,
  });

  @override
  State<PasoGenerico> createState() => _PasoGenericoState();
}

class _PasoGenericoState extends State<PasoGenerico> {
  bool _isAllGood = false;

  // Mapa para respaldar los valores anteriores
  final Map<String, Map<String, String>> _backupValues = {};

  @override
  void didUpdateWidget(PasoGenerico oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Resetear el checkbox cuando cambian los campos (cambio de paso)
    if (oldWidget.campos != widget.campos) {
      _isAllGood = false;
      _backupValues.clear();
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
          _buildAllGoodCheckbox(widget.campos),
          const SizedBox(height: 24),

          // Lista de campos
          ...widget.campos.map((campo) {
            return CampoInspeccionWidget(
              label: campo,
              campo: widget.model.camposEstado[campo]!,
              controller: widget.controller,
              onChanged: widget.onChanged,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildAllGoodCheckbox(List<String> campos) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _isAllGood
            ? Colors.green.withOpacity(0.1)
            : Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _isAllGood
              ? Colors.green.withOpacity(0.3)
              : Colors.grey.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: CheckboxListTile(
        title: const Text(
          'Marcar todo como "Buen Estado"',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          _isAllGood
              ? 'Todos los campos están en "1 Bueno" con comentario "En buen estado"'
              : 'Active esta opción para aplicar "Buen Estado" a todos los campos',
          style: TextStyle(
            fontSize: 12,
            color: _isAllGood ? Colors.green[700] : Colors.grey[600],
          ),
        ),
        value: _isAllGood,
        onChanged: (bool? value) {
          _toggleAllGood(value ?? false, campos);
        },
        activeColor: Colors.green,
        controlAffinity: ListTileControlAffinity.leading,
      ),
    );
  }

  void _toggleAllGood(bool isGood, List<String> campos) {
    setState(() {
      _isAllGood = isGood;

      if (isGood) {
        // Respaldar y aplicar "1 Bueno"
        for (final fieldName in campos) {
          final campo = widget.model.camposEstado[fieldName];
          if (campo != null) {
            // Guardar valores actuales en el respaldo
            _backupValues[fieldName] = {
              'initialValue': campo.initialValue,
              'comentario': campo.comentario,
            };

            // Aplicar nuevo estado
            campo.initialValue = '1 Bueno';
            campo.comentario = 'En buen estado';
            campo.solutionValue = 'No aplica';
          }
        }
      } else {
        // Restaurar valores desde el respaldo
        for (final fieldName in campos) {
          final campo = widget.model.camposEstado[fieldName];
          final backup = _backupValues[fieldName];

          if (campo != null && backup != null) {
            campo.initialValue = backup['initialValue'] ?? '4 No aplica';
            campo.comentario = backup['comentario'] ?? 'Sin comentario';
          }
        }
        // Limpiar respaldo
        _backupValues.clear();
      }
      widget.onChanged();
    });
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
          Icon(
            widget.icono,
            color: widget.color,
            size: 32,
          ),
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
}
