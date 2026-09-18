import 'dart:ui' show Rect;

import '../../../models/service_session.dart';
import 'suggestion_helper.dart';

/// Una palabra que el OCR leyó en un cuadro de la cámara, con su recuadro en
/// píxeles de la imagen ya derecha (como se ve en pantalla).
class OcrWord {
  const OcrWord(this.text, this.box);

  final String text;
  final Rect box;
}

/// Un número del cuadro que puede ser la lectura del indicador.
class IndicatorCandidate {
  const IndicatorCandidate({
    required this.value,
    required this.height,
    this.pointAdded = false,
  });

  /// Con punto decimal y signo delante: "12.345", "-0.005".
  final String value;

  /// Alto del texto en píxeles. La lectura es lo más grande del display;
  /// unidades, rótulos y la placa de la balanza son más chicos.
  final double height;

  /// El display no mostró el punto (en los LED de 7 segmentos es un punto
  /// diminuto que el OCR suele perder) y se ubicó según la división d.
  final bool pointAdded;
}

/// Saca la lectura del indicador del texto que reconoce el OCR.
///
/// Los displays de 7 segmentos no son letras de imprenta: el OCR confunde el
/// 0 con O o D, el 1 con I o l, el 5 con S, y separa los dígitos cuando hay
/// hueco entre segmentos. Aquí se juntan las palabras cercanas de una misma
/// línea y se corrigen esas confusiones solo dentro de lo que ya parece un
/// número: una palabra sin ningún dígito ("kg", "Net") nunca se convierte.
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
    'S': '5',
    's': '5',
    'b': '6',
    'G': '6',
    'B': '8',
    'g': '9',
    'q': '9',
  };

  static final _numberRun =
      RegExp(r'-?[0-9OoDQIli|!ZzSsbGBgq]+(?:[.,][0-9OoDQIli|!ZzSsbGBgq]+)?');

  /// Hueco máximo entre dos palabras de un mismo número, en alturas de letra.
  /// Entre segmentos de un display hay poco; entre dos números, más.
  static const _joinGap = 0.6;

  /// Lecturas posibles en [lines] (cada una, sus palabras), la más probable
  /// primero. [expectedDecimals] son los decimales que muestra la balanza:
  /// si el OCR perdió el punto, se ubica con ellos.
  static List<IndicatorCandidate> candidates(
    List<List<OcrWord>> lines, {
    int? expectedDecimals,
  }) {
    final found = <IndicatorCandidate>[];
    for (final line in lines) {
      for (final chunk in _chunks(line)) {
        final text = _normalizeSymbols(chunk.text);
        for (final match in _numberRun.allMatches(text)) {
          final value = _readNumber(match.group(0)!, expectedDecimals);
          if (value == null) continue;
          found.add(IndicatorCandidate(
            value: value.text,
            height: chunk.height,
            pointAdded: value.pointAdded,
          ));
        }
      }
    }
    found.sort((a, b) {
      final byHeight = b.height.compareTo(a.height);
      return byHeight != 0
          ? byHeight
          : _digits(b.value).compareTo(_digits(a.value));
    });
    return found;
  }

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

    var number = body
        .split('')
        .map((char) => _confusables[char] ?? char)
        .join()
        .replaceAll(',', '.');
    var pointAdded = false;
    if (!hasPoint &&
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
