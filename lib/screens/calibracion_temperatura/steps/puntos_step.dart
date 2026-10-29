// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../theme/app_icons.dart';
import '../../../utils/top_alert.dart';
import '../../../widgets/service_ui/calibracion_ui.dart';
import '../controllers/temperatura_controller.dart';
import '../models/temperatura_models.dart';
import '../widgets/resumen_punto_card.dart';
import '../widgets/temp_ui.dart';

const duracionesMin = [15.0, 30.0, 45.0, 60.0];
const intervalosS = [10, 15, 30, 60];

/// Límite de lecturas de un punto: más de esto ya no es una medición
/// programada razonable para un teléfono.
const maxLecturasPunto = 2000;

/// "91 lecturas cada 30 s · 45 min · fin estimado 10:45".
String resumenPunto(TempPunto punto, {DateTime? desde}) {
  final total = punto.lecturas;
  final inicio = desde ?? DateTime.now();
  final fin = inicio.add(Duration(seconds: punto.intervaloS * (total - 1)));
  String dos(int n) => n.toString().padLeft(2, '0');
  return '$total lecturas cada ${punto.intervaloS} s · '
      '${textoNumero(punto.duracionMin)} min · fin estimado '
      '${dos(fin.hour)}:${dos(fin.minute)}';
}

/// El motivo por el que la configuración no sirve, o null.
String? problemaPunto(TempPunto punto) {
  if (punto.duracionMin <= 0) return 'La duración debe ser mayor que cero.';
  if (punto.intervaloS < 2) return 'El intervalo mínimo es de 2 segundos.';
  if (punto.intervaloS > punto.duracionMin * 60) {
    return 'El intervalo no puede ser mayor que la duración.';
  }
  if (punto.lecturas > maxLecturasPunto) {
    return 'Son demasiadas lecturas ($maxLecturasPunto como máximo).';
  }
  return null;
}

class PuntosTempStep extends StatelessWidget {
  const PuntosTempStep({super.key});

  Future<void> _editar(
    BuildContext context,
    TemperaturaController controller, {
    TempPunto? punto,
  }) async {
    final unidad = controller.servicio.equipo?.unidad ?? '°C';
    final anterior = controller.puntos.lastOrNull;
    final base = punto ??
        TempPunto(
          n: (controller.puntos
                  .map((p) => p.n)
                  .fold(0, (a, b) => a > b ? a : b)) +
              1,
          temperaturaNominal: anterior?.temperaturaNominal ?? 100,
          duracionMin: anterior?.duracionMin ?? 45,
          intervaloS: anterior?.intervaloS ?? 30,
          estabilizacionMin: anterior?.estabilizacionMin,
        );
    final resultado = await showModalBottomSheet<(TempPunto?, bool)>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PuntoSheet(
        punto: base,
        unidad: unidad,
        puedeQuitar: punto != null,
      ),
    );
    if (resultado == null || !context.mounted) return;
    final (editado, quitar) = resultado;
    final lista = [...controller.puntos];
    final indice = lista.indexWhere((p) => p.n == base.n);
    if (quitar) {
      if (indice >= 0) lista.removeAt(indice);
    } else if (indice >= 0) {
      lista[indice] = editado!;
    } else {
      lista.add(editado!);
    }
    final error = await controller.guardarPuntos(lista);
    if (error != null && context.mounted) {
      TopAlert.show(context, error, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TemperaturaController>();
    final unidad = controller.servicio.equipo?.unidad ?? '°C';
    final isDark = CalUi.dark(context);
    return TempStepPage(
      title: 'Puntos de calibración',
      subtitle: 'Temperatura, lapso de medición y cada cuánto se captura',
      children: [
        Text(
          'La primera lectura se toma al iniciar y la última al cumplirse el '
          'lapso. Configure el registrador de los sensores con el mismo '
          'intervalo.',
          style: GoogleFonts.inter(
              fontSize: 12.5, height: 1.4, color: CalUi.secundario(isDark)),
        ),
        const SizedBox(height: 16),
        if (controller.puntos.isEmpty)
          const CalEmptyState(
            icon: AppIcons.temperatura,
            title: 'Sin puntos',
            subtitle: 'Agregue la primera temperatura a medir',
          ),
        for (final punto in controller.puntos) ...[
          PuntoTile(
            punto: punto,
            unidad: unidad,
            onTap: punto.estado == EstadoPunto.pendiente
                ? () => _editar(context, controller, punto: punto)
                : null,
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 8),
        FilledButton.icon(
          key: const ValueKey('temp-agregar-punto'),
          onPressed: () => _editar(context, controller),
          icon: const Icon(AppIcons.agregar, size: 18),
          label: const Text('Agregar punto'),
        ).animate(delay: 200.ms).fadeIn(),
      ],
    );
  }
}

/// Un punto en la lista, como un elemento de la lista de clientes.
class PuntoTile extends StatelessWidget {
  const PuntoTile({
    super.key,
    required this.punto,
    required this.unidad,
    this.onTap,
  });

  final TempPunto punto;
  final String unidad;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = CalUi.dark(context);
    final (color, icon) = estiloPunto(punto.estado);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: CalUi.fondo(isDark),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: CalUi.borde(isDark)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: CalUi.accent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text('${punto.n}',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: CalUi.ink)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${textoNumero(punto.temperaturaNominal)} $unidad',
                    style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: CalUi.texto(isDark)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    resumenPunto(punto),
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : Colors.black45),
                  ),
                  if (punto.estabilizacionMin != null)
                    Text(
                      'Estabilización: ${textoNumero(punto.estabilizacionMin)} min',
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          color: isDark ? Colors.white54 : Colors.black45),
                    ),
                  const SizedBox(height: 8),
                  TempEstado(punto.estado.etiqueta, color: color, icon: icon),
                ],
              ),
            ),
            Icon(onTap == null ? AppIcons.bloqueado : AppIcons.editar,
                size: 16, color: isDark ? Colors.white38 : Colors.black38),
          ],
        ),
      ),
    );
  }
}

class _PuntoSheet extends StatefulWidget {
  const _PuntoSheet({
    required this.punto,
    required this.unidad,
    required this.puedeQuitar,
  });

  final TempPunto punto;
  final String unidad;
  final bool puedeQuitar;

  @override
  State<_PuntoSheet> createState() => _PuntoSheetState();
}

class _PuntoSheetState extends State<_PuntoSheet> {
  late double? _nominal = widget.punto.temperaturaNominal;
  late double? _duracion = widget.punto.duracionMin;
  late double? _intervalo = widget.punto.intervaloS.toDouble();
  late double? _estabilizacion = widget.punto.estabilizacionMin;

  TempPunto? get _punto {
    if (_nominal == null || _duracion == null || _intervalo == null) {
      return null;
    }
    return TempPunto(
      n: widget.punto.n,
      temperaturaNominal: _nominal!,
      duracionMin: _duracion!,
      intervaloS: _intervalo!.round(),
      estabilizacionMin: _estabilizacion,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CalUi.dark(context);
    final punto = _punto;
    final problema =
        punto == null ? 'Complete los datos.' : problemaPunto(punto);
    Widget etiqueta(String texto) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(texto,
              style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.black87)),
        );
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black26,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text('Punto ${widget.punto.n}',
                    style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: CalUi.texto(isDark))),
                const SizedBox(height: 16),
                TempNumeroField(
                  key: const ValueKey('temp-punto-nominal'),
                  label: 'Temperatura nominal',
                  sufijo: widget.unidad,
                  icon: AppIcons.temperatura,
                  valor: _nominal,
                  onChanged: (v) => setState(() => _nominal = v),
                ),
                const SizedBox(height: 18),
                etiqueta('Lapso de medición'),
                TempOpciones<double>(
                  opciones: duracionesMin,
                  seleccion: _duracion,
                  etiqueta: (d) => '${textoNumero(d)} min',
                  onChanged: (d) => setState(() => _duracion = d),
                ),
                const SizedBox(height: 10),
                TempNumeroField(
                  key: const ValueKey('temp-punto-duracion'),
                  label: 'Duración',
                  sufijo: 'min',
                  negativos: false,
                  valor: _duracion,
                  onChanged: (v) => setState(() => _duracion = v),
                ),
                const SizedBox(height: 18),
                etiqueta('Capturar cada'),
                TempOpciones<int>(
                  opciones: intervalosS,
                  seleccion: _intervalo?.round(),
                  etiqueta: (s) => '$s s',
                  onChanged: (s) => setState(() => _intervalo = s.toDouble()),
                ),
                const SizedBox(height: 10),
                TempNumeroField(
                  key: const ValueKey('temp-punto-intervalo'),
                  label: 'Intervalo',
                  sufijo: 's',
                  negativos: false,
                  decimales: false,
                  valor: _intervalo,
                  onChanged: (v) => setState(() => _intervalo = v),
                ),
                const SizedBox(height: 18),
                TempNumeroField(
                  label: 'Estabilización previa (opcional)',
                  sufijo: 'min',
                  negativos: false,
                  valor: _estabilizacion,
                  onChanged: (v) => setState(() => _estabilizacion = v),
                ),
                const SizedBox(height: 18),
                if (problema != null)
                  TempAviso.error(problema)
                else
                  TempAviso(
                    icon: AppIcons.hora,
                    texto: 'Se tomarán ${resumenPunto(punto!)}.',
                  ),
                Row(
                  children: [
                    if (widget.puedeQuitar)
                      TextButton.icon(
                        onPressed: () => Navigator.pop(context, (null, true)),
                        icon: const Icon(AppIcons.eliminar, size: 18),
                        label: const Text('Quitar'),
                      ),
                    const Spacer(),
                    FilledButton.icon(
                      key: const ValueKey('temp-punto-guardar'),
                      onPressed: problema == null
                          ? () => Navigator.pop(context, (punto, false))
                          : null,
                      icon: const Icon(AppIcons.listo, size: 18),
                      label: const Text('Guardar punto'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
