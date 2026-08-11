'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { BOOTSTRAP_QUERIES, readBootstrap } = require('../src/bootstrap-service');

test('bootstrap incluye todas las tablas necesarias para trabajar offline', () => {
  assert.deepEqual(Object.keys(BOOTSTRAP_QUERIES), [
    'clientes',
    'plantas',
    'balanzas',
    'inf',
    'equipamientos',
    'servicios',
  ]);
});

test('bootstrap devuelve conteos y datos por tabla', async () => {
  const pool = {
    request() {
      return {
        async query(query) {
          return { recordset: [{ query }] };
        },
      };
    },
  };
  const result = await readBootstrap(pool);
  assert.equal(result.schemaVersion, 1);
  assert.equal(result.counts.clientes, 1);
  assert.equal(result.tables.servicios.length, 1);
  assert.ok(result.generatedAt);
});
