import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:service_met/database/soporte_tecnico/database_helper_diagnostico_correctivo.dart';
import 'package:service_met/screens/soporte_new/modulos/mnt_correctivo/controllers/mnt_correctivo_controller.dart';
import 'package:service_met/screens/soporte_new/modulos/mnt_correctivo/models/mnt_correctivo_model.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  // Los controladores avisan a la interfaz según la fase del cuadro.
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  Future<String> rutaBase() async =>
      p.join(await getDatabasesPath(), 'diagnostico_correctivo.db');

  Future<void> borrarBase() async {
    await DatabaseHelperDiagnosticoCorrectivo().close();
    await deleteDatabase(await rutaBase());
  }

  setUp(borrarBase);
  tearDown(borrarBase);

  /// Una base vieja o dañada: la tabla existe, pero sin las columnas que el
  /// guardado escribe. Cualquier escritura falla.
  Future<void> baseSinColumnas() async {
    final db = await openDatabase(
      await rutaBase(),
      version: 1,
      onCreate: (db, _) => db.execute('CREATE TABLE diagnostico_correctivo '
          '(id INTEGER PRIMARY KEY, otst TEXT, session_id TEXT)'),
    );
    await db.close();
  }

  MntCorrectivoController abrir() {
    final controller = MntCorrectivoController(
      model: MntCorrectivoModel(sessionId: '0001', codMetrica: '0032-11-020'),
    )..secaValue = '26-0032-11-S01';
    addTearDown(controller.dispose);
    return controller;
  }

  group('guardado de Mantenimiento Correctivo', () {
    test('si la base rechaza el registro, se entera quien guarda', () async {
      await baseSinColumnas();

      await expectLater(
        DatabaseHelperDiagnosticoCorrectivo().upsertRegistroRelevamiento(
            {'otst': 'X', 'session_id': '1', 'reporte': 'Falla'}),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('un guardado fallido queda marcado, con su motivo, y pendiente',
        () async {
      await baseSinColumnas();
      final controller = abrir()..reporteFalla = 'No enciende';
      controller.hasUnsavedChanges.value = true;

      await controller.autoSave();

      expect(controller.lastSaveSuccessful, isFalse);
      expect(controller.lastSaveError, contains('no column'));
      // Sigue pendiente: el próximo cambio o el paso a segundo plano
      // vuelven a intentarlo.
      expect(controller.hasUnsavedChanges.value, isTrue);
    });

    test('no se da por finalizado lo que no quedó en la base', () async {
      await baseSinColumnas();
      final controller = abrir();

      await expectLater(
        controller.finalizarServicio(
          horaFin: '10:30',
          fechaProxServicio: '2027-03-01',
        ),
        throwsA(isA<DatabaseException>()),
      );
      expect(controller.lastSaveSuccessful, isFalse);
    });

    test('con la base bien, guarda y deja de estar pendiente', () async {
      final controller = abrir()..reporteFalla = 'No enciende';
      controller.hasUnsavedChanges.value = true;

      await controller.autoSave();

      expect(controller.lastSaveSuccessful, isTrue);
      expect(controller.lastSaveError, isNull);
      expect(controller.hasUnsavedChanges.value, isFalse);
      final guardado = await DatabaseHelperDiagnosticoCorrectivo()
          .getRegistroBySeca('26-0032-11-S01', '0001');
      expect(guardado?['reporte'], 'No enciende');
    });
  });
}
