import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_design.dart';
import '../../../theme/app_icons.dart';

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
  /// Altura de la línea de firma, como fracción del alto del lienzo.
  static const baselineFactor = 0.74;

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
    final baseline = size.height * SignaturePad.baselineFactor;
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

/// Pantalla completa, en horizontal y sin las barras del sistema, para firmar
/// con el dedo: todo el teléfono es el lienzo, salvo una franja con ✕
/// (cancelar), "Limpiar" y ✓ (aceptar). Devuelve la firma en PNG, o null si
/// se cancela.
class SignatureCaptureScreen extends StatefulWidget {
  /// Qué firma se pide ("Firma del cliente").
  final String title;

  /// Quién firma: se lee bajo la línea, como la aclaración de una firma.
  final String signerName;

  /// Qué está firmando ("RIM-0103-11-26 · 0103-11-005").
  final String documentLabel;

  const SignatureCaptureScreen({
    super.key,
    required this.title,
    required this.signerName,
    required this.documentLabel,
  });

  static Future<Uint8List?> open(
    BuildContext context, {
    required String title,
    required String signerName,
    required String documentLabel,
  }) {
    return Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => SignatureCaptureScreen(
          title: title,
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
    // La app trabaja en vertical; para firmar conviene el ancho del teléfono,
    // y sin las barras del sistema el lienzo llega a los bordes.
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
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
    // Siempre blanco, también en oscuro: es la hoja donde se firma.
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Si el teléfono no gira, la franja de botones pasa abajo.
            final horizontal = constraints.maxWidth >= constraints.maxHeight;
            return Flex(
              direction: horizontal ? Axis.horizontal : Axis.vertical,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _lienzo()),
                Container(
                  width: horizontal ? 1 : null,
                  height: horizontal ? null : 1,
                  color: Colors.black12,
                ),
                // Lo justo para el ✓ (68) con su nombre y los márgenes.
                SizedBox(
                  width: horizontal ? 112 : null,
                  height: horizontal ? null : 128,
                  child: _acciones(horizontal),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _lienzo() => LayoutBuilder(
        builder: (context, constraints) {
          final baseline = constraints.maxHeight * SignaturePad.baselineFactor;
          // Los textos no reciben toques: el trazo pasa por encima de ellos.
          return Stack(
            children: [
              Positioned.fill(child: SignaturePad(controller: _controller)),
              Positioned(
                left: 20,
                top: 14,
                right: 20,
                child: IgnorePointer(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: AppDesign.ink,
                        ),
                      ),
                      Text(
                        widget.documentLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppDesign.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 20,
                right: 20,
                bottom: constraints.maxHeight - baseline + 10,
                child: IgnorePointer(
                  child: ListenableBuilder(
                    listenable: _controller,
                    builder: (context, _) => AnimatedOpacity(
                      opacity: _controller.isEmpty ? 1 : 0,
                      duration: const Duration(milliseconds: 150),
                      child: const Text(
                        'Firme aquí con el dedo',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 15, color: Colors.black26),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 20,
                right: 20,
                top: baseline + 8,
                child: IgnorePointer(
                  child: Text(
                    widget.signerName,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black54,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      );

  Widget _acciones(bool horizontal) => ListenableBuilder(
        listenable: _controller,
        builder: (context, _) => Padding(
          padding: const EdgeInsets.all(12),
          child: Flex(
            direction: horizontal ? Axis.vertical : Axis.horizontal,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _AccionFirma(
                icon: AppIcons.cerrar,
                label: 'Cancelar',
                onPressed: _saving ? null : () => Navigator.of(context).pop(),
              ),
              _AccionFirma(
                icon: AppIcons.borrar,
                label: 'Limpiar',
                onPressed:
                    _controller.isEmpty || _saving ? null : _controller.clear,
              ),
              _AccionFirma(
                icon: AppIcons.listo,
                label: 'Aceptar',
                tooltip: 'Aceptar firma',
                primary: true,
                busy: _saving,
                onPressed:
                    _controller.hasSignature && !_saving ? _accept : null,
              ),
            ],
          ),
        ),
      );
}

/// Acción de la franja de firma: un círculo con su ícono y el nombre debajo,
/// que se tocan como un solo botón. La principal (✓) es más grande y verde.
class _AccionFirma extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? tooltip;
  final VoidCallback? onPressed;
  final bool primary;
  final bool busy;

  const _AccionFirma({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.tooltip,
    this.primary = false,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final size = primary ? 68.0 : 50.0;
    final tinta = primary
        ? (enabled ? AppColors.actionPositiveInk : Colors.black38)
        : (enabled ? Colors.black87 : Colors.black26);
    return Tooltip(
      message: tooltip ?? label,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: tooltip ?? label,
        excludeSemantics: true,
        child: InkWell(
          onTap: onPressed,
          borderRadius: AppDesign.mediumRadius,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: size,
                  height: size,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: primary
                        ? (enabled ? AppColors.actionPositive : Colors.black12)
                        : null,
                    border: primary
                        ? null
                        : Border.all(
                            color: enabled ? Colors.black38 : Colors.black12,
                          ),
                  ),
                  child: busy
                      ? SizedBox.square(
                          dimension: 26,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: tinta,
                          ),
                        )
                      : Icon(icon, size: primary ? 38 : 24, color: tinta),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: enabled ? Colors.black87 : Colors.black38,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
