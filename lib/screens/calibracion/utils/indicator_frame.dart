import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'indicator_reading.dart';
import 'reading_profile.dart';
import 'seven_segment_reader.dart';

/// Un cuadro de la cámara tal como llega: acostado según el sensor.
class CameraFrame {
  const CameraFrame({
    required this.bytes,
    required this.width,
    required this.height,
    required this.bytesPerRow,
    required this.rotation,
    this.bgra = false,
  });

  /// NV21 (Android): la luminancia primero, fila por fila, y después el
  /// color (V y U intercalados, a media resolución). O BGRA (iOS).
  final Uint8List bytes;
  final int width;
  final int height;
  final int bytesPerRow;

  /// Grados que hay que girar la imagen, en sentido horario, para verla
  /// derecha: 0, 90, 180 o 270.
  final int rotation;
  final bool bgra;

  /// Si el cuadro trae el color: en NV21 el plano VU va después de la
  /// luminancia. Sin él, todos los modos de color leen la luminancia.
  bool get hasColor =>
      bgra ||
      bytes.length >= bytesPerRow * height + bytesPerRow * (height ~/ 2);

  /// La franja [region] (fracciones de la imagen derecha), ya derecha y en
  /// grises según [color]. Ancho y alto pares, como pide NV21.
  GrayImage crop(Rect region, {IndicatorColor color = IndicatorColor.luma}) {
    final turned = rotation == 90 || rotation == 270;
    final uprightWidth = turned ? height : width;
    final uprightHeight = turned ? width : height;
    final left = (region.left.clamp(0.0, 1.0) * uprightWidth).floor();
    final top = (region.top.clamp(0.0, 1.0) * uprightHeight).floor();
    final right = (region.right.clamp(0.0, 1.0) * uprightWidth).floor();
    final bottom = (region.bottom.clamp(0.0, 1.0) * uprightHeight).floor();
    final w = math.max(0, right - left) & ~1;
    final h = math.max(0, bottom - top) & ~1;
    final pixels = Uint8List(w * h);
    final sample =
        color == IndicatorColor.luma || !hasColor ? _luma : _colored(color);
    for (var y = 0; y < h; y++) {
      final uy = top + y;
      for (var x = 0; x < w; x++) {
        final ux = left + x;
        // Del punto de la imagen derecha al punto del sensor.
        final int sx, sy;
        switch (rotation) {
          case 90:
            sx = uy;
            sy = height - 1 - ux;
          case 180:
            sx = width - 1 - ux;
            sy = height - 1 - uy;
          case 270:
            sx = width - 1 - uy;
            sy = ux;
          default:
            sx = ux;
            sy = uy;
        }
        pixels[y * w + x] = sample(sx, sy);
      }
    }
    return GrayImage(w, h, pixels);
  }

  int _luma(int x, int y) {
    if (!bgra) return bytes[y * bytesPerRow + x];
    final i = y * bytesPerRow + x * 4;
    return (bytes[i] * 29 + bytes[i + 1] * 150 + bytes[i + 2] * 77) >> 8;
  }

  int Function(int x, int y) _colored(IndicatorColor color) {
    return (x, y) {
      final (r, g, b) = _rgb(x, y);
      return switch (color) {
        IndicatorColor.brillo => math.max(r, math.max(g, b)),
        // Lo rojo menos la mitad de lo verde: un SV verde y un reflejo
        // blanco quedan apagados frente a un PV rojo.
        IndicatorColor.rojo => (r - g ~/ 2).clamp(0, 255),
        IndicatorColor.verde => (g - r ~/ 2).clamp(0, 255),
        IndicatorColor.luma => _luma(x, y),
      };
    };
  }

  (int, int, int) _rgb(int x, int y) {
    if (bgra) {
      final i = y * bytesPerRow + x * 4;
      return (bytes[i + 2], bytes[i + 1], bytes[i]);
    }
    final luma = bytes[y * bytesPerRow + x];
    final chroma = bytesPerRow * height + (y >> 1) * bytesPerRow + (x & ~1);
    final v = bytes[chroma] - 128;
    final u = bytes[chroma + 1] - 128;
    return (
      (luma + 1.402 * v).round().clamp(0, 255),
      (luma - 0.344136 * u - 0.714136 * v).round().clamp(0, 255),
      (luma + 1.772 * u).round().clamp(0, 255),
    );
  }
}

/// La imagen en grises como NV21 para el OCR en Android: la luminancia tal
/// cual y el color neutro.
Uint8List grayToNv21(GrayImage image) {
  final luma = image.width * image.height;
  return Uint8List(luma + luma ~/ 2)
    ..setRange(0, luma, image.pixels)
    ..fillRange(luma, luma + luma ~/ 2, 128);
}

/// La imagen en grises como BGRA para el OCR en iOS.
Uint8List grayToBgra(GrayImage image) {
  final pixels = image.pixels;
  final bgra = Uint8List(pixels.length * 4);
  for (var i = 0; i < pixels.length; i++) {
    final value = pixels[i];
    bgra[i * 4] = value;
    bgra[i * 4 + 1] = value;
    bgra[i * 4 + 2] = value;
    bgra[i * 4 + 3] = 255;
  }
  return bgra;
}

/// Prepara la franja para el OCR de texto, que aprendió letras oscuras
/// sobre papel claro: estira el contraste, invierte los displays de dígitos
/// claros (LED, VFD, pantallas con luz), amplía los chicos y, con
/// [bridge], une los segmentos separados engrosando la tinta.
GrayImage prepareForText(GrayImage band, {int scale = 0, bool bridge = false}) {
  if (band.width < 4 || band.height < 4) return band;
  final pixels = band.pixels;
  final histogram = Int32List(256);
  for (final value in pixels) {
    histogram[value]++;
  }
  int percentile(double fraction) {
    final target = pixels.length * fraction;
    var seen = 0;
    for (var value = 0; value < 256; value++) {
      seen += histogram[value];
      if (seen >= target) return value;
    }
    return 255;
  }

  final low = percentile(0.02), high = percentile(0.98);
  final median = percentile(0.5);
  final range = math.max(1, high - low);
  // El fondo ocupa la mayor parte de la franja: si es más oscuro que el
  // medio del contraste, la tinta es clara y se invierte.
  final invert = median < low + range / 2;
  var out = Uint8List(pixels.length);
  for (var i = 0; i < pixels.length; i++) {
    final stretched = ((pixels[i] - low) * 255 / range).round().clamp(0, 255);
    out[i] = invert ? 255 - stretched : stretched;
  }
  var image = GrayImage(band.width, band.height, out);

  if (bridge) {
    // Mínimo 3×3: la tinta, ya oscura, crece un píxel y cierra los cortes
    // entre segmentos.
    final w = image.width, h = image.height;
    final grown = Uint8List(w * h);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        var value = 255;
        for (var dy = -1; dy <= 1; dy++) {
          final ny = y + dy;
          if (ny < 0 || ny >= h) continue;
          for (var dx = -1; dx <= 1; dx++) {
            final nx = x + dx;
            if (nx < 0 || nx >= w) continue;
            final v = out[ny * w + nx];
            if (v < value) value = v;
          }
        }
        grown[y * w + x] = value;
      }
    }
    image = GrayImage(w, h, grown);
    out = grown;
  }

  // El OCR necesita unos 20 píxeles por letra: las franjas bajas se
  // duplican.
  final factor = scale == 0 ? (band.height < 140 ? 2 : 1) : scale.clamp(1, 2);
  if (factor == 2) image = _double(image);
  return image;
}

/// Duplica la imagen, interpolando.
GrayImage _double(GrayImage image) {
  final w = image.width, h = image.height;
  final w2 = w * 2, h2 = h * 2;
  final source = image.pixels;
  final pixels = Uint8List(w2 * h2);
  for (var y = 0; y < h2; y++) {
    final fy = math.max(0.0, y / 2 - 0.25);
    final y0 = fy.floor().clamp(0, h - 1), y1 = math.min(y0 + 1, h - 1);
    final ty = fy - y0;
    for (var x = 0; x < w2; x++) {
      final fx = math.max(0.0, x / 2 - 0.25);
      final x0 = fx.floor().clamp(0, w - 1), x1 = math.min(x0 + 1, w - 1);
      final tx = fx - x0;
      final top = source[y0 * w + x0] * (1 - tx) + source[y0 * w + x1] * tx;
      final bottom = source[y1 * w + x0] * (1 - tx) + source[y1 * w + x1] * tx;
      pixels[y * w2 + x] = (top * (1 - ty) + bottom * ty).round();
    }
  }
  return GrayImage(w2, h2, pixels);
}

/// Un recuadro que se lee en cada cuadro, con su manera de leerlo.
class IndicatorRegion {
  const IndicatorRegion({
    required this.region,
    this.profile = ReadingProfile.automatico,
    this.expectedDecimals,
  });

  /// En fracciones de la imagen derecha.
  final Rect region;
  final ReadingProfile profile;

  /// Decimales que muestra el display, para ubicar el punto que el OCR
  /// pierda.
  final int? expectedDecimals;

  IndicatorRegion copyWith({
    Rect? region,
    ReadingProfile? profile,
    int? expectedDecimals,
  }) =>
      IndicatorRegion(
        region: region ?? this.region,
        profile: profile ?? this.profile,
        expectedDecimals: expectedDecimals ?? this.expectedDecimals,
      );
}

/// Lo leído en un recuadro de un cuadro.
class RegionReading {
  const RegionReading({required this.candidate, required this.band});

  /// La lectura, si se encontró una.
  final IndicatorCandidate? candidate;

  /// El recuadro en grises, tal como se analizó: la evidencia de la lectura.
  final GrayImage band;
}

/// Qué se hace con cada cuadro: se recorta cada recuadro, se prueba como
/// display de 7 segmentos y, si no lo es, se pasa por el OCR de texto.
class IndicatorFrameReader {
  /// Un solo recuadro, como en el lector de balanzas.
  IndicatorFrameReader({
    required Rect region,
    required this.recognize,
    int? expectedDecimals,
    ReadingProfile profile = ReadingProfile.automatico,
    this.segmentMemory = const Duration(seconds: 2),
  }) : _regions = [
          IndicatorRegion(
            region: region,
            profile: profile,
            expectedDecimals: expectedDecimals,
          ),
        ];

  /// Varios recuadros en el mismo cuadro (patrón e indicador del equipo,
  /// varios sensores).
  IndicatorFrameReader.multi({
    required List<IndicatorRegion> regions,
    required this.recognize,
    this.segmentMemory = const Duration(seconds: 2),
  }) : _regions = List.of(regions);

  /// El OCR de texto sobre una franja ya preparada: sus líneas, cada una con
  /// sus palabras.
  final Future<List<List<OcrWord>>> Function(GrayImage band) recognize;

  /// Tras leer un display de 7 segmentos, cuánto tiempo no se le cree al
  /// OCR en ese recuadro: en esos displays lee un 4 como Y y se come el 1 y
  /// el punto, y su lectura equivocada haría saltar el valor en pantalla.
  final Duration segmentMemory;

  List<IndicatorRegion> _regions;
  final Map<int, DateTime> _segmentsSeen = {};
  int _generation = 0;

  List<IndicatorRegion> get regions => List.unmodifiable(_regions);

  /// El técnico movió un recuadro o se fijó un perfil: lo que se estaba
  /// leyendo con los anteriores se descarta.
  set regions(List<IndicatorRegion> regions) {
    _regions = List.of(regions);
    reset();
  }

  /// El recuadro del lector de un solo recuadro.
  Rect get region => _regions.first.region;
  set region(Rect value) =>
      regions = [_regions.first.copyWith(region: value), ..._regions.skip(1)];

  /// Una sesión nueva de cámara no hereda el tipo de display anterior.
  void reset() {
    _segmentsSeen.clear();
    _generation++;
  }

  /// La lectura del primer recuadro. Los mensajes sin valor no cuentan.
  Future<IndicatorCandidate?> read(CameraFrame frame, {DateTime? now}) async {
    final readings = await readAll(frame, now: now);
    final candidate = readings.isEmpty ? null : readings.first.candidate;
    return candidate?.isNumber == true ? candidate : null;
  }

  /// La lectura de cada recuadro, en el orden de [regions]. Vacía si se
  /// llamó a [reset] mientras se leía.
  Future<List<RegionReading>> readAll(
    CameraFrame frame, {
    DateTime? now,
  }) async {
    final generation = _generation;
    now ??= DateTime.now();
    final regions = _regions;
    // Recortar y buscar los segmentos toma unos milisegundos por recuadro:
    // fuera del hilo de la pantalla.
    final analyzed = await Isolate.run(
      () => [for (final region in regions) _analyze(frame, region)],
    );
    if (generation != _generation) return const [];

    final results = <RegionReading>[];
    for (var i = 0; i < regions.length; i++) {
      final region = regions[i];
      final (band, segments) = analyzed[i];
      if (segments != null) {
        _segmentsSeen[i] = now;
        results.add(RegionReading(
          band: band,
          candidate: IndicatorReadingParser.fromSegments(
            segments,
            expectedDecimals: region.expectedDecimals,
          ),
        ));
        continue;
      }
      final engine = region.profile.engine;
      final seen = _segmentsSeen[i];
      final remembersSegments = engine == IndicatorEngine.auto &&
          seen != null &&
          now.difference(seen) < segmentMemory;
      if (engine == IndicatorEngine.segmentos || remembersSegments) {
        results.add(RegionReading(band: band, candidate: null));
        continue;
      }
      final prepared = prepareForText(
        band,
        scale: region.profile.scale,
        bridge: region.profile.bridge,
      );
      final lines = await recognize(prepared);
      if (generation != _generation) return const [];
      results.add(RegionReading(
        band: band,
        candidate: IndicatorReadingParser.candidates(
          lines,
          expectedDecimals: region.expectedDecimals,
          statuses: region.profile.units,
        ).firstOrNull,
      ));
    }
    return results;
  }

  /// En el isolate: el recuadro en grises y, si el perfil lo permite, la
  /// lectura de 7 segmentos. En automático y con color, si con la
  /// luminancia no aparece un display se prueba con el brillo (LED de
  /// color).
  static (GrayImage, SegmentReading?) _analyze(
    CameraFrame frame,
    IndicatorRegion region,
  ) {
    final profile = region.profile;
    final band = frame.crop(region.region, color: profile.color);
    if (profile.engine == IndicatorEngine.texto) return (band, null);
    final segments = SevenSegmentReader.read(
      band,
      brightInk: profile.brightInk,
      units: profile.units,
    );
    if (segments != null ||
        profile.engine != IndicatorEngine.auto ||
        profile.color != IndicatorColor.luma ||
        !frame.hasColor) {
      return (band, segments);
    }
    final bright = frame.crop(region.region, color: IndicatorColor.brillo);
    final retry = SevenSegmentReader.read(
      bright,
      brightInk: profile.brightInk,
      units: profile.units,
    );
    return retry == null ? (band, null) : (bright, retry);
  }
}
