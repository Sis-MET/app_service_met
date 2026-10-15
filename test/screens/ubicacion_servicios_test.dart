import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:service_met/database/app_database.dart';
import 'package:service_met/database/local_database_catalog.dart';
import 'package:service_met/database/soporte_tecnico/database_helper_ajustes.dart';
import 'package:service_met/database/soporte_tecnico/database_helper_diagnostico_correctivo.dart';
import 'package:service_met/database/soporte_tecnico/database_helper_instalacion.dart';
import 'package:service_met/database/soporte_tecnico/database_helper_mnt_prv_avanzado_stac.dart';
import 'package:service_met/database/soporte_tecnico/database_helper_mnt_prv_regular_stil.dart';
import 'package:service_met/database/soporte_tecnico/database_helper_relevamiento.dart';
import 'package:service_met/database/soporte_tecnico/database_helper_verificaciones.dart';
import 'package:service_met/home/services/calibration_upload_api_service.dart';
import 'package:service_met/home/services/support_upload_api_service.dart';
import 'package:service_met/models/service_session.dart';
import 'package:service_met/providers/service_session_provider.dart';
import 'package:service_met/repositories/calibration_repository.dart';
import 'package:service_met/screens/soporte_new/controllers/base_soporte_controller.dart';
import 'package:service_met/screens/soporte_new/modulos/ajuste_verificaciones/controllers/ajuste_verificaciones_controller.dart';
import 'package:service_met/screens/soporte_new/modulos/ajuste_verificaciones/models/ajuste_verificaciones_model.dart';
import 'package:service_met/screens/soporte_new/modulos/diagnostico/controllers/diagnostico_controller.dart';
import 'package:service_met/screens/soporte_new/modulos/diagnostico/models/diagnostico_model.dart';
import 'package:service_met/screens/soporte_new/modulos/instalacion/controllers/instalacion_controller.dart';
import 'package:service_met/screens/soporte_new/modulos/instalacion/models/instalacion_model.dart';
import 'package:service_met/screens/soporte_new/modulos/mnt_correctivo/controllers/mnt_correctivo_controller.dart';
import 'package:service_met/screens/soporte_new/modulos/mnt_correctivo/models/mnt_correctivo_model.dart';
import 'package:service_met/screens/soporte_new/modulos/mnt_prv_avanzado/controllers/mnt_prv_avanzado_controller.dart';
import 'package:service_met/screens/soporte_new/modulos/mnt_prv_avanzado/models/mnt_prv_avanzado_model.dart';
import 'package:service_met/screens/soporte_new/modulos/mnt_prv_regular/controllers/mnt_prv_regular_controller.dart';
import 'package:service_met/screens/soporte_new/modulos/mnt_prv_regular/models/mnt_prv_regular_model.dart';
import 'package:service_met/screens/soporte_new/modulos/relevamiento_de_datos/controllers/relevamiento_de_datos_controller.dart';
import 'package:service_met/screens/soporte_new/modulos/relevamiento_de_datos/models/relevamiento_de_datos_model.dart';
import 'package:service_met/screens/soporte_new/modulos/verificaciones_internas/controllers/verificaciones_internas_controller.dart';
import 'package:service_met/screens/soporte_new/modulos/verificaciones_internas/models/verificaciones_internas_model.dart';
import 'package:service_met/services/ubicacion_servicio.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// La calibración y cada uno de los 8 módulos de soporte dejan la ubicación
/// en su propia fila al guardar, y la subida la envía aparte del registro
/// técnico.
void main() {
  // Los controladores avisan a la interfaz según la fase del cuadro.
  TestWidgetsFlutterBinding.ensureInitialized();

  const otst = '26-0032-11-S99';
  const sessionId = '0001';
  const codMetrica = '0032-11-020';

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  Future<void> borrarBases() async {
    await DatabaseHelperAjustes().close();
    await DatabaseHelperDiagnosticoCorrectivo().close();
    await DatabaseHelperInstalacion().close();
    await DatabaseHelperMntPrvAvanzadoStac().close();
    await DatabaseHelperMntPrvRegularStil().close();
    await DatabaseHelperRelevamiento().close();
    await DatabaseHelperVerificaciones().close();
    await AppDatabase().close();
    final raiz = await getDatabasesPath();
    for (final archivo
        in LocalDatabaseCatalog.all.map((spec) => spec.database).toSet()) {
      await deleteDatabase(p.join(raiz, archivo));
    }
  }

  setUp(() async {
    await borrarBases();
    RegistroUbicacion.instance.reiniciar();
    RegistroUbicacion.lectorOverride = () async => UbicacionServicio(
          latitud: -16.500012,
          longitud: -68.150099,
          precision: 7.5,
          fecha: DateTime.utc(2026, 10, 15, 13, 30),
        );
  });

  tearDown(() async {
    // Deja terminar la escritura en segundo plano antes de borrar.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    RegistroUbicacion.lectorOverride = null;
    RegistroUbicacion.instance.reiniciar();
    await borrarBases();
  });

  final modulos = <String, BaseSoporteController Function()>{
    'ajuste_verificaciones': () => AjusteVerificacionesController(
        model: AjusteVerificacionesModel(
            sessionId: sessionId, codMetrica: codMetrica)),
    'diagnostico': () => DiagnosticoController(
        model: DiagnosticoModel(sessionId: sessionId, codMetrica: codMetrica)),
    // Como su pantalla al abrirse, que arma los puntos a revisar.
    'instalacion': () => InstalacionController(
        model: InstalacionModel(sessionId: sessionId, codMetrica: codMetrica))
      ..initCamposEstado(),
    'mnt_correctivo': () => MntCorrectivoController(
        model:
            MntCorrectivoModel(sessionId: sessionId, codMetrica: codMetrica)),
    'mnt_prv_avanzado': () => MntPrvAvanzadoController(
        model:
            MntPrvAvanzadoModel(sessionId: sessionId, codMetrica: codMetrica)),
    'mnt_prv_regular': () => MntPrvRegularController(
        model:
            MntPrvRegularModel(sessionId: sessionId, codMetrica: codMetrica)),
    'relevamiento_de_datos': () => RelevamientoDeDatosController(
        model: RelevamientoDeDatosModel(
            sessionId: sessionId, codMetrica: codMetrica)),
    'verificaciones_internas': () => VerificacionesInternasController(
        model: VerificacionesInternasModel(
            sessionId: sessionId, codMetrica: codMetrica)),
  };

  test('calibración guarda la ubicación al autoguardar y la sube aparte',
      () async {
    final provider = ServiceSessionProvider(CalibrationRepository());
    addTearDown(provider.dispose);
    await provider.createNewSession('tecnico');
    provider.updateCliente(ClienteInfo(id: '1', nombreComercial: 'Cliente'));
    provider.updatePlanta(PlantaInfo(codigo: '0032-11', nombre: 'Planta'));
    // Confirmar la SECA crea el registro con el mismo guardado de siempre.
    expect(await provider.confirmSeca(), isTrue);
    final seca = provider.session!.sessionInfo.seca!;
    final id = provider.session!.sessionInfo.sessionId!;
    await CalibrationRepository().registrarUbicacion(seca, id);

    final filas = await CalibrationRepository().getRegistrosPorSeca(seca);
    expect(filas.single['latitud'], -16.500012);
    expect(filas.single['precision_gps'], 7.5);
    final ubicaciones = calibrationUploadLocations(filas);
    expect(ubicaciones.single!['longitud'], -68.150099);
  });

  test('los 8 módulos de soporte están cubiertos', () {
    expect(modulos.keys.toSet(),
        LocalDatabaseCatalog.soporte.map((spec) => spec.module).toSet());
  });

  for (final MapEntry(key: modulo, value: crear) in modulos.entries) {
    test('$modulo guarda la ubicación del servicio y la sube aparte', () async {
      final controller = crear()..secaValue = otst;
      addTearDown(controller.dispose);

      await controller.guardarSesion();
      expect(controller.lastSaveSuccessful, isTrue,
          reason: controller.lastSaveError);
      // El guardado ya la pidió en segundo plano; esperarla aquí no la
      // duplica (solo se escribe si la fila no tiene una).
      await controller.registrarUbicacion();

      final spec = LocalDatabaseCatalog.soporte
          .singleWhere((spec) => spec.module == modulo);
      final db = await spec.openLive();
      final fila = (await db.query(
        spec.table,
        where: 'otst = ? AND session_id = ?',
        whereArgs: [otst, sessionId],
      ))
          .single;
      expect(fila['latitud'], -16.500012);
      expect(fila['longitud'], -68.150099);
      expect(fila['precision_gps'], 7.5);
      expect(fila['fecha_gps'], isNotEmpty);

      final sobre = buildSupportUploadEnvelopes([
        {...fila, '_support_module': modulo},
      ]).single;
      final ubicacion = sobre['ubicacion'] as Map;
      expect(ubicacion['latitud'], -16.500012);
      expect(sobre['module'], modulo);
      final datos = sobre['data'] as Map;
      for (final columna in UbicacionServicio.columnas) {
        expect(datos, isNot(contains(columna)));
      }
    });
  }
}
