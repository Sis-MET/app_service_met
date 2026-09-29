import 'package:flutter/material.dart';

class UploadAuthDialog extends StatefulWidget {
  final String usuario;
  final String? message;
  final String title;

  const UploadAuthDialog({
    super.key,
    required this.usuario,
    this.message,
    this.title = 'Autenticar subida',
  });

  @override
  State<UploadAuthDialog> createState() => _UploadAuthDialogState();
}

class _UploadAuthDialogState extends State<UploadAuthDialog> {
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  void _authenticate() {
    final password = _passwordController.text;
    if (password.isNotEmpty) Navigator.of(context).pop(password);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Usuario: ${widget.usuario}'),
          if (widget.message != null) ...[
            const SizedBox(height: 8),
            Text(widget.message!),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _passwordController,
            obscureText: true,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Contraseña',
              prefixIcon: Icon(Icons.lock_outline),
            ),
            onSubmitted: (_) => _authenticate(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _authenticate,
          child: const Text('Autenticar'),
        ),
      ],
    );
  }
}
