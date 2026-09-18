'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { loadSupportSchemas, SUPPORT_MODULES } = require('../src/schema');
const {
  buildSummaryInsertQuery,
  logicalCsvName,
  supportRegistrationCode,
  validateSupportRecords,
} = require('../src/support-service');

const schemas = loadSupportSchemas();
const installationCommentColumns = [
  'entorno_comentario',
  'nivelacion_comentario',
  'movilizacion_comentario',
  'flujo_pesadas_comentario',
  'superficie_apoyo_comentario',
  'tension_red_comentario',
  'sistema_tierra_comentario',
  'comunicacion_pc_comentario',
  'vibracion_externa_comentario',
  'comentario_general',
];

test('carga los esquemas de los ocho módulos de soporte', () => {
  assert.equal(schemas.size, 8);
  for (const [module, definition] of Object.entries(SUPPORT_MODULES)) {
    assert.equal(schemas.get(module).size, definition.columns);
    assert.equal(schemas.get(module).get('session_id').maxLength, 30);
    assert.equal(schemas.get(module).get('comentario_general').maxLength, 1000);
    for (const column of ['puntos_ind', 'puntos_ind_inicial', 'puntos_ind_final']) {
      const field = schemas.get(module).get(column);
      if (!field) continue;
      assert.equal(field.type, 'nvarchar');
      assert.equal(field.maxLength, 50);
    }
  }
  for (const column of installationCommentColumns) {
    assert.equal(schemas.get('instalacion').get(column).type, 'nvarchar');
    assert.equal(schemas.get('instalacion').get(column).maxLength, 1000);
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
  assert.equal(
    result.records.every(
      (record) => record.normalized.estado_servicio_csv === 'ACTIVO',
    ),
    true,
  );
  assert.equal(result.records[0].codigoRegistro, 'OTST-1-IBM.BL-MET-1');
});

test('ignora el estado CSV recibido y siempre lo reemplaza por ACTIVO', () => {
  const result = validateSupportRecords(
    [{
      module: 'mnt_prv_regular',
      data: {
        otst: 'OTST-ACTIVO',
        cod_metrica: 'MET-ACTIVO',
        estado_servicio: 'Completo',
        estado_servicio_csv: 'INACTIVO',
      },
    }],
    schemas,
  );

  assert.equal(result.records[0].valid, true);
  assert.equal(result.records[0].normalized.estado_servicio_csv, 'ACTIVO');
});

test('genera codigo_registro con el código específico de cada módulo', () => {
  const expected = {
    ajuste_verificaciones: 'IBM.BL',
    diagnostico: 'DIG.BL',
    instalacion: 'INS.BL',
    mnt_correctivo: 'MCR.BL',
    mnt_prv_avanzado: 'MPA.SP',
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

test('el resumen de soporte incluye el tipo de servicio abreviado', () => {
  const query = buildSummaryInsertQuery();
  assert.match(query, /INSERT INTO \[dbo\]\.\[DATA_SERVICIOS_DATOS\]/);
  assert.match(query, /\[tipo_servicio\]/);
  assert.match(query, /@tipoServicio/);
});

test('la API reemplaza una sigla antigua por la oficial del módulo', () => {
  const result = validateSupportRecords(
    [{
      module: 'mnt_prv_avanzado',
      data: {
        otst: '26-0090-11-S02',
        cod_metrica: '0090-11-014',
        estado_servicio: 'Completo',
        tipo_servicio: 'MPA.STAC',
      },
    }],
    schemas,
  );

  assert.equal(result.records[0].valid, true);
  assert.equal(result.records[0].normalized.tipo_servicio, 'MPA.SP');
  assert.equal(result.records[0].normalized.estado_servicio, 'Completo');
  assert.equal(
    result.records[0].codigoRegistro,
    '26-0090-11-S02-MPA.SP-0090-11-014',
  );
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

test('normaliza DD-MM-AAAA en cada fecha real de los ocho módulos', () => {
  const dateColumnsByModule = {
    ajuste_verificaciones: ['fecha_servicio', 'fecha_prox_servicio'],
    diagnostico: ['fecha_servicio'],
    instalacion: ['fecha_servicio', 'fecha_prox_servicio'],
    mnt_correctivo: ['fecha_servicio', 'fecha_prox_servicio'],
    mnt_prv_avanzado: ['fecha_servicio', 'fecha_prox_servicio'],
    mnt_prv_regular: ['fecha_servicio', 'fecha_prox_servicio'],
    relevamiento_de_datos: ['fecha_servicio', 'fecha_prox_servicio'],
    verificaciones_internas: ['fecha_servicio', 'fecha_prox_servicio'],
  };

  for (const [index, [module, dateColumns]] of Object.entries(dateColumnsByModule).entries()) {
    const data = {
      otst: `OTST-FECHA-${index}`,
      cod_metrica: `MET-FECHA-${index}`,
      estado_servicio:
        module === 'relevamiento_de_datos' ? 'Balanza Realizada' : 'Completo',
      ...(module === 'diagnostico'
        ? {
            reporte: 'Falla',
            evaluacion: 'Evaluada',
            comentario_general: 'Resultado',
            hora_fin: '10:30',
          }
        : {}),
    };
    for (const column of dateColumns) data[column] = '12-08-2026';

    const record = validateSupportRecords([{ module, data }], schemas).records[0];
    assert.equal(record.valid, true, module);
    for (const column of dateColumns) {
      assert.equal(record.normalized[column], '2026-08-12', `${module}.${column}`);
    }
  }
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

test('acepta etiquetas alfanuméricas en puntos_ind y omite columnas legacy de MPA', () => {
  const result = validateSupportRecords(
    [{
      module: 'mnt_prv_avanzado',
      data: {
        otst: 'OTST-MPA',
        cod_metrica: 'MET-MPA',
        estado_servicio: 'Completo',
        puntos_ind_inicial: '8F',
        puntos_ind_final: '8F',
        retorno_cero_inicial_unidad: 'kg',
        retorno_cero_final_unidad: 'kg',
      },
    }],
    schemas,
  );

  assert.equal(result.records[0].valid, true);
  assert.equal(result.records[0].normalized.puntos_ind_inicial, '8F');
  assert.equal(result.records[0].normalized.puntos_ind_final, '8F');
  assert.equal('retorno_cero_inicial_unidad' in result.records[0].normalized, false);
  assert.equal('retorno_cero_final_unidad' in result.records[0].normalized, false);
});

test('valida el nombre de puntos de indicador propio de cada módulo', () => {
  const indicatorColumnsByModule = {
    ajuste_verificaciones: [],
    diagnostico: [],
    instalacion: ['puntos_ind_inicial'],
    mnt_correctivo: ['puntos_ind_final'],
    mnt_prv_avanzado: ['puntos_ind_inicial', 'puntos_ind_final'],
    mnt_prv_regular: ['puntos_ind_inicial', 'puntos_ind_final'],
    relevamiento_de_datos: ['puntos_ind'],
    verificaciones_internas: ['puntos_ind_inicial'],
  };

  for (const [module, columns] of Object.entries(indicatorColumnsByModule)) {
    for (const column of columns) {
      const definition = schemas.get(module).get(column);
      assert.ok(definition, `${module}.${column}`);
      assert.equal(definition.type, 'nvarchar', `${module}.${column}`);
      assert.equal(definition.maxLength, 50, `${module}.${column}`);
    }
  }
});

test('normaliza etiquetas legacy de posición cuando SQL Server espera enteros', () => {
  const cases = [
    ['instalacion', 'posicion_inicial_1', 'Posición 1', 1],
    ['mnt_correctivo', 'posicion_final_1', 'Posicion 2', 2],
    ['mnt_prv_regular', 'posicion_inicial_1', '3', 3],
    ['relevamiento_de_datos', 'posicion1', 'Ida 4', 4],
    ['verificaciones_internas', 'posicion_inicial_1', 'Vuelta 5', 5],
    ['ajuste_verificaciones', 'excentricidad_inicial_pos1_numero', 'Posición 6', 6],
  ];

  for (const [index, [module, column, value, expected]] of cases.entries()) {
    const data = {
      otst: `OTST-POS-${index}`,
      cod_metrica: `MET-POS-${index}`,
      estado_servicio:
        module === 'relevamiento_de_datos' ? 'Balanza Realizada' : 'Completo',
      [column]: value,
    };
    const record = validateSupportRecords([{ module, data }], schemas).records[0];
    assert.equal(record.valid, true, `${module}.${column}`);
    assert.equal(record.normalized[column], expected, `${module}.${column}`);
  }
});

test('comentario_general admite 1000 caracteres en los ocho módulos', () => {
  for (const [index, module] of Object.keys(SUPPORT_MODULES).entries()) {
    const completeData = {
      otst: `OTST-${index}`,
      cod_metrica: `MET-${index}`,
      estado_servicio:
        module === 'relevamiento_de_datos' ? 'Balanza Realizada' : 'Completo',
      comentario_general: 'C'.repeat(1000),
      ...(module === 'diagnostico'
        ? { reporte: 'Falla', evaluacion: 'Evaluada', hora_fin: '10:30' }
        : {}),
    };
    const accepted = validateSupportRecords(
      [{ module, data: completeData }],
      schemas,
    );
    assert.equal(accepted.records[0].valid, true, module);

    const rejected = validateSupportRecords(
      [{
        module,
        data: { ...completeData, comentario_general: 'C'.repeat(1001) },
      }],
      schemas,
    );
    assert.equal(
      rejected.records[0].errors.some(
        (error) => error.column === 'comentario_general'
          && error.code === 'MAX_LENGTH',
      ),
      true,
      module,
    );
  }
});

test('todos los comentarios de instalación admiten hasta 1000 caracteres', () => {
  for (const [index, column] of installationCommentColumns.entries()) {
    const completeData = {
      otst: `OTST-INS-COM-${index}`,
      cod_metrica: `MET-INS-COM-${index}`,
      estado_servicio: 'Completo',
      [column]: 'C'.repeat(1000),
    };
    const accepted = validateSupportRecords(
      [{ module: 'instalacion', data: completeData }],
      schemas,
    );
    assert.equal(accepted.records[0].valid, true, column);

    const rejected = validateSupportRecords(
      [{
        module: 'instalacion',
        data: { ...completeData, [column]: 'C'.repeat(1001) },
      }],
      schemas,
    );
    assert.equal(
      rejected.records[0].errors.some(
        (error) => error.column === column && error.code === 'MAX_LENGTH',
      ),
      true,
      column,
    );
  }
});
