'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { buildInsertQuery } = require('../src/calibration-service');

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
