import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'indicator_reading.dart';
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

  /// NV21 (Android): la luminancia primero, fila por fila. O BGRA (iOS).
  final Uint8List bytes;
  final int width;
  final int height;
  final int bytesPerRow;

  /// Grados que hay que girar la imagen, en sentido horario, para verla
  /// derecha: 0, 90, 180 o 270.
  final int rotation;
  final bool bgra;

  /// La franja [region] (fracciones de la imagen derecha), ya derecha y en
  /// grises. Ancho y alto pares, como pide NV21.
  GrayImage crop(Rect region) {
    final turned = rotation == 90 || rotation == 270;
    final uprightWidth = turned ? height : width;
    final uprightHeight = turned ? width : height;
    final left = (region.left.clamp(0.0, 1.0) * uprightWidth).floor();
    final top = (region.top.clamp(0.0, 1.0) * uprightHeight).floor();
    final right = (region.right.clamp(0.0, 1.0) * uprightWidth).floor();
    final bottom = (region.bottom.clamp(0.0, 1.0) * uprightHeight).floor();
    final w = (right - left) & ~1;
    final h = (bottom - top) & ~1;
    final pixels = Uint8List(w * h);
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
        pixels[y * w + x] = _luma(sx, sy);
      }
    }
    return GrayImage(w, h, pixels);
  }

  int _luma(int x, int y) {
    if (!bgra) return bytes[y * bytesPerRow + x];
    final i = y * bytesPerRow + x * 4;
    return (bytes[i] * 29 + bytes[i + 1] * 150 + bytes[i + 2] * 77) >> 8;
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

/// Qué se hace con cada cuadro: se recorta la franja del recuadro, se
/// prueba como display de 7 segmentos y, si no lo es, se pasa por el OCR.
class IndicatorFrameReader {
  IndicatorFrameReader({
    required this.region,
    required this.recognize,
    this.expectedDecimals,
    this.segmentMemory = const Duration(seconds: 2),
  });

  /// Lo que se lee, en fracciones de la imagen derecha.
  final Rect region;

  /// El OCR de texto sobre la franja: sus líneas, cada una con sus palabras.
  final Future<List<List<OcrWord>>> Function(GrayImage band) recognize;

  final int? expectedDecimals;

  /// Tras leer un display de 7 segmentos, cuánto tiempo no se le cree al
  /// OCR: en esos displays lee un 4 como Y y se come el 1 y el punto, y su
  /// lectura equivocada haría saltar el valor en pantalla.
  final Duration segmentMemory;

  DateTime? _segmentsSeen;
  int _generation = 0;

  /// Una sesión nueva de cámara no hereda el tipo de display anterior.
  void reset() {
    _segmentsSeen = null;
    _generation++;
  }

  Future<IndicatorCandidate?> read(CameraFrame frame, {DateTime? now}) async {
    final generation = _generation;
    now ??= DateTime.now();
    final region = this.region;
    // Recortar y buscar los segmentos toma unos milisegundos: fuera del
    // hilo de la pantalla.
    final (band, segments) = await Isolate.run(() {
      final band = frame.crop(region);
      return (band, SevenSegmentReader.read(band));
    });
    if (generation != _generation) return null;

    if (segments != null) {
      _segmentsSeen = now;
      return IndicatorReadingParser.fromSegments(
        segments,
        expectedDecimals: expectedDecimals,
      );
    }
    final seen = _segmentsSeen;
    if (seen != null && now.difference(seen) < segmentMemory) return null;

    final lines = await recognize(band);
    if (generation != _generation) return null;
    return IndicatorReadingParser.candidates(
      lines,
      expectedDecimals: expectedDecimals,
    ).firstOrNull;
  }
}
