import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_icons.dart';
import '../../../widgets/service_ui/calibracion_ui.dart';
import '../models/temperatura_models.dart';
import '../services/temperatura_resultados.dart';
import 'temp_grafico.dart';
import 'temp_ui.dart';

(Color, IconData) estiloPunto(EstadoPunto estado) => switch (estado) {
      EstadoPunto.pendiente => (AppColors.shimmerGold, AppIcons.espera),
      EstadoPunto.enCurso => (AppColors.actionPositive, AppIcons.hora),
      EstadoPunto.completo => (AppColors.actionPositive, AppIcons.completo),
      EstadoPunto.interrumpido => (
          AppColors.actionNegative,
          AppIcons.advertencia
        ),
    };

/// Un punto con sus resultados preliminares, su gráfico y sus acciones, en
/// el panel de los formularios de Calibración.
class ResumenPuntoCard extends StatelessWidget {
  const ResumenPuntoCard({
    super.key,
    required this.punto,
    required this.canales,
    required this.lecturas,
    required this.unidad,
    this.acciones = const [],
  });

  final TempPunto punto;
  final List<TempCanal> canales;
  final List<TempLectura> lecturas;
  final String unidad;
  final List<Widget> acciones;

  String _n(double? v, [int decimales = 2]) =>
      v == null ? '—' : '${v.toStringAsFixed(decimales)} $unidad';

  @override
  Widget build(BuildContext context) {
    final isDark = CalUi.dark(context);
    final leidos = canales.where((c) => c.metodo.seLee).toList();
    final sensores = canales.where((c) => !c.metodo.seLee).length;
    final delPunto = lecturas.where((l) => l.nPunto == punto.n).toList();
    final resumen = TemperaturaResultados.punto(punto, canales, delPunto);
    final (color, icon) = estiloPunto(punto.estado);
    final tomadas = delPunto.map((l) => l.nLectura).toSet().length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: CalPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
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
                      Text('${textoNumero(punto.temperaturaNominal)} $unidad',
                          style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: CalUi.texto(isDark))),
                      Text(
                        '$tomadas de ${punto.lecturas} lecturas · cada '
                        '${punto.intervaloS} s',
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            color: isDark ? Colors.white54 : Colors.black45),
                      ),
                    ],
                  ),
                ),
                TempEstado(punto.estado.etiqueta, color: color, icon: icon),
              ],
            ),
            if (punto.motivoInterrupcion != null) ...[
              const SizedBox(height: 12),
              TempAviso.error('Detenido: ${punto.motivoInterrupcion}'),
            ],
            if (punto.estado != EstadoPunto.pendiente) ...[
              const SizedBox(height: 14),
              TempGrafico(
                canales: leidos,
                lecturas: delPunto,
                nominal: punto.temperaturaNominal,
              ),
              const SizedBox(height: 14),
              for (final c in resumen.canales) ...[
                CalSummaryRow('Promedio', _n(c.promedio, c.canal.decimales + 2),
                    labelWidth: 130),
                const SizedBox(height: 6),
                CalSummaryRow(
                    'Mín · máx',
                    c.minimo == null
                        ? null
                        : '${c.minimo!.toStringAsFixed(c.canal.decimales)} · '
                            '${c.maximo!.toStringAsFixed(c.canal.decimales)} $unidad',
                    labelWidth: 130),
                const SizedBox(height: 6),
                CalSummaryRow('Variación', _n(c.variacion, c.canal.decimales),
                    labelWidth: 130),
                const SizedBox(height: 6),
                CalSummaryRow('Desv. estándar',
                    c.desviacion?.toStringAsFixed(c.canal.decimales + 2),
                    labelWidth: 130),
                const SizedBox(height: 6),
                CalSummaryRow('Lecturas válidas', '${c.validas}',
                    labelWidth: 130),
                const SizedBox(height: 6),
              ],
              if (resumen.patron != null) ...[
                CalSummaryRow('Patrón', _n(resumen.patron, 3), labelWidth: 130),
                const SizedBox(height: 6),
              ],
              for (final e in resumen.errores.entries) ...[
                CalSummaryRow('Error de indicación',
                    '${e.value >= 0 ? '+' : ''}${_n(e.value, 3)}',
                    labelWidth: 130),
                const SizedBox(height: 6),
              ],
              if (resumen.sinLectura > 0 || resumen.excluidas > 0) ...[
                CalSummaryRow(
                  'No cuentan',
                  [
                    if (resumen.sinLectura > 0)
                      '${resumen.sinLectura} sin lectura',
                    if (resumen.excluidas > 0) '${resumen.excluidas} excluidas',
                  ].join(' · '),
                  labelWidth: 130,
                ),
                const SizedBox(height: 6),
              ],
              const SizedBox(height: 6),
              Text(
                sensores > 0
                    ? 'Resumen preliminar del indicador. Los $sensores '
                        'sensores del patrón graban en su software: el error '
                        'y la incertidumbre se calculan con esos datos.'
                    : 'Resumen preliminar: sin correcciones del certificado '
                        'ni incertidumbre.',
                style: GoogleFonts.inter(
                    fontSize: 11.5,
                    height: 1.4,
                    color: isDark ? Colors.white54 : Colors.black45),
              ),
            ],
            if (acciones.isNotEmpty) ...[
              const SizedBox(height: 14),
              Wrap(spacing: 8, runSpacing: 8, children: acciones),
            ],
          ],
        ),
      ),
    );
  }
}
