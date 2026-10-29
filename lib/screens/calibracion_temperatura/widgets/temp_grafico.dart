import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/app_colors.dart';
import '../models/temperatura_models.dart';

/// Colores de los canales, de la paleta del proyecto: verdes y amarillos
/// para los sensores del patrón, dorado para el indicador del equipo.
Color colorCanal(TempCanal canal, List<TempCanal> canales) {
  if (canal.rol == RolCanal.equipo) return AppColors.shimmerGold;
  const patron = [
    AppColors.actionPositive,
    AppColors.accentYellow,
    Color(0xFF5C8A2E),
    Color(0xFFB9D98F),
    Color(0xFF9C8A1E),
  ];
  final indice =
      canales.where((c) => c.rol == RolCanal.patron).toList().indexOf(canal);
  return patron[math.max(0, indice) % patron.length];
}

/// Las lecturas de un punto en el tiempo, una línea por canal, con la
/// temperatura nominal punteada. Las lecturas sin valor dejan un hueco.
class TempGrafico extends StatelessWidget {
  const TempGrafico({
    super.key,
    required this.canales,
    required this.lecturas,
    this.nominal,
    this.height = 160,
    this.oscuro = false,
  });

  final List<TempCanal> canales;
  final List<TempLectura> lecturas;
  final double? nominal;
  final double height;

  /// Sobre la cámara (fondo negro).
  final bool oscuro;

  @override
  Widget build(BuildContext context) {
    final isDark = oscuro || Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: height,
          child: CustomPaint(
            painter: _GraficoPainter(
              canales: canales,
              lecturas: lecturas,
              nominal: nominal,
              tinta: isDark ? Colors.white70 : AppColors.textSecondaryLight,
              rejilla: isDark ? Colors.white12 : Colors.black12,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            for (final canal in canales)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colorCanal(canal, canales),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    canal.nombre,
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      color: isDark ? Colors.white70 : null,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

class _GraficoPainter extends CustomPainter {
  _GraficoPainter({
    required this.canales,
    required this.lecturas,
    required this.nominal,
    required this.tinta,
    required this.rejilla,
  });

  final List<TempCanal> canales;
  final List<TempLectura> lecturas;
  final double? nominal;
  final Color tinta;
  final Color rejilla;

  @override
  void paint(Canvas canvas, Size size) {
    final validas = lecturas.where((l) => l.cuenta).toList();
    final valores = [
      for (final l in validas) l.valor!,
      if (nominal != null) nominal!,
    ];
    const izquierda = 44.0, abajo = 18.0;
    final area =
        Rect.fromLTRB(izquierda, 6, size.width - 6, size.height - abajo);
    final texto = GoogleFonts.inter(color: tinta, fontSize: 10);

    if (valores.isEmpty || area.width <= 0 || area.height <= 0) {
      final painter = TextPainter(
        text: TextSpan(text: 'Sin lecturas todavía', style: texto),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(
          canvas, size.center(Offset(-painter.width / 2, -painter.height / 2)));
      return;
    }
    var minimo = valores.reduce(math.min), maximo = valores.reduce(math.max);
    if (maximo - minimo < 1) {
      final medio = (maximo + minimo) / 2;
      minimo = medio - 0.5;
      maximo = medio + 0.5;
    }
    final margen = (maximo - minimo) * 0.08;
    minimo -= margen;
    maximo += margen;
    final ultima = lecturas.fold<int>(1, (a, l) => math.max(a, l.nLectura));
    double x(int n) => area.left + area.width * n / ultima;
    double y(double v) =>
        area.bottom - area.height * (v - minimo) / (maximo - minimo);

    final lineaRejilla = Paint()
      ..color = rejilla
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final v = minimo + (maximo - minimo) * i / 3;
      final yy = y(v);
      canvas.drawLine(
          Offset(area.left, yy), Offset(area.right, yy), lineaRejilla);
      final painter = TextPainter(
        text: TextSpan(text: v.toStringAsFixed(1), style: texto),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(canvas,
          Offset(area.left - painter.width - 6, yy - painter.height / 2));
    }

    if (nominal != null) {
      final paint = Paint()
        ..color = tinta
        ..strokeWidth = 1;
      final yy = y(nominal!);
      for (var xx = area.left; xx < area.right; xx += 8) {
        canvas.drawLine(
            Offset(xx, yy), Offset(math.min(xx + 4, area.right), yy), paint);
      }
    }

    for (final canal in canales) {
      final puntos = validas.where((l) => l.nCanal == canal.n).toList()
        ..sort((a, b) => a.nLectura.compareTo(b.nLectura));
      if (puntos.isEmpty) continue;
      final paint = Paint()
        ..color = colorCanal(canal, canales)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round;
      final path = Path();
      int? anterior;
      for (final l in puntos) {
        final punto = Offset(x(l.nLectura), y(l.valor!));
        // Un hueco donde faltó una lectura.
        if (anterior == null || l.nLectura != anterior + 1) {
          path.moveTo(punto.dx, punto.dy);
        } else {
          path.lineTo(punto.dx, punto.dy);
        }
        anterior = l.nLectura;
      }
      canvas.drawPath(path, paint);
      if (puntos.length == 1) {
        canvas.drawCircle(
            Offset(x(puntos.first.nLectura), y(puntos.first.valor!)),
            3,
            Paint()..color = paint.color);
      }
    }

    final etiqueta = TextPainter(
      text: TextSpan(text: 'Lectura $ultima', style: texto),
      textDirection: TextDirection.ltr,
    )..layout();
    etiqueta.paint(
        canvas, Offset(area.right - etiqueta.width, area.bottom + 4));
  }

  @override
  bool shouldRepaint(_GraficoPainter old) =>
      !identical(old.lecturas, lecturas) ||
      !identical(old.canales, canales) ||
      old.nominal != nominal ||
      old.tinta != tinta;
}
