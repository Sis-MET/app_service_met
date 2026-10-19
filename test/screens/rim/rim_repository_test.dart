import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:service_met/core/network/service_met_http_client.dart';
import 'package:service_met/login/models/user_model.dart';
import 'package:service_met/login/services/auth_api_service.dart';
import 'package:service_met/screens/rim/models/rim_documento.dart';
import 'package:service_met/screens/rim/services/rim_api.dart';
import 'package:service_met/screens/rim/services/rim_repository.dart';
import 'package:service_met/screens/rim/services/rim_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'rim_support.dart';

const _apiUrl = 'https://192.168.1.5:3100';

/// Token en memoria: evita el almacenamiento seguro del sistema.
class _FakeAuth extends AuthApiService {
  String? token = 'token-valido';
  int logins = 0;

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
    if (password != 'secreta') {
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

void main() {
  setUpAll(sqfliteFfiInit);

  late Database database;
  late RimStore store;
  late _FakeAuth auth;
  late List<http.Request> requests;

  setUp(() async {
    database = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    store = RimStore(
      database: database,
      installTime: () async => DateTime.utc(2026, 9, 1, 8),
    );
    await darTalonario(store);
    auth = _FakeAuth();
    requests = [];
  });

  tearDown(() => database.close());

  RimRepository repository(
    Future<http.Response> Function(http.Request request) handler,
  ) {
    final client = MockClient((request) async {
      requests.add(request);
      return handler(request);
    });
    return RimRepository(
      apiUrl: () => _apiUrl,
      loggedUser: () async => 'lmamani',
      appVersion: () async => '6.4.0+18',
      store: store,
      apiFactory: (url) => RimApi(url, client: client, auth: auth),
    );
  }

  http.Response json(int status, Object body) => http.Response(
        jsonEncode(body),
        status,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );

  test('emitir guarda en el teléfono sin tocar la red', () async {
    final repo = repository((_) async => json(500, {}));

    final rim = await repo.emitir(
        await rimSiguiente(store), firmaDePrueba, firmaRepresentanteDePrueba);

    expect(rim.estado, RimEstadoSubida.pending);
    expect(requests, isEmpty);
    expect(await repo.countUnsent(), 1);
    expect(
      await repo.existsForService(sessionId: '0007', codMetrica: '0090-11-014'),
      isTrue,
    );
  });

  test('sube el RIM con las firmas y guarda el correlativo del servidor',
      () async {
    final repo =
        repository((_) async => json(201, {'n': 15, 'duplicate': false}));
    final rim = await repo.emitir(
        await rimSiguiente(store), firmaDePrueba, firmaRepresentanteDePrueba);

    final result = await repo.subir(rim);

    expect(result.sent, isTrue);
    expect(result.error, isNull);
    expect(result.registro.serverN, 15);
    expect((await store.byUuid(rim.uuid))!.isSent, isTrue);

    final request = requests.single;
    expect(request.url.path, '/api/extras/rim');
    expect(request.headers['Authorization'], 'Bearer token-valido');
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    expect(body['uuid'], rim.uuid);
    expect(body['code'], 'RIM-26-0041');
    expect(body['installationId'], await store.instalacion());
    expect(body.containsKey('voided'), isFalse);
    expect(base64Decode(body['clientSignature'] as String), firmaDePrueba);
    expect(base64Decode(body['metricaSignature'] as String),
        firmaRepresentanteDePrueba);
    expect(body['issuedAt'],
        DateTime(2026, 10, 1, 14, 45).toUtc().toIso8601String());
    expect(body['functionalityTestPerformed'], isTrue);
    expect(body['inventory'], containsPair('powerCable', 'missing'));
    final service = body['service'] as Map<String, dynamic>;
    expect(service['serviceType'], 'soporte');
    expect(service['plantCode'], '0090-11');
    expect(service['metricCode'], '0090-11-014');

    // Ya subido: no se vuelve a enviar.
    await repo.subir(result.registro);
    expect(requests, hasLength(1));
  });

  test('sin conexión el RIM sigue pendiente y se puede reintentar', () async {
    var online = false;
    final repo = repository((_) async {
      if (!online) throw const SocketException('sin red');
      return json(200, {'n': 15, 'duplicate': true});
    });
    final rim = await repo.emitir(
        await rimSiguiente(store), firmaDePrueba, firmaRepresentanteDePrueba);

    final offline = await repo.subir(rim);
    expect(offline.sent, isFalse);
    expect(offline.error!.kind, RimApiErrorKind.offline);
    expect(offline.registro.estado, RimEstadoSubida.pending);
    expect(offline.registro.lastError, 'Sin conexión con la API de METRICA.');
    expect(await repo.countUnsent(), 1);

    online = true;
    final retry = await repo.subir(offline.registro);
    expect(retry.sent, isTrue);
    expect(retry.registro.serverN, 15);
    expect(retry.registro.retryCount, 2);
  });

  test('si el servidor no tiene la base, queda pendiente con el motivo',
      () async {
    final repo = repository((_) async => json(503, {
          'error': 'EXTRAS_NOT_READY',
          'message': 'El servidor todavía no tiene lista la base.',
        }));
    final rim = await repo.emitir(
        await rimSiguiente(store), firmaDePrueba, firmaRepresentanteDePrueba);

    final result = await repo.subir(rim);

    expect(result.error!.retryable, isTrue);
    expect(result.registro.estado, RimEstadoSubida.pending);
    expect(result.registro.lastError, contains('todavía no tiene lista'));
  });

  test('un RIM rechazado queda con error', () async {
    final repo = repository((_) async => json(400, {
          'error': 'VALIDATION_ERROR',
          'message': 'Los datos del RIM están incompletos o no son válidos.',
        }));
    final rim = await repo.emitir(
        await rimSiguiente(store), firmaDePrueba, firmaRepresentanteDePrueba);

    final result = await repo.subir(rim);

    expect(result.sent, isFalse);
    expect(result.error!.kind, RimApiErrorKind.rejected);
    expect(result.registro.estado, RimEstadoSubida.error);
    // Sigue pudiendo subirse cuando se corrija el servidor.
    expect(result.registro.canUpload, isTrue);
  });

  test('con la sesión vencida pide la contraseña y reintenta', () async {
    auth.token = null;
    final repo = repository((request) async {
      expect(request.headers['Authorization'], 'Bearer token-renovado');
      return json(201, {'n': 3, 'duplicate': false});
    });
    final rim = await repo.emitir(
        await rimSiguiente(store), firmaDePrueba, firmaRepresentanteDePrueba);
    final prompts = <String?>[];

    final result = await repo.subir(rim, onAuthRequired: (error) async {
      prompts.add(error);
      return prompts.length == 1 ? 'incorrecta' : 'secreta';
    });

    expect(result.sent, isTrue);
    expect(auth.logins, 2);
    expect(prompts, [null, 'Usuario o contraseña incorrectos.']);
  });

  test('si el técnico cancela la contraseña, el RIM sigue pendiente', () async {
    auth.token = null;
    final repo = repository((_) async => json(201, {'n': 3}));
    final rim = await repo.emitir(
        await rimSiguiente(store), firmaDePrueba, firmaRepresentanteDePrueba);

    final result = await repo.subir(rim, onAuthRequired: (_) async => null);

    expect(result.sent, isFalse);
    expect(result.error!.kind, RimApiErrorKind.authRequired);
    expect(result.registro.estado, RimEstadoSubida.pending);
    expect(requests, isEmpty);
  });

  test('un RIM anulado se sube con su anulación y queda registrado', () async {
    final repo = repository((_) async => json(201, {'n': 3}));
    final rim = await repo.emitir(
        await rimSiguiente(store), firmaDePrueba, firmaRepresentanteDePrueba);

    expect(await repo.anular(rim, 'Balanza equivocada.'), isTrue);
    final anulado = (await store.byUuid(rim.uuid))!;
    expect(anulado.anuladoPor, 'lmamani');

    final result = await repo.subir(anulado);
    expect(result.sent, isTrue);
    expect(result.registro.anulado, isTrue);
    final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
    expect(body['code'], 'RIM-26-0041');
    expect(body['voided'], {
      'by': 'lmamani',
      'at': anulado.anuladoEn!.toUtc().toIso8601String(),
      'reason': 'Balanza equivocada.',
    });
  });

  group('talonarios', () {
    late Database vacia;
    late RimStore sinTalonario;

    setUp(() async {
      vacia = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(singleInstance: false),
      );
      sinTalonario = RimStore(
        database: vacia,
        installTime: () async => DateTime.utc(2026, 9, 1, 8),
      );
    });

    tearDown(() => vacia.close());

    RimRepository conStore(
      RimStore rimStore,
      Future<http.Response> Function(http.Request request) handler,
    ) {
      final client = MockClient((request) async {
        requests.add(request);
        return handler(request);
      });
      return RimRepository(
        apiUrl: () => _apiUrl,
        loggedUser: () async => 'lmamani',
        appVersion: () async => '6.4.0+18',
        store: rimStore,
        apiFactory: (url) => RimApi(url, client: client, auth: auth),
      );
    }

    test('sin números pide un talonario y emite con el primero', () async {
      final repo = conStore(sinTalonario, (request) async {
        expect(request.url.path, '/api/extras/rim/talonarios');
        return json(201, {'id': 9, 'year': 2026, 'from': 51, 'to': 60});
      });
      expect(await repo.proximoNumero(DateTime(2026, 10, 19)), isNull);

      final resultado =
          await repo.asegurarTalonarios(ahora: DateTime(2026, 10, 19));

      expect(resultado.recibidos, 1);
      expect(resultado.restantes, 10);
      expect(resultado.error, isNull);
      final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
      expect(body['installationId'], await sinTalonario.instalacion());
      expect(body['year'], 2026);
      expect(body['appVersion'], '6.4.0+18');
      expect(body['requestId'], isNotEmpty);
      final numero = (await repo.proximoNumero(DateTime(2026, 10, 19)))!;
      expect(numero.codigo, 'RIM-26-0051');
      expect(numero.talonarioId, 9);
    });

    test('con números suficientes no pide nada', () async {
      final repo = repository((_) async => json(500, {}));
      final resultado =
          await repo.asegurarTalonarios(ahora: DateTime(2026, 10, 19));
      expect(resultado.recibidos, 0);
      expect(resultado.restantes, 10);
      expect(requests, isEmpty);
    });

    test('en diciembre pide también el talonario de la gestión siguiente',
        () async {
      final repo = repository((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        return json(201, {
          'id': 20,
          'year': body['year'],
          'from': 1,
          'to': 10,
        });
      });
      final resultado =
          await repo.asegurarTalonarios(ahora: DateTime(2026, 12, 5));
      expect(resultado.recibidos, 1);
      final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
      expect(body['year'], 2027);
      expect((await repo.proximoNumero(DateTime(2027, 1, 2)))!.codigo,
          'RIM-27-0001');
    });

    test('si la respuesta se pierde, repite la misma solicitud', () async {
      var online = false;
      final repo = conStore(sinTalonario, (_) async {
        if (!online) throw const SocketException('sin red');
        return json(200, {'id': 9, 'year': 2026, 'from': 51, 'to': 60});
      });

      final sinRed =
          await repo.asegurarTalonarios(ahora: DateTime(2026, 10, 19));
      expect(sinRed.recibidos, 0);
      expect(sinRed.error!.kind, RimApiErrorKind.offline);
      expect(sinRed.restantes, 0);

      online = true;
      final conRed =
          await repo.asegurarTalonarios(ahora: DateTime(2026, 10, 19));
      expect(conRed.recibidos, 1);
      final pedidos = [
        for (final request in requests)
          (jsonDecode(request.body) as Map<String, dynamic>)['requestId'],
      ];
      expect(pedidos, hasLength(2));
      expect(pedidos.toSet(), hasLength(1));
    });

    test('con la sesión vencida solo pide la contraseña si se lo indican',
        () async {
      auth.token = null;
      final repo = conStore(sinTalonario,
          (_) async => json(201, {'id': 9, 'year': 2026, 'from': 51, 'to': 60}));

      final silencioso =
          await repo.asegurarTalonarios(ahora: DateTime(2026, 10, 19));
      expect(silencioso.error!.kind, RimApiErrorKind.authRequired);
      expect(requests, isEmpty);

      final conPrompt = await repo.asegurarTalonarios(
        ahora: DateTime(2026, 10, 19),
        onAuthRequired: (_) async => 'secreta',
      );
      expect(conPrompt.recibidos, 1);
      expect(requests.single.headers['Authorization'], 'Bearer token-renovado');
    });

    test('informa una vez el cierre de los talonarios de gestiones pasadas',
        () async {
      await darTalonario(store, id: 5, gestion: 2025, desde: 1, hasta: 10);
      for (var i = 1; i <= 3; i++) {
        await store.insert(
          await rimSiguiente(store,
              uuid: '66666666-6666-4666-8666-66666666666$i', gestion: 2025),
          firmaDePrueba,
          firmaRepresentanteDePrueba,
        );
      }
      final repo = repository((request) async {
        expect(request.url.path, '/api/extras/rim/talonarios/5/cierre');
        return json(201, {'id': 1, 'duplicate': false});
      });

      await repo.asegurarTalonarios(ahora: DateTime(2026, 1, 10));
      await repo.asegurarTalonarios(ahora: DateTime(2026, 1, 11));

      final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
      expect(body, {
        'installationId': await store.instalacion(),
        'lastUsed': 3,
        'reason': 'fin_gestion',
      });
    });
  });
}
