import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../../utils/fecha_iso.dart';
import '../../calibracion/utils/capture_vote.dart';
import '../../calibracion/utils/indicator_frame.dart';
import '../../calibracion/utils/indicator_reading.dart';
import '../../calibracion/utils/seven_segment_reader.dart';
import '../models/temperatura_models.dart';
import '../services/medicion_programada.dart';

/// Guarda una lectura en la base. Si ya había una para esa hora y ese canal,
/// devuelve false.
typedef RegistrarLectura = Future<bool> Function(TempLectura lectura);

/// Guarda la imagen del display de una lectura y devuelve su ruta.
typedef GuardarImagen = Future<String?> Function(
    GrayImage imagen, int nLectura, int nCanal);

/// Estado de un canal en la lectura que toca ahora.
enum EstadoCanalCaptura {
  /// Todavía no llegó su hora.
  esperando,

  /// La cámara está leyendo la ráfaga.
  leyendo,

  /// Ya tiene su lectura.
  tomada,

  /// La cámara no pudo: el técnico puede escribirla hasta la siguiente.
  faltaManual,
}

/// Lleva la medición programada de un punto: decide qué lectura toca, junta
/// los votos de la ráfaga de cada canal de cámara, pide los canales
/// manuales y entrega cada lectura para guardarla en el momento.
///
/// Nunca inventa un valor: una lectura de cámara se registra solo con el
/// acuerdo de la ráfaga (ver [VotoLecturas]); si no, el técnico la escribe
/// mirando el display o queda «sin lectura» con su motivo.
class CapturaProgramada extends ChangeNotifier {
  CapturaProgramada({
    required this.punto,
    required this.canales,
    required this.registrar,
    this.guardarImagen,
    Map<int, ReadingExpectations> expectativas = const {},
    Iterable<TempLectura> previas = const [],
    DateTime Function()? reloj,
  })  : _reloj = reloj ?? DateTime.now,
        _expectativas = expectativas,
        horario = MedicionProgramada(
          inicio: punto.inicio!,
          intervalo: Duration(seconds: punto.intervaloS),
          lecturas: punto.lecturas,
        ) {
    _creadaEn = _reloj();
    for (final lectura in previas) {
      if (lectura.nPunto != punto.n) continue;
      _tomadas.add(_clave(lectura.nLectura, lectura.nCanal));
      _registrarUltima(lectura);
    }
  }

  final TempPunto punto;
  final List<TempCanal> canales;
  final RegistrarLectura registrar;
  final GuardarImagen? guardarImagen;
  final DateTime Function() _reloj;
  final Map<int, ReadingExpectations> _expectativas;
  final MedicionProgramada horario;

  late final DateTime _creadaEn;
  final Set<String> _tomadas = {};
  final Set<String> _enProceso = {};
  final Map<int, VotoLecturas> _votos = {};

  /// Por canal, si el último intento fue un mensaje sin valor del display.
  final Map<int, bool> _ultimoFueSinValor = {};
  final Map<int, TempLectura> _ultimas = {};
  final List<TempLectura> _lecturas = [];
  final Map<int, double> _ultimoValor = {};
  final List<(DateTime, DateTime?)> _pausas = [];
  int? _actual;
  bool _terminada = false;
  bool _cerrando = false;

  /// La última lectura registrada de cada canal.
  Map<int, TempLectura> get ultimas => Map.unmodifiable(_ultimas);

  /// Todas las lecturas del punto, las de antes y las de esta sesión.
  List<TempLectura> get lecturas => List.unmodifiable(_lecturas);

  List<TempCanal> get canalesCamara =>
      canales.where((c) => c.metodo == MetodoCanal.camara).toList();

  /// La lectura que toca ahora (0…), o null.
  int? get actual => _actual;
  bool get terminada => _terminada;
  bool get pausada => _pausas.isNotEmpty && _pausas.last.$2 == null;

  /// Cuántas horas programadas ya tienen todos sus canales cerrados.
  int get completas {
    var count = 0;
    for (var n = 0; n < horario.lecturas; n++) {
      if (_completa(n)) count++;
    }
    return count;
  }

  static String _clave(int n, int canal) => '$n/$canal';

  bool _tomada(int n, int canal) =>
      _tomadas.contains(_clave(n, canal)) ||
      _enProceso.contains(_clave(n, canal));

  bool _completa(int n) => canales.every((c) => _tomada(n, c.n));

  Set<int> get _hechas => {
        for (var n = 0; n < horario.lecturas; n++)
          if (_completa(n)) n,
      };

  EstadoCanalCaptura estadoDe(int nCanal) {
    final n = _actual;
    if (n == null) return EstadoCanalCaptura.esperando;
    if (_tomada(n, nCanal)) return EstadoCanalCaptura.tomada;
    final canal = canales.firstWhere((c) => c.n == nCanal);
    if (canal.metodo == MetodoCanal.manual) {
      return EstadoCanalCaptura.faltaManual;
    }
    return horario.enVentana(n, _reloj()) && !pausada
        ? EstadoCanalCaptura.leyendo
        : EstadoCanalCaptura.faltaManual;
  }

  /// Si la cámara tiene que leer ahora (hay una ráfaga abierta).
  bool get necesitaCuadros {
    final n = _actual;
    if (n == null || pausada || _terminada) return false;
    if (!horario.enVentana(n, _reloj())) return false;
    return canalesCamara.any((c) => !_tomada(n, c.n));
  }

  /// Canales que el técnico debe escribir ahora.
  List<TempCanal> get pendientesManuales {
    final n = _actual;
    if (n == null || _terminada) return const [];
    return [
      for (final canal in canales)
        if (estadoDe(canal.n) == EstadoCanalCaptura.faltaManual) canal,
    ];
  }

  /// La cámara se detuvo (app en segundo plano, pantalla apagada).
  void pausar() {
    if (pausada) return;
    _pausas.add((_reloj(), null));
    notifyListeners();
  }

  void reanudar() {
    if (!pausada) return;
    final (desde, _) = _pausas.removeLast();
    _pausas.add((desde, _reloj()));
    _votos.clear();
    notifyListeners();
  }

  bool _enPausa(int n) {
    final desde = horario.horaDe(n);
    final hasta = desde.add(horario.ventana);
    for (final (inicio, fin) in _pausas) {
      final finEfectivo = fin ?? _reloj();
      if (inicio.isBefore(hasta) && finEfectivo.isAfter(desde)) return true;
    }
    return false;
  }

  /// Avanza el horario: cierra las lecturas vencidas y abre la que toca. Lo
  /// llama un temporizador varias veces por segundo.
  Future<void> tick() async {
    if (_terminada || _cerrando) return;
    _cerrando = true;
    try {
      final ahora = _reloj();
      for (final n in horario.vencidas(ahora, _hechas)) {
        for (final canal in canales) {
          if (_tomada(n, canal.n)) continue;
          await _sinLectura(n, canal, _motivo(n, canal));
        }
      }
      final n = horario.actual(ahora);
      if (n != _actual) {
        _actual = n;
        _votos.clear();
        _ultimoFueSinValor.clear();
      }
      if (horario.terminada(ahora, _hechas)) _terminada = true;
    } finally {
      _cerrando = false;
    }
    notifyListeners();
  }

  String _motivo(int n, TempCanal canal) {
    if (!horario.limiteDe(n).isAfter(_creadaEn)) {
      return MotivoSinLectura.appCerrada;
    }
    if (canal.metodo == MetodoCanal.manual) {
      return MotivoSinLectura.manualSinIngresar;
    }
    if (_enPausa(n)) return MotivoSinLectura.segundoPlano;
    return _ultimoFueSinValor[canal.n] == true
        ? MotivoSinLectura.sinValor
        : MotivoSinLectura.noLegible;
  }

  /// Lo que leyó la cámara en un cuadro, en el orden de [canalesCamara].
  Future<void> cuadro(List<RegionReading> lecturas) async {
    final n = _actual;
    if (n == null || !necesitaCuadros) return;
    final camara = canalesCamara;
    for (var i = 0; i < camara.length && i < lecturas.length; i++) {
      final canal = camara[i];
      if (_tomada(n, canal.n)) continue;
      final voto = _votos.putIfAbsent(canal.n, VotoLecturas.new);
      voto.add(lecturas[i].candidate);
      if (voto.accepted) {
        await _aceptar(n, canal, voto.resultado, lecturas[i].band);
      } else if (voto.done) {
        final resultado = voto.resultado;
        _ultimoFueSinValor[canal.n] = resultado.candidate?.isNumber == false;
        // Sin acuerdo: otra ráfaga mientras dure la ventana.
        _votos.remove(canal.n);
      }
    }
    notifyListeners();
  }

  Future<void> _aceptar(
    int n,
    TempCanal canal,
    VotoResultado resultado,
    GrayImage band,
  ) async {
    final candidate = resultado.candidate!;
    final clave = _clave(n, canal.n);
    _enProceso.add(clave);
    try {
      final imagen = await guardarImagen?.call(band, n, canal.n);
      final ahora = _reloj();
      if (!candidate.isNumber) {
        _ultimoFueSinValor[canal.n] = true;
        await _guardar(TempLectura(
          nPunto: punto.n,
          nLectura: n,
          nCanal: canal.n,
          tiempoProgramadoS: horario.segundosDe(n),
          capturadaEn: fechaIsoConMilisegundos(ahora),
          textoLeido: _corto(candidate.raw ?? candidate.value),
          origen: OrigenLectura.sinLectura,
          coincidencia: resultado.coincidencia,
          cuadros: resultado.frames,
          estado: EstadoLectura.sinLectura,
          motivo: MotivoSinLectura.sinValor,
          imagenPath: imagen,
        ));
        return;
      }
      final valor = candidate.number!;
      final alertas = (_expectativas[canal.n] ?? const ReadingExpectations())
          .check(candidate, previous: _ultimoValor[canal.n]);
      await _guardar(TempLectura(
        nPunto: punto.n,
        nLectura: n,
        nCanal: canal.n,
        tiempoProgramadoS: horario.segundosDe(n),
        capturadaEn: fechaIsoConMilisegundos(ahora),
        valor: valor,
        valorOriginal: valor,
        textoLeido: _corto(candidate.raw ?? candidate.value),
        origen: candidate.source == IndicatorSource.segmentos
            ? OrigenLectura.ocrSegmentos
            : OrigenLectura.ocrTexto,
        coincidencia: resultado.coincidencia,
        cuadros: resultado.frames,
        alerta: alertas.isEmpty ? null : alertas.map((a) => a.code).join(','),
        imagenPath: imagen,
      ));
    } finally {
      _enProceso.remove(clave);
    }
  }

  /// El técnico escribió la lectura de [nCanal] para la hora en curso.
  /// Devuelve el mensaje de error, o null si se guardó.
  Future<String?> manual(int nCanal, double valor) async {
    final n = _actual;
    if (n == null || _terminada) return 'No hay una lectura abierta.';
    if (_tomada(n, nCanal)) return 'Esa lectura ya está registrada.';
    final ahora = _reloj();
    if (!ahora.isBefore(horario.limiteDe(n))) {
      return 'Se pasó la hora de esa lectura.';
    }
    // Los decimales escritos a mano no dicen nada del display.
    final alertas = (_expectativas[nCanal] ?? const ReadingExpectations())
        .check(IndicatorCandidate(value: textoNumero(valor), height: 0),
            previous: _ultimoValor[nCanal])
        .where((alerta) => alerta.code != 'decimales')
        .map((alerta) => alerta.code)
        .join(',');
    final clave = _clave(n, nCanal);
    _enProceso.add(clave);
    try {
      await _guardar(TempLectura(
        nPunto: punto.n,
        nLectura: n,
        nCanal: nCanal,
        tiempoProgramadoS: horario.segundosDe(n),
        capturadaEn: fechaIsoConMilisegundos(ahora),
        valor: valor,
        valorOriginal: valor,
        textoLeido: textoNumero(valor),
        origen: OrigenLectura.manual,
        alerta: alertas.isEmpty ? null : alertas,
      ));
    } finally {
      _enProceso.remove(clave);
    }
    notifyListeners();
    return null;
  }

  Future<void> _sinLectura(int n, TempCanal canal, String motivo) async {
    final clave = _clave(n, canal.n);
    _enProceso.add(clave);
    try {
      await _guardar(TempLectura(
        nPunto: punto.n,
        nLectura: n,
        nCanal: canal.n,
        tiempoProgramadoS: horario.segundosDe(n),
        capturadaEn: fechaIsoConMilisegundos(_reloj()),
        origen: OrigenLectura.sinLectura,
        estado: EstadoLectura.sinLectura,
        motivo: motivo,
      ));
    } finally {
      _enProceso.remove(clave);
    }
  }

  Future<void> _guardar(TempLectura lectura) async {
    await registrar(lectura);
    // Aunque ya existiera (otra pantalla la registró), la hora queda cerrada.
    _tomadas.add(_clave(lectura.nLectura, lectura.nCanal));
    _registrarUltima(lectura);
  }

  void _registrarUltima(TempLectura lectura) {
    _lecturas.add(lectura);
    final ultima = _ultimas[lectura.nCanal];
    if (ultima == null || lectura.nLectura >= ultima.nLectura) {
      _ultimas[lectura.nCanal] = lectura;
    }
    if (lectura.cuenta) _ultimoValor[lectura.nCanal] = lectura.valor!;
  }

  /// Lo que se espera de un canal: sus decimales, el rango del equipo con un
  /// margen y un salto máximo creíble entre dos lecturas.
  /// Lo leído cabe en la columna del servidor (60 caracteres).
  static String _corto(String texto) =>
      texto.length <= 60 ? texto : texto.substring(0, 60);

  static ReadingExpectations expectativasDe(
    TempCanal canal, {
    required TempPunto punto,
    TempEquipo? equipo,
  }) {
    final min = equipo?.rangoMin, max = equipo?.rangoMax;
    final margen =
        min != null && max != null ? math.max(10.0, (max - min) * 0.1) : null;
    return ReadingExpectations(
      decimals: canal.decimales,
      min: margen == null ? null : min! - margen,
      max: margen == null ? null : max! + margen,
      maxJump: math.max(5.0, punto.temperaturaNominal.abs() * 0.05),
      unit: equipo?.unidad ?? '°C',
    );
  }
}
