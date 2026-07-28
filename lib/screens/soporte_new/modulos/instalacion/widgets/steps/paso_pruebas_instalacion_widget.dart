import 'package:flutter/material.dart';
import 'package:service_met/screens/soporte_new/models/shared_metrology_models.dart';
import 'package:service_met/screens/soporte_new/widgets/shared/pruebas_metrologicas_widget.dart';

class PasoPruebasInstalacionWidget extends StatelessWidget {
  final PruebasMetrologicas pruebasFinales;
  final VoidCallback onDataChanged;

  const PasoPruebasInstalacionWidget({
    super.key,
    required this.pruebasFinales,
    required this.onDataChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 16),
          child: Text(
            'Pruebas de Instalación',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        PruebasMetrologicasWidget(
          pruebas: pruebasFinales,
          title: 'Pruebas Finales de Instalación',
          onDataChanged: onDataChanged,
        ),
      ],
    );
  }
}
