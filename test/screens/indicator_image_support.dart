import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:service_met/screens/calibracion/utils/seven_segment_reader.dart';

Future<GrayImage> loadIndicator(String name) async {
  final bytes = File('test/fixtures/indicators/$name.png').readAsBytesSync();
  final codec = await ui.instantiateImageCodec(bytes);
  final image = (await codec.getNextFrame()).image;
  final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!
      .buffer
      .asUint8List();
  final pixels = Uint8List(image.width * image.height);
  for (var i = 0; i < pixels.length; i++) {
    pixels[i] = data[i * 4];
  }
  final gray = GrayImage(image.width, image.height, pixels);
  image.dispose();
  codec.dispose();
  return gray;
}

GrayImage cropIndicator(GrayImage image, int x, int y, int width, int height) {
  final pixels = Uint8List(width * height);
  for (var row = 0; row < height; row++) {
    pixels.setRange(row * width, (row + 1) * width, image.pixels,
        (y + row) * image.width + x);
  }
  return GrayImage(width, height, pixels);
}

GrayImage resizeIndicator(GrayImage image, double scale) {
  final width = (image.width * scale).round() & ~1;
  final height = (image.height * scale).round() & ~1;
  final pixels = Uint8List(width * height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final x0 = (x / scale).floor(), y0 = (y / scale).floor();
      final x1 = ((x + 1) / scale).floor().clamp(x0 + 1, image.width);
      final y1 = ((y + 1) / scale).floor().clamp(y0 + 1, image.height);
      var sum = 0, count = 0;
      for (var yy = y0; yy < y1; yy++) {
        for (var xx = x0; xx < x1; xx++) {
          sum += image.pixels[yy * image.width + xx];
          count++;
        }
      }
      pixels[y * width + x] = sum ~/ count;
    }
  }
  return GrayImage(width, height, pixels);
}
