import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_met/screens/calibracion/widgets/calibration_number_field.dart';
import 'package:service_met/widgets/service_ui/step_indicator.dart';
import 'package:service_met/theme/app_icons.dart';

void main() {
  testWidgets('un pendiente lleva al campo y deshacer recupera su valor',
      (tester) async {
    final navigator = CalibrationFieldNavigator();
    final value = TextEditingController(text: '10');
    addTearDown(value.dispose);
    tester.view.physicalSize = const Size(360, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final changes = <String>[];
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
      body: CalibrationFieldNavigationScope(
        navigator: navigator,
        child: SingleChildScrollView(
            child: Column(children: [
          const SizedBox(height: 900),
          CalibrationNumberField(
            controller: value,
            column: 'indicacion1_1',
            onChanged: changes.add,
          ),
        ])),
      ),
    )));
    await tester.enterText(find.byType(TextField), '12');
    expect(navigator.canUndoInStep(7), isTrue);
    final revealed = navigator.reveal('indicacion1_1');
    await tester.pumpAndSettle();
    expect(await revealed, isTrue);
    expect(
        tester.getRect(find.byType(CalibrationNumberField)).top, lessThan(600));
    final undone = navigator.undoInStep(7);
    await tester.pumpAndSettle();
    expect(await undone, isTrue);
    expect(value.text, '10');
    expect(changes, ['12', '10']);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('la barra distingue revisión de completado', (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: StepIndicator(
      currentStep: 2,
      steps: [
        StepData(
            title: 'Cliente',
            subtitle: 'Acme',
            icon: AppIcons.empresa,
            progress: StepProgress.complete),
        StepData(
            title: 'Planta',
            subtitle: 'La Paz',
            icon: AppIcons.planta,
            progress: StepProgress.review),
        StepData(
            title: 'SECA',
            subtitle: 'Pendiente',
            icon: AppIcons.qr,
            progress: StepProgress.pending),
      ],
    ))));
    final semantics = tester.ensureSemantics();
    expect(find.bySemanticsLabel('Paso 2: Planta, requiere revisión'),
        findsOneWidget);
    semantics.dispose();
    expect(find.text('3 / 3'), findsOneWidget);
  });
}
