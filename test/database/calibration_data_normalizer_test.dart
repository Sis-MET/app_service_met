import 'package:flutter_test/flutter_test.dart';
import 'package:service_met/database/calibration_data_normalizer.dart';
import 'package:service_met/database/calibration_server_schema.dart';

void main() {
  test('el esquema generado contiene las 426 columnas del servidor', () {
    expect(calibrationServerSchema, hasLength(426));
    expect(calibrationServerSchema['carga']?.type, CalibrationSqlType.integer);
    expect(calibrationServerSchema['modelo']?.maxLength, 70);
    expect(calibrationServerSchema['cap_max1']?.precision, 15);
    expect(calibrationServerSchema['cap_max1']?.scale, 6);
  });

  test('convierte 2100.0 al entero 2100', () {
    final result = CalibrationDataNormalizer.normalizeRecord({
      'carga': '2100.0',
    });

    expect(result['carga'], 2100);
    expect(result['carga'], isA<int>());
  });

  test('rechaza una carga con fracción distinta de cero', () {
    expect(
      () => CalibrationDataNormalizer.normalizeRecord({'carga': '2100.5'}),
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
      'carga': '2100.0',
    });
    final upload = CalibrationDataNormalizer.normalizeForUpload({
      'vibracion_foto': longPath,
      'foto_balanza': longPath,
      'carga': '2100.0',
    });

    expect(local['vibracion_foto'], longPath);
    expect(upload.containsKey('vibracion_foto'), isFalse);
    expect(upload.containsKey('foto_balanza'), isFalse);
    expect(upload['carga'], 2100);
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
      'carga': '2100.0',
      'nombre_csv': 'SECA-01_20260810_143433.csv',
      'finalized_at': '2026-08-10T14:34:33',
    });

    expect(result['carga'], 2100);
    expect(result['nombre_csv'], 'SECA-01_20260810_143433.csv');
    expect(result.containsKey('finalized_at'), isFalse);
  });
}
