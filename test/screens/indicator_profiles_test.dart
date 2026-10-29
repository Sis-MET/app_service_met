import 'dart:io' show ZLibCodec;
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:service_met/screens/calibracion/utils/capture_vote.dart';
import 'package:service_met/screens/calibracion/utils/indicator_frame.dart';
import 'package:service_met/screens/calibracion/utils/indicator_reading.dart';
import 'package:service_met/screens/calibracion/utils/png_encoder.dart';
import 'package:service_met/screens/calibracion/utils/profile_search.dart';
import 'package:service_met/screens/calibracion/utils/reading_profile.dart';
import 'package:service_met/screens/calibracion/utils/seven_segment_reader.dart';
import 'package:service_met/screens/calibracion/widgets/indicator_camera_view.dart';

import 'seven_segment_render.dart';

/// Un controlador de mufla: el PV en LED rojo arriba (más grande) y el SV en
/// LED verde abajo, como cuadro NV21 de la cámara (luminancia y VU).
CameraFrame _controller({required String pv, required String sv}) {
  final top = renderSevenSegment(pv, height: 70);
  final bottom = renderSevenSegment(sv, height: 50);
  final w = math.max(top.width, bottom.width) & ~1;
  final h = (top.height + bottom.height) & ~1;
  final r = Uint8List(w * h), g = Uint8List(w * h), b = Uint8List(w * h);
  r.fillRange(0, r.length, 20);
  g.fillRange(0, g.length, 20);
  b.fillRange(0, b.length, 20);
  void paint(GrayImage display, int offsetY, {required bool red}) {
    for (var y = 0; y < display.height; y++) {
      for (var x = 0; x < display.width && x < w; x++) {
        final yy = y + offsetY;
        if (yy >= h) continue;
        final t = ((display.pixels[y * display.width + x] - 25) / 205)
            .clamp(0.0, 1.0);
        final i = yy * w + x;
        if (red) {
          r[i] = (20 + 235 * t).round();
          g[i] = (20 + 30 * t).round();
          b[i] = (20 + 15 * t).round();
        } else {
          r[i] = (20 + 40 * t).round();
          g[i] = (20 + 235 * t).round();
          b[i] = (20 + 30 * t).round();
        }
      }
    }
  }

  paint(top, 0, red: true);
  paint(bottom, top.height, red: false);
  return CameraFrame(
    bytes: _nv21(w, h, r, g, b),
    width: w,
    height: h,
    bytesPerRow: w,
    rotation: 0,
  );
}

Uint8List _nv21(int w, int h, Uint8List r, Uint8List g, Uint8List b) {
  final out = Uint8List(w * h + w * (h ~/ 2));
  for (var i = 0; i < w * h; i++) {
    out[i] = (0.299 * r[i] + 0.587 * g[i] + 0.114 * b[i]).round().clamp(0, 255);
  }
  for (var y = 0; y < h; y += 2) {
    for (var x = 0; x < w; x += 2) {
      var sr = 0.0, sg = 0.0, sb = 0.0;
      for (final (dx, dy) in const [(0, 0), (1, 0), (0, 1), (1, 1)]) {
        final i = (y + dy) * w + x + dx;
        sr += r[i];
        sg += g[i];
        sb += b[i];
      }
      sr /= 4;
      sg /= 4;
      sb /= 4;
      final v = 0.5 * sr - 0.418688 * sg - 0.081312 * sb + 128;
      final u = -0.168736 * sr - 0.331264 * sg + 0.5 * sb + 128;
      final at = w * h + (y >> 1) * w + x;
      out[at] = v.round().clamp(0, 255);
      out[at + 1] = u.round().clamp(0, 255);
    }
  }
  return out;
}

CameraFrame _grayFrame(GrayImage image) => CameraFrame(
      bytes: image.pixels,
      width: image.width,
      height: image.height,
      bytesPerRow: image.width,
      rotation: 0,
    );

Future<List<List<OcrWord>>> _noText(GrayImage _) async => const [];

void main() {
  const entire = Rect.fromLTRB(0, 0, 1, 1);

  group('color del cuadro', () {
    test('un cuadro solo con luminancia lee igual en todos los modos', () {
      final frame = _grayFrame(renderSevenSegment('123.4'));
      expect(frame.hasColor, isFalse);
      final luma = frame.crop(entire);
      for (final color in IndicatorColor.values) {
        expect(frame.crop(entire, color: color).pixels, luma.pixels);
      }
    });

    test('el rojo separa el PV del SV de un controlador', () {
      final frame = _controller(pv: '250', sv: '300');
      expect(frame.hasColor, isTrue);
      final rojo = SevenSegmentReader.read(
          frame.crop(entire, color: IndicatorColor.rojo));
      final verde = SevenSegmentReader.read(
          frame.crop(entire, color: IndicatorColor.verde));
      expect(rojo?.toString(), '250');
      expect(verde?.toString(), '300');
      // Con la luminancia se ven los dos y gana el más grande: el PV.
      expect(SevenSegmentReader.read(frame.crop(entire))?.toString(), '250');
    });

    test('NV21 a color: el rojo puro da rojo, el verde da verde', () {
      final w = 4, h = 2;
      final r = Uint8List.fromList(List.filled(8, 230));
      final g = Uint8List.fromList(List.filled(8, 20));
      final b = Uint8List.fromList(List.filled(8, 20));
      final frame = CameraFrame(
        bytes: _nv21(w, h, r, g, b),
        width: w,
        height: h,
        bytesPerRow: w,
        rotation: 0,
      );
      final rojo = frame.crop(entire, color: IndicatorColor.rojo).pixels.first;
      final verde =
          frame.crop(entire, color: IndicatorColor.verde).pixels.first;
      final brillo =
          frame.crop(entire, color: IndicatorColor.brillo).pixels.first;
      expect(rojo, greaterThan(180));
      expect(verde, lessThan(20));
      expect(brillo, greaterThan(200));
    });
  });

  group('7 segmentos en displays de temperatura', () {
    test('la unidad al final se descarta solo con units', () {
      final image = renderSevenSegment('25.0C');
      expect(SevenSegmentReader.read(image), isNull);
      final reading = SevenSegmentReader.read(image, units: true);
      expect(reading?.toString(), '25.0');
      expect(
        IndicatorReadingParser.fromSegments(reading!, expectedDecimals: 1)
            ?.value,
        '25.0',
      );
    });

    test('°F de 3 dígitos', () {
      final reading =
          SevenSegmentReader.read(renderSevenSegment('212F'), units: true);
      expect(reading?.toString(), '212');
    });

    test('un mensaje del display no es un valor', () {
      for (final text in ['HHHH', 'LLLL']) {
        final reading =
            SevenSegmentReader.read(renderSevenSegment(text), units: true);
        expect(reading?.status, text, reason: text);
        final candidate = IndicatorReadingParser.fromSegments(reading!);
        expect(candidate?.isNumber, isFalse);
        expect(candidate?.number, isNull);
        // Sin units, no se lee nada.
        expect(SevenSegmentReader.read(renderSevenSegment(text)), isNull);
      }
    });

    test('dígitos sin unidad siguen igual con units', () {
      for (final text in ['125.4', '-18.5', '1000']) {
        final reading =
            SevenSegmentReader.read(renderSevenSegment(text), units: true);
        expect(reading?.toString(), text, reason: text);
      }
    });

    test('limitar la polaridad no cambia la lectura correcta', () {
      final led = renderSevenSegment('350.2');
      expect(SevenSegmentReader.read(led, brightInk: true)?.toString(),
          '350.2');
      expect(SevenSegmentReader.read(led, brightInk: false), isNull);
      final lcd = renderSevenSegment('350.2', ink: 30, background: 200);
      expect(SevenSegmentReader.read(lcd, brightInk: false)?.toString(),
          '350.2');
    });
  });

  group('OCR de texto', () {
    test('prepara el display claro sobre oscuro como tinta oscura', () {
      final band = renderSevenSegment('88', height: 40);
      final prepared = prepareForText(band, scale: 1);
      // Las esquinas son fondo: tras invertir, claras.
      expect(prepared.pixels.first, greaterThan(200));
      expect(prepared.width, band.width);
      final doubled = prepareForText(band);
      expect(doubled.width, band.width * 2);
      expect(doubled.height, band.height * 2);
    });

    test('mensajes sin valor solo con statuses', () {
      final lines = [
        [const OcrWord('----', Rect.fromLTWH(0, 0, 80, 30))],
      ];
      expect(IndicatorReadingParser.candidates(lines), isEmpty);
      final found = IndicatorReadingParser.candidates(lines, statuses: true);
      expect(found.single.isNumber, isFalse);
      expect(found.single.status, '----');
      for (final text in ['OPEn', 'Err', 'oL', 'HHHH', '----°C']) {
        expect(
          IndicatorReadingParser.candidates([
            [OcrWord(text, const Rect.fromLTWH(0, 0, 80, 30))]
          ], statuses: true)
              .single
              .isNumber,
          isFalse,
          reason: text,
        );
      }
    });

    test('un número gana a un mensaje del mismo alto', () {
      final found = IndicatorReadingParser.candidates([
        [const OcrWord('OPEN', Rect.fromLTWH(0, 0, 80, 30))],
        [const OcrWord('125.4', Rect.fromLTWH(0, 40, 80, 30))],
      ], statuses: true);
      expect(found.first.value, '125.4');
      expect(found.first.raw, '125.4');
    });
  });

  group('varios recuadros', () {
    test('lee cada recuadro por separado', () async {
      final frame = _controller(pv: '250', sv: '300');
      final reader = IndicatorFrameReader.multi(
        regions: const [
          IndicatorRegion(region: Rect.fromLTRB(0, 0, 1, 0.58)),
          IndicatorRegion(region: Rect.fromLTRB(0, 0.58, 1, 1)),
        ],
        recognize: _noText,
      );
      final readings = await reader.readAll(frame);
      expect(readings.map((r) => r.candidate?.value), ['250', '300']);
      expect(readings.first.candidate?.source, IndicatorSource.segmentos);
      expect(readings.first.band.width, greaterThan(0));
    });

    test('mover un recuadro descarta lo que se leía', () async {
      final reader = IndicatorFrameReader(region: entire, recognize: _noText);
      reader.region = const Rect.fromLTRB(0.1, 0.1, 0.9, 0.9);
      expect(reader.region, const Rect.fromLTRB(0.1, 0.1, 0.9, 0.9));
      final candidate =
          await reader.read(_grayFrame(renderSevenSegment('42.5')));
      expect(candidate?.value, '42.5');
    });
  });

  group('verificar lectura', () {
    test('encuentra el perfil que da el valor que ve el técnico', () async {
      final frame = _controller(pv: '250', sv: '300');
      final profile = await ProfileSearch.find(
        frames: [frame, frame, frame],
        region: entire,
        expected: '300',
        recognize: _noText,
      );
      expect(profile?.engine, IndicatorEngine.segmentos);
      expect(profile?.color, IndicatorColor.verde);
    });

    test('sin coincidencia no fija nada', () async {
      final profile = await ProfileSearch.find(
        frames: [_grayFrame(renderSevenSegment('250'))],
        region: entire,
        expected: '999',
        recognize: _noText,
      );
      expect(profile, isNull);
      expect(ProfileSearch.parse(' 12,5 '), 12.5);
      expect(ProfileSearch.parse('abc'), isNull);
    });

    test('el perfil se guarda y se recupera', () {
      const profile = ReadingProfile(
        engine: IndicatorEngine.texto,
        color: IndicatorColor.brillo,
        brightInk: true,
        scale: 2,
        bridge: true,
        units: true,
      );
      expect(ReadingProfile.fromJson(profile.toJson()), profile);
      expect(ReadingProfile.fromJson(const {}), ReadingProfile.automatico);
      expect(profile.descripcion, contains('Texto'));
    });
  });

  group('voto de la ráfaga', () {
    IndicatorCandidate value(String v) =>
        IndicatorCandidate(value: v, height: 40);

    test('acepta con 3 cuadros iguales', () {
      final vote = VotoLecturas();
      vote
        ..add(value('125.4'))
        ..add(value('125.9'))
        ..add(null)
        ..add(value('125.4'));
      expect(vote.accepted, isFalse);
      vote.add(value('125.4'));
      expect(vote.accepted, isTrue);
      expect(vote.done, isTrue);
      expect(vote.resultado.candidate?.value, '125.4');
      expect(vote.resultado.votes, 3);
      expect(vote.resultado.coincidencia, closeTo(0.6, 1e-9));
    });

    test('termina sin acuerdo cuando ya no se puede llegar', () {
      final vote = VotoLecturas();
      vote
        ..add(null)
        ..add(null)
        ..add(value('1'));
      expect(vote.done, isFalse, reason: '1 voto + 2 cuadros pueden dar 3');
      vote.add(null);
      expect(vote.done, isTrue, reason: '1 voto + 1 cuadro < 3');
      expect(vote.accepted, isFalse);
      expect(vote.resultado.candidate?.value, '1');
    });

    test('un mensaje sin valor también se vota, aparte de los números', () {
      final vote = VotoLecturas();
      for (var i = 0; i < 3; i++) {
        vote.add(const IndicatorCandidate.sinValor('----', height: 30));
      }
      expect(vote.accepted, isTrue);
      expect(vote.resultado.candidate?.isNumber, isFalse);
    });
  });

  group('expectativas del canal', () {
    const expectations = ReadingExpectations(
      decimals: 1,
      min: 0,
      max: 1200,
      maxJump: 15,
      unit: '°C',
    );

    test('sin avisos en una lectura normal', () {
      expect(
        expectations.check(const IndicatorCandidate(value: '250.4', height: 1),
            previous: 249.9),
        isEmpty,
      );
    });

    test('decimales, rango y salto', () {
      final codes = expectations
          .check(const IndicatorCandidate(value: '1250', height: 1),
              previous: 250)
          .map((alert) => alert.code);
      expect(codes, containsAll(['decimales', 'fuera_de_rango', 'salto']));
      final alert = expectations
          .check(const IndicatorCandidate(value: '280.0', height: 1),
              previous: 250)
          .single;
      expect(alert.message, 'Cambió 30 °C desde la lectura anterior.');
    });
  });

  group('evidencia PNG', () {
    test('ida y vuelta de los píxeles', () {
      final image = renderSevenSegment('12.3', height: 30);
      final png = encodeGrayPng(image);
      expect(png.sublist(0, 8), [137, 80, 78, 71, 13, 10, 26, 10]);
      final data = ByteData.sublistView(png);
      expect(String.fromCharCodes(png.sublist(12, 16)), 'IHDR');
      expect(data.getUint32(16), image.width);
      expect(data.getUint32(20), image.height);
      // IDAT: tras IHDR (8 + 25 bytes).
      final idatLength = data.getUint32(33);
      expect(String.fromCharCodes(png.sublist(37, 41)), 'IDAT');
      final raw = ZLibCodec().decode(png.sublist(41, 41 + idatLength));
      final w = image.width;
      for (var y = 0; y < image.height; y++) {
        expect(raw[y * (w + 1)], 1);
        var previous = 0;
        for (var x = 0; x < w; x++) {
          final value = (raw[y * (w + 1) + 1 + x] + previous) & 0xFF;
          expect(value, image.pixels[y * w + x]);
          previous = value;
        }
      }
      // El CRC de IHDR coincide.
      final crc = data.getUint32(29);
      expect(crc, crc32(png.sublist(12, 29)));
    });

    test('reduce las imágenes anchas', () {
      final image = GrayImage(1280, 200, Uint8List(1280 * 200));
      final png = encodeGrayPng(image, maxWidth: 640);
      final data = ByteData.sublistView(png);
      expect(data.getUint32(16), 640);
      expect(data.getUint32(20), 100);
    });

    test('CRC-32 conocido', () {
      expect(crc32('123456789'.codeUnits), 0xCBF43926);
    });
  });

  group('recuadros en pantalla', () {
    test('mover no sale de la imagen', () {
      const region = Rect.fromLTRB(0.7, 0.7, 0.9, 0.9);
      final moved = IndicatorCameraView.move(region, const Offset(0.5, 0.5));
      expect(moved.left, closeTo(0.8, 1e-9));
      expect(moved.top, closeTo(0.8, 1e-9));
      expect(moved.right, closeTo(1, 1e-9));
      expect(moved.bottom, closeTo(1, 1e-9));
    });

    test('agrandar y achicar respetan el mínimo', () {
      const region = Rect.fromLTRB(0.2, 0.4, 0.8, 0.6);
      final bigger =
          IndicatorCameraView.resize(region, 2, const Offset(0.1, 0.1));
      expect(bigger.right, closeTo(0.9, 1e-9));
      expect(bigger.bottom, closeTo(0.7, 1e-9));
      final tiny =
          IndicatorCameraView.resize(region, 0, const Offset(0.9, 0.9));
      expect(tiny.width, closeTo(IndicatorCameraView.minWidth, 1e-9));
      expect(tiny.height, closeTo(IndicatorCameraView.minHeight, 1e-9));
    });
  });
}
