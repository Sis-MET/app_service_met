'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const {
  buildInsertQuery,
  buildSummaryInsertQuery,
} = require('../src/calibration-service');

test('el INSERT omite n explícito y recupera el IDENTITY asignado', () => {
  const query = buildInsertQuery(
    ['[codigo_registro]', '[carga]'],
    ['@p0', '@p1'],
  );

  assert.match(query, /INSERT INTO \[dbo\]\.\[DATA_SERVICIOS_DATOS_CALIBRACION\]/);
  assert.match(query, /\(\[codigo_registro\],\[carga\]\)/);
  assert.doesNotMatch(query, /INSERT[^;]*\[n\]/s);
  assert.match(query, /SCOPE_IDENTITY\(\)/);
});

test('el resumen omite su identity y recupera la asignada', () => {
  const query = buildSummaryInsertQuery();

  assert.match(query, /INSERT INTO \[dbo\]\.\[DATA_SERVICIOS_DATOS\]/);
  assert.doesNotMatch(query, /INSERT[^;]*\[n\]/s);
  assert.match(query, /\[estado_servicio\]/);
  assert.match(query, /\[tipo_servicio\]/);
  assert.match(query, /@tipoServicio/);
  assert.match(query, /SCOPE_IDENTITY\(\)/);
});
