import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:service_met/theme/app_icons.dart';
import 'package:service_met/theme/app_theme.dart';

/// Toda la app usa los íconos de [AppIcons], de una sola familia y un solo
/// trazo. Estas pruebas avisan si una pantalla vuelve a usar `Icons` de
/// Material o Font Awesome, que se verían distintos al resto.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  final fuentes = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .toList();

  test('ninguna pantalla usa Icons de Material ni Font Awesome', () {
    final material = RegExp(r'\bIcons\.\w+');
    final fontAwesome = RegExp(r'FontAwesomeIcons|FaIcon\b|font_awesome');
    final usos = <String>[];
    for (final file in fuentes) {
      final lineas = file.readAsLinesSync();
      for (var i = 0; i < lineas.length; i++) {
        final linea = lineas[i];
        if (linea.trimLeft().startsWith('//')) continue;
        if (material.hasMatch(linea) || fontAwesome.hasMatch(linea)) {
          usos.add('${file.path}:${i + 1}: ${linea.trim()}');
        }
      }
    }
    expect(usos, isEmpty,
        reason: 'Use AppIcons (lib/theme/app_icons.dart) en su lugar.');
  });

  test('el catálogo usa solo Lucide con trazo 300', () {
    final catalogo = File('lib/theme/app_icons.dart').readAsStringSync();
    final declaraciones =
        RegExp(r'static const IconData (\w+) = ([\w.]+);').allMatches(catalogo);
    expect(declaraciones, isNotEmpty);
    for (final declaracion in declaraciones) {
      expect(declaracion.group(2), matches(RegExp(r'^LucideIcons\.\w+300$')),
          reason: 'AppIcons.${declaracion.group(1)}');
    }
    expect(AppIcons.balanza.fontFamily, 'Lucide300');
    expect(AppIcons.buscar.fontPackage, 'lucide_icons_flutter');
  });

  testWidgets('volver, cerrar y menú automáticos usan los íconos de la app',
      (tester) async {
    late BuildContext contexto;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (context) {
        contexto = context;
        return const SizedBox();
      }),
    ));

    for (final tema in [
      AppTheme.buildLightTheme(contexto),
      AppTheme.buildDarkTheme(contexto),
    ]) {
      final acciones = tema.actionIconTheme!;
      IconData? icono(Widget Function(BuildContext)? builder) =>
          (builder!(contexto) as Icon).icon;
      expect(icono(acciones.backButtonIconBuilder), AppIcons.atras);
      expect(icono(acciones.closeButtonIconBuilder), AppIcons.cerrar);
      expect(icono(acciones.drawerButtonIconBuilder), AppIcons.menu);
    }
  });
}
