import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_met/screens/soporte_new/precarga/precarga_controller.dart';
import 'package:service_met/screens/soporte_new/precarga/widgets/seca_step.dart';

void main() {
  testWidgets('permite reemplazar y editar el correlativo de la OTST',
      (tester) async {
    final controller = PrecargaController()
      ..plantaCodigo = '0090-11'
      ..generateSuggestedSeca();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnimatedBuilder(
            animation: controller,
            builder: (_, __) => SecaStep(controller: controller),
          ),
        ),
      ),
    );

    final field = find.byType(TextField);
    await tester.tap(field);
    await tester.enterText(field, '2');
    await tester.pump();

    expect(controller.cotizacionSuffix, 'S02');
    final year = DateTime.now().year.toString().substring(2);
    expect(controller.suggestedSeca, '$year-0090-11-S02');

    await tester.tap(find.text('Código OTST'));
    await tester.pump();

    expect(tester.widget<TextField>(field).controller?.text, 'S02');
  });
}
