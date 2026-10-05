import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:service_met/home/widgets/home_bottom_bar.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  const destinos = ['Inicio', 'Servicios', 'Precarga', 'Otros'];

  Future<void> pump(
    WidgetTester tester, {
    required int actual,
    ValueChanged<int>? onTap,
    double ancho = 360,
    ThemeMode modo = ThemeMode.light,
  }) async {
    tester.view.physicalSize = Size(ancho * 3, 800 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      themeMode: modo,
      darkTheme: ThemeData.dark(),
      home: Scaffold(
        bottomNavigationBar: HomeBottomBar(
          currentIndex: actual,
          onTap: onTap ?? (_) {},
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('el destino abierto muestra su nombre; los demás, solo el ícono',
      (tester) async {
    await pump(tester, actual: 0);

    expect(find.text('Inicio'), findsOneWidget);
    for (final otro in destinos.skip(1)) {
      expect(find.text(otro), findsNothing);
      // Siguen identificados para el lector de pantalla.
      expect(find.bySemanticsLabel(otro), findsOneWidget);
    }
    expect(
      tester.getSemantics(find.bySemanticsLabel('Inicio')),
      matchesSemantics(
        label: 'Inicio',
        isButton: true,
        isSelected: true,
        hasSelectedState: true,
        hasTapAction: true,
      ),
    );
  });

  testWidgets('tocar otro destino avisa cuál; el abierto no', (tester) async {
    final elegidos = <int>[];
    await pump(tester, actual: 1, onTap: elegidos.add);

    await tester.tap(find.bySemanticsLabel('Precarga'));
    await tester.tap(find.bySemanticsLabel('Servicios'));
    expect(elegidos, [2]);
  });

  testWidgets('la píldora pasa al nuevo destino', (tester) async {
    var actual = 0;
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: StatefulBuilder(
        builder: (context, setState) => Scaffold(
          bottomNavigationBar: HomeBottomBar(
            currentIndex: actual,
            onTap: (index) => setState(() => actual = index),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final antes = tester.getSize(find.bySemanticsLabel('Otros')).width;
    await tester.tap(find.bySemanticsLabel('Otros'));
    await tester.pumpAndSettle();
    expect(find.text('Otros'), findsOneWidget);
    expect(find.text('Inicio'), findsNothing);
    expect(tester.getSize(find.bySemanticsLabel('Otros')).width,
        greaterThan(antes));
  });

  testWidgets('es más angosta que la pantalla, centrada y de ancho fijo',
      (tester) async {
    Rect capsula() => tester.getRect(find.byKey(HomeBottomBar.capsulaKey));

    await pump(tester, actual: 0, ancho: 412);
    final conInicio = capsula();
    expect(conInicio.width, lessThan(412 - 32));
    expect(conInicio.center.dx, closeTo(206, 0.5));

    // Con otro destino abierto la cápsula no cambia de tamaño.
    await pump(tester, actual: 1, ancho: 412);
    expect(capsula().width, conInicio.width);
  });

  testWidgets('sigue el tema claro u oscuro de la app', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    Future<void> conTema(ThemeMode modo) async {
      await tester.pumpWidget(MaterialApp(
        themeMode: modo,
        theme: ThemeData.light(),
        darkTheme: ThemeData.dark(),
        home: Scaffold(
          bottomNavigationBar: HomeBottomBar(currentIndex: 0, onTap: (_) {}),
        ),
      ));
      await tester.pumpAndSettle();
    }

    Color fondo() => (tester
            .widget<AnimatedContainer>(find.byKey(HomeBottomBar.capsulaKey))
            .decoration! as BoxDecoration)
        .color!;
    Color tinta() =>
        DefaultTextStyle.of(tester.element(find.text('Inicio'))).style.color!;

    await conTema(ThemeMode.light);
    expect(fondo(), NavBarPaleta.claro.fondo);
    expect(tinta(), NavBarPaleta.claro.activo);

    // Cambiar el tema con la app abierta actualiza la barra.
    await conTema(ThemeMode.dark);
    expect(fondo(), NavBarPaleta.oscuro.fondo);
    expect(tinta(), NavBarPaleta.oscuro.activo);

    await conTema(ThemeMode.light);
    expect(fondo(), NavBarPaleta.claro.fondo);
  });

  testWidgets('cabe en un teléfono angosto, con letra grande y en oscuro',
      (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    for (var i = 0; i < destinos.length; i++) {
      await pump(tester, actual: i, ancho: 320, modo: ThemeMode.dark);
      expect(tester.takeException(), isNull);
    }
  });
}
