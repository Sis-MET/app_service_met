'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { readBitrixConfig } = require('../src/bitrix/bitrix-config');
const { createBitrixService } = require('../src/bitrix/bitrix-service');
const { buildComments, validateOpportunity } = require('../src/bitrix/bitrix-mapping');

const UUID = '3f1c2a4b-5d6e-4f70-8a9b-0c1d2e3f4a5b';

function config(env = {}) {
  return readBitrixConfig({
    BITRIX_WEBHOOK_URL: 'https://metrica.bitrix24.com/rest/1/abc/',
    ...env,
  });
}

/** Cliente falso: responde según el método y registra cada llamada. */
function fakeClient(handlers) {
  const calls = [];
  return {
    calls,
    async call(method, params) {
      calls.push({ method, params });
      const handler = handlers[method];
      if (!handler) throw new Error(`Método no esperado: ${method}`);
      return handler(params, calls);
    },
  };
}

/** Etapas estándar de los Leads, como en el kanban de Prospectos. */
const STAGES = {
  result: [
    { STATUS_ID: 'CONVERTED', NAME: 'Convertido', SORT: 900, SEMANTICS: 'S' },
    { STATUS_ID: 'IN_PROCESS', NAME: 'En Progreso', SORT: 20, SEMANTICS: null },
    { STATUS_ID: 'NEW', NAME: 'Sin asignar', SORT: 10, SEMANTICS: null },
    { STATUS_ID: 'PROCESSED', NAME: 'Procesado', SORT: 30, SEMANTICS: null },
    { STATUS_ID: 'JUNK', NAME: 'Basura', SORT: 1000, SEMANTICS: 'F' },
  ],
};

const FIELDS = {
  result: {
    fields: {
      title: { type: 'string', title: 'Nombre' },
      ufCrm_111: { type: 'string', title: 'SECA', isReadOnly: false },
      ufCrm_222: {
        type: 'enumeration',
        title: 'Tipo de oportunidad',
        items: [{ ID: '45', VALUE: 'VENTA' }],
      },
      ufCrm_333: { type: 'double', title: 'Capacidad' },
    },
  },
};

function opportunity(overrides = {}) {
  return {
    uuid: UUID,
    companyId: 120,
    companyName: 'EMBOL S.A.',
    contactId: 55,
    contactName: 'Juan Pérez',
    opportunityType: { key: 'reemplazo_indicador', label: 'Reemplazo de indicador', line: 'VENTA' },
    title: 'Oportunidad ServiceMET - Reemplazo de indicador - EMBOL S.A.',
    description: 'Indicador presenta fallas y el cliente solicita cotización.',
    priority: 'media',
    notes: '',
    service: {
      serviceType: 'calibracion',
      serviceName: 'Calibración',
      seca: '1523-C01-26',
      clientName: 'Coca-Cola Embol S.A.',
      plantName: 'Planta Viacha',
      metricCode: '0072-11-015',
      brand: 'Mettler Toledo',
      model: 'IND560',
      serial: 'ABC123',
      capacity: '60000',
      division: '20',
      unit: 'kg',
      technician: 'Ing. Ana Quispe',
      serviceDate: '2026-09-29',
    },
    appVersion: '6.3.3+15',
    ...overrides,
  };
}

function handlers(overrides = {}) {
  return {
    'crm.status.list': () => STAGES,
    'crm.item.fields': () => FIELDS,
    'crm.company.contact.items.get': () => ({
      result: [{ CONTACT_ID: 55, SORT: 10, IS_PRIMARY: 'Y' }],
    }),
    'crm.item.list': () => ({ result: { items: [] }, total: 0 }),
    'crm.item.add': () => ({ result: { item: { id: 9876 } } }),
    ...overrides,
  };
}

test('usa la primera etapa en curso de Prospectos ("Sin asignar")', async () => {
  const client = fakeClient(handlers());
  const service = createBitrixService({ client, config: config() });
  const target = await service.resolveTarget();
  assert.deepEqual(target, { stageId: 'NEW', stageName: 'Sin asignar' });
  const statusCall = client.calls.find((call) => call.method === 'crm.status.list');
  assert.deepEqual(statusCall.params.filter, { ENTITY_ID: 'STATUS' });
});

test('usa la etapa configurada solo si existe en Prospectos', async () => {
  const ok = createBitrixService({
    client: fakeClient(handlers()),
    config: config({ BITRIX_LEAD_STAGE_ID: 'IN_PROCESS' }),
  });
  assert.equal((await ok.resolveTarget()).stageId, 'IN_PROCESS');

  const missing = createBitrixService({
    client: fakeClient(handlers()),
    config: config({ BITRIX_LEAD_STAGE_ID: 'C4:NEW' }),
  });
  await assert.rejects(missing.resolveTarget(), { code: 'BITRIX_STAGE_NOT_FOUND' });
});

test('sin etapas en curso falla con un mensaje claro y no lo guarda en caché', async () => {
  let stages = { result: [{ STATUS_ID: 'CONVERTED', NAME: 'Convertido', SEMANTICS: 'S' }] };
  const client = fakeClient(handlers({ 'crm.status.list': () => stages }));
  const service = createBitrixService({ client, config: config() });
  await assert.rejects(service.resolveTarget(), { code: 'BITRIX_STAGE_NOT_FOUND' });
  stages = STAGES;
  assert.equal((await service.resolveTarget()).stageId, 'NEW');
});

test('crea el prospecto (Lead) con empresa, contacto y clave de origen', async () => {
  const client = fakeClient(handlers());
  const service = createBitrixService({ client, config: config() });
  const result = await service.createOpportunity(opportunity(), { user: 'aquispe' });
  assert.equal(result.leadId, 9876);
  assert.equal(result.duplicate, false);

  const add = client.calls.find((call) => call.method === 'crm.item.add');
  const { fields } = add.params;
  assert.equal(add.params.entityTypeId, 1);
  assert.equal(fields.categoryId, undefined, 'los Leads no tienen pipeline');
  assert.equal(fields.stageId, 'NEW');
  assert.equal(fields.companyId, 120);
  assert.deepEqual(fields.contactIds, [55]);
  assert.equal(fields.sourceDescription, 'ServiceMET');
  assert.equal(fields.originatorId, 'SERVICEMET');
  assert.equal(fields.originId, UUID);
  assert.equal(fields.sourceId, undefined);
  assert.match(fields.comments, /SECA: 1523-C01-26/);
  assert.match(fields.comments, /Código métrica: 0072-11-015/);
  assert.match(fields.comments, /División: 20 kg/);
  assert.match(fields.comments, /Registrado por: Ing\. Ana Quispe \(usuario aquispe\)/);
});

test('acepta una oportunidad registrada fuera de un servicio, sin equipo', async () => {
  const client = fakeClient(handlers());
  const service = createBitrixService({ client, config: config() });
  const result = await service.createOpportunity(opportunity({
    contactId: null,
    service: {
      serviceType: 'directo',
      serviceName: 'Registro directo',
      clientName: 'Coca-Cola Embol S.A.',
      plantDepartment: 'LA PAZ',
      technician: 'Ing. Ana Quispe',
      serviceDate: '2026-10-02',
    },
  }), { user: 'aquispe' });
  assert.equal(result.leadId, 9876);
  // La oportunidad validada vuelve para dejar constancia en form_bitrix.
  assert.equal(result.opportunity.service.serviceType, 'directo');

  const { fields } = client.calls.find((call) => call.method === 'crm.item.add').params;
  assert.match(fields.comments, /Tipo de servicio: Registro directo/);
  assert.doesNotMatch(fields.comments, /SECA|OTST|Código métrica/);

  await assert.rejects(
    service.createOpportunity(opportunity({ service: { serviceType: 'venta' } })),
    (error) => error.details.some((detail) => detail.field === 'service.serviceType'),
  );
});

test('no duplica: si el UUID ya existe devuelve el prospecto registrado', async () => {
  const client = fakeClient(handlers({
    'crm.item.list': () => ({ result: { items: [{ id: 4321, stageId: 'NEW' }] } }),
  }));
  const service = createBitrixService({ client, config: config() });
  const result = await service.createOpportunity(opportunity());
  assert.equal(result.leadId, 4321);
  assert.equal(result.duplicate, true);
  assert.ok(!client.calls.some((call) => call.method === 'crm.item.add'));
  const lookup = client.calls.find((call) => call.method === 'crm.item.list');
  assert.equal(lookup.params.entityTypeId, 1);
  assert.deepEqual(lookup.params.filter, { originatorId: 'SERVICEMET', originId: UUID });
});

test('dos envíos simultáneos del mismo UUID crean un solo prospecto', async () => {
  let created = false;
  const client = fakeClient(handlers({
    'crm.item.list': () => ({
      result: { items: created ? [{ id: 9876, stageId: 'NEW' }] : [] },
    }),
    'crm.item.add': () => {
      created = true;
      return { result: { item: { id: 9876 } } };
    },
  }));
  const service = createBitrixService({ client, config: config() });
  const [first, second] = await Promise.all([
    service.createOpportunity(opportunity()),
    service.createOpportunity(opportunity()),
  ]);
  assert.equal(client.calls.filter((call) => call.method === 'crm.item.add').length, 1);
  assert.deepEqual([first.duplicate, second.duplicate].sort(), [false, true]);
});

test('usa los campos personalizados existentes y deja el resto en comments', async () => {
  const client = fakeClient(handlers());
  const service = createBitrixService({
    client,
    config: config({
      BITRIX_FIELD_SECA: 'ufCrm_111',
      BITRIX_FIELD_TIPO_OPORTUNIDAD: 'ufCrm_222',
      BITRIX_FIELD_CAPACIDAD: 'ufCrm_333',
      BITRIX_FIELD_MARCA: 'ufCrm_999',
    }),
  });
  const result = await service.createOpportunity(opportunity());
  const { fields } = client.calls.find((call) => call.method === 'crm.item.add').params;

  assert.equal(fields.ufCrm_111, '1523-C01-26');
  assert.equal(fields.ufCrm_222, '45');
  assert.equal(fields.ufCrm_333, undefined, 'un campo numérico no recibe texto');
  assert.equal(fields.ufCrm_999, undefined, 'un campo inexistente no se inventa');
  assert.deepEqual(result.mappedFields.sort(), ['seca', 'tipoOportunidad']);
  assert.equal(result.warnings.length, 2);

  assert.doesNotMatch(fields.comments, /SECA:/);
  assert.doesNotMatch(fields.comments, /Línea: VENTA/);
  assert.match(fields.comments, /Tipo: Reemplazo de indicador/, 'el detalle queda en el comentario');
  assert.match(fields.comments, /Capacidad: 60000 kg/);
  assert.match(fields.comments, /Marca: Mettler Toledo/);
  assert.match(fields.comments, /Indicador presenta fallas/);
});

test('rechaza un contacto que no pertenece a la empresa', async () => {
  const client = fakeClient(handlers({
    'crm.company.contact.items.get': () => ({ result: [{ CONTACT_ID: 999 }] }),
  }));
  const service = createBitrixService({ client, config: config() });
  await assert.rejects(service.createOpportunity(opportunity()), (error) => {
    assert.equal(error.statusCode, 400);
    assert.equal(error.details[0].field, 'contactId');
    return true;
  });
  assert.ok(!client.calls.some((call) => call.method === 'crm.item.add'));
});

test('valida los datos obligatorios antes de llamar a Bitrix', async () => {
  const client = fakeClient(handlers());
  const service = createBitrixService({ client, config: config() });
  await assert.rejects(
    service.createOpportunity(opportunity({ companyId: null, description: '', uuid: 'x' })),
    (error) => {
      const fields = error.details.map((detail) => detail.field).sort();
      assert.deepEqual(fields, ['companyId', 'description', 'uuid']);
      return true;
    },
  );
  assert.equal(client.calls.length, 0);
});

test('busca empresas por nombre y exige al menos 2 letras', async () => {
  const client = fakeClient(handlers({
    'crm.item.list': () => ({
      result: { items: [{ id: '120', title: 'EMBOL S.A.', companyTypeId: 'CUSTOMER' }] },
      total: 1,
    }),
  }));
  const service = createBitrixService({ client, config: config() });
  const result = await service.searchCompanies('  embol ');
  assert.deepEqual(result.items, [{ id: 120, title: 'EMBOL S.A.', companyTypeId: 'CUSTOMER', industry: null }]);
  assert.deepEqual(client.calls[0].params.filter, { '%title': 'embol' });
  assert.equal(client.calls[0].params.entityTypeId, 4);
  await assert.rejects(service.searchCompanies('e'), { code: 'VALIDATION_ERROR' });
});

test('lista los contactos vinculados a la empresa con teléfono y correo', async () => {
  const client = fakeClient(handlers({
    'crm.company.contact.items.get': () => ({
      result: [{ CONTACT_ID: 8, IS_PRIMARY: 'N' }, { CONTACT_ID: 9, IS_PRIMARY: 'Y' }],
    }),
    'crm.item.list': () => ({
      result: {
        items: [
          { id: 8, name: 'Luis', lastName: 'Mamani', post: 'Jefe de planta', fm: [] },
          {
            id: 9,
            name: 'Juan',
            lastName: 'Pérez',
            fm: [
              { typeId: 'PHONE', value: '+591 70000000' },
              { typeId: 'EMAIL', value: 'jperez@embol.com' },
            ],
          },
        ],
      },
    }),
  }));
  const service = createBitrixService({ client, config: config() });
  const result = await service.getContactsByCompany('120');
  assert.deepEqual(result.items.map((contact) => contact.id), [9, 8]);
  assert.equal(result.items[0].phone, '+591 70000000');
  assert.equal(result.items[0].email, 'jperez@embol.com');
  assert.equal(result.items[1].post, 'Jefe de planta');
  const list = client.calls.find((call) => call.method === 'crm.item.list');
  assert.deepEqual(list.params.filter, { '@id': [8, 9] });
  assert.equal(list.params.entityTypeId, 3);
});

test('una empresa sin contactos no llama a crm.item.list', async () => {
  const client = fakeClient(handlers({ 'crm.company.contact.items.get': () => ({ result: [] }) }));
  const service = createBitrixService({ client, config: config() });
  assert.deepEqual((await service.getContactsByCompany(120)).items, []);
  assert.ok(!client.calls.some((call) => call.method === 'crm.item.list'));
});

test('comments en HTML escapa lo escrito por el técnico', () => {
  const html = buildComments(validateOpportunity(opportunity({ description: 'Falla <b>grave</b>' })), {
    format: 'html',
  });
  assert.match(html, /Falla &lt;b&gt;grave&lt;\/b&gt;/);
  assert.match(html, /<br>/);
});

/** Los campos personalizados reales de Prospectos en el Bitrix24 de METRICA. */
const METRICA_FIELDS = {
  result: {
    fields: {
      title: { type: 'string', title: 'Nombre' },
      opened: { type: 'boolean', title: 'Disponible para todos', isRequired: true },
      ufCrm_1735591283504: {
        type: 'enumeration',
        title: 'MES DE SERVICIO USUAL',
        items: ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio',
          'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre']
          .map((VALUE, index) => ({ ID: String(331 + index * 2), VALUE })),
      },
      ufCrm_1790601080: {
        type: 'enumeration',
        title: 'TIPO DE OPORTUNIDAD',
        items: [
          { ID: '971', VALUE: 'VENTA' },
          { ID: '973', VALUE: 'SOPORTE TECNICO' },
          { ID: '975', VALUE: 'CALIBRACIÓN' },
        ],
      },
      ufCrm_LEAD_1790626227373: {
        type: 'enumeration',
        title: 'Ciudad del prospecto',
        isRequired: true,
        items: ['La Paz', 'Cochabamba', 'Santa Cruz', 'Oruro', 'Potosí', 'Sucre',
          'Tarija', 'Beni', 'Pando'].map((VALUE, index) => ({ ID: String(977 + index * 2), VALUE })),
      },
    },
  },
};

function metricaConfig(env = {}) {
  return config({
    BITRIX_FIELD_TIPO_OPORTUNIDAD: 'ufCrm_1790601080',
    BITRIX_FIELD_CIUDAD: 'ufCrm_LEAD_1790626227373',
    BITRIX_FIELD_MES_SERVICIO: 'ufCrm_1735591283504',
    ...env,
  });
}

function withDepartment(department, overrides = {}) {
  const base = opportunity(overrides);
  return { ...base, service: { ...base.service, plantDepartment: department } };
}

test('llena línea, ciudad (del departamento) y mes con los IDs de las listas', async () => {
  const client = fakeClient(handlers({ 'crm.item.fields': () => METRICA_FIELDS }));
  const service = createBitrixService({ client, config: metricaConfig() });
  await service.createOpportunity(withDepartment('LA PAZ'));
  const { fields } = client.calls.find((call) => call.method === 'crm.item.add').params;
  assert.equal(fields.ufCrm_1790601080, '971', 'VENTA');
  assert.equal(fields.ufCrm_LEAD_1790626227373, '977', 'La Paz');
  assert.equal(fields.ufCrm_1735591283504, '347', 'Septiembre');
  assert.doesNotMatch(fields.comments, /Ciudad:/);
});

test('reconoce abreviaturas y departamentos: SCZ → Santa Cruz, Chuquisaca → Sucre', async () => {
  for (const [department, id] of [['SCZ', '981'], ['Chuquisaca', '987'], ['potosi', '985']]) {
    const client = fakeClient(handlers({ 'crm.item.fields': () => METRICA_FIELDS }));
    const service = createBitrixService({ client, config: metricaConfig() });
    await service.createOpportunity(withDepartment(department));
    const { fields } = client.calls.find((call) => call.method === 'crm.item.add').params;
    assert.equal(fields.ufCrm_LEAD_1790626227373, id, department);
  }
});

test('la ciudad elegida por el técnico manda sobre el departamento', async () => {
  const client = fakeClient(handlers({ 'crm.item.fields': () => METRICA_FIELDS }));
  const service = createBitrixService({ client, config: metricaConfig() });
  await service.createOpportunity(withDepartment('La Paz', { city: 'Oruro' }));
  const { fields } = client.calls.find((call) => call.method === 'crm.item.add').params;
  assert.equal(fields.ufCrm_LEAD_1790626227373, '983');
});

test('CALIBRACIÓN coincide aunque la app la envíe sin tilde', async () => {
  const client = fakeClient(handlers({ 'crm.item.fields': () => METRICA_FIELDS }));
  const service = createBitrixService({ client, config: metricaConfig() });
  await service.createOpportunity(withDepartment('Oruro', {
    opportunityType: { key: 'calibracion', label: 'Calibración de otro equipo', line: 'CALIBRACION' },
  }));
  const { fields } = client.calls.find((call) => call.method === 'crm.item.add').params;
  assert.equal(fields.ufCrm_1790601080, '975');
});

test('sin ciudad deducible pide elegirla y no llama a Bitrix', async () => {
  const client = fakeClient(handlers({ 'crm.item.fields': () => METRICA_FIELDS }));
  const service = createBitrixService({ client, config: metricaConfig() });
  await assert.rejects(service.createOpportunity(withDepartment('Yacuiba')), (error) => {
    assert.equal(error.statusCode, 400);
    assert.equal(error.details[0].field, 'city');
    assert.match(error.message, /Yacuiba/);
    return true;
  });
  assert.ok(!client.calls.some((call) => call.method === 'crm.item.add'));
});

test('un obligatorio sin configurar es un error de configuración claro', async () => {
  const client = fakeClient(handlers({ 'crm.item.fields': () => METRICA_FIELDS }));
  const service = createBitrixService({ client, config: config() });
  await assert.rejects(service.createOpportunity(withDepartment('La Paz')), (error) => {
    assert.equal(error.code, 'BITRIX_REQUIRED_FIELD');
    assert.match(error.message, /Ciudad del prospecto/);
    return true;
  });
});

test('entrega a la app las ciudades de la lista configurada', async () => {
  const client = fakeClient(handlers({ 'crm.item.fields': () => METRICA_FIELDS }));
  const configured = createBitrixService({ client, config: metricaConfig() });
  const options = await configured.formOptions();
  assert.equal(options.city.required, true);
  assert.equal(options.city.options.length, 9);
  assert.equal(options.city.options[4], 'Potosí');

  const unconfigured = createBitrixService({ client: fakeClient(handlers()), config: config() });
  assert.deepEqual(await unconfigured.formOptions(), { city: null });
});
