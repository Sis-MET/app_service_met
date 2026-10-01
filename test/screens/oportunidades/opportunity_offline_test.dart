import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:service_met/login/services/auth_api_service.dart';
import 'package:service_met/screens/oportunidades/controllers/opportunity_form_controller.dart';
import 'package:service_met/screens/oportunidades/data/tipos_oportunidad.dart';
import 'package:service_met/screens/oportunidades/models/bitrix_crm.dart';
import 'package:service_met/screens/oportunidades/models/opportunity_draft.dart';
import 'package:service_met/screens/oportunidades/models/opportunity_service_context.dart';
import 'package:service_met/screens/oportunidades/services/bitrix_company_matcher.dart';
import 'package:service_met/screens/oportunidades/services/bitrix_opportunity_api.dart';
import 'package:service_met/screens/oportunidades/services/form_options_cache.dart';
import 'package:service_met/screens/oportunidades/services/opportunity_repository.dart';
import 'package:service_met/screens/oportunidades/services/pending_opportunity_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _apiUrl = 'https://192.168.1.5:3100';

class _FakeAuth extends AuthApiService {
  String? token = 'token-valido';

  _FakeAuth()
      : super(_apiUrl, client: MockClient((_) async => http.Response('', 500)));

  @override
  Future<String?> readValidToken() async => token;
}

class _NoCache implements FormOptionsCache {
  @override
  Future<BitrixFormOptions?> read() async => null;

  @override
  Future<void> write(BitrixFormOptions options) async {}
}

OpportunityServiceContext _service({
  String? code = '0072',
  String name = 'Coca-Cola Embol S.A.',
  String? legalName = 'Embotelladoras Bolivianas Unidas S.A.',
}) =>
    OpportunityServiceContext(
      serviceType: OpportunityServiceType.directo,
      serviceName: 'Registro directo',
      capturedAt: DateTime(2026, 10, 2, 9),
      clientCode: code,
      clientName: name,
      clientLegalName: legalName,
      plantDepartment: 'LA PAZ',
    );

OpportunityDraft _draft({
  OpportunityServiceContext? service,
  int? companyId,
  String? uuid,
  DateTime? createdAt,
}) =>
    OpportunityDraft(
      uuid: uuid ?? newOpportunityUuid(),
      service: service ?? _service(),
      companyId: companyId,
      companyName: companyId == null ? null : 'EMBOL S.A.',
      typeKey: 'reparacion',
      typeLabel: 'Reparación',
      title: 'Oportunidad ServiceMET - Reparación',
      description: 'El cliente solicita cotización de reparación.',
      createdAt: createdAt ?? DateTime(2026, 10, 2, 9),
    );

void main() {
  setUpAll(sqfliteFfiInit);

  group('coincidencia de nombres', () {
    test('ignora mayúsculas, tildes, puntuación y forma societaria', () {
      expect(BitrixCompanyMatcher.identity('EMBOL S.A.'), 'embol');
      expect(BitrixCompanyMatcher.identity('Coca-Cola Embol S.R.L.'),
          'coca cola embol');
      expect(BitrixCompanyMatcher.identity('  Cervecería  Boliviana, Ltda. '),
          'cerveceria boliviana');
      expect(BitrixCompanyMatcher.identity(null), '');
    });

    test('solo acepta una igualdad completa con el cliente', () {
      final service = _service();
      const candidates = [
        BitrixCompany(id: 1, title: 'EMBOL S.A.'),
        BitrixCompany(id: 2, title: 'COCA COLA EMBOL SA'),
        BitrixCompany(id: 3, title: 'Embotelladoras Bolivianas Unidas'),
        BitrixCompany(id: 4, title: 'Coca-Cola Embol Santa Cruz'),
      ];
      expect(
        BitrixCompanyMatcher.exactMatches(service, candidates)
            .map((company) => company.id),
        [2, 3],
      );
    });

    test('busca con los nombres sin forma societaria y su palabra más larga',
        () {
      expect(BitrixCompanyMatcher.queries(_service()), [
        'Coca-Cola Embol',
        'Embotelladoras Bolivianas Unidas',
        'embol',
        'embotelladoras',
      ]);
      expect(
        BitrixCompanyMatcher.queries(
            _service(name: 'Empresa, S.A.', legalName: null)),
        ['Empresa'],
      );
    });

    test('recuerda por código de cliente o, si no hay, por nombre', () {
      expect(BitrixCompanyMatcher.clientKey(_service()), 'codigo:0072');
      expect(BitrixCompanyMatcher.clientKey(_service(code: null)),
          'nombre:coca cola embol');
      expect(
        BitrixCompanyMatcher.clientKey(OpportunityServiceContext(
          serviceType: OpportunityServiceType.directo,
          serviceName: 'Registro directo',
          capturedAt: DateTime(2026),
        )),
        isNull,
      );
    });
  });

  group('con la tabla local', () {
    late Database database;
    late PendingOpportunityStore store;
    late _FakeAuth auth;
    late List<http.Request> requests;

    /// Empresas que devuelve la búsqueda de Bitrix24, o null si no hay red.
    List<Map<String, Object>>? companies;
    var leadId = 900;

    setUp(() async {
      database = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      store = PendingOpportunityStore(database: database);
      auth = _FakeAuth();
      requests = [];
      companies = const [];
      leadId = 900;
    });

    tearDown(() => database.close());

    http.Response json(int status, Object body) => http.Response(
          jsonEncode(body),
          status,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );

    OpportunityRepository repository() {
      final client = MockClient((request) async {
        requests.add(request);
        final found = companies;
        if (found == null) throw const SocketException('sin red');
        if (request.url.path == '/api/bitrix/companies') {
          return json(200, {'items': found, 'total': found.length});
        }
        if (request.url.path == '/api/bitrix/opportunities') {
          return json(201, {'leadId': ++leadId, 'duplicate': false});
        }
        return json(404, {});
      });
      return OpportunityRepository(
        apiUrl: () => _apiUrl,
        loggedUser: () async => 'aquispe',
        store: store,
        optionsCache: _NoCache(),
        apiFactory: (url) =>
            BitrixOpportunityApi(url, client: client, auth: auth),
      );
    }

    Iterable<http.Request> creadas() => requests
        .where((request) => request.url.path == '/api/bitrix/opportunities');

    test('sin conexión y sin empresa queda pendiente, sin error', () async {
      companies = null;
      final draft = _draft();

      final result = await repository().submit(draft);

      expect(result.outcome, OpportunitySubmitOutcome.savedPending);
      expect(result.error!.kind, BitrixApiErrorKind.offline);
      final stored = (await store.byUuid(draft.uuid))!;
      expect(stored.status, OpportunityStatus.pending);
      expect(stored.draft.hasCompany, isFalse);
      expect(stored.lastError, isNull,
          reason: 'todavía no se buscó: no hay nada que corregir');
      expect(stored.canSync, isTrue);
    });

    test('con una coincidencia exacta la vincula, la envía y la recuerda',
        () async {
      companies = [
        {'id': 120, 'title': 'EMBOL S.A.'},
        {'id': 121, 'title': 'Coca Cola Embol SA'},
      ];
      final draft = _draft();

      final result = await repository().submit(draft);

      expect(result.outcome, OpportunitySubmitOutcome.sent);
      expect(result.record!.draft.companyId, 121);
      expect(result.record!.draft.companySource, CompanySource.exact);
      final body = jsonDecode(creadas().single.body) as Map<String, dynamic>;
      expect(body['companyId'], 121);
      expect(body['companyName'], 'Coca Cola Embol SA');

      // La siguiente oportunidad del mismo cliente ya no busca: usa la
      // recordada, también sin conexión.
      companies = null;
      requests.clear();
      final repo = repository();
      final remembered = await repo.rememberedCompany(_service());
      expect(remembered!.id, 121);
      final resolution = await repo.resolveCompany(_service());
      expect(resolution.source, CompanySource.remembered);
      expect(requests, isEmpty);
    });

    test('la empresa elegida a mano reemplaza a la recordada', () async {
      companies = [
        {'id': 121, 'title': 'Coca Cola Embol SA'},
      ];
      final repo = repository();
      await repo.submit(_draft());
      await repo.submit(_draft(companyId: 300));

      expect((await repo.rememberedCompany(_service()))!.id, 300);
    });

    test('sin coincidencia exacta no adivina: pide elegir la empresa',
        () async {
      companies = [
        {'id': 120, 'title': 'EMBOL S.A.'},
        {'id': 122, 'title': 'Coca-Cola Embol Santa Cruz'},
      ];
      final draft = _draft();

      final result = await repository().submit(draft);

      expect(result.outcome, OpportunitySubmitOutcome.failed);
      expect(result.error!.code, OpportunityRepository.companyNotResolved);
      expect(result.error!.message, contains('no hay una coincidencia exacta'));
      expect(creadas(), isEmpty);
      final stored = (await store.byUuid(draft.uuid))!;
      expect(stored.status, OpportunityStatus.pending);
      expect(stored.lastError, contains('Elija la empresa'));
    });

    test('dos empresas con el mismo nombre: tampoco elige', () async {
      companies = [
        {'id': 121, 'title': 'Coca Cola Embol SA'},
        {'id': 125, 'title': 'COCA-COLA EMBOL S.A.'},
      ];

      final resolution = await repository().resolveCompany(_service());

      expect(resolution.company, isNull);
      expect(resolution.ambiguous, isTrue);
      expect(resolution.message, contains('más de una empresa'));
    });

    test('al volver la conexión completa y envía las pendientes', () async {
      companies = null;
      final repo = repository();
      final sinEmpresa = _draft(createdAt: DateTime(2026, 10, 2, 9));
      final conEmpresa = _draft(
        companyId: 500,
        service: _service(code: '0090', name: 'Otro Cliente', legalName: null),
        createdAt: DateTime(2026, 10, 2, 10),
      );
      await repo.submit(sinEmpresa);
      await repo.submit(conEmpresa);
      expect(await repo.countUnsent(), 2);

      // Sin conexión, sincronizar no cambia nada.
      final offline = await repo.syncPending();
      expect(offline.sent, 0);
      expect(offline.offline, contains('Sin conexión'));
      expect(await repo.countUnsent(), 2);

      companies = [
        {'id': 121, 'title': 'Coca Cola Embol SA'},
      ];
      requests.clear();
      final report = await repo.syncPending();

      expect(report.sent, 2);
      expect(report.linked, 1);
      expect(report.needCompany, 0);
      expect(report.authRequired, isFalse);
      expect(report.message, '2 oportunidad(es) enviada(s) a Bitrix24.');
      expect(await repo.countUnsent(), 0);
      expect(
        creadas().map((request) => jsonDecode(request.body)['companyId']),
        [121, 500],
      );
      final completada = (await store.byUuid(sinEmpresa.uuid))!;
      expect(completada.isSent, isTrue);
      expect(completada.draft.companySource, CompanySource.exact);
    });

    test('lo que no tiene empresa segura queda para el técnico', () async {
      companies = null;
      final repo = repository();
      final dudosa = _draft(createdAt: DateTime(2026, 10, 2, 9));
      final clara = _draft(
        companyId: 500,
        createdAt: DateTime(2026, 10, 2, 10),
        service: _service(code: '0090', name: 'Otro Cliente', legalName: null),
      );
      await repo.submit(dudosa);
      await repo.submit(clara);

      companies = [
        {'id': 120, 'title': 'EMBOL S.A.'},
      ];
      final report = await repo.syncPending();

      expect(report.sent, 1);
      expect(report.needCompany, 1);
      expect(report.message, contains('necesita(n) que elija la empresa'));
      final pendiente = (await store.byUuid(dudosa.uuid))!;
      expect(pendiente.isSent, isFalse);
      expect(pendiente.lastError, contains('Elija la empresa'));
      expect((await store.byUuid(clara.uuid))!.isSent, isTrue);
    });

    test('con la sesión vencida no pide la contraseña: lo informa', () async {
      companies = null;
      final repo = repository();
      await repo.submit(_draft(companyId: 500));
      await repo.submit(_draft(companyId: 500));

      companies = const [];
      auth.token = null;
      requests.clear();
      final report = await repo.syncPending();

      expect(report.sent, 0);
      expect(report.authRequired, isTrue);
      expect(report.message, contains('Ingrese su contraseña'));
      expect(requests, isEmpty, reason: 'se detiene en la primera');
      expect(await repo.countUnsent(), 2);
    });

    test('no reintenta sola lo que el servidor rechazó', () async {
      final draft = _draft(companyId: 500);
      await store.save(draft, status: OpportunityStatus.error, lastError: 'x');

      final report = await repository().syncPending();

      expect(report.sent, 0);
      expect(report.message, isNull);
      expect(requests, isEmpty);
    });

    group('formulario', () {
      OpportunityFormController controller(OpportunityRepository repo) =>
          OpportunityFormController(
            serviceContext: _service(),
            loggedUser: () async => 'aquispe',
            searchDebounce: Duration.zero,
            repository: repo,
          );

      void llenar(OpportunityFormController form) {
        form.selectType(OpportunityTypeCatalog.reparacion);
        form.descriptionController.text = 'El cliente solicita cotización.';
      }

      test('sin conexión, registrar deja la oportunidad pendiente', () async {
        companies = null;
        final form = controller(repository());
        addTearDown(form.dispose);
        llenar(form);

        final result = await form.submit();

        expect(result!.outcome, OpportunitySubmitOutcome.savedPending);
        expect(result.record!.draft.hasCompany, isFalse);
        expect(form.fieldErrors, isEmpty);
        expect(form.storedLocally, isTrue);
      });

      test('con conexión y sin coincidencia pide elegir la empresa', () async {
        companies = [
          {'id': 120, 'title': 'EMBOL S.A.'},
        ];
        final form = controller(repository());
        addTearDown(form.dispose);
        llenar(form);

        final result = await form.submit();

        expect(result!.outcome, OpportunitySubmitOutcome.failed);
        expect(form.fieldErrors['company'], contains('Elija la empresa'));
        expect(creadas(), isEmpty);
      });

      test('propone la empresa recordada sin marcar el formulario como tocado',
          () async {
        await store.rememberCompany(
          'codigo:0072',
          clientName: 'Coca-Cola Embol S.A.',
          company: const BitrixCompany(id: 121, title: 'Coca Cola Embol SA'),
        );
        companies = null;
        final form = controller(repository());
        addTearDown(form.dispose);
        // La lectura de la tabla local no termina en el mismo ciclo.
        for (var i = 0; i < 100 && form.company == null; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }

        expect(form.company!.id, 121);
        expect(form.companySource, CompanySource.remembered);
        expect(form.isDirty, isFalse);
        expect(form.buildDraft().companySource, CompanySource.remembered);

        // Si el técnico elige otra, pasa a ser su elección.
        form.selectCompany(const BitrixCompany(id: 7, title: 'Otra S.A.'));
        expect(form.companySource, CompanySource.manual);
        expect(form.isDirty, isTrue);
      });
    });
  });
}
