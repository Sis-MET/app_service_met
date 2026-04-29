import 'package:flutter/foundation.dart';
import 'package:service_met/database/soporte_tecnico/database_helper_ajustes.dart';

class SoporteMetrologiaUtils {
  /// Obtiene d1 de la base de datos de ajustes
  static Future<double> getD1FromDatabase(String sessionId, String codMetrica) async {
    try {
      final dbHelper = DatabaseHelperAjustes();
      final db = await dbHelper.database;

      final results = await db.query(
        'ajustes_metrologicos',
        columns: ['d1'],
        where: 'session_id = ? AND cod_metrica = ?',
        whereArgs: [sessionId, codMetrica],
        limit: 1,
      );

      if (results.isNotEmpty && results.first['d1'] != null) {
        final d1Value = results.first['d1'];
        if (d1Value is double) {
          return d1Value;
        } else if (d1Value is int) {
          return d1Value.toDouble();
        } else if (d1Value is String) {
          return double.tryParse(d1Value) ?? 0.1;
        }
      }
      return 0.1;
    } catch (e) {
      debugPrint('Error al obtener d1: $e');
      return 0.1;
    }
  }

  /// Obtiene D correspondiente para una carga dada (para plataformas multirrango)
  static Future<double> getDForCarga(String sessionId, String codMetrica, double carga) async {
    try {
      final dbHelper = DatabaseHelperAjustes();
      final db = await dbHelper.database;

      final results = await db.query(
        'ajustes_metrologicos',
        columns: ['d1', 'd2', 'd3', 'cap_max1', 'cap_max2', 'cap_max3'],
        where: 'session_id = ? AND cod_metrica = ?',
        whereArgs: [sessionId, codMetrica],
        limit: 1,
      );

      if (results.isNotEmpty) {
        final data = results.first;
        final d1 = double.tryParse(data['d1']?.toString() ?? '') ?? 0.1;
        final d2 = double.tryParse(data['d2']?.toString() ?? '') ?? 0.1;
        final d3 = double.tryParse(data['d3']?.toString() ?? '') ?? 0.1;

        final capMax1 = double.tryParse(data['cap_max1']?.toString() ?? '') ?? 0.0;
        final capMax2 = double.tryParse(data['cap_max2']?.toString() ?? '') ?? 0.0;
        final capMax3 = double.tryParse(data['cap_max3']?.toString() ?? '') ?? 0.0;

        if (carga <= capMax1 && capMax1 > 0) return d1;
        if (carga <= capMax2 && capMax2 > 0) return d2;
        if (carga <= capMax3 && capMax3 > 0) return d3;
        return d1;
      }
      return 0.1;
    } catch (e) {
      debugPrint('Error al obtener D: $e');
      return 0.1;
    }
  }

  /// Calcula cuántos lugares decimales debe tener un valor `d`
  static int getDecimalPlaces(double dValue) {
    if (dValue >= 1) return 0;
    if (dValue >= 0.1) return 1;
    if (dValue >= 0.01) return 2;
    if (dValue >= 0.001) return 3;
    
    // Fallback genérico para valores muy pequeños
    String text = dValue.toString();
    if (text.contains('.')) {
      return text.split('.')[1].length;
    }
    return 0;
  }

  /// Genera una lista de 11 sugerencias basadas en el valor actual y dValue
  static List<String> generateIndicationSuggestions(
    String cargaText,
    String currentValue,
    double dValue,
  ) {
    if (dValue == 0) return [];
    
    final carga = double.tryParse(cargaText.replaceAll(',', '.')) ?? 0.0;
    final decimalPlaces = getDecimalPlaces(dValue);

    // Si el valor actual está vacío, usa la carga como base
    final baseText = currentValue.trim().isEmpty ? cargaText : currentValue;
    final baseValue = double.tryParse(baseText.replaceAll(',', '.')) ?? carga;

    return List.generate(11, (i) {
      final value = baseValue + ((i - 5) * dValue);
      return value.toStringAsFixed(decimalPlaces);
    });
  }
}
