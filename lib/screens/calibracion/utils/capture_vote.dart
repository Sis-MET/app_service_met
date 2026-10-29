import 'indicator_reading.dart';

/// Lo que decidió una ráfaga de cuadros sobre un recuadro.
class VotoResultado {
  const VotoResultado({
    required this.candidate,
    required this.votes,
    required this.frames,
  });

  /// La lectura que más se repitió (un valor o un mensaje sin valor). Null
  /// si en ningún cuadro hubo lectura.
  final IndicatorCandidate? candidate;

  /// En cuántos cuadros apareció [candidate].
  final int votes;

  /// Cuántos cuadros se analizaron.
  final int frames;

  /// Qué parte de los cuadros coincidió: 0 a 1.
  double get coincidencia => frames == 0 ? 0 : votes / frames;
}

/// Junta las lecturas de una ráfaga de cuadros y decide.
///
/// Una lectura programada se acepta solo si [required] cuadros dan
/// exactamente lo mismo; así un cuadro movido o un reflejo que el lector
/// interpreta mal no queda registrado. Con [maxFrames] cuadros sin acuerdo,
/// la ráfaga termina sin lectura. El voto no corrige nada: elige entre lo
/// que el lector dio.
class VotoLecturas {
  VotoLecturas({this.required = 3, this.maxFrames = 5})
      : assert(required >= 1 && maxFrames >= required);

  final int required;
  final int maxFrames;

  final Map<String, int> _counts = {};
  final Map<String, IndicatorCandidate> _first = {};
  int _frames = 0;
  String? _winner;

  int get frames => _frames;

  /// Hay una lectura aceptada.
  bool get accepted => _winner != null;

  /// La ráfaga terminó: con lectura aceptada, con todos los cuadros vistos
  /// o porque ya ningún valor puede llegar a [required].
  bool get done {
    if (accepted || _frames >= maxFrames) return true;
    final best = _counts.values.fold(0, (a, b) => a > b ? a : b);
    return best + (maxFrames - _frames) < required;
  }

  /// La lectura de un cuadro; null si el lector no encontró nada.
  void add(IndicatorCandidate? candidate) {
    if (done) return;
    _frames++;
    if (candidate == null) return;
    final key = '${candidate.isNumber ? 'n' : 's'}:${candidate.value}';
    final count = (_counts[key] ?? 0) + 1;
    _counts[key] = count;
    _first.putIfAbsent(key, () => candidate);
    if (count >= required) _winner = key;
  }

  /// La lectura aceptada, o la más repetida si no se alcanzó el acuerdo.
  VotoResultado get resultado {
    final key = _winner ?? _mostVoted();
    return VotoResultado(
      candidate: key == null ? null : _first[key],
      votes: key == null ? 0 : _counts[key]!,
      frames: _frames,
    );
  }

  String? _mostVoted() {
    String? best;
    var votes = 0;
    for (final entry in _counts.entries) {
      if (entry.value > votes) {
        best = entry.key;
        votes = entry.value;
      }
    }
    return best;
  }

  void reset() {
    _counts.clear();
    _first.clear();
    _frames = 0;
    _winner = null;
  }
}
