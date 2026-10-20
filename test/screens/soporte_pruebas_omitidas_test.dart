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
import 'package:service_met/home/services/support_upload_api_service.dart';
import 'package:service_met/models/service_session.dart';
import 'package:service_met/screens/soporte_new/controllers/base_soporte_controller.dart';
import 'package:service_met/screens/soporte_new/modulos/ajuste_verificaciones/controllers/ajuste_verificaciones_controller.dart';
import 'package:service_met/screens/soporte_new/modulos/ajuste_verificaciones/models/ajuste_verificaciones_model.dart';
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
import 'package:service_met/screens/soporte_new/utils/pruebas_iniciales_columnas.dart';
import 'package:service_met/screens/soporte_new/utils/pruebas_omitidas.dart';
import 'package:service_met/services/ubicacion_servicio.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Omitir una prueba metrológica con "Realizar ..." queda en el registro de
/// cada uno de los 7 módulos con pruebas: la prueba no deja datos, sigue
/// omitida al reabrir el servicio y no se sube.
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
    // Sin GPS en las pruebas.
    RegistroUbicacion.lectorOverride = () async => null;
  });

  tearDown(() async {
    // Deja terminar la escritura en segundo plano antes de borrar.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    RegistroUbicacion.lectorOverride = null;
    RegistroUbicacion.instance.reiniciar();
    await borrarBases();
  });

  Future<Map<String, dynamic>> fila(String modulo) async {
    final spec =
        LocalDatabaseCatalog.soporte.singleWhere((s) => s.module == modulo);
    final db = await spec.openLive();
    return Map<String, dynamic>.from((await db.query(
      spec.table,
      where: 'otst = ? AND session_id = ?',
      whereArgs: [otst, sessionId],
    ))
        .single);
  }

  // Los indicadores "Realizar ..." se llaman igual en todos los módulos,
  // pero no están en el controlador base.
  bool realizada(BaseSoporteController c, String prueba) => switch (prueba) {
        'excentricidad' => (c as dynamic).excentricidadRealizada as bool,
        'repetibilidad' => (c as dynamic).repetibilidadRealizada as bool,
        _ => (c as dynamic).linealidadRealizada as bool,
      };

  LinealidadData cargas(List<String> valores) => LinealidadData(filas: [
        for (final v in valores)
          FilaLinealidad(carga: v, indicacion: v, retorno: '0'),
      ]);

  final modulos = <String, _Modulo>{
    'ajuste_verificaciones': _Modulo(
      crear: () => AjusteVerificacionesController(
          model: AjusteVerificacionesModel(
              sessionId: sessionId, codMetrica: codMetrica)),
      ponerLinealidad: (c, lin) => (c as AjusteVerificacionesController)
        ..linealidadInicial = lin
        ..linealidadFinal = lin,
      linealidad: (c) => (c as AjusteVerificacionesController).linealidadInicial,
      reabrir: (c, _) => (c as AjusteVerificacionesController).restoreSession(),
      columnaCarga: (n) => 'linealidad_inicial_punto${n}_lt',
    ),
    'instalacion': _Modulo(
      crear: () => InstalacionController(
          model:
              InstalacionModel(sessionId: sessionId, codMetrica: codMetrica))
        ..initCamposEstado(),
      ponerLinealidad: (c, lin) =>
          (c as InstalacionController).linealidadInicial = lin,
      linealidad: (c) => (c as InstalacionController).linealidadInicial,
      reabrir: (c, _) => (c as InstalacionController).restoreSession(),
      columnaCarga: (n) => 'lin_inicial_$n',
    ),
    'mnt_correctivo': _Modulo(
      crear: () => MntCorrectivoController(
          model:
              MntCorrectivoModel(sessionId: sessionId, codMetrica: codMetrica))
        ..initCamposEstado(),
      ponerLinealidad: (c, lin) =>
          (c as MntCorrectivoController).linealidadFinal = lin,
      linealidad: (c) => (c as MntCorrectivoController).linealidadFinal,
      reabrir: (c, _) => (c as MntCorrectivoController).restoreSession(),
      columnaCarga: (n) => 'lin_final_$n',
    ),
    'mnt_prv_avanzado': _Modulo(
      crear: () => MntPrvAvanzadoController(
          model:
              MntPrvAvanzadoModel(sessionId: sessionId, codMetrica: codMetrica))
        ..initCamposEstado(),
      ponerLinealidad: (c, lin) => (c as MntPrvAvanzadoController)
        ..linealidadInicial = lin
        ..linealidadFinal = lin,
      linealidad: (c) => (c as MntPrvAvanzadoController).linealidadInicial,
      // Como la pantalla: lee la fila y se la pasa al controlador.
      reabrir: (c, fila) => c.loadExistingSession(sessionId, fila),
      columnaCarga: (n) => 'lin_inicial_$n',
    ),
    'mnt_prv_regular': _Modulo(
      crear: () => MntPrvRegularController(
          model:
              MntPrvRegularModel(sessionId: sessionId, codMetrica: codMetrica))
        ..initCamposEstado(),
      ponerLinealidad: (c, lin) => (c as MntPrvRegularController)
        ..linealidadInicial = lin
        ..linealidadFinal = lin,
      linealidad: (c) => (c as MntPrvRegularController).linealidadInicial,
      reabrir: (c, fila) => c.loadExistingSession(sessionId, fila),
      columnaCarga: (n) => 'lin_inicial_$n',
    ),
    'relevamiento_de_datos': _Modulo(
      crear: () => RelevamientoDeDatosController(
          model: RelevamientoDeDatosModel(
              sessionId: sessionId, codMetrica: codMetrica))
        ..initCamposEstado(),
      ponerLinealidad: (c, lin) =>
          (c as RelevamientoDeDatosController).linealidad = lin,
      linealidad: (c) => (c as RelevamientoDeDatosController).linealidad,
      reabrir: (c, _) => (c as RelevamientoDeDatosController).restoreSession(),
      columnaCarga: (n) => 'lin$n',
    ),
    'verificaciones_internas': _Modulo(
      crear: () => VerificacionesInternasController(
          model: VerificacionesInternasModel(
              sessionId: sessionId, codMetrica: codMetrica))
        ..initCamposEstado(),
      ponerLinealidad: (c, lin) =>
          (c as VerificacionesInternasController).linealidadInicial = lin,
      linealidad: (c) =>
          (c as VerificacionesInternasController).linealidadInicial,
      reabrir: (c, _) =>
          (c as VerificacionesInternasController).restoreSession(),
      columnaCarga: (n) => 'lin_inicial_$n',
    ),
  };

  test('cubre los módulos de soporte con pruebas metrológicas', () {
    // Diagnóstico no tiene pruebas metrológicas.
    expect(
      modulos.keys.toSet(),
      LocalDatabaseCatalog.soporte
          .map((spec) => spec.module)
          .where((m) => m != 'diagnostico')
          .toSet(),
    );
  });

  for (final MapEntry(key: modulo, value: m) in modulos.entries) {
    group(modulo, () {
      BaseSoporteController abrir() {
        final c = m.crear()..secaValue = otst;
        addTearDown(c.dispose);
        return c;
      }

      test('la prueba omitida no deja datos y sigue omitida al reabrir',
          () async {
        final controller = abrir();
        m.ponerLinealidad(controller, cargas(['10', '20']));
        expect(await controller.guardarAhora(), isTrue,
            reason: controller.lastSaveError);
        expect((await fila(modulo))[m.columnaCarga(1)], '10');

        expect(
          await controller.cambiarPrueba(
              () => (controller as dynamic).linealidadRealizada = false),
          isTrue,
          reason: controller.lastSaveError,
        );

        final guardada = await fila(modulo);
        expect(guardada[m.columnaCarga(1)], '');
        expect(guardada[m.columnaCarga(2)], '');
        expect(guardada[PruebasOmitidas.columna], 'linealidad');

        final reabierto = abrir();
        await m.reabrir(reabierto, guardada);
        expect(realizada(reabierto, 'linealidad'), isFalse);
        expect(realizada(reabierto, 'excentricidad'), isTrue);
        expect(realizada(reabierto, 'repetibilidad'), isTrue);

        // La subida no lleva la columna local ni datos de la prueba.
        final datos = buildSupportUploadEnvelopes([
          {...guardada, '_support_module': modulo},
        ]).single['data'] as Map;
        expect(datos, isNot(contains(PruebasOmitidas.columna)));
        expect(datos[m.columnaCarga(1)], '');
      });

      // Antes, en los módulos que lo deducían de los datos, una prueba sin
      // llenar volvía omitida y se podía terminar el servicio sin ella.
      test('una prueba todavía sin llenar sigue activa al reabrir', () async {
        final controller = abrir();
        expect(await controller.guardarAhora(), isTrue,
            reason: controller.lastSaveError);

        final reabierto = abrir();
        await m.reabrir(reabierto, await fila(modulo));
        for (final prueba in ['excentricidad', 'repetibilidad', 'linealidad']) {
          expect(realizada(reabierto, prueba), isTrue, reason: prueba);
        }
      });

      test('reabrir conserva las cargas después de una vacía', () async {
        final controller = abrir();
        m.ponerLinealidad(controller, cargas(['10', '', '30']));
        expect(await controller.guardarAhora(), isTrue,
            reason: controller.lastSaveError);

        final reabierto = abrir();
        await m.reabrir(reabierto, await fila(modulo));
        expect(m.linealidad(reabierto).filas.map((f) => f.carga),
            ['10', '', '30']);

        // Y guardar de nuevo no la borra.
        expect(await reabierto.guardarAhora(), isTrue,
            reason: reabierto.lastSaveError);
        expect((await fila(modulo))[m.columnaCarga(3)], '30');
      });

      test('una fila quitada no deja su valor en la tabla', () async {
        final controller = abrir();
        m.ponerLinealidad(controller, cargas(['10', '20', '30']));
        expect(await controller.guardarAhora(), isTrue);
        m.ponerLinealidad(controller, cargas(['10', '20']));
        expect(await controller.guardarAhora(), isTrue);

        expect((await fila(modulo))[m.columnaCarga(3)], '');
      });
    });
  }

  test('un registro anterior a la columna se lee como antes', () {
    expect(PruebasOmitidas.leer({'lin_inicial_1': '10'}), isNull);
    expect(PruebasOmitidas.leer({PruebasOmitidas.columna: ''}),
        (excentricidad: true, repetibilidad: true, linealidad: true));
    expect(
        PruebasOmitidas.leer(
            {PruebasOmitidas.columna: 'excentricidad,linealidad'}),
        (excentricidad: false, repetibilidad: true, linealidad: false));
  });

  // Instalación y Verificaciones: una repetibilidad de 3 mediciones volvía
  // con 10 y pedía 7 lecturas más para avanzar.
  test('la repetibilidad inicial vuelve con sus mediciones', () {
    final fila = <String, dynamic>{};
    PruebasInicialesColumnas.escribir(
      fila,
      excentricidad: ExcentricidadData(),
      excentricidadRealizada: false,
      repetibilidad: RepetibilidadData(cargas: [
        CargaRepetibilidad(
          carga: '10',
          indicaciones: ['10', '10', '10'],
          retornos: ['0', '0', '0'],
        ),
      ]),
      repetibilidadRealizada: true,
      linealidad: LinealidadData(),
      linealidadRealizada: true,
    );

    final leidas = PruebasInicialesColumnas.leer(fila);
    expect(leidas.repetibilidad.cargas.single.indicaciones, hasLength(3));
    expect(leidas.excentricidadRealizada, isFalse);
    expect(leidas.linealidadRealizada, isTrue);
  });
}

/// Lo que cambia de un módulo a otro para estas pruebas.
class _Modulo {
  const _Modulo({
    required this.crear,
    required this.ponerLinealidad,
    required this.linealidad,
    required this.reabrir,
    required this.columnaCarga,
  });

  final BaseSoporteController Function() crear;
  final void Function(BaseSoporteController c, LinealidadData lin)
      ponerLinealidad;
  final LinealidadData Function(BaseSoporteController c) linealidad;

  /// Como la pantalla al continuar el servicio guardado en [fila].
  final Future<void> Function(
      BaseSoporteController c, Map<String, dynamic> fila) reabrir;

  /// Columna de la carga [n] de la linealidad (inicial, o final si el
  /// módulo solo tiene finales).
  final String Function(int n) columnaCarga;
}
