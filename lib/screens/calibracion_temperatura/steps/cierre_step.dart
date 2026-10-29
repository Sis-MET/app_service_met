import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../theme/app_icons.dart';
import '../controllers/temperatura_controller.dart';
import '../models/temperatura_models.dart';
import '../widgets/temp_ui.dart';

class CierreTempStep extends StatelessWidget {
  const CierreTempStep({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<TemperaturaController>();
    final s = c.servicio;
    final medidos = c.puntos
        .where((p) =>
            p.estado == EstadoPunto.completo ||
            p.estado == EstadoPunto.interrumpido)
        .length;
    final unidad = s.equipo?.unidad ?? '°C';
    void ambiente({double? t, double? hr, bool esT = true}) =>
        c.actualizar((s) => s.copyWith(
              ambiente: TempAmbiente(
                temperaturaInicio: s.ambiente.temperaturaInicio,
                humedadInicio: s.ambiente.humedadInicio,
                temperaturaFin: esT ? t : s.ambiente.temperaturaFin,
                humedadFin: esT ? s.ambiente.humedadFin : hr,
              ),
            ));
    return TempStepPage(
      title: 'Cierre',
      subtitle: 'Condiciones finales y observaciones del servicio',
      children: [
        TempSection(
          title: 'Resumen',
          icon: AppIcons.resumen,
          child: Column(
            children: [
              TempDato('Equipo', s.equipo?.codMetrica),
              TempDato('Puntos medidos', '$medidos de ${c.puntos.length}'),
              TempDato(
                'Puntos',
                c.puntos
                    .map((p) =>
                        '${textoNumero(p.temperaturaNominal)} $unidad (${p.estado.etiqueta.toLowerCase()})')
                    .join(' · '),
              ),
              TempDato('Lecturas', '${c.lecturas.length}'),
              TempDato('Correcciones', '${c.correcciones.length}'),
            ],
          ),
        ),
        TempSection(
          title: 'Condiciones ambientales finales',
          icon: AppIcons.humedad,
          child: Row(children: [
            Expanded(
              child: TempNumeroField(
                key: const ValueKey('temp-amb-fin'),
                label: 'Temperatura',
                sufijo: '°C',
                valor: s.ambiente.temperaturaFin,
                onChanged: (v) => ambiente(t: v),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TempNumeroField(
                key: const ValueKey('temp-hr-fin'),
                label: 'Humedad',
                sufijo: '%HR',
                negativos: false,
                valor: s.ambiente.humedadFin,
                onChanged: (v) => ambiente(hr: v, esT: false),
              ),
            ),
          ]),
        ),
        TempSection(
          title: 'Observaciones',
          icon: AppIcons.nota,
          child: TempTextoField(
            label: 'Observaciones',
            hint: 'Estado del equipo, incidentes durante la medición…',
            valor: s.observaciones,
            maxLines: 4,
            maxLength: 2000,
            onChanged: (v) => c.actualizar((s) => s.copyWith(observaciones: v)),
          ),
        ),
        const TempAviso.bloqueado(
          'Al finalizar, el registro queda cerrado: ya no se corrigen '
          'lecturas ni datos, y queda listo para subir a DataMET.',
        ),
      ],
    );
  }
}
