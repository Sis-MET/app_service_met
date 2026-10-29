import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_icons.dart';
import '../../../utils/new_scale_code.dart';
import '../../../utils/top_alert.dart';
import '../controllers/temperatura_controller.dart';
import '../models/temperatura_models.dart';
import '../services/temperatura_repository.dart';
import '../widgets/acciones_registro.dart';
import '../widgets/resumen_punto_card.dart';
import '../widgets/temp_ui.dart';
import 'medicion_step.dart';

class ResumenTempStep extends StatefulWidget {
  const ResumenTempStep({super.key});

  @override
  State<ResumenTempStep> createState() => _ResumenTempStepState();
}

class _ResumenTempStepState extends State<ResumenTempStep> {
  bool _subiendo = false;

  Future<void> _subir(TemperaturaController c) async {
    setState(() => _subiendo = true);
    await subirRegistroTemperatura(context, c.servicio.uuid, store: c.store);
    await c.recargar();
    if (mounted) setState(() => _subiendo = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<TemperaturaController>();
    final s = c.servicio;
    final unidad = s.equipo?.unidad ?? '°C';
    final impedimento = TemperaturaRepository.impedimento(s);
    final (estadoTexto, estadoColor, estadoIcono) = switch (s.subida) {
      EstadoSubidaTemp.subido => (
          'En DataMET (N.º ${s.serverN})',
          AppColors.actionPositive,
          AppIcons.nubeLista
        ),
      EstadoSubidaTemp.enviando => (
          'Enviando…',
          AppColors.shimmerGold,
          AppIcons.subir
        ),
      EstadoSubidaTemp.error => (
          'Rechazado',
          AppColors.actionNegative,
          AppIcons.error
        ),
      EstadoSubidaTemp.pendiente => (
          'Pendiente de subir',
          AppColors.shimmerGold,
          AppIcons.pendiente
        ),
    };
    return TempStepPage(
      title: 'Resumen',
      subtitle: s.finalizado
          ? 'Calibración finalizada: queda tal como se registró'
          : 'Revise los resultados antes de finalizar',
      children: [
        TempSection(
          title: 'Registro',
          icon: AppIcons.temperatura,
          trailing: s.finalizado
              ? TempEstado(estadoTexto, color: estadoColor, icon: estadoIcono)
              : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TempDato('Código', s.codigoRegistro),
              TempDato('Cliente', s.cliente?.nombre),
              TempDato('Planta', s.planta?.nombre),
              TempDato(
                  'Equipo',
                  [s.equipo?.tipo, s.equipo?.marca, s.equipo?.modelo]
                      .whereType<String>()
                      .join(' · ')),
              TempDato('Técnico', s.personal),
              TempDato('Inicio', horaLegible(s.horaInicio)),
              TempDato('Fin', horaLegible(s.horaFin)),
              if (s.subidaError != null && !s.subido)
                TempAviso.error(s.subidaError!),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => exportarCsvTemperatura(context, c.paquete),
                    icon: const Icon(AppIcons.exportarArchivo, size: 18),
                    label: const Text('Exportar CSV'),
                  ),
                  if (s.finalizado &&
                      NewScaleCode.isProvisional(s.equipo?.codMetrica))
                    OutlinedButton.icon(
                      onPressed: () async {
                        await asignarCodigoTemperatura(context, s,
                            store: c.store);
                        await c.recargar();
                      },
                      icon: const Icon(AppIcons.etiqueta, size: 18),
                      label: const Text('Asignar código'),
                    ),
                  if (s.finalizado && !s.subido)
                    FilledButton.icon(
                      key: const ValueKey('temp-subir'),
                      onPressed: _subiendo || impedimento != null
                          ? null
                          : () => _subir(c),
                      icon: _subiendo
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(AppIcons.subir, size: 18),
                      label: const Text('Subir a DataMET'),
                    ),
                ],
              ),
              if (s.finalizado && impedimento != null && !s.subido)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: TempAviso(texto: impedimento),
                ),
            ],
          ),
        ),
        for (final punto in c.puntos)
          if (punto.estado != EstadoPunto.pendiente)
            ResumenPuntoCard(
              punto: punto,
              canales: c.canales,
              lecturas: c.lecturas,
              unidad: unidad,
              acciones: [
                OutlinedButton.icon(
                  onPressed: () => abrirLecturasPunto(context, c, punto),
                  icon: const Icon(AppIcons.tabla, size: 18),
                  label: const Text('Ver lecturas'),
                ),
              ],
            ),
        if (s.finalizado)
          FilledButton.icon(
            key: const ValueKey('temp-otro-equipo'),
            onPressed: () async {
              final error = await c.otroEquipo();
              if (!context.mounted) return;
              TopAlert.show(
                context,
                error ?? 'Nuevo equipo en la SECA ${c.servicio.seca}.',
                isError: error != null,
              );
            },
            icon: const Icon(AppIcons.agregar, size: 18),
            label: const Text('Calibrar otro equipo (misma SECA)'),
          ),
      ],
    );
  }
}
