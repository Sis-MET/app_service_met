'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { createApp } = require('../src/app');
const { signJwt } = require('../src/security');
const { readBitrixConfig } = require('../src/bitrix/bitrix-config');
const { ExtrasError } = require('../src/extras/extras-validation');

const SECRET = 'x'.repeat(40);

function appConfig() {
  return {
    trustProxy: false,
    corsOrigins: [],
    jwtSecret: SECRET,
    jwtTtlSeconds: 3600,
    database: {},
    bitrix: readBitrixConfig({}),
    extras: { database: 'servicios_extras' },
  };
}

function token(scope = ['extras:upload', 'bitrix:opportunity']) {
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

async function post(base, path, { auth = token(), body = {} } = {}) {
  const response = await fetch(`${base}${path}`, {
    method: 'POST',
    headers: {
      ...(auth ? { Authorization: `Bearer ${auth}` } : {}),
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(body),
  });
  return { status: response.status, body: await response.json() };
}

async function silencingWarnings(run) {
  const original = console.warn;
  const warnings = [];
  console.warn = (message) => warnings.push(String(message));
  try {
    await run(warnings);
  } finally {
    console.warn = original;
  }
}

test('subir un RIM exige sesión y el scope de formularios', async () => {
  const app = createApp(appConfig(), new Map(), new Map(), {
    bitrixService: null,
    extrasService: { async saveRim() { return { n: 1, duplicate: false }; } },
  });
  await withServer(app, async (base) => {
    assert.equal((await post(base, '/api/extras/rim', { auth: null })).status, 401);
    const noScope = await post(base, '/api/extras/rim', { auth: token(['calibracion:upload']) });
    assert.equal(noScope.status, 403);
    assert.equal(noScope.body.error, 'INSUFFICIENT_SCOPE');
  });
});

test('registra el RIM con el usuario del token: 201 y luego 200 si se reenvía', async () => {
  const received = [];
  const extrasService = {
    async saveRim(body, options) {
      received.push({ body, options });
      return { n: 12, duplicate: received.length > 1 };
    },
  };
  const app = createApp(appConfig(), new Map(), new Map(), { bitrixService: null, extrasService });
  await withServer(app, async (base) => {
    const created = await post(base, '/api/extras/rim', { body: { uuid: 'abc' } });
    assert.equal(created.status, 201);
    assert.deepEqual(
      { n: created.body.n, duplicate: created.body.duplicate },
      { n: 12, duplicate: false },
    );
    assert.equal(received[0].options.user, 'tecnico1');

    const again = await post(base, '/api/extras/rim', { body: { uuid: 'abc' } });
    assert.equal(again.status, 200);
    assert.equal(again.body.duplicate, true);
    assert.match(again.body.message, /N\.º 12/);
  });
});

test('los errores del RIM llegan con código, mensaje y detalle por campo', async () => {
  let failure;
  const extrasService = {
    async saveRim() {
      throw failure;
    },
  };
  const app = createApp(appConfig(), new Map(), new Map(), { bitrixService: null, extrasService });
  await silencingWarnings(async () => {
    await withServer(app, async (base) => {
      failure = new ExtrasError('Los datos del RIM están incompletos o no son válidos.', {
        code: 'VALIDATION_ERROR',
        statusCode: 400,
        details: [{ field: 'clientSignature', message: 'Falta la firma del cliente.' }],
      });
      const invalid = await post(base, '/api/extras/rim');
      assert.equal(invalid.status, 400);
      assert.equal(invalid.body.details[0].field, 'clientSignature');

      failure = new ExtrasError('El servidor todavía no tiene lista la base.', {
        code: 'EXTRAS_NOT_READY',
        statusCode: 503,
      });
      const notReady = await post(base, '/api/extras/rim');
      assert.equal(notReady.status, 503);
      assert.equal(notReady.body.error, 'EXTRAS_NOT_READY');
    });
  });
});

test('un error interno no revela detalles de la base', async () => {
  const extrasService = {
    async saveRim() {
      throw new Error('Login failed for user ServiceMET');
    },
  };
  const originalError = console.error;
  console.error = () => {};
  try {
    const app = createApp(appConfig(), new Map(), new Map(), { bitrixService: null, extrasService });
    await withServer(app, async (base) => {
      const result = await post(base, '/api/extras/rim');
      assert.equal(result.status, 500);
      assert.equal(result.body.error, 'INTERNAL_ERROR');
      assert.doesNotMatch(result.body.message, /Login failed/);
    });
  } finally {
    console.error = originalError;
  }
});

test('la oportunidad registrada en Bitrix24 queda también en form_bitrix', async () => {
  const saved = [];
  const opportunity = { uuid: 'abc', title: 'Reparación' };
  const bitrixService = {
    async createOpportunity() {
      return {
        leadId: 321, duplicate: false, stageId: 'NEW', mappedFields: [], warnings: [], opportunity,
      };
    },
  };
  const extrasService = {
    async saveBitrixOpportunity(received, registered) {
      saved.push({ received, registered });
      return { n: 1, duplicate: false };
    },
  };
  const app = createApp(appConfig(), new Map(), new Map(), { bitrixService, extrasService });
  await withServer(app, async (base) => {
    const created = await post(base, '/api/bitrix/opportunities');
    assert.equal(created.status, 201);
    assert.equal(created.body.leadId, 321);
    // La oportunidad validada es interna: no vuelve a la app.
    assert.equal('opportunity' in created.body, false);
  });
  assert.deepEqual(saved, [{
    received: opportunity,
    registered: { leadId: 321, stageId: 'NEW', user: 'tecnico1' },
  }]);
});

test('si la copia en form_bitrix falla, la oportunidad igual responde 201', async () => {
  const bitrixService = {
    async createOpportunity() {
      return {
        leadId: 55, duplicate: false, stageId: 'NEW', mappedFields: [], warnings: [],
        opportunity: { uuid: 'abc' },
      };
    },
  };
  const extrasService = {
    async saveBitrixOpportunity() {
      throw new Error('base no disponible');
    },
  };
  await silencingWarnings(async (warnings) => {
    const app = createApp(appConfig(), new Map(), new Map(), { bitrixService, extrasService });
    await withServer(app, async (base) => {
      const created = await post(base, '/api/bitrix/opportunities');
      assert.equal(created.status, 201);
      assert.equal(created.body.leadId, 55);
    });
    assert.ok(warnings.some((warning) => /form_bitrix/.test(warning)));
  });
});
