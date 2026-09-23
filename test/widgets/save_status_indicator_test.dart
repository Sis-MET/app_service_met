import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_met/widgets/service_ui/service_app_bar.dart';

void main() {
  Future<void> show(WidgetTester tester, SaveStatus status) =>
      tester.pumpWidget(MaterialApp(
        home: Scaffold(
          appBar: AppBar(actions: [SaveStatusIndicator(status: status)]),
        ),
      ));

  bool visible(String key) => find.byKey(ValueKey(key)).evaluate().isNotEmpty;

  testWidgets('al abrir lo ya guardado no se anuncia', (tester) async {
    await show(tester, SaveStatus.local);
    expect(visible('hidden'), isTrue);
    expect(find.byType(Tooltip), findsNothing);
  });

  testWidgets('pendiente, guardando y guardado; luego se retira',
      (tester) async {
    await show(tester, SaveStatus.local);

    await show(tester, SaveStatus.pending);
    await tester.pump(const Duration(milliseconds: 300));
    expect(visible('pending'), isTrue);
    expect(find.byTooltip('Cambios pendientes de guardar en este dispositivo'),
        findsOneWidget);

    await show(tester, SaveStatus.saving);
    await tester.pump(const Duration(milliseconds: 300));
    expect(visible('saving'), isTrue);
    expect(visible('pending'), isFalse);

    await show(tester, SaveStatus.local);
    await tester.pump(const Duration(milliseconds: 300));
    expect(visible('saved'), isTrue);

    // Tras mostrarse el check sale con su animación y deja el hueco vacío.
    await tester.pump(SaveStatusIndicator.savedHold);
    await tester.pump(const Duration(milliseconds: 250));
    expect(visible('saved'), isFalse);
    expect(visible('hidden'), isTrue);
  });

  testWidgets('un error queda visible hasta resolverse', (tester) async {
    await show(tester, SaveStatus.saving);
    await show(tester, SaveStatus.error);
    await tester.pump(const Duration(seconds: 3));
    expect(visible('error'), isTrue);

    await show(tester, SaveStatus.idle);
    await tester.pump(const Duration(milliseconds: 250));
    expect(visible('error'), isFalse);
  });

  testWidgets('ocupa siempre el mismo ancho', (tester) async {
    await show(tester, SaveStatus.idle);
    final hidden = tester.getSize(find.byType(SaveStatusIndicator));
    await show(tester, SaveStatus.saving);
    await tester.pump(const Duration(milliseconds: 300));
    expect(
        tester.getSize(find.byType(SaveStatusIndicator)).width, hidden.width);
  });
}
