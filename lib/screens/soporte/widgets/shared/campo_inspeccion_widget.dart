import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:service_met/screens/soporte/models/campo_estado.dart';
import 'package:service_met/screens/soporte/utils/estado_maps.dart';

class CampoInspeccionWidget extends StatefulWidget {
  final String label;
  final CampoEstado campo;
  final void Function(String label, File foto) onAddPhoto;
  final void Function(String label, int index) onRemovePhoto;

  const CampoInspeccionWidget({
    super.key,
    required this.label,
    required this.campo,
    required this.onAddPhoto,
    required this.onRemovePhoto,
  });

  @override
  State<CampoInspeccionWidget> createState() => _CampoInspeccionWidgetState();
}

class _CampoInspeccionWidgetState extends State<CampoInspeccionWidget> {
  final ImagePicker _imagePicker = ImagePicker();
  bool _isExpanded = false;

  static const Map<String, IconData> _solucionIconMap = {
    'No aplica': Icons.block_outlined,
    'Se ajusta': Icons.build_circle_outlined,
    'Se repara': Icons.handyman_outlined,
    'Se cambia': Icons.cached_outlined,
    'Limpieza': Icons.cleaning_services_outlined,
    'Lubricación': Icons.water_drop_outlined,
  };

  static const Map<String, Color> _solucionColorMap = {
    'No aplica': Colors.grey,
    'Se ajusta': Colors.orange,
    'Se repara': Colors.red,
    'Se cambia': Colors.blue,
    'Limpieza': Colors.lightBlue,
    'Lubricación': Colors.teal,
  };

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final estado = widget.campo.initialValue;
    final color = estadoColorMap[estado] ?? Colors.grey;
    final icon = estadoIconMap[estado] ?? Icons.help_outline;

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
          if (_isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDropdownEstado(),
                  const SizedBox(height: 16),
                  _buildDropdownSolucion(),
                  const SizedBox(height: 16),
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
    final opciones = ['1 Bueno', '2 Regular', '3 Malo', '4 No aplica'];

    return DropdownButtonFormField<String>(
      value:
          widget.campo.initialValue.isEmpty ? null : widget.campo.initialValue,
      decoration: InputDecoration(
        labelText: 'Estado',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        prefixIcon: Icon(
          estadoIconMap[widget.campo.initialValue] ?? Icons.help_outline,
          color: estadoColorMap[widget.campo.initialValue] ?? Colors.grey,
        ),
      ),
      items: opciones.map((String value) {
        final color = estadoColorMap[value]!;
        final icon = estadoIconMap[value]!;

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
            if (newValue.startsWith('1') || newValue.startsWith('4')) {
              widget.campo.solutionValue = 'No aplica';
            }
          });
        }
      },
    );
  }

  Widget _buildDropdownSolucion() {
    final opciones = [
      'No aplica',
      'Se ajusta',
      'Se repara',
      'Se cambia',
      'Limpieza',
      'Lubricación'
    ];

    return DropdownButtonFormField<String>(
      value: widget.campo.solutionValue.isEmpty
          ? 'No aplica'
          : widget.campo.solutionValue,
      decoration: InputDecoration(
        labelText: 'Solución',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        prefixIcon: Icon(
          _solucionIconMap[widget.campo.solutionValue] ?? Icons.help_outline,
          color: _solucionColorMap[widget.campo.solutionValue] ?? Colors.grey,
        ),
      ),
      items: opciones.map((String value) {
        final color = _solucionColorMap[value] ?? Colors.black;
        final icon = _solucionIconMap[value] ?? Icons.circle;

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
            widget.campo.solutionValue = newValue;
          });
        }
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
                  widget.campo.eliminarFoto(index);
                  widget.onRemovePhoto(widget.label, index);
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
        imageQuality: 85,
      );

      if (photo != null) {
        final file = File(photo.path);
        setState(() {
          widget.campo.agregarFoto(file);
          widget.onAddPhoto(widget.label, file);
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
