import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:service_met/database/soporte_tecnico/database_helper_instalacion.dart';
import 'package:service_met/database/soporte_tecnico/database_helper_relevamiento.dart';
import 'package:service_met/database/soporte_tecnico/database_helper_verificaciones.dart';
import 'package:service_met/models/service_session.dart';
import 'package:service_met/screens/soporte_new/modulos/instalacion/controllers/instalacion_controller.dart';
import 'package:service_met/screens/soporte_new/modulos/instalacion/models/instalacion_model.dart';
import 'package:service_met/screens/soporte_new/modulos/relevamiento_de_datos/controllers/relevamiento_de_datos_controller.dart';
import 'package:service_met/screens/soporte_new/modulos/relevamiento_de_datos/models/relevamiento_de_datos_model.dart';
import 'package:service_met/screens/soporte_new/modulos/verificaciones_internas/controllers/verificaciones_internas_controller.dart';
import 'package:service_met/screens/soporte_new/modulos/verificaciones_internas/models/verificaciones_internas_model.dart';
import 'package:service_met/screens/soporte_new/utils/pruebas_iniciales_columnas.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _otst = '26-0032-11-S01';
const _sessionId = '0001';
const _codMetrica = '0032-11-020';

ExcentricidadData _excentricidad() => ExcentricidadData(
      tipoPlataforma: 'Rectangular',
      puntosIndicacion: 'Rectangular 3F',
      carga: '50',
      posiciones: [
        for (var i = 1; i <= 3; i++)
          PosicionData(posicion: '$i', indicacion: '50.0', retorno: '0'),
      ],
    );

RepetibilidadData _repetibilidad() => RepetibilidadData(cargas: [
      CargaRepetibilidad(
        carga: '100',
        indicaciones: ['100.0', '100.1', '100.0'],
        retornos: ['0', '0', '0'],
      ),
    ]);

LinealidadData _linealidad() => LinealidadData(filas: [
      FilaLinealidad(carga: '10', indicacion: '10.0', retorno: '0'),
      FilaLinealidad(carga: '20', indicacion: '20.1', retorno: '0'),
    ]);

void main() {
  // Los controladores avisan a la interfaz según la fase del cuadro.
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  Future<void> borrarBases() async {
    await DatabaseHelperVerificaciones().close();
    await DatabaseHelperInstalacion().close();
    await DatabaseHelperRelevamiento().close();
    final dir = await getDatabasesPath();
    await deleteDatabase(p.join(dir, 'verificaciones_internas.db'));
    await deleteDatabase(p.join(dir, 'instalacion.db'));
    await deleteDatabase(p.join(dir, 'relevamiento_de_datos.db'));
  }

  setUp(borrarBases);
  tearDown(borrarBases);

  group('PruebasInicialesColumnas', () {
    test('lo que se escribe se vuelve a leer igual', () {
      final data = <String, dynamic>{};
      PruebasInicialesColumnas.escribir(
        data,
        excentricidad: _excentricidad(),
        excentricidadRealizada: true,
        repetibilidad: _repetibilidad(),
        repetibilidadRealizada: true,
        linealidad: _linealidad(),
        linealidadRealizada: true,
      );

      final leidas = PruebasInicialesColumnas.leer(data);

      expect(leidas.excentricidadRealizada, isTrue);
      expect(leidas.excentricidad.carga, '50');
      expect(leidas.excentricidad.posiciones.map((e) => e.indicacion),
          ['50.0', '50.0', '50.0']);
      expect(leidas.repetibilidadRealizada, isTrue);
      expect(leidas.repetibilidad.cargas.single.carga, '100');
      expect(leidas.repetibilidad.cargas.single.indicaciones.take(3),
          ['100.0', '100.1', '100.0']);
      expect(leidas.linealidadRealizada, isTrue);
      expect(
          leidas.linealidad.filas.map((f) => f.indicacion), ['10.0', '20.1']);
      expect(data['linealidad_inicial_cantidad_puntos'], 2);
    });

    test('una prueba no realizada deja sus casillas vacías', () {
      final data = <String, dynamic>{'lin_inicial_1': '99'};
      PruebasInicialesColumnas.escribir(
        data,
        excentricidad: _excentricidad(),
        excentricidadRealizada: false,
        repetibilidad: _repetibilidad(),
        repetibilidadRealizada: false,
        linealidad: _linealidad(),
        linealidadRealizada: false,
      );

      expect(data['carga_exc_inicial'], '');
      expect(data['repetibilidad1_inicial'], '');
      expect(data['lin_inicial_1'], '');
      final leidas = PruebasInicialesColumnas.leer(data);
      expect(leidas.excentricidadRealizada, isFalse);
      expect(leidas.repetibilidadRealizada, isFalse);
      expect(leidas.linealidadRealizada, isFalse);
    });
  });

  group('continuar un servicio de soporte pendiente', () {
    test(
        'Verificaciones internas recupera las pruebas iniciales, el retorno a '
        'cero y las fotos', () async {
      // Antes volvían vacías: la pantalla pedía otra vez el retorno a cero
      // para avanzar y el autoguardado borraba las pruebas de la base.
      VerificacionesInternasController abrir() {
        final controller = VerificacionesInternasController(
          model: VerificacionesInternasModel(
            sessionId: _sessionId,
            codMetrica: _codMetrica,
          ),
        )
          ..secaValue = _otst
          ..initCamposEstado();
        addTearDown(controller.dispose);
        return controller;
      }

      final original = abrir()
        ..retornoCeroInicial = 'Bueno'
        ..estabilidadInicial = 'Estable'
        ..excentricidadInicial = _excentricidad()
        ..repetibilidadInicial = _repetibilidad()
        ..linealidadInicial = _linealidad();
      original.camposEstado[0]
        ..value = 'Bueno'
        ..fotos = ['/fotos/soporte/001.jpg'];
      original.camposEstado[10]
        ..value = 'Malo'
        ..solutionValue = 'Se ajustó'
        ..fotos = ['/fotos/soporte/002.jpg'];
      await original.guardarSesion();
      expect(original.lastSaveSuccessful, isTrue);

      final continuado = abrir();
      await continuado.restoreSession();

      expect(continuado.retornoCeroInicial, 'Bueno');
      expect(continuado.estabilidadInicial, 'Estable');
      expect(continuado.excentricidadInicial.carga, '50');
      expect(continuado.excentricidadInicial.posiciones, hasLength(3));
      expect(continuado.repetibilidadInicial.cargas.single.carga, '100');
      expect(continuado.linealidadInicial.filas, hasLength(2));
      expect(continuado.camposEstado[0].fotos, ['/fotos/soporte/001.jpg']);
      expect(continuado.camposEstado[10].value, 'Malo');
      expect(continuado.camposEstado[10].solutionValue, 'Se ajustó');
      expect(continuado.camposEstado[10].fotos, ['/fotos/soporte/002.jpg']);
    });

    test('Instalación recupera las fotos de las condiciones', () async {
      InstalacionController abrir() {
        final controller = InstalacionController(
          model: InstalacionModel(
            sessionId: _sessionId,
            codMetrica: _codMetrica,
          ),
        )
          ..secaValue = _otst
          ..initCamposEstado();
        addTearDown(controller.dispose);
        return controller;
      }

      final original = abrir()..linealidadInicial = _linealidad();
      original.camposEstado[1]
        ..value = 'Adecuada'
        ..fotos = ['/fotos/soporte/010.jpg', '/fotos/soporte/011.jpg'];
      await original.guardarSesion();
      expect(original.lastSaveSuccessful, isTrue);

      final continuado = abrir();
      await continuado.restoreSession();

      expect(continuado.camposEstado[1].value, 'Adecuada');
      expect(continuado.camposEstado[1].fotos,
          ['/fotos/soporte/010.jpg', '/fotos/soporte/011.jpg']);
      expect(continuado.linealidadInicial.filas, hasLength(2));
    });

    test(
        'Relevamiento recupera la repetibilidad y cada posición de '
        'excentricidad en su lugar', () async {
      // Antes la repetibilidad volvía vacía y una posición sin indicación
      // corría a las siguientes: al continuar, la pantalla pedía datos que
      // ya estaban escritos o los mostraba en otra posición.
      RelevamientoDeDatosController abrir() {
        final controller = RelevamientoDeDatosController(
          model: RelevamientoDeDatosModel(
            sessionId: _sessionId,
            codMetrica: _codMetrica,
          ),
        )
          ..secaValue = _otst
          ..initCamposEstado();
        addTearDown(controller.dispose);
        return controller;
      }

      final original = abrir()
        ..excentricidad = ExcentricidadData(
          tipoPlataforma: 'Rectangular',
          puntosIndicacion: 'Rectangular 3F',
          carga: '50',
          posiciones: [
            PosicionData(posicion: '1', indicacion: '50.0', retorno: '0'),
            PosicionData(posicion: '2', indicacion: '', retorno: '0'),
            PosicionData(posicion: '3', indicacion: '50.1', retorno: '0'),
          ],
        )
        ..repetibilidad = RepetibilidadData(cargas: [
          CargaRepetibilidad(
            carga: '100',
            indicaciones: ['100.0', '100.1', '100.0', '99.9', '100.0'],
            retornos: ['0', '0', '0', '0', '0'],
          ),
        ]);
      await original.guardarSesion();
      expect(original.lastSaveSuccessful, isTrue);

      final continuado = abrir();
      await continuado.restoreSession();

      final posiciones = continuado.excentricidad.posiciones;
      expect(posiciones.map((e) => e.indicacion), ['50.0', '', '50.1']);
      final repetibilidad = continuado.repetibilidad.cargas.single;
      expect(repetibilidad.carga, '100');
      expect(repetibilidad.indicaciones,
          ['100.0', '100.1', '100.0', '99.9', '100.0']);
      expect(repetibilidad.retornos, ['0', '0', '0', '0', '0']);
    });
  });
}
