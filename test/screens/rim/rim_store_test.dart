import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:service_met/screens/rim/data/rim_catalogo.dart';
import 'package:service_met/screens/rim/models/rim_documento.dart';
import 'package:service_met/screens/rim/models/rim_numeracion.dart';
import 'package:service_met/screens/rim/services/rim_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'rim_support.dart';

/// Base en memoria independiente de la de cada prueba.
Future<Database> _otraBase() => databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );

/// Momento de la instalación de la app en el teléfono de prueba.
final _instalada = DateTime.utc(2026, 9, 1, 8);

void main() {
  setUpAll(sqfliteFfiInit);

  late Database database;
  late RimStore store;

  setUp(() async {
    database = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    store = RimStore(database: database, installTime: () async => _instalada);
    await darTalonario(store);
  });

  tearDown(() => database.close());

  test('el código es RIM-AA-NNNN y se lee de vuelta', () {
    expect(rimCodigo(gestion: 2026, numero: 42), 'RIM-26-0042');
    expect(rimCodigo(gestion: 2031, numero: 7), 'RIM-31-0007');
    expect(rimCodigo(gestion: 2026, numero: 12345), 'RIM-26-12345');
    expect(leerCodigoRim('RIM-26-0042'), (gestion: 2026, numero: 42));
    // El código anterior no tiene número.
    expect(leerCodigoRim('RIM-0103-11-26'), isNull);
    expect(leerCodigoRim('RIM-26-0000'), isNull);
    expect(leerCodigoRim(null), isNull);
  });

  test('guarda el RIM con las dos firmas y lo recupera idéntico', () async {
    final guardado = await store.insert(
        await rimSiguiente(store), firmaDePrueba, firmaRepresentanteDePrueba);

    expect(guardado.estado, RimEstadoSubida.pending);
    expect(guardado.canUpload, isTrue);
    expect(guardado.firmaCliente, firmaDePrueba);
    expect(guardado.firmaRepresentante, firmaRepresentanteDePrueba);

    final rim = (await store.byUuid(guardado.uuid))!.documento;
    expect(rim.codigo, 'RIM-26-0041');
    expect(rim.instalacion, await store.instalacion());
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

    final fila = (await database.query(RimStore.table)).single;
    expect(fila['gestion'], 2026);
    expect(fila['numero'], 41);
    expect(fila['talonario_id'], 1);
  });

  test('numera en orden con los talonarios y nunca repite un número',
      () async {
    final primero = await store.insert(
      await rimSiguiente(store, uuid: '11111111-1111-4111-8111-111111111111'),
      firmaDePrueba,
      firmaRepresentanteDePrueba,
    );
    final segundo = await store.insert(
      await rimSiguiente(store, uuid: '22222222-2222-4222-8222-222222222222'),
      firmaDePrueba,
      firmaRepresentanteDePrueba,
    );
    expect(primero.documento.codigo, 'RIM-26-0041');
    expect(segundo.documento.codigo, 'RIM-26-0042');

    final siguiente = (await store.proximoNumero(gestion: 2026))!;
    expect(siguiente.codigo, 'RIM-26-0043');
    expect(siguiente.restantes, 8);

    // Otro talonario: sus números se usan cuando se agota el primero.
    await darTalonario(store, id: 2, desde: 91, hasta: 95);
    expect((await store.proximoNumero(gestion: 2026))!.restantes, 13);
    for (var i = 3; i <= 10; i++) {
      await store.insert(
        await rimSiguiente(store,
            uuid: '33333333-3333-4333-8333-3333333333${i.toString().padLeft(2, '0')}'),
        firmaDePrueba,
        firmaRepresentanteDePrueba,
      );
    }
    final despues = (await store.proximoNumero(gestion: 2026))!;
    expect(despues.codigo, 'RIM-26-0091');
    expect(despues.talonarioId, 2);
    expect(despues.restantes, 5);
    // Otra gestión no tiene números hasta recibir su talonario.
    expect(await store.proximoNumero(gestion: 2027), isNull);
  });

  test('sin talonario o con un número que ya no es el siguiente no se emite',
      () async {
    final otro = RimStore(
      database: await _otraBase(),
      installTime: () async => _instalada,
    );
    expect(await otro.proximoNumero(gestion: 2026), isNull);
    await expectLater(
      otro.insert(
        rimDePrueba(instalacion: await otro.instalacion()),
        firmaDePrueba,
        firmaRepresentanteDePrueba,
      ),
      throwsA(isA<RimNumeroNoDisponible>()),
    );

    final adelantado = rimDePrueba(
      codigo: 'RIM-26-0043',
      instalacion: await store.instalacion(),
    );
    await expectLater(
      store.insert(adelantado, firmaDePrueba, firmaRepresentanteDePrueba),
      throwsA(isA<RimNumeroNoDisponible>()),
    );
    // Un código anterior a la numeración ya no se emite.
    await expectLater(
      store.insert(
        rimDePrueba(codigo: 'RIM-0090-11-26', instalacion: null),
        firmaDePrueba,
        firmaRepresentanteDePrueba,
      ),
      throwsA(isA<RimNumeroNoDisponible>()),
    );
    expect(await database.query(RimStore.table), isEmpty);
  });

  test('una base copiada a otra instalación no usa los talonarios copiados',
      () async {
    final emitido = await store.insert(
        await rimSiguiente(store), firmaDePrueba, firmaRepresentanteDePrueba);

    // La misma base, abierta por la app instalada en otro momento (otro
    // teléfono o una reinstalación).
    final copia = RimStore(
      database: database,
      installTime: () async => DateTime.utc(2026, 10, 15, 9),
    );
    expect(await copia.instalacion(), isNot(await store.instalacion()));
    expect(await copia.proximoNumero(gestion: 2026), isNull);
    expect(await copia.talonarios(), isEmpty);
    // Lo ya emitido se conserva y se puede subir desde la copia.
    final conservado = (await copia.byUuid(emitido.uuid))!;
    expect(conservado.documento.codigo, 'RIM-26-0041');
    expect(conservado.documento.instalacion, await store.instalacion());
    // Un número del talonario copiado no se puede usar en la copia.
    await expectLater(
      copia.insert(
        rimDePrueba(
          uuid: '55555555-5555-4555-8555-555555555555',
          codigo: 'RIM-26-0042',
          instalacion: await store.instalacion(),
        ),
        firmaDePrueba,
        firmaRepresentanteDePrueba,
      ),
      throwsA(isA<RimNumeroNoDisponible>()),
    );
    // La instalación original sigue igual.
    expect((await store.proximoNumero(gestion: 2026))!.codigo, 'RIM-26-0042');
  });

  test('el pedido de talonario conserva su identificador hasta recibirlo',
      () async {
    final pedido = await store.solicitudTalonario(2027);
    expect(await store.solicitudTalonario(2027), pedido);
    expect(await store.solicitudTalonario(2026), isNot(pedido));

    await store.guardarTalonario(
      RimTalonario(
        id: 9,
        instalacion: await store.instalacion(),
        gestion: 2027,
        desde: 1,
        hasta: 10,
        recibidoEn: DateTime(2026, 12, 5),
      ),
      solicitud: pedido,
    );
    // Recibido: el próximo pedido de 2027 es otro.
    expect(await store.solicitudTalonario(2027), isNot(pedido));
    expect((await store.proximoNumero(gestion: 2027))!.codigo, 'RIM-27-0001');
  });

  test('los talonarios de gestiones pasadas quedan por cerrar', () async {
    await darTalonario(store, id: 5, gestion: 2025, desde: 1, hasta: 10);
    for (var i = 1; i <= 3; i++) {
      await store.insert(
        await rimSiguiente(store,
            uuid: '66666666-6666-4666-8666-66666666666$i', gestion: 2025),
        firmaDePrueba,
        firmaRepresentanteDePrueba,
      );
    }
    final pendientes = await store.talonariosPorCerrar(2026);
    expect(pendientes.single.talonario.id, 5);
    expect(pendientes.single.ultimoUsado, 3);

    await store.marcarCierreReportado(5);
    expect(await store.talonariosPorCerrar(2026), isEmpty);
    // El de la gestión en curso no se cierra.
    expect(await store.talonariosPorCerrar(2027), hasLength(1));
  });

  test('un RIM emitido no se reemplaza', () async {
    final primero = await store.insert(
        await rimSiguiente(store), firmaDePrueba, firmaRepresentanteDePrueba);
    final otro = RimDocumento.fromJson({
      ...primero.documento.toJson(),
      'code': (await store.proximoNumero(gestion: 2026))!.codigo,
      'reason': 'Texto cambiado después de firmar.',
    });

    await expectLater(
      store.insert(otro, firmaDePrueba, firmaRepresentanteDePrueba),
      throwsA(isA<DatabaseException>()),
    );
    final vigente = await store.byUuid(otro.uuid);
    expect(vigente!.documento.motivo, startsWith('El indicador no enciende'));
    expect(vigente.documento.codigo, 'RIM-26-0041');
  });

  test('sabe si un servicio ya tiene RIM de su instrumento', () async {
    await store.insert(
        await rimSiguiente(store), firmaDePrueba, firmaRepresentanteDePrueba);

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
        await rimSiguiente(store), firmaDePrueba, firmaRepresentanteDePrueba);
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

  test('anular deja el RIM en el teléfono y lo sube con su anulación',
      () async {
    final rim = await store.insert(
        await rimSiguiente(store), firmaDePrueba, firmaRepresentanteDePrueba);

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
    // Se sube igual, para que su número no quede como un hueco.
    expect(anulado.canUpload, isTrue);
    expect(anulado.canAnular, isFalse);
    expect(await store.countUnsent(), 1);
    final json = anulado.toUploadJson();
    expect(json['code'], 'RIM-26-0041');
    expect(json['voided'], {
      'by': 'lmamani',
      'at': anulado.anuladoEn!.toUtc().toIso8601String(),
      'reason': 'Se eligió la balanza equivocada.',
    });
    // Sigue existiendo, con su contenido y sus firmas, y su número no se
    // vuelve a usar.
    expect(anulado.documento.contactoNombre, 'Juan Pérez Ñáñez');
    expect(anulado.firmaCliente, firmaDePrueba);
    expect(anulado.firmaRepresentante, firmaRepresentanteDePrueba);
    expect((await store.proximoNumero(gestion: 2026))!.codigo, 'RIM-26-0042');
    // Un RIM anulado ya no cuenta para el servicio: se puede emitir otro.
    expect(
      await store.existsForService(
          sessionId: '0007', codMetrica: '0090-11-014'),
      isFalse,
    );
    // No se puede anular dos veces.
    expect(
      await store.anular(rim.uuid, usuario: 'otro', motivo: 'Otra vez'),
      isFalse,
    );
  });

  test('lista primero lo pendiente (con los anulados) y después lo subido',
      () async {
    const uuids = [
      '11111111-1111-4111-8111-111111111111',
      '22222222-2222-4222-8222-222222222222',
      '33333333-3333-4333-8333-333333333333',
    ];
    for (var i = 0; i < uuids.length; i++) {
      await store.insert(
        await rimSiguiente(store,
            uuid: uuids[i], emitidoEn: DateTime(2026, 10, 1, 9 + i)),
        firmaDePrueba,
        firmaRepresentanteDePrueba,
      );
    }
    await store.markSent(uuids[0], 1);
    await store.anular(uuids[1], usuario: 'lmamani', motivo: 'Duplicado');

    final lista = await store.list();
    expect(lista.map((rim) => rim.uuid), [uuids[1], uuids[2], uuids[0]]);
    expect(await store.countUnsent(), 2);
  });

  test('una tabla anterior a la numeración se completa sin perder RIM',
      () async {
    // Tabla como la creaba la versión 6.3.3: sin firma_representante ni
    // numeración, con un RIM de código anterior.
    final anterior = await _otraBase();
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
    final viejo = rimDePrueba(codigo: 'RIM-0090-11-26', instalacion: null);
    await anterior.insert(RimStore.table, {
      'uuid': viejo.uuid,
      'codigo_rim': viejo.codigo,
      'service_type': viejo.service.serviceType.name,
      'payload': jsonEncode(viejo.toJson()),
      'firma_cliente': firmaDePrueba,
      'emitido_en': viejo.emitidoEn.toUtc().toIso8601String(),
      'status': RimEstadoSubida.pending.name,
    });

    final migrado =
        RimStore(database: anterior, installTime: () async => _instalada);
    final conservado = (await migrado.byUuid(viejo.uuid))!;
    expect(conservado.documento.codigo, 'RIM-0090-11-26');
    expect(conservado.documento.numeracion, isNull);
    expect(conservado.firmaCliente, firmaDePrueba);
    expect(conservado.firmaRepresentante, isNull);
    final json = conservado.toUploadJson();
    expect(json.containsKey('metricaSignature'), isFalse);
    expect(json.containsKey('installationId'), isFalse);

    await darTalonario(migrado);
    final nuevo = await migrado.insert(
      await rimSiguiente(migrado,
          uuid: '44444444-4444-4444-8444-444444444444'),
      firmaDePrueba,
      firmaRepresentanteDePrueba,
    );
    expect(nuevo.documento.codigo, 'RIM-26-0041');
    expect(nuevo.firmaRepresentante, firmaRepresentanteDePrueba);
    expect(await migrado.countUnsent(), 2);
  });
}
