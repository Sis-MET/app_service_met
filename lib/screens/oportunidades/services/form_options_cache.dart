import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/bitrix_crm.dart';

/// Últimas opciones del formulario descargadas de Bitrix24, para que en
/// planta, sin conexión, el técnico pueda elegir igual la ciudad.
abstract class FormOptionsCache {
  Future<BitrixFormOptions?> read();
  Future<void> write(BitrixFormOptions options);
}

class SharedPreferencesFormOptionsCache implements FormOptionsCache {
  static const key = 'bitrix_form_options';

  const SharedPreferencesFormOptionsCache();

  @override
  Future<BitrixFormOptions?> read() async {
    final raw = (await SharedPreferences.getInstance()).getString(key);
    if (raw == null || raw.isEmpty) return null;
    final decoded = jsonDecode(raw);
    return decoded is Map
        ? BitrixFormOptions.fromJson(Map<String, dynamic>.from(decoded))
        : null;
  }

  @override
  Future<void> write(BitrixFormOptions options) async {
    await (await SharedPreferences.getInstance())
        .setString(key, jsonEncode(options.toJson()));
  }
}
