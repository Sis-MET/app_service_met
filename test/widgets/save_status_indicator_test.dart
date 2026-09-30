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

  double width(WidgetTester tester) =>
      tester.getSize(find.byType(SaveStatusIndicator)).width;

  testWidgets('sin nada que contar no ocupa lugar; al aparecer lo hace',
      (tester) async {
    await show(tester, SaveStatus.idle);
    expect(width(tester), SaveStatusIndicator.collapsedWidth);

    await show(tester, SaveStatus.pending);
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      width(tester),
      inExclusiveRange(SaveStatusIndicator.collapsedWidth,
          SaveStatusIndicator.expandedWidth),
      reason: 'el hueco se abre con una transición',
    );
    await tester.pump(SaveStatusIndicator.resize);
    expect(width(tester), SaveStatusIndicator.expandedWidth);

    // El check ocupa su lugar mientras se ve y luego lo devuelve.
    await show(tester, SaveStatus.local);
    await tester.pump(const Duration(milliseconds: 300));
    expect(width(tester), SaveStatusIndicator.expandedWidth);
    await tester.pump(SaveStatusIndicator.savedHold);
    await tester.pumpAndSettle();
    expect(width(tester), SaveStatusIndicator.collapsedWidth);
  });

  testWidgets('con "reducir animaciones" hace lugar sin transición',
      (tester) async {
    Future<void> reduced(SaveStatus status) => tester.pumpWidget(MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: Scaffold(
              appBar: AppBar(actions: [SaveStatusIndicator(status: status)]),
            ),
          ),
        ));
    await reduced(SaveStatus.idle);
    await reduced(SaveStatus.saving);
    await tester.pump();
    expect(width(tester), SaveStatusIndicator.expandedWidth);
  });
}
