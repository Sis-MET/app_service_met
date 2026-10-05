import 'package:flutter/widgets.dart';

/// Íconos de la barra inferior, dibujados a medida: trazo fino con puntas y
/// uniones redondeadas sobre una grilla de 24 × 24.
enum NavIcono { inicio, servicios, precarga, otros }

class NavIcon extends StatelessWidget {
  final NavIcono icono;
  final Color color;
  final double size;

  const NavIcon(
    this.icono, {
    super.key,
    required this.color,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _NavIconPainter(icono, color)),
      );
}

class _NavIconPainter extends CustomPainter {
  final NavIcono icono;
  final Color color;

  _NavIconPainter(this.icono, this.color);

  static const _trazo = 1.7;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _trazo
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (icono) {
      case NavIcono.inicio:
        _casa(canvas, paint);
      case NavIcono.servicios:
        _balanza(canvas, paint);
      case NavIcono.precarga:
        _descarga(canvas, paint);
      case NavIcono.otros:
        _categorias(canvas, paint);
    }
  }

  /// Casa de esquinas suaves con una puerta como un guion.
  void _casa(Canvas canvas, Paint paint) {
    final casa = Path()
      ..moveTo(4, 11.2)
      ..lineTo(4, 17.5)
      ..quadraticBezierTo(4, 20.5, 7, 20.5)
      ..lineTo(17, 20.5)
      ..quadraticBezierTo(20, 20.5, 20, 17.5)
      ..lineTo(20, 11.2)
      ..quadraticBezierTo(20, 10, 19.1, 9.3)
      ..lineTo(13.3, 4.4)
      ..quadraticBezierTo(12, 3.3, 10.7, 4.4)
      ..lineTo(4.9, 9.3)
      ..quadraticBezierTo(4, 10, 4, 11.2)
      ..close();
    canvas.drawPath(casa, paint);
    canvas.drawLine(const Offset(10, 16.2), const Offset(14, 16.2), paint);
  }

  /// Balanza: plato, columna y cuerpo con el dial.
  void _balanza(Canvas canvas, Paint paint) {
    canvas.drawLine(const Offset(6.5, 4), const Offset(17.5, 4), paint);
    canvas.drawLine(const Offset(12, 4), const Offset(12, 7.5), paint);
    canvas.drawRRect(
      RRect.fromLTRBR(4, 7.5, 20, 20.5, const Radius.circular(3.5)),
      paint,
    );
    canvas.drawCircle(const Offset(12, 14), 3.4, paint);
    canvas.drawLine(const Offset(12, 14), const Offset(13.7, 12.3), paint);
  }

  /// Flecha que baja a una bandeja.
  void _descarga(Canvas canvas, Paint paint) {
    canvas.drawLine(const Offset(12, 3.5), const Offset(12, 14), paint);
    canvas.drawPath(
      Path()
        ..moveTo(8, 10)
        ..lineTo(12, 14)
        ..lineTo(16, 10),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(4, 14)
        ..lineTo(4, 17.5)
        ..quadraticBezierTo(4, 20.5, 7, 20.5)
        ..lineTo(17, 20.5)
        ..quadraticBezierTo(20, 20.5, 20, 17.5)
        ..lineTo(20, 14),
      paint,
    );
  }

  /// Tres cuadros y un círculo: "lo demás".
  void _categorias(Canvas canvas, Paint paint) {
    const r = Radius.circular(2.4);
    canvas.drawRRect(RRect.fromLTRBR(3.5, 3.5, 10.5, 10.5, r), paint);
    canvas.drawRRect(RRect.fromLTRBR(13.5, 3.5, 20.5, 10.5, r), paint);
    canvas.drawRRect(RRect.fromLTRBR(3.5, 13.5, 10.5, 20.5, r), paint);
    canvas.drawCircle(const Offset(17, 17), 3.5, paint);
  }

  @override
  bool shouldRepaint(_NavIconPainter oldDelegate) =>
      oldDelegate.icono != icono || oldDelegate.color != color;
}
