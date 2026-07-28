import 'dart:math';

double parseDouble(String value) {
  return double.tryParse(value.replaceAll(',', '.').trim()) ?? 0.0;
}

String formatDouble(double value) {
  return value.toStringAsFixed(2).replaceAll('.', ',');
}

double getDecimalPlaces(double dValue) {
  if (dValue == 0) return 1;
  return pow(10, -(log(dValue) / ln10).floor()).toDouble();
}

double calcularError(double indicacion, double carga) {
  if (carga == 0) return 0;
  return ((indicacion - carga) / carga) * 100;
}

double calcularIncertidumbre(double carga) {
  if (carga == 0) return 0;
  return (carga * 0.001) / sqrt(3);
}

List<String> getIndicationSuggestionsForCarga(
    String cargaText, String currentValue) {
  final carga = parseDouble(cargaText);
  if (carga <= 0) return [];
  final baseValue = currentValue.trim().isEmpty ? carga : parseDouble(currentValue);
  final suggestions = <String>[];
  for (int i = -5; i <= 5; i++) {
    final val = baseValue + (i * 0.01 * carga);
    suggestions.add(val.toStringAsFixed(2).replaceAll('.', ','));
  }
  return suggestions;
}
