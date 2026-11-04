import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' show Offset, Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:service_met/screens/calibracion/utils/indicator_frame.dart';
import 'package:service_met/screens/calibracion/utils/indicator_reading.dart';
import 'package:service_met/screens/calibracion/utils/needle_reader.dart';
import 'package:service_met/screens/calibracion/utils/reading_profile.dart';
import 'package:service_met/screens/calibracion/utils/seven_segment_reader.dart';

import 'dial_render.dart';
import 'seven_segment_render.dart';

CameraFrame _frame(GrayImage image) => CameraFrame(
      bytes: image.pixels,
      width: image.width,
      height: image.height,
      bytesPerRow: image.width,
      rotation: 0,
    );

void main() {
  const entire = Rect.fromLTRB(0, 0, 1, 1);

  test('descarta resultados pendientes al cerrar la cámara', () async {
    final entered = Completer<void>();
    final result = Completer<List<List<OcrWord>>>();
    final reader = IndicatorFrameReader(
        region: entire,
        recognize: (_) {
          entered.complete();
          return result.future;
        });
    final pending = reader.read(_frame(GrayImage(40, 40, Uint8List(1600))));
    await entered.future;
    reader.reset();
    result.complete([
      [const OcrWord('123', Rect.fromLTWH(0, 0, 40, 20))]
    ]);
    expect(await pending, isNull);
    final decoding = reader.read(_frame(renderSevenSegment('4000.01')));
    reader.reset();
    expect(await decoding, isNull);
  });

  test('orienta NV21 respetando el relleno de cada fila', () {
    final expected = {
      0: [1, 2, 3, 4, 5, 6, 7, 8],
      90: [5, 1, 6, 2, 7, 3, 8, 4],
      180: [8, 7, 6, 5, 4, 3, 2, 1],
      270: [4, 8, 3, 7, 2, 6, 1, 5],
    };
    for (final entry in expected.entries) {
      final frame = CameraFrame(
        bytes: Uint8List.fromList([1, 2, 3, 4, 99, 99, 5, 6, 7, 8, 99, 99]),
        width: 4,
        height: 2,
        bytesPerRow: 6,
        rotation: entry.key,
      );
      final band = frame.crop(entire);
      expect(band.pixels, entry.value, reason: '${entry.key}°');
      expect(band.width, entry.key % 180 == 0 ? 4 : 2);
    }
  });

  test('recorta la región derecha y produce dimensiones pares', () {
    final frame = CameraFrame(
      bytes: Uint8List.fromList(List.generate(48, (i) => i)),
      width: 8,
      height: 6,
      bytesPerRow: 8,
      rotation: 90,
    );
    final band = frame.crop(const Rect.fromLTRB(1 / 3, 0.25, 5 / 6, 0.75));
    expect((band.width, band.height), (2, 4));
    expect(band.pixels, [26, 18, 27, 19, 28, 20, 29, 21]);
  });

  test('convierte grises para ML Kit y respeta el stride BGRA', () {
    final image = GrayImage(2, 2, Uint8List.fromList([10, 20, 30, 40]));
    expect(grayToNv21(image), [10, 20, 30, 40, 128, 128]);
    final packed = grayToBgra(image);
    expect(packed.take(8), [10, 10, 10, 255, 20, 20, 20, 255]);
    final padded = Uint8List(24)
      ..setRange(0, 8, packed)
      ..setRange(12, 20, packed, 8);
    final frame = CameraFrame(
        bytes: padded,
        width: 2,
        height: 2,
        bytesPerRow: 12,
        rotation: 0,
        bgra: true);
    expect(frame.crop(entire).pixels, image.pixels);
  });

  test('el isolate no captura el OCR ni recursos de la pantalla', () async {
    final port = ReceivePort();
    addTearDown(port.close);
    final reader = IndicatorFrameReader(
      region: entire,
      recognize: (_) async {
        // Un recurso nativo no se puede enviar al isolate del decodificador.
        port.sendPort.send('OCR');
        return [
          [const OcrWord('12.34', Rect.fromLTWH(0, 0, 40, 20))]
        ];
      },
    );
    final reading =
        await reader.read(_frame(GrayImage(40, 40, Uint8List(1600))));
    expect(reading?.value, '12.34');
  });

  test('prioriza segmentos y evita alternar con OCR durante dos segundos',
      () async {
    var ocrCalls = 0;
    final reader = IndicatorFrameReader(
      region: entire,
      expectedDecimals: 2,
      recognize: (_) async {
        ocrCalls++;
        return [
          [const OcrWord('999.00', Rect.fromLTWH(0, 0, 80, 40))]
        ];
      },
    );
    final now = DateTime(2026);
    final reading =
        await reader.read(_frame(renderSevenSegment('400001')), now: now);
    expect(reading?.value, '4000.01');
    expect(reading?.pointAdded, isTrue);
    expect(ocrCalls, 0);
    final blank = _frame(GrayImage(40, 40, Uint8List(1600)));
    expect(await reader.read(blank, now: now.add(const Duration(seconds: 1))),
        isNull);
    expect(ocrCalls, 0);
    expect(
        (await reader.read(blank, now: now.add(const Duration(seconds: 2))))
            ?.value,
        '999.00');
    expect(ocrCalls, 1);
    await reader.read(_frame(renderSevenSegment('400001')), now: now);
    reader.reset();
    expect((await reader.read(blank, now: now))?.value, '999.00');
    expect(ocrCalls, 2);
  });

  test('lee la aguja de un dial con la escala en fracciones de la imagen',
      () async {
    // El dial va dentro de una imagen vertical más grande; el sensor la
    // entrega acostada (rotación 90), como en Android.
    const spec = DialSpec(size: 360, scale: 150);
    final dial = renderDial(spec, value: 117);
    const width = 480, height = 640, left = 70, top = 150;
    final upright = Uint8List(width * height)..fillRange(0, width * height, 120);
    for (var y = 0; y < spec.size; y++) {
      upright.setRange((top + y) * width + left,
          (top + y) * width + left + spec.size, dial.pixels, y * spec.size);
    }
    // Sensor de 640 × 480: (ux, uy) de la imagen derecha está en
    // (uy, width - 1 - ux).
    final sensor = Uint8List(width * height);
    for (var uy = 0; uy < height; uy++) {
      for (var ux = 0; ux < width; ux++) {
        sensor[(width - 1 - ux) * height + uy] = upright[uy * width + ux];
      }
    }
    final frame = CameraFrame(
      bytes: sensor,
      width: height,
      height: width,
      bytesPerRow: height,
      rotation: 90,
    );
    Offset fraction(Offset p) =>
        Offset((p.dx + left) / width, (p.dy + top) / height);
    final scale = DialScale(
      center: fraction(spec.axis),
      marks: [
        for (final v in [0.0, 80.0, 160.0])
          DialMark(fraction(spec.pointAt(v)), v),
      ],
    );
    final reader = IndicatorFrameReader.multi(
      regions: [
        IndicatorRegion(
          region: Rect.fromLTWH(left / width - 0.02, top / height - 0.02,
              spec.size / width + 0.04, spec.size / height + 0.04),
          profile: ReadingProfile.aguja(scale),
          expectedDecimals: 0,
          step: 1,
        ),
      ],
      recognize: (_) async => fail('una aguja no pasa por el OCR'),
    );
    final readings = await reader.readAll(frame);
    final reading = readings.single;
    expect(reading.candidate?.value, '117');
    expect(reading.candidate?.source, IndicatorSource.aguja);
    expect(reading.needle?.value, closeTo(117, 0.3));
    expect(reading.candidate?.raw, endsWith('escala 0/80/160'));
  });
}
