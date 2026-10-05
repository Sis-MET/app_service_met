import 'package:flutter/material.dart';

import '../../../utils/top_alert.dart';
import '../../../widgets/service_ui/service_options_menu.dart';
import '../models/opportunity_service_context.dart';
import '../opportunity_form_screen.dart';
import '../../../theme/app_icons.dart';

/// "Registrar oportunidad comercial" del menú ⋮ de Calibración y de Soporte.
///
/// Es opcional y no es un paso: abre el formulario encima del servicio y, al
/// cerrarlo, el técnico sigue en el mismo paso. [contextBuilder] se evalúa al
/// elegirla, para tomar lo que el servicio sabe en ese momento.
class OpportunityMenuAction extends ServiceMenuAction {
  static const title = 'Registrar oportunidad comercial';

  OpportunityMenuAction({
    required OpportunityServiceContext Function() contextBuilder,
  }) : super(
          icon: AppIcons.oportunidad,
          label: title,
          onSelected: (context) => _open(context, contextBuilder),
        );

  static Future<void> _open(
    BuildContext context,
    OpportunityServiceContext Function() contextBuilder,
  ) async {
    FocusScope.of(context).unfocus();
    final outcome = await OpportunityFormScreen.open(
      context,
      serviceContext: contextBuilder(),
    );
    if (outcome == null || !context.mounted) return;
    TopAlert.show(context, outcome.message);
  }
}
