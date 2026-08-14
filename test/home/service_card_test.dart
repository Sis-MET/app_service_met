import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_met/home/models/servicio_model.dart';
import 'package:service_met/home/widgets/service_card.dart';

void main() {
  testWidgets('muestra el resumen de calibración en el orden solicitado',
      (tester) async {
    final servicio = ServicioResumen(
      tipo: TipoServicio.calibracion,
      codigo: 'PLANTA-C02-26',
      cantidad: 3,
      fecha: '2026-08-14',
      items: const [
        {'cliente': 'Cliente Demo', 'planta': 'Planta Central'},
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ServiceCard(servicio: servicio),
        ),
      ),
    );

    final texts = tester
        .widgetList<Text>(find.byType(Text))
        .map((widget) => widget.data ?? widget.textSpan?.toPlainText() ?? '')
        .toList();

    expect(
      texts.where((text) => text.isNotEmpty).take(5),
      [
        'SECA PLANTA-C02-26',
        'Cliente: Cliente Demo',
        'Planta: Planta Central',
        'Fecha: 14/08/2026',
        'Cantidad de balanzas: 3',
      ],
    );
  });

  testWidgets('muestra el mismo resumen para soporte técnico', (tester) async {
    final servicio = ServicioResumen(
      tipo: TipoServicio.soporte,
      codigo: '26-0090-11-S02',
      cantidad: 2,
      fecha: '2026-08-13',
      items: const [
        {'cliente': 'Cliente Soporte', 'planta': 'Planta Norte'},
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ServiceCard(servicio: servicio),
        ),
      ),
    );

    final texts = tester
        .widgetList<Text>(find.byType(Text))
        .map((widget) => widget.data ?? widget.textSpan?.toPlainText() ?? '')
        .where((text) => text.isNotEmpty)
        .take(5);

    expect(texts, [
      'OTST 26-0090-11-S02',
      'Cliente: Cliente Soporte',
      'Planta: Planta Norte',
      'Fecha: 13/08/2026',
      'Cantidad de servicios: 2',
    ]);
  });
}
