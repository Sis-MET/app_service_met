import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:service_met/screens/soporte_new/controllers/base_soporte_controller.dart';
import 'package:service_met/utils/top_alert.dart';

/// Movimiento entre los pasos de un servicio de soporte, con la misma
/// seguridad que la calibración:
///
/// - hacia atrás se va siempre: lo escrito sigue en pantalla y se guarda;
/// - hacia adelante ("Siguiente" o el panel ≡), solo con todos los pasos
///   anteriores completos y lo escrito guardado en el teléfono;
/// - se finaliza solo con todos los pasos completos y guardados.
///
/// Si falta algo, lleva al primer paso incompleto y dice qué falta.
class PasosSoporte {
  PasosSoporte({
    required this.controller,
    required this.total,
    required this.falta,
  });

  final BaseSoporteController controller;

  /// Cantidad de pasos del módulo.
  final int total;

  /// Qué le falta a un paso para darlo por completo; null si nada.
  final String? Function(int paso) falta;

  /// Evita dos avances a la vez (dos toques seguidos en "Siguiente").
  bool _avanzando = false;

  /// Primer paso antes de [paso] al que le falta algo, o null.
  int? incompletoAntesDe(int paso) {
    for (var i = 0; i < paso && i < total; i++) {
      if (falta(i) != null) return i;
    }
    return null;
  }

  /// Va a [paso]: hacia atrás siempre; hacia adelante, solo con lo anterior
  /// completo y guardado.
  Future<void> irA(BuildContext context, int paso) async {
    final actual = controller.currentStep;
    if (paso == actual || paso < 0 || paso >= total) return;
    if (paso < actual) {
      controller.setCurrentStep(paso);
      if (controller.hasUnsavedChanges.value) {
        unawaited(controller.autoSave());
      }
      return;
    }
    if (await _listoHasta(context, paso) && context.mounted) {
      controller.setCurrentStep(paso);
    }
  }

  /// Antes de abrir el resumen final: todos los pasos completos y guardados.
  Future<bool> listoParaFinalizar(BuildContext context) =>
      _listoHasta(context, total);

  Future<bool> _listoHasta(BuildContext context, int paso) async {
    if (_avanzando) return false;
    final pendiente = incompletoAntesDe(paso);
    if (pendiente != null) {
      controller.setCurrentStep(pendiente);
      TopAlert.show(context, falta(pendiente)!, isError: true);
      return false;
    }
    _avanzando = true;
    try {
      if (await controller.guardarAhora()) return true;
      if (context.mounted) {
        final motivo = controller.lastSaveError;
        TopAlert.show(
          context,
          'No se pudo guardar en el teléfono'
          '${motivo == null ? '' : ': $motivo'}.\n'
          'Lo escrito sigue en pantalla; intente de nuevo.',
          isError: true,
        );
      }
      return false;
    } finally {
      _avanzando = false;
    }
  }
}
