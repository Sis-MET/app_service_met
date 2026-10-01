import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:service_met/login/services/auth_api_service.dart';
import 'package:service_met/login/services/connection_profile_service.dart';
import 'package:service_met/screens/oportunidades/models/opportunity_service_context.dart';
import 'package:service_met/screens/oportunidades/opportunity_form_screen.dart';
import 'package:service_met/screens/oportunidades/services/bitrix_opportunity_api.dart';
import 'package:service_met/screens/oportunidades/services/opportunity_repository.dart';
import 'package:service_met/screens/oportunidades/widgets/opportunity_menu_action.dart';
import 'package:service_met/widgets/service_ui/service_options_menu.dart';
import 'package:service_met/widgets/service_ui/service_workspace_layout.dart';
import 'package:service_met/widgets/service_ui/step_indicator.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _apiUrl = 'https://192.168.1.5:3100';

class _FakeAuth extends AuthApiService {
  _FakeAuth()
      : super(_apiUrl, client: MockClient((_) async => http.Response('', 500)));

  @override
  Future<String?> readValidToken() async => 'token';
}

OpportunityServiceContext _support() => OpportunityServiceContext.fromSupport(
      serviceName: 'Instalación',
      otst: '26-0090-11-S02',
      codMetrica: '0090-11-014',
      userName: 'Tec. Luis Mamani',
      clienteNombre: 'Coca-Cola Embol S.A.',
      plantaNombre: 'Planta Viacha',
      instrumentoData: const {
        'marca': 'OHAUS',
        'cap_max1': '150',
        'd1': '0.05',
        'unidad': 'kg'
      },
    );

/// Servicio de soporte mínimo, en el paso 2 de 2.
class _SupportHost extends StatelessWidget {
  const _SupportHost();

  @override
  Widget build(BuildContext context) {
    return ServiceWorkspaceLayout(
      title: 'Instalación',
      steps: const [
        StepData(title: 'Condiciones', subtitle: 'Paso 1', icon: Icons.info),
        StepData(title: 'Pruebas', subtitle: 'Paso 2', icon: Icons.scale),
      ],
      stepWidgets: const [
        Center(child: Text('Contenido del paso 1')),
        Center(child: Text('Contenido del paso 2')),
      ],
      currentStep: 1,
      menuActions: [OpportunityMenuAction(contextBuilder: _support)],
      onExit: () async => true,
    );
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() {
    SharedPreferences.setMockInitialValues({'logged_user': 'lmamani'});
    PackageInfo.setMockInitialValues(
      appName: 'ServiceMET',
      packageName: 'service_met',
      version: '6.3.3',
      buildNumber: '15',
      buildSignature: '',
    );
  });

  Future<void> pumpScreen(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ConnectionProfileService(),
        child: MaterialApp(home: home),
      ),
    );
    await tester.pumpAndSettle();
  }

  OpportunityRepository fakeRepository(
    Future<http.Response> Function(http.Request) handler,
  ) {
    final client = MockClient(handler);
    return OpportunityRepository(
      apiUrl: () => _apiUrl,
      loggedUser: () async => 'lmamani',
      apiFactory: (url) =>
          BitrixOpportunityApi(url, client: client, auth: _FakeAuth()),
    );
  }

  testWidgets('se abre desde el menú ⋮ del servicio y vuelve al mismo paso',
      (tester) async {
    await pumpScreen(tester, const _SupportHost());
    expect(find.text('Contenido del paso 2'), findsOneWidget);
    expect(find.byIcon(Icons.handshake_outlined), findsNothing,
        reason: 'ya no ocupa lugar en el AppBar');

    await tester.tap(find.byTooltip(ServiceOptionsMenu.tooltip));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.handshake_outlined), findsOneWidget);
    await tester.tap(find.text(OpportunityMenuAction.title));
    await tester.pumpAndSettle();

    expect(find.text('Nueva oportunidad'), findsOneWidget);
    expect(find.text('Soporte técnico · Instalación'), findsOneWidget);
    expect(find.text('26-0090-11-S02'), findsOneWidget);
    expect(find.text('0090-11-014'), findsOneWidget);
    expect(find.text('150 kg'), findsOneWidget);
    expect(find.text('0.05 kg'), findsOneWidget);
    expect(find.text('Tec. Luis Mamani'), findsOneWidget);

    await tester.tap(find.byTooltip('Cancelar'));
    await tester.pumpAndSettle();

    expect(find.text('Nueva oportunidad'), findsNothing);
    expect(find.text('Contenido del paso 2'), findsOneWidget);
  });

  testWidgets('con datos incompletos no registra y explica qué falta',
      (tester) async {
    final requests = <http.Request>[];
    late Future<OpportunityFormOutcome?> result;
    await pumpScreen(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => result = OpportunityFormScreen.open(
            context,
            serviceContext: _support(),
            repositoryBuilder: () => fakeRepository((request) async {
              requests.add(request);
              return http.Response('{}', 500);
            }),
          ),
          child: const Text('abrir'),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Registrar oportunidad'));
    await tester.pumpAndSettle();

    expect(find.text('Seleccione el tipo de oportunidad.'), findsOneWidget);
    expect(find.text('Describa la oportunidad detectada.'), findsOneWidget);
    expect(find.text('Nueva oportunidad'), findsOneWidget);
    expect(requests.where((request) => request.method == 'POST'), isEmpty,
        reason: 'no intenta registrar con datos incompletos');

    // Con algo escrito, cancelar pide confirmación antes de descartar.
    await tester.enterText(find.widgetWithText(TextField, 'Descripción'),
        'Cliente pide cotización.');
    await tester.tap(find.byTooltip('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('¿Descartar la oportunidad?'), findsOneWidget);
    await tester.tap(find.text('Descartar'));
    await tester.pumpAndSettle();
    expect(find.text('Nueva oportunidad'), findsNothing);
    expect(await result, isNull);
  });

  testWidgets('busca la empresa, carga sus contactos y arma el título',
      (tester) async {
    final queries = <String>[];
    final repository = fakeRepository((request) async {
      if (request.url.path == '/api/bitrix/companies') {
        queries.add(request.url.queryParameters['q']!);
        return http.Response(
          jsonEncode({
            'items': [
              {'id': 120, 'title': 'EMBOL S.A.'},
            ],
            'total': 1,
            'truncated': false,
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      if (request.url.path == '/api/bitrix/companies/120/contacts') {
        return http.Response(
          jsonEncode({
            'items': [
              {
                'id': 55,
                'name': 'Juan',
                'lastName': 'Pérez',
                'post': 'Jefe de planta',
                'isPrimary': true,
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      return http.Response('{}', 404);
    });

    await pumpScreen(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => OpportunityFormScreen.open(
            context,
            serviceContext: _support(),
            repositoryBuilder: () => repository,
          ),
          child: const Text('abrir'),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, 'Título'))
          .controller!
          .text,
      'Oportunidad ServiceMET - Coca-Cola Embol S.A.',
    );

    await tester.tap(find.text('Empresa Bitrix24'));
    await tester.pumpAndSettle();

    // La búsqueda inicial usa el cliente de ServiceMET sin "S.A.", pero la
    // empresa se elige a mano.
    expect(queries, ['Coca-Cola Embol']);
    expect(find.widgetWithText(ActionChip, 'Embol'), findsOneWidget);
    await tester.tap(find.text('EMBOL S.A.'));
    await tester.pumpAndSettle();

    expect(find.text('ID 120'), findsOneWidget);
    expect(find.text('Sin contacto'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, 'Título'))
          .controller!
          .text,
      'Oportunidad ServiceMET - EMBOL S.A.',
    );

    await tester.ensureVisible(find.text('Tipo de oportunidad'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tipo de oportunidad'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reemplazo de indicador').last);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, 'Título'))
          .controller!
          .text,
      'Oportunidad ServiceMET - Reemplazo de indicador - EMBOL S.A.',
    );
  });
}
