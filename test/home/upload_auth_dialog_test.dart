import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_met/home/widgets/upload_auth_dialog.dart';

void main() {
  testWidgets(
      'cancelar cierra el diálogo sin reutilizar un controller disposed',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => showDialog<String>(
                context: context,
                barrierDismissible: false,
                builder: (_) => const UploadAuthDialog(usuario: 'Tecnico'),
              ),
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(find.byType(UploadAuthDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
