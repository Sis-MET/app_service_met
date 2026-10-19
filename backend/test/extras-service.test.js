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
const PNG_METRICA = Buffer.concat([PNG.subarray(0, 8), Buffer.from('firma de métrica')]);

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
    metricaSignature: PNG_METRICA.toString('base64'),
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
  // La base de los formularios es la del backend: DataMET o DataMET_prueba.
  assert.equal(readExtrasConfig({ DB_NAME: ' DataMET_prueba ' }).database, 'DataMET_prueba');
  assert.throws(() => readExtrasConfig({}), /DB_NAME/);
  assert.throws(() => readExtrasConfig({ DB_NAME: 'x]; DROP TABLE t;--' }));
  // Una EXTRAS_DB_NAME vieja en el .env se ignora y se avisa.
  const avisos = [];
  const config = readExtrasConfig(
    { DB_NAME: 'DataMET', EXTRAS_DB_NAME: 'servicios_extras' },
    { warn: (mensaje) => avisos.push(mensaje) },
  );
  assert.equal(config.database, 'DataMET');
  assert.match(avisos[0], /EXTRAS_DB_NAME=servicios_extras se ignora/);
  assert.equal(readExtrasConfig({ DB_NAME: 'DataMET', EXTRAS_DB_NAME: 'DataMET' }, { warn: () => assert.fail() }).database, 'DataMET');
  assert.throws(() => createExtrasService({ database: 'a b', run: async () => [] }));
});

test('registra el RIM con el usuario autenticado y solo con INSERT', async () => {
  const db = fakeDatabase();
  const service = createExtrasService({
    database: 'DataMET',
    run: db.run,
    resolveUserName: async (user) => (user === 'aquispe' ? 'Ing. Ana Quispe M.' : ''),
  });
  // La app no decide quién lo registra: se ignora lo que diga el cuerpo.
  const result = await service.saveRim(rim({ reg_usuario: 'otro' }), { user: 'aquispe' });

  assert.deepEqual(result, { n: 1, duplicate: false });
  const [call] = db.calls;
  assert.match(call.text, /INSERT INTO \[DataMET\]\.\[dbo\]\.\[form_rim\]/);
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
  assert.deepEqual(values.firma_cliente, PNG);
  assert.deepEqual(values.firma_representante, PNG_METRICA);
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
  const service = createExtrasService({ database: 'DataMET', run: db.run });
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
    database: 'DataMET',
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
      database: 'DataMET',
      async run() {
        throw Object.assign(new Error('Invalid object name'), { number });
      },
    });
    await assert.rejects(service.saveRim(rim(), { user: 'aquispe' }), (error) => {
      assert.equal(error.code, 'EXTRAS_NOT_READY');
      assert.equal(error.statusCode, 503);
      assert.match(error.message, /012_create_form_rim_y_form_bitrix/);
      return true;
    });
  }
});

test('un error desconocido de SQL no se disfraza', async () => {
  const service = createExtrasService({
    database: 'DataMET',
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
      metricaSignature: undefined,
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
        'metricaSignature',
        'reason',
        'service.metricCode',
        'service.serviceType',
        'uuid',
      ]);
      return true;
    },
  );
});

test('acepta un RIM emitido fuera de un servicio (registro directo)', async () => {
  const db = fakeDatabase();
  const service = createExtrasService({ database: 'DataMET', run: db.run });
  const directo = rim({
    service: {
      ...rim().service,
      serviceType: 'directo',
      serviceName: 'Registro directo',
      seca: null,
      sessionId: null,
    },
  });
  await service.saveRim(directo, { user: 'aquispe' });
  const values = Object.fromEntries(db.calls[0].params.map((param) => [param.name, param.value]));
  assert.equal(values.tipo_servicio, 'directo');
  assert.equal(values.servicio, 'Registro directo');
  assert.equal(values.seca_otst, null);
  assert.equal(values.session_id, null);
  assert.equal(values.cod_metrica, '0103-11-005');
});

test('las firmas deben ser PNG de tamaño razonable', () => {
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
  assert.deepEqual(field({ metricaSignature: Buffer.from('no es png').toString('base64') }), ['metricaSignature']);
  assert.deepEqual(field({ metricaSignature: enorme }), ['metricaSignature']);
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
  const service = createExtrasService({ database: 'DataMET', run: db.run });
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
  assert.match(call.text, /INSERT INTO \[DataMET\]\.\[dbo\]\.\[form_bitrix\]/);
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

const INSTALACION = '9b2d7c41-5e3a-4f8b-9c6d-1a2b3c4d5e6f';
const SOLICITUD = 'c4a1e2f3-6b7d-4e8f-a9b0-1c2d3e4f5a6b';

/** RIM numerado por talonario, emitido en la app nueva. */
function rimNumerado(overrides = {}) {
  return rim({ code: 'RIM-26-0042', installationId: INSTALACION, ...overrides });
}

function paramValues(call) {
  return Object.fromEntries(call.params.map((param) => [param.name, param.value]));
}

test('formatea y lee el código RIM-AA-NNNN', () => {
  const { formatRimCode, parseRimCode } = require('../src/extras/extras-validation');
  assert.equal(formatRimCode(2026, 42), 'RIM-26-0042');
  assert.equal(formatRimCode(2027, 12345), 'RIM-27-12345');
  assert.deepEqual(parseRimCode('RIM-26-0042'), { year: 2026, number: 42 });
  assert.equal(parseRimCode('RIM-0103-11-26'), null);
  assert.equal(parseRimCode('RIM-26-0000'), null);
  assert.equal(parseRimCode('RIM-26-42'), null);
});

test('un RIM numerado se registra con gestión, número, instalación y su talonario', async () => {
  const db = fakeDatabase();
  const service = createExtrasService({ database: 'DataMET', run: db.run });
  const result = await service.saveRim(rimNumerado(), { user: 'aquispe' });

  assert.deepEqual(result, { n: 1, duplicate: false });
  const [call] = db.calls;
  const values = paramValues(call);
  assert.equal(values.codigo_rim, 'RIM-26-0042');
  assert.equal(values.gestion, 2026);
  assert.equal(values.numero, 42);
  assert.equal(values.instalacion, INSTALACION);
  assert.equal(values.origen, 'servicemet');
  // El talonario lo resuelve SQL Server: debe ser de esa instalación.
  assert.match(call.text, /\[DataMET\]\.\[dbo\]\.\[rim_talonarios\]/);
  assert.match(call.text, /\[instalacion\] = @instalacion/);
  assert.match(call.text, /THROW 51020/);
  assert.match(call.text, /\[talonario_id\]\) VALUES \(.*@talonario_id\)/s);
  assert.doesNotMatch(call.text, /UPDATE|DELETE|UPDLOCK/i);
  assert.doesNotMatch(call.text, /form_rim_anulaciones/);
});

test('el RIM con código anterior se sigue aceptando, sin número ni talonario', async () => {
  const db = fakeDatabase();
  const service = createExtrasService({ database: 'DataMET', run: db.run });
  await service.saveRim(rim(), { user: 'aquispe' });
  const [call] = db.calls;
  const values = paramValues(call);
  assert.equal('gestion' in values, false);
  assert.equal('numero' in values, false);
  assert.doesNotMatch(call.text, /rim_talonarios|talonario_id/);
});

test('el código debe tener un formato válido y el numerado, su instalación', () => {
  const fields = (overrides) => {
    try {
      validateRim(rim(overrides));
      return [];
    } catch (error) {
      return error.details.map((detail) => detail.field);
    }
  };
  assert.deepEqual(fields({ code: 'RIM 26 0042' }), ['code']);
  assert.deepEqual(fields({ code: 'cualquier cosa' }), ['code']);
  assert.deepEqual(fields({ code: 'RIM-26-0042' }), ['installationId']);
  assert.deepEqual(fields({ code: 'RIM-26-0042', installationId: 'telefono' }), ['installationId']);
  assert.deepEqual(fields({ code: 'RIM-26-0042', installationId: INSTALACION }), []);
});

test('la gestión del código coincide con la fecha de emisión en hora de La Paz', () => {
  // 31/12/2026 23:30 en La Paz es 01/01/2027 03:30 UTC.
  const finDeAnio = '2027-01-01T03:30:00.000Z';
  assert.doesNotThrow(() => validateRim(rimNumerado({ code: 'RIM-26-0042', issuedAt: finDeAnio })));
  assert.doesNotThrow(() => validateRim(rimNumerado({ code: 'RIM-27-0001', issuedAt: finDeAnio })));
  assert.throws(
    () => validateRim(rimNumerado({ code: 'RIM-25-0042' })),
    (error) => error.details.some((detail) => detail.field === 'code'
      && /gestión/.test(detail.message)),
  );
});

test('un RIM anulado en el teléfono se registra junto con su anulación', async () => {
  const db = fakeDatabase();
  const service = createExtrasService({ database: 'DataMET', run: db.run });
  // RIM de prueba anterior a la segunda firma: solo se acepta anulado.
  await service.saveRim(rimNumerado({
    metricaSignature: undefined,
    voided: {
      by: 'aquispe',
      at: '2026-10-01T19:00:00.000Z',
      reason: 'Se registró el instrumento equivocado.',
    },
  }), { user: 'lmamani' });

  const [call] = db.calls;
  const values = paramValues(call);
  assert.match(call.text, /INSERT INTO \[DataMET\]\.\[dbo\]\.\[form_rim_anulaciones\]/);
  assert.match(call.text, /BEGIN TRANSACTION[\s\S]*COMMIT TRANSACTION/);
  assert.equal(values.anulacion_por, 'aquispe');
  assert.equal(values.anulacion_motivo, 'Se registró el instrumento equivocado.');
  assert.ok(values.anulacion_en instanceof Date);
  // Quién lo subió es el usuario del token, no el de la anulación.
  assert.equal(values.reg_usuario, 'lmamani');
  assert.equal(values.firma_representante, null);

  assert.throws(
    () => validateRim(rimNumerado({ voided: { by: '', reason: 'x', at: 'ayer' } })),
    (error) => {
      assert.deepEqual(
        error.details.map((detail) => detail.field).sort(),
        ['voided.at', 'voided.by', 'voided.reason'],
      );
      return true;
    },
  );
  // Sin anular, la segunda firma sigue siendo obligatoria.
  assert.throws(() => validateRim(rimNumerado({ metricaSignature: undefined })));
});

test('un número que no es del talonario del teléfono se rechaza con 409', async () => {
  const service = createExtrasService({
    database: 'DataMET',
    async run() {
      throw Object.assign(new Error('El número del RIM no pertenece a un talonario entregado a este teléfono.'), { number: 51020 });
    },
  });
  await assert.rejects(service.saveRim(rimNumerado(), { user: 'aquispe' }), (error) => {
    assert.equal(error.code, 'RIM_NUMBER_NOT_ASSIGNED');
    assert.equal(error.statusCode, 409);
    return true;
  });
});

test('un número ya usado por otro RIM se rechaza con 409 RIM_NUMBER_TAKEN', async () => {
  const calls = [];
  const service = createExtrasService({
    database: 'DataMET',
    async run(text) {
      calls.push(text);
      if (text.includes('INSERT INTO')) {
        throw Object.assign(new Error('Cannot insert duplicate key row UX_form_rim_numero'), { number: 2601 });
      }
      return []; // Ningún RIM con ese UUID: chocó el número.
    },
  });
  await assert.rejects(service.saveRim(rimNumerado(), { user: 'aquispe' }), (error) => {
    assert.equal(error.code, 'RIM_NUMBER_TAKEN');
    assert.equal(error.statusCode, 409);
    return true;
  });
  assert.equal(calls.length, 2);
});

test('sin el script 014 el RIM numerado responde 503 indicando el script', async () => {
  for (const number of [207, 208]) {
    const service = createExtrasService({
      database: 'DataMET',
      async run() {
        throw Object.assign(new Error('Invalid column name gestion'), { number });
      },
    });
    await assert.rejects(service.saveRim(rimNumerado(), { user: 'aquispe' }), (error) => {
      assert.equal(error.code, 'EXTRAS_NOT_READY');
      assert.match(error.message, /014_rim_numeracion_y_gestion/);
      return true;
    });
  }
});

test('entrega un talonario a la instalación con la cantidad configurada', async () => {
  const calls = [];
  const service = createExtrasService({
    database: 'DataMET',
    talonarioSize: 10,
    resolveUserName: async () => 'Ing. Ana Quispe M.',
    async run(text, params) {
      calls.push({ text, params });
      return [{
        id: 7, gestion: 2026, desde: 41, hasta: 50,
        instalacion: INSTALACION.toUpperCase(), nuevo: true,
      }];
    },
  });
  const talonario = await service.reserveTalonario({
    requestId: SOLICITUD,
    installationId: INSTALACION,
    year: 2026,
    device: 'SM-A515F',
    appVersion: '6.4.0+18',
  }, { user: 'aquispe', now: new Date('2026-10-19T14:00:00Z') });

  assert.deepEqual(talonario, { id: 7, year: 2026, from: 41, to: 50, duplicate: false });
  const [call] = calls;
  assert.match(call.text, /EXEC \[DataMET\]\.\[dbo\]\.\[rim_reservar_talonario\]/);
  assert.match(call.text, /@origen = N'servicemet'/);
  const values = paramValues(call);
  assert.equal(values.cantidad, 10);
  assert.equal(values.usuario, 'aquispe');
  assert.equal(values.reg_por, 'Ing. Ana Quispe M.');
  assert.equal(values.instalacion, INSTALACION);
  assert.equal(values.solicitud, SOLICITUD);
});

test('solo entrega talonarios de la gestión en curso y, en diciembre, de la siguiente', async () => {
  const service = createExtrasService({
    database: 'DataMET',
    async run(_text, params) {
      const values = Object.fromEntries(params.map((param) => [param.name, param.value]));
      return [{ id: 1, gestion: values.gestion, desde: 1, hasta: 10, instalacion: INSTALACION, nuevo: true }];
    },
  });
  const pedir = (year, now) => service.reserveTalonario(
    { requestId: SOLICITUD, installationId: INSTALACION, year },
    { user: 'aquispe', now: new Date(now) },
  );
  const soloGestion = (texto) => (error) => error.details?.[0]?.field === 'year'
    && error.details[0].message.includes(texto);
  await assert.rejects(pedir(2027, '2026-10-19T14:00:00Z'), soloGestion('gestión 2026.'));
  await assert.rejects(pedir(2025, '2026-10-19T14:00:00Z'), soloGestion('gestión 2026.'));
  assert.equal((await pedir(2027, '2026-12-05T14:00:00Z')).year, 2027);
  // 01/12/2026 02:00 UTC todavía es noviembre en La Paz.
  await assert.rejects(pedir(2027, '2026-12-01T02:00:00Z'), soloGestion('gestión 2026.'));
});

test('una solicitud de talonario usada desde otra instalación se rechaza', async () => {
  const service = createExtrasService({
    database: 'DataMET',
    async run() {
      return [{ id: 7, gestion: 2026, desde: 41, hasta: 50, instalacion: SOLICITUD, nuevo: false }];
    },
  });
  await assert.rejects(
    service.reserveTalonario(
      { requestId: SOLICITUD, installationId: INSTALACION, year: 2026 },
      { user: 'aquispe', now: new Date('2026-10-19T14:00:00Z') },
    ),
    (error) => error.code === 'RIM_TALONARIO_CONFLICT' && error.statusCode === 409,
  );
});

test('los errores de la numeración llegan con código estable', async () => {
  const cases = [
    [51011, 'RIM_NUMBERS_EXHAUSTED', 409],
    [51012, 'RIM_NUMBERING_BUSY', 503],
    [2812, 'EXTRAS_NOT_READY', 503],
  ];
  for (const [number, code, statusCode] of cases) {
    const service = createExtrasService({
      database: 'DataMET',
      async run() {
        throw Object.assign(new Error(`error ${number}`), { number });
      },
    });
    await assert.rejects(
      service.reserveTalonario(
        { requestId: SOLICITUD, installationId: INSTALACION, year: 2026 },
        { user: 'aquispe', now: new Date('2026-10-19T14:00:00Z') },
      ),
      (error) => error.code === code && error.statusCode === statusCode,
    );
  }
});

test('cierra una sola vez el talonario de la instalación al terminar la gestión', async () => {
  const calls = [];
  let cerrado = false;
  const service = createExtrasService({
    database: 'DataMET',
    async run(text, params) {
      calls.push({ text, params });
      const inserted = !cerrado;
      cerrado = true;
      return [{ id: 3, inserted }];
    },
  });
  const body = { installationId: INSTALACION, lastUsed: 47, reason: 'fin_gestion' };
  assert.deepEqual(await service.closeTalonario('7', body, { user: 'aquispe' }), { id: 3, duplicate: false });
  assert.deepEqual(await service.closeTalonario('7', body, { user: 'aquispe' }), { id: 3, duplicate: true });

  const [call] = calls;
  assert.match(call.text, /INSERT INTO \[DataMET\]\.\[dbo\]\.\[rim_talonarios_cierres\]/);
  assert.match(call.text, /THROW 51021/);
  assert.doesNotMatch(call.text, /UPDATE|DELETE/i);
  const values = paramValues(call);
  assert.equal(values.talonario_id, 7);
  assert.equal(values.ultimo_usado, 47);
  assert.equal(values.motivo, 'fin_gestion');

  await assert.rejects(
    service.closeTalonario('7', { ...body, reason: 'telefono_perdido' }, { user: 'aquispe' }),
    (error) => error.code === 'VALIDATION_ERROR',
  );
  const ajeno = createExtrasService({
    database: 'DataMET',
    async run() {
      throw Object.assign(new Error('El talonario no existe o no fue entregado a este teléfono.'), { number: 51021 });
    },
  });
  await assert.rejects(
    ajeno.closeTalonario('7', body, { user: 'aquispe' }),
    (error) => error.code === 'RIM_TALONARIO_NOT_FOUND' && error.statusCode === 404,
  );
});

test('el tamaño del talonario se configura y se valida', () => {
  assert.equal(readExtrasConfig({ DB_NAME: 'DataMET' }).talonarioSize, 10);
  assert.equal(readExtrasConfig({ DB_NAME: 'DataMET', RIM_TALONARIO_SIZE: '20' }).talonarioSize, 20);
  assert.throws(() => readExtrasConfig({ DB_NAME: 'DataMET', RIM_TALONARIO_SIZE: '0' }));
  assert.throws(() => readExtrasConfig({ DB_NAME: 'DataMET', RIM_TALONARIO_SIZE: 'diez' }));
});
