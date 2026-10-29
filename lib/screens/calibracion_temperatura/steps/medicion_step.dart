import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../theme/app_icons.dart';
import '../../../utils/top_alert.dart';
import '../captura/captura_temperatura_screen.dart';
import '../controllers/temperatura_controller.dart';
import '../lecturas_punto_screen.dart';
import '../models/temperatura_models.dart';
import '../widgets/resumen_punto_card.dart';
import '../widgets/temp_ui.dart';

/// Abre las lecturas de un punto; con el registro en curso, corregibles.
Future<void> abrirLecturasPunto(
  BuildContext context,
  TemperaturaController controller,
  TempPunto punto,
) {
  return Navigator.of(context).push<void>(MaterialPageRoute(
    builder: (_) => LecturasPuntoScreen(
      punto: punto,
      canales: controller.canales,
      lecturas: controller.lecturas,
      correcciones: controller.correcciones,
      unidad: controller.servicio.equipo?.unidad ?? '°C',
      onCorregir: controller.editable ? controller.corregir : null,
      recargar: () async {
        await controller.recargar();
        return (controller.lecturas, controller.correcciones);
      },
    ),
  ));
}

class MedicionTempStep extends StatelessWidget {
  const MedicionTempStep({super.key});

  Future<void> _detener(
      BuildContext context, TemperaturaController c, TempPunto punto) async {
    final motivo = await pedirMotivo(
      context,
      titulo: 'Detener la medición',
      mensaje: 'Las lecturas tomadas se conservan. El punto queda '
          'interrumpido con este motivo.',
      accion: 'Detener',
      destructivo: true,
    );
    if (motivo == null || !context.mounted) return;
    final error = await c.detenerPunto(punto.n, motivo);
    if (error != null && context.mounted) {
      TopAlert.show(context, error, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<TemperaturaController>();
    final unidad = c.servicio.equipo?.unidad ?? '°C';
    final enCurso = c.puntos.where((p) => p.estado == EstadoPunto.enCurso);
    final camara =
        c.canales.where((k) => k.metodo == MetodoCanal.camara).length;
    return TempStepPage(
      title: 'Medición',
      subtitle: 'Lecturas programadas de cada punto con la cámara',
      children: [
        TempAviso(
          icon: AppIcons.camara,
          texto: camara == 0
              ? 'El indicador se registra a mano: la app pide cada lectura a '
                  'su hora.'
              : 'Fije el teléfono frente al indicador del equipo (trípode o '
                  'soporte). La cámara toma cada lectura sola y guarda una '
                  'imagen del display como evidencia. Los sensores del patrón '
                  'graban en su software: inicie su registro a la misma hora '
                  'y con el mismo intervalo.',
        ),
        if (c.puntos.isEmpty)
          const TempAviso(texto: 'Agregue los puntos en el paso anterior.'),
        for (final punto in c.puntos)
          ResumenPuntoCard(
            punto: punto,
            canales: c.canales,
            lecturas: c.lecturas,
            unidad: unidad,
            acciones: [
              if (punto.estado == EstadoPunto.pendiente && c.editable)
                FilledButton.icon(
                  key: ValueKey('temp-iniciar-${punto.n}'),
                  onPressed: enCurso.isNotEmpty
                      ? null
                      : () =>
                          CapturaTemperaturaScreen.abrir(context, c, punto.n),
                  icon: const Icon(AppIcons.camara, size: 18),
                  label: const Text('Preparar e iniciar'),
                ),
              if (punto.estado == EstadoPunto.enCurso && c.editable) ...[
                FilledButton.icon(
                  onPressed: () =>
                      CapturaTemperaturaScreen.abrir(context, c, punto.n),
                  icon: const Icon(AppIcons.camara, size: 18),
                  label: const Text('Continuar medición'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _detener(context, c, punto),
                  icon: const Icon(AppIcons.cuadro, size: 18),
                  label: const Text('Detener'),
                ),
              ],
              if (punto.estado != EstadoPunto.pendiente)
                OutlinedButton.icon(
                  onPressed: () => abrirLecturasPunto(context, c, punto),
                  icon: const Icon(AppIcons.tabla, size: 18),
                  label: const Text('Ver lecturas'),
                ),
            ],
          ),
        if (enCurso.isNotEmpty)
          const TempAviso(
            texto: 'Hay un punto en medición: los demás se inician cuando '
                'termine o se detenga.',
          ),
      ],
    );
  }
}
