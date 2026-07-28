import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:service_met/screens/soporte_new/models/campo_estado.dart';
import 'package:service_met/screens/soporte_new/utils/estado_maps.dart';

class PasoCondicionesInstalacionWidget extends StatelessWidget {
  final List<CampoEstado> campos;
  final void Function(int index, String value, String solutionValue) onChanged;

  const PasoCondicionesInstalacionWidget({
    super.key,
    required this.campos,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 16),
          child: Text(
            'Condiciones de Instalación',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        ...List.generate(campos.length, (i) {
          return _CampoCondicionWidget(
            campoEstado: campos[i],
            onValueChanged: (value, solutionValue) => onChanged(i, value, solutionValue),
          );
        }),
      ],
    );
  }
}

class _CampoCondicionWidget extends StatefulWidget {
  final CampoEstado campoEstado;
  final void Function(String value, String solutionValue) onValueChanged;

  const _CampoCondicionWidget({
    required this.campoEstado,
    required this.onValueChanged,
  });

  @override
  State<_CampoCondicionWidget> createState() => _CampoCondicionWidgetState();
}

class _CampoCondicionWidgetState extends State<_CampoCondicionWidget> {
  final ImagePicker _picker = ImagePicker();
  late CampoEstado _campoEstado;

  @override
  void initState() {
    super.initState();
    _campoEstado = widget.campoEstado;
  }

  @override
  void didUpdateWidget(_CampoCondicionWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.campoEstado != widget.campoEstado) {
      _campoEstado = widget.campoEstado;
    }
  }

  void _onEstadoChanged(String? value) {
    if (value == null) return;
    setState(() => _campoEstado.value = value);
    widget.onValueChanged(_campoEstado.value, _campoEstado.solutionValue);
  }

  void _onSolucionChanged(String? value) {
    if (value == null) return;
    setState(() => _campoEstado.solutionValue = value);
    widget.onValueChanged(_campoEstado.value, _campoEstado.solutionValue);
  }

  Future<void> _addPhoto() async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.gallery);
    if (photo != null) {
      setState(() => _campoEstado.fotos.add(photo.path));
      widget.onValueChanged(_campoEstado.value, _campoEstado.solutionValue);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _campoEstado.nombre,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _campoEstado.value.isNotEmpty ? _campoEstado.value : null,
              decoration: const InputDecoration(
                labelText: 'Estado',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: estadoColorMap.keys.map((key) {
                return DropdownMenuItem(
                  value: key,
                  child: Row(
                    children: [
                      Icon(estadoIconMap[key], color: estadoColorMap[key], size: 18),
                      const SizedBox(width: 8),
                      Text(key),
                    ],
                  ),
                );
              }).toList(),
              onChanged: _onEstadoChanged,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _campoEstado.solutionValue,
              decoration: const InputDecoration(
                labelText: 'Solución',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: const [
                DropdownMenuItem(value: 'No aplica', child: Text('No aplica')),
                DropdownMenuItem(value: 'Se ajusta', child: Text('Se ajusta')),
                DropdownMenuItem(value: 'Se repara', child: Text('Se repara')),
                DropdownMenuItem(value: 'Se cambia', child: Text('Se cambia')),
                DropdownMenuItem(value: 'Limpieza', child: Text('Limpieza')),
                DropdownMenuItem(value: 'Lubricación', child: Text('Lubricación')),
              ],
              onChanged: _onSolucionChanged,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Fotos: ', style: TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                if (_campoEstado.fotos.isNotEmpty)
                  Text('${_campoEstado.fotos.length} adjunta(s)',
                      style: const TextStyle(color: Colors.grey)),
                IconButton(
                  icon: const Icon(Icons.add_a_photo, size: 20),
                  onPressed: _addPhoto,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
