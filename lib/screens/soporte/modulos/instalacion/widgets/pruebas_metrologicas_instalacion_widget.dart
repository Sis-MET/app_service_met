// ignore_for_file: library_private_types_in_public_api

import 'package:flutter/material.dart';
import '../models/instalacion_model.dart';
import 'excentricidad_instalacion_widget.dart';
import 'repetibilidad_instalacion_widget.dart';
import 'linealidad_instalacion_widget.dart';

class PruebasMetrologicasInstalacionWidget extends StatefulWidget {
  final PruebasMetrologicas pruebas;
  final Function onChanged;
  final Future<List<String>> Function(String, String) getIndicationSuggestions;
  final Future<double> Function() getD1FromDatabase;

  const PruebasMetrologicasInstalacionWidget({
    super.key,
    required this.pruebas,
    required this.onChanged,
    required this.getIndicationSuggestions,
    required this.getD1FromDatabase,
  });

  @override
  _PruebasMetrologicasInstalacionWidgetState createState() =>
      _PruebasMetrologicasInstalacionWidgetState();
}

class _PruebasMetrologicasInstalacionWidgetState
    extends State<PruebasMetrologicasInstalacionWidget> {
  // Mapeo de estados a colores e iconos
  static const Map<String, IconData> _iconMap = {
    '1 Bueno': Icons.check_circle,
    '2 Regular': Icons.warning,
    '3 Malo': Icons.error,
  };

  static const Map<String, Color> _colorMap = {
    '1 Bueno': Colors.green,
    '2 Regular': Colors.orange,
    '3 Malo': Colors.red,
  };

  InputDecoration _buildInputDecoration(String labelText,
      {Widget? suffixIcon}) {
    return InputDecoration(
      labelText: labelText,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20.0)),
      suffixIcon: suffixIcon,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'PRUEBAS METROLÓGICAS INICIALES',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: const Color(0xFFDECD00),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20.0),

        // Retorno a Cero
        DropdownButtonFormField<String>(
          initialValue: widget.pruebas.retornoCero.estado,
          decoration: InputDecoration(
            labelText: 'Retorno a Cero',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20.0),
            ),
            prefixIcon: Icon(
              _iconMap[widget.pruebas.retornoCero.estado] ?? Icons.help_outline,
              color:
                  _colorMap[widget.pruebas.retornoCero.estado] ?? Colors.grey,
            ),
          ),
          items: ['1 Bueno', '2 Regular', '3 Malo'].map((String value) {
            final color = _colorMap[value]!;
            final icon = _iconMap[value]!;
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
          onChanged: (value) {
            if (value != null) {
              widget.pruebas.retornoCero.estado = value;
              widget.onChanged();
            }
          },
        ),
        const SizedBox(height: 20.0),

        // Excentricidad
        SwitchListTile(
          title: const Text('PRUEBAS DE EXCENTRICIDAD INICIAL',
              style: TextStyle(fontWeight: FontWeight.bold)),
          value: widget.pruebas.excentricidad?.activo ?? false,
          onChanged: (bool value) {
            setState(() {
              if (value) {
                widget.pruebas.excentricidad = Excentricidad(activo: true);
              } else {
                widget.pruebas.excentricidad = null;
              }
              widget.onChanged();
            });
          },
        ),
        if (widget.pruebas.excentricidad != null)
          ExcentricidadInstalacionWidget(
            excentricidad: widget.pruebas.excentricidad!,
            getIndicationSuggestions: widget.getIndicationSuggestions,
            onChanged: widget.onChanged,
          ),

        const SizedBox(height: 20.0),

        // Repetibilidad
        SwitchListTile(
          title: const Text('PRUEBAS DE REPETIBILIDAD INICIAL',
              style: TextStyle(fontWeight: FontWeight.bold)),
          value: widget.pruebas.repetibilidad?.activo ?? false,
          onChanged: (bool value) {
            setState(() {
              if (value) {
                widget.pruebas.repetibilidad = Repetibilidad(activo: true);
              } else {
                widget.pruebas.repetibilidad = null;
              }
              widget.onChanged();
            });
          },
        ),
        if (widget.pruebas.repetibilidad != null)
          RepetibilidadInstalacionWidget(
            repetibilidad: widget.pruebas.repetibilidad!,
            getIndicationSuggestions: widget.getIndicationSuggestions,
            onChanged: widget.onChanged,
          ),

        const SizedBox(height: 20.0),

        // Linealidad
        SwitchListTile(
          title: const Text('PRUEBAS DE LINEALIDAD INICIAL',
              style: TextStyle(fontWeight: FontWeight.bold)),
          value: widget.pruebas.linealidad?.activo ?? false,
          onChanged: (bool value) {
            setState(() {
              if (value) {
                widget.pruebas.linealidad = Linealidad(activo: true);
              } else {
                widget.pruebas.linealidad = null;
              }
              widget.onChanged();
            });
          },
        ),
        if (widget.pruebas.linealidad != null)
          LinealidadInstalacionWidget(
            linealidad: widget.pruebas.linealidad!,
            onChanged: widget.onChanged,
            getD1FromDatabase: widget.getD1FromDatabase,
          ),
      ],
    );
  }
}
