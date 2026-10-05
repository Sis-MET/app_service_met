import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_icons.dart';

/// Explica por qué no se pudo cerrar la balanza. Un diálogo y no un aviso
/// pasajero: el mensaje dice qué dato corregir y no debe perderse.
Future<void> showSaveBlockedDialog(BuildContext context, String message) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Row(
        children: [
          Icon(AppIcons.sinConexion, color: AppColors.actionNegative),
          SizedBox(width: 8),
          Expanded(child: Text('La balanza no se cerró')),
        ],
      ),
      content: SingleChildScrollView(child: Text(message)),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Entendido'),
        ),
      ],
    ),
  );
}
