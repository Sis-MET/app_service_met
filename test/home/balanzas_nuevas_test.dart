import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:service_met/home/services/local_service_record_repository.dart';
import 'package:service_met/home/widgets/asignar_codigo_sheet.dart';
import 'package:service_met/home/widgets/balanzas_nuevas_section.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  const nueva = {
    'cod_metrica': '0032-11-151026093012',
    'marca': 'OHAUS',
    'modelo': 'Defender',
    'serie': 'B1234',
  };

  test('distingue las balanzas nuevas de las registradas', () {
    expect(esBalanzaNueva(nueva), isTrue);
    expect(esBalanzaNueva({'cod_metrica': '0032-11-020'}), isFalse);
    expect(esBalanzaNueva({}), isFalse);
  });

  testWidgets('explica los pasos y permite subir antes las registradas',
      (tester) async {
    Map<String, dynamic>? elegida;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: BalanzasNuevasSection(
            registros: const [nueva],
            hayRegistradas: true,
            onAsignar: (registro) => elegida = registro,
          ),
        ),
      ),
    ));

    expect(find.text('1 balanza nueva sin código definitivo'), findsOneWidget);
    expect(find.text('Registre la balanza en DataMET.'), findsOneWidget);
    expect(find.textContaining('puede subir las balanzas ya registradas'),
        findsOneWidget);
    expect(find.text('0032-11-151026093012'), findsOneWidget);

    await tester.tap(find.text('Asignar código'));
    expect(elegida, nueva);
  });

  group('asignar código', () {
    late List<String> guardados;
    String? resultado;

    Future<void> abrir(
      WidgetTester tester, {
      VerificarCodigo? verificar,
      BuscarEnCatalogo? buscar,
      GuardarCodigo? guardar,
    }) async {
      guardados = [];
      resultado = null;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () async {
                  resultado = await showAsignarCodigoSheet(
                    context,
                    registro: nueva,
                    verificar: verificar,
                    buscarEnCatalogo: buscar,
                    guardar: guardar ?? (codigo) async => guardados.add(codigo),
                  );
                },
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
    }

    Future<void> escribir(WidgetTester tester, String texto) async {
      await tester.enterText(find.byType(TextField), texto);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
    }

    testWidgets('deja escrito el cliente y la planta del código provisional',
        (tester) async {
      await abrir(tester);
      final campo = tester.widget<TextField>(find.byType(TextField));
      expect(campo.controller!.text, '0032-11-');
      expect(find.text('0032-11-151026093012'), findsOneWidget);
      expect(find.text('OHAUS · Defender\nSerie B1234'), findsOneWidget);
    });

    testWidgets('no acepta otro código provisional', (tester) async {
      await abrir(tester);
      await escribir(tester, '0032-11-151026093013');
      await tester.tap(find.text('Guardar código'));
      await tester.pumpAndSettle();

      expect(find.textContaining('también es provisional'), findsOneWidget);
      expect(guardados, isEmpty);
      expect(resultado, isNull);
    });

    testWidgets('confirma con la precarga y guarda el código', (tester) async {
      await abrir(
        tester,
        buscar: (codigo) async => codigo == '0032-11-021'
            ? {'marca': 'OHAUS', 'modelo': 'Defender', 'inf_serie': 'B1234'}
            : null,
      );
      await escribir(tester, '0032-11-021');
      expect(find.text('En la precarga: OHAUS Defender · serie B1234.'),
          findsOneWidget);

      await tester.tap(find.text('Guardar código'));
      await tester.pumpAndSettle();
      expect(guardados, ['0032-11-021']);
      expect(resultado, '0032-11-021');
      expect(find.byType(AsignarCodigoSheet), findsNothing);
    });

    testWidgets('avisa si la serie del catálogo no coincide o no está',
        (tester) async {
      await abrir(
        tester,
        buscar: (codigo) async => codigo == '0032-11-021'
            ? {'marca': 'OHAUS', 'inf_serie': 'OTRA'}
            : null,
      );
      await escribir(tester, '0032-11-021');
      expect(find.textContaining('no es la registrada en el servicio'),
          findsOneWidget);

      await escribir(tester, '0032-11-099');
      expect(find.textContaining('No figura en la precarga'), findsOneWidget);
      // Es solo un aviso: igual puede guardarse.
      await tester.tap(find.text('Guardar código'));
      await tester.pumpAndSettle();
      expect(guardados, ['0032-11-099']);
    });

    testWidgets('advierte otro cliente o planta y bloquea un repetido',
        (tester) async {
      await abrir(
        tester,
        verificar: (codigo) async => codigo == '0032-11-020'
            ? 'La balanza 0032-11-020 ya tiene un registro en esta SECA.'
            : null,
      );
      await escribir(tester, '0040-02-001');
      expect(find.textContaining('No empieza con 0032-11'), findsOneWidget);

      await escribir(tester, '0032-11-020');
      await tester.tap(find.text('Guardar código'));
      await tester.pumpAndSettle();
      expect(find.text('La balanza 0032-11-020 ya tiene un registro en esta '
          'SECA.'), findsOneWidget);
      expect(guardados, isEmpty);
    });

    testWidgets('si no se pudo guardar muestra el motivo y no cierra',
        (tester) async {
      await abrir(
        tester,
        guardar: (_) async => throw const AsignacionCodigoException(
            'El registro cambió mientras tanto.'),
      );
      await escribir(tester, '0032-11-021');
      await tester.tap(find.text('Guardar código'));
      await tester.pumpAndSettle();

      expect(find.text('El registro cambió mientras tanto.'), findsOneWidget);
      expect(find.byType(AsignarCodigoSheet), findsOneWidget);
      expect(resultado, isNull);
    });
  });
}
