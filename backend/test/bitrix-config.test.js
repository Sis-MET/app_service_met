'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { readBitrixConfig } = require('../src/bitrix/bitrix-config');

test('sin webhook la integración queda deshabilitada sin error', () => {
  const config = readBitrixConfig({});
  assert.equal(config.enabled, false);
  assert.equal(config.configError, null);
  assert.equal(config.stageId, null);
  assert.equal(config.sourceId, null);
  assert.deepEqual(config.fieldMap, {});
});

test('arma la URL del webhook a partir de sus partes', () => {
  const config = readBitrixConfig({
    BITRIX_BASE_URL: 'https://metrica.bitrix24.com/',
    BITRIX_USER_ID: '17',
    BITRIX_WEBHOOK_SECRET: 'abc123secret',
  });
  assert.equal(config.enabled, true);
  assert.equal(config.webhookUrl, 'https://metrica.bitrix24.com/rest/17/abc123secret/');
  assert.equal(config.webhookSecret, 'abc123secret');
});

test('rechaza un webhook sin HTTPS y no filtra el secreto en el error', () => {
  const config = readBitrixConfig({
    BITRIX_WEBHOOK_URL: 'http://metrica.bitrix24.com/rest/1/topsecret/',
  });
  assert.equal(config.enabled, false);
  assert.match(config.configError, /HTTPS/);
  assert.doesNotMatch(config.configError, /topsecret/);
});

test('rechaza una URL que no es de webhook entrante', () => {
  const config = readBitrixConfig({
    BITRIX_WEBHOOK_URL: 'https://metrica.bitrix24.com/crm/deal/',
  });
  assert.equal(config.enabled, false);
  assert.match(config.configError, /rest\/USUARIO\/SECRETO/);
});

test('solo acepta campos personalizados en camelCase y avisa los inválidos', () => {
  const config = readBitrixConfig({
    BITRIX_WEBHOOK_URL: 'https://metrica.bitrix24.com/rest/1/abc/',
    BITRIX_FIELD_SECA: 'ufCrm_1712345678',
    BITRIX_FIELD_PLANTA: 'UF_CRM_1712345679',
    BITRIX_LEAD_STAGE_ID: 'NEW',
    BITRIX_LEAD_SOURCE_ID: 'OTHER',
  });
  assert.deepEqual(config.fieldMap, { seca: 'ufCrm_1712345678' });
  assert.equal(config.warnings.length, 1);
  assert.match(config.warnings[0], /BITRIX_FIELD_PLANTA/);
  assert.equal(config.stageId, 'NEW');
  assert.equal(config.sourceId, 'OTHER');
});

test('ignora IDs inválidos con aviso', () => {
  const config = readBitrixConfig({
    BITRIX_LEAD_ASSIGNED_BY_ID: 'juan',
    BITRIX_LEAD_STAGE_ID: 'Sin asignar',
  });
  assert.equal(config.assignedById, null);
  assert.equal(config.stageId, null);
  assert.equal(config.warnings.length, 2);
});
