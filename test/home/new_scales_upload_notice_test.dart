import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_met/home/models/calibration_upload_models.dart';
import 'package:service_met/home/widgets/new_scales_upload_notice.dart';

void main() {
  test('cuenta únicamente las balanzas nuevas insertadas', () {
    final result = CalibrationUploadResult.fromJson({
      'message': '3 registros insertados',
      'uploaded': [
        {'index': 0, 'codigoRegistro': 'A', 'n': 1, 'isNewScale': true},
        {'index': 1, 'codigoRegistro': 'B', 'n': 2, 'isNewScale': false},
        {'index': 2, 'codigoRegistro': 'C', 'n': 3, 'isNewScale': true},
      ],
      'invalidRecords': [],
    });

    expect(result.newScaleCount, 2);
  });

  testWidgets('avisa que las balanzas nuevas deben registrarse en DataMET',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => showNewScalesUploadNotice(context, 2),
              child: const Text('Mostrar'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Mostrar'));
    await tester.pumpAndSettle();

    expect(find.text('2 balanzas nuevas'), findsOneWidget);
    expect(find.textContaining('dirigirse a DataMET'), findsOneWidget);

    await tester.tap(find.text('Entendido'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
