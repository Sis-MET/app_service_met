import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:service_met/screens/oportunidades/models/opportunity_service_context.dart';
import 'package:service_met/screens/registro_directo/catalogo_servicio.dart';
import 'package:service_met/screens/registro_directo/seleccion_rapida_screen.dart';

/// Precarga mínima: dos clientes; EMBOL tiene dos plantas y Solo una.
class _Catalogo implements CatalogoServicio {
  static const clientes = [
    {
      'codigo_cliente': '0090',
      'cliente_id': '90',
      'cliente': 'EMBOL',
      'razonsocial': 'Embotelladoras Bolivianas Unidas S.A.',
    },
    {
      'codigo_cliente': '0032',
      'cliente_id': '32',
      'cliente': 'Solo Planta',
      'razonsocial': 'Solo Planta S.R.L.',
    },
  ];

  static const plantas = [
    {
      'cliente_id': '90',
      'codigo_planta': '0090-11',
      'planta': 'Planta Viacha',
      'dep': 'LA PAZ',
      'dir': 'Carretera a Viacha km 14',
    },
    {
      'cliente_id': '90',
      'codigo_planta': '0090-21',
      'planta': 'Planta Cochabamba',
      'dep': 'COCHABAMBA',
      'dir': 'Av. Blanco Galindo',
    },
    {
      'cliente_id': '32',
      'codigo_planta': '0032-11',
      'planta': 'Planta Única',
      'dep': 'ORURO',
      'dir': 'Zona Este',
    },
  ];

  static const instrumentos = [
    {
      'cod_metrica': '0090-11-014',
      'tipo_instrumento': 'Balanza de plataforma',
      'marca': 'OHAUS',
      'modelo': 'Defender 5000',
      'inf_serie': 'B845123',
      'cap_max1': '150',
      'd1': '0.05',
      'unidad': 'kg',
      'ubicacion': 'Almacén',
    },
    {
      'cod_metrica': '0090-11-015',
      'tipo_instrumento': 'Báscula camionera',
      'marca': 'Mettler Toledo',
      'cap_max1': '60000',
      'd1': '20',
      'unidad': 'kg',
    },
  ];

  @override
  Future<List<Map<String, dynamic>>> buscarClientes(String texto) async => [
        for (final cliente in clientes)
          if ('${cliente['cliente']} ${cliente['razonsocial']}'
              .toLowerCase()
              .contains(texto.trim().toLowerCase()))
            cliente,
      ];

  @override
  Future<Map<String, dynamic>?> clientePorCodigo(String codigo) async {
    for (final cliente in clientes) {
      if (cliente['codigo_cliente'] == codigo) return cliente;
    }
    return null;
  }

  @override
  Future<List<Map<String, dynamic>>> plantasDe(
    Map<String, dynamic> cliente,
  ) async =>
      [
        for (final planta in plantas)
          if (planta['cliente_id'] == cliente['cliente_id']) planta,
      ];

  @override
  Future<List<Map<String, dynamic>>> instrumentosDe(
    Map<String, dynamic> planta,
  ) async =>
      [
        for (final instrumento in instrumentos)
          if (instrumento['cod_metrica']!
              .startsWith('${planta['codigo_planta']}-'))
            instrumento,
      ];
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  /// Abre la selección y deja en [resultado] lo que devuelve.
  Future<List<OpportunityServiceContext?>> abrir(
    WidgetTester tester,
    PropositoSeleccion proposito, {
    String? qr,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final resultado = <OpportunityServiceContext?>[];
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () async => resultado.add(
              await Navigator.of(context).push<OpportunityServiceContext>(
                MaterialPageRoute(
                  builder: (_) => SeleccionRapidaScreen(
                    proposito: proposito,
                    userName: 'Tec. Luis Mamani',
                    catalogo: _Catalogo(),
                    scanQr: (_) async => qr,
                  ),
                ),
              ),
            ),
            child: const Text('abrir'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    return resultado;
  }

  Future<void> elegir(WidgetTester tester, String campo, String opcion) async {
    await tester.tap(find.byKey(ValueKey('seleccion-$campo')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(opcion));
    await tester.pumpAndSettle();
  }

  testWidgets('RIM: exige cliente, planta e instrumento', (tester) async {
    final resultado = await abrir(tester, PropositoSeleccion.rim);
    expect(find.text('Nuevo RIM'), findsOneWidget);

    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.text('Seleccione el cliente.'), findsOneWidget);

    await elegir(tester, 'cliente', 'EMBOL');
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.text('Seleccione la planta.'), findsOneWidget);

    await elegir(tester, 'planta', 'Planta Viacha');
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.text('Seleccione el instrumento.'), findsOneWidget);
    expect(resultado, isEmpty);

    await elegir(tester, 'instrumento', '0090-11-014');
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    final service = resultado.single!;
    expect(service.serviceType, OpportunityServiceType.directo);
    expect(service.serviceName, 'Registro directo');
    expect(service.serviceLabel, 'Registro directo');
    expect(service.seca, isNull);
    expect(service.sessionId, isNull);
    expect(service.technician, 'Tec. Luis Mamani');
    expect(service.clientCode, '0090');
    expect(service.clientName, 'EMBOL');
    expect(service.clientLegalName, 'Embotelladoras Bolivianas Unidas S.A.');
    expect(service.plantCode, '0090-11');
    expect(service.plantName, 'Planta Viacha');
    expect(service.plantDepartment, 'LA PAZ');
    expect(service.plantAddress, 'Carretera a Viacha km 14');
    expect(service.metricCode, '0090-11-014');
    expect(service.equipmentType, 'Balanza de plataforma');
    expect(service.serial, 'B845123');
    expect(service.capacityWithUnit, '150 kg');
    expect(service.divisionWithUnit, '0.05 kg');
  });

  testWidgets('el buscador filtra los clientes de la precarga', (tester) async {
    await abrir(tester, PropositoSeleccion.rim);
    await tester.tap(find.byKey(const ValueKey('seleccion-cliente')));
    await tester.pumpAndSettle();
    expect(find.text('EMBOL'), findsOneWidget);
    expect(find.text('Solo Planta'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Buscar'), 'embot');
    await tester.pumpAndSettle();
    expect(find.text('EMBOL'), findsOneWidget);
    expect(find.text('Solo Planta'), findsNothing);
  });

  testWidgets('un cliente con una sola planta la elige solo', (tester) async {
    await abrir(tester, PropositoSeleccion.rim);
    await elegir(tester, 'cliente', 'Solo Planta');

    expect(find.text('Planta Única'), findsOneWidget);
    expect(find.text('0032-11 · ORURO'), findsOneWidget);
  });

  testWidgets('el QR del instrumento completa cliente, planta e instrumento',
      (tester) async {
    final resultado = await abrir(
      tester,
      PropositoSeleccion.rim,
      qr: '0090-11-015 Báscula camionera',
    );

    await tester.tap(find.text('Escanear QR del instrumento'));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    expect(find.text('EMBOL'), findsOneWidget);
    expect(find.text('Planta Viacha'), findsOneWidget);
    expect(find.text('0090-11-015'), findsOneWidget);

    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(resultado.single!.metricCode, '0090-11-015');
    expect(resultado.single!.capacityWithUnit, '60000 kg');
  });

  testWidgets('un QR de un instrumento que no está en la precarga avisa',
      (tester) async {
    await abrir(tester, PropositoSeleccion.rim, qr: '0090-11-999');

    await tester.tap(find.text('Escanear QR del instrumento'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('El instrumento 0090-11-999 no está en la precarga.'),
        findsOneWidget);
    // El cliente y la planta sí quedan elegidos.
    expect(find.text('EMBOL'), findsOneWidget);
    expect(find.text('Planta Viacha'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('RIM de un instrumento no registrado: código provisional',
      (tester) async {
    final resultado = await abrir(tester, PropositoSeleccion.rim);
    await elegir(tester, 'cliente', 'EMBOL');
    await elegir(tester, 'planta', 'Planta Cochabamba');

    await tester.tap(find.text('El instrumento no está en la lista'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Usar estos datos'));
    await tester.pumpAndSettle();
    expect(find.text('Escriba qué instrumento es.'), findsOneWidget);

    await tester.enterText(
        find.widgetWithText(TextField, 'Instrumento'), 'Balanza analítica');
    await tester.enterText(
        find.widgetWithText(TextField, 'Marca'), 'Sartorius');
    await tester.enterText(
        find.widgetWithText(TextField, 'Capacidad máxima'), '220');
    await tester.enterText(find.widgetWithText(TextField, 'Unidad'), 'g');
    await tester.tap(find.text('Usar estos datos'));
    await tester.pumpAndSettle();
    expect(find.text('Instrumento no registrado'), findsOneWidget);

    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    final service = resultado.single!;
    // Mismo formato que una balanza nueva: PLANTA-DDMMAAHHMMSS.
    expect(service.metricCode, matches(RegExp(r'^0090-21-\d{12}$')));
    expect(service.equipmentType, 'Balanza analítica');
    expect(service.brand, 'Sartorius');
    expect(service.capacityWithUnit, '220 g');
  });

  testWidgets('oportunidad: basta el cliente', (tester) async {
    final resultado = await abrir(tester, PropositoSeleccion.oportunidad);
    expect(find.text('Nueva oportunidad'), findsOneWidget);
    expect(find.text('Planta (opcional)'), findsOneWidget);
    expect(find.text('Instrumento (opcional)'), findsOneWidget);
    expect(find.text('El instrumento no está en la lista'), findsNothing);

    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.text('Seleccione el cliente.'), findsOneWidget);

    await elegir(tester, 'cliente', 'EMBOL');
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    final service = resultado.single!;
    expect(service.serviceType, OpportunityServiceType.directo);
    expect(service.clientName, 'EMBOL');
    expect(service.clientCode, '0090');
    expect(service.plantName, isNull);
    expect(service.metricCode, isNull);
  });

  testWidgets('cancelar no devuelve nada', (tester) async {
    final resultado = await abrir(tester, PropositoSeleccion.oportunidad);
    await elegir(tester, 'cliente', 'EMBOL');
    await tester.tap(find.byTooltip('Cancelar'));
    await tester.pumpAndSettle();
    expect(resultado, [null]);
  });
}
