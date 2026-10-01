'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const {
  createExtrasService,
  readExtrasConfig,
} = require('../src/extras/extras-service');
const { validateRim, MAX_SIGNATURE_BYTES } = require('../src/extras/extras-validation');
const { validateOpportunity } = require('../src/bitrix/bitrix-mapping');

const UUID = '3f2a8c1e-7b4d-4e9a-a1c2-5d6e7f8091ab';
const PNG = Buffer.concat([
  Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
  Buffer.from('firma'),
]);

function rim(overrides = {}) {
  return {
    uuid: UUID,
    code: 'RIM-0103-11-26',
    service: {
      serviceType: 'calibracion',
      serviceName: 'Calibración',
      seca: '26-0103-C01',
      sessionId: '0001',
      clientCode: '0103',
      clientName: 'EMBOL',
      clientLegalName: 'EMBOL S.A.',
      plantCode: '0103-11',
      plantName: 'Planta Río Seco',
      plantAddress: 'Av. Juan Pablo II',
      plantDepartment: 'LA PAZ',
      metricCode: '0103-11-005',
      equipmentType: 'Balanza de plataforma',
      brand: 'Mettler Toledo',
      model: 'IND570',
      serial: 'B123',
      capacity: '600',
      division: '0.2',
      unit: 'kg',
      location: 'Despacho',
      technician: 'Ing. Ana Quispe',
    },
    reason: 'El indicador no enciende.',
    inventory: { indicator: 'present', powerCable: 'missing', loadCells: 'present' },
    quantities: { loadCells: '4' },
    otherItems: [{ name: 'Cable RS232', status: 'present' }],
    inventoryNotes: '',
    damageLevel: 'fair',
    damageTypes: { scratches: ['platform', 'display', 'platform'], corrosion: [] },
    damageDescription: 'Rayones en la plataforma.',
    cleanlinessLevel: 'moderate',
    functionalityTestPerformed: true,
    functionalityTestDescription: 'Se probó con otra fuente.',
    contactName: 'Juan Pérez',
    contactPosition: 'Jefe de planta',
    contactPhone: '+591 70000000',
    metricaRepresentative: 'Ing. Ana Quispe',
    receptionLocation: 'Planta Río Seco',
    assignedTechnician: '',
    issuedAt: '2026-10-01T18:30:00.000Z',
    createdBy: 'aquispe',
    appVersion: '6.3.3+15',
    clientSignature: PNG.toString('base64'),
    ...overrides,
  };
}

/** Base simulada: guarda las consultas y responde como SQL Server. */
function fakeDatabase() {
  const rows = new Map();
  const calls = [];
  let next = 1;
  async function run(text, params) {
    calls.push({ text, params });
    const values = Object.fromEntries(params.map((param) => [param.name, param.value]));
    const table = /FROM (\[[^\]]+\]\.\[dbo\]\.\[[^\]]+\])/.exec(text)[1];
    const key = `${table}:${values.uuid}`;
    let inserted = false;
    if (text.includes('INSERT INTO') && !rows.has(key)) {
      rows.set(key, { n: next++, values });
      inserted = true;
    }
    return rows.has(key) ? [{ n: rows.get(key).n, inserted }] : [];
  }
  return { run, rows, calls };
}

test('el nombre de la base se valida para no inyectar SQL', () => {
  assert.equal(readExtrasConfig({}).database, 'servicios_extras');
  assert.equal(readExtrasConfig({ EXTRAS_DB_NAME: ' extras_prueba ' }).database, 'extras_prueba');
  assert.throws(() => readExtrasConfig({ EXTRAS_DB_NAME: 'x]; DROP TABLE t;--' }));
  assert.throws(() => createExtrasService({ database: 'a b', run: async () => [] }));
});

test('registra el RIM con el usuario autenticado y solo con INSERT', async () => {
  const db = fakeDatabase();
  const service = createExtrasService({
    database: 'servicios_extras',
    run: db.run,
    resolveUserName: async (user) => (user === 'aquispe' ? 'Ing. Ana Quispe M.' : ''),
  });
  // La app no decide quién lo registra: se ignora lo que diga el cuerpo.
  const result = await service.saveRim(rim({ reg_usuario: 'otro' }), { user: 'aquispe' });

  assert.deepEqual(result, { n: 1, duplicate: false });
  const [call] = db.calls;
  assert.match(call.text, /INSERT INTO \[servicios_extras\]\.\[dbo\]\.\[form_rim\]/);
  assert.doesNotMatch(call.text, /UPDATE|DELETE|UPDLOCK/i);
  const values = Object.fromEntries(call.params.map((param) => [param.name, param.value]));
  assert.equal(values.reg_usuario, 'aquispe');
  assert.equal(values.reg_por, 'Ing. Ana Quispe M.');
  assert.equal(values.usuario_app, 'aquispe');
  assert.equal(values.codigo_rim, 'RIM-0103-11-26');
  assert.equal(values.cod_metrica, '0103-11-005');
  assert.equal(values.cod_planta, '0103-11');
  assert.equal(values.dir_planta, 'Av. Juan Pablo II');
  assert.equal(values.tecnico_asignado, null);
  assert.equal(values.pruebas_funcionamiento, true);
  assert.ok(values.emitido_en instanceof Date);
  assert.ok(Buffer.isBuffer(values.firma_cliente));
  assert.deepEqual(JSON.parse(values.inventario), {
    items: { indicator: 'present', powerCable: 'missing', loadCells: 'present' },
    quantities: { loadCells: '4' },
    others: [{ name: 'Cable RS232', status: 'present' }],
  });
  assert.deepEqual(JSON.parse(values.danos), {
    scratches: ['platform', 'display'],
    corrosion: [],
  });
  // La fecha de registro la pone SQL Server, no la app.
  assert.equal('fecha_reg' in values, false);
});

test('reenviar el mismo RIM no crea otra fila', async () => {
  const db = fakeDatabase();
  const service = createExtrasService({ database: 'servicios_extras', run: db.run });
  const first = await service.saveRim(rim(), { user: 'aquispe' });
  const second = await service.saveRim(rim({ reason: 'Otro texto distinto.' }), { user: 'aquispe' });
  assert.deepEqual(second, { n: first.n, duplicate: true });
  assert.equal(db.rows.size, 1);
  // El contenido registrado es el del primer envío.
  assert.equal([...db.rows.values()][0].values.motivo, 'El indicador no enciende.');
});

test('dos envíos simultáneos del mismo UUID terminan en una sola fila', async () => {
  const calls = [];
  const service = createExtrasService({
    database: 'servicios_extras',
    async run(text) {
      calls.push(text);
      if (text.includes('INSERT INTO')) {
        throw Object.assign(new Error('Violation of UNIQUE KEY'), { number: 2627 });
      }
      return [{ n: 7, inserted: false }];
    },
  });
  assert.deepEqual(await service.saveRim(rim(), { user: 'aquispe' }), { n: 7, duplicate: true });
  assert.equal(calls.length, 2);
});

test('sin la base o la tabla responde 503 EXTRAS_NOT_READY', async () => {
  for (const number of [208, 229, 911, 916, 4060]) {
    const service = createExtrasService({
      database: 'servicios_extras',
      async run() {
        throw Object.assign(new Error('Invalid object name'), { number });
      },
    });
    await assert.rejects(service.saveRim(rim(), { user: 'aquispe' }), (error) => {
      assert.equal(error.code, 'EXTRAS_NOT_READY');
      assert.equal(error.statusCode, 503);
      assert.match(error.message, /012_create_servicios_extras/);
      return true;
    });
  }
});

test('un error desconocido de SQL no se disfraza', async () => {
  const service = createExtrasService({
    database: 'servicios_extras',
    async run() {
      throw Object.assign(new Error('Deadlock'), { number: 1205 });
    },
  });
  await assert.rejects(service.saveRim(rim(), { user: 'aquispe' }), /Deadlock/);
});

test('rechaza un RIM incompleto indicando cada campo', () => {
  assert.throws(
    () => validateRim(rim({
      uuid: 'x',
      reason: '',
      damageLevel: 'roto',
      cleanlinessLevel: '',
      functionalityTestPerformed: 'yes',
      contactName: 'A',
      clientSignature: '',
      issuedAt: 'ayer',
      service: { serviceType: 'venta' },
    })),
    (error) => {
      assert.equal(error.code, 'VALIDATION_ERROR');
      assert.equal(error.statusCode, 400);
      assert.deepEqual(error.details.map((detail) => detail.field).sort(), [
        'cleanlinessLevel',
        'clientSignature',
        'contactName',
        'damageLevel',
        'functionalityTestPerformed',
        'issuedAt',
        'reason',
        'service.metricCode',
        'service.serviceType',
        'uuid',
      ]);
      return true;
    },
  );
});

test('la firma debe ser un PNG de tamaño razonable', () => {
  const field = (overrides) => {
    try {
      validateRim(rim(overrides));
      return null;
    } catch (error) {
      return error.details.map((detail) => detail.field);
    }
  };
  assert.deepEqual(field({ clientSignature: Buffer.from('no es png').toString('base64') }), ['clientSignature']);
  assert.deepEqual(field({ clientSignature: '<svg onload=alert(1)>' }), ['clientSignature']);
  const enorme = Buffer.concat([PNG, Buffer.alloc(MAX_SIGNATURE_BYTES)]).toString('base64');
  assert.deepEqual(field({ clientSignature: enorme }), ['clientSignature']);
  assert.equal(field({}), null);
});

test('descarta claves desconocidas y la descripción de pruebas si no hubo pruebas', () => {
  const valid = validateRim(rim({
    functionalityTestPerformed: false,
    functionalityTestDescription: 'no debería guardarse',
    inventory: { indicator: 'present' },
    quantities: {},
    otherItems: [],
    extra: 'ignorado',
  }));
  assert.equal(valid.functionalityTestDescription, '');
  assert.equal('extra' in valid, false);
  assert.equal(valid.uuid, UUID);
  assert.throws(() => validateRim(rim({ inventory: { 'x]; DROP': 'present' } })));
  assert.throws(() => validateRim(rim({ inventory: { indicator: 'robado' } })));
  assert.throws(() => validateRim(rim({ damageTypes: { scratches: 'platform' } })));
  assert.throws(() => validateRim(rim({ quantities: { loadCells: 'cuatro' } })));
});

test('deja constancia en form_bitrix de la oportunidad registrada', async () => {
  const db = fakeDatabase();
  const service = createExtrasService({ database: 'servicios_extras', run: db.run });
  const opportunity = validateOpportunity({
    uuid: UUID,
    companyId: 120,
    companyName: 'EMBOL S.A.',
    contactId: null,
    opportunityType: { key: 'reparacion', label: 'Reparación', line: 'SOPORTE TECNICO' },
    city: 'La Paz',
    title: 'Reparación de indicador',
    description: 'El cliente solicita cotización.',
    priority: 'alta',
    notes: '',
    service: rim().service,
    createdAt: '2026-10-01T18:30:00.000Z',
    appVersion: '6.3.3+15',
  });
  const saved = await service.saveBitrixOpportunity(opportunity, {
    leadId: 321,
    stageId: 'NEW',
    user: 'aquispe',
  });
  assert.deepEqual(saved, { n: 1, duplicate: false });
  const [call] = db.calls;
  assert.match(call.text, /INSERT INTO \[servicios_extras\]\.\[dbo\]\.\[form_bitrix\]/);
  const values = Object.fromEntries(call.params.map((param) => [param.name, param.value]));
  assert.equal(values.bitrix_lead_id, 321);
  assert.equal(values.etapa, 'NEW');
  assert.equal(values.reg_usuario, 'aquispe');
  assert.equal(values.company_id, 120);
  assert.equal(values.contact_id, null);
  assert.equal(values.tipo_oportunidad, 'reparacion');
  assert.equal(values.linea, 'SOPORTE TECNICO');
  assert.equal(values.prioridad, 'alta');
  assert.equal(values.observaciones, null);
  assert.equal(values.tecnico, 'Ing. Ana Quispe');
  assert.ok(values.creado_en instanceof Date);

  // Reenviar la oportunidad (duplicada en Bitrix24) no duplica la constancia.
  const again = await service.saveBitrixOpportunity(opportunity, { leadId: 321, user: 'aquispe' });
  assert.deepEqual(again, { n: 1, duplicate: true });
});
