import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:service_met/widgets/service_ui/balanza_info_button.dart';
import 'package:service_met/widgets/service_ui/ficha_instrumento.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  test('ordena los rangos por capacidad sin tocar los guardados', () {
    final rangos = RangoInstrumento.ordenados(
      capacidades: ['1500', '300.0', '0'],
      d: ['0.5', '0.1', '0'],
      e: ['5', '1', '0'],
      decimales: ['1', '1', '0'],
    );

    expect(rangos.map((r) => r.numero), [1, 2]);
    expect(rangos.map((r) => r.capacidad), [300, 1500]);
    // El Rango 1 en pantalla es cap_max2.
    expect(rangos.first.guardado, 2);
    expect(rangos.first.d, '0.1');
    expect(rangos.last.e, '5');
  });

  test('formatea medidas sin ceros de más', () {
    expect(formatoMedida('300.0'), '300');
    expect(formatoMedida(0.050), '0.05');
    expect(formatoMedida('1,5'), '1.5');
    expect(formatoMedida('0'), '');
    expect(formatoMedida(null), '');
  });

  testWidgets('la ficha muestra el Rango 1 como el menor', (tester) async {
    // Alto suficiente para que la lista construya todas las tarjetas.
    tester.view.physicalSize = const Size(1080, 4200);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: FichaInstrumentoSheet(
          info: ServiceBalanzaInfo(
            codMetrica: '0032-11-020',
            marca: 'Mettler Toledo',
            modelo: 'IND570',
            unidad: 'kg',
            capMax1: '600',
            d1: '0.2',
            e1: '0.2',
            dec1: '1',
            capMax2: '300',
            d2: '0.1',
            e2: '0.1',
            dec2: '1',
            capMax3: '0',
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('0032-11-020'), findsOneWidget);
    expect(find.text('Catálogo'), findsOneWidget);
    expect(find.text('Mettler Toledo · IND570'), findsOneWidget);
    expect(find.text('De menor a mayor capacidad'), findsOneWidget);

    // La tabla de rangos, en orden: 300 kg y luego 600 kg.
    Finder fila(String inicio) => find.byWidgetPredicate((widget) =>
        widget is Semantics &&
        (widget.properties.label ?? '').startsWith(inicio));
    final rango1 = fila('Rango 1: 300 kg, d 0.1, e 0.1, 1 decimales');
    final rango2 = fila('Rango 2: 600 kg');
    expect(rango1, findsOneWidget);
    expect(rango2, findsOneWidget);
    expect(tester.getTopLeft(rango1).dy,
        lessThan(tester.getTopLeft(rango2).dy));
    expect(fila('Rango 3'), findsNothing);
    // Encabezados con la unidad, una sola vez.
    expect(find.text('CAP. MÁX (kg)'), findsOneWidget);
    expect(find.text('d (kg)'), findsOneWidget);
    // La escala, también de menor a mayor.
    expect(tester.getTopLeft(find.text('300 kg')).dx,
        lessThan(tester.getTopLeft(find.text('600 kg')).dx));
  });

  testWidgets('una balanza nueva avisa que su código es provisional',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: FichaInstrumentoEncabezado(
            codMetrica: '0032-11-151026093012',
            rangos: [],
          ),
        ),
      ),
    ));

    expect(find.text('Nueva'), findsOneWidget);
    expect(find.textContaining('Código provisional'), findsOneWidget);
    expect(find.text('Sin capacidades registradas'), findsOneWidget);
  });
}
