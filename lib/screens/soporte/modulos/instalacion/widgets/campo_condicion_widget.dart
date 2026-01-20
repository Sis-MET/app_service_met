// ignore_for_file: deprecated_member_use

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../controllers/instalacion_controller.dart';
import '../models/instalacion_model.dart';

class CampoCondicionWidget extends StatefulWidget {
  final String label;
  final CampoEstado campo;
  final List<String> opciones;
  final InstalacionController controller;
  final VoidCallback onChanged;

  const CampoCondicionWidget({
    super.key,
    required this.label,
    required this.campo,
    required this.opciones,
    required this.controller,
    required this.onChanged,
  });

  @override
  State<CampoCondicionWidget> createState() => _CampoCondicionWidgetState();
}

class _CampoCondicionWidgetState extends State<CampoCondicionWidget> {
  final ImagePicker _imagePicker = ImagePicker();
  bool _isExpanded = false;

  // Mapeo de estados a colores e iconos
  static const Map<String, IconData> _iconMap = {
    'Bueno': Icons.check_circle,
    'Aceptable': Icons.warning,
    'Malo': Icons.error,
    'No aplica': Icons.block,
  };

  static const Map<String, Color> _colorMap = {
    'Bueno': Colors.green,
    'Aceptable': Colors.orange,
    'Malo': Colors.red,
    'No aplica': Colors.grey,
  };

  Color _getColorForValue(String value) {
    // Buscar coincidencia parcial en el mapa
    for (var key in _colorMap.keys) {
      if (value.contains(key)) {
        return _colorMap[key]!;
      }
    }
    return Colors.grey;
  }

  IconData _getIconForValue(String value) {
    // Buscar coincidencia parcial en el mapa
    for (var key in _iconMap.keys) {
      if (value.contains(key)) {
        return _iconMap[key]!;
      }
    }
    return Icons.help_outline;
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final estado = widget.campo.initialValue.isEmpty
        ? 'No aplica'
        : widget.campo.initialValue;
    final color = _getColorForValue(estado);
    final icon = _getIconForValue(estado);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: color.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          // Header del campo
          InkWell(
            onTap: () {
              setState(() => _isExpanded = !_isExpanded);
            },
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  Icon(icon, color: color, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.label,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // Indicador de fotos
                  if (widget.campo.fotos.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.camera_alt,
                              color: Colors.white, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            '${widget.campo.fotos.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(width: 8),
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: isDarkMode ? Colors.white70 : Colors.black54,
                  ),
                ],
              ),
            ),
          ),

          // Contenido expandible
          if (_isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Dropdown de Estado
                  _buildDropdownEstado(),
                  const SizedBox(height: 16),

                  // Campo de comentario
                  _buildComentarioField(),
                  const SizedBox(height: 16),

                  // Sección de fotos
                  _buildFotosSection(),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDropdownEstado() {
    return DropdownButtonFormField<String>(
      value:
          widget.campo.initialValue.isEmpty ? null : widget.campo.initialValue,
      decoration: InputDecoration(
        labelText: 'Estado',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        prefixIcon: Icon(
          _getIconForValue(widget.campo.initialValue),
          color: _getColorForValue(widget.campo.initialValue),
        ),
      ),
      items: widget.opciones.map((String value) {
        final color = _getColorForValue(value);
        final icon = _getIconForValue(value);

        return DropdownMenuItem<String>(
          value: value,
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                value,
                style: TextStyle(color: color, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        );
      }).toList(),
      onChanged: (newValue) {
        if (newValue != null) {
          setState(() {
            widget.campo.initialValue = newValue;
            widget.onChanged();
          });
        }
      },
    );
  }

  Widget _buildComentarioField() {
    return TextFormField(
      initialValue: widget.campo.comentario,
      decoration: InputDecoration(
        labelText: 'Comentario',
        prefixIcon: const Icon(Icons.comment_outlined),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      maxLines: 2,
      onChanged: (value) {
        widget.campo.comentario = value;
        widget.onChanged();
      },
    );
  }

  Widget _buildFotosSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Fotografías (${widget.campo.fotos.length}/5)',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            ElevatedButton.icon(
              onPressed:
                  widget.campo.fotos.length < 5 ? () => _tomarFoto() : null,
              icon: const Icon(Icons.camera_alt, size: 18),
              label: const Text('AGREGAR'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                textStyle: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        if (widget.campo.fotos.isNotEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: widget.campo.fotos.length,
              itemBuilder: (context, index) {
                return _buildFotoThumbnail(widget.campo.fotos[index], index);
              },
            ),
          ),
        ] else ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.grey.withOpacity(0.3),
                style: BorderStyle.solid,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.grey[600], size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No hay fotografías agregadas',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFotoThumbnail(File foto, int index) {
    return Container(
      width: 100,
      margin: const EdgeInsets.only(right: 8),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              foto,
              width: 100,
              height: 100,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  widget.controller.eliminarFoto(widget.label, index);
                  widget.onChanged();
                });
              },
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _tomarFoto() async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85, // Comprimir automáticamente
      );

      if (photo != null) {
        setState(() {
          widget.controller.agregarFoto(widget.label, File(photo.path));
          widget.onChanged();
        });
      }
    } catch (e) {
      debugPrint('Error al tomar foto: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al tomar foto: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
