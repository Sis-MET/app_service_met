import 'package:flutter/material.dart';
import '../../../theme/app_icons.dart';

/// Pide la contraseña para autorizar una actualización de la precarga.
///
/// Es un StatefulWidget a propósito: el [TextEditingController] debe vivir y
/// morir con el widget que lo usa. Cuando el controller se creaba fuera y se
/// liberaba apenas `showDialog` completaba su Future, la ruta todavía estaba
/// animando su salida y el TextField se reconstruía con un controller ya
/// liberado, lanzando "A TextEditingController was used after being disposed".
///
/// Mismo patrón que `UploadAuthDialog` en lib/home/widgets/.
class AutorizarActualizacionDialog extends StatefulWidget {
  const AutorizarActualizacionDialog({super.key});

  @override
  State<AutorizarActualizacionDialog> createState() =>
      _AutorizarActualizacionDialogState();
}

class _AutorizarActualizacionDialogState
    extends State<AutorizarActualizacionDialog> {
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  void _confirmar() => Navigator.of(context).pop(_passwordController.text);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Autorizar actualización'),
      content: TextField(
        controller: _passwordController,
        obscureText: true,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Contraseña',
          prefixIcon: Icon(AppIcons.bloqueado),
        ),
        onSubmitted: (_) => _confirmar(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _confirmar,
          child: const Text('Actualizar'),
        ),
      ],
    );
  }
}
