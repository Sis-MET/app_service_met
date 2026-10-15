import 'package:flutter/material.dart';

import 'package:service_met/screens/oportunidades/models/opportunity_service_context.dart';
import 'package:service_met/screens/oportunidades/widgets/opportunity_menu_action.dart';
import 'package:service_met/screens/rim/rim_flow.dart';
import 'package:service_met/screens/soporte_new/controllers/base_soporte_controller.dart';
import 'package:service_met/screens/soporte_new/precarga/precarga_screen.dart';
import 'package:service_met/utils/top_alert.dart';
import 'package:service_met/widgets/requiere_ubicacion.dart';
import 'package:service_met/widgets/service_ui/service_options_menu.dart';

/// Menú ⋮ común a los módulos de soporte: emitir el RIM del instrumento y
/// registrar una oportunidad comercial, sobre "Salir (queda guardado)".
///
/// [contextBuilder] se evalúa al elegir cada opción, para tomar lo que el
/// servicio sabe en ese momento.
class SoporteMenu {
  final BaseSoporteController controller;
  final OpportunityServiceContext Function() contextBuilder;

  /// Datos con los que la precarga abrió el módulo, para volver a ella con
  /// el mismo cliente, planta y OTST.
  final String userName;
  final String clienteId;
  final String plantaCodigo;
  final String otst;

  const SoporteMenu({
    required this.controller,
    required this.contextBuilder,
    required this.userName,
    required this.clienteId,
    required this.plantaCodigo,
    required this.otst,
  });

  List<ServiceMenuAction> get actions => [
        RimMenuAction(
          contextBuilder: contextBuilder,
          onCambiarBalanza: cambiarBalanza,
        ),
        OpportunityMenuAction(contextBuilder: contextBuilder),
      ];

  /// Al salir a medias, sugiere el RIM si el instrumento todavía no lo tiene.
  ServiceExitSuggestion get exitSuggestion => rimExitSuggestion(
        contextBuilder: contextBuilder,
        onCambiarBalanza: cambiarBalanza,
      );

  /// Deja sin concluir el servicio de esta balanza (lo registrado queda en
  /// el teléfono) y vuelve a la precarga para elegir otra, con el mismo
  /// cliente, planta y OTST.
  Future<void> cambiarBalanza(BuildContext context) async {
    if (!await controller.guardarAntesDeSalir()) {
      if (context.mounted) {
        TopAlert.show(
          context,
          'No se pudo guardar lo registrado. Corrija el guardado antes de '
          'cambiar de balanza.',
          isError: true,
        );
      }
      return;
    }
    await controller.markRecoveryAbandoned();
    if (!context.mounted) return;
    Navigator.of(context).pushReplacement(
      RequiereUbicacion.ruta(PrecargaScreenSop(
        tableName: controller.tableName,
        userName: userName,
        clienteId: clienteId,
        plantaCodigo: plantaCodigo,
        servicio: controller.tipoServicio,
        seca: otst,
        skipToBalanza: true,
      )),
    );
  }
}
