import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:service_met/home/screens/configuracion_screen.dart';
import 'package:service_met/providers/settings_provider.dart';
import 'package:service_met/screens/calidad/cumplimiento_screen.dart';
import 'package:service_met/screens/calidad/data/requisitos_17025.dart';
import 'package:service_met/screens/calidad/historial_versiones_screen.dart';
import 'package:service_met/screens/calidad/manual_screen.dart';
import 'package:service_met/screens/calidad/models/cumplimiento.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _abrir(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: screen));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('Cumplimiento', () {
    testWidgets('filtra por cláusula y despliega el detalle', (tester) async {
      await _abrir(tester, const CumplimientoScreen());

      final total = evaluacionCumplimiento.requisitos.length;
      expect(find.text('Requisitos · $total'), findsOneWidget);

      final clausula =
          find.textContaining('Registros técnicos', findRichText: true).first;
      await tester.ensureVisible(clausula);
      await tester.pumpAndSettle();
      await tester.tap(clausula);
      await tester.pumpAndSettle();
      final deRegistros =
          evaluacionCumplimiento.deClausula(Clausula.registrosTecnicos).length;
      expect(find.text('Requisitos · $deRegistros'), findsOneWidget);

      final requisito = find.text('Historial de modificaciones');
      await tester.ensureVisible(requisito);
      await tester.pumpAndSettle();
      expect(find.text('QUÉ EXIGE'), findsNothing);
      await tester.tap(requisito);
      await tester.pumpAndSettle();
      expect(find.text('QUÉ EXIGE'), findsOneWidget);
      expect(find.text('BRECHA'), findsOneWidget);
    });

    testWidgets('la búsqueda sin resultados ofrece limpiar los filtros',
        (tester) async {
      await _abrir(tester, const CumplimientoScreen());

      await tester.enterText(find.byType(TextField), 'zzz sin resultados');
      await tester.pumpAndSettle();
      expect(find.text('Ningún requisito coincide con los filtros.'),
          findsOneWidget);

      await tester.ensureVisible(find.text('Limpiar filtros'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Limpiar filtros'));
      await tester.pumpAndSettle();
      expect(
        find.text('Requisitos · ${evaluacionCumplimiento.requisitos.length}'),
        findsOneWidget,
      );
    });
  });

  group('Manual de uso', () {
    testWidgets('busca, abre la sección y marca pasos', (tester) async {
      await _abrir(tester, const ManualScreen());

      await tester.enterText(find.byType(TextField), 'Confirmar SECA');
      await tester.pumpAndSettle();
      expect(find.textContaining('resultado(s)'), findsOneWidget);

      await tester
          .ensureVisible(find.textContaining('Calibración de balanzas'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Calibración de balanzas'));
      await tester.pumpAndSettle();
      expect(find.text('Pasos del asistente'), findsOneWidget);
      expect(find.text('Toca un paso al completarlo'), findsOneWidget);

      await tester.ensureVisible(find.text('Cliente y Planta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cliente y Planta'));
      await tester.pumpAndSettle();
      expect(find.textContaining('1 de 8 hechos'), findsOneWidget);
    });

    testWidgets('navega a la sección siguiente', (tester) async {
      await _abrir(tester, const ManualScreen());

      await tester.tap(find.text('1. Acerca de ServiceMET'));
      await tester.pumpAndSettle();

      final siguiente = find.text('Antes de empezar');
      await tester.ensureVisible(siguiente);
      await tester.pumpAndSettle();
      await tester.tap(siguiente);
      await tester.pumpAndSettle();
      expect(find.text('2 de 14'), findsOneWidget);
    });
  });

  testWidgets('el historial marca la versión instalada', (tester) async {
    await _abrir(
      tester,
      const HistorialVersionesScreen(versionInstalada: '6.3.3+15'),
    );

    expect(find.text('Instalada: 6.3.3+15'), findsOneWidget);
    expect(find.text('Instalada'), findsOneWidget);
    expect(find.text('NUEVO'), findsOneWidget);
    expect(find.text('Próxima versión'), findsOneWidget);
  });

  testWidgets('Ajustes muestra la sección de calidad y abre el tablero',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'ServiceMET',
      packageName: 'bo.metrica.smet',
      version: '6.3.3',
      buildNumber: '15',
      buildSignature: '',
    );
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => SettingsProvider(),
      child: const MaterialApp(home: ConfiguracionScreen()),
    ));
    await tester.pumpAndSettle();

    final panel = find.text('Cumplimiento NB/ISO/IEC 17025');
    await tester.ensureVisible(panel);
    await tester.pumpAndSettle();
    expect(find.text('Manual de uso'), findsOneWidget);
    expect(find.text('Historial de versiones'), findsOneWidget);

    await tester.tap(panel);
    await tester.pumpAndSettle();
    expect(find.text('Cumplimiento'), findsOneWidget);
  });
}
