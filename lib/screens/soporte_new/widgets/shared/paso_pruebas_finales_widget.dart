import 'package:flutter/material.dart';
import 'package:service_met/screens/soporte_new/models/shared_metrology_models.dart';
import 'package:service_met/screens/soporte_new/widgets/shared/pruebas_metrologicas_widget.dart';

class PasoPruebasFinalesWidget extends StatelessWidget {
  final PruebasMetrologicas pruebasFinales;
  final VoidCallback onDataChanged;

  const PasoPruebasFinalesWidget({
    super.key,
    required this.pruebasFinales,
    required this.onDataChanged,
  });

  @override
  Widget build(BuildContext context) {
    return PruebasMetrologicasWidget(
      pruebas: pruebasFinales,
      title: 'Pruebas Finales',
      onDataChanged: onDataChanged,
    );
  }
}
