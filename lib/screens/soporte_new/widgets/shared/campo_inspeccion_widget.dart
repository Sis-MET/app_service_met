import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:service_met/screens/soporte_new/models/campo_estado.dart';
import 'package:service_met/screens/soporte_new/utils/estado_maps.dart';
import 'package:service_met/screens/soporte_new/utils/soporte_constants.dart';
import 'package:service_met/utils/foto_helper.dart';
import 'package:service_met/utils/foto_storage_dialog.dart';
import 'package:service_met/widgets/service_ui/input_decoration.dart';

const Map<String, IconData> _solucionIconMap = {
  'No aplica': Icons.block_outlined,
  'Se ajusta': Icons.build_circle_outlined,
  'Se repara': Icons.handyman_outlined,
  'Se cambia': Icons.cached_outlined,
  'Limpieza': Icons.cleaning_services_outlined,
  'Lubricación': Icons.water_drop_outlined,
};

const Map<String, Color> _solucionColorMap = {
  'No aplica': Colors.grey,
  'Se ajusta': Colors.orange,
  'Se repara': Colors.red,
  'Se cambia': Colors.blue,
  'Limpieza': Colors.lightBlue,
  'Lubricación': Colors.teal,
};

class CampoInspeccionWidget extends StatefulWidget {
  final CampoEstado campoEstado;
  final void Function(String value, String solutionValue) onChanged;
  final String seca;
  final String codMetrica;
  final List<String>? customOptions;
  final bool solutionAsComment;

  const CampoInspeccionWidget({
    super.key,
    required this.campoEstado,
    required this.onChanged,
    required this.seca,
    required this.codMetrica,
    this.customOptions,
    this.solutionAsComment = false,
  });

  @override
  State<CampoInspeccionWidget> createState() => _CampoInspeccionWidgetState();
}

class _CampoInspeccionWidgetState extends State<CampoInspeccionWidget> {
  final ImagePicker _picker = ImagePicker();
  late CampoEstado _campoEstado;

  @override
  void initState() {
    super.initState();
    _campoEstado = widget.campoEstado;
    _normalizeEstado();
  }

  @override
  void didUpdateWidget(CampoInspeccionWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.campoEstado != widget.campoEstado) {
      _campoEstado = widget.campoEstado;
    }
    _normalizeEstado();
    if (_campoEstado.fotos.length != oldWidget.campoEstado.fotos.length) {
      setState(() {});
    }
  }

  void _normalizeEstado() {
    if (widget.customOptions != null) {
      if (!widget.customOptions!.contains(_campoEstado.value)) {
        _campoEstado.value = '';
      }
      return;
    }
    if (estadoColorMap.containsKey(_campoEstado.value)) return;
    _campoEstado.value = _campoEstado.value == '1 Bueno' ? 'Bueno' : '';
  }

  void _onValueChanged(String? value) {
    if (value == null) return;
    setState(() {
      _campoEstado.value = value;
    });
    widget.onChanged(_campoEstado.value, _campoEstado.solutionValue);
  }

  void _onSolutionChanged(String? value) {
    if (value == null) return;
    setState(() {
      _campoEstado.solutionValue = value;
    });
    widget.onChanged(_campoEstado.value, _campoEstado.solutionValue);
  }

  Future<void> _addPhoto() async {
    if (!await FotoHelper.isConfigured()) {
      if (!mounted) return;
      final configured = await FotoStorageDialog.show(
        context,
        subDirName: 'soporte_fotos',
      );
      if (!configured || !mounted) return;
    }

    final seca = widget.seca;
    final codMetrica = widget.codMetrica;
    if (seca.isEmpty || codMetrica.isEmpty) return;

    final XFile? photo = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (photo == null || !mounted) return;

    try {
      final savedPath = await FotoHelper.saveFoto(
        seca,
        codMetrica,
        photo.path,
        subDirName: 'soporte_fotos',
      );
      if (!mounted) return;
      setState(() {
        _campoEstado.fotos.add(savedPath);
      });
      widget.onChanged(_campoEstado.value, _campoEstado.solutionValue);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar foto: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final customOptions = widget.customOptions;
    final estadoOptions = customOptions ?? estadoColorMap.keys.toList();
    final valueColor = customOptions == null
        ? estadoColorMap[_campoEstado.value] ?? Colors.grey
        : Theme.of(context).colorScheme.primary;

    return ExpansionTile(
      title: Text(_campoEstado.nombre,
          style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(
        _campoEstado.value.isNotEmpty
            ? _campoEstado.value
            : 'Seleccionar estado',
        style: TextStyle(
          color: valueColor,
        ),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                value:
                    _campoEstado.value.isNotEmpty ? _campoEstado.value : null,
                decoration: serviceInputDeco(
                    customOptions == null ? 'Estado' : 'Condición', isDark),
                dropdownColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                items: estadoOptions.map((key) {
                  return DropdownMenuItem(
                    value: key,
                    child: Row(
                      children: [
                        Icon(
                          customOptions == null
                              ? estadoIconMap[key]
                              : Icons.tune_rounded,
                          color: customOptions == null
                              ? estadoColorMap[key]
                              : Theme.of(context).colorScheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(key),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: _onValueChanged,
              ),
              const SizedBox(height: 12),
              if (widget.solutionAsComment)
                TextFormField(
                  initialValue: _campoEstado.solutionValue,
                  decoration: serviceInputDeco('Comentario', isDark).copyWith(
                    prefixIcon: const Icon(Icons.comment_outlined),
                  ),
                  maxLines: 2,
                  onChanged: (value) {
                    _campoEstado.solutionValue = value;
                    widget.onChanged(_campoEstado.value, value);
                  },
                )
              else
                DropdownButtonFormField<String>(
                  value: _campoEstado.solutionValue,
                  decoration: serviceInputDeco('Solución', isDark),
                  dropdownColor:
                      isDark ? const Color(0xFF2A2A2A) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  items: SoporteConstants.soluciones.map((sol) {
                    return DropdownMenuItem(
                      value: sol,
                      child: Row(
                        children: [
                          Icon(_solucionIconMap[sol],
                              color: _solucionColorMap[sol], size: 20),
                          const SizedBox(width: 8),
                          Text(sol),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: _onSolutionChanged,
                ),
              const SizedBox(height: 12),
              const Text('Fotos:',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ...List.generate(_campoEstado.fotos.length, (index) {
                    return GestureDetector(
                      onTap: () {
                        final path = _campoEstado.fotos[index];
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Eliminar foto'),
                            content: const Text('¿Desea eliminar esta foto?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(),
                                child: const Text('Cancelar'),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.of(ctx).pop();
                                  FotoHelper.deleteFoto(path);
                                  setState(() {
                                    _campoEstado.fotos.removeAt(index);
                                  });
                                  widget.onChanged(_campoEstado.value,
                                      _campoEstado.solutionValue);
                                },
                                child: const Text('Eliminar'),
                              ),
                            ],
                          ),
                        );
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(_campoEstado.fotos[index]),
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 80,
                            height: 80,
                            color: Colors.grey[300],
                            child: const Icon(Icons.broken_image),
                          ),
                        ),
                      ),
                    );
                  }),
                  GestureDetector(
                    onTap: _addPhoto,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color:
                            isDark ? const Color(0xFF2A2A2A) : Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: isDark ? Colors.white24 : Colors.grey[400]!),
                      ),
                      child: Icon(Icons.add_a_photo,
                          size: 32,
                          color: isDark ? Colors.white38 : Colors.grey),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ],
    );
  }
}
