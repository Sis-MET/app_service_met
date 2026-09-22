import 'dart:math' as math;
import 'dart:typed_data';

/// Una imagen en grises (la luminancia del cuadro de la cámara), fila por
/// fila.
class GrayImage {
  GrayImage(this.width, this.height, this.pixels)
      : assert(pixels.length == width * height);

  final int width;
  final int height;
  final Uint8List pixels;
}

/// Lo que se leyó en un display de 7 segmentos.
class SegmentReading {
  const SegmentReading({
    required this.digits,
    required this.pointAfter,
    required this.negative,
    required this.height,
  });

  /// Los dígitos de izquierda a derecha, sin punto: "400001".
  final String digits;

  /// Cuántos dígitos hay antes del punto decimal, si se vio el punto.
  final int? pointAfter;

  final bool negative;

  /// Alto de los dígitos en píxeles.
  final double height;

  @override
  String toString() {
    final point = pointAfter;
    final body = point == null
        ? digits
        : '${digits.substring(0, point)}.${digits.substring(point)}';
    return '${negative ? '-' : ''}$body';
  }
}

/// Lee displays de 7 segmentos (LED, VFD, LCD) mirando qué segmentos de cada
/// dígito están encendidos.
///
/// El OCR de texto aprendió letras de imprenta: en estos displays el 4 le
/// parece una Y, y un 1 (dos trazos sueltos) o el punto (un puntito) los
/// pierde. Aquí se arma cada dígito con sus segmentos y se decodifica por
/// la posición de los segmentos encendidos. Si algún carácter de la fila no
/// calza con un dígito de 7 segmentos, no se lee nada: la letra de imprenta
/// de otras pantallas queda para el OCR.
abstract final class SevenSegmentReader {
  static SegmentReading? read(GrayImage image) {
    if (image.width < 16 || image.height < 16) return null;
    SegmentReading? best;
    // Dígitos claros sobre fondo oscuro (LED, VFD) u oscuros sobre claro
    // (LCD): se prueban los dos.
    for (final brightInk in const [true, false]) {
      var pass = _Pass(image, brightInk: brightInk);
      if (pass.crowded) continue;
      // Con itálica, la parte de arriba de un dígito queda encima de la de
      // abajo del siguiente y se confunden: primero se endereza.
      final tilt = pass.tilt();
      if (tilt != null && tilt.abs() > 0.04) {
        pass = _Pass(_straighten(image, tilt), brightInk: brightInk);
      }
      final reading = pass.read();
      if (reading != null && _better(reading, best)) best = reading;
    }
    return best;
  }

  /// Corre cada fila para que lo inclinado [tilt] quede vertical.
  static GrayImage _straighten(GrayImage image, double tilt) {
    final w = image.width, h = image.height, source = image.pixels;
    final pixels = Uint8List(w * h);
    final middle = h / 2;
    for (var y = 0; y < h; y++) {
      final shift = tilt * (y - middle);
      for (var x = 0; x < w; x++) {
        final from = (x - shift).clamp(0.0, w - 1.0);
        final x0 = from.floor(), x1 = math.min(x0 + 1, w - 1);
        final t = from - x0;
        pixels[y * w + x] =
            (source[y * w + x0] * (1 - t) + source[y * w + x1] * t).round();
      }
    }
    return GrayImage(w, h, pixels);
  }

  /// Más dígitos y, a igual cantidad, más grandes: el display y no un
  /// rótulo.
  static bool _better(SegmentReading reading, SegmentReading? than) =>
      than == null ||
      reading.digits.length > than.digits.length ||
      (reading.digits.length == than.digits.length &&
          reading.height > than.height);
}

/// Segmentos en bits: a arriba, b arriba a la derecha, c abajo a la
/// derecha, d abajo, e abajo a la izquierda, f arriba a la izquierda, g al
/// medio.
const _a = 1, _b = 2, _c = 4, _d = 8, _e = 16, _f = 32, _g = 64;

const _patterns = {
  _a | _b | _c | _d | _e | _f: '0',
  _a | _b | _d | _e | _g: '2',
  _a | _b | _c | _d | _g: '3',
  _b | _c | _f | _g: '4',
  _a | _c | _d | _f | _g: '5',
  _a | _c | _d | _e | _f | _g: '6',
  _c | _d | _e | _f | _g: '6',
  _a | _b | _c: '7',
  _a | _b | _c | _f: '7',
  _a | _b | _c | _d | _e | _f | _g: '8',
  _a | _b | _c | _d | _f | _g: '9',
  _a | _b | _c | _f | _g: '9',
};

/// Inclinaciones que se prueban (desplazamiento horizontal por unidad de
/// alto): derecho, itálica de unos 5° y 10°, y 5° al revés. Muchos LCD van en
/// itálica, y la foto suma su propia inclinación.
const _shears = [0.0, 0.09, 0.18, -0.09];

class _Box {
  _Box(this.left, this.top, this.right, this.bottom);

  /// Bordes incluidos.
  int left, top, right, bottom;

  int get width => right - left + 1;
  int get height => bottom - top + 1;
  int get size => math.max(width, height);
  double get centerX => (left + right) / 2;
  double get centerY => (top + bottom) / 2;

  void add(_Box other) {
    left = math.min(left, other.left);
    top = math.min(top, other.top);
    right = math.max(right, other.right);
    bottom = math.max(bottom, other.bottom);
  }
}

/// Una mancha de tinta conectada: un segmento, un dígito entero si el
/// display no muestra cortes, el punto, o ruido.
class _Part {
  _Part(this.label, this.box, this.area, {required this.touchesEdge});

  final int label;
  final _Box box;
  final int area;
  final bool touchesEdge;
}

/// Un carácter armado con sus manchas.
class _Glyph {
  _Glyph(_Part part)
      : box =
            _Box(part.box.left, part.box.top, part.box.right, part.box.bottom),
        labels = {part.label},
        area = part.area;

  final _Box box;
  final Set<int> labels;
  int area;

  void add(_Part part) {
    box.add(part.box);
    labels.add(part.label);
    area += part.area;
  }

  void merge(_Glyph other) {
    box.add(other.box);
    labels.addAll(other.labels);
    area += other.area;
  }
}

/// Una recta y = a + b·x.
class _Line {
  const _Line(this.a, this.b);

  final double a;
  final double b;

  double at(double x) => a + b * x;

  /// Mínimos cuadrados; con todos los puntos en la misma x, horizontal.
  static _Line fit(List<double> xs, List<double> ys) {
    final n = xs.length;
    final mx = xs.reduce((p, q) => p + q) / n;
    final my = ys.reduce((p, q) => p + q) / n;
    var sxx = 0.0, sxy = 0.0;
    for (var i = 0; i < n; i++) {
      sxx += (xs[i] - mx) * (xs[i] - mx);
      sxy += (xs[i] - mx) * (ys[i] - my);
    }
    final slope = sxx == 0 ? 0.0 : sxy / sxx;
    return _Line(my - slope * mx, slope);
  }
}

/// La casilla de un dígito: de arriba abajo (v de 0 a 1) y de izquierda a
/// derecha (u de 0 a 1), con la itálica descontada.
class _Cell {
  _Cell(this.glyph, this.top, this.height, this.shear)
      : width = glyph.box.width - shear.abs() * height;

  final _Glyph glyph;
  final double top;
  final double height;
  final double shear;

  /// Ancho del dígito sin la itálica.
  final double width;

  double left(double v) => shear >= 0
      ? glyph.box.left + shear * (1 - v) * height
      : glyph.box.left - shear * v * height;

  int x(double u, double v) => (left(v) + u * width).round();
  int y(double v) => (top + v * height).round();
  double v(int y) => (y - top) / height;
}

class _Pass {
  _Pass(this.image, {required this.brightInk}) {
    _mask();
    _label();
  }

  final GrayImage image;
  final bool brightInk;

  late final Uint8List _ink;
  late final int _margin;
  late final Int32List _labels;
  final _parts = <_Part>[];

  /// Cuántas manchas de tinta puede tener una franja con un display: más
  /// que esto es ruido (una superficie con textura, muy poca luz) y no hay
  /// nada que leer.
  static const _crowd = 2500;

  /// Un cuadro lleno de manchas: no se analiza, que cuesta caro y no es un
  /// display.
  bool get crowded => _parts.length > _crowd;

  int get _w => image.width;
  int get _h => image.height;

  /// Alto mínimo de un dígito del display: lo más chico son rótulos y
  /// letras del logo.
  double get _minHeight => math.max(16, _h * 0.05);

  SegmentReading? read() {
    final glyphs = _assemble();
    SegmentReading? best;
    final tall = [
      for (final glyph in glyphs)
        if (glyph.box.height >= _minHeight &&
            glyph.box.height >= glyph.box.width)
          glyph,
    ]..sort((a, b) => a.box.left.compareTo(b.box.left));
    for (final row in _rows(tall)) {
      final reading = _readRow(row, glyphs);
      if (reading != null && SevenSegmentReader._better(reading, best)) {
        best = reading;
      }
    }
    return best;
  }

  /// Tinta: lo que se aparta del promedio de su vecindario hacia el lado de
  /// los dígitos. Con el promedio local, un reflejo o una sombra sobre el
  /// display no se come los segmentos. El margen sale del contraste de la
  /// imagen, para que el grano de la cámara no cuente como tinta. No se
  /// suaviza antes: en un VFD los dígitos y el punto están a pocos píxeles
  /// y se pegarían.
  void _mask() {
    final w = _w, h = _h, pixels = image.pixels;
    final stride = w + 1;
    final integral = Int32List(stride * (h + 1));
    for (var y = 0; y < h; y++) {
      var row = 0;
      for (var x = 0; x < w; x++) {
        row += pixels[y * w + x];
        integral[(y + 1) * stride + x + 1] = integral[y * stride + x + 1] + row;
      }
    }
    double mean(int x, int y, int radius) {
      final x0 = math.max(0, x - radius), x1 = math.min(w, x + radius + 1);
      final y0 = math.max(0, y - radius), y1 = math.min(h, y + radius + 1);
      final sum = integral[y1 * stride + x1] -
          integral[y0 * stride + x1] -
          integral[y1 * stride + x0] +
          integral[y0 * stride + x0];
      return sum / ((x1 - x0) * (y1 - y0));
    }

    // El contraste entre la tinta y el fondo, aunque los dígitos sean una
    // parte chica de la imagen.
    final histogram = Int32List(256);
    for (final value in pixels) {
      histogram[value]++;
    }
    final low = _percentile(histogram, pixels.length, 0.01);
    final high = _percentile(histogram, pixels.length, 0.99);
    _margin = math.max(12, ((high - low) * 0.12).round());

    final radius = math.max(4, h ~/ 8);
    _ink = Uint8List(w * h);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final value = pixels[y * w + x];
        final around = mean(x, y, radius);
        final ink =
            brightInk ? value > around + _margin : value < around - _margin;
        if (ink) _ink[y * w + x] = 1;
      }
    }
  }

  static int _percentile(Int32List histogram, int total, double fraction) {
    final target = total * fraction;
    var seen = 0;
    for (var value = 0; value < 256; value++) {
      seen += histogram[value];
      if (seen >= target) return value;
    }
    return 255;
  }

  void _label() {
    final w = _w, h = _h, ink = _ink;
    _labels = Int32List(w * h);
    final stack = Int32List(w * h);
    var next = 0;
    for (var start = 0; start < w * h; start++) {
      if (ink[start] == 0 || _labels[start] != 0) continue;
      next++;
      var left = w, top = h, right = -1, bottom = -1, area = 0;
      var sp = 0;
      stack[sp++] = start;
      _labels[start] = next;
      while (sp > 0) {
        final index = stack[--sp];
        final x = index % w, y = index ~/ w;
        area++;
        if (x < left) left = x;
        if (x > right) right = x;
        if (y < top) top = y;
        if (y > bottom) bottom = y;
        for (var dy = -1; dy <= 1; dy++) {
          final ny = y + dy;
          if (ny < 0 || ny >= h) continue;
          for (var dx = -1; dx <= 1; dx++) {
            final nx = x + dx;
            if (nx < 0 || nx >= w) continue;
            final neighbor = ny * w + nx;
            if (ink[neighbor] == 0 || _labels[neighbor] != 0) continue;
            _labels[neighbor] = next;
            stack[sp++] = neighbor;
          }
        }
      }
      _parts.add(_Part(
        next,
        _Box(left, top, right, bottom),
        area,
        touchesEdge: left == 0 || top == 0 || right == w - 1 || bottom == h - 1,
      ));
    }
  }

  /// La itálica del display (más el giro de la foto): la inclinación con la
  /// que los bordes de trazos verticales quedan más apilados en columnas.
  /// Null si hay muy poca tinta para decirlo.
  double? tilt() {
    final keep = Uint8List(_parts.length + 1);
    for (final part in _parts) {
      if (!part.touchesEdge &&
          part.area >= 3 &&
          part.box.height >= _minHeight * 0.3 &&
          part.box.height < _h * 0.8 &&
          part.box.width < _w * 0.35) {
        keep[part.label] = 1;
      }
    }
    final xs = <int>[], ys = <int>[];
    for (var y = 0; y < _h; y++) {
      for (var x = 0; x < _w; x++) {
        final label = _labels[y * _w + x];
        // Solo los bordes de trazos verticales aportan al ángulo. Las
        // barras horizontales sesgaban la proyección y deformaban el 2.
        if (label != 0 &&
            keep[label] == 1 &&
            y > 1 &&
            y < _h - 2 &&
            _labels[(y - 2) * _w + x] == label &&
            _labels[(y + 2) * _w + x] == label &&
            (x == 0 || _labels[y * _w + x - 1] != label)) {
          xs.add(x);
          ys.add(y);
        }
      }
    }
    if (xs.length < 20) return null;

    final middle = _h / 2;
    final reach = (_h * 0.3).ceil() + 1;
    final columns = Int32List(_w + reach * 2);
    var best = 0.0, bestScore = -1;
    for (var step = -4; step <= 10; step++) {
      final shear = step * 0.03;
      columns.fillRange(0, columns.length, 0);
      for (var i = 0; i < xs.length; i++) {
        columns[(xs[i] + shear * (ys[i] - middle)).round() + reach]++;
      }
      var score = 0;
      for (final count in columns) {
        score += count * count;
      }
      if (score > bestScore) {
        bestScore = score;
        best = shear;
      }
    }
    return best;
  }

  /// Junta los segmentos de cada dígito: comparten columnas (en las
  /// esquinas el horizontal se mete sobre el vertical) y están uno sobre
  /// otro. Dos dígitos vecinos no comparten columnas, por juntos que estén.
  /// Lo diminuto (el punto, polvo) no se pega a nada.
  List<_Glyph> _assemble() {
    // Un dígito nunca ocupa más de un tercio del ancho de la franja: lo más
    // grande es el marco del display, reflejos o la carcasa.
    final widest = _w * 0.35;
    final parts = [
      for (final part in _parts)
        if (!part.touchesEdge &&
            part.area >= 3 &&
            part.box.height < _h * 0.8 &&
            part.box.width < widest)
          part,
    ]..sort((a, b) => a.box.left.compareTo(b.box.left));

    final parent = List<int>.generate(parts.length, (i) => i);
    final boxes = [
      for (final part in parts)
        _Box(part.box.left, part.box.top, part.box.right, part.box.bottom),
    ];
    int find(int i) {
      while (parent[i] != i) {
        parent[i] = parent[parent[i]];
        i = parent[i];
      }
      return i;
    }

    // Ordenadas por su borde izquierdo, cada mancha solo puede juntarse con
    // las que empiezan antes de que ella termine.
    for (var i = 0; i < parts.length; i++) {
      final a = parts[i].box;
      final until = a.right + (_thickness(a) * 0.6).round();
      for (var j = i + 1; j < parts.length; j++) {
        final b = parts[j].box;
        if (b.left > until) break;
        if (math.min(a.size, b.size) < math.max(a.size, b.size) * 0.2) {
          continue;
        }
        // Con cortes anchos, la punta de un segmento suelto puede quedar a
        // un par de píxeles de la columna del vecino. Se tolera poco más de
        // medio grosor de trazo, y solo entre segmentos sueltos (alargados):
        // el espacio entre dígitos es mayor, y dos dígitos enteros no se
        // tocan.
        final sharedColumns =
            math.min(a.right, b.right) - math.max(a.left, b.left) + 1;
        final reach = _elongated(a) && _elongated(b)
            ? (math.min(_thickness(a), _thickness(b)) * 0.6).round()
            : 0;
        if (sharedColumns < 1 - reach) continue;
        final gapY = math.max(a.top, b.top) - math.min(a.bottom, b.bottom) - 1;
        if (gapY > math.max(a.height, b.height) * 0.35) continue;

        // Lo que se va armando tiene que poder ser un dígito: no más ancho
        // que el doble de su alto. Así una tira del marco no se traga los
        // dígitos de al lado.
        final ra = find(i), rb = find(j);
        if (ra == rb) continue;
        final union = _Box(
            boxes[ra].left, boxes[ra].top, boxes[ra].right, boxes[ra].bottom)
          ..add(boxes[rb]);
        if (union.width > widest || union.width > union.height * 2) continue;
        parent[ra] = rb;
        boxes[rb] = union;
      }
    }

    final byRoot = <int, _Glyph>{};
    for (var i = 0; i < parts.length; i++) {
      final root = find(i);
      final glyph = byRoot[root];
      if (glyph == null) {
        byRoot[root] = _Glyph(parts[i]);
      } else {
        glyph.add(parts[i]);
      }
    }
    final glyphs = byRoot.values.toList()
      ..sort((a, b) => a.box.left.compareTo(b.box.left));

    // Con cortes anchos o la foto girada, el segmento del medio puede no
    // alcanzar a unir las dos mitades de un dígito: se juntan la de arriba
    // y la de abajo si están una sobre otra, casi pegadas.
    final taken = <_Glyph>{};
    for (var i = 0; i < glyphs.length; i++) {
      final first = glyphs[i];
      if (taken.contains(first)) continue;
      for (var j = i + 1; j < glyphs.length; j++) {
        final second = glyphs[j];
        if (second.box.left > first.box.right) break;
        if (taken.contains(second)) continue;
        // Con la foto girada, la mitad de abajo puede empezar más a la
        // izquierda que la de arriba: la de arriba es la del centro más alto.
        final upper = first.box.centerY < second.box.centerY ? first : second;
        final lower = identical(upper, first) ? second : first;
        final a = upper.box, b = lower.box;
        final union = _Box(a.left, a.top, a.right, a.bottom)..add(b);
        if (union.width > widest || union.width > union.height * 0.9) continue;
        if (a.height > union.height * 0.7 || b.height > union.height * 0.7) {
          continue;
        }
        if (math.min(a.size, b.size) < union.height * 0.25) continue;
        final shared =
            math.min(a.right, b.right) - math.max(a.left, b.left) + 1;
        if (shared < math.min(a.width, b.width) * 0.5) continue;
        if (b.top - a.bottom - 1 > union.height * 0.2) continue;
        first.merge(second);
        taken.add(second);
      }
    }
    glyphs.removeWhere(taken.contains);
    return glyphs;
  }

  static int _thickness(_Box box) => math.min(box.width, box.height);

  /// Un segmento suelto (o un 1). Un dígito entero, como el 0 o el 8, mide
  /// a lo sumo el doble de alto que de ancho.
  static bool _elongated(_Box box) => box.size >= _thickness(box) * 2.2;

  /// Filas de dígitos: caracteres altos, de alto parecido, cada uno junto al
  /// anterior y a su altura. Se encadenan de a dos para seguir el display
  /// aunque la foto esté un poco girada.
  Iterable<List<_Glyph>> _rows(List<_Glyph> tall) sync* {
    final next = <_Glyph, _Glyph>{};
    final hasPrevious = <_Glyph>{};
    for (var i = 0; i < tall.length; i++) {
      final a = tall[i];
      // Vienen ordenados por su borde izquierdo: el siguiente de la fila no
      // puede estar más lejos de dos veces el alto de este.
      final until = a.box.right + a.box.height * 2;
      _Glyph? best;
      for (var j = i + 1; j < tall.length; j++) {
        final b = tall[j];
        if (b.box.left > until) break;
        if (b.box.left <= a.box.right) continue;
        // El 1, el 4 y el 7 no llegan arriba o abajo (les falta el segmento
        // a o el d): más bajos, pero dentro del alto de sus vecinos.
        final h = math.max(a.box.height, b.box.height);
        final shorter = math.min(a.box.height, b.box.height);
        if (shorter < h * 0.65) continue;
        final overlap = math.min(a.box.bottom, b.box.bottom) -
            math.max(a.box.top, b.box.top) +
            1;
        if (overlap < shorter * 0.8) continue;
        if (b.box.left - a.box.right > h * 1.3) continue;
        if (best == null || b.box.left < best.box.left) best = b;
      }
      if (best != null && hasPrevious.add(best)) next[a] = best;
    }

    for (final start in tall) {
      if (hasPrevious.contains(start)) continue;
      final row = [start];
      for (var glyph = next[start]; glyph != null; glyph = next[glyph]) {
        row.add(glyph);
      }
      yield row;
    }
  }

  SegmentReading? _readRow(List<_Glyph> row, List<_Glyph> all) {
    // Un carácter suelto no alcanza para decir que es un display.
    if (row.length < 2) return null;
    // La fila se sigue por el centro de los dígitos (el 1 y el 4 son más
    // bajos, pero están centrados), y el alto es el de los dígitos
    // completos.
    final middle = _Line.fit(
      [for (final glyph in row) glyph.box.centerX],
      [for (final glyph in row) glyph.box.centerY],
    );
    final tallest = row.map((glyph) => glyph.box.height).reduce(math.max);
    final full = [
      for (final glyph in row)
        if (glyph.box.height >= tallest * 0.9) glyph.box.height,
    ]..sort();
    final height = full[full.length ~/ 2].toDouble();
    if (height < _minHeight) return null;
    final top = _Line(middle.a - (height - 1) / 2, middle.b);
    final bottom = _Line(middle.a + (height - 1) / 2, middle.b);

    final pitch = _pitch(row, height);
    if (pitch == null) return null;
    if (!_complete(row, all, middle, height, pitch)) return null;
    if (!row.every((glyph) => _contrasted(glyph, height))) return null;

    // El 1 no depende de la inclinación: es el único sin ningún trazo
    // horizontal.
    final ones = [for (final glyph in row) _isOne(glyph, top, height)];
    if (ones.contains(null)) return null;
    if (!_onesAlone(row, ones, all, middle, height)) return null;

    // La inclinación con la que cada segmento queda más claramente
    // prendido o apagado.
    String? digits;
    var shear = 0.0;
    var doubt = double.infinity;
    for (final candidate in _shears) {
      final text = StringBuffer();
      var total = 0.0;
      for (var i = 0; i < row.length; i++) {
        if (ones[i]!) {
          text.write('1');
          continue;
        }
        final glyph = row[i];
        final decoded =
            _decode(_Cell(glyph, top.at(glyph.box.centerX), height, candidate));
        if (decoded == null) {
          total = double.infinity;
          break;
        }
        text.write(decoded.digit);
        total += decoded.doubt;
      }
      if (total < doubt) {
        doubt = total;
        digits = text.toString();
        shear = candidate;
      }
    }
    // Una fila de puros 1 son trazos verticales cualquiera: bordes,
    // reflejos.
    if (digits == null || !digits.contains(RegExp('[02-9]'))) return null;

    final strokes = [for (final glyph in row) _stroke(glyph)]..sort();
    return SegmentReading(
      digits: digits,
      pointAfter:
          _point(row, all, bottom, height, shear, strokes[strokes.length ~/ 2]),
      negative: _minus(row, all, top, height),
      height: height,
    );
  }

  /// El paso entre dígitos, si es parejo. En un display de 7 segmentos los
  /// dígitos van a paso fijo, y el borde derecho de cada uno (el 1 incluido,
  /// que usa los segmentos de la derecha) cae siempre en el mismo lugar de
  /// su casilla.
  double? _pitch(List<_Glyph> row, double height) {
    final steps = [
      for (var i = 0; i + 1 < row.length; i++)
        (row[i + 1].box.right - row[i].box.right).toDouble(),
    ]..sort();
    final pitch = steps[steps.length ~/ 2];
    if (steps.first < height * 0.4) return null;
    if (steps.first < pitch * 0.8 || steps.last > pitch * 1.25) return null;
    return pitch;
  }

  /// La fila está entera: al lado no queda nada del alto de los dígitos que
  /// no se haya podido encadenar (un dígito partido, dos pegados). Si no, se
  /// leería un pedazo del número. Las unidades y rótulos son más bajos y no
  /// cuentan.
  bool _complete(
    List<_Glyph> row,
    List<_Glyph> all,
    _Line middle,
    double height,
    double pitch,
  ) {
    final first = row.first.box, last = row.last.box;
    // Los componentes que tocan el borde no entran en _assemble. Si uno
    // ocupa el lugar de un dígito vecino, el recuadro cortó la lectura:
    // ignorarlo convertiría, por ejemplo, 23456 en 3456.
    for (final part in _parts) {
      final box = part.box;
      if (!part.touchesEdge ||
          box.size < height * 0.1 ||
          part.area < height * 0.15 ||
          box.height > height * 1.3 ||
          box.width > pitch * 1.3) {
        continue;
      }
      final center = middle.at(box.centerX);
      if (box.bottom >= center - height * 0.55 &&
          box.top <= center + height * 0.55 &&
          box.right >= first.left - pitch * 1.5 &&
          box.left <= last.right + pitch * 1.5) {
        return false;
      }
    }
    for (final glyph in all) {
      final box = glyph.box;
      if (row.contains(glyph) || box.height < height * 0.75) continue;
      if ((box.centerY - middle.at(box.centerX)).abs() > height * 0.3) {
        continue;
      }
      if (box.right < first.left - pitch * 1.5 ||
          box.left > last.right + pitch * 1.5) {
        continue;
      }
      return false;
    }
    return true;
  }

  /// El 1 ocupa solo la derecha de su casilla. Si a su izquierda, dentro de
  /// la casilla, hay otro pedazo del alto de un segmento, no es un 1 sino
  /// un dígito partido (un 4 al que se le separó la parte izquierda).
  bool _onesAlone(
    List<_Glyph> row,
    List<bool?> ones,
    List<_Glyph> all,
    _Line middle,
    double height,
  ) {
    final widths = [
      for (var i = 0; i < row.length; i++)
        if (ones[i] == false) row[i].box.width,
    ]..sort();
    final width =
        widths.isEmpty ? height * 0.55 : widths[widths.length ~/ 2].toDouble();
    for (var i = 0; i < row.length; i++) {
      if (ones[i] != true) continue;
      final one = row[i].box;
      final from = one.right - width;
      for (final glyph in all) {
        final box = glyph.box;
        if (row.contains(glyph) || box.size < height * 0.25) continue;
        if (box.right < from || box.left >= one.left) continue;
        if ((box.centerY - middle.at(box.centerX)).abs() > height * 0.5) {
          continue;
        }
        return false;
      }
    }
    return true;
  }

  /// Grosor del trazo: la mediana de los tramos de tinta de cada fila, que
  /// en su mayoría cruzan segmentos verticales.
  int _stroke(_Glyph glyph) {
    final box = glyph.box;
    final runs = <int>[];
    for (var y = box.top; y <= box.bottom; y++) {
      var run = 0;
      for (var x = box.left; x <= box.right + 1; x++) {
        if (x <= box.right && _isInk(glyph, x, y)) {
          run++;
        } else if (run > 0) {
          runs.add(run);
          run = 0;
        }
      }
    }
    if (runs.isEmpty) return 1;
    runs.sort();
    return runs[runs.length ~/ 2];
  }

  /// La tinta del carácter contrasta con lo que lo rodea. El promedio local
  /// deja un halo de "tinta" del lado equivocado alrededor de un trazo muy
  /// contrastado; ese halo tiene el mismo tono que el fondo de más allá.
  bool _contrasted(_Glyph glyph, double height) {
    final box = glyph.box;
    final pad = math.max(2, (height * 0.12).round());
    var inkSum = 0, inkCount = 0, aroundSum = 0, aroundCount = 0;
    for (var y = math.max(0, box.top - pad);
        y <= math.min(_h - 1, box.bottom + pad);
        y++) {
      for (var x = math.max(0, box.left - pad);
          x <= math.min(_w - 1, box.right + pad);
          x++) {
        final index = y * _w + x;
        final inside =
            x >= box.left && x <= box.right && y >= box.top && y <= box.bottom;
        if (inside) {
          if (glyph.labels.contains(_labels[index])) {
            inkSum += image.pixels[index];
            inkCount++;
          }
        } else if (_ink[index] == 0) {
          aroundSum += image.pixels[index];
          aroundCount++;
        }
      }
    }
    if (inkCount == 0 || aroundCount == 0) return false;
    final difference = inkSum / inkCount - aroundSum / aroundCount;
    return (brightInk ? difference : -difference) >= _margin;
  }

  /// Si [glyph] es un 1: una sola barra (los segmentos b y c), sin nada que
  /// sobresalga a los lados como sobresalen los trazos horizontales de los
  /// demás dígitos (el de arriba del 7, aunque sea corto). Null si parece un
  /// 1 pero no ocupa el alto de la fila.
  bool? _isOne(_Glyph glyph, _Line top, double height) {
    final box = glyph.box;
    if (box.width > height * 0.45) return false;

    // Dónde empieza y termina la tinta en cada fila. Una barra es un solo
    // tramo por fila; un 0 angosto tiene dos, con el hueco al medio.
    final ys = <double>[];
    final starts = <int>[], ends = <int>[];
    var split = 0;
    for (var y = box.top; y <= box.bottom; y++) {
      var start = -1, end = -1, runs = 0;
      var inside = false;
      for (var x = box.left; x <= box.right; x++) {
        final ink = _isInk(glyph, x, y);
        if (ink && !inside) runs++;
        inside = ink;
        if (!ink) continue;
        if (start < 0) start = x;
        end = x;
      }
      if (start < 0) continue;
      if (runs > 1) split++;
      ys.add(y.toDouble());
      starts.add(start);
      ends.add(end);
    }
    if (ys.length < 3) return null;
    if (split > ys.length * 0.15) return false;
    final widths = [
      for (var i = 0; i < ys.length; i++) ends[i] - starts[i] + 1,
    ]..sort();
    final bar = widths[widths.length ~/ 2];
    if (bar > height * 0.25) return false;

    // El eje de la barra, por las filas angostas (sigue la itálica).
    final axisY = <double>[], axisX = <double>[];
    for (var i = 0; i < ys.length; i++) {
      if (ends[i] - starts[i] + 1 > bar * 1.5) continue;
      axisY.add(ys[i]);
      axisX.add((starts[i] + ends[i]) / 2);
    }
    final axis = _Line.fit(axisY, axisX);
    for (var i = 0; i < ys.length; i++) {
      final center = axis.at(ys[i]);
      if (starts[i] < center - bar * 0.8 || ends[i] > center + bar * 0.8) {
        return false;
      }
    }

    // Tinta en la mitad de arriba y en la de abajo: un trazo suelto no es
    // un 1.
    final cell = _Cell(glyph, top.at(box.centerX), height, 0);
    var upper = 0, lower = 0, rowsUpper = 0, rowsLower = 0;
    for (var y = cell.y(0.1); y <= cell.y(0.9); y++) {
      final v = cell.v(y);
      if (v > 0.45 && v < 0.55) continue;
      var ink = false;
      for (var x = box.left; x <= box.right; x++) {
        if (_isInk(glyph, x, y)) {
          ink = true;
          break;
        }
      }
      if (v <= 0.45) {
        rowsUpper++;
        if (ink) upper++;
      } else {
        rowsLower++;
        if (ink) lower++;
      }
    }
    if (rowsUpper == 0 || rowsLower == 0) return null;
    return upper >= rowsUpper * 0.6 && lower >= rowsLower * 0.6 ? true : null;
  }

  ({String digit, double doubt})? _decode(_Cell cell) {
    // Un dígito que no es 1 ocupa buena parte del ancho de su casilla.
    if (cell.width < cell.height * 0.3) return null;

    // Adentro de las dos "ventanas" del 8 nunca hay segmentos. Si hay
    // tinta, es una mancha o letra de imprenta (el 4 con diagonal).
    if (_inkFraction(cell, 0.38, 0.56, 0.22, 0.32) > 0.25 ||
        _inkFraction(cell, 0.38, 0.56, 0.68, 0.78) > 0.25) {
      return null;
    }

    final coverage = [
      _columnCoverage(cell, 0.3, 0.7, -0.05, 0.2), // a
      _rowCoverage(cell, 0.65, 1.05, 0.15, 0.4), // b
      _rowCoverage(cell, 0.65, 1.05, 0.6, 0.85), // c
      _columnCoverage(cell, 0.3, 0.7, 0.8, 1.05), // d
      _rowCoverage(cell, -0.05, 0.35, 0.6, 0.85), // e
      _rowCoverage(cell, -0.05, 0.35, 0.15, 0.4), // f
      _columnCoverage(cell, 0.3, 0.7, 0.38, 0.62), // g
    ];
    var pattern = 0;
    var doubt = 0.0;
    for (var i = 0; i < coverage.length; i++) {
      final value = coverage[i];
      // Una punta de trazo puede cubrir media ventana sin ser un segmento
      // horizontal: el 7 se convertía en 3. La zona intermedia se rechaza.
      if (value >= 0.7) {
        pattern |= 1 << i;
      } else if (value > 0.25) {
        return null; // Ni prendido ni apagado: no es un display de segmentos.
      }
      doubt += math.min(value, 1 - value);
    }
    final digit = _patterns[pattern];
    return digit == null ? null : (digit: digit, doubt: doubt);
  }

  bool _isInk(_Glyph glyph, int x, int y) {
    if (x < 0 || y < 0 || x >= _w || y >= _h) return false;
    final label = _labels[y * _w + x];
    return label != 0 && glyph.labels.contains(label);
  }

  /// Fracción de columnas (u de [u0] a [u1]) con tinta del carácter entre
  /// las alturas [v0] y [v1]: un segmento horizontal cruza casi todas.
  double _columnCoverage(
      _Cell cell, double u0, double u1, double v0, double v1) {
    final columns = math.max(1, ((u1 - u0) * cell.width).round());
    var hit = 0;
    for (var i = 0; i <= columns; i++) {
      final u = u0 + (u1 - u0) * i / columns;
      for (var y = cell.y(v0); y <= cell.y(v1); y++) {
        if (_isInk(cell.glyph, cell.x(u, cell.v(y)), y)) {
          hit++;
          break;
        }
      }
    }
    return hit / (columns + 1);
  }

  /// Fracción de filas (v de [v0] a [v1]) con tinta del carácter entre [u0]
  /// y [u1]: un segmento vertical cruza casi todas.
  double _rowCoverage(_Cell cell, double u0, double u1, double v0, double v1) {
    var hit = 0, rows = 0;
    for (var y = cell.y(v0); y <= cell.y(v1); y++) {
      rows++;
      final v = cell.v(y);
      for (var x = cell.x(u0, v); x <= cell.x(u1, v); x++) {
        if (_isInk(cell.glyph, x, y)) {
          hit++;
          break;
        }
      }
    }
    return rows == 0 ? 0 : hit / rows;
  }

  double _inkFraction(_Cell cell, double u0, double u1, double v0, double v1) {
    var ink = 0, total = 0;
    for (var y = cell.y(v0); y <= cell.y(v1); y++) {
      final v = cell.v(y);
      for (var x = cell.x(u0, v); x <= cell.x(u1, v); x++) {
        total++;
        if (_isInk(cell.glyph, x, y)) ink++;
      }
    }
    return total == 0 ? 0 : ink / total;
  }

  /// El punto decimal: una mancha chica apoyada en la base de los dígitos,
  /// en el hueco entre dos de ellos, más o menos del grueso de un trazo. Una
  /// punta de segmento que quedó suelta es bastante más chica.
  int? _point(
    List<_Glyph> row,
    List<_Glyph> all,
    _Line bottom,
    double height,
    double shear,
    int stroke,
  ) {
    // Con itálica, la base de cada dígito queda corrida a la izquierda.
    final lean = shear > 0 ? shear * height : 0.0;
    int? found;
    for (final glyph in all) {
      final box = glyph.box;
      if (row.contains(glyph) || box.size > height * 0.2) continue;
      if (box.width < stroke * 0.4 ||
          box.height < stroke * 0.4 ||
          glyph.area < stroke * stroke * 0.2) {
        continue;
      }
      final base = bottom.at(box.centerX);
      if (box.bottom < base - height * 0.15 ||
          box.bottom > base + height * 0.1) {
        continue;
      }
      for (var i = 0; i + 1 < row.length; i++) {
        if (box.centerX >= row[i].box.right - lean - height * 0.15 &&
            box.centerX <= row[i + 1].box.left + height * 0.1) {
          if (found != null && found != i + 1) return null;
          found = i + 1;
        }
      }
    }
    return found;
  }

  /// El signo menos: un trazo horizontal a media altura, antes del primer
  /// dígito.
  bool _minus(List<_Glyph> row, List<_Glyph> all, _Line top, double height) {
    final first = row.first.box;
    for (final glyph in all) {
      final box = glyph.box;
      if (row.contains(glyph)) continue;
      if (box.width < height * 0.25 ||
          box.width > height * 0.8 ||
          box.height > height * 0.25) {
        continue;
      }
      final middle = (box.centerY - top.at(box.centerX)) / height;
      if (middle < 0.35 || middle > 0.65) continue;
      if (box.right < first.left && first.left - box.right <= height) {
        return true;
      }
    }
    return false;
  }
}
