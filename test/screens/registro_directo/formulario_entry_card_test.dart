import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_met/screens/registro_directo/widgets/formulario_entry_card.dart';

void main() {
  testWidgets(
      'la tarjeta abre la lista y el botón llena uno nuevo, también en '
      'pantallas angostas', (tester) async {
    tester.view.physicalSize = const Size(320 * 3, 640 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final toques = <String>[];

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: FormularioEntryCard(
            icon: Icons.handshake_outlined,
            title: 'Oportunidades comerciales',
            subtitle: '3 pendiente(s) de enviar a Bitrix24.',
            pending: 3,
            onOpenList: () => toques.add('lista'),
            newLabel: 'Nueva oportunidad',
            onNew: () => toques.add('nuevo'),
          ),
        ),
      ),
    ));

    expect(tester.takeException(), isNull, reason: 'sin desbordes');
    expect(find.text('3'), findsOneWidget);

    await tester.tap(find.text('Oportunidades comerciales'));
    await tester.tap(find.widgetWithText(FilledButton, 'Nueva oportunidad'));
    expect(toques, ['lista', 'nuevo']);
  });
}
