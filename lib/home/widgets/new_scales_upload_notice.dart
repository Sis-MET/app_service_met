import 'package:flutter/material.dart';
import '../../theme/app_icons.dart';

Future<void> showNewScalesUploadNotice(
  BuildContext context,
  int count,
) async {
  if (count <= 0) return;
  final plural = count == 1 ? 'balanza nueva' : 'balanzas nuevas';
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: const Icon(
        AppIcons.agregarEmpresa,
        color: Colors.orange,
        size: 36,
      ),
      title: Text('$count $plural'),
      content: Text(
        'La subida se completó correctamente. Debe dirigirse a DataMET para '
        'registrar los datos ${count == 1 ? 'de esta balanza nueva' : 'de estas balanzas nuevas'}.',
        textAlign: TextAlign.center,
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Entendido'),
        ),
      ],
    ),
  );
}
