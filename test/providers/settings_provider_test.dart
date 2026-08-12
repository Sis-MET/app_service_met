import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_met/providers/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('usa el tema del sistema cuando no existe una preferencia', () async {
    SharedPreferences.setMockInitialValues({});

    final provider = SettingsProvider();
    await provider.ready;

    expect(provider.themeMode, ThemeMode.system);
  });

  test('migra la preferencia antigua y permite volver al modo del sistema',
      () async {
    SharedPreferences.setMockInitialValues({'is_dark_mode': true});

    final provider = SettingsProvider();
    await provider.ready;
    expect(provider.themeMode, ThemeMode.dark);

    await provider.setThemeMode(ThemeMode.system);

    final prefs = await SharedPreferences.getInstance();
    expect(provider.themeMode, ThemeMode.system);
    expect(prefs.getString('theme_mode'), 'system');
    expect(prefs.containsKey('is_dark_mode'), isFalse);
  });

  test('guarda las selecciones clara y oscura de forma explícita', () async {
    SharedPreferences.setMockInitialValues({});
    final provider = SettingsProvider();
    await provider.ready;

    await provider.setThemeMode(ThemeMode.light);
    expect(provider.themeMode, ThemeMode.light);

    await provider.setThemeMode(ThemeMode.dark);
    expect(provider.themeMode, ThemeMode.dark);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('theme_mode'), 'dark');
  });
}
