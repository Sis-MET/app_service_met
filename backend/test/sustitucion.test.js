'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const {
  addSubstitutionValidation,
  buildSubstitutionInsertQuery,
  normalizeSubstitution,
} = require('../src/sustitucion');

/** Paso como lo envía la app: con los valores de sus filas al subir. */
function paso(numero, fila, metodo, indicacion, referencia, base, record) {
  const cargaReferencia = Number(record[`lin${referencia}`]);
  const indicacionReferencia = Number(record[`ind${referencia}`]);
  const errorReferencia = indicacionReferencia - cargaReferencia;
  return {
    paso: numero,
    fila,
    metodo,
    indicacion_sustitutiva: indicacion,
    fila_referencia: referencia,
    carga_referencia: cargaReferencia,
    indicacion_referencia: indicacionReferencia,
    error_referencia: errorReferencia,
    carga_sustitutiva: indicacion - errorReferencia,
    fila_base: base,
    carga_base: Number(record[`lin${base}`]),
    carga_resultante: Number(record[`lin${fila}`]),
    registrado_en: '2026-11-13T10:15:00-04:00',
  };
}

// Ejemplo 2 del laboratorio, Método 1: E(500) = +0,5. La sustitutiva de 495
// vale 494,5 → 994,5 (indica 995,5, E = +1). La de 1001 vale 1000 y se suma
// a los 500 kg de pesas → 1500.
const metodo1 = {
  metodo_carga: 'Método 1',
  lin1: '500', ind1: '500.5',
  lin2: '994.5', ind2: '995.5',
  lin3: '1500', ind3: '1500.5',
};
const pasosMetodo1 = [
  paso(1, 2, 'M1', 495, 1, 1, metodo1),
  paso(2, 3, 'M1', 1001, 2, 1, metodo1),
];

// Ejemplo del Método 2: E(500) = −0,5; sustitutivas de 495, 502 y 490, cada
// una corregida con E(500) y sumada a la carga anterior.
const metodo2 = {
  metodo_carga: 'Método 2',
  lin1: '500', ind1: '499.5',
  lin2: '995.5', ind2: '995',
  lin3: '1498', ind3: '1497.5',
  lin4: '1988.5', ind4: '1988',
};
const pasosMetodo2 = [
  paso(1, 2, 'M2', 495, 1, 1, metodo2),
  paso(2, 3, 'M2', 502, 1, 2, metodo2),
  paso(3, 4, 'M2', 490, 1, 3, metodo2),
];

test('acepta la cadena del Método 1 con los ejemplos del laboratorio', () => {
  const { pasos, issues } = normalizeSubstitution(pasosMetodo1, metodo1);

  assert.deepEqual(issues, []);
  assert.equal(pasos.length, 2);
  assert.equal(pasos[1].carga_sustitutiva, 1000);
  assert.equal(pasos[1].carga_resultante, 1500);
  assert.equal(pasos[1].filaReferencia, 2);
  assert.equal(pasos[1].filaBase, 1);
  assert.ok(pasos[0].registradoEn instanceof Date);
});

test('acepta la cadena del Método 2 con los ejemplos del laboratorio', () => {
  const { pasos, issues } = normalizeSubstitution(pasosMetodo2, metodo2);

  assert.deepEqual(issues, []);
  assert.deepEqual(pasos.map((p) => p.carga_resultante), [995.5, 1498, 1988.5]);
});

test('sin pasos no hay nada que validar', () => {
  assert.deepEqual(normalizeSubstitution(undefined, metodo1), { pasos: [], issues: [] });
  assert.deepEqual(normalizeSubstitution([], metodo1), { pasos: [], issues: [] });
});

test('rechaza un paso cuya carga no es la registrada en la fila', () => {
  const record = { ...metodo1, lin3: '1994.5' };
  const { pasos, issues } = normalizeSubstitution(pasosMetodo1, record);

  assert.deepEqual(pasos, []);
  assert.ok(issues.some((i) => i.code === 'SUBSTITUTION_MISMATCH'
    && i.column === 'sustituciones[1].carga_resultante'));
});

test('rechaza una carga base que no es la de su fila', () => {
  const pasos = structuredClone(pasosMetodo1);
  pasos[1].carga_base = 994.5;
  const { issues } = normalizeSubstitution(pasos, metodo1);

  assert.ok(issues.some((i) => i.column === 'sustituciones[1].carga_base'));
});

test('admite el redondeo de la carga resultante a los decimales de d', () => {
  const record = { ...metodo1, lin2: '994' }; // d = 1: 994,5 se registró como 994
  const pasos = [paso(1, 2, 'M1', 495, 1, 1, record)];
  pasos[0].carga_sustitutiva = 494.5;
  const { issues } = normalizeSubstitution(pasos, record);

  assert.deepEqual(issues, []);
});

test('exige que el método del paso sea el declarado en metodo_carga', () => {
  const { issues } = normalizeSubstitution(pasosMetodo1, { ...metodo1, metodo_carga: 'Método 2' });

  assert.ok(issues.every((i) => i.code === 'SUBSTITUTION_METHOD_MISMATCH'));
  assert.equal(issues.length, 2);
});

test('en el Método 1 la referencia es la carga anterior', () => {
  // Corregir la segunda sustitutiva con la carga de pesas no es el Método 1.
  const record = { ...metodo1, lin3: '1500.5' };
  const pasos = [pasosMetodo1[0], paso(2, 3, 'M1', 1001, 1, 1, record)];
  const { issues } = normalizeSubstitution(pasos, record);

  assert.ok(issues.some((i) => i.code === 'SUBSTITUTION_METHOD_MISMATCH'
    && i.column === 'sustituciones[1].fila_referencia'));
});

test('en el Método 2 la base es la carga anterior', () => {
  const record = { ...metodo2, lin3: '1002.5' };
  const pasos = [pasosMetodo2[0], paso(2, 3, 'M2', 502, 1, 1, record)];
  const { issues } = normalizeSubstitution(pasos, record);

  assert.ok(issues.some((i) => i.column === 'sustituciones[1].fila_base'));
});

test('rechaza filas fuera de orden, numeración salteada y datos que no son números', () => {
  const pasos = structuredClone(pasosMetodo2);
  pasos[2].paso = 5;
  pasos[1].fila = 2;
  pasos[0].indicacion_sustitutiva = 'abc';
  const { issues } = normalizeSubstitution(pasos, metodo2);
  const columns = issues.map((i) => i.column);

  assert.ok(columns.includes('sustituciones[0].indicacion_sustitutiva'));
  assert.ok(columns.includes('sustituciones[1].fila'));
  assert.ok(columns.includes('sustituciones[2].paso'));
});

test('rechaza un valor que no es una lista', () => {
  const { issues } = normalizeSubstitution({ paso: 1 }, metodo1);
  assert.equal(issues[0].code, 'INVALID_SUBSTITUTION');
});

test('un paso que no concuerda invalida su registro', () => {
  const validation = {
    records: [
      { index: 0, valid: true, errors: [], normalized: metodo1 },
      { index: 1, valid: true, errors: [], normalized: { ...metodo2, lin4: '1990' } },
    ],
    batchErrors: [],
  };
  addSubstitutionValidation(validation, [pasosMetodo1, pasosMetodo2]);

  assert.equal(validation.records[0].valid, true);
  assert.equal(validation.records[0].sustitucion.length, 2);
  assert.equal(validation.records[1].valid, false);
  assert.deepEqual(validation.records[1].sustitucion, []);
});

test('un registro sin pasos no cambia', () => {
  const validation = {
    records: [{ index: 0, valid: true, errors: [], normalized: metodo1 }],
    batchErrors: [],
  };
  addSubstitutionValidation(validation, undefined);

  assert.equal(validation.records[0].valid, true);
  assert.deepEqual(validation.records[0].sustitucion, []);
});

test('el INSERT de los pasos va a su tabla y deja el id al IDENTITY', () => {
  const query = buildSubstitutionInsertQuery();

  assert.match(query, /INSERT INTO \[dbo\]\.\[DATA_SERVICIOS_DATOS_CALIBRACION_SUSTITUCION\]/);
  assert.match(query, /\[calibracion_n\]/);
  assert.match(query, /\[carga_resultante\]/);
  assert.doesNotMatch(query, /\[id\]/);
});
