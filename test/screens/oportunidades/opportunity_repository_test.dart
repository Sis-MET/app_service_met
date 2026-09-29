import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:service_met/core/network/service_met_http_client.dart';
import 'package:service_met/login/models/user_model.dart';
import 'package:service_met/login/services/auth_api_service.dart';
import 'package:service_met/screens/oportunidades/models/opportunity_draft.dart';
import 'package:service_met/screens/oportunidades/models/opportunity_service_context.dart';
import 'package:service_met/screens/oportunidades/services/bitrix_opportunity_api.dart';
import 'package:service_met/screens/oportunidades/services/opportunity_repository.dart';
import 'package:service_met/screens/oportunidades/services/pending_opportunity_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _apiUrl = 'https://192.168.1.5:3100';

/// Token en memoria: evita el almacenamiento seguro del sistema.
class _FakeAuth extends AuthApiService {
  String? token = 'token-valido';
  int logins = 0;
  String validPassword = 'secreta';

  _FakeAuth()
      : super(_apiUrl, client: MockClient((_) async => http.Response('', 500)));

  @override
  Future<String?> readValidToken() async => token;

  @override
  Future<AuthApiResult> login({
    required String usuario,
    required String password,
  }) async {
    logins++;
    if (password != validPassword) {
      throw const ServiceMetNetworkException(
        'Usuario o contraseña incorrectos.',
        code: 'INVALID_CREDENTIALS',
        statusCode: 401,
      );
    }
    token = 'token-renovado';
    return AuthApiResult(
      user: UserModel.fromMap({'usuario': usuario}),
      token: token!,
      expiresAt: DateTime.now().add(const Duration(hours: 8)),
    );
  }
}

OpportunityDraft _draft({int? companyId = 120, String? uuid}) =>
    OpportunityDraft(
      uuid: uuid ?? newOpportunityUuid(),
      service: OpportunityServiceContext(
        serviceType: OpportunityServiceType.calibracion,
        serviceName: 'Calibración',
        capturedAt: DateTime(2026, 9, 29, 10),
        seca: '1523-C01-26',
        metricCode: '0072-11-015',
      ),
      companyId: companyId,
      companyName: companyId == null ? null : 'EMBOL S.A.',
      typeKey: 'reemplazo_indicador',
      typeLabel: 'Reemplazo de indicador',
      title: 'Oportunidad ServiceMET - Reemplazo de indicador - EMBOL S.A.',
      description:
          'Indicador presenta fallas y el cliente solicita cotización.',
      createdAt: DateTime(2026, 9, 29, 10),
    );

void main() {
  setUpAll(sqfliteFfiInit);

  late Database database;
  late PendingOpportunityStore store;
  late _FakeAuth auth;
  late List<http.Request> requests;

  setUp(() async {
    database = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    store = PendingOpportunityStore(database: database);
    auth = _FakeAuth();
    requests = [];
  });

  tearDown(() => database.close());

  OpportunityRepository repository(
    Future<http.Response> Function(http.Request request) handler,
  ) {
    final client = MockClient((request) async {
      requests.add(request);
      return handler(request);
    });
    return OpportunityRepository(
      apiUrl: () => _apiUrl,
      loggedUser: () async => 'aquispe',
      store: store,
      apiFactory: (url) =>
          BitrixOpportunityApi(url, client: client, auth: auth),
    );
  }

  http.Response json(int status, Object body) => http.Response(
        jsonEncode(body),
        status,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );

  test('registra en Bitrix24 y guarda el número de prospecto', () async {
    final repo = repository(
        (_) async => json(201, {'leadId': 9876, 'duplicate': false}));
    final draft = _draft();

    final result = await repo.submit(draft);

    expect(result.outcome, OpportunitySubmitOutcome.sent);
    expect(result.leadId, 9876);
    final stored = await store.byUuid(draft.uuid);
    expect(stored!.status, OpportunityStatus.sent);
    expect(stored.bitrixLeadId, 9876);
    expect(stored.retryCount, 1);

    final request = requests.single;
    expect(request.url.path, '/api/bitrix/opportunities');
    expect(request.headers['Authorization'], 'Bearer token-valido');
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    expect(body['uuid'], draft.uuid);
    expect(body['companyId'], 120);
    expect((body['service'] as Map)['seca'], '1523-C01-26');
  });

  test('sin conexión queda pendiente con el motivo, sin perder nada', () async {
    final repo =
        repository((_) async => throw const SocketException('sin red'));
    final draft = _draft();

    final result = await repo.submit(draft);

    expect(result.outcome, OpportunitySubmitOutcome.savedPending);
    expect(result.error!.kind, BitrixApiErrorKind.offline);
    final stored = await store.byUuid(draft.uuid);
    expect(stored!.status, OpportunityStatus.pending);
    expect(stored.lastError, contains('Sin conexión'));
    expect(stored.draft.description, draft.description);
    expect(await store.countUnsent(), 1);
  });

  test('Bitrix24 caído (502) también queda pendiente', () async {
    final repo = repository((_) async => json(502, {
          'error': 'BITRIX_UNAVAILABLE',
          'message': 'Bitrix24 no está disponible en este momento.',
        }));
    final result = await repo.submit(_draft());
    expect(result.outcome, OpportunitySubmitOutcome.savedPending);
    expect(result.error!.message, contains('Bitrix24 no está disponible'));
  });

  test('datos rechazados quedan con error y con el detalle por campo',
      () async {
    final repo = repository((_) async => json(400, {
          'error': 'VALIDATION_ERROR',
          'message': 'Datos inválidos.',
          'details': [
            {
              'field': 'contactId',
              'message': 'El contacto no pertenece a la empresa.'
            },
          ],
        }));
    final draft = _draft();
    final result = await repo.submit(draft);
    expect(result.outcome, OpportunitySubmitOutcome.failed);
    expect(result.error!.details.single.field, 'contactId');
    expect((await store.byUuid(draft.uuid))!.status, OpportunityStatus.error);
  });

  test('el reenvío usa el mismo UUID y no duplica lo ya enviado', () async {
    var online = false;
    final repo = repository((_) async {
      if (!online) throw http.ClientException('sin red');
      return json(201, {'leadId': 55});
    });
    final draft = _draft();
    await repo.submit(draft);
    final pending = (await store.byUuid(draft.uuid))!;

    online = true;
    final resent = await repo.resend(pending);
    expect(resent.outcome, OpportunitySubmitOutcome.sent);
    expect(jsonDecode(requests.last.body)['uuid'], draft.uuid);
    expect((await store.byUuid(draft.uuid))!.retryCount, 2);

    final again = await repo.resend(pending);
    expect(again.outcome, OpportunitySubmitOutcome.sent);
    expect(again.duplicate, isTrue);
    expect(requests, hasLength(2), reason: 'lo enviado no vuelve a salir');
  });

  test('un doble toque no envía la misma oportunidad dos veces', () async {
    final gate = Completer<void>();
    final repo = repository((_) async {
      await gate.future;
      return json(201, {'leadId': 77});
    });
    final draft = _draft();
    final first = repo.submit(draft);
    final second = await repo.submit(draft);
    expect(second.outcome, OpportunitySubmitOutcome.failed);
    expect(second.error!.code, 'IN_FLIGHT');
    gate.complete();
    expect((await first).leadId, 77);
    expect(requests, hasLength(1));
  });

  test('con la sesión vencida pide la contraseña y reintenta una vez',
      () async {
    auth.token = null;
    final repo = repository((request) async => json(201, {'leadId': 31}));
    final prompts = <String?>[];

    final result = await repo.submit(_draft(), onAuthRequired: (error) async {
      prompts.add(error);
      return 'secreta';
    });

    expect(result.outcome, OpportunitySubmitOutcome.sent);
    expect(auth.logins, 1);
    expect(prompts, [null]);
    expect(requests.single.headers['Authorization'], 'Bearer token-renovado');
  });

  test('una contraseña incorrecta se vuelve a pedir con el motivo', () async {
    auth.token = null;
    final repo = repository((_) async => json(201, {'leadId': 32}));
    final answers = ['mala', 'secreta'];
    final prompts = <String?>[];

    final result = await repo.submit(_draft(), onAuthRequired: (error) async {
      prompts.add(error);
      return answers.removeAt(0);
    });

    expect(result.outcome, OpportunitySubmitOutcome.sent);
    expect(auth.logins, 2);
    expect(prompts, [null, 'Usuario o contraseña incorrectos.']);
  });

  test('si el técnico cancela la contraseña queda pendiente', () async {
    auth.token = null;
    final repo = repository((_) async => json(201, {'leadId': 31}));
    final draft = _draft();
    final result = await repo.submit(draft, onAuthRequired: (_) async => null);
    expect(result.outcome, OpportunitySubmitOutcome.savedPending);
    expect(requests, isEmpty);
    expect((await store.byUuid(draft.uuid))!.status, OpportunityStatus.pending);
  });

  test(
      'guardar pendiente no llama a la API y permite elegir la empresa después',
      () async {
    final repo = repository((_) async => json(201, {'leadId': 1}));
    final record = await repo.savePending(_draft(companyId: null));
    expect(record.status, OpportunityStatus.pending);
    expect(record.canSendDirectly, isFalse);
    expect(requests, isEmpty);
  });

  test('descartar borra solo lo que no se envió', () async {
    final repo = repository((_) async => json(201, {'leadId': 5}));
    final sent = _draft();
    await repo.submit(sent);
    final pending = await repo.savePending(_draft());

    expect(await repo.discard(sent.uuid), isFalse);
    expect(await repo.discard(pending.uuid), isTrue);
    final all = await repo.list();
    expect(all.map((item) => item.uuid), [sent.uuid]);
  });

  test('una oportunidad enviada no vuelve a pendiente al guardarla', () async {
    final repo = repository((_) async => json(201, {'leadId': 8}));
    final draft = _draft();
    await repo.submit(draft);
    await store.save(draft, status: OpportunityStatus.pending);
    await store.markFailed(draft.uuid,
        status: OpportunityStatus.error, error: 'x');
    final stored = (await store.byUuid(draft.uuid))!;
    expect(stored.status, OpportunityStatus.sent);
    expect(stored.bitrixLeadId, 8);
  });
}
