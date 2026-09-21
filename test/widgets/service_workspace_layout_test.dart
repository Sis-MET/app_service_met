import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_met/widgets/service_ui/nav_pill.dart';
import 'package:service_met/widgets/service_ui/service_workspace_layout.dart';
import 'package:service_met/widgets/service_ui/step_indicator.dart';

void main() {
  testWidgets('la píldora queda encima de la barra de navegación de 3 botones',
      (tester) async {
    // La app dibuja detrás de la barra (edge-to-edge); con tres botones la
    // barra mide 48 de alto.
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);
    tester.view.padding = const FakeViewPadding(bottom: 48);
    tester.view.viewPadding = const FakeViewPadding(bottom: 48);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: ServiceWorkspaceLayout(
          title: 'Diagnóstico',
          steps: const [
            StepData(title: 'Datos', subtitle: 'Paso 1', icon: Icons.info),
            StepData(title: 'Pruebas', subtitle: 'Paso 2', icon: Icons.scale),
          ],
          stepWidgets: const [SizedBox(), SizedBox()],
          currentStep: 0,
          onNext: () {},
        ),
      ),
    );

    final pildora = tester.getRect(find.byType(ServiceNavPill));
    expect(pildora.bottom, lessThanOrEqualTo(800 - 48 - 20));

    // Los pasos llegan hasta el borde, por detrás de la barra, como en el
    // inicio: si terminaran encima quedaría una franja lisa que el degradado
    // inferior oscurece hasta verse negra.
    expect(tester.getRect(find.byType(PageView)).bottom, 800);
    final context = tester.element(find.byType(PageView));
    expect(ServiceNavPill.pagePadding(context).bottom, 100 + 48);
  });
}
