import 'package:service_met/models/service_session.dart';
import 'package:service_met/widgets/service_ui/balanza_info_button.dart';

/// Construye la ficha de información del instrumento a partir del mapa
/// devuelto por `DatabaseHelperPrecarga.getBalanzasPorPrefix`
/// (balanzas.* + inf.*).
ServiceBalanzaInfo buildServiceBalanzaInfo(
    Map<String, dynamic>? data, String codMetricaFallback) {
  if (data == null) {
    return ServiceBalanzaInfo(
      codMetrica: codMetricaFallback.isEmpty ? null : codMetricaFallback,
    );
  }

  String? s(String key) {
    final v = data[key]?.toString();
    return (v == null || v.isEmpty) ? null : v;
  }

  return ServiceBalanzaInfo(
    codMetrica: s('cod_metrica') ??
        (codMetricaFallback.isEmpty ? null : codMetricaFallback),
    tipo: s('tipo_instrumento') ?? s('instrumento'),
    categoria: s('categoria'),
    marca: s('marca'),
    modelo: s('modelo'),
    serie: s('inf_serie') ?? s('serie'),
    codInterno: s('cod_interno'),
    unidad: s('unidad'),
    ubicacion: s('ubicacion'),
    nCeldas: s('n_celdas'),
    capMax1: s('cap_max1'),
    d1: s('d1'),
    e1: s('e1'),
    dec1: s('dec1'),
    capMax2: s('cap_max2'),
    d2: s('d2'),
    e2: s('e2'),
    dec2: s('dec2'),
    capMax3: s('cap_max3'),
    d3: s('d3'),
    e3: s('e3'),
    dec3: s('dec3'),
  );
}

/// Construye un [BalanzaInfo] (modelo de calibración) a partir del mapa
/// devuelto por `DatabaseHelperPrecarga.getBalanzasPorPrefix`.
/// Necesario para reutilizar `SuggestionHelper` (divisiones, decimales,
/// valores sugeridos) en los módulos de soporte.
BalanzaInfo buildCalBalanzaInfo(
    Map<String, dynamic>? data, String codMetricaFallback) {
  if (data == null) {
    return BalanzaInfo(
      codMetrica: codMetricaFallback.isEmpty ? null : codMetricaFallback,
    );
  }

  String? s(String key) {
    final v = data[key]?.toString();
    return (v == null || v.isEmpty) ? null : v;
  }

  double? d(String key) => double.tryParse(s(key) ?? '');

  return BalanzaInfo(
    codMetrica: s('cod_metrica') ??
        (codMetricaFallback.isEmpty ? null : codMetricaFallback),
    tipo: s('tipo_instrumento') ?? s('instrumento'),
    categoria: s('categoria'),
    marca: s('marca'),
    modelo: s('modelo'),
    serie: s('inf_serie') ?? s('serie'),
    codInterno: s('cod_interno'),
    unidad: s('unidad'),
    ubicacion: s('ubicacion'),
    rango: s('rango'),
    nCeldas: s('n_celdas'),
    capMax1: s('cap_max1'),
    d1: d('d1'),
    e1: d('e1'),
    dec1: d('dec1'),
    capMax2: s('cap_max2'),
    d2: d('d2'),
    e2: d('e2'),
    dec2: d('dec2'),
    capMax3: s('cap_max3'),
    d3: d('d3'),
    e3: d('e3'),
    dec3: d('dec3'),
  );
}
