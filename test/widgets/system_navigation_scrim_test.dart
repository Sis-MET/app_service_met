import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_met/widgets/system_navigation_scrim.dart';

const _scrim = ValueKey('system-navigation-scrim');

/// Una pantalla con un botón pegado al borde inferior, debajo del degradado.
Widget _app(VoidCallback onTap) => MaterialApp(
      builder: (context, child) => SystemNavigationScrim(child: child!),
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            onTap: onTap,
            child: const SizedBox(width: 400, height: 60, child: Text('abajo')),
          ),
        ),
      ),
    );

void _barra(WidgetTester tester, double alto) {
  tester.view.padding = FakeViewPadding(bottom: alto);
  tester.view.viewPadding = FakeViewPadding(bottom: alto);
}

void main() {
  testWidgets('oscurece la barra de navegación y un poco más arriba',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);
    _barra(tester, 48);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(() {}));

    final rect = tester.getRect(find.byKey(_scrim));
    expect(rect.bottom, 800);
    expect(rect.height, 48 + SystemNavigationScrim.fadeAbove);
  });

  testWidgets('los toques pasan a lo que queda debajo', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);
    _barra(tester, 48);
    addTearDown(tester.view.reset);
    var toques = 0;

    await tester.pumpWidget(_app(() => toques++));
    await tester.tap(find.text('abajo'));

    expect(toques, 1);
  });

  testWidgets('sin barra de navegación no dibuja nada', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);
    _barra(tester, 0);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(() {}));

    expect(find.byKey(_scrim), findsNothing);
  });

  testWidgets('si la barra aparece o se va, lo de adentro conserva su estado',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);
    _barra(tester, 48);
    addTearDown(tester.view.reset);

    // Sin GlobalKey: si el degradado cambiara la estructura, se rearmaría.
    await tester.pumpWidget(
      const MaterialApp(home: SystemNavigationScrim(child: _ConEstado())),
    );
    final antes = tester.state(find.byType(_ConEstado));

    _barra(tester, 0);
    await tester.pump();
    expect(find.byKey(_scrim), findsNothing);
    expect(tester.state(find.byType(_ConEstado)), same(antes));

    _barra(tester, 48);
    await tester.pump();
    expect(find.byKey(_scrim), findsOneWidget);
    expect(tester.state(find.byType(_ConEstado)), same(antes));
  });
}

class _ConEstado extends StatefulWidget {
  const _ConEstado();

  @override
  State<_ConEstado> createState() => _ConEstadoState();
}

class _ConEstadoState extends State<_ConEstado> {
  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}
