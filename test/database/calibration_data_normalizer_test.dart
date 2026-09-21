import 'package:flutter_test/flutter_test.dart';
import 'package:service_met/database/calibration_data_normalizer.dart';
import 'package:service_met/database/calibration_server_schema.dart';
import 'package:service_met/models/service_session.dart';

void main() {
  test('el esquema generado contiene las 426 columnas del servidor', () {
    expect(calibrationServerSchema, hasLength(426));
    expect(
        calibrationServerSchema['cantidad1']?.type, CalibrationSqlType.integer);
    expect(calibrationServerSchema['modelo']?.maxLength, 70);
    expect(calibrationServerSchema['cap_max1']?.precision, 15);
    expect(calibrationServerSchema['cap_max1']?.scale, 6);
  });

  test('la carga de excentricidad es decimal, como la capacidad', () {
    // sql/011_expand_excentricidad_carga.sql la cambió de int a decimal(15,6).
    final carga = calibrationServerSchema['carga'];
    expect(carga?.type, CalibrationSqlType.decimal);
    expect(carga?.precision, 15);
    expect(carga?.scale, 6);

    final result = CalibrationDataNormalizer.normalizeRecord({
      'carga': '66.650',
    });
    expect(result['carga'], '66.65');
  });

  test('convierte 2.0 al entero 2', () {
    final result = CalibrationDataNormalizer.normalizeRecord({
      'cantidad1': '2.0',
    });

    expect(result['cantidad1'], 2);
    expect(result['cantidad1'], isA<int>());
  });

  test('rechaza un entero con fracción distinta de cero', () {
    expect(
      () => CalibrationDataNormalizer.normalizeRecord({'cantidad1': '2.5'}),
      throwsA(
        isA<CalibrationDataException>().having(
          (error) => error.code,
          'code',
          'INVALID_INTEGER',
        ),
      ),
    );
  });

  test('aplica longitud máxima de SQL Server', () {
    expect(
      () => CalibrationDataNormalizer.normalizeRecord({
        'categoria_balanza': '123456',
      }),
      throwsA(
        isA<CalibrationDataException>().having(
          (error) => error.code,
          'code',
          'MAX_LENGTH',
        ),
      ),
    );
  });

  test('conserva rutas de fotos localmente y no las envía al servidor', () {
    final longPath =
        '/ruta/local/${List.filled(20, 'segmento/').join()}foto.jpg';

    final local = CalibrationDataNormalizer.normalizeRecord({
      'vibracion_foto': longPath,
      'cantidad1': '2.0',
    });
    final upload = CalibrationDataNormalizer.normalizeForUpload({
      'vibracion_foto': longPath,
      'foto_balanza': longPath,
      'cantidad1': '2.0',
    });

    expect(local['vibracion_foto'], longPath);
    expect(upload.containsKey('vibracion_foto'), isFalse);
    expect(upload.containsKey('foto_balanza'), isFalse);
    expect(upload['cantidad1'], 2);
  });

  test('las rutas de las fotos de la calibración nunca se suben', () {
    final record = ServiceSession(
      sessionInfo: SessionInfo(seca: '0032-11-C01-26', sessionId: '0001'),
      metadata: SessionMetadata(),
      balanza: BalanzaInfo(fotosPaths: ['/fotos/001.jpg']),
      linealidad: LinealidadData(fotosPaths: ['/fotos/002.jpg']),
      condicionesFinales:
          CondicionesFinales(fotosFinalesPaths: ['/fotos/003.jpg']),
    ).toMap();

    final local = CalibrationDataNormalizer.normalizeRecord(record);
    final upload = CalibrationDataNormalizer.normalizeForUpload(record);

    for (final column in [
      ServiceSession.fotosBalanzaColumn,
      ServiceSession.fotosLinealidadColumn,
      ServiceSession.fotosFinalesColumn,
    ]) {
      expect(local[column], contains('.jpg'), reason: column);
      expect(upload.containsKey(column), isFalse, reason: column);
    }
  });

  test('normaliza decimales sin perder precisión en punto flotante', () {
    final result = CalibrationDataNormalizer.normalizeRecord({
      'cap_max1': '0002100,500000',
    });

    expect(result['cap_max1'], '2100.5');
    expect(result['cap_max1'], isA<String>());
  });

  test('conserva el nombre lógico del CSV solo para el resumen', () {
    final result = CalibrationDataNormalizer.normalizeForUpload({
      'cantidad1': '2.0',
      'nombre_csv': 'SECA-01_20260810_143433.csv',
      'finalized_at': '2026-08-10T14:34:33',
    });

    expect(result['cantidad1'], 2);
    expect(result['nombre_csv'], 'SECA-01_20260810_143433.csv');
    expect(result.containsKey('finalized_at'), isFalse);
  });
}
