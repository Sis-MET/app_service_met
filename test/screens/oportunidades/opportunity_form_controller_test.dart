import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:service_met/login/services/auth_api_service.dart';
import 'package:service_met/screens/oportunidades/controllers/opportunity_form_controller.dart';
import 'package:service_met/screens/oportunidades/data/tipos_oportunidad.dart';
import 'package:service_met/screens/oportunidades/models/bitrix_crm.dart';
import 'package:service_met/screens/oportunidades/models/opportunity_service_context.dart';
import 'package:service_met/screens/oportunidades/services/bitrix_opportunity_api.dart';
import 'package:service_met/screens/oportunidades/services/form_options_cache.dart';
import 'package:service_met/screens/oportunidades/services/opportunity_repository.dart';

const _apiUrl = 'https://192.168.1.5:3100';

class _FakeAuth extends AuthApiService {
  _FakeAuth()
      : super(_apiUrl, client: MockClient((_) async => http.Response('', 500)));

  @override
  Future<String?> readValidToken() async => 'token';
}

class _MemoryCache implements FormOptionsCache {
  BitrixFormOptions? stored;

  _MemoryCache([this.stored]);

  @override
  Future<BitrixFormOptions?> read() async => stored;

  @override
  Future<void> write(BitrixFormOptions options) async => stored = options;
}

const _cities = BitrixFormOptions(
  cities: ['La Paz', 'Cochabamba', 'Santa Cruz', 'Potosí'],
  cityRequired: true,
);

void main() {
  OpportunityServiceContext service({String? department}) =>
      OpportunityServiceContext(
        serviceType: OpportunityServiceType.calibracion,
        serviceName: 'Calibración',
        capturedAt: DateTime(2026, 9, 29),
        clientName: 'Coca-Cola Embol S.A.',
        clientLegalName: 'Embotelladoras Bolivianas Unidas S.A.',
        plantDepartment: department,
      );

  /// Cada búsqueda queda esperando hasta que la prueba la responda.
  final pending = <String, Completer<http.Response>>{};

  OpportunityFormController controller({
    String? department,
    _MemoryCache? cache,
    BitrixFormOptions? online,
  }) {
    final client = MockClient((request) {
      if (request.url.path == '/api/bitrix/form-options') {
        return Future.value(online == null
            ? http.Response('{}', 503)
            : http.Response(jsonEncode(online.toJson()), 200));
      }
      final completer = Completer<http.Response>();
      pending[request.url.queryParameters['q']!] = completer;
      return completer.future;
    });
    return OpportunityFormController(
      serviceContext: service(department: department),
      loggedUser: () async => 'aquispe',
      searchDebounce: Duration.zero,
      repository: OpportunityRepository(
        apiUrl: () => _apiUrl,
        loggedUser: () async => 'aquispe',
        optionsCache: cache ?? _MemoryCache(),
        apiFactory: (url) =>
            BitrixOpportunityApi(url, client: client, auth: _FakeAuth()),
      ),
    );
  }

  http.Response companies(String title) => http.Response(
        jsonEncode({
          'items': [
            {'id': 1, 'title': title},
          ],
          'total': 1,
        }),
        200,
      );

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  setUp(pending.clear);

  test('una respuesta vieja no pisa la búsqueda más reciente', () async {
    final form = controller();
    addTearDown(form.dispose);

    form.search('coca');
    await settle();
    form.search('embol');
    await settle();

    pending['embol']!.complete(companies('EMBOL S.A.'));
    await settle();
    pending['coca']!.complete(companies('COCA-COLA (viejo)'));
    await settle();

    expect(form.results!.items.single.title, 'EMBOL S.A.');
    expect(form.searching, isFalse);
  });

  test('cerrar el formulario con una búsqueda en curso no avisa a nadie',
      () async {
    final form = controller();
    await settle();
    var notifications = 0;
    form.addListener(() => notifications++);

    form.search('embol');
    await settle();
    final before = notifications;
    form.dispose();

    pending['embol']!.complete(companies('EMBOL S.A.'));
    await settle();
    expect(notifications, before);
  });

  test('sugiere palabras del cliente sin sufijos societarios', () {
    final form = controller();
    addTearDown(form.dispose);
    expect(form.suggestedQuery, 'Coca-Cola Embol');
    expect(form.searchSuggestions,
        ['Coca-Cola', 'Embol', 'Embotelladoras', 'Bolivianas', 'Unidas']);
  });

  test('el título deja de generarse cuando el técnico lo escribe', () {
    final form = controller();
    addTearDown(form.dispose);
    expect(form.titleController.text,
        'Oportunidad ServiceMET - Coca-Cola Embol S.A.');

    form.titleController.text = 'Cambio de indicador báscula 2';
    form.onTitleChanged(form.titleController.text);
    form.selectType(null);
    expect(form.titleController.text, 'Cambio de indicador báscula 2');
  });

  test('guardar pendiente no exige empresa, registrar sí', () async {
    final form = controller();
    addTearDown(form.dispose);
    expect(await form.submit(), isNull);
    expect(
        form.fieldErrors.keys, containsAll(['company', 'type', 'description']));
    expect(pending, isEmpty, reason: 'no llama a la API con datos incompletos');
  });

  test('el detalle elegido lleva su línea de Bitrix24 y la ciudad elegida', () {
    final form = controller();
    addTearDown(form.dispose);
    form.selectType(OpportunityTypeCatalog.reemplazoIndicador);
    expect(form.buildDraft().typeLine, 'VENTA');
    expect(form.buildDraft().city, isNull, reason: 'automática');

    form.selectType(OpportunityTypeCatalog.calibracion);
    form.selectCity('Oruro');
    final json = form.buildDraft().toJson();
    expect(json['opportunityType'], {
      'key': 'calibracion',
      'label': 'Calibración de otro equipo',
      'line': 'CALIBRACIÓN',
    });
    expect(json['city'], 'Oruro');
  });

  test('sin conexión usa las ciudades guardadas; con conexión, las vigentes',
      () async {
    final offline = controller(
      department: 'LA PAZ',
      cache: _MemoryCache(_cities),
    );
    addTearDown(offline.dispose);
    await settle();
    await settle();
    expect(offline.cityOptions, _cities.cities);
    expect(offline.suggestedCity, 'La Paz');

    final cache = _MemoryCache();
    final online = controller(
      cache: cache,
      online: const BitrixFormOptions(cities: ['Tarija'], cityRequired: true),
    );
    addTearDown(online.dispose);
    await settle();
    await settle();
    expect(online.cityOptions, ['Tarija']);
    expect(cache.stored!.cities, ['Tarija'],
        reason: 'queda para trabajar sin red');
  });

  test('sin departamento y con ciudad obligatoria, pide elegirla', () async {
    final form = controller(cache: _MemoryCache(_cities));
    addTearDown(form.dispose);
    await settle();
    await settle();
    expect(await form.submit(), isNull);
    expect(form.fieldErrors['city'], 'Elija la ciudad del prospecto.');

    form.selectCity('Potosí');
    expect(form.fieldErrors.containsKey('city'), isFalse);
  });
}
