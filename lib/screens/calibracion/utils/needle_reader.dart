import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Offset, Rect;

import 'seven_segment_reader.dart' show GrayImage;

/// Una marca de la escala del dial: dónde la puso el técnico y qué valor
/// indica ahí la escala.
class DialMark {
  const DialMark(this.position, this.value);

  /// En fracciones de la imagen derecha, como los recuadros del lector.
  final Offset position;
  final double value;

  DialMark copyWith({Offset? position, double? value}) =>
      DialMark(position ?? this.position, value ?? this.value);

  List<double> toJson() => [position.dx, position.dy, value];

  static DialMark? fromJson(Object? json) {
    if (json is! List || json.length != 3) return null;
    final numbers = [
      for (final item in json) item is num ? item.toDouble() : null,
    ];
    if (numbers.contains(null)) return null;
    return DialMark(Offset(numbers[0]!, numbers[1]!), numbers[2]!);
  }

  @override
  bool operator ==(Object other) =>
      other is DialMark && other.position == position && other.value == value;

  @override
  int get hashCode => Object.hash(position, value);
}

/// La escala de un indicador de aguja (termómetro de dial de hornos y
/// muflas): el eje de la aguja y al menos dos marcas con su valor, puestas
/// por el técnico sobre la imagen. Con ellas el ángulo de la aguja se
/// convierte en un valor de la escala.
class DialScale {
  const DialScale({required this.center, required this.marks});

  /// Un dial de 270° en sentido horario dentro de [box]: el eje al centro y
  /// tres marcas, [desde] abajo a la izquierda, el medio arriba y [hasta]
  /// abajo a la derecha. [aspect] (ancho / alto de la imagen en píxeles)
  /// hace que el dial quede redondo en la imagen.
  factory DialScale.inicial(
    Rect box, {
    required double desde,
    required double hasta,
    double aspect = 9 / 16,
  }) {
    final center = box.center;
    // Radio en anchos de imagen: 0,4 del lado menor del recuadro.
    final r = 0.4 * math.min(box.width, box.height / aspect);
    DialMark mark(double degrees, double value) {
      final a = degrees * math.pi / 180;
      return DialMark(
        center + Offset(r * math.sin(a), -r * math.cos(a) * aspect),
        value,
      );
    }

    return DialScale(center: center, marks: [
      mark(-135, desde),
      mark(0, (desde + hasta) / 2),
      mark(135, hasta),
    ]);
  }

  /// El eje de la aguja, en fracciones de la imagen derecha.
  final Offset center;

  /// De la de menor valor a la de mayor valor.
  final List<DialMark> marks;

  DialScale withCenter(Offset center) =>
      DialScale(center: center, marks: marks);

  DialScale withMark(int index, DialMark mark) => DialScale(
        center: center,
        marks: [
          for (var i = 0; i < marks.length; i++) i == index ? mark : marks[i],
        ],
      );

  /// El dial que acompaña al recuadro cuando el técnico lo mueve o lo
  /// agranda: el eje y las marcas se corren y se estiran con él.
  DialScale mapped(Rect from, Rect to) {
    if (from.width <= 0 || from.height <= 0) return this;
    Offset map(Offset p) => Offset(
          to.left + (p.dx - from.left) / from.width * to.width,
          to.top + (p.dy - from.top) / from.height * to.height,
        );
    return DialScale(
      center: map(center),
      marks: [
        for (final m in marks) m.copyWith(position: map(m.position)),
      ],
    );
  }

  /// Si los valores de las marcas suben de una a la siguiente.
  bool get valoresEnOrden {
    for (var i = 1; i < marks.length; i++) {
      if (!(marks[i].value > marks[i - 1].value)) return false;
    }
    return marks.length >= 2;
  }

  /// La geometría en píxeles sobre una imagen de [width] × [height], con el
  /// origen corrido a [origin] (la esquina del recorte). Null si las marcas
  /// no forman una escala: valores que no suben, una marca sobre el eje o
  /// marcas que no siguen un mismo sentido de giro.
  DialGeometry? geometry(
    double width,
    double height, {
    Offset origin = Offset.zero,
  }) =>
      DialGeometry._from(this, width, height, origin);

  Map<String, Object?> toJson() => {
        'center': [center.dx, center.dy],
        'marks': [for (final m in marks) m.toJson()],
      };

  static DialScale? fromJson(Object? json) {
    if (json is! Map) return null;
    final center = json['center'];
    final marks = json['marks'];
    if (center is! List ||
        center.length != 2 ||
        center.any((v) => v is! num) ||
        marks is! List) {
      return null;
    }
    final parsed = [for (final m in marks) DialMark.fromJson(m)];
    if (parsed.length < 2 || parsed.contains(null)) return null;
    return DialScale(
      center:
          Offset((center[0] as num).toDouble(), (center[1] as num).toDouble()),
      marks: parsed.cast<DialMark>(),
    );
  }

  @override
  bool operator ==(Object other) {
    if (other is! DialScale ||
        other.center != center ||
        other.marks.length != marks.length) {
      return false;
    }
    for (var i = 0; i < marks.length; i++) {
      if (other.marks[i] != marks[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(center, Object.hashAll(marks));
}

/// La escala del dial en píxeles: el eje, el radio y, para cada marca, su
/// recorrido desde la primera en el sentido en que sube la escala.
///
/// Los ángulos son los de `atan2` con la y hacia abajo (como en la imagen):
/// crecen en sentido horario.
class DialGeometry {
  DialGeometry._({
    required this.cx,
    required this.cy,
    required this.radius,
    required this.start,
    required this.direction,
    required this.sweeps,
    required this.values,
  });

  final double cx, cy;

  /// Distancia media del eje a las marcas: el radio de la escala.
  final double radius;

  /// Ángulo de la primera marca.
  final double start;

  /// 1 si la escala sube en sentido horario, -1 si sube al revés.
  final int direction;

  /// Recorrido de cada marca desde la primera (0 para la primera, creciente).
  final List<double> sweeps;
  final List<double> values;

  double get total => sweeps.last;

  /// Recorrido mínimo entre la primera y la última marca.
  static const _minSweep = 20 * math.pi / 180;

  static DialGeometry? _from(
    DialScale dial,
    double width,
    double height,
    Offset origin,
  ) {
    final marks = dial.marks;
    if (!dial.valoresEnOrden || width <= 0 || height <= 0) return null;
    final cx = dial.center.dx * width - origin.dx;
    final cy = dial.center.dy * height - origin.dy;
    final angles = <double>[];
    var radius = 0.0;
    for (final mark in marks) {
      final dx = mark.position.dx * width - origin.dx - cx;
      final dy = mark.position.dy * height - origin.dy - cy;
      final distance = math.sqrt(dx * dx + dy * dy);
      if (distance < 4) return null;
      radius += distance;
      angles.add(math.atan2(dy, dx));
    }
    radius /= marks.length;
    // Casi todos los diales suben en sentido horario; con tres marcas o más
    // se reconoce también uno que sube al revés.
    for (final direction in const [1, -1]) {
      final sweeps = [
        for (final angle in angles) wrap(direction * (angle - angles.first)),
      ];
      var increasing = true;
      for (var i = 1; i < sweeps.length; i++) {
        if (!(sweeps[i] > sweeps[i - 1])) increasing = false;
      }
      if (increasing && sweeps.last >= _minSweep) {
        return DialGeometry._(
          cx: cx,
          cy: cy,
          radius: radius,
          start: angles.first,
          direction: direction,
          sweeps: sweeps,
          values: [for (final mark in marks) mark.value],
        );
      }
    }
    return null;
  }

  /// [angle] llevado a 0…2π.
  static double wrap(double angle) => angle % (2 * math.pi);

  /// El recorrido desde la primera marca de una aguja que apunta a [angle].
  /// En la zona muerta (entre la última marca y la primera), la mitad más
  /// cercana al final cuenta como pasado el final y la otra como antes del
  /// inicio (negativo).
  double sweepOf(double angle) {
    final s = wrap(direction * (angle - start));
    if (s <= total) return s;
    final dead = 2 * math.pi - total;
    return s - total <= dead / 2 ? s : s - 2 * math.pi;
  }

  double angleOf(double sweep) => start + direction * sweep;

  /// El valor de la escala en el recorrido [sweep]: lineal entre las marcas
  /// vecinas y, fuera de ellas, con el tramo del extremo.
  double valueAt(double sweep) {
    var i = 0;
    while (i < sweeps.length - 2 && sweep > sweeps[i + 1]) {
      i++;
    }
    final s0 = sweeps[i], s1 = sweeps[i + 1];
    return values[i] + (sweep - s0) * (values[i + 1] - values[i]) / (s1 - s0);
  }
}

/// Dónde apunta la aguja en un cuadro.
class NeedleReading {
  const NeedleReading({
    required this.angle,
    required this.sweep,
    required this.value,
    required this.score,
    required this.outOfScale,
    this.scale = const [],
  });

  /// Ángulo de la aguja en la imagen (como `atan2`, con la y hacia abajo).
  final double angle;

  /// Recorrido desde la primera marca, en radianes.
  final double sweep;

  /// El valor de la escala donde apunta, sin redondear.
  final double value;

  /// Qué tan clara se vio: la parte del trazo de la aguja con tinta (0 a 1).
  final double score;

  /// Apunta antes de la primera marca o pasada la última.
  final bool outOfScale;

  /// Los valores de las marcas con que se convirtió el ángulo.
  final List<double> scale;

  double get sweepDegrees => sweep * 180 / math.pi;
}

/// Lee la aguja de un indicador analógico.
///
/// Primero la encuentra: desde el eje que marcó el técnico se recorre la
/// escala ángulo por ángulo y se mide qué parte de cada rayo cae sobre
/// tinta, en un tramo interior (de 0,25 a 0,5 del radio de la escala) y uno
/// exterior (de 0,5 a 0,8). La aguja es la única que llena los dos: su cola
/// solo llega al interior y los números y las rayas de la escala no tocan el
/// interior. Después afina el ángulo con el tramo interior de la aguja, donde
/// no hay números: el centro de la tinta de través en cada radio, una recta
/// por esos centros y el punto donde cruza la escala. Así un eje marcado
/// unos píxeles corrido casi no mueve la lectura, igual que al leer a ojo la
/// punta de la aguja sobre la escala. Con luz despareja, el fondo del dial
/// se estima por sectores.
///
/// Nunca adivina: sin una aguja clara, o con dos candidatas parecidas, no
/// hay lectura.
abstract final class NeedleReader {
  static const _inner = (0.25, 0.5);
  static const _outer = (0.5, 0.8);

  /// Hueco sin tinta que se tolera en el trazo de la aguja, en fracción del
  /// radio.
  static const _maxGap = 0.03;

  /// Tramo con el que se afina el ángulo: sin números ni rayas.
  static const _fit = (0.2, 0.55);

  /// Parte mínima de cada tramo con tinta para aceptar la aguja.
  static const minScore = 0.6;

  /// Una segunda candidata con más de esta parte de la mejor hace dudosa la
  /// lectura.
  static const maxRival = 0.7;

  /// Cuánto puede pasarse la aguja de las marcas extremas, en fracción del
  /// recorrido, y seguir siendo una lectura.
  static const overshoot = 0.02;

  /// Radio de trabajo: un dial más grande se reduce antes de buscar.
  static const _workRadius = 160.0;

  /// Tinta: más oscura que el fondo en esta parte del contraste.
  static const _inkContrast = 0.35;

  static NeedleReading? read(GrayImage image, DialGeometry dial) =>
      trace(image, dial).reading;

  /// La lectura con lo que la decidió, para revisar un caso difícil.
  static NeedleTrace trace(GrayImage image, DialGeometry dial) {
    if (image.width < 8 || image.height < 8 || dial.radius < 12) {
      return const NeedleTrace.rechazo('Dial muy chico');
    }
    final factor = math.max(1, (dial.radius / _workRadius).floor());
    final work = _Work.reduce(image, dial, factor);
    final ink = work.ink();
    if (ink == null) return const NeedleTrace.rechazo('Sin contraste');

    final r = work.radius;
    final total = dial.total;
    final dead = 2 * math.pi - total;
    final margin =
        math.max(0.0, math.min(0.08 * total, dead / 2 - 2 * math.pi / 180));
    // Medio píxel de arco en el borde exterior.
    final step = 0.5 / (_outer.$2 * r);
    final count = ((total + 2 * margin) / step).floor() + 1;
    final sweeps = Float64List(count);
    final scores = Float64List(count);
    for (var i = 0; i < count; i++) {
      final s = -margin + i * step;
      final angle = dial.angleOf(s);
      final ray = work.ray(ink, math.cos(angle), math.sin(angle));
      sweeps[i] = s;
      scores[i] = ray.score;
    }

    var best = 0;
    for (var i = 1; i < count; i++) {
      if (scores[i] > scores[best]) best = i;
    }
    final peak = scores[best];
    if (peak < minScore) {
      return NeedleTrace.rechazo('Sin aguja clara', peak: peak);
    }

    // El centro del pico (la aguja tiene ancho): promedio ponderado de lo
    // que supera la mitad del pico, sin saltar a otro pico.
    final half = peak / 2;
    var from = best, to = best;
    while (from > 0 && scores[from - 1] >= half) {
      from--;
    }
    while (to < count - 1 && scores[to + 1] >= half) {
      to++;
    }
    var weight = 0.0, sum = 0.0;
    for (var i = from; i <= to; i++) {
      final w = scores[i] - half;
      weight += w;
      sum += w * sweeps[i];
    }
    final coarse = weight > 0 ? sum / weight : sweeps[best];

    // Otra candidata parecida fuera del pico (y de un margen a su lado) hace
    // dudosa la lectura.
    final guard = math.max(3 * math.pi / 180, (ink.dilation * 2 + 2) / r);
    final low = sweeps[from] - guard, high = sweeps[to] + guard;
    var rival = 0.0;
    double? rivalSweep;
    for (var i = 0; i < count; i++) {
      if (sweeps[i] >= low && sweeps[i] <= high) continue;
      if (scores[i] > rival) {
        rival = scores[i];
        rivalSweep = sweeps[i];
      }
    }
    if (rival > maxRival * peak) {
      return NeedleTrace.rechazo('Dos agujas posibles',
          peak: peak, rival: rival, coarse: coarse, rivalSweep: rivalSweep);
    }

    final refined = _refine(work, ink, dial.angleOf(coarse));
    final angle = refined ?? dial.angleOf(coarse);
    final sweep = dial.sweepOf(angle);
    final outOfScale =
        sweep < -overshoot * total || sweep > total * (1 + overshoot);
    return NeedleTrace(
      NeedleReading(
        angle: angle,
        sweep: sweep,
        value: dial.valueAt(sweep),
        score: peak,
        outOfScale: outOfScale,
        scale: dial.values,
      ),
      peak: peak,
      rival: rival,
      coarse: coarse,
      rivalSweep: rivalSweep,
      refined: refined != null,
    );
  }

  /// El ángulo donde la recta de la aguja (por el centro de su tinta entre
  /// 0,2 y 0,55 del radio) cruza la escala, visto desde el eje marcado. Null
  /// si ese tramo de la aguja no se ve bien (queda el ángulo del rayo).
  static double? _refine(_Work work, _Ink ink, double angle) {
    final r = work.radius;
    final ux = math.cos(angle), uy = math.sin(angle);
    final nx = -uy, ny = ux;
    final lateral = math.max(4.0, 0.06 * r);
    final points = <(double, double, double)>[];
    for (var t = _fit.$1 * r; t <= _fit.$2 * r; t += 1) {
      final px = work.cx + t * ux, py = work.cy + t * uy;
      // La tinta de través más cercana al rayo, sin juntarla con otra.
      final samples = <double>[];
      for (var o = -lateral; o <= lateral + 1e-9; o += 0.5) {
        samples.add(work.darknessAt(ink, px + o * nx, py + o * ny));
      }
      final middle = samples.length ~/ 2;
      var peak = -1;
      for (var k = 0; k <= middle; k++) {
        if (samples[middle - k] >= 0.5) {
          peak = middle - k;
          break;
        }
        if (middle + k < samples.length && samples[middle + k] >= 0.5) {
          peak = middle + k;
          break;
        }
      }
      if (peak < 0) continue;
      var a = peak, b = peak;
      while (a > 0 && samples[a - 1] >= 0.15) {
        a--;
      }
      while (b < samples.length - 1 && samples[b + 1] >= 0.15) {
        b++;
      }
      // Una mancha que llena la ventana no es la aguja.
      if (a == 0 || b == samples.length - 1) continue;
      var mass = 0.0, moment = 0.0;
      for (var k = a; k <= b; k++) {
        mass += samples[k];
        moment += samples[k] * (-lateral + k * 0.5);
      }
      points.add((t, moment / mass, mass));
    }
    if (points.length < 0.15 * r) return null;

    // Recta c = p + q·t por mínimos cuadrados; se descartan los puntos a más
    // de 1,5 píxeles y se vuelve a ajustar.
    (double, double)? fit(List<(double, double, double)> pts) {
      var sw = 0.0, st = 0.0, sc = 0.0, stt = 0.0, stc = 0.0;
      for (final (t, c, w) in pts) {
        sw += w;
        st += w * t;
        sc += w * c;
        stt += w * t * t;
        stc += w * t * c;
      }
      final det = sw * stt - st * st;
      if (det.abs() < 1e-9) return null;
      final q = (sw * stc - st * sc) / det;
      return ((sc - q * st) / sw, q);
    }

    var line = fit(points);
    if (line == null) return null;
    final (p0, q0) = line;
    final kept = [
      for (final point in points)
        if ((point.$2 - (p0 + q0 * point.$1)).abs() <= 1.5) point,
    ];
    if (kept.length < 0.15 * r) return null;
    line = fit(kept);
    if (line == null) return null;
    final (p, q) = line;

    // Del eje marcado al cruce de la recta con la escala (radio r).
    final norm = math.sqrt(1 + q * q);
    final vx = (ux + q * nx) / norm, vy = (uy + q * ny) / norm;
    final along = p * (nx * vx + ny * vy);
    final disc = along * along - p * p + r * r;
    if (disc <= 0) return null;
    final s = -along + math.sqrt(disc);
    final x = p * nx + s * vx, y = p * ny + s * vy;
    return math.atan2(y, x);
  }
}

/// Lo que decidió el lector de aguja en un cuadro.
class NeedleTrace {
  const NeedleTrace(
    this.reading, {
    required this.peak,
    this.rival = 0,
    this.coarse,
    this.rivalSweep,
    this.refined = false,
  }) : rejected = null;

  const NeedleTrace.rechazo(
    String this.rejected, {
    this.peak = 0,
    this.rival = 0,
    this.coarse,
    this.rivalSweep,
  })  : reading = null,
        refined = false;

  final NeedleReading? reading;

  /// Por qué no hubo lectura.
  final String? rejected;

  /// La mejor y la segunda candidata (parte de tinta, 0 a 1).
  final double peak, rival;

  /// El recorrido del rayo antes de afinar y el de la segunda candidata, en
  /// radianes.
  final double? coarse, rivalSweep;

  /// Si se afinó con la recta de la aguja.
  final bool refined;

  @override
  String toString() => reading == null
      ? 'NeedleTrace($rejected, peak: ${peak.toStringAsFixed(2)}, '
          'rival: ${rival.toStringAsFixed(2)}'
          '${coarse == null ? '' : ' en ${_deg(coarse!)}° y ${_deg(rivalSweep ?? 0)}°'})'
      : 'NeedleTrace(${reading!.value.toStringAsFixed(2)}, '
          'peak: ${peak.toStringAsFixed(2)}, '
          'rival: ${rival.toStringAsFixed(2)}'
          '${rivalSweep == null ? '' : ' en ${_deg(rivalSweep!)}°'}, '
          'refined: $refined)';
}

String _deg(double radians) => (radians * 180 / math.pi).toStringAsFixed(1);

/// La tinta del dial: dilatada para encontrar la aguja aunque el eje esté
/// unos píxeles corrido, y cuánto más oscuro que el fondo es cada píxel
/// para afinarla.
class _Ink {
  const _Ink(this.mask, this.darkness, this.dilation);

  final Uint8List mask;

  /// 0 (fondo) a 1 (lo más oscuro del dial).
  final Float32List darkness;
  final int dilation;
}

/// El dial reducido a un cuadrado alrededor del eje, en grises.
class _Work {
  _Work(this.size, this.pixels, this.cx, this.cy, this.radius);

  final int size;
  final Uint8List pixels;

  /// El eje y el radio de la escala, en píxeles de trabajo.
  final double cx, cy, radius;

  /// Promedia bloques de [factor] × [factor] en un cuadrado que cubre hasta
  /// 0,85 del radio. Lo que cae fuera del recorte repite el borde.
  static _Work reduce(GrayImage image, DialGeometry dial, int factor) {
    final radius = dial.radius / factor;
    final half = (0.85 * radius).ceil() + 4;
    final size = half * 2 + 1;
    final x0 = (dial.cx - half * factor).floor();
    final y0 = (dial.cy - half * factor).floor();
    final source = image.pixels;
    final w = image.width, h = image.height;
    final pixels = Uint8List(size * size);
    final area = factor * factor;
    for (var v = 0; v < size; v++) {
      for (var u = 0; u < size; u++) {
        var sum = 0;
        for (var dy = 0; dy < factor; dy++) {
          final y = (y0 + v * factor + dy).clamp(0, h - 1);
          final row = y * w;
          for (var dx = 0; dx < factor; dx++) {
            final x = (x0 + u * factor + dx).clamp(0, w - 1);
            sum += source[row + x];
          }
        }
        pixels[v * size + u] = sum ~/ area;
      }
    }
    return _Work(
      size,
      pixels,
      (dial.cx - x0) / factor,
      (dial.cy - y0) / factor,
      radius,
    );
  }

  /// Sectores del fondo: 24 en ángulo y 2 en radio.
  static const _sectors = 24;

  /// Qué es tinta en el anillo donde se busca la aguja, o null si el dial no
  /// tiene contraste. Un dial oscuro con aguja clara se invierte.
  _Ink? ink() {
    final rIn = 0.18 * radius, rOut = 0.85 * radius, rMid = 0.5 * radius;
    final cells = _sectors * 2;
    final histograms = Int32List(cells * 256);
    final global = Int32List(256);
    final cellOf = Int32List(size * size)..fillRange(0, size * size, -1);
    for (var v = 0; v < size; v++) {
      final dy = v + 0.5 - cy;
      for (var u = 0; u < size; u++) {
        final dx = u + 0.5 - cx;
        final d = math.sqrt(dx * dx + dy * dy);
        if (d < rIn || d > rOut) continue;
        final sector =
            ((math.atan2(dy, dx) + math.pi) / (2 * math.pi) * _sectors)
                .floor()
                .clamp(0, _sectors - 1);
        final cell = sector * 2 + (d < rMid ? 0 : 1);
        final i = v * size + u;
        cellOf[i] = cell;
        histograms[cell * 256 + pixels[i]]++;
        global[pixels[i]]++;
      }
    }
    // Los extremos: la aguja puede ser una parte mínima del anillo.
    final low = _percentile(global, 0, 0.002);
    final median = _percentile(global, 0, 0.5);
    final high = _percentile(global, 0, 0.998);
    if (high - low < 24) return null;
    // El fondo ocupa casi todo el anillo: si lo más lejano a la mediana es
    // claro, el dial es oscuro y la aguja clara.
    final invert = median - low < high - median;
    int tone(int value) => invert ? 255 - value : value;

    final faces = Int32List(cells);
    final known = <int>[];
    for (var cell = 0; cell < cells; cell++) {
      if (_count(histograms, cell * 256) == 0) {
        faces[cell] = -1;
        continue;
      }
      // El fondo de cada sector: lo claro que domina (aguja y números son
      // una parte chica del sector).
      faces[cell] =
          tone(_percentile(histograms, cell * 256, invert ? 0.25 : 0.75));
      known.add(faces[cell]);
    }
    if (known.isEmpty) return null;
    known.sort();
    final face = known[known.length ~/ 2];
    final darkest = tone(invert ? high : low);
    final contrast = face - darkest;
    if (contrast < 24) return null;

    final mask = Uint8List(size * size);
    final darkness = Float32List(size * size);
    for (var i = 0; i < mask.length; i++) {
      final cell = cellOf[i];
      if (cell < 0) continue;
      final background = faces[cell] < 0 ? face : faces[cell];
      final below = (background - tone(pixels[i])) / contrast;
      darkness[i] = below.clamp(0.0, 1.0);
      if (below >= NeedleReader._inkContrast) mask[i] = 1;
    }
    final dilation = math.max(2, (0.015 * radius).round());
    return _Ink(_dilate(mask, dilation), darkness, dilation);
  }

  /// Cuánto más oscuro que el fondo es el punto ([x], [y]), interpolando.
  double darknessAt(_Ink ink, double x, double y) {
    final fx = x - 0.5, fy = y - 0.5;
    final x0 = fx.floor(), y0 = fy.floor();
    if (x0 < 0 || y0 < 0 || x0 + 1 >= size || y0 + 1 >= size) return 0;
    final tx = fx - x0, ty = fy - y0;
    final d = ink.darkness;
    final i = y0 * size + x0;
    final top = d[i] * (1 - tx) + d[i + 1] * tx;
    final bottom = d[i + size] * (1 - tx) + d[i + size + 1] * tx;
    return top * (1 - ty) + bottom * ty;
  }

  /// El rayo desde el eje en dirección ([dx], [dy]): qué parte de cada tramo
  /// (interior y exterior) cae sobre tinta, rebajado si la tinta se corta.
  /// La aguja es un trazo continuo; la cola y un número alineados con ella
  /// dejan un hueco entre los dos.
  ({double inner, double outer, double gap, double score}) ray(
    _Ink ink,
    double dx,
    double dy,
  ) {
    final mask = ink.mask;
    final from = NeedleReader._inner.$1 * radius;
    final middle = NeedleReader._inner.$2 * radius;
    final to = NeedleReader._outer.$2 * radius;
    var innerHits = 0, innerSamples = 0, outerHits = 0, outerSamples = 0;
    var run = 0, longest = 0;
    for (var r = from; r <= to; r += 1) {
      final x = (cx + r * dx).floor(), y = (cy + r * dy).floor();
      final hit = x >= 0 && y >= 0 && x < size && y < size
          ? mask[y * size + x] == 1
          : false;
      if (r < middle) {
        innerSamples++;
        if (hit) innerHits++;
      } else {
        outerSamples++;
        if (hit) outerHits++;
      }
      run = hit ? 0 : run + 1;
      if (run > longest) longest = run;
    }
    final inner = innerSamples == 0 ? 0.0 : innerHits / innerSamples;
    final outer = outerSamples == 0 ? 0.0 : outerHits / outerSamples;
    // Un hueco de hasta 0,03 del radio (ya con la tinta dilatada) se tolera
    // (un reflejo sobre la aguja); desde ahí baja hasta anular el rayo al
    // doble.
    final gap = longest / radius;
    final continuity = (2 - gap / NeedleReader._maxGap).clamp(0.0, 1.0);
    return (
      inner: inner,
      outer: outer,
      gap: gap,
      score: math.min(inner, outer) * continuity,
    );
  }

  Uint8List _dilate(Uint8List mask, int radius) {
    final n = size;
    final horizontal = Uint8List(n * n);
    for (var y = 0; y < n; y++) {
      final row = y * n;
      var last = -1 << 30;
      // La tinta más cercana a la izquierda y a la derecha de cada píxel.
      for (var x = 0; x < n; x++) {
        if (mask[row + x] == 1) last = x;
        if (x - last <= radius) horizontal[row + x] = 1;
      }
      last = 1 << 30;
      for (var x = n - 1; x >= 0; x--) {
        if (mask[row + x] == 1) last = x;
        if (last - x <= radius) horizontal[row + x] = 1;
      }
    }
    final result = Uint8List(n * n);
    for (var x = 0; x < n; x++) {
      var last = -1 << 30;
      for (var y = 0; y < n; y++) {
        if (horizontal[y * n + x] == 1) last = y;
        if (y - last <= radius) result[y * n + x] = 1;
      }
      last = 1 << 30;
      for (var y = n - 1; y >= 0; y--) {
        if (horizontal[y * n + x] == 1) last = y;
        if (last - y <= radius) result[y * n + x] = 1;
      }
    }
    return result;
  }

  static int _count(Int32List histogram, int offset) {
    var total = 0;
    for (var v = 0; v < 256; v++) {
      total += histogram[offset + v];
    }
    return total;
  }

  static int _percentile(Int32List histogram, int offset, double fraction) {
    final target = _count(histogram, offset) * fraction;
    var seen = 0;
    for (var v = 0; v < 256; v++) {
      seen += histogram[offset + v];
      if (seen >= target && seen > 0) return v;
    }
    return 255;
  }
}
