import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../../../models/service_session.dart';
import '../../../theme/app_colors.dart';
import '../utils/indicator_reading.dart';

/// Lee el display de la balanza con la cámara.
///
/// El reconocimiento corre en el teléfono (ML Kit), sin internet. Solo se lee
/// lo que queda dentro del recuadro, y la lectura se ofrece cuando se repite
/// en varios cuadros seguidos: el técnico la compara con el display y la
/// confirma. Nunca se escribe sola en el campo.
class IndicatorReaderScreen extends StatefulWidget {
  const IndicatorReaderScreen({super.key, this.balanza});

  /// Para ubicar el punto decimal que el OCR pierda y avisar si la lectura no
  /// cuadra con la división d.
  final BalanzaInfo? balanza;

  /// Abre el lector y devuelve la lectura confirmada ("12.345"), o null.
  static Future<String?> read(BuildContext context, {BalanzaInfo? balanza}) {
    return Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => IndicatorReaderScreen(balanza: balanza),
      ),
    );
  }

  /// Zona que se lee, en fracciones de la imagen: una franja al centro
  /// donde se encuadra el display. Lo de fuera (placa, rótulos, otras
  /// pantallas) no compite con la lectura.
  static const region = Rect.fromLTRB(0.06, 0.36, 0.94, 0.64);

  @override
  State<IndicatorReaderScreen> createState() => _IndicatorReaderScreenState();
}

class _IndicatorReaderScreenState extends State<IndicatorReaderScreen>
    with WidgetsBindingObserver {
  final _recognizer = TextRecognizer();
  final _stability = ReadingStability();
  late final int? _expectedDecimals =
      IndicatorReadingCheck.expectedDecimals(widget.balanza);

  CameraController? _camera;
  CameraDescription? _description;
  bool _starting = false;
  bool _busy = false;
  DateTime _lastFrame = DateTime.fromMillisecondsSinceEpoch(0);
  IndicatorCandidate? _candidate;
  String? _error;
  bool _torch = false;

  /// Unos cinco cuadros por segundo: suficiente para seguir el display sin
  /// calentar el teléfono.
  static const _frameGap = Duration(milliseconds: 180);

  static const _deviceRotation = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Android se queda con la cámara solo mientras la app está al frente.
    if (state == AppLifecycleState.inactive) {
      _stop();
    } else if (state == AppLifecycleState.resumed) {
      _start();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stop(rebuild: false);
    _recognizer.close();
    super.dispose();
  }

  Future<void> _start() async {
    if (_camera != null || _starting) return;
    _starting = true;
    CameraController? camera;
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw CameraException('NoCamera', 'El teléfono no tiene cámara.');
      }
      final description = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      camera = CameraController(
        description,
        ResolutionPreset.high,
        enableAudio: false,
        // Los formatos que ML Kit acepta en bytes: NV21 en Android.
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );
      await camera.initialize();
      // La app va siempre en vertical: así el recuadro de pantalla y la
      // imagen que se lee coinciden aunque se gire el teléfono.
      await camera.lockCaptureOrientation(DeviceOrientation.portraitUp);
      if (!mounted) {
        await camera.dispose();
        return;
      }
      _camera = camera;
      _description = description;
      _torch = false;
      await camera.startImageStream(_onFrame);
      if (mounted) setState(() => _error = null);
    } on CameraException catch (error) {
      // Sin cámara abierta a medias: "Reintentar" empieza de cero.
      _camera = null;
      await camera?.dispose();
      if (mounted) setState(() => _error = _describe(error));
    } finally {
      _starting = false;
    }
  }

  Future<void> _stop({bool rebuild = true}) async {
    final camera = _camera;
    _camera = null;
    if (camera == null) return;
    if (rebuild && mounted) setState(() {});
    try {
      if (camera.value.isStreamingImages) await camera.stopImageStream();
    } on CameraException catch (_) {
      // Se cierra igual.
    }
    await camera.dispose();
  }

  String _describe(CameraException error) {
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

  Future<void> _onFrame(CameraImage image) async {
    final now = DateTime.now();
    final camera = _camera;
    final description = _description;
    if (_busy ||
        camera == null ||
        description == null ||
        now.difference(_lastFrame) < _frameGap) {
      return;
    }
    _busy = true;
    _lastFrame = now;
    try {
      final rotation = _rotation(camera, description);
      final input = rotation == null ? null : _inputImage(image, rotation);
      if (input == null) return;
      final recognized = await _recognizer.processImage(input);
      if (!mounted) return;

      final upright = rotation == InputImageRotation.rotation90deg ||
              rotation == InputImageRotation.rotation270deg
          ? Size(image.height.toDouble(), image.width.toDouble())
          : Size(image.width.toDouble(), image.height.toDouble());
      final lines = [
        for (final block in recognized.blocks)
          for (final line in block.lines)
            if (_inRegion(line.boundingBox, upright))
              [
                for (final element in line.elements)
                  OcrWord(element.text, element.boundingBox),
              ],
      ];
      final best = IndicatorReadingParser.candidates(
        lines,
        expectedDecimals: _expectedDecimals,
      ).firstOrNull;
      _stability.add(best?.value);
      setState(() => _candidate = best);
    } catch (error) {
      // Un cuadro que no se pudo leer no detiene al siguiente.
      debugPrint('Lector del indicador: $error');
    } finally {
      _busy = false;
    }
  }

  /// Giro de la imagen para que el texto quede derecho, según cómo está el
  /// sensor montado y cómo se sostiene el teléfono.
  InputImageRotation? _rotation(
    CameraController camera,
    CameraDescription description,
  ) {
    final sensor = description.sensorOrientation;
    if (Platform.isIOS) return InputImageRotationValue.fromRawValue(sensor);
    final device = _deviceRotation[camera.value.lockedCaptureOrientation ??
        camera.value.deviceOrientation];
    if (device == null) return null;
    final degrees = description.lensDirection == CameraLensDirection.front
        ? (sensor + device) % 360
        : (sensor - device + 360) % 360;
    return InputImageRotationValue.fromRawValue(degrees);
  }

  InputImage? _inputImage(CameraImage image, InputImageRotation rotation) {
    final raw = image.format.raw;
    final format = raw is int ? InputImageFormatValue.fromRawValue(raw) : null;
    final supported = Platform.isAndroid
        ? format == InputImageFormat.nv21
        : format == InputImageFormat.bgra8888;
    if (!supported || image.planes.length != 1) return null;
    final plane = image.planes.single;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format!,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  bool _inRegion(Rect box, Size upright) {
    final center = Offset(
      box.center.dx / upright.width,
      box.center.dy / upright.height,
    );
    // Un poco de holgura: el cuadro analizado y la vista previa pueden no
    // coincidir al píxel.
    return IndicatorReaderScreen.region.inflate(0.03).contains(center);
  }

  /// Enfoca y expone en [point], en fracciones de la imagen: tocar el
  /// display ayuda con el reflejo de los LCD.
  void _focusAt(Offset point) {
    final camera = _camera;
    if (camera == null) return;
    final clamped = Offset(point.dx.clamp(0.0, 1.0), point.dy.clamp(0.0, 1.0));
    // No todas las cámaras permiten elegir el punto; entonces se ignora.
    camera.setFocusPoint(clamped).catchError((_) {});
    camera.setExposurePoint(clamped).catchError((_) {});
  }

  Future<void> _toggleTorch() async {
    final camera = _camera;
    if (camera == null) return;
    try {
      await camera.setFlashMode(_torch ? FlashMode.off : FlashMode.torch);
      if (mounted) setState(() => _torch = !_torch);
    } on CameraException catch (_) {
      // Sin linterna en este teléfono.
    }
  }

  @override
  Widget build(BuildContext context) {
    final camera = _camera;
    final candidate = _candidate;
    final stable = candidate != null && _stability.stable;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        title: Text(
          'Leer indicador',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: _torch ? 'Apagar linterna' : 'Encender linterna',
            onPressed: camera == null ? null : _toggleTorch,
            icon: Icon(
              _torch
                  ? Icons.flashlight_off_rounded
                  : Icons.flashlight_on_rounded,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _error != null
                ? Center(child: _CameraError(message: _error!, onRetry: _start))
                : camera == null ||
                        !camera.value.isInitialized ||
                        camera.value.previewSize == null
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    : _FullPreview(
                        camera: camera,
                        stable: stable,
                        onTap: _focusAt,
                      ),
          ),
          _ReadingPanel(
            candidate: candidate,
            stable: stable,
            warnings: candidate == null
                ? const []
                : IndicatorReadingCheck.warnings(candidate, widget.balanza),
            onUse: () => Navigator.of(context).pop(candidate!.value),
          ),
        ],
      ),
    );
  }
}

/// La cámara a todo el espacio, recortando arriba y abajo, con la franja que
/// se lee marcada. La franja está en fracciones de la imagen: se lleva a la
/// pantalla con la misma escala y el mismo recorte que la vista previa, así
/// coincide con lo que analiza el OCR.
class _FullPreview extends StatelessWidget {
  const _FullPreview({
    required this.camera,
    required this.stable,
    required this.onTap,
  });

  final CameraController camera;
  final bool stable;
  final ValueChanged<Offset> onTap;

  @override
  Widget build(BuildContext context) {
    // previewSize viene acostado; la app va en vertical.
    final preview = camera.value.previewSize!;
    final image = Size(preview.height, preview.width);

    return LayoutBuilder(
      builder: (context, constraints) {
        final space = constraints.biggest;
        final scale = space.width / image.width > space.height / image.height
            ? space.width / image.width
            : space.height / image.height;
        final shown = image * scale;
        final origin = Offset(
          (space.width - shown.width) / 2,
          (space.height - shown.height) / 2,
        );
        const region = IndicatorReaderScreen.region;
        final band = Rect.fromLTRB(
          origin.dx + region.left * shown.width,
          origin.dy + region.top * shown.height,
          origin.dx + region.right * shown.width,
          origin.dy + region.bottom * shown.height,
        );

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) => onTap(Offset(
            (details.localPosition.dx - origin.dx) / shown.width,
            (details.localPosition.dy - origin.dy) / shown.height,
          )),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRect(
                child: OverflowBox(
                  maxWidth: shown.width,
                  maxHeight: shown.height,
                  child: SizedBox.fromSize(
                    size: shown,
                    child: CameraPreview(camera),
                  ),
                ),
              ),
              CustomPaint(painter: _RegionPainter(band: band, stable: stable)),
              Positioned(
                left: 16,
                right: 16,
                bottom: space.height - band.top + 10,
                child: Text(
                  'Encuadre el display dentro del recuadro',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    shadows: const [Shadow(blurRadius: 4)],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Oscurece todo menos la franja que se lee.
class _RegionPainter extends CustomPainter {
  const _RegionPainter({required this.band, required this.stable});

  final Rect band;
  final bool stable;

  @override
  void paint(Canvas canvas, Size size) {
    final hole = RRect.fromRectAndRadius(band, const Radius.circular(14));
    canvas.drawPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(Offset.zero & size)
        ..addRRect(hole),
      Paint()..color = Colors.black.withOpacity(0.55),
    );
    canvas.drawRRect(
      hole,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = stable ? AppColors.actionPositive : Colors.white,
    );
  }

  @override
  bool shouldRepaint(_RegionPainter oldDelegate) =>
      oldDelegate.stable != stable || oldDelegate.band != band;
}

class _ReadingPanel extends StatelessWidget {
  const _ReadingPanel({
    required this.candidate,
    required this.stable,
    required this.warnings,
    required this.onUse,
  });

  final IndicatorCandidate? candidate;
  final bool stable;
  final List<String> warnings;
  final VoidCallback onUse;

  @override
  Widget build(BuildContext context) {
    final status = stable
        ? 'Lectura estable: compárela con el display'
        : candidate == null
            ? 'Buscando la lectura…'
            : 'Esperando que la lectura se repita…';

    return ColoredBox(
      color: Colors.black,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                candidate?.value ?? '—',
                key: const ValueKey('indicator-reading'),
                style: GoogleFonts.robotoMono(
                  fontSize: 46,
                  fontWeight: FontWeight.w700,
                  color: stable ? Colors.white : Colors.white60,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    stable
                        ? Icons.check_circle_rounded
                        : Icons.hourglass_top_rounded,
                    size: 16,
                    color: stable ? AppColors.actionPositive : Colors.white60,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      status,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: stable ? Colors.white : Colors.white60,
                      ),
                    ),
                  ),
                ],
              ),
              for (final warning in warnings)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    warning,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.amber[300],
                    ),
                  ),
                ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white38),
                        minimumSize: const Size(0, 50),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      key: const ValueKey('indicator-use'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.actionPositive,
                        foregroundColor: AppColors.actionPositiveInk,
                        minimumSize: const Size(0, 50),
                      ),
                      onPressed: stable ? onUse : null,
                      child: Text(
                        stable ? 'Usar ${candidate!.value}' : 'Usar lectura',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CameraError extends StatelessWidget {
  const _CameraError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.no_photography_outlined,
              color: Colors.white70, size: 40),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: Colors.white, height: 1.4),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white38),
            ),
            onPressed: onRetry,
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }
}
