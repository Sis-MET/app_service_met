import 'package:flutter_test/flutter_test.dart';
import 'package:service_met/database/calibration_data_normalizer.dart';
import 'package:service_met/home/services/calibration_upload_api_service.dart';
import 'package:service_met/home/services/support_upload_api_service.dart';
import 'package:service_met/services/ubicacion_servicio.dart';
import 'package:service_met/utils/fecha_iso.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  late Database db;
  var lecturas = 0;
  UbicacionServicio? gps;

  setUp(() async {
    lecturas = 0;
    gps = UbicacionServicio(
      latitud: -16.500012,
      longitud: -68.150099,
      precision: 8.4,
      fecha: DateTime.utc(2026, 10, 15, 13, 30),
    );
    RegistroUbicacion.instance.reiniciar();
    RegistroUbicacion.lectorOverride = () async {
      lecturas++;
      return gps;
    };
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await db.execute('''
      CREATE TABLE registros_calibracion (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        seca TEXT DEFAULT '',
        session_id TEXT DEFAULT '',
        cod_metrica TEXT DEFAULT ''
      )
    ''');
    await db.insert('registros_calibracion',
        {'seca': '26-0032-11', 'session_id': '0001', 'cod_metrica': 'A'});
  });

  tearDown(() async {
    RegistroUbicacion.lectorOverride = null;
    RegistroUbicacion.instance.reiniciar();
    await db.close();
  });

  Future<bool> registrar([String sessionId = '0001']) =>
      RegistroUbicacion.instance.registrar(
        abrir: () async => db,
        tabla: 'registros_calibracion',
        where: 'seca = ? AND session_id = ?',
        whereArgs: ['26-0032-11', sessionId],
      );

  test('agrega las columnas y guarda la ubicación en la fila del servicio',
      () async {
    expect(await registrar(), isTrue);

    final fila = (await db.query('registros_calibracion')).single;
    expect(fila['latitud'], -16.500012);
    expect(fila['longitud'], -68.150099);
    expect(fila['precision_gps'], 8.4);
    expect(fila['fecha_gps'], isNotEmpty);
    expect(UbicacionServicio.deRegistro(fila)!.coordenadas,
        '-16.500012, -68.150099');
  });

  test('la primera ubicación no se reemplaza en guardados posteriores',
      () async {
    expect(await registrar(), isTrue);
    RegistroUbicacion.instance.reiniciar();
    gps = const UbicacionServicio(latitud: -17.78, longitud: -63.18);

    expect(await registrar(), isFalse);
    final fila = (await db.query('registros_calibracion')).single;
    expect(fila['latitud'], -16.500012);
  });

  test('sin GPS no abre la base ni escribe nada', () async {
    gps = null;
    var abierta = false;
    final escrito = await RegistroUbicacion.instance.registrar(
      abrir: () async {
        abierta = true;
        return db;
      },
      tabla: 'registros_calibracion',
      where: 'seca = ? AND session_id = ?',
      whereArgs: ['26-0032-11', '0001'],
    );

    expect(escrito, isFalse);
    expect(abierta, isFalse);
  });

  test('reutiliza una lectura reciente para las demás balanzas', () async {
    await db.insert('registros_calibracion',
        {'seca': '26-0032-11', 'session_id': '0002', 'cod_metrica': 'B'});

    expect(await registrar('0001'), isTrue);
    expect(await registrar('0002'), isTrue);
    expect(lecturas, 1);
  });

  test('si la fila aún no existe, lo intenta en el siguiente guardado',
      () async {
    expect(await registrar('0009'), isFalse);
    await db.insert('registros_calibracion',
        {'seca': '26-0032-11', 'session_id': '0009', 'cod_metrica': 'C'});
    expect(await registrar('0009'), isTrue);
  });

  test('dos guardados al mismo tiempo no chocan al crear las columnas',
      () async {
    await db.insert('registros_calibracion',
        {'seca': '26-0032-11', 'session_id': '0002', 'cod_metrica': 'B'});

    final escritos = await Future.wait([registrar('0001'), registrar('0002')]);

    expect(escritos, [isTrue, isTrue]);
    final columnas =
        await db.rawQuery('PRAGMA table_info(registros_calibracion)');
    expect(columnas.where((c) => c['name'] == 'latitud'), hasLength(1));
  });

  test('descarta coordenadas inválidas guardadas en la fila', () {
    expect(
        UbicacionServicio.deRegistro({'latitud': '', 'longitud': ''}), isNull);
    expect(UbicacionServicio.deRegistro({'latitud': 0, 'longitud': 0}), isNull);
    expect(
        UbicacionServicio.deRegistro({'latitud': 95, 'longitud': 10}), isNull);
    expect(
        UbicacionServicio.deRegistro({'latitud': '-16,5', 'longitud': '-68.1'})!
            .latitud,
        -16.5);
  });

  test('la fecha del fijado se guarda en hora local con su desfase', () {
    final texto = fechaIsoConDesfase(DateTime.utc(2026, 1, 2, 3));
    expect(
        texto,
        matches(
            RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}[+-]\d{2}:\d{2}$')));
    expect(DateTime.parse(texto).toUtc(), DateTime.utc(2026, 1, 2, 3));
  });

  group('subida', () {
    final conUbicacion = {
      'seca': '26-0032-11',
      'session_id': '0001',
      'cod_metrica': '0032-11-001',
      'estado_servicio_bal': 'Balanza Calibrada',
      'latitud': -16.5,
      'longitud': -68.15,
      'precision_gps': 6.0,
      'fecha_gps': '2026-10-15T09:30:00-04:00',
    };

    test('calibración: el detalle no lleva la ubicación', () {
      final normalizado =
          CalibrationDataNormalizer.normalizeForUpload(conUbicacion);
      for (final columna in UbicacionServicio.columnas) {
        expect(normalizado, isNot(contains(columna)));
      }
    });

    test('calibración: las ubicaciones van alineadas con los registros', () {
      final ubicaciones = calibrationUploadLocations([
        conUbicacion,
        {'seca': '26-0032-11', 'session_id': '0002'},
      ]);
      expect(ubicaciones, hasLength(2));
      expect(ubicaciones.first!['latitud'], -16.5);
      final fecha = ubicaciones.first!['fecha_gps'] as String;
      // La salida usa la zona local del teléfono o del servidor de pruebas.
      // Debe conservar el instante y un desfase explícito, no exigir UTC-4.
      expect(DateTime.parse(fecha).toUtc(), DateTime.utc(2026, 10, 15, 13, 30));
      expect(fecha, matches(RegExp(r'[+-]\d{2}:\d{2}$')));
      expect(ubicaciones.last, isNull);
    });

    test('calibración: conserva el instante de fechas con distintos desfases',
        () {
      final ubicaciones = calibrationUploadLocations([
        for (final fecha in [
          '2026-10-15T09:30:00-04:00',
          '2026-10-15T13:30:00Z',
          '2026-10-15T19:15:00+05:45',
        ])
          {...conUbicacion, 'fecha_gps': fecha},
      ]);
      expect(ubicaciones, hasLength(3));
      for (final ubicacion in ubicaciones) {
        final fecha = ubicacion!['fecha_gps'] as String;
        expect(
            DateTime.parse(fecha).toUtc(), DateTime.utc(2026, 10, 15, 13, 30));
        expect(fecha, matches(RegExp(r'[+-]\d{2}:\d{2}$')));
      }
    });

    test('soporte: la ubicación va en el sobre, fuera de los datos', () {
      final sobres = buildSupportUploadEnvelopes([
        {
          '_support_module': 'mnt_prv_regular',
          'otst': '26-0090-11-S02',
          'session_id': '0001',
          'cod_metrica': '0090-11-014',
          'latitud': -16.5,
          'longitud': -68.15,
          'precision_gps': null,
          'fecha_gps': null,
        },
        {
          '_support_module': 'mnt_prv_regular',
          'otst': '26-0090-11-S02',
          'session_id': '0002',
          'cod_metrica': '0090-11-015',
        },
      ]);

      final datos = sobres.first['data'] as Map<String, dynamic>;
      for (final columna in UbicacionServicio.columnas) {
        expect(datos, isNot(contains(columna)));
      }
      expect((sobres.first['ubicacion'] as Map)['longitud'], -68.15);
      expect(sobres.last, isNot(contains('ubicacion')));
    });
  });
}
