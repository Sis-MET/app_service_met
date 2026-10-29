import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../models/service_session.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/dialogo_permiso.dart';
import '../utils/indicator_frame.dart';
import '../utils/indicator_reading.dart';
import '../utils/seven_segment_reader.dart';
import '../../../theme/app_icons.dart';
import 'camera_frames.dart';
import 'indicator_camera_view.dart';

/// Lee el display de la balanza con la cámara.
///
/// El reconocimiento corre en el teléfono, sin internet. Solo se lee lo que
/// queda dentro del recuadro, que el técnico mueve y ajusta al display (se
/// recuerda para la próxima vez): primero como display de 7 segmentos y, si
/// no lo es, con el OCR de ML Kit. La lectura se ofrece cuando se repite en
/// varios cuadros seguidos: el técnico la compara con el display y la
/// confirma. Nunca se escribe sola en el campo.
class IndicatorReaderScreen extends StatefulWidget {
  const IndicatorReaderScreen({super.key, this.balanza});

  /// Para ubicar el punto decimal que el OCR pierda y avisar si la lectura no
  /// cuadra con la división d.
  final BalanzaInfo? balanza;

  /// Abre el lector y devuelve la lectura confirmada ("12.345"), o null. Si
  /// todavía no hay permiso de cámara, primero muestra el aviso de la app.
  static Future<String?> read(BuildContext context,
      {BalanzaInfo? balanza}) async {
    if (!await asegurarCamara(context) || !context.mounted) return null;
    return Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => IndicatorReaderScreen(balanza: balanza),
      ),
    );
  }

  /// Zona que se lee al comienzo, en fracciones de la imagen: una franja al
  /// centro donde se encuadra el display. Lo de fuera (placa, rótulos, otras
  /// pantallas) no compite con la lectura.
  static const region = Rect.fromLTRB(0.06, 0.36, 0.94, 0.64);

  /// Dónde se recuerda el recuadro que el técnico ajustó.
  static const regionKey = 'lector_indicador.region';

  /// El recuadro guardado, o [region] si no hay uno válido.
  static Rect savedRegion(SharedPreferences prefs) {
    final values = prefs.getStringList(regionKey);
    final numbers = values?.map(double.tryParse).toList();
    if (numbers == null ||
        numbers.length != 4 ||
        numbers.any((value) => value == null)) {
      return region;
    }
    final rect =
        Rect.fromLTRB(numbers[0]!, numbers[1]!, numbers[2]!, numbers[3]!);
    final valid = rect.left >= 0 &&
        rect.top >= 0 &&
        rect.right <= 1 &&
        rect.bottom <= 1 &&
        rect.width >= IndicatorCameraView.minWidth &&
        rect.height >= IndicatorCameraView.minHeight;
    return valid ? rect : region;
  }

  @override
  State<IndicatorReaderScreen> createState() => _IndicatorReaderScreenState();
}

class _IndicatorReaderScreenState extends State<IndicatorReaderScreen>
    with WidgetsBindingObserver {
  final _recognizer = TextRecognizer();
  final _stability = ReadingStability();
  late final _reader = IndicatorFrameReader(
    region: _analyzed(_region),
    expectedDecimals: IndicatorReadingCheck.expectedDecimals(widget.balanza),
    recognize: _recognize,
  );

  /// El recuadro en pantalla; lo que se analiza tiene un poco de holgura,
  /// porque el cuadro analizado y la vista previa pueden no coincidir al
  /// píxel.
  Rect _region = IndicatorReaderScreen.region;
  static Rect _analyzed(Rect region) =>
      region.inflate(0.03).intersect(const Rect.fromLTRB(0, 0, 1, 1));

  CameraController? _camera;
  CameraTuning? _tuning;
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadRegion();
    _start();
  }

  Future<void> _loadRegion() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = IndicatorReaderScreen.savedRegion(prefs);
      if (!mounted || saved == _region) return;
      _setRegion(saved);
    } catch (_) {
      // Sin preferencias se usa el recuadro de siempre.
    }
  }

  void _setRegion(Rect region) {
    setState(() {
      _region = region;
      _candidate = null;
    });
    _stability.add(null);
    _reader.region = _analyzed(region);
  }

  Future<void> _saveRegion() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(IndicatorReaderScreen.regionKey, [
        for (final value in [
          _region.left,
          _region.top,
          _region.right,
          _region.bottom
        ])
          value.toStringAsFixed(4),
      ]);
    } catch (_) {
      // No recordarlo no impide leer.
    }
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
      final (opened, description) = await abrirCamaraLector();
      camera = opened;
      if (!mounted) {
        await camera.dispose();
        return;
      }
      _camera = camera;
      _description = description;
      _torch = false;
      final tuning = CameraTuning(camera);
      _tuning = tuning;
      unawaited(tuning.load());
      await camera.startImageStream(_onFrame);
      if (mounted) setState(() => _error = null);
    } on CameraException catch (error) {
      // Sin cámara abierta a medias: "Reintentar" empieza de cero.
      _camera = null;
      await camera?.dispose();
      if (mounted) setState(() => _error = describirErrorCamara(error));
    } finally {
      _starting = false;
    }
  }

  Future<void> _stop({bool rebuild = true}) async {
    final camera = _camera;
    _camera = null;
    _tuning?.dispose();
    _tuning = null;
    _candidate = null;
    _stability.add(null);
    _reader.reset();
    if (camera == null) return;
    if (rebuild && mounted) setState(() {});
    try {
      if (camera.value.isStreamingImages) await camera.stopImageStream();
    } on CameraException catch (_) {
      // Se cierra igual.
    }
    await camera.dispose();
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
      final rotation = rotacionCuadro(camera, description);
      final frame = rotation == null ? null : cuadroDeCamara(image, rotation);
      if (frame == null) return;
      final best = await _reader.read(frame);
      if (!mounted || !identical(camera, _camera)) return;
      _stability.add(best?.value);
      setState(() => _candidate = best);
    } catch (error) {
      // Un cuadro que no se pudo leer no detiene al siguiente.
      debugPrint('Lector del indicador: $error');
      if (mounted && identical(camera, _camera)) {
        _stability.add(null);
        setState(() => _candidate = null);
      }
    } finally {
      _busy = false;
    }
  }

  /// El OCR solo ve la franja del recuadro, ya derecha: con el cuadro
  /// entero, en un display VFD encontraba los rótulos de la balanza y no
  /// los dígitos.
  Future<List<List<OcrWord>>> _recognize(GrayImage band) async {
    if (!mounted || _camera == null) return const [];
    return reconocerFranja(_recognizer, band);
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
            tooltip: 'Ajustes de cámara',
            onPressed: _tuning == null
                ? null
                : () => CameraTuning.showSheet(context, _tuning!),
            icon: const Icon(AppIcons.ajustes),
          ),
          IconButton(
            tooltip: _torch ? 'Apagar linterna' : 'Encender linterna',
            onPressed: camera == null ? null : _toggleTorch,
            icon: Icon(
              _torch ? AppIcons.linternaApagada : AppIcons.linterna,
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
                    : IndicatorCameraView(
                        camera: camera,
                        hint: 'Encuadre el display dentro del recuadro',
                        regions: [
                          CameraRegion(
                            region: _region,
                            label: 'Display',
                            highlighted: stable,
                          ),
                        ],
                        onTapFocus: _focusAt,
                        onRegionChanged: (_, region) {
                          _setRegion(region);
                          _saveRegion();
                        },
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
                    stable ? AppIcons.completo : AppIcons.espera,
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
          const Icon(AppIcons.sinFotos, color: Colors.white70, size: 40),
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
