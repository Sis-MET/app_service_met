import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_met/widgets/service_ui/editable_suggestion_field.dart';
import 'package:service_met/theme/app_icons.dart';

void main() {
  testWidgets('acepta un tipo de equipo que no pertenece al catalogo',
      (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    var savedValue = '';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EditableSuggestionField(
            controller: controller,
            label: 'Tipo de Equipo',
            icon: AppIcons.balanza,
            options: const ['BALANZA', 'BASCULA'],
            onChanged: (value) => savedValue = value,
            isDark: false,
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'PLATAFORMA DE PESAJE');
    await tester.pump();

    expect(controller.text, 'PLATAFORMA DE PESAJE');
    expect(savedValue, 'PLATAFORMA DE PESAJE');
  });

  testWidgets('permite elegir una sugerencia del catalogo', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    var savedValue = '';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EditableSuggestionField(
            controller: controller,
            label: 'Tipo de Equipo',
            icon: AppIcons.balanza,
            options: const ['BALANZA', 'BASCULA'],
            onChanged: (value) => savedValue = value,
            isDark: false,
          ),
        ),
      ),
    );

    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.tap(find.text('BASCULA'));
    await tester.pumpAndSettle();

    expect(controller.text, 'BASCULA');
    expect(savedValue, 'BASCULA');
  });
}
