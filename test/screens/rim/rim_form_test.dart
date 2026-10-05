import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:service_met/screens/oportunidades/models/opportunity_service_context.dart';
import 'package:service_met/screens/rim/data/rim_catalogo.dart';
import 'package:service_met/screens/rim/models/rim_documento.dart';
import 'package:service_met/screens/rim/rim_flow.dart';
import 'package:service_met/screens/rim/rim_form_screen.dart';
import 'package:service_met/screens/rim/services/rim_repository.dart';
import 'package:service_met/screens/rim/services/rim_store.dart';
import 'package:service_met/widgets/service_ui/service_options_menu.dart';
import 'package:service_met/widgets/service_ui/service_workspace_layout.dart';
import 'package:service_met/widgets/service_ui/step_indicator.dart';

import 'rim_support.dart';
import 'package:service_met/theme/app_icons.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late MemoryRimStore store;

  setUp(() {
    store = MemoryRimStore();
    RimFlow.storeBuilder = () => store;
  });

  tearDown(() => RimFlow.storeBuilder = RimStore.new);

  Future<void> pump(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: home));
    await tester.pumpAndSettle();
  }

  /// Botón que abre el formulario y guarda lo que devuelve.
  Widget abridor(
    void Function(Future<RimRegistro?>) onOpen, {
    OpportunityServiceContext? service,
    bool firma = true,
  }) =>
      Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () => onOpen(Navigator.of(context).push<RimRegistro>(
              MaterialPageRoute(
                fullscreenDialog: true,
                builder: (_) => RimFormScreen(
                  serviceContext: service ?? servicioDePrueba(),
                  repository: RimRepository(
                    apiUrl: () => null,
                    loggedUser: () async => 'lmamani',
                    store: store,
                  ),
                  loggedUser: () async => 'lmamani',
                  appVersion: () async => '6.3.3+15',
                  signatureCapture: (_, firmante) async {
                    if (!firma) return null;
                    return firmante == RimFirmante.cliente
                        ? firmaDePrueba
                        : firmaRepresentanteDePrueba;
                  },
                ),
              ),
            )),
            child: const Text('abrir'),
          ),
        ),
      );

  Future<void> tocar(WidgetTester tester, Finder finder) async {
    // Un campo con foco vuelve a traer su cursor a la vista y desharía el
    // desplazamiento.
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('trae del servicio el cliente, la planta y el instrumento',
      (tester) async {
    await pump(tester, abridor((_) {}));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    expect(find.text('Recepción de instrumento'), findsOneWidget);
    expect(find.text('Paso 1 de 2 · Estado físico'), findsOneWidget);
    expect(find.text('RIM-0090-11-26'), findsOneWidget);
    expect(find.text('Soporte técnico · Mantenimiento correctivo'),
        findsOneWidget);
    expect(find.text('26-0090-11-S02'), findsOneWidget);
    expect(find.text('Coca-Cola Embol'), findsOneWidget);
    expect(find.text('Planta Viacha - LA PAZ'), findsOneWidget);
    expect(find.text('0090-11-014'), findsOneWidget);
    expect(find.text('150 kg'), findsOneWidget);
    expect(find.text('0.05 kg'), findsOneWidget);
    // No hay campos para volver a escribir cliente, planta ni instrumento.
    expect(find.widgetWithText(TextField, 'Empresa'), findsNothing);
    expect(find.widgetWithText(TextField, 'Marca'), findsNothing);
  });

  testWidgets('no avanza ni emite sin lo obligatorio, y dice qué falta',
      (tester) async {
    await pump(tester, abridor((_) {}));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Siguiente'));
    await tester.pumpAndSettle();
    expect(find.text('Paso 1 de 2 · Estado físico'), findsOneWidget);
    expect(find.text('Seleccione el estado general.'), findsOneWidget);
    expect(find.text('Seleccione el nivel de suciedad.'), findsOneWidget);

    await tocar(tester, find.byKey(const ValueKey('rim-estado-good')));
    await tocar(tester, find.byKey(const ValueKey('rim-suciedad-clean')));
    await tester.tap(find.text('Siguiente'));
    await tester.pumpAndSettle();
    expect(find.text('Paso 2 de 2 · Recepción y firmas'), findsOneWidget);

    await tester.tap(find.text('Emitir RIM'));
    await tester.pumpAndSettle();
    expect(find.text('Describa por qué se recibe el instrumento.'),
        findsOneWidget);
    expect(find.text('Indique si se realizaron pruebas.'), findsOneWidget);
    expect(find.text('Escriba el nombre de quien entrega.'), findsOneWidget);
    expect(find.text('Falta la firma del cliente.'), findsOneWidget);
    expect(find.text('Falta la firma del representante de Métrica.'),
        findsOneWidget);
    expect(find.text('¿Emitir el RIM?'), findsNothing);
    expect(store.registros, isEmpty);
  });

  testWidgets('para firmar pide primero el nombre de quien firma',
      (tester) async {
    await pump(tester, abridor((_) {}));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await tocar(tester, find.byKey(const ValueKey('rim-estado-good')));
    await tocar(tester, find.byKey(const ValueKey('rim-suciedad-clean')));
    await tester.tap(find.text('Siguiente'));
    await tester.pumpAndSettle();

    await tocar(tester, find.byKey(const ValueKey('rim-firma-cliente')));
    expect(
        find.text('Escriba el nombre de quien va a firmar.'), findsOneWidget);
    expect(find.text('Volver a firmar'), findsNothing);

    // El representante de Métrica ya se conoce por la sesión: puede firmar.
    await tocar(tester, find.byKey(const ValueKey('rim-firma-representante')));
    expect(find.text('Volver a firmar'), findsOneWidget);
  });

  testWidgets('emite el RIM firmado, lo guarda en el teléfono y lo devuelve',
      (tester) async {
    late Future<RimRegistro?> result;
    await pump(tester, abridor((future) => result = future));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    // Paso 1: inventario, daños y suciedad.
    await tocar(tester, find.widgetWithText(ActionChip, 'Presente'));
    final cable = find.descendant(
      of: find.byKey(const ValueKey('rim-componente-powerCable')),
      matching: find.widgetWithText(ChoiceChip, 'Faltante'),
    );
    await tocar(tester, cable);
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('rim-componente-loadCells')),
        matching: find.byType(TextField),
      ),
      '4',
    );
    await tocar(tester, find.byKey(const ValueKey('rim-estado-fair')));
    await tocar(
      tester,
      find.descendant(
        of: find.byKey(const ValueKey('rim-dano-scratches')),
        matching: find.byType(Checkbox),
      ),
    );
    await tocar(tester, find.widgetWithText(FilterChip, 'Plataforma'));
    await tocar(tester, find.byKey(const ValueKey('rim-suciedad-moderate')));
    await tester.tap(find.text('Siguiente'));
    await tester.pumpAndSettle();

    // Paso 2: motivo, pruebas, quien entrega y firma.
    await tester.enterText(
        find.byKey(const ValueKey('rim-motivo')), 'El indicador no enciende.');
    await tocar(tester, find.text('No'));
    await tester.enterText(
        find.byKey(const ValueKey('rim-contacto')), 'Juan Pérez');
    // En "Recepción" y en su firma.
    expect(find.text('Tec. Luis Mamani'), findsNWidgets(2),
        reason: 'el representante sale de la sesión, no se escribe');
    expect(
        find.text('Planta Viacha - Carretera a Viacha km 14'), findsOneWidget);
    await tocar(tester, find.byKey(const ValueKey('rim-firma-cliente')));
    expect(find.text('Volver a firmar'), findsOneWidget);
    await tocar(tester, find.byKey(const ValueKey('rim-firma-representante')));
    expect(find.text('Volver a firmar'), findsNWidgets(2));

    await tester.tap(find.text('Emitir RIM'));
    await tester.pumpAndSettle();
    expect(find.text('¿Emitir el RIM?'), findsOneWidget);
    expect(find.textContaining('no se puede modificar'), findsOneWidget);
    expect(
      find.textContaining(
          'firmado por Juan Pérez (cliente) y Tec. Luis Mamani (Métrica)'),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Emitir RIM').last);
    await tester.pumpAndSettle();

    expect(find.text('Recepción de instrumento'), findsNothing);
    final registro = (await result)!;
    expect(store.registros.single, same(registro));
    expect(registro.firmaCliente, firmaDePrueba);
    expect(registro.firmaRepresentante, firmaRepresentanteDePrueba);

    final rim = registro.documento;
    expect(rim.codigo, 'RIM-0090-11-26');
    expect(rim.inventario['indicator'], RimEstadoComponente.present);
    expect(rim.inventario['powerCable'], RimEstadoComponente.missing);
    expect(rim.inventario, hasLength(RimCatalogo.componentes.length));
    expect(rim.cantidades, {'loadCells': '4'});
    expect(rim.estadoGeneral, 'fair');
    expect(rim.danos, {
      'scratches': ['platform'],
    });
    expect(rim.nivelSuciedad, 'moderate');
    expect(rim.motivo, 'El indicador no enciende.');
    expect(rim.pruebasFuncionamiento, isFalse);
    expect(rim.contactoNombre, 'Juan Pérez');
    expect(rim.lugarRecepcion, 'Planta Viacha - Carretera a Viacha km 14');
    // Quién y con qué versión salen de la sesión, no de un campo.
    expect(rim.representanteMetrica, 'Tec. Luis Mamani');
    expect(rim.creadoPor, 'lmamani');
    expect(rim.appVersion, '6.3.3+15');
    expect(rim.service.metricCode, '0090-11-014');
    expect(DateTime.now().difference(rim.emitidoEn).inMinutes, 0);
  });

  testWidgets('cancelar con datos pide confirmación y no guarda nada',
      (tester) async {
    late Future<RimRegistro?> result;
    await pump(tester, abridor((future) => result = future));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    await tocar(tester, find.byKey(const ValueKey('rim-estado-good')));
    await tester.tap(find.byTooltip('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('¿Descartar el RIM?'), findsOneWidget);
    await tester.tap(find.text('Seguir llenando'));
    await tester.pumpAndSettle();
    expect(find.text('Recepción de instrumento'), findsOneWidget);

    await tester.tap(find.byTooltip('Cancelar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Descartar'));
    await tester.pumpAndSettle();
    expect(find.text('Recepción de instrumento'), findsNothing);
    expect(await result, isNull);
    expect(store.registros, isEmpty);
  });

  group('desde el servicio', () {
    Widget servicio({
      OpportunityServiceContext Function()? contextBuilder,
      Future<void> Function(BuildContext)? onCambiarBalanza,
    }) =>
        ServiceWorkspaceLayout(
          title: 'Mantenimiento correctivo',
          steps: const [
            StepData(title: 'Inspección', subtitle: 'Paso 1', icon: Icons.info),
            StepData(
                title: 'Pruebas', subtitle: 'Paso 2', icon: AppIcons.balanza),
          ],
          stepWidgets: const [
            Center(child: Text('Contenido del paso 1')),
            Center(child: Text('Contenido del paso 2')),
          ],
          currentStep: 1,
          menuActions: [
            RimMenuAction(
              contextBuilder: contextBuilder ?? servicioDePrueba,
              onCambiarBalanza: onCambiarBalanza,
            ),
          ],
          exitSuggestion: rimExitSuggestion(
            contextBuilder: contextBuilder ?? servicioDePrueba,
            onCambiarBalanza: onCambiarBalanza,
          ),
          onExit: () async => false,
        );

    testWidgets('el menú ⋮ ofrece emitir el RIM', (tester) async {
      await pump(tester, servicio());

      await tester.tap(find.byTooltip(ServiceOptionsMenu.tooltip));
      await tester.pumpAndSettle();

      expect(find.text(RimMenuAction.title), findsOneWidget);
      expect(find.byIcon(RimMenuAction.menuIcon), findsOneWidget);
    });

    testWidgets('sin instrumento elegido avisa y no abre el formulario',
        (tester) async {
      await pump(
        tester,
        servicio(
          contextBuilder: () => OpportunityServiceContext(
            serviceType: OpportunityServiceType.calibracion,
            serviceName: 'Calibración',
            capturedAt: DateTime(2026, 10, 1),
          ),
        ),
      );

      await tester.tap(find.byTooltip(ServiceOptionsMenu.tooltip));
      await tester.pumpAndSettle();
      await tester.tap(find.text(RimMenuAction.title));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Primero seleccione el instrumento del servicio.'),
          findsOneWidget);
      expect(find.text('Recepción de instrumento'), findsNothing);
      // El aviso se retira solo.
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });

    testWidgets('al salir a medias sugiere el RIM si la balanza no lo tiene',
        (tester) async {
      await pump(tester, servicio());

      await tester.tap(find.byTooltip(ServiceOptionsMenu.tooltip));
      await tester.pumpAndSettle();
      await tester.tap(find.text(ServiceOptionsMenu.exitLabel));
      await tester.pumpAndSettle();

      expect(find.text('¿Salir de el servicio?'), findsOneWidget);
      expect(
          find.textContaining('emita el RIM antes de salir'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Emitir RIM'), findsOneWidget);
      // "Seguir aquí" no abre nada.
      await tester.tap(find.text('Seguir aquí'));
      await tester.pumpAndSettle();
      expect(find.text('Contenido del paso 2'), findsOneWidget);
      expect(find.text('Recepción de instrumento'), findsNothing);
    });

    testWidgets('con el RIM ya emitido, salir no vuelve a sugerirlo',
        (tester) async {
      await store.insert(
          rimDePrueba(), firmaDePrueba, firmaRepresentanteDePrueba);
      await pump(tester, servicio());

      await tester.tap(find.byTooltip(ServiceOptionsMenu.tooltip));
      await tester.pumpAndSettle();
      await tester.tap(find.text(ServiceOptionsMenu.exitLabel));
      await tester.pumpAndSettle();

      expect(find.text('¿Salir de el servicio?'), findsOneWidget);
      expect(find.textContaining('emita el RIM'), findsNothing);
      expect(find.widgetWithText(OutlinedButton, 'Emitir RIM'), findsNothing);
    });

    testWidgets('un servicio que ya tiene RIM pregunta antes de emitir otro',
        (tester) async {
      await store.insert(
          rimDePrueba(), firmaDePrueba, firmaRepresentanteDePrueba);
      await pump(tester, servicio());

      await tester.tap(find.byTooltip(ServiceOptionsMenu.tooltip));
      await tester.pumpAndSettle();
      await tester.tap(find.text(RimMenuAction.title));
      await tester.pumpAndSettle();

      expect(find.text('Este instrumento ya tiene un RIM'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.text('Recepción de instrumento'), findsNothing);
      expect(find.text('Contenido del paso 2'), findsOneWidget);
    });
  });
}
