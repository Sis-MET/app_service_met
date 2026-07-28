import 'package:flutter/material.dart';
import 'package:service_met/screens/soporte_new/models/shared_metrology_models.dart';
import 'package:service_met/screens/soporte_new/widgets/shared/pruebas_metrologicas_widget.dart';

class PasoPruebasInicialesFinales extends StatelessWidget {
  final PruebasMetrologicas pruebasIniciales;
  final PruebasMetrologicas pruebasFinales;
  final VoidCallback onDataChanged;
  final VoidCallback? onCopiar;

  const PasoPruebasInicialesFinales({
    super.key,
    required this.pruebasIniciales,
    required this.pruebasFinales,
    required this.onDataChanged,
    this.onCopiar,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PruebasMetrologicasWidget(
          pruebas: pruebasIniciales,
          title: 'Pruebas Iniciales',
          onDataChanged: onDataChanged,
        ),
        const Divider(height: 32),
        if (onCopiar != null)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: ElevatedButton.icon(
                onPressed: onCopiar,
                icon: const Icon(Icons.copy),
                label: const Text('Copiar iniciales a finales'),
              ),
            ),
          ),
        PruebasMetrologicasWidget(
          pruebas: pruebasFinales,
          title: 'Pruebas Finales',
          onDataChanged: onDataChanged,
        ),
      ],
    );
  }
}
