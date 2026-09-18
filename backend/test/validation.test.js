'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { loadTableSchema } = require('../src/schema');
const {
  isNewScaleCode,
  summaryServiceStatus,
  validateRecords,
} = require('../src/validation');
const { signJwt, verifyJwt } = require('../src/security');

const schema = loadTableSchema();

test('lee las 426 columnas del esquema de calibración', () => {
  assert.equal(schema.size, 426);
  assert.equal(schema.get('modelo').maxLength, 70);
  assert.equal(schema.get('cap_max1').precision, 15);
  assert.equal(schema.get('cap_max1').scale, 6);
});

test('genera codigo_registro y excluye fotografías', () => {
  const result = validateRecords([{
    seca: '1234',
    cod_metrica: 'ABC-01',
    estado_servicio_bal: 'Balanza Calibrada',
    estado_servicio_csv: 'INACTIVO',
    modelo: 'IND-560',
    vibracion_foto: '/ruta/local/no-transferible.jpg',
  }], schema);
  assert.equal(result.records[0].valid, true);
  assert.equal(result.records[0].codigoRegistro, '1234-ABC-01');
  assert.equal(result.records[0].normalized.tipo_servicio, 'CAL.BL');
  assert.equal(result.records[0].normalized.estado_servicio_csv, 'ACTIVO');
  assert.equal(result.records[0].normalized.vibracion_foto, undefined);
});

test('reporta columna, valor y límite cuando un texto es demasiado largo', () => {
  const result = validateRecords([{
    seca: '1234',
    cod_metrica: 'ABC-01',
    estado_servicio_bal: 'Balanza Calibrada',
    categoria_balanza: '123456',
  }], schema);
  const issue = result.records[0].errors[0];
  assert.equal(issue.column, 'categoria_balanza');
  assert.equal(issue.code, 'MAX_LENGTH');
  assert.match(issue.expected, /5/);
});

test('rechaza decimales que exceden precisión o escala', () => {
  const result = validateRecords([{
    seca: '1234',
    cod_metrica: 'ABC-01',
    estado_servicio_bal: 'Balanza Calibrada',
    cap_max1: '1234567890.1234567',
  }], schema);
  assert.equal(result.records[0].errors[0].code, 'DECIMAL_OVERFLOW');
});

test('normaliza una representación decimal exacta de un entero', () => {
  const result = validateRecords([{
    seca: '1234',
    cod_metrica: 'ABC-01',
    estado_servicio_bal: 'Balanza Calibrada',
    cantidad1: '2.0',
  }], schema);
  assert.equal(result.records[0].valid, true);
  assert.equal(result.records[0].normalized.cantidad1, 2);
});

test('acepta una carga de excentricidad con decimales', () => {
  assert.equal(schema.get('carga').type, 'decimal');
  assert.equal(schema.get('carga').precision, 15);
  assert.equal(schema.get('carga').scale, 6);

  const result = validateRecords([{
    seca: '1234',
    cod_metrica: 'ABC-01',
    estado_servicio_bal: 'Balanza Calibrada',
    carga: '66.65',
  }], schema);
  assert.equal(result.records[0].valid, true);
  assert.equal(result.records[0].normalized.carga, '66.65');
});

test('valida y conserva el nombre lógico del CSV para el resumen', () => {
  const result = validateRecords([{
    seca: '1234',
    cod_metrica: 'ABC-01',
    estado_servicio_bal: 'Balanza Calibrada',
    nombre_csv: '1234_20260810_143433.csv',
  }], schema);

  assert.equal(result.records[0].valid, true);
  assert.equal(result.records[0].nombreCsv, '1234_20260810_143433.csv');
  assert.equal(result.records[0].normalized.nombre_csv, undefined);
});

test('detecta codigo_registro repetido dentro del lote', () => {
  const record = {
    seca: '1234',
    cod_metrica: 'ABC-01',
    estado_servicio_bal: 'Balanza Calibrada',
  };
  const result = validateRecords([record, record], schema);
  assert.equal(result.records[0].valid, false);
  assert.equal(result.records[1].valid, false);
  assert.equal(result.records[1].errors[0].code, 'DUPLICATE_IN_BATCH');
});

test('detecta codigo_registro repetido sin distinguir mayúsculas', () => {
  const result = validateRecords([
    {
      seca: 'seca-100',
      cod_metrica: 'bal-01',
      estado_servicio_bal: 'Balanza Calibrada',
    },
    {
      seca: 'SECA-100',
      cod_metrica: 'BAL-01',
      estado_servicio_bal: 'Balanza Calibrada',
    },
  ], schema);
  assert.equal(result.records[0].valid, false);
  assert.equal(result.records[1].valid, false);
  assert.equal(result.records[0].errors[0].code, 'DUPLICATE_IN_BATCH');
});

test('firma y verifica JWT con expiración', () => {
  const secret = '01234567890123456789012345678901';
  const token = signJwt({ sub: 'tecnico' }, secret, 60);
  assert.equal(verifyJwt(token, secret).sub, 'tecnico');
  assert.throws(() => verifyJwt(token, `${secret}x`));
});

test('identifica el formato unificado de una balanza nueva', () => {
  assert.equal(isNewScaleCode('0004-08-130826113108'), true);
  assert.equal(summaryServiceStatus('0004-08-130826113108'), 'BALANZA NUEVA');
  assert.equal(summaryServiceStatus('0004-08-014'), 'EN OBSERVACION');
});

test('no clasifica como nueva una fecha u hora imposible', () => {
  assert.equal(isNewScaleCode('0004-08-320826113108'), false);
  assert.equal(isNewScaleCode('0004-08-130826256108'), false);
});

test('una balanza nueva conserva el estado normal en la tabla detallada', () => {
  const result = validateRecords([{
    seca: '26-0004-08-C01',
    cod_metrica: '0004-08-130826113108',
    estado_servicio_bal: 'Balanza Calibrada',
  }], schema);

  assert.equal(result.records[0].valid, true);
  assert.equal(
    result.records[0].normalized.estado_servicio_bal,
    'Balanza Calibrada',
  );
  assert.equal(
    summaryServiceStatus(result.records[0].codMetrica),
    'BALANZA NUEVA',
  );
});
