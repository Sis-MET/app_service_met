import 'package:flutter_test/flutter_test.dart';
import 'package:service_met/screens/soporte_new/database/database_helper_soporte.dart';
import 'package:service_met/screens/soporte_new/utils/support_module_catalog.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database database;
  late DatabaseHelperSoporte helper;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    database = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    helper = DatabaseHelperSoporte.forTesting(database);
  });

  tearDown(() => database.close());

  Future<void> save({
    String module = 'diagnostico',
    String session = 'SOP_1',
    String personal = 'Ana',
    int step = 1,
  }) {
    return helper.saveSessionProgress(
      moduleKey: module,
      sessionId: session,
      otst: '0001-01-S01-26',
      personal: personal,
      currentStep: step,
      totalSteps: 3,
      routeData: const {
        'cliente_nombre': 'Cliente',
        'planta_nombre': 'Planta',
        'cod_metrica': '0001-01-001',
      },
    );
  }

  test('recupera solamente sesiones pendientes del técnico actual', () async {
    await save();
    await save(session: 'SOP_2', personal: 'Bruno');

    final result = await helper.getPendingSessions('Ana');

    expect(result, hasLength(1));
    expect(result.single['session_id'], 'SOP_1');
    expect(result.single['current_step'], 1);
  });

  test('una sesión completada no reaparece ni vuelve a pendiente', () async {
    await save();
    await helper.markSessionCompleted('diagnostico', 'SOP_1');
    await save(step: 2);

    expect(await helper.getPendingSessions('Ana'), isEmpty);
    final stored = await helper.getSessionProgress('diagnostico', 'SOP_1');
    expect(stored?['status'], 'completed');
  });

  test('descartar elimina la sesión de recuperación', () async {
    await save();
    await helper.markSessionAbandoned('diagnostico', 'SOP_1');

    expect(await helper.getPendingSessions('Ana'), isEmpty);
  });

  test('rechaza sesiones sin identificadores recuperables', () async {
    await helper.saveSessionProgress(
      moduleKey: 'diagnostico',
      sessionId: '',
      otst: 'OTST',
      personal: 'Ana',
      currentStep: 0,
      totalSteps: 2,
      routeData: const {'cod_metrica': '0001-01-001'},
    );

    expect(await helper.getPendingSessions('Ana'), isEmpty);
  });

  test('el catálogo cubre los ocho submódulos sin claves repetidas', () {
    final keys = SupportModuleCatalog.all.map((module) => module.key).toSet();

    expect(SupportModuleCatalog.all, hasLength(8));
    expect(keys, hasLength(8));
  });
}
