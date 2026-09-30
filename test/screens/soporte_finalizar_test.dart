import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:service_met/database/soporte_tecnico/database_helper_instalacion.dart';
import 'package:service_met/screens/soporte_new/modulos/instalacion/controllers/instalacion_controller.dart';
import 'package:service_met/screens/soporte_new/modulos/instalacion/models/instalacion_model.dart';
import 'package:service_met/screens/soporte_new/modulos/instalacion/stac_instalacion.dart';
import 'package:service_met/screens/soporte_new/widgets/fin_servicio_screen.dart';
import 'package:service_met/widgets/service_ui/nav_pill.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _otst = '26-0032-11-S01';
const _sessionId = '0001';
const _codMetrica = '0032-11-020';

void main() {
  late Directory directory;
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    directory =
        await Directory.systemTemp.createTemp('servicemet_finalizar_test_');
    await databaseFactory.setDatabasesPath(directory.path);
  });
  tearDownAll(() async {
    await DatabaseHelperInstalacion().close();
  });

  testWidgets('Finalizar revisa todos los pasos y lleva al que falta',
      (tester) async {
    // Instalación guardada en "Estado Final" con las condiciones y el cierre
    // completos pero sin las pruebas, como si se hubiera saltado el paso 2
    // desde el panel ≡.
    await tester.runAsync(() async {
      final previo = InstalacionController(
        model: InstalacionModel(sessionId: _sessionId, codMetrica: _codMetrica),
      )
        ..secaValue = _otst
        ..initCamposEstado()
        ..comentarioGeneral = 'Instalada y nivelada'
        ..recomendacion = 'Sin recomendación'
        ..estadoFisico = 'Bueno'
        ..estadoOperacional = 'Bueno'
        ..estadoMetrologico = 'Bueno'
        ..fechaProxServicio = '2027-03-30'
        ..horaFin = '12:00:00';
      for (final campo in previo.camposEstado) {
        campo.value = 'Adecuada';
      }
      await previo.guardarSesion();
      expect(previo.lastSaveSuccessful, isTrue);
      previo
        ..currentStep = 2
        ..configureRecovery(
          personal: 'tecnico',
          clienteId: '1',
          clienteRazonSocial: '',
          plantaCodigo: '0032-11',
          plantaDireccion: '',
          plantaDepartamento: '',
          nReca: '015',
        );
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await previo.persistRecoveryProgress();
      previo.dispose();
    });

    await tester.pumpWidget(const MaterialApp(
      home: StacInstalacion(
        sessionId: _sessionId,
        secaValue: _otst,
        nReca: '015',
        codMetrica: _codMetrica,
        userName: 'tecnico',
        clienteId: '1',
        plantaCodigo: '0032-11',
      ),
    ));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 500)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Paso 3 de 3 · Estado Final'), findsOneWidget);

    await tester.tap(find.descendant(
        of: find.byType(ServiceNavPill), matching: find.text('Finalizar')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(FinServicioScreen), findsNothing,
        reason: 'no se finaliza con un paso incompleto');
    expect(find.text('Complete retorno a cero y estabilidad'), findsOneWidget);
    expect(find.text('Paso 2 de 3 · Pruebas'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)));
  });

  testWidgets('otra balanza no deja debajo el módulo ya finalizado',
      (tester) async {
    Widget pagina(String texto, VoidCallback onPressed) => Scaffold(
          body: Center(
            child: TextButton(onPressed: onPressed, child: Text(texto)),
          ),
        );

    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (inicio) => pagina(
          'inicio',
          () => Navigator.push(
            inicio,
            MaterialPageRoute(
              builder: (modulo) => pagina(
                'módulo',
                () => Navigator.push(
                  modulo,
                  MaterialPageRoute(
                    builder: (resumen) => pagina(
                      'otra balanza',
                      () => FinServicioScreen.replaceFinishedService(
                        resumen,
                        MaterialPageRoute(
                          builder: (precarga) => pagina(
                            'precarga',
                            () => Navigator.pop(precarga),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ));

    for (final paso in ['inicio', 'módulo', 'otra balanza']) {
      await tester.tap(find.text(paso));
      await tester.pumpAndSettle();
    }
    expect(find.text('precarga'), findsOneWidget);

    // Salir de la balanza nueva vuelve al inicio, no al servicio finalizado.
    await tester.tap(find.text('precarga'));
    await tester.pumpAndSettle();
    expect(find.text('inicio'), findsOneWidget);
    expect(find.text('módulo'), findsNothing);
  });
}
