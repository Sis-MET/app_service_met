import 'dart:convert';
import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:service_met/database/auditoria_registros.dart';
import 'package:service_met/screens/calibracion/utils/reading_profile.dart';
import 'package:service_met/screens/calibracion_temperatura/data/temperatura_store.dart';
import 'package:service_met/screens/calibracion_temperatura/models/temperatura_models.dart';
import 'package:service_met/screens/calibracion_temperatura/services/temperatura_export.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;
  late TemperaturaStore store;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    store = TemperaturaStore(open: () async => db);
  });

  tearDown(() => db.close());

  final inicio = DateTime(2026, 10, 29, 9, 0);

  Future<TempServicio> servicioListo() async {
    var servicio =
        await store.crear(personal: 'jperez', appVersion: '6.5.0+20');
    servicio = await store.guardar(servicio.copyWith(
      seca: '0032-11-C01-26',
      secaConfirmada: true,
      cliente: const TempCliente(codigo: '0032', nombre: 'Lab Andino'),
      planta: const TempPlanta(codigo: '0032-11', nombre: 'El Alto'),
      equipo: const TempEquipo(
        codMetrica: '0032-11-090',
        tipo: 'Mufla',
        rangoMin: 100,
        rangoMax: 1100,
        resolucion: 1,
      ),
      equipoConfirmado: true,
    ));
    await store.guardarPatrones(servicio.uuid, const [
      TempPatron(codInstrumento: 'TM-001', instrumento: 'Termómetro patrón'),
    ]);
    await store.guardarCanales(servicio.uuid, const [
      TempCanal(
          n: 1,
          nombre: 'Patrón · Centro',
          rol: RolCanal.patron,
          codPatron: 'TM-001'),
      TempCanal(
          n: 2,
          nombre: 'Indicador del equipo',
          rol: RolCanal.equipo,
          decimales: 0),
    ]);
    await store.guardarPuntos(servicio.uuid, const [
      TempPunto(n: 1, temperaturaNominal: 300, duracionMin: 45, intervaloS: 30),
      TempPunto(n: 2, temperaturaNominal: 600, duracionMin: 45, intervaloS: 30),
    ]);
    return servicio;
  }

  TempLectura lectura(int n, int canal, double? valor,
          {EstadoLectura estado = EstadoLectura.valida}) =>
      TempLectura(
        nPunto: 1,
        nLectura: n,
        nCanal: canal,
        tiempoProgramadoS: n * 30,
        capturadaEn: '2026-10-29T09:00:00.000-04:00',
        valor: valor,
        valorOriginal: valor,
        origen: valor == null
            ? OrigenLectura.sinLectura
            : OrigenLectura.ocrSegmentos,
        estado: estado,
      );

  test('crea las tablas y la cabecera con su código de registro', () async {
    final servicio = await servicioListo();
    final leido = await store.servicio(servicio.uuid);
    expect(leido?.codigoRegistro, '0032-11-C01-26-0032-11-090');
    expect(leido?.equipo?.tipo, 'Mufla');
    expect(leido?.personal, 'jperez');
    expect(leido?.appVersion, '6.5.0+20');
    expect((await store.pendientes('jperez')).single.uuid, servicio.uuid);
    // Las columnas de ubicación existen.
    final columnas = (await db.rawQuery('PRAGMA table_info(temp_servicios)'))
        .map((c) => c['name'])
        .toSet();
    expect(columnas, containsAll(['latitud', 'longitud', 'fecha_gps']));
  });

  test('91 lecturas en 45 minutos cada 30 segundos', () {
    expect(lecturasProgramadas(duracionMin: 45, intervaloS: 30), 91);
    expect(lecturasProgramadas(duracionMin: 30, intervaloS: 60), 31);
    expect(lecturasProgramadas(duracionMin: 1, intervaloS: 45), 2);
    expect(lecturasProgramadas(duracionMin: 0, intervaloS: 30), 0);
  });

  test('las lecturas solo se agregan', () async {
    final servicio = await servicioListo();
    await expectLater(
      store.registrarLectura(servicio.uuid, lectura(0, 1, 299.8)),
      throwsA(isA<TemperaturaError>()),
      reason: 'el punto no está en medición',
    );
    await store.iniciarPunto(servicio.uuid, 1, inicio);
    expect(await store.registrarLectura(servicio.uuid, lectura(0, 1, 299.8)),
        isTrue);
    // Otra lectura para la misma hora y canal no reemplaza a la primera.
    expect(await store.registrarLectura(servicio.uuid, lectura(0, 1, 500)),
        isFalse);
    final lecturas = await store.lecturasDe(servicio.uuid);
    expect(lecturas.single.valor, 299.8);
  });

  test('corregir conserva el valor original y deja el historial', () async {
    final servicio = await servicioListo();
    await store.iniciarPunto(servicio.uuid, 1, inicio);
    await store.registrarLectura(servicio.uuid, lectura(0, 1, 299.8));

    await expectLater(
      store.corregir(servicio.uuid,
          nPunto: 1,
          nLectura: 0,
          nCanal: 1,
          tipo: TipoCorreccion.correccion,
          valorNuevo: 289.8,
          motivo: '',
          usuario: 'jperez'),
      throwsA(isA<TemperaturaError>()),
      reason: 'sin motivo',
    );

    final corregida = await store.corregir(servicio.uuid,
        nPunto: 1,
        nLectura: 0,
        nCanal: 1,
        tipo: TipoCorreccion.correccion,
        valorNuevo: 289.8,
        motivo: 'La imagen muestra 289.8',
        usuario: 'jperez');
    expect(corregida.valor, 289.8);
    expect(corregida.valorOriginal, 299.8);

    await store.corregir(servicio.uuid,
        nPunto: 1,
        nLectura: 0,
        nCanal: 1,
        tipo: TipoCorreccion.exclusion,
        motivo: 'Se abrió la puerta',
        usuario: 'jperez');
    final lectura0 = (await store.lecturasDe(servicio.uuid)).single;
    expect(lectura0.estado, EstadoLectura.excluida);
    expect(lectura0.valor, 289.8);
    expect(lectura0.valorOriginal, 299.8);

    final historial = await store.correccionesDe(servicio.uuid);
    expect(historial.map((c) => c.tipo),
        [TipoCorreccion.correccion, TipoCorreccion.exclusion]);
    expect(historial.first.valorAnterior, 299.8);
    expect(historial.first.valorNuevo, 289.8);
    expect(historial.first.usuario, 'jperez');
  });

  test('canales y puntos medidos quedan fijos', () async {
    final servicio = await servicioListo();
    await store.iniciarPunto(servicio.uuid, 1, inicio);
    await store.registrarLectura(servicio.uuid, lectura(0, 1, 300));

    await expectLater(
      store.guardarCanales(servicio.uuid, const [
        TempCanal(n: 1, nombre: 'Otro nombre', rol: RolCanal.patron),
      ]),
      throwsA(isA<TemperaturaError>()),
    );
    // El recuadro y el perfil sí se guardan: son solo del teléfono.
    await store.guardarLectorCanal(servicio.uuid, 1,
        region: const Rect.fromLTRB(0.1, 0.2, 0.5, 0.4),
        perfil: ReadingProfile.temperatura);
    final canal = (await store.canalesDe(servicio.uuid)).first;
    expect(canal.region, const Rect.fromLTRB(0.1, 0.2, 0.5, 0.4));
    expect(canal.perfil, ReadingProfile.temperatura);
    expect(canal.nombre, 'Patrón · Centro');

    await expectLater(
      store.guardarPuntos(servicio.uuid, const [
        TempPunto(
            n: 1, temperaturaNominal: 350, duracionMin: 45, intervaloS: 30),
      ]),
      throwsA(isA<TemperaturaError>()),
    );
    // Los pendientes sí cambian, y el medido sigue igual.
    await store.guardarPuntos(servicio.uuid, const [
      TempPunto(n: 1, temperaturaNominal: 300, duracionMin: 45, intervaloS: 30),
      TempPunto(n: 2, temperaturaNominal: 700, duracionMin: 30, intervaloS: 60),
    ]);
    final puntos = await store.puntosDe(servicio.uuid);
    expect(puntos.map((p) => p.temperaturaNominal), [300, 700]);
    expect(puntos.first.estado, EstadoPunto.enCurso);
  });

  test('finalizar exige un punto medido y después bloquea todo', () async {
    final servicio = await servicioListo();
    await expectLater(
        store.finalizar(servicio.uuid), throwsA(isA<TemperaturaError>()));
    await store.iniciarPunto(servicio.uuid, 1, inicio);
    await store.registrarLectura(servicio.uuid, lectura(0, 1, 300));
    await expectLater(
        store.finalizar(servicio.uuid), throwsA(isA<TemperaturaError>()),
        reason: 'punto en medición');
    await expectLater(
      store.terminarPunto(servicio.uuid, 1,
          estado: EstadoPunto.interrumpido, fin: inicio),
      throwsA(isA<TemperaturaError>()),
      reason: 'interrumpir pide motivo',
    );
    await store.terminarPunto(servicio.uuid, 1,
        estado: EstadoPunto.interrumpido,
        fin: inicio.add(const Duration(minutes: 10)),
        motivo: 'Corte de energía en la planta');

    final cerrado = await store.finalizar(servicio.uuid);
    expect(cerrado.estado, EstadoServicioTemp.finalizado);
    expect(cerrado.horaFin, isNotNull);
    expect(await store.contarSinSubir(), 1);

    await expectLater(store.guardar(cerrado), throwsA(isA<TemperaturaError>()));
    await expectLater(
      store.corregir(servicio.uuid,
          nPunto: 1,
          nLectura: 0,
          nCanal: 1,
          tipo: TipoCorreccion.exclusion,
          motivo: 'Ya no se puede',
          usuario: 'jperez'),
      throwsA(isA<TemperaturaError>()),
    );
    await store.marcarSubida(servicio.uuid, EstadoSubidaTemp.subido,
        serverN: 7);
    expect(await store.contarSinSubir(), 0);
    expect((await store.servicio(servicio.uuid))?.serverN, 7);
  });

  test('el código de un equipo nuevo se asigna con historial', () async {
    var servicio = await store.crear(personal: 'jperez');
    servicio = await store.guardar(servicio.copyWith(
      seca: '0032-11-C01-26',
      equipo: const TempEquipo(codMetrica: '0032-11-291026093000', nuevo: true),
    ));
    final asignado = await store.asignarCodigo(servicio.uuid,
        codigo: '0032-11-095', usuario: 'jperez', appVersion: '6.5.0+20');
    expect(asignado.equipo?.codMetrica, '0032-11-095');
    expect(asignado.equipo?.nuevo, isFalse);
    expect(asignado.codigoRegistro, '0032-11-C01-26-0032-11-095');
    final historial = await AuditoriaRegistros.deRegistro(db,
        tablaRegistro: TemperaturaStore.servicios,
        clave: 'uuid=${servicio.uuid}');
    expect(historial.single.valorAnterior, '0032-11-291026093000');
    expect(historial.single.valorNuevo, '0032-11-095');
    await expectLater(
      store.asignarCodigo(servicio.uuid,
          codigo: '0032-11-096', usuario: 'jperez', appVersion: '6.5.0+20'),
      throwsA(isA<TemperaturaError>()),
      reason: 'ya no es provisional',
    );
  });

  test('otro equipo de la misma SECA copia la configuración sin lecturas',
      () async {
    final servicio = await servicioListo();
    await store.iniciarPunto(servicio.uuid, 1, inicio);
    final base = await store.paquete(servicio.uuid);
    final otro = await store.crear(personal: 'jperez', base: base);
    final copia = await store.paquete(otro.uuid);
    expect(copia?.servicio.seca, '0032-11-C01-26');
    expect(copia?.servicio.equipo, isNull);
    expect(copia?.canales.length, 2);
    expect(copia?.patrones.single.codInstrumento, 'TM-001');
    expect(
        copia?.puntos.every((p) => p.estado == EstadoPunto.pendiente), isTrue);
    expect(copia?.lecturas, isEmpty);
  });

  test('descartar deja el registro en el teléfono', () async {
    final servicio = await servicioListo();
    await store.abandonar(servicio.uuid);
    expect(await store.pendientes('jperez'), isEmpty);
    expect((await store.servicio(servicio.uuid))?.estado,
        EstadoServicioTemp.abandonado);
  });

  test('el JSON de subida lleva todo menos lo que es solo del teléfono',
      () async {
    final servicio = await servicioListo();
    await store.iniciarPunto(servicio.uuid, 1, inicio);
    await store.registrarLectura(
        servicio.uuid, lectura(0, 1, 300.2).copyWith());
    final paquete = (await store.paquete(servicio.uuid))!;
    final json = TemperaturaExport.uploadJson(paquete);
    expect(json['uuid'], servicio.uuid);
    expect(json['codigo_registro'], '0032-11-C01-26-0032-11-090');
    expect((json['canales'] as List).first, isNot(contains('region')),
        reason: 'el recuadro no se sube');
    final lecturas = json['lecturas'] as List;
    expect(lecturas.single, containsPair('valor_original', 300.2));
    expect(lecturas.single, isNot(contains('imagen_path')));
    expect(() => jsonEncode(json), returnsNormally);

    final csv = utf8.decode(TemperaturaExport.csv(paquete).sublist(3));
    expect(csv, contains('Punto 1;300 °C;91 lecturas cada 30 s'));
    expect(csv, contains('0;0;300.2;;'));
    expect(TemperaturaExport.csvFileName(paquete.servicio),
        'TEMP_0032-11-C01-26_0032-11-090.csv');
  });
}
