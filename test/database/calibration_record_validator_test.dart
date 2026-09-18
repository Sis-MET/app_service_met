import 'package:flutter_test/flutter_test.dart';
import 'package:service_met/database/calibration_record_validator.dart';

void main() {
  group('fieldError', () {
    test('las columnas enteras no admiten decimales; la carga sí', () {
      expect(
        CalibrationRecordValidator.fieldError('cantidad1', '1.5'),
        'debe ser un número entero, sin decimales',
      );
      expect(CalibrationRecordValidator.fieldError('cantidad1', '2'), isNull);
      expect(CalibrationRecordValidator.fieldError('carga', '66.65'), isNull);
      expect(CalibrationRecordValidator.isIntegerColumn('cantidad1'), isTrue);
      expect(CalibrationRecordValidator.isIntegerColumn('carga'), isFalse);
      expect(CalibrationRecordValidator.isIntegerColumn('lin1'), isFalse);
    });

    test('un campo vacío no es un error mientras se escribe', () {
      expect(CalibrationRecordValidator.fieldError('hri', ''), isNull);
    });

    test('explica la precisión de la columna decimal', () {
      expect(
        CalibrationRecordValidator.fieldError('indicacion1', '1.1234567'),
        'admite hasta 6 cifras enteras y 6 decimales',
      );
      expect(
        CalibrationRecordValidator.fieldError('ti', '-'),
        'no es un número válido',
      );
    });
  });

  test('lista todo lo que el guardado rechazaría, con nombre de pantalla', () {
    final issues = CalibrationRecordValidator.schemaIssues({
      'hri': '45.2',
      'carga': '66.65',
      'indicacion2_3': 'abc',
      'factor': '1.5',
      'n_celdas': '4 celdas',
      'rango': 'Multi intervalo',
      'vibracion_foto': '/una/ruta/muy/larga/que/no/va/al/servidor.jpg',
    });

    // Por paso del asistente y, dentro de un paso, en el orden de pantalla.
    expect(issues.map((issue) => issue.toString()), [
      'Instrumento › N° Celdas: debe ser un número entero, sin decimales',
      'Instrumento › Rango: admite hasta 10 caracteres (tiene 15)',
      'Repetibilidad › Carga 2, medición 3: indicación: '
          'no es un número válido',
      'Certificado › Factor de seguridad: '
          'debe ser un número entero, sin decimales',
    ]);
    expect(issues.map((issue) => issue.step), [3, 3, 7, 10]);
  });

  test('nombra cada casilla de las pruebas como se ve en pantalla', () {
    String label(String column) =>
        CalibrationRecordValidator.labelFor(column).label;

    expect(label('p_indicador2'), 'Precargas › Indicación 2');
    expect(label('retorno4'), 'Excentricidad › Posición 4: retorno');
    expect(label('repetibilidad3'), 'Repetibilidad › Carga 3');
    expect(label('lin12'), 'Linealidad › Carga 12: carga real');
    expect(label('retorno_lin3'), 'Linealidad › Carga 3: retorno a cero');
    expect(label('dec2'), 'Rango 2 › Dec.');
    expect(
        label('estado6'), 'Instrumentos de medición › Instrumento 1: estado');
    expect(
        label('vibracion_comentario'), 'Inspección › Vibración (comentario)');
    expect(label('hri_fin'), 'Condiciones finales › HRi fin');
  });

  group('missingTests', () {
    final completo = <String, dynamic>{
      'precarga1': '10',
      'ti': '20',
      'hri': '45',
      'patmi': '1013',
      'carga': '67',
      'indicacion1': '67.0',
      'repetibilidad1': '100',
      'indicacion1_1': '100.0',
      'lin1': '50',
      'ind1': '50.0',
      'ti_fin': '21',
      'hri_fin': '44',
      'patmi_fin': '1012',
    };

    test('un registro completo no tiene faltantes', () {
      expect(CalibrationRecordValidator.missingTests(completo), isEmpty);
    });

    test('señala las pruebas que no quedaron en la base', () {
      final sinPruebas = Map<String, dynamic>.from(completo)
        ..['indicacion1_1'] = ''
        ..remove('ind1')
        ..['hri_fin'] = null;

      expect(CalibrationRecordValidator.missingTests(sinPruebas), [
        'Repetibilidad',
        'Linealidad',
        'Condiciones ambientales finales',
      ]);
    });
  });
}
