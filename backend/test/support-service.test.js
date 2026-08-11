'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { loadSupportSchemas, SUPPORT_MODULES } = require('../src/schema');
const { logicalCsvName, validateSupportRecords } = require('../src/support-service');

const schemas = loadSupportSchemas();

test('carga los esquemas de los ocho módulos de soporte', () => {
  assert.equal(schemas.size, 8);
  for (const [module, definition] of Object.entries(SUPPORT_MODULES)) {
    assert.equal(schemas.get(module).size, definition.columns);
  }
});

test('valida un registro completo de cada módulo', () => {
  const records = Object.keys(SUPPORT_MODULES).map((module, index) => ({
    module,
    data: {
      otst: `OTST-${index + 1}`,
      cod_metrica: `MET-${index + 1}`,
      fecha_servicio: '2026-08-11',
      estado_servicio:
        module === 'relevamiento_de_datos' ? 'Balanza Realizada' : 'Completo',
      ...(module === 'diagnostico'
        ? {
            reporte: 'Falla reportada',
            evaluacion: 'Evaluación realizada',
            comentario_general: 'Diagnóstico final',
            hora_fin: '10:30',
          }
        : {}),
    },
  }));

  const result = validateSupportRecords(records, schemas);
  assert.equal(result.records.length, 8);
  assert.equal(result.records.every((record) => record.valid), true);
  assert.equal(result.records[0].codigoRegistro, 'OTST-1-MET-1');
});

test('rechaza un servicio incompleto y una columna demasiado larga', () => {
  const result = validateSupportRecords(
    [{
      module: 'diagnostico',
      data: {
        otst: 'OTST-1',
        cod_metrica: 'MET-1',
        cliente: 'X'.repeat(51),
      },
    }],
    schemas,
  );
  const codes = result.records[0].errors.map((error) => error.code);
  assert.ok(codes.includes('INCOMPLETE_SERVICE'));
  assert.ok(codes.includes('MAX_LENGTH'));
});

test('valida el límite del codigo_registro generado', () => {
  const result = validateSupportRecords(
    [{
      module: 'diagnostico',
      data: {
        otst: 'O'.repeat(30),
        cod_metrica: 'M'.repeat(30),
        reporte: 'Falla',
        evaluacion: 'Evaluada',
        comentario_general: 'Resultado',
        hora_fin: '10:30',
      },
    }],
    schemas,
  );
  assert.equal(
    result.records[0].errors.some(
      (error) => error.column === 'codigo_registro' && error.code === 'MAX_LENGTH',
    ),
    true,
  );
});

test('genera un nombre CSV lógico sin transferir archivos', () => {
  assert.equal(
    logicalCsvName('mnt_correctivo', {
      otst: 'OTST-10',
      session_id: '0002',
      nombre_zip: 'respaldo.zip',
    }),
    'respaldo.csv',
  );
});
