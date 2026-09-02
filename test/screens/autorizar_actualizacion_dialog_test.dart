import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_met/screens/precarga/widgets/autorizar_actualizacion_dialog.dart';

/// Regresión: el controller se creaba en `_updateData` y se liberaba apenas
/// `showDialog` completaba su Future. Para ese momento la ruta seguía animando
/// su salida y el TextField se reconstruía, lanzando "A TextEditingController
/// was used after being disposed" desde `_AnimatedState.didUpdateWidget`.
void main() {
  Future<String?> abrirDialogo(WidgetTester tester) async {
    String? resultado;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                resultado = await showDialog<String>(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => const AutorizarActualizacionDialog(),
                );
              },
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    return resultado;
  }

  testWidgets('cancelar cierra el diálogo sin usar un controller disposed',
      (tester) async {
    await abrirDialogo(tester);
    expect(find.byType(TextField), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(find.byType(AutorizarActualizacionDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('confirmar devuelve la contraseña y no deja excepciones',
      (tester) async {
    await abrirDialogo(tester);

    await tester.enterText(find.byType(TextField), 'clave123');
    await tester.tap(find.text('Actualizar'));
    await tester.pumpAndSettle();

    expect(find.byType(AutorizarActualizacionDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('enviar desde el teclado cierra sin excepciones', (tester) async {
    await abrirDialogo(tester);

    await tester.enterText(find.byType(TextField), 'clave123');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.byType(AutorizarActualizacionDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
