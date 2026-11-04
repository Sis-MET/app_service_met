import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Offset;

import 'package:service_met/screens/calibracion/utils/needle_reader.dart';
import 'package:service_met/screens/calibracion/utils/seven_segment_reader.dart';

/// Un termómetro de dial dibujado para las pruebas del lector de aguja: cara
/// clara, rayas cada división, números en las rayas mayores, el rótulo de la
/// unidad bajo el eje, la aguja afinada hacia la punta con su cola ancha y
/// el eje con su brillo.
///
/// La escala va de [min] a [max] en [sweep] grados a partir de [start]
/// (grados desde las 12, en sentido horario; con [clockwise] en false sube
/// al revés). [scale] es el radio de la escala en píxeles; la imagen es un
/// cuadrado de [size] con el eje en [center] (por defecto, al medio).
class DialSpec {
  const DialSpec({
    this.size = 420,
    this.scale = 180,
    this.min = 0,
    this.max = 160,
    this.start = -135,
    this.sweep = 270,
    this.clockwise = true,
    this.center,
  });

  final int size;
  final double scale;
  final double min, max, start, sweep;
  final bool clockwise;
  final Offset? center;

  Offset get axis => center ?? Offset(size / 2, size / 2);

  /// Grados desde las 12 (horario) donde la escala marca [value].
  double degreesOf(double value) {
    final q = (value - min) / (max - min);
    return start + (clockwise ? 1 : -1) * q * sweep;
  }

  /// El punto de la escala con [value], a [radius] del eje.
  Offset pointAt(double value, [double? radius]) {
    final a = degreesOf(value) * math.pi / 180;
    final r = radius ?? scale;
    return axis + Offset(r * math.sin(a), -r * math.cos(a));
  }

  /// Las marcas que pondría el técnico (inicio, medio y fin), en fracciones
  /// de la imagen, con el eje corrido [centerError] píxeles.
  DialScale dial({Offset centerError = Offset.zero, List<double>? values}) {
    final marks = values ?? [min, (min + max) / 2, max];
    Offset fraction(Offset p) => Offset(p.dx / size, p.dy / size);
    return DialScale(
      center: fraction(axis + centerError),
      marks: [for (final v in marks) DialMark(fraction(pointAt(v)), v)],
    );
  }
}

GrayImage renderDial(
  DialSpec spec, {
  double? value,
  bool darkFace = false,
  double noise = 0,
  double shade = 0,
  bool glare = false,
  bool tail = true,
  bool numbers = true,
}) {
  final n = spec.size;
  final r = spec.scale;
  final axis = spec.axis;
  final faceRadius = r * 1.12;
  final span = spec.max - spec.min;
  final minorStep = span / 80, majorStep = span / 8;

  // La aguja, en coordenadas propias: a lo largo y de través.
  final needleDeg = value == null ? null : spec.degreesOf(value);
  final needleDir = needleDeg == null
      ? Offset.zero
      : Offset(math.sin(needleDeg * math.pi / 180),
          -math.cos(needleDeg * math.pi / 180));

  // Los números: un recuadro hueco por cifra, centrados a 0,7 del radio.
  final labels = <(Offset, int)>[];
  if (numbers) {
    for (var k = 0; k <= 8; k++) {
      final v = spec.min + k * majorStep;
      final digits = v.abs().round().toString().length;
      labels.add((spec.pointAt(v, r * 0.7), digits));
    }
  }

  bool inBox(Offset p, Offset c, double w, double h, double stroke) {
    final dx = (p.dx - c.dx).abs(), dy = (p.dy - c.dy).abs();
    if (dx > w / 2 || dy > h / 2) return false;
    return dx > w / 2 - stroke || dy > h / 2 - stroke;
  }

  double ink(Offset p) {
    final d = p - axis;
    final dist = d.distance;
    if (dist > faceRadius * 1.08) return 0.35; // fondo detrás del equipo
    if (dist > faceRadius) return 0.85; // bisel
    // Eje.
    if (dist < r * 0.02) return 0.1;
    if (dist < r * 0.07) return 0.6;
    if (needleDeg != null) {
      final along = d.dx * needleDir.dx + d.dy * needleDir.dy;
      final across = (d.dx * needleDir.dy - d.dy * needleDir.dx).abs();
      if (along >= 0 && along <= r * 0.9) {
        final width = r * (0.03 - 0.022 * along / (r * 0.9));
        if (across <= width / 2) return 0.92;
      }
      if (tail && along < 0 && along >= -r * 0.45) {
        final width = r * 0.11 * (1 - 0.5 * (-along) / (r * 0.45));
        if (across <= width / 2) return 0.92;
      }
    }
    // Rayas de la escala.
    if (dist >= r * 0.86 && dist <= r * 1.0) {
      final deg = math.atan2(d.dx, -d.dy) * 180 / math.pi;
      final delta = ((deg - spec.start) * (spec.clockwise ? 1 : -1)) % 360;
      final v = spec.min + delta / spec.sweep * span;
      if (v <= spec.max + minorStep / 2) {
        final k = ((v - spec.min) / minorStep).round();
        final nearest = spec.min + k * minorStep;
        final angleGap = (v - nearest) / span * spec.sweep * math.pi / 180;
        final major = k % 10 == 0;
        final width = major ? r * 0.016 : r * 0.008;
        final inner = major ? r * 0.82 : r * 0.88;
        if (dist >= inner && (dist * math.sin(angleGap)).abs() <= width / 2) {
          return 0.9;
        }
      }
    }
    // Números y unidad.
    if (dist > r * 0.55 && dist < r * 0.85) {
      for (final (c, digits) in labels) {
        final w = r * 0.075, h = r * 0.12;
        for (var i = 0; i < digits; i++) {
          final x = c.dx + (i - (digits - 1) / 2) * w * 1.15;
          if (inBox(p, Offset(x, c.dy), w, h, r * 0.016)) return 0.9;
        }
      }
    }
    if (inBox(p, axis + Offset(0, r * 0.32), r * 0.14, r * 0.1, r * 0.018)) {
      return 0.9;
    }
    return 0;
  }

  final random = math.Random(7);
  final pixels = Uint8List(n * n);
  for (var y = 0; y < n; y++) {
    for (var x = 0; x < n; x++) {
      // 2 × 2 muestras por píxel: bordes suaves, como en la cámara.
      var dark = 0.0;
      for (final (sx, sy) in const [
        (0.25, 0.25),
        (0.75, 0.25),
        (0.25, 0.75),
        (0.75, 0.75)
      ]) {
        dark += ink(Offset(x + sx, y + sy));
      }
      dark /= 4;
      final face = darkFace ? 30.0 : 236.0;
      final inkTone = darkFace ? 230.0 : 25.0;
      var tone = face + (inkTone - face) * dark;
      // Luz despareja: más oscuro hacia la derecha.
      if (shade > 0) tone *= 1 - shade * x / n;
      if (glare) {
        final g =
            Offset((x - n * 0.62) / (n * 0.12), (y - n * 0.4) / (n * 0.06));
        if (g.distance < 1) tone = tone + (255 - tone) * (1 - g.distance) * 0.8;
      }
      if (noise > 0) tone += (random.nextDouble() * 2 - 1) * noise;
      pixels[y * n + x] = tone.round().clamp(0, 255);
    }
  }
  return GrayImage(n, n, pixels);
}
