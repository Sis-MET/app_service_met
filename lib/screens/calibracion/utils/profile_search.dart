import 'dart:ui' show Rect;

import 'indicator_frame.dart';
import 'indicator_reading.dart';
import 'reading_profile.dart';
import 'seven_segment_reader.dart';

/// «Verificar lectura»: el técnico escribe lo que muestra el display y el
/// lector busca, entre sus maneras de leer, una con la que los últimos
/// cuadros den ese mismo valor. Así un display raro (color, polaridad,
/// segmentos muy separados, pantalla gráfica) queda leído como corresponde
/// y no con la primera interpretación que salga.
abstract final class ProfileSearch {
  /// El primer perfil de [ReadingProfile.candidatos] con el que la mayoría
  /// de [frames] da [expected] en [region]; null si ninguno. [onProgress]
  /// recibe cuántos perfiles se probaron y cuántos hay.
  static Future<ReadingProfile?> find({
    required List<CameraFrame> frames,
    required Rect region,
    required String expected,
    required Future<List<List<OcrWord>>> Function(GrayImage band) recognize,
    int? expectedDecimals,
    bool units = false,
    void Function(int tried, int total)? onProgress,
    bool Function()? cancelled,
  }) async {
    final target = parse(expected);
    if (target == null || frames.isEmpty) return null;
    final profiles = ReadingProfile.candidatos(
      units: units,
      withColor: frames.first.hasColor,
    );
    for (var i = 0; i < profiles.length; i++) {
      if (cancelled?.call() ?? false) return null;
      onProgress?.call(i, profiles.length);
      final profile = profiles[i];
      final reader = IndicatorFrameReader(
        region: region,
        recognize: recognize,
        expectedDecimals: expectedDecimals,
        profile: profile,
        segmentMemory: Duration.zero,
      );
      var hits = 0;
      for (final frame in frames) {
        final candidate = await reader.read(frame);
        final value = candidate?.number;
        if (value != null && (value - target).abs() < 1e-9) hits++;
      }
      if (hits * 2 > frames.length) {
        onProgress?.call(profiles.length, profiles.length);
        return profile;
      }
    }
    onProgress?.call(profiles.length, profiles.length);
    return null;
  }

  /// "125,4", "-3.0", " 25 " → número; null si no lo es.
  static double? parse(String text) =>
      double.tryParse(text.trim().replaceAll(',', '.'));
}
