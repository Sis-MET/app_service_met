import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:service_met/screens/rim/data/rim_catalogo.dart';
import 'package:service_met/screens/rim/models/rim_documento.dart';
import 'package:service_met/screens/rim/services/rim_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'rim_support.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  late Database database;
  late RimStore store;

  setUp(() async {
    database = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    store = RimStore(database: database);
  });

  tearDown(() => database.close());

  test('el código sigue el formato del formulario web', () {
    expect(
      rimCodigo(plantCode: '0103-11', clientCode: '0103', year: 2026),
      'RIM-0103-11-26',
    );
    expect(rimCodigo(clientCode: '0103', year: 2026), 'RIM-0103-XX-26');
    expect(rimCodigo(year: 2031), 'RIM-XXXX-XX-31');
  });

  test('guarda el RIM con las dos firmas y lo recupera idéntico', () async {
    final guardado = await store.insert(
        rimDePrueba(), firmaDePrueba, firmaRepresentanteDePrueba);

    expect(guardado.estado, RimEstadoSubida.pending);
    expect(guardado.canUpload, isTrue);
    expect(guardado.firmaCliente, firmaDePrueba);
    expect(guardado.firmaRepresentante, firmaRepresentanteDePrueba);

    final rim = (await store.byUuid(guardado.uuid))!.documento;
    expect(rim.codigo, 'RIM-0090-11-26');
    expect(rim.motivo, startsWith('El indicador no enciende'));
    expect(rim.inventario['powerCable'], RimEstadoComponente.missing);
    expect(rim.inventario.containsKey('bracket'), isFalse);
    expect(rim.cantidades, {'loadCells': '4'});
    expect(rim.otrosComponentes.single.nombre, 'Cable RS232');
    expect(rim.danos, {
      'scratches': ['platform', 'display'],
      'corrosion': <String>[],
    });
    expect(rim.estadoGeneral, 'fair');
    expect(rim.nivelSuciedad, 'moderate');
    expect(rim.pruebasFuncionamiento, isTrue);
    expect(rim.contactoNombre, 'Juan Pérez Ñáñez');
    expect(rim.emitidoEn, DateTime(2026, 10, 1, 14, 45));
    expect(rim.creadoPor, 'lmamani');
    expect(rim.appVersion, '6.3.3+15');
    // La foto del servicio viaja completa, con los códigos de DataMET.
    expect(rim.service.plantCode, '0090-11');
    expect(rim.service.clientCode, '0090');
    expect(rim.service.plantAddress, 'Carretera a Viacha km 14');
    expect(rim.service.metricCode, '0090-11-014');
    expect(rim.service.capacityWithUnit, '150 kg');
  });

  test('un RIM emitido no se reemplaza', () async {
    await store.insert(
        rimDePrueba(), firmaDePrueba, firmaRepresentanteDePrueba);
    final otro = RimDocumento.fromJson({
      ...rimDePrueba().toJson(),
      'reason': 'Texto cambiado después de firmar.',
    });

    await expectLater(
      store.insert(otro, firmaDePrueba, firmaRepresentanteDePrueba),
      throwsA(isA<DatabaseException>()),
    );
    final vigente = await store.byUuid(otro.uuid);
    expect(vigente!.documento.motivo, startsWith('El indicador no enciende'));
  });

  test('sabe si un servicio ya tiene RIM de su instrumento', () async {
    await store.insert(
        rimDePrueba(), firmaDePrueba, firmaRepresentanteDePrueba);

    expect(
      await store.existsForService(
          sessionId: '0007', codMetrica: '0090-11-014'),
      isTrue,
    );
    expect(
      await store.existsForService(
          sessionId: '0007', codMetrica: '0090-11-099'),
      isFalse,
    );
    expect(
      await store.existsForService(
          sessionId: '0008', codMetrica: '0090-11-014'),
      isFalse,
    );
    expect(
      await store.existsForService(sessionId: null, codMetrica: null),
      isFalse,
    );
  });

  test('subido: guarda el correlativo del servidor y ya no se anula', () async {
    final rim = await store.insert(
        rimDePrueba(), firmaDePrueba, firmaRepresentanteDePrueba);
    await store.markSending(rim.uuid);
    final subido = await store.markSent(rim.uuid, 42);

    expect(subido.isSent, isTrue);
    expect(subido.serverN, 42);
    expect(subido.retryCount, 1);
    expect(subido.sentAt, isNotNull);
    expect(subido.canUpload, isFalse);
    expect(subido.canAnular, isFalse);
    expect(await store.countUnsent(), 0);

    expect(
      await store.anular(rim.uuid, usuario: 'lmamani', motivo: 'Error'),
      isFalse,
    );
    expect((await store.byUuid(rim.uuid))!.anulado, isFalse);
    // Un fallo tardío no vuelve atrás lo ya subido.
    final igual = await store.markFailed(
      rim.uuid,
      estado: RimEstadoSubida.error,
      error: 'tarde',
    );
    expect(igual.isSent, isTrue);
  });

  test('anular deja el RIM en el teléfono, con quién, cuándo y por qué',
      () async {
    final rim = await store.insert(
        rimDePrueba(), firmaDePrueba, firmaRepresentanteDePrueba);

    expect(
      await store.anular(
        rim.uuid,
        usuario: 'lmamani',
        motivo: 'Se eligió la balanza equivocada.',
      ),
      isTrue,
    );

    final anulado = (await store.byUuid(rim.uuid))!;
    expect(anulado.anulado, isTrue);
    expect(anulado.anuladoPor, 'lmamani');
    expect(anulado.anuladoEn, isNotNull);
    expect(anulado.motivoAnulacion, 'Se eligió la balanza equivocada.');
    expect(anulado.canUpload, isFalse);
    // Sigue existiendo, con su contenido y sus firmas.
    expect(anulado.documento.contactoNombre, 'Juan Pérez Ñáñez');
    expect(anulado.firmaCliente, firmaDePrueba);
    expect(anulado.firmaRepresentante, firmaRepresentanteDePrueba);
    expect(await store.countUnsent(), 0);
    // Un RIM anulado ya no cuenta para el servicio: se puede emitir otro.
    expect(
      await store.existsForService(
          sessionId: '0007', codMetrica: '0090-11-014'),
      isFalse,
    );
    // No se puede anular dos veces ni empezar a subirlo.
    expect(
      await store.anular(rim.uuid, usuario: 'otro', motivo: 'Otra vez'),
      isFalse,
    );
    await store.markSending(rim.uuid);
    expect((await store.byUuid(rim.uuid))!.estado, RimEstadoSubida.pending);
  });

  test('lista primero lo pendiente y después el historial', () async {
    const uuids = [
      '11111111-1111-4111-8111-111111111111',
      '22222222-2222-4222-8222-222222222222',
      '33333333-3333-4333-8333-333333333333',
    ];
    for (var i = 0; i < uuids.length; i++) {
      await store.insert(
        rimDePrueba(uuid: uuids[i], emitidoEn: DateTime(2026, 10, 1, 9 + i)),
        firmaDePrueba,
        firmaRepresentanteDePrueba,
      );
    }
    await store.markSent(uuids[0], 1);
    await store.anular(uuids[1], usuario: 'lmamani', motivo: 'Duplicado');

    final lista = await store.list();
    expect(lista.map((rim) => rim.uuid), [uuids[2], uuids[1], uuids[0]]);
    expect(await store.countUnsent(), 1);
  });

  test('una tabla anterior a la firma de Métrica se completa sin perder RIM',
      () async {
    // Tabla como la creaba la versión anterior: sin firma_representante.
    final anterior =
        await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    addTearDown(anterior.close);
    await anterior.execute('''
      CREATE TABLE ${RimStore.table} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL UNIQUE,
        codigo_rim TEXT NOT NULL,
        service_type TEXT NOT NULL,
        service_name TEXT,
        service_session_id TEXT,
        seca TEXT,
        cod_metrica TEXT,
        cliente TEXT,
        planta TEXT,
        contacto_nombre TEXT,
        payload TEXT NOT NULL,
        firma_cliente BLOB NOT NULL,
        created_by TEXT,
        emitido_en TEXT NOT NULL,
        app_version TEXT,
        status TEXT NOT NULL,
        retry_count INTEGER NOT NULL DEFAULT 0,
        last_error TEXT,
        server_n INTEGER,
        sent_at TEXT,
        anulado INTEGER NOT NULL DEFAULT 0,
        anulado_por TEXT,
        anulado_en TEXT,
        motivo_anulacion TEXT
      )
    ''');
    final viejo = rimDePrueba();
    await anterior.insert(RimStore.table, {
      'uuid': viejo.uuid,
      'codigo_rim': viejo.codigo,
      'service_type': viejo.service.serviceType.name,
      'payload': jsonEncode(viejo.toJson()),
      'firma_cliente': firmaDePrueba,
      'emitido_en': viejo.emitidoEn.toUtc().toIso8601String(),
      'status': RimEstadoSubida.pending.name,
    });

    final migrado = RimStore(database: anterior);
    final conservado = (await migrado.byUuid(viejo.uuid))!;
    expect(conservado.firmaCliente, firmaDePrueba);
    expect(conservado.firmaRepresentante, isNull);
    expect(conservado.toUploadJson().containsKey('metricaSignature'), isFalse);

    final nuevo = await migrado.insert(
      rimDePrueba(uuid: '44444444-4444-4444-8444-444444444444'),
      firmaDePrueba,
      firmaRepresentanteDePrueba,
    );
    expect(nuevo.firmaRepresentante, firmaRepresentanteDePrueba);
  });
}
