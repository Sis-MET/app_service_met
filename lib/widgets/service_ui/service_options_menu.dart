import 'package:flutter/material.dart';

import '../../theme/app_design.dart';
import '../../utils/top_alert.dart';
import '../../theme/app_icons.dart';

/// Opción del menú ⋮ de un servicio que no es salir, p. ej., registrar una
/// oportunidad comercial.
class ServiceMenuAction {
  final IconData icon;
  final String label;

  /// Se llama con el menú ya cerrado y el contexto de la pantalla.
  final void Function(BuildContext context) onSelected;

  const ServiceMenuAction({
    required this.icon,
    required this.label,
    required this.onSelected,
  });
}

/// Sugerencia que acompaña a la confirmación de salida: algo que conviene
/// hacer antes de dejar el servicio a medias (p. ej., emitir el RIM de una
/// balanza que no permite concluirlo).
class ServiceExitSuggestion {
  final IconData icon;

  /// Por qué conviene, en una o dos líneas.
  final String message;

  /// Texto del botón.
  final String label;

  /// Si la sugerencia corresponde ahora. Sin él, se muestra siempre.
  final Future<bool> Function()? applies;

  /// Se llama con la confirmación ya cerrada y sin salir del servicio.
  final void Function(BuildContext context) onSelected;

  const ServiceExitSuggestion({
    required this.icon,
    required this.message,
    required this.label,
    required this.onSelected,
    this.applies,
  });
}

/// Menú ⋮ del AppBar de un servicio: sus [actions] y, al final, la única
/// forma de salir a medias, "Salir (queda guardado)".
///
/// Atrás del sistema solo retrocede entre pasos: un gesto accidental en el
/// borde de la pantalla nunca saca al técnico del servicio. Salir es una
/// decisión explícita y se confirma.
class ServiceOptionsMenu extends StatelessWidget {
  static const tooltip = 'Más opciones';
  static const exitLabel = 'Salir (queda guardado)';
  static const _exitValue = -1;

  /// Guarda lo pendiente y dice si se puede cerrar la pantalla. Se llama
  /// después de que el técnico confirma.
  final Future<bool> Function() onExit;

  /// "la calibración", "el servicio"…, para la confirmación.
  final String serviceName;

  /// Opciones sobre la salida, en este orden.
  final List<ServiceMenuAction> actions;

  /// Se ofrece dentro de la confirmación de salida, cuando corresponde.
  final ServiceExitSuggestion? exitSuggestion;

  /// Al abrir el menú (p. ej., cerrar el teclado numérico).
  final VoidCallback? onOpened;

  const ServiceOptionsMenu({
    super.key,
    required this.onExit,
    this.serviceName = 'el servicio',
    this.actions = const [],
    this.exitSuggestion,
    this.onOpened,
  });

  /// Aviso para Atrás en el primer paso, donde no hay paso anterior.
  static void showFirstStepHint(BuildContext context) {
    TopAlert.show(
      context,
      'Es el primer paso. Para salir use ⋮ › "$exitLabel".',
    );
  }

  Future<void> _exit(BuildContext context) async {
    var suggestion = exitSuggestion;
    if (suggestion?.applies != null) {
      var applies = false;
      try {
        applies = await suggestion!.applies!();
      } catch (_) {
        // Sin poder comprobarlo no se sugiere nada: salir no debe fallar.
      }
      if (!applies) suggestion = null;
      if (!context.mounted) return;
    }
    // true: salir; false: la sugerencia; null: seguir en el servicio.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('¿Salir de $serviceName?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Lo registrado queda guardado en este teléfono y podrá continuar '
              'desde Servicios.',
            ),
            if (suggestion != null) ...[
              const SizedBox(height: 16),
              Text(
                suggestion.message,
                style: Theme.of(dialogContext).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(dialogContext, false),
                icon: Icon(suggestion.icon),
                label: Text(suggestion.label),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Seguir aquí'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Salir'),
          ),
        ],
      ),
    );
    if (!context.mounted) return;
    if (confirmed == false) {
      suggestion?.onSelected(context);
      return;
    }
    if (confirmed != true) return;
    final canClose = await onExit();
    if (canClose && context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    // Íconos y textos en un solo color, el del tema: negro en claro y blanco
    // en oscuro.
    final ink = Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : AppDesign.ink;

    Widget row(IconData icon, String label) => ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(icon, color: ink),
          title: Text(label, style: TextStyle(color: ink)),
        );

    // onSelected llega con el menú ya cerrado, así el diálogo o la pantalla
    // que abre la opción no se cierran junto con él.
    return PopupMenuButton<int>(
      tooltip: tooltip,
      icon: const Icon(AppIcons.masVertical),
      shape: RoundedRectangleBorder(borderRadius: AppDesign.mediumRadius),
      clipBehavior: Clip.antiAlias,
      onOpened: onOpened,
      onSelected: (value) => value == _exitValue
          ? _exit(context)
          : actions[value].onSelected(context),
      itemBuilder: (_) => [
        for (var i = 0; i < actions.length; i++)
          PopupMenuItem<int>(
            value: i,
            child: row(actions[i].icon, actions[i].label),
          ),
        PopupMenuItem<int>(
          value: _exitValue,
          child: row(AppIcons.salir, exitLabel),
        ),
      ],
    );
  }
}
