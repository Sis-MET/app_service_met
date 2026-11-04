'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { createApp } = require('../src/app');
const { signJwt } = require('../src/security');
const { readBitrixConfig } = require('../src/bitrix/bitrix-config');
const {
  scheduledReadings,
  validateTemperatura,
} = require('../src/temperatura/temperatura-validation');
const {
  COLUMNS,
  MAX_PARAMETERS,
  TABLES,
  buildInserts,
  createTemperaturaService,
  translate,
} = require('../src/temperatura/temperatura-service');

const UUID = '3f2b8c1e-4a5d-4e6f-9a1b-2c3d4e5f6a7b';

function registro(overrides = {}) {
  const lecturas = [];
  for (let n = 0; n < 3; n += 1) {
    lecturas.push({
      n_punto: 1, n_lectura: n, n_canal: 1, tiempo_programado_s: n * 30,
      capturada_en: `2026-10-29T09:0${n}:00.250-04:00`,
      valor: 300 + n / 10, valor_original: 300 + n / 10, texto_leido: `30${n}.0`,
      origen: 'ocr_segmentos', coincidencia: 0.8, cuadros: 5, alerta: null,
      estado: 'valida', motivo: null,
    });
    lecturas.push({
      n_punto: 1, n_lectura: n, n_canal: 2, tiempo_programado_s: n * 30,
      capturada_en: `2026-10-29T09:0${n}:01.000-04:00`,
      valor: null, valor_original: null, texto_leido: null,
      origen: 'sin_lectura', coincidencia: null, cuadros: null, alerta: null,
      estado: 'sin_lectura', motivo: 'No se pudo leer el display',
    });
  }
  return {
    uuid: UUID,
    codigo_registro: '0032-11-C01-26-0032-11-090',
    seca: '0032-11-C01-26',
    session_id: 'TE20261029090000',
    estado: 'finalizado',
    cod_metrica: '0032-11-090',
    equipo_nuevo: false,
    cliente: 'Lab Andino',
    cod_planta: '0032-11',
    tipo_equipo: 'Mufla',
    rango_min: 100,
    rango_max: 1100,
    unidad: '°C',
    resolucion: 1,
    temp_amb_inicio: 21.5,
    hr_inicio: 40,
    temp_amb_fin: 22,
    hr_fin: 41,
    fecha_servicio: '2026-10-29',
    hora_inicio: '2026-10-29T08:50:00-04:00',
    hora_fin: '2026-10-29T10:00:00-04:00',
    finalizado_en: '2026-10-29T10:00:00-04:00',
    personal: 'jperez',
    app_version: '6.5.0+20',
    gps: { latitud: -16.5, longitud: -68.15, precision_gps: 8, fecha_gps: '2026-10-29T08:50:00-04:00' },
    patrones: [{ n: 1, cod_instrumento: 'TM-001', instrumento: 'Termómetro', uso: 'temperatura' }],
    canales: [
      { n_canal: 1, nombre: 'Patrón · Centro', rol: 'patron', cod_patron: 'TM-001', posicion: 'Centro', metodo: 'camara', decimales: 1 },
      { n_canal: 2, nombre: 'Indicador del equipo', rol: 'equipo', metodo: 'camara', decimales: 0 },
    ],
    puntos: [{
      n_punto: 1, temperatura_nominal: 300, estabilizacion_min: 30, duracion_min: 1,
      intervalo_s: 30, lecturas_programadas: 3, estado: 'completo',
      inicio_medicion: '2026-10-29T09:00:00.000-04:00', fin_medicion: '2026-10-29T09:01:00.000-04:00',
    }],
    lecturas,
    correcciones: [{
      n_punto: 1, n_lectura: 1, n_canal: 1, tipo: 'exclusion', valor_anterior: 300.1,
      valor_nuevo: 300.1, motivo: 'Se abrió la puerta', usuario: 'jperez',
      fecha: '2026-10-29T09:30:00-04:00',
    }],
    ...overrides,
  };
}

/** Transacción falsa: registra las consultas y responde según [answers]. */
function fakeTransaction(answers = {}) {
  const queries = [];
  let committed = false;
  async function transaction(work) {
    const exec = async (text, params) => {
      queries.push({ text, params });
      if (text.includes('sp_getapplock')) return [{ lockResult: 0 }];
      if (text.includes('OBJECT_ID')) return [{ id: answers.ready === false ? null : 1 }];
      if (text.includes(`FROM ${TABLES.header} WHERE [uuid]`)) return answers.existing ? [{ n: 41 }] : [];
      if (text.includes('AS [taken]')) return [{ taken: answers.taken ? 1 : 0 }];
      if (text.includes('[data_users]')) return answers.noUser ? [] : [{ titulo_abr: 'Ing.', nombre1: 'Juan', apellido1: 'Pérez' }];
      if (text.includes(`INSERT INTO ${TABLES.header}`)) return [{ n: 42 }];
      if (text.includes('COL_LENGTH')) return [{ ok: 1 }];
      if (text.includes(`INSERT INTO ${TABLES.summary}`)) return [{ n: 900 }];
      return [];
    };
    const result = await work(exec);
    committed = true;
    return result;
  }
  return { transaction, queries, get committed() { return committed; } };
}

test('un registro completo es válido', () => {
  const { issues, value } = validateTemperatura(registro());
  assert.deepEqual(issues, []);
  assert.equal(value.lecturas.length, 6);
  assert.equal(value.header.uuid, UUID);
});

test('acepta las lecturas de la aguja de un indicador analógico', () => {
  const body = registro({ indicador: 'Analógico' });
  for (const lectura of body.lecturas.filter((l) => l.n_canal === 1)) {
    lectura.origen = 'ocr_aguja';
    lectura.texto_leido = 'aguja 300.04 · 41.7° · escala 0/600/1200';
  }
  const { issues, value } = validateTemperatura(body);
  assert.deepEqual(issues, []);
  assert.equal(value.lecturas[0].origen, 'ocr_aguja');
  body.lecturas[0].origen = 'aguja';
  assert.match(validateTemperatura(body).issues[0].field, /origen/);
});

test('los sensores que graban en su software no llevan lecturas', () => {
  const body = registro({ registro_sensores: 'Registrador 12 · archivo M0091.csv' });
  body.canales.push({
    n_canal: 3, nombre: 'T1', rol: 'patron', cod_patron: 'TM-001',
    posicion: 'Centro', metodo: 'externo', decimales: 1,
  });
  assert.deepEqual(validateTemperatura(body).issues, []);
  body.lecturas.push({ ...body.lecturas[0], n_canal: 3 });
  const issues = validateTemperatura(body).issues;
  assert.equal(issues.length, 1);
  assert.match(issues[0].message, /graba en su software/);
});

test('lecturas programadas como en la app', () => {
  assert.equal(scheduledReadings(45, 30), 91);
  assert.equal(scheduledReadings(0.7, 7), 7);
  assert.equal(scheduledReadings(30, 60), 31);
});

test('rechaza incoherencias con su campo', () => {
  const body = registro({
    codigo_registro: 'otro',
    cod_metrica: '0032-11-291026093000',
    estado: 'en_curso',
  });
  body.puntos[0].lecturas_programadas = 5;
  body.lecturas[0].n_canal = 9;
  body.lecturas[1].valor = 12;
  body.correcciones[0].n_lectura = 2;
  body.correcciones[0].n_canal = 2;
  body.lecturas.push({ ...body.lecturas[2] });
  const fields = validateTemperatura(body).issues.map((issue) => issue.field);
  for (const field of [
    'estado',
    'codigo_registro',
    'cod_metrica',
    'puntos[0].lecturas_programadas',
    'lecturas[0].n_canal',
    'lecturas[1].valor',
    'lecturas[6]',
  ]) {
    assert.ok(fields.includes(field), `falta el problema de ${field}: ${fields.join(', ')}`);
  }
});

test('exige patrón, canal del patrón y un punto medido', () => {
  const body = registro({ patrones: [], canales: [registro().canales[1]] });
  body.puntos[0].estado = 'pendiente';
  const messages = validateTemperatura(body).issues.map((issue) => issue.message);
  assert.ok(messages.includes('Falta el patrón de temperatura.'));
  assert.ok(messages.includes('Falta un canal del patrón.'));
  assert.ok(messages.includes('Ningún punto se midió.'));
});

test('lotes de lecturas dentro del límite de parámetros', () => {
  const rows = Array.from({ length: 1000 }, (_, i) => ({ n_lectura: i }));
  const queries = buildInserts(TABLES.lecturas, COLUMNS.lecturas, rows);
  assert.ok(queries.length > 1);
  for (const query of queries) {
    assert.ok(query.params.length <= MAX_PARAMETERS, `${query.params.length} parámetros`);
  }
  assert.equal(
    queries.reduce((sum, query) => sum + query.params.length, 0),
    1000 * COLUMNS.lecturas.length,
  );
  // Las fechas conservan su desfase: se convierten en SQL.
  assert.match(queries[0].text, /CONVERT\(datetimeoffset\(3\), @p0_5\)/);
});

test('inserta cabecera, hijos y resumen CAL.TE en una transacción', async () => {
  const fake = fakeTransaction();
  const service = createTemperaturaService({ transaction: fake.transaction });
  const result = await service.save(registro(), { user: 'jperez' });
  assert.deepEqual(result, { n: 42, summaryN: 900, duplicate: false });
  assert.ok(fake.committed);
  const texts = fake.queries.map((query) => query.text);
  for (const table of ['header', 'patrones', 'canales', 'puntos', 'lecturas', 'correcciones', 'summary']) {
    assert.ok(texts.some((text) => text.includes(`INSERT INTO ${TABLES[table]}`)), table);
  }
  assert.ok(!texts.some((text) => /\bUPDATE\b|\bDELETE\b/i.test(text)), 'solo INSERT');
  const header = fake.queries.find((query) => query.text.includes(`INSERT INTO ${TABLES.header}`));
  const regPor = header.params.find((param) => param.value === 'Ing. Juan Pérez');
  assert.ok(regPor, 'el nombre lo impone el servidor');
  const summary = fake.queries.find((query) => query.text.includes(`INSERT INTO ${TABLES.summary}`));
  assert.equal(summary.params.find((param) => param.name === 'tipoServicio').value, 'CAL.TE');
  assert.equal(summary.params.find((param) => param.name === 'latitud').value, -16.5);
});

test('el mismo uuid responde que ya estaba, sin insertar', async () => {
  const fake = fakeTransaction({ existing: true });
  const service = createTemperaturaService({ transaction: fake.transaction });
  const result = await service.save(registro(), { user: 'jperez' });
  assert.deepEqual(result, { n: 41, duplicate: true });
  assert.ok(!fake.queries.some((query) => query.text.includes('INSERT INTO')));
});

test('el código de registro ya usado es un conflicto', async () => {
  const service = createTemperaturaService({ transaction: fakeTransaction({ taken: true }).transaction });
  await assert.rejects(service.save(registro(), { user: 'jperez' }), { code: 'ALREADY_EXISTS', statusCode: 409 });
});

test('sin el script 017 avisa qué falta', async () => {
  const service = createTemperaturaService({ transaction: fakeTransaction({ ready: false }).transaction });
  await assert.rejects(service.save(registro(), { user: 'jperez' }), (error) => {
    assert.equal(error.code, 'TEMPERATURA_NOT_READY');
    assert.equal(error.statusCode, 503);
    assert.match(error.message, /017_calibracion_temperatura\.sql/);
    return true;
  });
  assert.equal(translate({ number: 208 }).code, 'TEMPERATURA_NOT_READY');
  assert.equal(translate({ number: 2627 }).statusCode, 409);
});

test('un registro inválido no abre la transacción', async () => {
  const fake = fakeTransaction();
  const service = createTemperaturaService({ transaction: fake.transaction });
  await assert.rejects(service.save({ uuid: 'x' }, { user: 'jperez' }), (error) => {
    assert.equal(error.statusCode, 422);
    assert.ok(error.details.length > 0);
    return true;
  });
  assert.equal(fake.queries.length, 0);
});

test('sin el nombre del usuario no se registra', async () => {
  const service = createTemperaturaService({ transaction: fakeTransaction({ noUser: true }).transaction });
  await assert.rejects(service.save(registro(), { user: 'nadie' }), { code: 'REGISTERED_USER_NOT_FOUND' });
});

// ── Ruta ──────────────────────────────────────────────────────────────────

const SECRET = 'x'.repeat(40);

function appConfig() {
  return {
    trustProxy: false,
    corsOrigins: [],
    jwtSecret: SECRET,
    jwtTtlSeconds: 3600,
    database: {},
    bitrix: readBitrixConfig({}),
    extras: { database: 'DataMET' },
  };
}

async function withServer(app, run) {
  const server = app.listen(0);
  await new Promise((resolve) => server.once('listening', resolve));
  try {
    await run(`http://127.0.0.1:${server.address().port}`);
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
}

async function post(base, scope, body) {
  const auth = signJwt({ sub: 'jperez', scope }, SECRET, 3600);
  const response = await fetch(`${base}/api/calibracion/temperatura`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${auth}`, 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  return { status: response.status, body: await response.json() };
}

test('la ruta responde 201, 200 si ya estaba y exige el permiso', async () => {
  const calls = [];
  const service = {
    async save(body, { user }) {
      calls.push(user);
      return body.uuid === UUID ? { n: 42, duplicate: false } : { n: 41, duplicate: true };
    },
  };
  const app = createApp(appConfig(), new Map(), new Map(), {
    temperaturaService: service,
    extrasService: null,
    bitrixService: null,
  });
  await withServer(app, async (base) => {
    const created = await post(base, ['calibracion:upload'], registro());
    assert.equal(created.status, 201);
    assert.equal(created.body.n, 42);
    const again = await post(base, ['calibracion:upload'], { uuid: 'otro' });
    assert.equal(again.status, 200);
    assert.equal(again.body.duplicate, true);
    const forbidden = await post(base, ['soporte:upload'], registro());
    assert.equal(forbidden.status, 403);
  });
  assert.deepEqual(calls, ['jperez', 'jperez']);
});

test('la ruta devuelve los problemas de validación', async () => {
  const app = createApp(appConfig(), new Map(), new Map(), {
    temperaturaService: createTemperaturaService({ transaction: fakeTransaction().transaction }),
    extrasService: null,
    bitrixService: null,
  });
  await withServer(app, async (base) => {
    const response = await post(base, ['calibracion:upload'], { uuid: UUID });
    assert.equal(response.status, 422);
    assert.equal(response.body.error, 'VALIDATION_ERROR');
    assert.ok(Array.isArray(response.body.details));
  });
});
