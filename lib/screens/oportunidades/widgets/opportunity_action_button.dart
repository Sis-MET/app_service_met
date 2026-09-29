import 'package:flutter/material.dart';

import '../../../utils/top_alert.dart';
import '../models/opportunity_service_context.dart';
import '../opportunity_form_screen.dart';

/// Acción del AppBar de Calibración y de Soporte: "Registrar oportunidad".
///
/// Es opcional y no es un paso: abre el formulario encima del servicio y, al
/// cerrarlo, el técnico sigue en el mismo paso. [contextBuilder] se evalúa al
/// tocar, para tomar lo que el servicio sabe en ese momento.
class OpportunityActionButton extends StatelessWidget {
  final OpportunityServiceContext Function() contextBuilder;

  /// Antes de abrir (p. ej., cerrar el teclado numérico del servicio).
  final VoidCallback? beforeOpen;

  const OpportunityActionButton({
    super.key,
    required this.contextBuilder,
    this.beforeOpen,
  });

  Future<void> _open(BuildContext context) async {
    beforeOpen?.call();
    FocusScope.of(context).unfocus();
    final outcome = await OpportunityFormScreen.open(
      context,
      serviceContext: contextBuilder(),
    );
    if (outcome == null || !context.mounted) return;
    TopAlert.show(context, outcome.message);
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Registrar oportunidad',
      icon: const Icon(Icons.business_center_outlined),
      onPressed: () => _open(context),
    );
  }
}
