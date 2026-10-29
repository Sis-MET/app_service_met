import 'package:flutter_test/flutter_test.dart';
import 'package:service_met/screens/calibracion_temperatura/data/temperatura_store.dart';
import 'package:service_met/screens/calibracion_temperatura/models/temperatura_models.dart';
import 'package:service_met/screens/calibracion_temperatura/services/temperatura_api.dart';
import 'package:service_met/screens/calibracion_temperatura/services/temperatura_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _FakeUploader implements TemperaturaUploader {
  _FakeUploader(this.respuesta);

  Future<({int n, bool duplicate})> Function(Map<String, Object?>) respuesta;
  final List<Map<String, Object?>> enviados = [];
  int autenticaciones = 0;

  @override
  Future<({int n, bool duplicate})> subir(Map<String, Object?> registro) {
    enviados.add(registro);
    return respuesta(registro);
  }

  @override
  Future<void> authenticate(
      {required String usuario, required String password}) async {
    autenticaciones++;
    respuesta = (_) async => (n: 77, duplicate: false);
  }

  @override
  void close() {}
}

void main() {
  late Database db;
  late TemperaturaStore store;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    store = TemperaturaStore(open: () async => db);
  });

  tearDown(() => db.close());

  Future<String> finalizado({String cod = '0032-11-090'}) async {
    var s = await store.crear(personal: 'jperez');
    s = await store.guardar(s.copyWith(
      seca: '0032-11-C01-26',
      secaConfirmada: true,
      equipo: TempEquipo(
          codMetrica: cod,
          tipo: 'Mufla',
          rangoMin: 100,
          rangoMax: 1100,
          resolucion: 1),
      equipoConfirmado: true,
    ));
    await store
        .guardarPatrones(s.uuid, const [TempPatron(codInstrumento: 'TM-001')]);
    await store.guardarCanales(s.uuid, const [
      TempCanal(n: 1, nombre: 'Patrón', rol: RolCanal.patron),
    ]);
    await store.guardarPuntos(s.uuid, const [
      TempPunto(n: 1, temperaturaNominal: 300, duracionMin: 1, intervaloS: 30),
    ]);
    await store.iniciarPunto(s.uuid, 1, DateTime(2026, 10, 29, 9));
    await store.registrarLectura(
      s.uuid,
      const TempLectura(
        nPunto: 1,
        nLectura: 0,
        nCanal: 1,
        tiempoProgramadoS: 0,
        capturadaEn: '2026-10-29T09:00:00.000-04:00',
        valor: 300,
        valorOriginal: 300,
        origen: OrigenLectura.ocrSegmentos,
      ),
    );
    await store.terminarPunto(s.uuid, 1,
        estado: EstadoPunto.completo, fin: DateTime(2026, 10, 29, 9, 1));
    await store.finalizar(s.uuid);
    return s.uuid;
  }

  TemperaturaRepository repo(_FakeUploader api) => TemperaturaRepository(
        apiUrl: () => 'https://api.prueba',
        loggedUser: () async => 'jperez',
        store: store,
        apiFactory: (_) => api,
      );

  test('sube una vez y marca el registro', () async {
    final uuid = await finalizado();
    final api = _FakeUploader((_) async => (n: 42, duplicate: false));
    final subida = await repo(api).subir(uuid);
    expect(subida.ok, isTrue);
    expect(subida.servicio.subido, isTrue);
    expect(subida.servicio.serverN, 42);
    expect(api.enviados.single['uuid'], uuid);
    // Ya subido: no vuelve a enviarse.
    final otra = await repo(api).subir(uuid);
    expect(otra.ok, isFalse);
    expect(api.enviados.length, 1);
  });

  test('sin red queda pendiente con el motivo', () async {
    final uuid = await finalizado();
    final api = _FakeUploader((_) async => throw const TemperaturaApiException(
        'Sin conexión con la API de METRICA.',
        kind: TemperaturaApiErrorKind.offline));
    final subida = await repo(api).subir(uuid);
    expect(subida.ok, isFalse);
    expect(subida.servicio.subida, EstadoSubidaTemp.pendiente);
    expect(subida.servicio.subidaError, contains('Sin conexión'));
  });

  test('un rechazo del servidor queda como rechazado', () async {
    final uuid = await finalizado();
    final api = _FakeUploader((_) async => throw TemperaturaApi.exception(422, {
          'error': 'VALIDATION_ERROR',
          'message': 'No es válido',
          'details': [
            {'field': 'puntos', 'message': 'Ningún punto se midió.'}
          ]
        }));
    final subida = await repo(api).subir(uuid);
    expect(subida.servicio.subida, EstadoSubidaTemp.error);
    expect(subida.error?.details, ['Ningún punto se midió.']);
  });

  test('con la sesión vencida pide la contraseña y reintenta', () async {
    final uuid = await finalizado();
    final api = _FakeUploader((_) async => throw TemperaturaApi.exception(
        401, {'error': 'TOKEN_EXPIRED', 'message': 'Sesión vencida'}));
    final subida =
        await repo(api).subir(uuid, onAuthRequired: (_) async => 'clave');
    expect(api.autenticaciones, 1);
    expect(subida.servicio.serverN, 77);
  });

  test('no se sube en curso ni con código provisional', () async {
    final enCurso = await store.crear(personal: 'jperez');
    final api = _FakeUploader((_) async => (n: 1, duplicate: false));
    expect(
        (await repo(api).subir(enCurso.uuid)).error?.code, 'NOT_READY_LOCAL');
    final provisional = await finalizado(cod: '0032-11-291026093000');
    final subida = await repo(api).subir(provisional);
    expect(subida.error?.message, contains('código métrica definitivo'));
    expect(api.enviados, isEmpty);
  });

  test('errores de la API por código', () {
    expect(TemperaturaApi.exception(404, const {}).kind,
        TemperaturaApiErrorKind.unavailable);
    expect(TemperaturaApi.exception(409, {'error': 'ALREADY_EXISTS'}).kind,
        TemperaturaApiErrorKind.rejected);
    expect(
        TemperaturaApi.exception(503, {'error': 'TEMPERATURA_NOT_READY'})
            .retryable,
        isTrue);
  });
}
