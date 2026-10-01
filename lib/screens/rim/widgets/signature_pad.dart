import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../theme/app_design.dart';
import '../../../widgets/service_ui/service_app_bar.dart';

/// Trazos de una firma hecha con el dedo.
class SignaturePadController extends ChangeNotifier {
  /// Largo mínimo del trazo, en píxeles lógicos, para contar como firma: un
  /// toque suelto o una rayita no lo son.
  static const minLength = 60.0;

  static const _strokeWidth = 2.6;

  final List<List<Offset>> _strokes = [];

  List<List<Offset>> get strokes => _strokes;

  bool get isEmpty => _strokes.isEmpty;

  /// Hay un trazo suficiente para aceptarlo como firma.
  bool get hasSignature {
    var length = 0.0;
    for (final stroke in _strokes) {
      for (var i = 1; i < stroke.length; i++) {
        length += (stroke[i] - stroke[i - 1]).distance;
        if (length >= minLength) return true;
      }
    }
    return false;
  }

  void start(Offset point) {
    _strokes.add([point]);
    notifyListeners();
  }

  void extend(Offset point) {
    if (_strokes.isEmpty) return;
    _strokes.last.add(point);
    notifyListeners();
  }

  void clear() {
    if (_strokes.isEmpty) return;
    _strokes.clear();
    notifyListeners();
  }

  static Paint _paint(double scale) => Paint()
    ..color = Colors.black
    ..style = PaintingStyle.stroke
    ..strokeWidth = _strokeWidth * scale
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  /// Dibuja los trazos suavizados; un toque suelto queda como punto.
  static void paintStrokes(
    Canvas canvas,
    List<List<Offset>> strokes, {
    Offset origin = Offset.zero,
    double scale = 1,
  }) {
    final paint = _paint(scale);
    Offset map(Offset point) => (point - origin) * scale;
    for (final stroke in strokes) {
      if (stroke.length == 1) {
        canvas.drawCircle(
          map(stroke.first),
          paint.strokeWidth / 2,
          Paint()..color = Colors.black,
        );
        continue;
      }
      final path = Path()..moveTo(map(stroke.first).dx, map(stroke.first).dy);
      for (var i = 1; i < stroke.length - 1; i++) {
        final current = map(stroke[i]);
        final middle = (current + map(stroke[i + 1])) / 2;
        path.quadraticBezierTo(current.dx, current.dy, middle.dx, middle.dy);
      }
      final last = map(stroke.last);
      path.lineTo(last.dx, last.dy);
      canvas.drawPath(path, paint);
    }
  }

  /// La firma en PNG, recortada a lo dibujado y sobre fondo blanco, para que
  /// se vea igual en el PDF y en cualquier visor. Null si no hay firma.
  Future<Uint8List?> toPng({int longestSide = 900}) async {
    if (isEmpty) return null;
    var bounds = Rect.fromPoints(_strokes.first.first, _strokes.first.first);
    for (final stroke in _strokes) {
      for (final point in stroke) {
        bounds = bounds.expandToInclude(Rect.fromPoints(point, point));
      }
    }
    bounds = bounds.inflate(12);
    final scale = longestSide / math.max(bounds.width, bounds.height);
    final width = math.max(1, (bounds.width * scale).round());
    final height = math.max(1, (bounds.height * scale).round());

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      Paint()..color = Colors.white,
    );
    paintStrokes(canvas, _strokes, origin: bounds.topLeft, scale: scale);
    final image = await recorder.endRecording().toImage(width, height);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }
}

/// Lienzo blanco donde se firma con el dedo.
class SignaturePad extends StatelessWidget {
  final SignaturePadController controller;

  const SignaturePad({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    // Listener en vez de un detector de gestos: el trazo empieza en el
    // primer contacto, sin esperar a que se resuelva el gesto.
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (event) => controller.start(event.localPosition),
      onPointerMove: (event) => controller.extend(event.localPosition),
      child: ClipRect(
        child: CustomPaint(
          painter: _SignaturePainter(controller),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _SignaturePainter extends CustomPainter {
  final SignaturePadController controller;

  _SignaturePainter(this.controller) : super(repaint: controller);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    final baseline = size.height * 0.74;
    canvas.drawLine(
      Offset(size.width * 0.08, baseline),
      Offset(size.width * 0.92, baseline),
      Paint()
        ..color = Colors.black26
        ..strokeWidth = 1,
    );
    SignaturePadController.paintStrokes(canvas, controller.strokes);
  }

  @override
  bool shouldRepaint(_SignaturePainter oldDelegate) =>
      oldDelegate.controller != controller;
}

/// Pantalla completa, en horizontal, para que el cliente firme con el dedo.
/// Devuelve la firma en PNG, o null si se cancela.
class SignatureCaptureScreen extends StatefulWidget {
  /// Quién firma, para que lo lea antes de firmar.
  final String signerName;

  /// Qué está firmando ("RIM-0103-11-26 · 0103-11-005").
  final String documentLabel;

  const SignatureCaptureScreen({
    super.key,
    required this.signerName,
    required this.documentLabel,
  });

  static Future<Uint8List?> open(
    BuildContext context, {
    required String signerName,
    required String documentLabel,
  }) {
    return Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => SignatureCaptureScreen(
          signerName: signerName,
          documentLabel: documentLabel,
        ),
      ),
    );
  }

  @override
  State<SignatureCaptureScreen> createState() => _SignatureCaptureScreenState();
}

class _SignatureCaptureScreenState extends State<SignatureCaptureScreen> {
  final _controller = SignaturePadController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // La app trabaja en vertical; para firmar conviene el ancho del teléfono.
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _accept() async {
    if (_saving || !_controller.hasSignature) return;
    setState(() => _saving = true);
    final png = await _controller.toPng();
    if (!mounted) return;
    Navigator.of(context).pop(png);
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Scaffold(
      appBar: ServiceAppBar(
        title: 'Firma del cliente',
        subtitle: widget.documentLabel,
        leading: Center(
          child: IconButton(
            tooltip: 'Cancelar',
            icon: const Icon(Icons.close_rounded),
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Firma de ${widget.signerName}. Firme con el dedo sobre la '
                'línea.',
                style: TextStyle(fontSize: 13, color: muted),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: AppDesign.smallRadius,
                    border: Border.all(color: muted.withValues(alpha: 0.5)),
                  ),
                  child: ClipRRect(
                    borderRadius: AppDesign.smallRadius,
                    child: SignaturePad(controller: _controller),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              ListenableBuilder(
                listenable: _controller,
                builder: (context, _) => Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _controller.isEmpty || _saving
                          ? null
                          : _controller.clear,
                      icon: const Icon(Icons.backspace_outlined),
                      label: const Text('Limpiar'),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed:
                          _controller.hasSignature && !_saving ? _accept : null,
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Aceptar firma'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
