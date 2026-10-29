import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../utils/indicator_frame.dart';
import '../utils/indicator_reading.dart';
import '../utils/seven_segment_reader.dart';

const _deviceRotation = {
  DeviceOrientation.portraitUp: 0,
  DeviceOrientation.landscapeLeft: 90,
  DeviceOrientation.portraitDown: 180,
  DeviceOrientation.landscapeRight: 270,
};

/// Abre la cámara trasera para leer displays: en el formato que el lector
/// entiende (NV21 en Android, con el color; BGRA en iOS) y en vertical, así
/// el recuadro de la pantalla y la imagen que se lee coinciden.
Future<(CameraController, CameraDescription)> abrirCamaraLector({
  ResolutionPreset resolucion = ResolutionPreset.high,
}) async {
  final cameras = await availableCameras();
  if (cameras.isEmpty) {
    throw CameraException('NoCamera', 'El teléfono no tiene cámara.');
  }
  final description = cameras.firstWhere(
    (camera) => camera.lensDirection == CameraLensDirection.back,
    orElse: () => cameras.first,
  );
  final camera = CameraController(
    description,
    resolucion,
    enableAudio: false,
    imageFormatGroup:
        Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
  );
  try {
    await camera.initialize();
    await camera.lockCaptureOrientation(DeviceOrientation.portraitUp);
  } catch (_) {
    await camera.dispose();
    rethrow;
  }
  return (camera, description);
}

/// Mensaje para el técnico de un error de la cámara.
String describirErrorCamara(CameraException error) {
  switch (error.code) {
    case 'CameraAccessDenied':
    case 'CameraAccessDeniedWithoutPrompt':
    case 'CameraAccessRestricted':
      return 'ServiceMET no tiene permiso para usar la cámara. '
          'Actívelo en los ajustes del teléfono.';
    default:
      return 'No se pudo abrir la cámara: ${error.description ?? error.code}';
  }
}

/// Giro de la imagen para que el texto quede derecho, según cómo está el
/// sensor montado y cómo se sostiene el teléfono.
InputImageRotation? rotacionCuadro(
  CameraController camera,
  CameraDescription description,
) {
  final sensor = description.sensorOrientation;
  if (Platform.isIOS) return InputImageRotationValue.fromRawValue(sensor);
  final device = _deviceRotation[
      camera.value.lockedCaptureOrientation ?? camera.value.deviceOrientation];
  if (device == null) return null;
  final degrees = description.lensDirection == CameraLensDirection.front
      ? (sensor + device) % 360
      : (sensor - device + 360) % 360;
  return InputImageRotationValue.fromRawValue(degrees);
}

/// El cuadro de la cámara para el lector, o null si el formato no sirve.
/// Con [copiar] los bytes se copian: la cámara reutiliza su búfer y el
/// cuadro se guarda para después («Verificar lectura»).
CameraFrame? cuadroDeCamara(
  CameraImage image,
  InputImageRotation rotation, {
  bool copiar = false,
}) {
  final raw = image.format.raw;
  final format = raw is int ? InputImageFormatValue.fromRawValue(raw) : null;
  final supported = Platform.isAndroid
      ? format == InputImageFormat.nv21
      : format == InputImageFormat.bgra8888;
  if (!supported || image.planes.length != 1) return null;
  final plane = image.planes.single;
  return CameraFrame(
    bytes: copiar ? Uint8List.fromList(plane.bytes) : plane.bytes,
    width: image.width,
    height: image.height,
    bytesPerRow: plane.bytesPerRow,
    rotation: rotation.rawValue,
    bgra: !Platform.isAndroid,
  );
}

/// El OCR de ML Kit sobre una franja ya derecha y en grises: sus líneas,
/// cada una con sus palabras.
Future<List<List<OcrWord>>> reconocerFranja(
  TextRecognizer recognizer,
  GrayImage band,
) async {
  final android = Platform.isAndroid;
  final recognized = await recognizer.processImage(InputImage.fromBytes(
    bytes: android ? grayToNv21(band) : grayToBgra(band),
    metadata: InputImageMetadata(
      size: Size(band.width.toDouble(), band.height.toDouble()),
      rotation: InputImageRotation.rotation0deg,
      format: android ? InputImageFormat.nv21 : InputImageFormat.bgra8888,
      bytesPerRow: android ? band.width : band.width * 4,
    ),
  ));
  return [
    for (final block in recognized.blocks)
      for (final line in block.lines)
        [
          for (final element in line.elements)
            OcrWord(element.text, element.boundingBox),
        ],
  ];
}
