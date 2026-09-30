import 'package:flutter/material.dart';

import '../controllers/base_soporte_controller.dart';

/// "Salir (queda guardado)" de un módulo de soporte: guarda lo pendiente y,
/// solo si no se pudo, pregunta antes de cerrar. Devuelve si se puede salir.
Future<bool> salirGuardando(
  BuildContext context,
  BaseSoporteController controller,
) async {
  if (await controller.guardarAntesDeSalir()) return true;
  if (!context.mounted) return false;
  final salir = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('No se pudo guardar'),
      content: const Text(
        'Los últimos cambios no quedaron guardados. Si sale ahora, se '
        'perderán.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Salir sin guardar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Quedarme'),
        ),
      ],
    ),
  );
  return salir == true;
}
