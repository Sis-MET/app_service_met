import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:service_met/database/app_database.dart';
import 'package:service_met/database/precarga_bd.dart';
import 'package:service_met/models/service_session.dart';
import 'package:service_met/providers/service_session_provider.dart';
import 'package:service_met/repositories/calibration_repository.dart';
import 'package:service_met/screens/calibracion/calibration_workspace_screen.dart';
import 'package:service_met/screens/calibracion/steps/condiciones_finales_step.dart';
import 'package:service_met/screens/calibracion/steps/exportacion_step.dart';
import 'package:service_met/screens/calibracion/steps/seca_step.dart';
import 'package:service_met/theme/app_design.dart';
import 'package:service_met/screens/oportunidades/widgets/opportunity_menu_action.dart';
import 'package:service_met/widgets/service_ui/nav_pill.dart';
import 'package:service_met/widgets/service_ui/service_options_menu.dart';
import 'package:service_met/widgets/service_ui/service_steps_drawer.dart';
import 'package:service_met/widgets/service_ui/step_indicator.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// Conserva el paso preparado por la prueba al montar el workspace.
class _WorkspaceProvider extends ServiceSessionProvider {
  _WorkspaceProvider() : super(CalibrationRepository());
  @override
  Future<void> initialize(
      {required String userName, String? secaValue, String? sessionId}) async {}
}

void main() {
  late Directory directory;
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    directory =
        await Directory.systemTemp.createTemp('servicemet_sticker_test_');
    await databaseFactory.setDatabasesPath(directory.path);
    await DatabaseHelperPrecarga().database;
  });
  tearDownAll(() async {
    await AppDatabase().close();
    await DatabaseHelperPrecarga().close();
    // Solo la carpeta temporal creada por esta prueba.
    if (directory.parent.absolute.path == Directory.systemTemp.absolute.path &&
        directory.uri.pathSegments
            .where((s) => s.isNotEmpty)
            .last
            .startsWith('servicemet_sticker_test_')) {
      await directory.delete(recursive: true);
    }
  });

  Future<ServiceSessionProvider> pumpStep(WidgetTester tester, Widget step,
      {String? seca}) async {
    final provider = ServiceSessionProvider(CalibrationRepository());
    await provider.createNewSession('tecnico', secaValue: seca);
    provider.updateSessionInfo(provider.session!.sessionInfo.copyWith(
        codMetrica: '0032-11-020',
        nReca: '015',
        sticker: '777',
        fechaServicio: '2025-12-30'));
    addTearDown(provider.dispose);
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: provider,
      child: MaterialApp(home: Scaffold(body: step)),
    ));
    // Deja empezar también las animaciones con demora antes de desmontar.
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    return provider;
  }

  testWidgets('el sticker usa el SECA guardado y reacciona a sus cambios',
      (tester) async {
    final provider = await pumpStep(tester, const CondicionesFinalesStep(),
        seca: '0032-11-C07-25');
    expect(find.text('0032-C07-015-25'), findsOneWidget);
    expect(find.text('Nº: 777'), findsOneWidget);
    provider.updateSessionInfo(provider.session!.sessionInfo
        .copyWith(seca: '0032-11-C09-25', nReca: '016', sticker: '778'));
    await tester.pump();
    expect(find.text('0032-C07-015-25'), findsNothing);
    expect(find.text('0032-C09-016-25'), findsOneWidget);
    expect(find.text('Nº: 778'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await provider.flushPendingSave();
  });

  testWidgets('volver al paso SECA mantiene la cotización que se escribió',
      (tester) async {
    final provider = await pumpStep(tester, const SecaStep());
    await tester.enterText(find.byType(TextField), 'C08');
    await tester.pump();
    expect(provider.cotizacion, 'C08');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: provider,
      child: const MaterialApp(home: Scaffold(body: SecaStep())),
    ));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'C08');
    expect(provider.cotizacionSuffix, 'C08');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('el workspace oculta Siguiente solo en el paso 11',
      (tester) async {
    final provider = _WorkspaceProvider();
    await provider.createNewSession('tecnico');
    provider.goToStep(10);
    addTearDown(provider.dispose);
    await tester
        .pumpWidget(ChangeNotifierProvider<ServiceSessionProvider>.value(
      value: provider,
      child: const MaterialApp(
          home: CalibrationWorkspaceScreen(userName: 'tecnico')),
    ));
    await tester.pumpAndSettle();
    expect(tester.widget<ServiceNavPill>(find.byType(ServiceNavPill)).showNext,
        isFalse);
    expect(
        find.descendant(
            of: find.byType(ServiceNavPill), matching: find.text('Siguiente')),
        findsNothing);
    await tester.tap(find.descendant(
        of: find.byType(ServiceNavPill), matching: find.byTooltip('Anterior')));
    await tester.pumpAndSettle();
    expect(provider.currentStep, 9);
    expect(tester.widget<ServiceNavPill>(find.byType(ServiceNavPill)).showNext,
        isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  /// Abre el workspace en [step] encima de una pantalla "abrir".
  Future<ServiceSessionProvider> openWorkspace(
      WidgetTester tester, int step) async {
    final provider = _WorkspaceProvider();
    await provider.createNewSession('tecnico');
    provider.goToStep(step);
    addTearDown(provider.dispose);
    await tester
        .pumpWidget(ChangeNotifierProvider<ServiceSessionProvider>.value(
      value: provider,
      child: MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        const CalibrationWorkspaceScreen(userName: 'tecnico'))),
            child: const Text('abrir'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    return provider;
  }

  testWidgets('sin flecha; Atrás retrocede un paso y nunca saca del módulo',
      (tester) async {
    final provider = await openWorkspace(tester, 2);
    expect(find.byType(AppBackButton), findsNothing);
    expect(find.byType(BackButton), findsNothing);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(provider.currentStep, 1);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(provider.currentStep, 0);

    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byType(CalibrationWorkspaceScreen), findsOneWidget);
    expect(find.textContaining('Es el primer paso'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('el panel ≡ muestra los 11 pasos y lleva a los habilitados',
      (tester) async {
    final semantics = tester.ensureSemantics();
    final provider = await openWorkspace(tester, 2);
    expect(find.byType(StepIndicator), findsNothing,
        reason: 'sin barra de pasos bajo el AppBar');
    expect(find.text('Paso 3 de 11 · SECA'), findsOneWidget);

    await tester.tap(find.byTooltip(ServiceStepsButton.tooltip));
    await tester.pumpAndSettle();
    expect(find.text('0 de 11 pasos completos'), findsOneWidget);
    expect(find.bySemanticsLabel('Paso 3 de 11: SECA, pendiente, paso actual'),
        findsOneWidget);
    // Sin cliente todavía, los pasos siguientes no se pueden abrir.
    expect(find.bySemanticsLabel('Paso 4 de 11: Instrumento, bloqueado'),
        findsOneWidget);
    Finder enPanel(String text) =>
        find.descendant(of: find.byType(Drawer), matching: find.text(text));
    await tester.tap(enPanel('Instrumento'));
    await tester.pumpAndSettle();
    expect(provider.currentStep, 2);

    await tester.tap(enPanel('Cliente'));
    await tester.pumpAndSettle();
    expect(find.byType(Drawer), findsNothing);
    expect(provider.currentStep, 0);
    expect(find.text('Paso 1 de 11 · Cliente'), findsOneWidget);
    semantics.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('sin instrumento confirmado el panel no abre las pruebas',
      (tester) async {
    final semantics = tester.ensureSemantics();
    final provider = _WorkspaceProvider();
    addTearDown(provider.dispose);
    // Como tras "otra balanza": cliente, planta y SECA listos, instrumento
    // todavía sin confirmar. Otra planta, para no sumar una balanza a la
    // SECA de las demás pruebas.
    await tester.runAsync(() async {
      await provider.createNewSession('tecnico');
      provider.updateCliente(ClienteInfo(id: '2', nombreComercial: 'Otro'));
      provider.updatePlanta(PlantaInfo(codigo: '0099-11', nombre: 'Otra'));
      expect(await provider.confirmSeca(), isTrue);
    });
    provider.goToStep(3);
    await tester
        .pumpWidget(ChangeNotifierProvider<ServiceSessionProvider>.value(
      value: provider,
      child: const MaterialApp(
          home: CalibrationWorkspaceScreen(userName: 'tecnico')),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip(ServiceStepsButton.tooltip));
    await tester.pumpAndSettle();
    expect(
        find.bySemanticsLabel('Paso 3 de 11: SECA, completo'), findsOneWidget);
    expect(find.bySemanticsLabel('Paso 5 de 11: Inspección, bloqueado'),
        findsOneWidget);
    await tester.tap(find.descendant(
        of: find.byType(Drawer), matching: find.text('Inspección')));
    await tester.pumpAndSettle();
    expect(provider.currentStep, 3);

    semantics.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(provider.flushPendingSave);
  });

  testWidgets('con el panel ≡ abierto, Atrás solo lo cierra', (tester) async {
    final provider = await openWorkspace(tester, 2);
    await tester.tap(find.byTooltip(ServiceStepsButton.tooltip));
    await tester.pumpAndSettle();
    expect(find.byType(Drawer), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(Drawer), findsNothing);
    expect(provider.currentStep, 2, reason: 'no retrocede un paso');
    expect(find.byType(CalibrationWorkspaceScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('la oportunidad comercial está en el menú ⋮', (tester) async {
    await openWorkspace(tester, 2);
    expect(find.byIcon(Icons.handshake_outlined), findsNothing);
    await tester.tap(find.byTooltip(ServiceOptionsMenu.tooltip));
    await tester.pumpAndSettle();
    expect(find.text(OpportunityMenuAction.title), findsOneWidget);
    expect(find.text(ServiceOptionsMenu.exitLabel), findsOneWidget);
    await tester.tapAt(const Offset(10, 400));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('se sale solo desde el menú ⋮, con confirmación', (tester) async {
    await openWorkspace(tester, 4);

    Future<void> elegirSalir() async {
      await tester.tap(find.byTooltip(ServiceOptionsMenu.tooltip));
      await tester.pumpAndSettle();
      await tester.tap(find.text(ServiceOptionsMenu.exitLabel));
      await tester.pumpAndSettle();
      expect(find.text('¿Salir de la calibración?'), findsOneWidget);
    }

    await elegirSalir();
    await tester.tap(find.text('Seguir aquí'));
    await tester.pumpAndSettle();
    expect(find.byType(CalibrationWorkspaceScreen), findsOneWidget);

    await elegirSalir();
    await tester.tap(find.text('Salir'));
    await tester.pumpAndSettle();
    expect(find.byType(CalibrationWorkspaceScreen), findsNothing);
    expect(find.text('abrir'), findsOneWidget);
  });

  testWidgets(
      'la revisión final muestra pendientes y vuelve al paso a corregir',
      (tester) async {
    final provider = await pumpStep(tester, const ExportacionStep());
    expect(find.text('Revisión de esta balanza'), findsOneWidget);
    expect(find.text('Instrumento'), findsOneWidget);
    expect(find.text('Corregir'), findsWidgets);
    await tester.tap(find.text('Corregir').first);
    await tester.pump();
    expect(provider.currentStep, 3);
    await tester.pumpWidget(const SizedBox.shrink());
    await provider.flushPendingSave();
  });

  testWidgets('la revisión abre otra balanza del mismo servicio',
      (tester) async {
    final provider = ServiceSessionProvider(CalibrationRepository());
    addTearDown(provider.dispose);
    late String? firstId;
    await tester.runAsync(() async {
      await provider.createNewSession('tecnico');
      provider.updateCliente(ClienteInfo(id: '1', nombreComercial: 'Cliente'));
      provider.updatePlanta(PlantaInfo(codigo: '0032-11', nombre: 'Planta'));
      expect(await provider.confirmSeca(), isTrue);
      provider.updateSessionInfo(
          provider.session!.sessionInfo.copyWith(codMetrica: 'BALANZA-01'));
      expect(await provider.flushAutoSave(), isTrue);
      firstId = provider.session!.sessionInfo.sessionId;
      await provider.resetearParaNuevaBalanza();
      provider.updateSessionInfo(
          provider.session!.sessionInfo.copyWith(codMetrica: 'BALANZA-02'));
      expect(await provider.flushAutoSave(), isTrue);
    });

    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: provider,
      child: const MaterialApp(home: Scaffold(body: ExportacionStep())),
    ));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('BALANZA-01'), findsOneWidget);
    // Sin pruebas registradas: la lista lo dice con las mismas reglas del
    // cierre y lleva directo al primer paso por completar.
    expect(
        find.textContaining('En curso · falta: Instrumento'), findsOneWidget);
    await tester.ensureVisible(find.text('Corregir').last);
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.text('Corregir').last);
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();
    expect(provider.session!.sessionInfo.sessionId, firstId);
    expect(provider.currentStep, 3);
    await tester.pumpWidget(const SizedBox.shrink());
    await provider.flushPendingSave();
  });
}
