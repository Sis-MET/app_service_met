import 'dart:ui' show Rect;

import '../../../models/service_session.dart';
import 'needle_reader.dart';
import 'seven_segment_reader.dart';
import 'suggestion_helper.dart';

/// Una palabra que el OCR leyó en un cuadro de la cámara, con su recuadro en
/// píxeles de la imagen ya derecha (como se ve en pantalla).
class OcrWord {
  const OcrWord(this.text, this.box);

  final String text;
  final Rect box;
}

/// De dónde salió una lectura.
enum IndicatorSource {
  /// El lector propio de displays de 7 segmentos.
  segmentos,

  /// El OCR de texto de ML Kit.
  texto,

  /// La aguja de un indicador analógico ([NeedleReader]).
  aguja,
}

/// Un número del cuadro que puede ser la lectura del indicador.
class IndicatorCandidate {
  const IndicatorCandidate({
    required this.value,
    required this.height,
    this.pointAdded = false,
    this.source = IndicatorSource.texto,
    this.raw,
    this.status,
  });

  /// Un display que no muestra un valor: "----", "OPEn", "HHHH".
  const IndicatorCandidate.sinValor(
    String this.status, {
    required this.height,
    this.source = IndicatorSource.texto,
    this.raw,
  })  : value = status,
        pointAdded = false;

  /// Con punto decimal y signo delante: "12.345", "-0.005". En un mensaje
  /// sin valor, el mensaje.
  final String value;

  /// Alto del texto en píxeles. La lectura es lo más grande del display;
  /// unidades, rótulos y la placa de la balanza son más chicos.
  final double height;

  /// El display no mostró el punto (en los LED de 7 segmentos es un punto
  /// diminuto que el OCR suele perder) y se ubicó según la división d.
  final bool pointAdded;

  final IndicatorSource source;

  /// Lo que se leyó tal cual, antes de corregir confusiones ("4OO.O1").
  final String? raw;

  /// El mensaje del display cuando no muestra un valor.
  final String? status;

  bool get isNumber => status == null;

  double? get number => isNumber ? double.tryParse(value) : null;
}

/// Saca la lectura del indicador del texto que reconoce el OCR.
///
/// Los displays de 7 segmentos no son letras de imprenta: el OCR confunde el
/// 0 con O o D, el 1 con I o l, el 4 con Y, el 5 con S, y separa los dígitos
/// cuando hay hueco entre segmentos. Aquí se juntan las palabras cercanas de
/// una misma línea y se corrigen esas confusiones solo dentro de lo que ya
/// parece un número: una palabra sin ningún dígito ("kg", "Net") nunca se
/// convierte.
abstract final class IndicatorReadingParser {
  static const _confusables = {
    'O': '0',
    'o': '0',
    'D': '0',
    'Q': '0',
    'I': '1',
    'l': '1',
    'i': '1',
    '|': '1',
    '!': '1',
    'Z': '2',
    'z': '2',
    // El 4 de 7 segmentos no tiene la diagonal de imprenta.
    'Y': '4',
    'y': '4',
    'S': '5',
    's': '5',
    'b': '6',
    'G': '6',
    'B': '8',
    'g': '9',
    'q': '9',
  };

  static final _numberRun = RegExp(
      r'-?[0-9OoDQIli|!ZzYySsbGBgq]+(?:[.,][0-9OoDQIli|!ZzYySsbGBgq]+)?');

  /// Hueco máximo entre dos palabras de un mismo número, en alturas de letra.
  /// Entre segmentos de un display hay poco; entre dos números, más.
  static const _joinGap = 0.6;

  /// Lecturas posibles en [lines] (cada una, sus palabras), la más probable
  /// primero. [expectedDecimals] son los decimales que muestra la balanza:
  /// si el OCR perdió el punto, se ubica con ellos.
  ///
  /// Con [statuses] (displays de temperatura), un mensaje sin valor que
  /// ocupe un trozo entero ("----", "OPEn", "Err", "HHHH") también es un
  /// candidato, por detrás de cualquier número de su mismo alto.
  static List<IndicatorCandidate> candidates(
    List<List<OcrWord>> lines, {
    int? expectedDecimals,
    bool statuses = false,
  }) {
    final found = <IndicatorCandidate>[];
    for (final line in lines) {
      for (final chunk in _chunks(line)) {
        final text = _normalizeSymbols(chunk.text);
        if (statuses && _status.hasMatch(text.replaceFirst(_unit, ''))) {
          found.add(IndicatorCandidate.sinValor(
            text,
            height: chunk.height,
            raw: chunk.text,
          ));
          continue;
        }
        for (final match in _numberRun.allMatches(text)) {
          final value = _readNumber(match.group(0)!, expectedDecimals);
          if (value == null) continue;
          found.add(IndicatorCandidate(
            value: value.text,
            height: chunk.height,
            pointAdded: value.pointAdded,
            raw: match.group(0),
          ));
        }
      }
    }
    found.sort((a, b) {
      final byHeight = b.height.compareTo(a.height);
      if (byHeight != 0) return byHeight;
      if (a.isNumber != b.isNumber) return a.isNumber ? -1 : 1;
      return _digits(b.value).compareTo(_digits(a.value));
    });
    return found;
  }

  /// Mensajes de los indicadores de temperatura cuando no dan un valor:
  /// sensor abierto o desconectado, fuera de rango, error.
  static final _status = RegExp(
    r'^(-{2,}|_{2,}|OPEN|OL|O\.L|0L|ERR\d*|E-?\d{1,2}|H{2,}|L{2,}|E{3,}|SB\.?ER|S\.?ERR|SENS)$',
    caseSensitive: false,
  );

  /// La unidad pegada al mensaje ("----°C").
  static final _unit = RegExp(r'[°º]?[CF]$', caseSensitive: false);

  static int _digits(String value) =>
      value.replaceAll(RegExp(r'\D'), '').length;

  static String _normalizeSymbols(String text) => text
      // El signo menos llega como raya larga o menos tipográfico, y el punto
      // decimal a veces como punto medio.
      .replaceAll(RegExp('[\u2212\u2013\u2014\u2010]'), '-')
      .replaceAll('\u00B7', '.');

  static List<({String text, double height})> _chunks(List<OcrWord> line) {
    final words = [...line]..sort((a, b) => a.box.left.compareTo(b.box.left));
    final chunks = <({String text, double height})>[];
    var text = '';
    var height = 0.0;
    Rect? previous;
    for (final word in words) {
      final gap = previous == null ? 0.0 : word.box.left - previous.right;
      final limit = _joinGap *
          (previous == null
              ? word.box.height
              : (word.box.height > previous.height
                  ? word.box.height
                  : previous.height));
      if (previous != null && gap > limit) {
        chunks.add((text: text, height: height));
        text = '';
        height = 0;
      }
      text += word.text.replaceAll(RegExp(r'\s'), '');
      if (word.box.height > height) height = word.box.height;
      previous = word.box;
    }
    if (text.isNotEmpty) chunks.add((text: text, height: height));
    return chunks;
  }

  static ({String text, bool pointAdded})? _readNumber(
    String raw,
    int? expectedDecimals,
  ) {
    final negative = raw.startsWith('-');
    final body = negative ? raw.substring(1) : raw;
    final hasPoint = body.contains('.') || body.contains(',');
    final realDigits = RegExp(r'\d').allMatches(body).length;
    final zeroLike = RegExp('[OoDQ]').allMatches(body).length;
    final symbols = body.length - (hasPoint ? 1 : 0);
    // Una palabra con más letras parecidas que dígitos no es una lectura,
    // salvo con punto ("O.OO5"). Sin ningún dígito solo se acepta un cero
    // de display ("O.OOO", "OO"): el retorno a cero es la mitad de las
    // lecturas. Una O suelta es más bien un rótulo ("ON", "ZERO").
    final accepted = realDigits > 0
        ? realDigits * 2 >= symbols || hasPoint
        : zeroLike == symbols && (hasPoint || symbols >= 2);
    if (!accepted) return null;

    final number = body
        .split('')
        .map((char) => _confusables[char] ?? char)
        .join()
        .replaceAll(',', '.');
    return _finish(number,
        negative: negative, expectedDecimals: expectedDecimals);
  }

  /// La lectura de un display de 7 segmentos, en el mismo formato que las
  /// del OCR.
  static IndicatorCandidate? fromSegments(
    SegmentReading reading, {
    int? expectedDecimals,
  }) {
    final status = reading.status;
    if (status != null) {
      return IndicatorCandidate.sinValor(
        status,
        height: reading.height,
        source: IndicatorSource.segmentos,
        raw: status,
      );
    }
    final digits = reading.digits;
    final point = reading.pointAfter;
    final value = _finish(
      point == null
          ? digits
          : '${digits.substring(0, point)}.${digits.substring(point)}',
      negative: reading.negative,
      expectedDecimals: expectedDecimals,
    );
    if (value == null) return null;
    return IndicatorCandidate(
      value: value.text,
      height: reading.height,
      pointAdded: value.pointAdded,
      source: IndicatorSource.segmentos,
      raw: reading.toString(),
    );
  }

  /// El mensaje de una aguja que apunta fuera de las marcas de la escala.
  static const fueraDeEscala = 'Fuera de escala';

  /// La lectura de una aguja, redondeada a [step] (la resolución con que se
  /// lee el dial) y escrita con [decimals] decimales, como la anotaría el
  /// técnico. Lo leído ([IndicatorCandidate.raw]) guarda el valor sin
  /// redondear, el ángulo desde la primera marca y los valores de las marcas,
  /// para poder rehacer la conversión. Fuera de la escala marcada, un mensaje
  /// sin valor.
  static IndicatorCandidate fromNeedle(
    NeedleReading reading, {
    double? step,
    int? decimals,
  }) {
    final raw = [
      'aguja ${reading.value.toStringAsFixed(2)}',
      '${reading.sweepDegrees.toStringAsFixed(1)}°',
      if (reading.scale.isNotEmpty)
        'escala ${reading.scale.map(_shortNumber).join('/')}',
    ].join(' · ');
    if (reading.outOfScale) {
      return IndicatorCandidate.sinValor(
        fueraDeEscala,
        height: 0,
        source: IndicatorSource.aguja,
        raw: raw,
      );
    }
    var value = reading.value;
    if (step != null && step > 0) value = (value / step).round() * step;
    final places =
        decimals ?? (step == null ? 1 : IndicatorReadingCheck.decimalsOf(step));
    var text = value.toStringAsFixed(places);
    // Un cero redondeado desde abajo no lleva signo.
    if (double.parse(text) == 0) text = text.replaceFirst('-', '');
    return IndicatorCandidate(
      value: text,
      height: 0,
      source: IndicatorSource.aguja,
      raw: raw,
    );
  }

  static String _shortNumber(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value
          .toStringAsFixed(3)
          .replaceFirst(RegExp(r'0+$'), '')
          .replaceFirst(RegExp(r'\.$'), '');

  /// Ubica el punto que el display no mostró y quita los ceros de la
  /// izquierda.
  static ({String text, bool pointAdded})? _finish(
    String number, {
    required bool negative,
    required int? expectedDecimals,
  }) {
    var pointAdded = false;
    if (!number.contains('.') &&
        expectedDecimals != null &&
        expectedDecimals > 0 &&
        number.length > expectedDecimals) {
      final at = number.length - expectedDecimals;
      number = '${number.substring(0, at)}.${number.substring(at)}';
      pointAdded = true;
    }
    // Los ceros que el display deja a la izquierda no son parte del valor.
    number = number.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(number)) return null;
    return (text: '${negative ? '-' : ''}$number', pointAdded: pointAdded);
  }
}

/// Cuándo una lectura es la misma varios cuadros seguidos. Evita tomar un
/// valor mientras el display todavía cambia o el OCR duda entre dos.
class ReadingStability {
  ReadingStability({this.required = 3});

  final int required;
  final List<String?> _recent = [];

  String? get value => _recent.isEmpty ? null : _recent.last;

  bool get stable =>
      _recent.length >= required &&
      _recent.every((reading) => reading != null && reading == _recent.last);

  void add(String? reading) {
    _recent.add(reading);
    if (_recent.length > required) _recent.removeAt(0);
  }
}

/// Compara una lectura con lo que puede mostrar la balanza, para que el
/// técnico la mire dos veces antes de usarla. No corrige nada.
abstract final class IndicatorReadingCheck {
  /// Decimales que muestra el indicador, si todos los rangos coinciden. Si
  /// difieren, depende del valor y no se puede ubicar un punto perdido.
  static int? expectedDecimals(BalanzaInfo? balanza) {
    if (balanza == null) return null;
    final decimals = SuggestionHelper.getValidCapacities(balanza)
        .map((rango) => decimalsOf(rango['d']!))
        .toSet();
    return decimals.length == 1 ? decimals.single : null;
  }

  static List<String> warnings(
    IndicatorCandidate candidate,
    BalanzaInfo? balanza,
  ) {
    final value = double.tryParse(candidate.value);
    if (value == null || balanza == null) return const [];
    final d = SuggestionHelper.getDivisionForValue(balanza, value.abs());
    if (d <= 0) return const [];

    final division = _format(d);
    final warnings = <String>[];
    if (candidate.pointAdded) {
      warnings.add('Se ubicó el punto decimal según d = $division.');
    }
    final expected = decimalsOf(d);
    final actual = candidate.value.contains('.')
        ? candidate.value.split('.').last.length
        : 0;
    if (actual != expected) {
      warnings.add(expected == 1
          ? 'Con d = $division el indicador muestra 1 decimal.'
          : 'Con d = $division el indicador muestra $expected decimales.');
    } else if (!_isMultipleOf(value, d)) {
      warnings.add('No es múltiplo de d = $division.');
    }
    return warnings;
  }

  /// Decimales de la división: 0.005 → 3, 0.1 → 1, 10 → 0.
  static int decimalsOf(double d) {
    final text = _format(d);
    return text.contains('.') ? text.split('.').last.length : 0;
  }

  static bool _isMultipleOf(double value, double d) {
    final steps = value / d;
    return (steps - steps.round()).abs() < 1e-6;
  }

  static String _format(double d) =>
      d == d.roundToDouble() ? d.toInt().toString() : d.toString();
}

/// Un aviso sobre una lectura que el técnico debe mirar. La lectura se
/// guarda igual: el aviso no la corrige.
class ReadingAlert {
  const ReadingAlert(this.code, this.message);

  /// Estable, se guarda con la lectura: `decimales`, `fuera_de_rango`,
  /// `salto`, `punto_ubicado`.
  final String code;
  final String message;

  @override
  String toString() => message;
}

/// Lo que se espera de las lecturas de un canal: sus decimales, el rango
/// del equipo y cuánto puede cambiar entre dos lecturas seguidas.
class ReadingExpectations {
  const ReadingExpectations({
    this.decimals,
    this.min,
    this.max,
    this.maxJump,
    this.unit = '',
  });

  final int? decimals;
  final double? min;
  final double? max;

  /// Cambio máximo creíble frente a la lectura anterior. Un salto mayor en
  /// 30 segundos suele ser una lectura equivocada (un 8 por un 0) o la puerta
  /// abierta.
  final double? maxJump;
  final String unit;

  List<ReadingAlert> check(IndicatorCandidate candidate, {double? previous}) {
    final value = candidate.number;
    if (value == null) return const [];
    final alerts = <ReadingAlert>[];
    final suffix = unit.isEmpty ? '' : ' $unit';
    if (candidate.pointAdded) {
      alerts.add(const ReadingAlert(
          'punto_ubicado', 'Se ubicó el punto decimal según la resolución.'));
    }
    final decimals = this.decimals;
    if (decimals != null) {
      final actual = candidate.value.contains('.')
          ? candidate.value.split('.').last.length
          : 0;
      if (actual != decimals) {
        alerts.add(ReadingAlert(
          'decimales',
          decimals == 1
              ? 'El display muestra 1 decimal.'
              : 'El display muestra $decimals decimales.',
        ));
      }
    }
    final min = this.min, max = this.max;
    if ((min != null && value < min) || (max != null && value > max)) {
      final range = min != null && max != null
          ? ' (${_text(min)} a ${_text(max)}$suffix)'
          : '';
      alerts.add(
          ReadingAlert('fuera_de_rango', 'Fuera del rango esperado$range.'));
    }
    final jump = maxJump;
    if (jump != null && previous != null && (value - previous).abs() > jump) {
      alerts.add(ReadingAlert(
        'salto',
        'Cambió ${_text((value - previous).abs())}$suffix desde la lectura anterior.',
      ));
    }
    return alerts;
  }

  static String _text(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
}
