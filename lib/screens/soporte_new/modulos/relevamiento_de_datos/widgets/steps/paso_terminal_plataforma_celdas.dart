import 'package:flutter/material.dart';
import 'package:service_met/screens/soporte_new/models/campo_estado.dart';
import 'package:service_met/screens/soporte_new/widgets/shared/campo_inspeccion_widget.dart';

class PasoTerminalPlataformaCeldas extends StatelessWidget {
  final List<CampoEstado> campos;
  final void Function(int index, String value, String solutionValue) onChanged;
  final void Function(String label, String foto) onAddPhoto;
  final void Function(int index) onRemovePhoto;

  const PasoTerminalPlataformaCeldas({
    super.key,
    required this.campos,
    required this.onChanged,
    required this.onAddPhoto,
    required this.onRemovePhoto,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 16),
          child: Text(
            'Inspección de Terminal, Plataforma y Celdas',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        ...List.generate(campos.length, (i) {
          return CampoInspeccionWidget(
            campoEstado: campos[i],
            onChanged: (value, solutionValue) => onChanged(i, value, solutionValue),
            onAddPhoto: onAddPhoto,
            onRemovePhoto: (index) => onRemovePhoto(index),
          );
        }),
      ],
    );
  }
}
