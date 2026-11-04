import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../services/pantalla_encendida.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_icons.dart';
import '../../../utils/foto_helper.dart';
import '../../../widgets/dialogo_permiso.dart';
import '../../calibracion/utils/indicator_frame.dart';
import '../../calibracion/utils/indicator_reading.dart';
import '../../calibracion/utils/needle_reader.dart';
import '../../calibracion/utils/png_encoder.dart';
import '../../calibracion/utils/profile_search.dart';
import '../../calibracion/utils/reading_profile.dart';
import '../../calibracion/utils/seven_segment_reader.dart';
import '../../calibracion/widgets/camera_frames.dart';
import '../../calibracion/widgets/indicator_camera_view.dart';
import '../controllers/temperatura_controller.dart';
import '../models/temperatura_models.dart';
import '../widgets/temp_grafico.dart';
import '../widgets/temp_ui.dart';
import 'captura_programada.dart';

/// La medición programada de un punto con la cámara: cada display en su
/// recuadro, una lectura por intervalo durante el lapso configurado, y
/// cada lectura guardada en el momento con su imagen.
///
/// Antes de iniciar se encuadran los displays y se puede «Verificar
/// lectura»; durante la medición la pantalla queda encendida. Si la app
/// sale de primer plano, el horario sigue y lo que no se pudo tomar queda
/// «sin lectura» con su motivo.
class CapturaTemperaturaScreen extends StatefulWidget {
  const CapturaTemperaturaScreen({
    super.key,
    required this.controller,
    required this.nPunto,
  });

  final TemperaturaController controller;
  final int nPunto;

  static Future<void> abrir(
    BuildContext context,
    TemperaturaController controller,
    int nPunto,
  ) async {
    final conCamara =
        controller.canales.any((c) => c.metodo == MetodoCanal.camara);
    if (conCamara && (!await asegurarCamara(context) || !context.mounted)) {
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            CapturaTemperaturaScreen(controller: controller, nPunto: nPunto),
      ),
    );
    await controller.recargar();
  }

  /// Dónde se recuerda el perfil del lector de un patrón o un equipo.
  static String perfilKey(TempCanal canal, TempServicio servicio) =>
      'lector_temperatura.perfil.${canal.rol == RolCanal.patron ? canal.codPatron ?? canal.nombre : 'equipo:${servicio.equipo?.codMetrica}'}';

  /// Recuadro de inicio para un indicador de aguja: un cuadrado al centro
  /// (en una imagen vertical 9:16).
  static const regionDial = Rect.fromLTWH(0.12, 0.29, 0.76, 0.43);

  /// Recuadros de inicio para [cantidad] displays: franjas una debajo de
  /// otra, al centro.
  static List<Rect> regionesIniciales(int cantidad) {
    if (cantidad <= 0) return const [];
    if (cantidad == 1) return const [Rect.fromLTRB(0.06, 0.36, 0.94, 0.64)];
    const top = 0.14, bottom = 0.86, gap = 0.04;
    final alto = (bottom - top - gap * (cantidad - 1)) / cantidad;
    return [
      for (var i = 0; i < cantidad; i++)
        Rect.fromLTWH(0.06, top + i * (alto + gap), 0.88, alto),
    ];
  }

  @override
  State<CapturaTemperaturaScreen> createState() =>
      _CapturaTemperaturaScreenState();
}

class _CapturaTemperaturaScreenState extends State<CapturaTemperaturaScreen>
    with WidgetsBindingObserver {
  TemperaturaController get _c => widget.controller;

  late List<TempCanal> _canales;
  final _recognizer = TextRecognizer();
  late IndicatorFrameReader _reader;
  CameraController? _camera;
  CameraDescription? _description;
  CameraTuning? _tuning;
  bool _starting = false;
  bool _busy = false;
  bool _torch = false;
  String? _error;
  DateTime _lastFrame = DateTime.fromMillisecondsSinceEpoch(0);

  /// Lo que se ve ahora en cada canal de cámara (n → lectura).
  final Map<int, IndicatorCandidate?> _vivo = {};

  /// Dónde ve la aguja el lector en cada indicador analógico (n → lectura).
  final Map<int, NeedleReading?> _agujas = {};

  /// Canales cuyo recuadro o escala falta guardar.
  final Set<int> _porGuardar = {};

  /// Los últimos cuadros, para «Verificar lectura».
  final List<CameraFrame> _recientes = [];

  CapturaProgramada? _captura;
  Timer? _ticker;
  Timer? _guardarRegiones;
  bool _terminando = false;
  Set<int> _manualesAvisados = {};
  final Map<int, TextEditingController> _manuales = {};

  TempPunto get _punto => _c.puntos.firstWhere((p) => p.n == widget.nPunto);
  List<TempCanal> get _camara =>
      _canales.where((c) => c.metodo == MetodoCanal.camara).toList();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Los sensores del patrón graban en su software: aquí solo el indicador.
    _canales = _conRegiones(_c.canales.where((c) => c.metodo.seLee).toList());
    _reader = IndicatorFrameReader.multi(
      regions: _regiones(),
      recognize: _recognize,
    );
    _cargarPerfiles();
    if (_camara.isNotEmpty) _start();
    if (_punto.estado == EstadoPunto.enCurso) _iniciarCaptura();
  }

  /// El indicador del equipo cuando es de aguja: se lee con la escala que
  /// marca el técnico.
  bool _esAguja(TempCanal canal) =>
      canal.rol == RolCanal.equipo &&
      esIndicadorAnalogico(_c.servicio.equipo?.indicador);

  /// Los canales de cámara sin recuadro reciben uno de inicio; un indicador
  /// de aguja, además, una escala de inicio dentro de su recuadro.
  List<TempCanal> _conRegiones(List<TempCanal> canales) {
    final camara =
        canales.where((c) => c.metodo == MetodoCanal.camara).toList();
    final iniciales = CapturaTemperaturaScreen.regionesIniciales(camara.length);
    final resultado = <TempCanal>[];
    var i = 0;
    for (final canal in canales) {
      if (canal.metodo != MetodoCanal.camara) {
        resultado.add(canal);
        continue;
      }
      final aguja = _esAguja(canal);
      final region = canal.region ??
          (aguja ? CapturaTemperaturaScreen.regionDial : iniciales[i]);
      final esDial = canal.perfil?.engine == IndicatorEngine.aguja &&
          canal.perfil?.dial != null;
      resultado.add(switch ((aguja, esDial)) {
        (true, false) => canal.copyWith(
            region: region, perfil: ReadingProfile.aguja(_dialInicial(region))),
        // El equipo dejó de ser analógico: vuelve a leerse como display.
        (false, true) => canal.copyWith(region: region, clearPerfil: true),
        _ => canal.copyWith(region: region),
      });
      i++;
    }
    return resultado;
  }

  /// Una escala de 270° dentro de [region], con los valores del rango del
  /// equipo; el técnico ajusta las marcas y sus valores.
  DialScale _dialInicial(Rect region) {
    final equipo = _c.servicio.equipo;
    final desde = equipo?.rangoMin ?? 0;
    final hasta = equipo?.rangoMax != null && equipo!.rangoMax! > desde
        ? equipo.rangoMax!
        : desde + 100;
    return DialScale.inicial(region, desde: desde, hasta: hasta);
  }

  List<IndicatorRegion> _regiones() => [
        for (final canal in _camara)
          IndicatorRegion(
            region: canal.region!
                .inflate(0.02)
                .intersect(const Rect.fromLTRB(0, 0, 1, 1)),
            profile: canal.perfil?.engine == IndicatorEngine.aguja
                ? canal.perfil!
                : (canal.perfil ?? ReadingProfile.temperatura)
                    .copyWith(units: true),
            expectedDecimals: canal.decimales,
            step: _c.servicio.equipo?.resolucion,
          ),
      ];

  /// El perfil que se fijó la última vez para el mismo patrón o equipo.
  Future<void> _cargarPerfiles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var cambio = false;
      for (var i = 0; i < _canales.length; i++) {
        final canal = _canales[i];
        if (canal.metodo != MetodoCanal.camara || canal.perfil != null) {
          continue;
        }
        final json = prefs
            .getString(CapturaTemperaturaScreen.perfilKey(canal, _c.servicio));
        if (json == null) continue;
        final decoded = jsonDecode(json);
        if (decoded is! Map) continue;
        _canales[i] = canal.copyWith(
            perfil: ReadingProfile.fromJson(decoded.cast<String, Object?>()));
        cambio = true;
      }
      if (cambio && mounted) {
        setState(() {});
        _reader.regions = _regiones();
      }
    } catch (_) {
      // Sin perfil recordado se lee en automático.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _captura?.pausar();
      _stop();
    } else if (state == AppLifecycleState.resumed) {
      _captura?.reanudar();
      _captura?.tick();
      if (_camara.isNotEmpty) _start();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _guardarRegiones?.cancel();
    _guardarLector();
    _captura?.removeListener(_alCambiarCaptura);
    _captura?.dispose();
    PantallaEncendida.mantener(false);
    _stop(rebuild: false);
    _recognizer.close();
    for (final controller in _manuales.values) {
      controller.dispose();
    }
    super.dispose();
  }

  // ── Cámara ────────────────────────────────────────────────────────────

  Future<void> _start() async {
    if (_camera != null || _starting) return;
    _starting = true;
    CameraController? camera;
    try {
      // Más resolución: el teléfono suele estar lejos del equipo caliente.
      final (opened, description) =
          await abrirCamaraLector(resolucion: ResolutionPreset.veryHigh);
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
    _vivo.clear();
    _agujas.clear();
    _reader.reset();
    if (camera == null) return;
    if (rebuild && mounted) setState(() {});
    try {
      if (camera.value.isStreamingImages) await camera.stopImageStream();
    } on CameraException catch (_) {}
    await camera.dispose();
  }

  Future<List<List<OcrWord>>> _recognize(GrayImage band) async {
    if (!mounted || _camera == null) return const [];
    return reconocerFranja(_recognizer, band);
  }

  Future<void> _onFrame(CameraImage image) async {
    final now = DateTime.now();
    final camera = _camera;
    final description = _description;
    // Durante una ráfaga, unos 4 cuadros por segundo; entre lecturas basta
    // uno por segundo para mostrar el valor en vivo sin calentar el
    // teléfono durante 45 minutos.
    final rafaga = _captura?.necesitaCuadros ?? false;
    final gap = rafaga
        ? const Duration(milliseconds: 220)
        : const Duration(milliseconds: 900);
    if (_busy ||
        camera == null ||
        description == null ||
        now.difference(_lastFrame) < gap) {
      return;
    }
    _busy = true;
    _lastFrame = now;
    try {
      final rotation = rotacionCuadro(camera, description);
      final frame = rotation == null
          ? null
          : cuadroDeCamara(image, rotation, copiar: _captura == null);
      if (frame == null) return;
      if (_captura == null) {
        _recientes.add(frame);
        if (_recientes.length > 3) _recientes.removeAt(0);
      }
      final lecturas = await _reader.readAll(frame);
      if (!mounted || !identical(camera, _camera) || lecturas.isEmpty) return;
      final camara = _camara;
      for (var i = 0; i < camara.length && i < lecturas.length; i++) {
        _vivo[camara[i].n] = lecturas[i].candidate;
        _agujas[camara[i].n] = lecturas[i].needle;
      }
      await _captura?.cuadro(lecturas);
      if (mounted) setState(() {});
    } catch (error) {
      debugPrint('Captura de temperatura: $error');
    } finally {
      _busy = false;
    }
  }

  void _focusAt(Offset point) {
    final camera = _camera;
    if (camera == null) return;
    final clamped = Offset(point.dx.clamp(0.0, 1.0), point.dy.clamp(0.0, 1.0));
    camera.setFocusPoint(clamped).catchError((_) {});
    camera.setExposurePoint(clamped).catchError((_) {});
  }

  Future<void> _toggleTorch() async {
    final camera = _camera;
    if (camera == null) return;
    try {
      await camera.setFlashMode(_torch ? FlashMode.off : FlashMode.torch);
      if (mounted) setState(() => _torch = !_torch);
    } on CameraException catch (_) {}
  }

  /// El recuadro se movió o cambió de tamaño; la escala de un dial lo
  /// acompaña.
  void _moverRegion(int indice, Rect region) {
    final canal = _camara[indice];
    final perfil = canal.perfil;
    final dial = perfil?.engine == IndicatorEngine.aguja ? perfil?.dial : null;
    _cambiarLector(
      canal.copyWith(
        region: region,
        perfil: dial == null
            ? null
            : perfil!.copyWith(dial: dial.mapped(canal.region!, region)),
      ),
    );
  }

  /// El técnico movió el eje o una marca de la escala del dial.
  void _moverDial(int indice, DialScale dial) {
    final canal = _camara[indice];
    final perfil = canal.perfil;
    if (perfil == null) return;
    _cambiarLector(canal.copyWith(perfil: perfil.copyWith(dial: dial)));
  }

  /// El recuadro o la escala de [canal] cambiaron: lo que se estaba leyendo
  /// se descarta y se guarda al rato (se mueven con el dedo).
  void _cambiarLector(TempCanal canal) {
    setState(() {
      final i = _canales.indexWhere((c) => c.n == canal.n);
      _canales[i] = canal;
      _vivo.remove(canal.n);
      _agujas.remove(canal.n);
    });
    _reader.regions = _regiones();
    _porGuardar.add(canal.n);
    _guardarRegiones?.cancel();
    _guardarRegiones =
        Timer(const Duration(milliseconds: 600), _guardarLector);
  }

  void _guardarLector() {
    for (final n in _porGuardar) {
      final canal = _canales.firstWhere((c) => c.n == n);
      _c.store.guardarLectorCanal(
        _c.servicio.uuid,
        n,
        region: canal.region,
        perfil: canal.perfil,
      );
    }
    _porGuardar.clear();
  }

  /// Cambia el valor de la marca [k] del dial: el valor de la escala donde
  /// el técnico la puso.
  Future<void> _editarMarca(int indice, int k) async {
    final canal = _camara[indice];
    final dial = canal.perfil?.dial;
    if (dial == null || _captura != null) return;
    final marcas = dial.marks;
    final anterior = k > 0 ? marcas[k - 1].value : null;
    final siguiente = k < marcas.length - 1 ? marcas[k + 1].value : null;
    final unidad = _c.servicio.equipo?.unidad ?? '°C';
    final valor = await _pedirValor(
      titulo: switch (k) {
        0 => 'Inicio de la escala',
        _ when k == marcas.length - 1 => 'Fin de la escala',
        _ => 'Marca intermedia',
      },
      mensaje: 'Valor de la escala donde está esta marca. Póngala sobre una '
          'raya con número, por ejemplo ${textoNumero(marcas[k].value)}.',
      etiqueta: 'Valor de la marca',
      inicial: textoNumero(marcas[k].value),
      validar: (v) {
        if (anterior != null && v <= anterior) {
          return 'Debe ser mayor que ${textoNumero(anterior)} $unidad.';
        }
        if (siguiente != null && v >= siguiente) {
          return 'Debe ser menor que ${textoNumero(siguiente)} $unidad.';
        }
        return null;
      },
    );
    if (valor == null || !mounted) return;
    _moverDial(indice, dial.withMark(k, marcas[k].copyWith(value: valor)));
  }

  /// Pide un número; [validar] devuelve el error, o null si sirve.
  Future<double?> _pedirValor({
    required String titulo,
    required String mensaje,
    required String etiqueta,
    String? inicial,
    String? Function(double valor)? validar,
  }) {
    final unidad = _c.servicio.equipo?.unidad ?? '°C';
    return showDialog<double>(
      context: context,
      builder: (dialogContext) {
        final texto = TextEditingController(text: inicial);
        String? error;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void aceptar() {
              final valor = ProfileSearch.parse(texto.text);
              final problema = valor == null
                  ? 'Escriba un número.'
                  : validar?.call(valor);
              if (problema != null) {
                setDialogState(() => error = problema);
                return;
              }
              Navigator.pop(dialogContext, valor);
            }

            return AlertDialog(
              title: Text(titulo),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(mensaje),
                  const SizedBox(height: 12),
                  TextField(
                    controller: texto,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true, signed: true),
                    decoration: InputDecoration(
                      labelText: etiqueta,
                      suffixText: unidad,
                      errorText: error,
                      border: const OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => aceptar(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: aceptar,
                  child: const Text('Aceptar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ── Verificar lectura ─────────────────────────────────────────────────

  /// En un indicador de aguja no hay maneras de leer que probar: se compara
  /// lo que ve el técnico con lo que lee la cámara.
  Future<void> _verificarAguja(TempCanal canal) async {
    final unidad = _c.servicio.equipo?.unidad ?? '°C';
    final visto = await _pedirValor(
      titulo: 'Verificar ${canal.nombre}',
      mensaje: 'Escriba el valor que marca la aguja ahora, mirándola de '
          'frente.',
      etiqueta: 'Valor de la aguja',
    );
    if (visto == null || !mounted) return;
    final leido = _vivo[canal.n];
    final numero = leido?.number;
    if (leido == null || numero == null) {
      _mensaje('La cámara todavía no ve la aguja: ajuste el recuadro al '
          'dial, el centro al eje y las marcas sobre sus valores.');
      return;
    }
    final tolerancia = _c.servicio.equipo?.resolucion ?? 1;
    if ((numero - visto).abs() <= tolerancia + 1e-9) {
      _mensaje('Coincide: la cámara lee ${leido.value} $unidad.');
    } else {
      _mensaje('La cámara lee ${leido.value} $unidad y usted ve '
          '${textoNumero(visto)} $unidad. Acerque el centro al eje de la '
          'aguja y cada marca a su raya de la escala.');
    }
  }

  Future<void> _verificar(TempCanal canal) async {
    if (canal.perfil?.engine == IndicatorEngine.aguja) {
      return _verificarAguja(canal);
    }
    final frames = List.of(_recientes);
    if (frames.isEmpty) {
      _mensaje('Espere a que la cámara muestre el display.');
      return;
    }
    final visto = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final texto = TextEditingController();
        return AlertDialog(
          title: Text('Verificar ${canal.nombre}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Escriba exactamente lo que muestra el display '
                  'ahora. El lector buscará la manera de leerlo igual.'),
              const SizedBox(height: 12),
              TextField(
                controller: texto,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true, signed: true),
                decoration: InputDecoration(
                  labelText: 'Valor del display',
                  suffixText: _c.servicio.equipo?.unidad ?? '°C',
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, texto.text),
              child: const Text('Buscar'),
            ),
          ],
        );
      },
    );
    if (visto == null || ProfileSearch.parse(visto) == null || !mounted) return;
    final progreso = ValueNotifier<double>(0);
    var cancelado = false;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Probando maneras de leer…'),
        content: ValueListenableBuilder<double>(
          valueListenable: progreso,
          builder: (_, valor, __) => LinearProgressIndicator(value: valor),
        ),
        actions: [
          TextButton(
            onPressed: () {
              cancelado = true;
              Navigator.pop(dialogContext);
            },
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
    final perfil = await ProfileSearch.find(
      frames: frames,
      region: canal.region!
          .inflate(0.02)
          .intersect(const Rect.fromLTRB(0, 0, 1, 1)),
      expected: visto,
      recognize: (band) => reconocerFranja(_recognizer, band),
      expectedDecimals: canal.decimales,
      units: true,
      onProgress: (tried, total) => progreso.value = tried / total,
      cancelled: () => cancelado || !mounted,
    );
    if (!mounted) return;
    if (!cancelado) Navigator.of(context).pop();
    progreso.dispose();
    if (cancelado) return;
    if (perfil == null) {
      _mensaje('No se logró leer $visto en este display. Ajuste el '
          'recuadro, el zoom o la exposición y vuelva a intentar.');
      return;
    }
    setState(() {
      final i = _canales.indexWhere((c) => c.n == canal.n);
      _canales[i] = _canales[i].copyWith(perfil: perfil);
    });
    _reader.regions = _regiones();
    await _c.store
        .guardarLectorCanal(_c.servicio.uuid, canal.n, perfil: perfil);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          CapturaTemperaturaScreen.perfilKey(canal, _c.servicio),
          jsonEncode(perfil.toJson()));
    } catch (_) {}
    _mensaje('Listo: ${canal.nombre} se lee con ${perfil.descripcion}.');
  }

  void _mensaje(String texto) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texto)));
  }

  // ── Medición ──────────────────────────────────────────────────────────

  Future<void> _iniciar() async {
    final punto = _punto;
    final sinLectura = _camara.where((c) => _vivo[c.n]?.isNumber != true);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(AppIcons.hora),
        title: const Text('Iniciar medición'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Se tomarán ${punto.lecturas} lecturas cada '
                '${punto.intervaloS} s durante '
                '${textoNumero(punto.duracionMin)} min.'),
            const SizedBox(height: 10),
            const Text('Deje el teléfono fijo, con la app abierta: la '
                'pantalla se mantendrá encendida.'),
            if (_c.canales.any((c) => !c.metodo.seLee)) ...[
              const SizedBox(height: 10),
              Text('Inicie ahora el registro de los sensores del patrón en su '
                  'software, con el mismo intervalo (${punto.intervaloS} s).'),
            ],
            if (sinLectura.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Todavía no se lee: ${sinLectura.map((c) => c.nombre).join(', ')}.',
                style: const TextStyle(color: AppColors.actionNegative),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Todavía no'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Iniciar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final error = await _c.iniciarPunto(punto.n);
    if (!mounted) return;
    if (error != null) {
      _mensaje(error);
      return;
    }
    _iniciarCaptura();
  }

  void _iniciarCaptura() {
    final punto = _punto;
    final equipo = _c.servicio.equipo;
    final captura = CapturaProgramada(
      punto: punto,
      canales: _canales,
      registrar: (lectura) =>
          _c.store.registrarLectura(_c.servicio.uuid, lectura),
      guardarImagen: _guardarImagen,
      expectativas: {
        for (final canal in _canales)
          canal.n: CapturaProgramada.expectativasDe(canal,
              punto: punto, equipo: equipo),
      },
      previas: _c.lecturas,
    );
    captura.addListener(_alCambiarCaptura);
    _captura = captura;
    _recientes.clear();
    PantallaEncendida.mantener(true);
    _ticker = Timer.periodic(
        const Duration(milliseconds: 250), (_) => captura.tick());
    captura.tick();
    setState(() {});
  }

  Future<String?> _guardarImagen(
      GrayImage imagen, int nLectura, int nCanal) async {
    try {
      final s = _c.servicio;
      final dir = await FotoHelper.getInstrumentoDir(
        s.seca ?? 'SIN-SECA',
        s.equipo?.codMetrica ?? 'SIN-CODIGO',
        subDirName: 'temperatura',
      );
      final bytes = await Isolate.run(() => encodeGrayPng(imagen));
      final nombre =
          'P${widget.nPunto}_L${nLectura.toString().padLeft(3, '0')}_C$nCanal.png';
      final path = p.join(dir.path, nombre);
      await File(path).writeAsBytes(bytes, flush: true);
      return path;
    } catch (error) {
      // Sin imagen la lectura se registra igual.
      debugPrint('No se pudo guardar la imagen de la lectura: $error');
      return null;
    }
  }

  void _alCambiarCaptura() {
    final captura = _captura;
    if (captura == null || !mounted) return;
    final pendientes = captura.pendientesManuales.map((c) => c.n).toSet();
    // Un aviso al aparecer una lectura para escribir a mano.
    if (pendientes.difference(_manualesAvisados).isNotEmpty) {
      HapticFeedback.heavyImpact();
    }
    _manualesAvisados = pendientes;
    if (captura.terminada && !_terminando) _terminar();
    setState(() {});
  }

  Future<void> _terminar() async {
    _terminando = true;
    _ticker?.cancel();
    PantallaEncendida.mantener(false);
    final error = await _c.completarPunto(widget.nPunto);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(AppIcons.completo, color: AppColors.actionPositive),
        title: const Text('Medición terminada'),
        content: Text(error ??
            'Se completaron las ${_punto.lecturas} lecturas del punto '
                '${widget.nPunto}.'),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Ver resultados'),
          ),
        ],
      ),
    );
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _registrarManual(TempCanal canal) async {
    final controller = _manuales[canal.n];
    final valor = ProfileSearch.parse(controller?.text ?? '');
    if (valor == null) {
      _mensaje('Escriba el valor de ${canal.nombre}.');
      return;
    }
    final error = await _captura?.manual(canal.n, valor);
    if (!mounted) return;
    if (error != null) {
      _mensaje(error);
    } else {
      controller?.clear();
    }
  }

  Future<void> _salir() async {
    final captura = _captura;
    if (captura == null || captura.terminada) {
      Navigator.of(context).pop();
      return;
    }
    final accion = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('La medición sigue en curso'),
        content: const Text(
          'Si sale sin detenerla, el horario continúa: las lecturas que no '
          'se tomen quedarán «sin lectura» y podrá continuarla desde el paso '
          'Medición.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'salir'),
            child: const Text('Salir sin detener'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'detener'),
            child: const Text('Detener'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Seguir midiendo'),
          ),
        ],
      ),
    );
    if (!mounted || accion == null) return;
    if (accion == 'detener') {
      await _detener();
      return;
    }
    Navigator.of(context).pop();
  }

  Future<void> _detener() async {
    final motivo = await pedirMotivo(
      context,
      titulo: 'Detener la medición',
      mensaje: 'Las lecturas tomadas se conservan. El punto queda '
          'interrumpido con este motivo.',
      accion: 'Detener',
      destructivo: true,
    );
    if (motivo == null || !mounted) return;
    _ticker?.cancel();
    _terminando = true;
    final error = await _c.detenerPunto(widget.nPunto, motivo);
    if (!mounted) return;
    if (error != null) {
      _terminando = false;
      _mensaje(error);
      return;
    }
    Navigator.of(context).pop();
  }

  // ── Pantalla ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final camera = _camera;
    final punto = _punto;
    final unidad = _c.servicio.equipo?.unidad ?? '°C';
    final captura = _captura;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _salir();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          systemOverlayStyle: SystemUiOverlayStyle.light,
          title: Text(
            'Punto ${punto.n} · ${textoNumero(punto.temperaturaNominal)} $unidad',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
          ),
          actions: [
            if (_camara.isNotEmpty) ...[
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
                icon:
                    Icon(_torch ? AppIcons.linternaApagada : AppIcons.linterna),
              ),
            ],
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: _camara.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Todos los canales son manuales: escriba cada lectura '
                          'cuando se pida.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(color: Colors.white70),
                        ),
                      ),
                    )
                  : _error != null
                      ? Center(
                          child:
                              _CameraError(message: _error!, onRetry: _start))
                      : camera == null ||
                              !camera.value.isInitialized ||
                              camera.value.previewSize == null
                          ? const Center(
                              child: CircularProgressIndicator(
                                  color: Colors.white))
                          : IndicatorCameraView(
                              camera: camera,
                              hint: captura == null
                                  ? (_camara.any(_esAguja)
                                      ? 'Recuadro sobre el dial, la cruz en el '
                                          'eje de la aguja y cada marca sobre '
                                          'su valor (tóquela para cambiarlo)'
                                      : _camara.length == 1
                                          ? 'Encuadre el indicador del equipo en el recuadro'
                                          : 'Encuadre cada display en su recuadro')
                                  : null,
                              regions: [
                                for (final canal in _camara)
                                  CameraRegion(
                                    region: canal.region!,
                                    label: canal.nombre,
                                    color: colorCanal(canal, _canales),
                                    value: _vivo[canal.n]?.value,
                                    highlighted: captura?.estadoDe(canal.n) ==
                                        EstadoCanalCaptura.tomada,
                                    dial: canal.perfil?.engine ==
                                            IndicatorEngine.aguja
                                        ? canal.perfil?.dial
                                        : null,
                                    needleAngle: _agujas[canal.n]?.angle,
                                  ),
                              ],
                              onTapFocus: _focusAt,
                              onRegionChanged: _moverRegion,
                              onDialChanged: _moverDial,
                              onMarkTap: captura == null ? _editarMarca : null,
                            ),
            ),
            _Panel(
              punto: punto,
              unidad: unidad,
              canales: _canales,
              vivo: _vivo,
              captura: captura,
              lecturas: captura?.lecturas ?? const [],
              manuales: _manuales,
              onVerificar: _verificar,
              onIniciar: _iniciar,
              onDetener: _detener,
              onManual: _registrarManual,
            ),
          ],
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.punto,
    required this.unidad,
    required this.canales,
    required this.vivo,
    required this.captura,
    required this.lecturas,
    required this.manuales,
    required this.onVerificar,
    required this.onIniciar,
    required this.onDetener,
    required this.onManual,
  });

  final TempPunto punto;
  final String unidad;
  final List<TempCanal> canales;
  final Map<int, IndicatorCandidate?> vivo;
  final CapturaProgramada? captura;
  final List<TempLectura> lecturas;
  final Map<int, TextEditingController> manuales;
  final ValueChanged<TempCanal> onVerificar;
  final VoidCallback onIniciar;
  final VoidCallback onDetener;
  final ValueChanged<TempCanal> onManual;

  static String _hora(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  static String _cuenta(Duration d) {
    final s = d.inSeconds.clamp(0, 359999);
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final captura = this.captura;
    final white = GoogleFonts.inter(color: Colors.white, fontSize: 13);
    final muted = GoogleFonts.inter(color: Colors.white60, fontSize: 12.5);
    return ColoredBox(
      color: Colors.black,
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.5),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (captura != null) ...[
                  Builder(builder: (context) {
                    final ahora = DateTime.now();
                    final proxima = captura.horario.hastaLaProxima(ahora);
                    final n = captura.actual;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          captura.terminada
                              ? 'Medición terminada'
                              : 'Lectura ${(n ?? 0) + 1} de ${punto.lecturas}'
                                  '${proxima == null ? '' : ' · próxima en ${_cuenta(proxima)}'}'
                                  ' · fin ${_hora(captura.horario.ultima)}',
                          key: const ValueKey('captura-estado'),
                          style: white.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        LinearProgressIndicator(
                          value: captura.completas / punto.lecturas,
                          color: AppColors.actionPositive,
                          backgroundColor: Colors.white12,
                        ),
                        if (captura.pausada)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text('Cámara detenida: vuelva a la app.',
                                style:
                                    muted.copyWith(color: Colors.amber[300])),
                          ),
                      ],
                    );
                  }),
                  const SizedBox(height: 12),
                ],
                for (final canal in canales)
                  _FilaCanal(
                    canal: canal,
                    color: colorCanal(canal, canales),
                    unidad: unidad,
                    vivo: vivo[canal.n],
                    ultima: captura?.ultimas[canal.n],
                    estado: captura?.estadoDe(canal.n),
                    manual: manuales.putIfAbsent(
                        canal.n, () => TextEditingController()),
                    onVerificar:
                        captura == null && canal.metodo == MetodoCanal.camara
                            ? () => onVerificar(canal)
                            : null,
                    onManual: () => onManual(canal),
                  ),
                if (captura != null && lecturas.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  TempGrafico(
                    canales: canales,
                    lecturas: lecturas,
                    nominal: punto.temperaturaNominal,
                    height: 110,
                    oscuro: true,
                  ),
                ],
                const SizedBox(height: 12),
                if (captura == null)
                  FilledButton.icon(
                    key: const ValueKey('captura-iniciar'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.actionPositive,
                      foregroundColor: AppColors.actionPositiveInk,
                      minimumSize: const Size(0, 52),
                    ),
                    onPressed: onIniciar,
                    icon: const Icon(AppIcons.hora),
                    label: Text('Iniciar medición (${punto.lecturas} lecturas)',
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                  )
                else if (!captura.terminada)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white38),
                      minimumSize: const Size(0, 48),
                    ),
                    onPressed: onDetener,
                    icon: const Icon(AppIcons.cuadro),
                    label: const Text('Detener medición'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FilaCanal extends StatelessWidget {
  const _FilaCanal({
    required this.canal,
    required this.color,
    required this.unidad,
    required this.vivo,
    required this.ultima,
    required this.estado,
    required this.manual,
    required this.onVerificar,
    required this.onManual,
  });

  final TempCanal canal;
  final Color color;
  final String unidad;
  final IndicatorCandidate? vivo;
  final TempLectura? ultima;
  final EstadoCanalCaptura? estado;
  final TextEditingController manual;
  final VoidCallback? onVerificar;
  final VoidCallback onManual;

  @override
  Widget build(BuildContext context) {
    final aguja = canal.perfil?.engine == IndicatorEngine.aguja &&
        canal.metodo == MetodoCanal.camara;
    final fueraDeEscala = aguja && vivo != null && !vivo!.isNumber;
    final valor = estado == null
        ? (fueraDeEscala ? null : vivo?.value)
        : ultima == null
            ? null
            : ultima!.valor == null
                // Lo leído de una aguja es largo (valor, ángulo y escala).
                ? (aguja ? 'sin lectura' : ultima!.textoLeido ?? 'sin lectura')
                : textoNumero(ultima!.valor, decimales: canal.decimales);
    final (icono, colorEstado, texto) = switch (estado) {
      null => (
          vivo == null ? AppIcons.espera : AppIcons.ver,
          Colors.white60,
          canal.metodo == MetodoCanal.manual
              ? 'Manual'
              : fueraDeEscala
                  ? 'La aguja está fuera de la escala marcada'
                  : vivo == null
                      ? (aguja ? 'Buscando la aguja…' : 'Buscando el display…')
                      : 'En vivo'
        ),
      EstadoCanalCaptura.esperando => (
          AppIcons.espera,
          Colors.white60,
          'Esperando'
        ),
      EstadoCanalCaptura.leyendo => (
          AppIcons.enfocar,
          AppColors.accentYellow,
          'Leyendo…'
        ),
      EstadoCanalCaptura.tomada => (
          AppIcons.completo,
          AppColors.actionPositive,
          'Registrada'
        ),
      EstadoCanalCaptura.faltaManual => (
          AppIcons.editar,
          AppColors.actionNegative,
          canal.metodo == MetodoCanal.manual
              ? 'Escríbala'
              : 'No se pudo leer: escríbala'
        ),
    };
    final pedirManual = estado == EstadoCanalCaptura.faltaManual;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: pedirManual ? AppColors.actionNegative : Colors.white12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(canal.nombre,
                        style: GoogleFonts.inter(
                            color: Colors.white, fontWeight: FontWeight.w700)),
                    Row(children: [
                      Icon(icono, size: 13, color: colorEstado),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(texto,
                            style: GoogleFonts.inter(
                                color: colorEstado, fontSize: 12)),
                      ),
                    ]),
                  ],
                ),
              ),
              Text(
                valor ?? '—',
                style: GoogleFonts.robotoMono(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (onVerificar != null)
                IconButton(
                  tooltip: 'Verificar lectura',
                  onPressed: onVerificar,
                  icon: const Icon(AppIcons.verificado, color: Colors.white),
                ),
            ],
          ),
          if (pedirManual)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: manual,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true, signed: true),
                      style: GoogleFonts.robotoMono(color: Colors.white),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Valor del display',
                        hintStyle: const TextStyle(color: Colors.white38),
                        suffixText: unidad,
                        suffixStyle: const TextStyle(color: Colors.white70),
                        enabledBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.white24)),
                        focusedBorder: const OutlineInputBorder(
                            borderSide:
                                BorderSide(color: AppColors.actionPositive)),
                      ),
                      onSubmitted: (_) => onManual(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.actionPositive,
                      foregroundColor: AppColors.actionPositiveInk,
                    ),
                    onPressed: onManual,
                    child: const Text('Registrar'),
                  ),
                ],
              ),
            ),
        ],
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
          Text(message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: Colors.white, height: 1.4)),
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
