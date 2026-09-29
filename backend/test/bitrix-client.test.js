'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { createBitrixClient } = require('../src/bitrix/bitrix-client');

const WEBHOOK = 'https://metrica.bitrix24.com/rest/7/s3cr3tc0de/';

function jsonResponse(status, body) {
  return {
    ok: status >= 200 && status < 300,
    status,
    async text() {
      return JSON.stringify(body);
    },
  };
}

function silentLogger() {
  const lines = [];
  return {
    lines,
    log: (line) => lines.push(line),
    warn: (line) => lines.push(line),
  };
}

test('envía el método como POST JSON al webhook', async () => {
  const calls = [];
  const client = createBitrixClient({
    webhookUrl: WEBHOOK,
    fetchImpl: async (url, options) => {
      calls.push({ url, options });
      return jsonResponse(200, { result: { items: [] }, total: 0 });
    },
    logger: silentLogger(),
  });
  const body = await client.call('crm.item.list', { entityTypeId: 4 });
  assert.deepEqual(body.result.items, []);
  assert.equal(calls[0].url, `${WEBHOOK}crm.item.list.json`);
  assert.equal(calls[0].options.method, 'POST');
  assert.deepEqual(JSON.parse(calls[0].options.body), { entityTypeId: 4 });
});

test('traduce un webhook revocado sin exponer el secreto', async () => {
  const logger = silentLogger();
  const client = createBitrixClient({
    webhookUrl: WEBHOOK,
    webhookSecret: 's3cr3tc0de',
    fetchImpl: async () => jsonResponse(401, {
      error: 'NO_AUTH_FOUND',
      error_description: `Wrong auth for ${WEBHOOK}`,
    }),
    logger,
  });
  await assert.rejects(client.call('crm.item.list', {}), (error) => {
    assert.equal(error.code, 'BITRIX_AUTH_ERROR');
    assert.equal(error.statusCode, 502);
    assert.doesNotMatch(error.message, /s3cr3tc0de/);
    return true;
  });
  assert.ok(logger.lines.every((line) => !line.includes('s3cr3tc0de')));
});

test('un error de validación de Bitrix llega como 422 con su descripción', async () => {
  const client = createBitrixClient({
    webhookUrl: WEBHOOK,
    fetchImpl: async () => jsonResponse(400, {
      error: 'CRM_FIELD_ERROR',
      error_description: 'Campo stageId inválido',
    }),
    logger: silentLogger(),
  });
  await assert.rejects(client.call('crm.item.add', {}), (error) => {
    assert.equal(error.code, 'BITRIX_REJECTED');
    assert.equal(error.statusCode, 422);
    assert.match(error.message, /stageId/);
    return true;
  });
});

test('sin respuesta a tiempo devuelve BITRIX_TIMEOUT', async () => {
  const client = createBitrixClient({
    webhookUrl: WEBHOOK,
    timeoutMs: 1000,
    fetchImpl: async () => {
      const error = new Error('The operation was aborted due to timeout');
      error.name = 'TimeoutError';
      throw error;
    },
    logger: silentLogger(),
  });
  await assert.rejects(client.call('crm.item.list', {}), { code: 'BITRIX_TIMEOUT', statusCode: 504 });
});

test('sin red devuelve BITRIX_UNAVAILABLE', async () => {
  const client = createBitrixClient({
    webhookUrl: WEBHOOK,
    fetchImpl: async () => {
      throw new TypeError('fetch failed');
    },
    logger: silentLogger(),
  });
  await assert.rejects(client.call('crm.item.list', {}), { code: 'BITRIX_UNAVAILABLE', statusCode: 502 });
});

test('reintenta una vez cuando Bitrix limita las solicitudes', async () => {
  let attempts = 0;
  const client = createBitrixClient({
    webhookUrl: WEBHOOK,
    rateLimitDelayMs: 1,
    fetchImpl: async () => {
      attempts += 1;
      return attempts === 1
        ? jsonResponse(503, { error: 'QUERY_LIMIT_EXCEEDED' })
        : jsonResponse(200, { result: true });
    },
    logger: silentLogger(),
  });
  const body = await client.call('crm.item.fields', {});
  assert.equal(body.result, true);
  assert.equal(attempts, 2);
});

test('rechaza nombres de método arbitrarios', async () => {
  const client = createBitrixClient({
    webhookUrl: WEBHOOK,
    fetchImpl: async () => jsonResponse(200, { result: true }),
    logger: silentLogger(),
  });
  await assert.rejects(client.call('../profile', {}), /Método de Bitrix24 inválido/);
});
