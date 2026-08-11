'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { loadSupportSchemas, SUPPORT_MODULES } = require('../src/schema');
const {
  logicalCsvName,
  supportRegistrationCode,
  validateSupportRecords,
} = require('../src/support-service');

const schemas = loadSupportSchemas();

test('carga los esquemas de los ocho módulos de soporte', () => {
  assert.equal(schemas.size, 8);
  for (const [module, definition] of Object.entries(SUPPORT_MODULES)) {
    assert.equal(schemas.get(module).size, definition.columns);
    assert.equal(schemas.get(module).get('session_id').maxLength, 30);
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
  assert.equal(result.records[0].codigoRegistro, 'OTST-1-IBM.BL-MET-1');
});

test('genera codigo_registro con el código específico de cada módulo', () => {
  const expected = {
    ajuste_verificaciones: 'IBM.BL',
    diagnostico: 'DIG.BL',
    instalacion: 'INS.BL',
    mnt_correctivo: 'MCR.BL',
    mnt_prv_avanzado: 'MPA.STAC',
    mnt_prv_regular: 'MPR.BL',
    relevamiento_de_datos: 'REL.BL',
    verificaciones_internas: 'VIN.SP',
  };

  for (const [module, serviceCode] of Object.entries(expected)) {
    assert.equal(
      supportRegistrationCode(module, '26-0090-11-S02', '0090-11-014'),
      `26-0090-11-S02-${serviceCode}-0090-11-014`,
    );
  }
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

test('acepta session_id de hasta 30 caracteres y normaliza fecha DD/MM/AAAA', () => {
  const sessionId = 'SOP_1723382400000_1234';
  const result = validateSupportRecords(
    [{
      module: 'mnt_prv_regular',
      data: {
        otst: 'OTST-20',
        cod_metrica: 'MET-20',
        estado_servicio: 'Completo',
        session_id: sessionId,
        fecha_prox_servicio: '11/08/2027',
      },
    }],
    schemas,
  );

  assert.equal(result.records[0].valid, true);
  assert.equal(result.records[0].normalized.session_id, sessionId);
  assert.equal(result.records[0].normalized.fecha_prox_servicio, '2027-08-11');
});

test('rechaza una fecha inexistente aunque tenga un formato admitido', () => {
  const result = validateSupportRecords(
    [{
      module: 'mnt_prv_regular',
      data: {
        otst: 'OTST-21',
        cod_metrica: 'MET-21',
        estado_servicio: 'Completo',
        fecha_prox_servicio: '31/02/2027',
      },
    }],
    schemas,
  );

  assert.equal(
    result.records[0].errors.some((error) => error.code === 'INVALID_DATE'),
    true,
  );
});

test('rechaza session_id cuando supera los 30 caracteres', () => {
  const result = validateSupportRecords(
    [{
      module: 'mnt_prv_regular',
      data: {
        otst: 'OTST-22',
        cod_metrica: 'MET-22',
        estado_servicio: 'Completo',
        session_id: 'S'.repeat(31),
      },
    }],
    schemas,
  );

  assert.equal(
    result.records[0].errors.some(
      (error) => error.column === 'session_id' && error.code === 'MAX_LENGTH',
    ),
    true,
  );
});
