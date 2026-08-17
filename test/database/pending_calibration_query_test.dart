import 'package:flutter_test/flutter_test.dart';
import 'package:service_met/database/app_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await db.execute('''
      CREATE TABLE registros_calibracion (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        personal TEXT,
        seca TEXT,
        session_id TEXT,
        cod_metrica TEXT,
        fecha_servicio TEXT,
        estado_servicio_bal TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE servicio_status (
        seca TEXT,
        session_id TEXT,
        personal TEXT,
        current_step INTEGER,
        seca_confirmed INTEGER,
        balanza_confirmed INTEGER,
        status TEXT,
        finalized_at TEXT,
        updated_at TEXT
      )
    ''');
  });

  tearDown(() => db.close());

  Future<void> insertRecord(
    String seca,
    String personal, {
    String estado = '',
  }) {
    return db.insert('registros_calibracion', {
      'personal': personal,
      'seca': seca,
      'session_id': '0001',
      'fecha_servicio': '2026-08-12',
      'estado_servicio_bal': estado,
    });
  }

  Future<void> insertStatus(
    String seca,
    String personal,
    String status, {
    String? finalizedAt,
  }) {
    return db.insert('servicio_status', {
      'seca': seca,
      'session_id': '0001',
      'personal': personal,
      'status': status,
      'finalized_at': finalizedAt,
      'updated_at': '2026-08-12T12:00:00',
    });
  }

  test('solo devuelve procesos recuperables del usuario actual', () async {
    await insertRecord('PENDIENTE-ANA', 'Ana');
    await insertStatus('PENDIENTE-ANA', 'Ana', 'in_progress');

    await insertRecord('PENDIENTE-OTRO', 'Bruno');
    await insertStatus('PENDIENTE-OTRO', 'Bruno', 'in_progress');

    await insertRecord('COMPLETADO', 'Ana');
    await insertStatus('COMPLETADO', 'Ana', 'completed');

    await insertRecord('ABANDONADO', 'Ana');
    await insertStatus('ABANDONADO', 'Ana', 'abandoned');

    final result = await db.rawQuery(pendingServiciosQuery, ['Ana']);

    expect(result.map((row) => row['seca']), ['PENDIENTE-ANA']);
  });

  test('ignora estados pendientes que ya tienen evidencia de cierre', () async {
    await insertRecord(
      'BALANZA-CALIBRADA',
      'Ana',
      estado: 'Balanza Calibrada',
    );
    await insertStatus('BALANZA-CALIBRADA', 'Ana', 'in_progress');

    await insertRecord('SERVICIO-FINALIZADO', 'Ana');
    await insertStatus(
      'SERVICIO-FINALIZADO',
      'Ana',
      'in_progress',
      finalizedAt: '2026-08-12T12:30:00',
    );

    final result = await db.rawQuery(pendingServiciosQuery, ['Ana']);

    expect(result, isEmpty);
  });

  test('mantiene compatibilidad con registros antiguos sin status', () async {
    await insertRecord('LEGACY-ANA', 'Ana');
    await insertRecord('LEGACY-OTRO', 'Bruno');

    final result = await db.rawQuery(pendingServiciosQuery, ['Ana']);

    expect(result.map((row) => row['seca']), ['LEGACY-ANA']);
  });

  test('ignora registros que no tienen identificadores recuperables', () async {
    await insertRecord('', 'Ana');

    final result = await db.rawQuery(pendingServiciosQuery, ['Ana']);

    expect(result, isEmpty);
  });

  test('detecta otra sesión de la misma balanza dentro del SECA', () async {
    await db.insert('registros_calibracion', {
      'personal': 'Ana',
      'seca': '26-0100-01',
      'session_id': '0001',
      'cod_metrica': '0100-01-001',
      'fecha_servicio': '2026-08-17',
      'estado_servicio_bal': 'Balanza Calibrada',
    });

    final duplicate = await db.rawQuery(
      duplicateCalibrationServiceQuery,
      ['26-0100-01', '0100-01-001', '0002'],
    );
    final sameSession = await db.rawQuery(
      duplicateCalibrationServiceQuery,
      ['26-0100-01', '0100-01-001', '0001'],
    );

    expect(duplicate.single['session_id'], '0001');
    expect(sameSession, isEmpty);
  });

  test('permite reiniciar una sesión que fue abandonada', () async {
    await db.insert('registros_calibracion', {
      'personal': 'Ana',
      'seca': '26-0100-01',
      'session_id': '0001',
      'cod_metrica': '0100-01-001',
      'fecha_servicio': '2026-08-17',
      'estado_servicio_bal': '',
    });
    await insertStatus('26-0100-01', 'Ana', 'abandoned');

    final result = await db.rawQuery(
      duplicateCalibrationServiceQuery,
      ['26-0100-01', '0100-01-001', '0002'],
    );

    expect(result, isEmpty);
  });
}
