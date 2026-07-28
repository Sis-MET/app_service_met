import 'package:flutter/material.dart';
import 'package:service_met/screens/soporte/models/shared_metrology_models.dart';
import 'package:service_met/screens/soporte/widgets/shared/excentricidad_widget.dart';
import 'package:service_met/screens/soporte/widgets/shared/repetibilidad_widget.dart';
import 'package:service_met/screens/soporte/widgets/shared/linealidad_widget.dart';
import 'package:service_met/screens/soporte/widgets/shared/soporte_input_decorations.dart';

class PruebasMetrologicasWidget extends StatefulWidget {
  final PruebasMetrologicas pruebas;
  final bool isInicial;
  final VoidCallback onChanged;
  final Future<double> Function() getD1FromDatabase;

  const PruebasMetrologicasWidget({
    super.key,
    required this.pruebas,
    required this.isInicial,
    required this.onChanged,
    required this.getD1FromDatabase,
  });

  @override
  State<PruebasMetrologicasWidget> createState() =>
      _PruebasMetrologicasWidgetState();
}

class _PruebasMetrologicasWidgetState extends State<PruebasMetrologicasWidget> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'PRUEBAS METROLÓGICAS ${widget.isInicial ? 'INICIALES' : 'FINALES'}',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFFDECD00),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20.0),

        DropdownButtonFormField<String>(
          value: widget.pruebas.retornoCero.estado.isEmpty
              ? null
              : widget.pruebas.retornoCero.estado,
          hint: const Text('Seleccione...'),
          decoration: SoporteInputDecorations.buildInputDecoration('Retorno a Cero'),
          items: const [
            DropdownMenuItem(value: '1 Bueno', child: Text('1 Bueno')),
            DropdownMenuItem(value: '2 Aceptable', child: Text('2 Aceptable')),
            DropdownMenuItem(value: '3 Malo', child: Text('3 Malo')),
            DropdownMenuItem(value: '4 No aplica', child: Text('4 No aplica')),
          ],
          onChanged: (value) {
            if (value != null) {
              widget.pruebas.retornoCero.estado = value;
              widget.onChanged();
            }
          },
        ),
        const SizedBox(height: 20.0),

        DropdownButtonFormField<String>(
          value: widget.pruebas.retornoCero.estabilidad.isEmpty
              ? null
              : widget.pruebas.retornoCero.estabilidad,
          hint: const Text('Seleccione...'),
          decoration: SoporteInputDecorations.buildInputDecoration('Estabilidad'),
          items: const [
            DropdownMenuItem(value: '1 Bueno', child: Text('1 Bueno')),
            DropdownMenuItem(value: '2 Aceptable', child: Text('2 Aceptable')),
            DropdownMenuItem(value: '3 Malo', child: Text('3 Malo')),
            DropdownMenuItem(value: '4 No aplica', child: Text('4 No aplica')),
          ],
          onChanged: (value) {
            if (value != null) {
              widget.pruebas.retornoCero.estabilidad = value;
              widget.onChanged();
            }
          },
        ),
        const SizedBox(height: 20.0),

        SwitchListTile(
          title: Text(
              'PRUEBAS DE EXCENTRICIDAD ${widget.isInicial ? 'INICIAL' : 'FINAL'}',
              style: const TextStyle(fontWeight: FontWeight.bold)),
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
          ExcentricidadWidget(
            excentricidad: widget.pruebas.excentricidad!,
            getD1FromDatabase: widget.getD1FromDatabase,
            onChanged: widget.onChanged,
          ),

        const SizedBox(height: 20.0),

        SwitchListTile(
          title: Text(
              'PRUEBAS DE REPETIBILIDAD ${widget.isInicial ? 'INICIAL' : 'FINAL'}',
              style: const TextStyle(fontWeight: FontWeight.bold)),
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
          RepetibilidadWidget(
            repetibilidad: widget.pruebas.repetibilidad!,
            getD1FromDatabase: widget.getD1FromDatabase,
            onChanged: widget.onChanged,
          ),

        const SizedBox(height: 20.0),

        SwitchListTile(
          title: Text(
              'PRUEBAS DE LINEALIDAD ${widget.isInicial ? 'INICIAL' : 'FINAL'}',
              style: const TextStyle(fontWeight: FontWeight.bold)),
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
          LinealidadWidget(
            linealidad: widget.pruebas.linealidad!,
            onChanged: widget.onChanged,
            getD1FromDatabase: widget.getD1FromDatabase,
          ),
      ],
    );
  }
}
