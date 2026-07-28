import 'package:flutter/material.dart';
import 'package:service_met/screens/soporte_new/models/shared_metrology_models.dart';
import 'package:service_met/screens/soporte_new/widgets/shared/pruebas_metrologicas_widget.dart';

class PasoPruebasInicialesWidget extends StatelessWidget {
  final PruebasMetrologicas pruebasIniciales;
  final VoidCallback onDataChanged;

  const PasoPruebasInicialesWidget({
    super.key,
    required this.pruebasIniciales,
    required this.onDataChanged,
  });

  @override
  Widget build(BuildContext context) {
    return PruebasMetrologicasWidget(
      pruebas: pruebasIniciales,
      title: 'Pruebas Iniciales',
      onDataChanged: onDataChanged,
    );
  }
}
