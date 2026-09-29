'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { createApp } = require('../src/app');
const { signJwt } = require('../src/security');
const { BitrixError } = require('../src/bitrix/bitrix-client');
const { readBitrixConfig } = require('../src/bitrix/bitrix-config');

const SECRET = 'x'.repeat(40);

function appConfig(bitrixEnv = {}) {
  return {
    trustProxy: false,
    corsOrigins: [],
    jwtSecret: SECRET,
    jwtTtlSeconds: 3600,
    database: {},
    bitrix: readBitrixConfig(bitrixEnv),
  };
}

function token(scope = ['bitrix:opportunity']) {
  return signJwt({ sub: 'tecnico1', scope }, SECRET, 3600);
}

async function withServer(app, run) {
  const server = app.listen(0);
  await new Promise((resolve) => server.once('listening', resolve));
  const base = `http://127.0.0.1:${server.address().port}`;
  try {
    await run(base);
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
}

async function request(base, path, { method = 'GET', auth = token(), body } = {}) {
  const response = await fetch(`${base}${path}`, {
    method,
    headers: {
      ...(auth ? { Authorization: `Bearer ${auth}` } : {}),
      ...(body ? { 'Content-Type': 'application/json' } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  return { status: response.status, body: await response.json() };
}

const silent = { warn() {}, log() {}, error() {} };

test('las rutas de Bitrix exigen sesión y el scope de oportunidades', async () => {
  const app = createApp(appConfig(), new Map(), new Map(), { bitrixService: {} });
  await withServer(app, async (base) => {
    assert.equal((await request(base, '/api/bitrix/companies?q=em', { auth: null })).status, 401);
    const noScope = await request(base, '/api/bitrix/companies?q=em', {
      auth: token(['calibracion:upload']),
    });
    assert.equal(noScope.status, 403);
    assert.equal(noScope.body.error, 'INSUFFICIENT_SCOPE');
  });
});

test('sin webhook responde 503 BITRIX_NOT_CONFIGURED y status lo explica', async () => {
  const app = createApp(appConfig(), new Map(), new Map());
  await withServer(app, async (base) => {
    const search = await request(base, '/api/bitrix/companies?q=embol');
    assert.equal(search.status, 503);
    assert.equal(search.body.error, 'BITRIX_NOT_CONFIGURED');
    const status = await request(base, '/api/bitrix/status');
    assert.equal(status.status, 200);
    assert.equal(status.body.configured, false);
  });
});

test('crea la oportunidad con el usuario autenticado y responde 201', async () => {
  const received = [];
  const service = {
    async createOpportunity(body, options) {
      received.push({ body, options });
      return { leadId: 321, duplicate: false, stageId: 'NEW', mappedFields: [], warnings: [] };
    },
  };
  const originalWarn = console.warn;
  console.warn = silent.warn;
  try {
    const app = createApp(appConfig(), new Map(), new Map(), { bitrixService: service });
    await withServer(app, async (base) => {
      const created = await request(base, '/api/bitrix/opportunities', {
        method: 'POST',
        body: { uuid: 'abc' },
      });
      assert.equal(created.status, 201);
      assert.equal(created.body.leadId, 321);
      assert.equal(received[0].options.user, 'tecnico1');
    });
  } finally {
    console.warn = originalWarn;
  }
});

test('un duplicado responde 200 con el prospecto existente', async () => {
  const service = {
    async createOpportunity() {
      return { leadId: 55, duplicate: true, stageId: 'NEW', mappedFields: [], warnings: [] };
    },
  };
  const app = createApp(appConfig(), new Map(), new Map(), { bitrixService: service });
  await withServer(app, async (base) => {
    const result = await request(base, '/api/bitrix/opportunities', { method: 'POST', body: {} });
    assert.equal(result.status, 200);
    assert.equal(result.body.duplicate, true);
    assert.match(result.body.message, /#55/);
  });
});

test('los errores de Bitrix llegan con código y mensaje claros', async () => {
  const service = {
    async searchCompanies() {
      throw new BitrixError('Bitrix24 no respondió dentro del tiempo esperado.', {
        code: 'BITRIX_TIMEOUT',
        statusCode: 504,
      });
    },
    async createOpportunity() {
      throw new BitrixError('Datos inválidos.', {
        code: 'VALIDATION_ERROR',
        statusCode: 400,
        details: [{ field: 'companyId', message: 'Seleccione la empresa de Bitrix24.' }],
      });
    },
  };
  const originalWarn = console.warn;
  console.warn = silent.warn;
  try {
    const app = createApp(appConfig(), new Map(), new Map(), { bitrixService: service });
    await withServer(app, async (base) => {
      const timeout = await request(base, '/api/bitrix/companies?q=embol');
      assert.equal(timeout.status, 504);
      assert.equal(timeout.body.error, 'BITRIX_TIMEOUT');
      assert.match(timeout.body.message, /tiempo esperado/);

      const invalid = await request(base, '/api/bitrix/opportunities', { method: 'POST', body: {} });
      assert.equal(invalid.status, 400);
      assert.equal(invalid.body.details[0].field, 'companyId');
    });
  } finally {
    console.warn = originalWarn;
  }
});
