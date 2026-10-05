import 'package:flutter/material.dart';

import '../../../../theme/app_design.dart';
import '../../../../theme/app_icons.dart';

class ServicioIncompletoDialog extends StatelessWidget {
  final VoidCallback onConfirmSalir;
  final VoidCallback onContinuar;

  const ServicioIncompletoDialog({
    super.key,
    required this.onConfirmSalir,
    required this.onContinuar,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(AppIcons.advertencia, color: Colors.orange, size: 28),
          SizedBox(width: 8),
          Text('Servicio incompleto'),
        ],
      ),
      content: const Text(
        'Hay datos de precarga sin completar. Si sale ahora, '
        'los datos ingresados no se guardarán.\n\n'
        '¿Está seguro de que desea salir?',
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            onContinuar();
          },
          child: const Text('Continuar'),
        ),
        FilledButton(
          style: AppDesign.negativeButtonStyle(),
          onPressed: () {
            Navigator.of(context).pop();
            onConfirmSalir();
          },
          child: const Text('Salir sin guardar'),
        ),
      ],
    );
  }
}
