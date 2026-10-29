import 'dart:io' show ZLibCodec;
import 'dart:math' as math;
import 'dart:typed_data';

import 'seven_segment_reader.dart';

/// Guarda una imagen en grises como PNG, sin librerías de imagen: la
/// evidencia de cada lectura del lector es el recuadro tal como se analizó.
///
/// Con [maxWidth] la imagen se reduce (conservando la proporción) para que
/// una medición de 90 lecturas no ocupe decenas de megas.
Uint8List encodeGrayPng(GrayImage image, {int maxWidth = 640}) {
  final source = image.width > maxWidth ? _shrink(image, maxWidth) : image;
  final w = source.width, h = source.height;

  // Cada fila empieza con su filtro; "Sub" (1) comprime mejor los fondos
  // parejos de un display.
  final raw = Uint8List((w + 1) * h);
  for (var y = 0; y < h; y++) {
    final row = y * (w + 1);
    raw[row] = 1;
    var previous = 0;
    for (var x = 0; x < w; x++) {
      final value = source.pixels[y * w + x];
      raw[row + 1 + x] = (value - previous) & 0xFF;
      previous = value;
    }
  }

  final header = ByteData(13)
    ..setUint32(0, w)
    ..setUint32(4, h)
    ..setUint8(8, 8) // 8 bits por píxel
    ..setUint8(9, 0) // grises
    ..setUint8(10, 0)
    ..setUint8(11, 0)
    ..setUint8(12, 0);
  final out = BytesBuilder(copy: false)
    ..add(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  _chunk(out, 'IHDR', header.buffer.asUint8List());
  _chunk(out, 'IDAT', Uint8List.fromList(ZLibCodec(level: 6).encode(raw)));
  _chunk(out, 'IEND', Uint8List(0));
  return out.toBytes();
}

void _chunk(BytesBuilder out, String type, Uint8List data) {
  final typeBytes = Uint8List.fromList(type.codeUnits);
  final length = ByteData(4)..setUint32(0, data.length);
  out
    ..add(length.buffer.asUint8List())
    ..add(typeBytes)
    ..add(data);
  final crc = ByteData(4)..setUint32(0, crc32([...typeBytes, ...data]));
  out.add(crc.buffer.asUint8List());
}

final _crcTable = List<int>.generate(256, (n) {
  var c = n;
  for (var k = 0; k < 8; k++) {
    c = (c & 1) != 0 ? 0xEDB88320 ^ (c >>> 1) : c >>> 1;
  }
  return c;
});

/// CRC-32 de PNG y ZIP.
int crc32(List<int> bytes) {
  var crc = 0xFFFFFFFF;
  for (final byte in bytes) {
    crc = _crcTable[(crc ^ byte) & 0xFF] ^ (crc >>> 8);
  }
  return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
}

/// Reduce por promedio de áreas.
GrayImage _shrink(GrayImage image, int width) {
  final w = math.max(1, width);
  final h = math.max(1, (image.height * w / image.width).round());
  final pixels = Uint8List(w * h);
  final sx = image.width / w, sy = image.height / h;
  for (var y = 0; y < h; y++) {
    final y0 = (y * sy).floor(), y1 = math.max(y0 + 1, ((y + 1) * sy).floor());
    for (var x = 0; x < w; x++) {
      final x0 = (x * sx).floor(),
          x1 = math.max(x0 + 1, ((x + 1) * sx).floor());
      var sum = 0, count = 0;
      for (var yy = y0; yy < y1 && yy < image.height; yy++) {
        for (var xx = x0; xx < x1 && xx < image.width; xx++) {
          sum += image.pixels[yy * image.width + xx];
          count++;
        }
      }
      pixels[y * w + x] = count == 0 ? 0 : (sum / count).round();
    }
  }
  return GrayImage(w, h, pixels);
}
