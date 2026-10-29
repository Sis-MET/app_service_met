import 'dart:math' as math;
import 'dart:typed_data';

import 'package:service_met/screens/calibracion/utils/seven_segment_reader.dart';

/// Segmentos encendidos de cada carácter: a, b, c, d, e, f, g.
const _segments = {
  '0': 'abcdef',
  '1': 'bc',
  '2': 'abdeg',
  '3': 'abcdg',
  '4': 'bcfg',
  '5': 'acdfg',
  '6': 'acdefg',
  '7': 'abc',
  '8': 'abcdefg',
  '9': 'abcdfg',
  '-': 'g',
  ' ': '',
  // Letras de los displays de temperatura.
  'C': 'adef',
  'F': 'aefg',
  'E': 'adefg',
  'H': 'bcefg',
  'L': 'def',
  'P': 'abefg',
};

typedef _Point = (double, double);

/// Dibuja [text] como un display de 7 segmentos: dígitos, '.', '-' y ' '.
///
/// Cada segmento es un hexágono con puntas, separado de sus vecinos por
/// [gap] (en fracciones del alto), como en los displays reales. [slant] es la
/// itálica del display y [rotate] el giro de la foto, en grados. Con [ink]
/// y [background] se elige un LED o VFD (claro sobre oscuro) o un LCD.
GrayImage renderSevenSegment(
  String text, {
  int height = 60,
  double width = 0.55,
  double stroke = 0.12,
  double gap = 0.03,
  double spacing = 0.2,
  double slant = 0,
  double rotate = 0,
  int ink = 230,
  int background = 25,
  int margin = 40,
  int noise = 0,
  int seed = 1,
  List<(String, int, int, int)> extra = const [],
}) {
  final cells = text.replaceAll('.', '').length;
  final h = height.toDouble();
  final w = h * width;
  final pitch = w + h * spacing;
  final imageWidth = (margin * 2 + pitch * cells).ceil() & ~1;
  final imageHeight = (margin * 2 + h).ceil() & ~1;

  final polygons = <List<_Point>>[];
  _addText(polygons, text, margin.toDouble(), margin.toDouble(), h,
      width: width, stroke: stroke, gap: gap, spacing: spacing);
  for (final (label, x, y, size) in extra) {
    _addText(polygons, label, x.toDouble(), y.toDouble(), size.toDouble(),
        width: width, stroke: stroke, gap: gap, spacing: spacing);
  }

  // Itálica sobre la base de los dígitos; luego el giro de la foto.
  final baseline = margin + h;
  final tilt = math.tan(slant * math.pi / 180);
  final angle = rotate * math.pi / 180;
  final cx = imageWidth / 2, cy = imageHeight / 2;
  _Point transform(_Point p) {
    final x = p.$1 + tilt * (baseline - p.$2);
    final y = p.$2;
    return (
      cx + (x - cx) * math.cos(angle) + (y - cy) * math.sin(angle),
      cy - (x - cx) * math.sin(angle) + (y - cy) * math.cos(angle),
    );
  }

  final on = Uint8List(imageWidth * imageHeight);
  for (final polygon in polygons) {
    final points = polygon.map(transform).toList();
    final xs = points.map((p) => p.$1), ys = points.map((p) => p.$2);
    final x0 = math.max(0, xs.reduce(math.min).floor());
    final x1 = math.min(imageWidth - 1, xs.reduce(math.max).ceil());
    final y0 = math.max(0, ys.reduce(math.min).floor());
    final y1 = math.min(imageHeight - 1, ys.reduce(math.max).ceil());
    for (var y = y0; y <= y1; y++) {
      for (var x = x0; x <= x1; x++) {
        if (_inside(points, x + 0.5, y + 0.5)) on[y * imageWidth + x] = 1;
      }
    }
  }

  // Un poco de desenfoque, como el de la cámara, y ruido.
  final random = math.Random(seed);
  final pixels = Uint8List(on.length);

  for (var y = 0; y < imageHeight; y++) {
    for (var x = 0; x < imageWidth; x++) {
      var sum = 0, count = 0;
      for (var dy = -1; dy <= 1; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          final nx = x + dx, ny = y + dy;
          if (nx < 0 || ny < 0 || nx >= imageWidth || ny >= imageHeight) {
            continue;
          }
          sum += on[ny * imageWidth + nx];
          count++;
        }
      }
      final share = sum / count;
      final value = background + (ink - background) * share;
      final jitter = noise == 0 ? 0 : random.nextInt(noise * 2 + 1) - noise;
      pixels[y * imageWidth + x] = (value + jitter).round().clamp(0, 255);
    }
  }
  return GrayImage(imageWidth, imageHeight, pixels);
}

void _addText(
  List<List<_Point>> polygons,
  String text,
  double left,
  double top,
  double h, {
  required double width,
  required double stroke,
  required double gap,
  required double spacing,
}) {
  final w = h * width, s = h * stroke, g = h * gap;
  final pitch = w + h * spacing;
  var x = left;
  for (final char in text.split('')) {
    if (char == '.') {
      // El punto, más chico que un segmento, en la base y al medio del
      // hueco tras el dígito anterior.
      final size = s * 0.6;
      final px = x - h * spacing / 2 - size / 2;
      polygons.add(_rect(px, top + h - size, size, size));
      continue;
    }
    final lit = _segments[char];
    if (lit == null) throw ArgumentError('Sin segmentos para "$char"');
    // Líneas centrales del contorno del dígito.
    final l = x + s / 2, r = x + w - s / 2;
    final t = top + s / 2, m = top + h / 2, b = top + h - s / 2;
    final lines = {
      'a': ((l, t), (r, t)),
      'b': ((r, t), (r, m)),
      'c': ((r, m), (r, b)),
      'd': ((l, b), (r, b)),
      'e': ((l, m), (l, b)),
      'f': ((l, t), (l, m)),
      'g': ((l, m), (r, m)),
    };
    for (final segment in lit.split('')) {
      final (from, to) = lines[segment]!;
      polygons.add(_segment(from, to, s, g));
    }
    x += pitch;
  }
}

/// Un segmento de [from] a [to] con puntas a 45°, recortado [gap] en cada
/// extremo.
List<_Point> _segment(_Point from, _Point to, double s, double gap) {
  final horizontal = from.$2 == to.$2;
  final half = s / 2;
  if (horizontal) {
    final x0 = from.$1 + gap, x1 = to.$1 - gap, y = from.$2;
    return [
      (x0, y),
      (x0 + half, y - half),
      (x1 - half, y - half),
      (x1, y),
      (x1 - half, y + half),
      (x0 + half, y + half),
    ];
  }
  final y0 = from.$2 + gap, y1 = to.$2 - gap, x = from.$1;
  return [
    (x, y0),
    (x + half, y0 + half),
    (x + half, y1 - half),
    (x, y1),
    (x - half, y1 - half),
    (x - half, y0 + half),
  ];
}

List<_Point> _rect(double x, double y, double w, double h) =>
    [(x, y), (x + w, y), (x + w, y + h), (x, y + h)];

bool _inside(List<_Point> polygon, double x, double y) {
  var inside = false;
  for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
    final (xi, yi) = polygon[i];
    final (xj, yj) = polygon[j];
    if ((yi > y) != (yj > y) && x < (xj - xi) * (y - yi) / (yj - yi) + xi) {
      inside = !inside;
    }
  }
  return inside;
}
