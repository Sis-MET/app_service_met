'use strict';

/**
 * Verifica el webhook de Bitrix24 configurado en backend/.env y muestra los
 * IDs reales que puede copiar a las variables BITRIX_*.
 *
 *   pnpm bitrix:discover                       solo lectura
 *   pnpm bitrix:discover -- --empresa "embol"  busca empresas por nombre
 *   pnpm bitrix:discover -- --crear-prueba --empresa-id 120 [--contacto-id 55]
 *                          [--ciudad "La Paz"] crea un prospecto de prueba
 *
 * Nunca imprime la URL ni el secreto del webhook.
 */

const path = require('node:path');
require('../src/config'); // Carga backend/.env.
const crypto = require('node:crypto');
const { readBitrixConfig } = require('../src/bitrix/bitrix-config');
const { createBitrixClient } = require('../src/bitrix/bitrix-client');
const { createBitrixService } = require('../src/bitrix/bitrix-service');

function argument(name) {
  const index = process.argv.indexOf(name);
  return index >= 0 ? process.argv[index + 1] : undefined;
}

const flag = (name) => process.argv.includes(name);

async function step(title, run) {
  console.log(`\n=== ${title} ===`);
  try {
    return await run();
  } catch (error) {
    console.log(`  ERROR ${error.code ?? ''}: ${error.message}`);
    return undefined;
  }
}

async function main() {
  const config = readBitrixConfig(process.env);
  for (const warning of config.warnings) console.log(`Aviso: ${warning}`);
  if (!config.enabled) {
    const envPath = path.join(__dirname, '..', '.env');
    console.log(config.configError || 'Falta BITRIX_WEBHOOK_URL.');
    console.log(`\nEl script lee ${envPath}.`);
    console.log('Ese archivo no se versiona (.env.example es solo la plantilla sin secretos).');
    console.log('Créelo o edítelo y agregue la URL del webhook entrante de Bitrix24:');
    console.log('  BITRIX_WEBHOOK_URL=https://TU_PORTAL.bitrix24.es/rest/USUARIO/SECRETO/');
    process.exitCode = 1;
    return;
  }
  console.log(`Portal: ${new URL(config.webhookUrl).host}`);

  const client = createBitrixClient({
    webhookUrl: config.webhookUrl,
    webhookSecret: config.webhookSecret,
    timeoutMs: config.timeoutMs,
    logger: { log() {}, warn() {} },
  });
  const service = createBitrixService({ client, config });

  const companies = await step('1. Empresas (crm.item.list, entityTypeId=4)', async () => {
    const query = argument('--empresa');
    let items;
    if (query) {
      ({ items } = await service.searchCompanies(query, { limit: 10 }));
    } else {
      const body = await client.call('crm.item.list', {
        entityTypeId: 4,
        select: ['id', 'title'],
        order: { id: 'DESC' },
        start: 0,
      });
      items = (body.result?.items ?? []).slice(0, 5);
      console.log(`  Total de empresas visibles: ${body.total ?? '?'}`);
    }
    for (const company of items) console.log(`  #${company.id}  ${company.title}`);
    if (!items.length) console.log('  (sin resultados)');
    return items;
  });

  await step('2. Contactos de la primera empresa (crm.company.contact.items.get + crm.item.list, entityTypeId=3)', async () => {
    const company = companies?.[0];
    if (!company) return console.log('  (no hay empresa para probar)');
    const { items } = await service.getContactsByCompany(company.id);
    console.log(`  Empresa #${company.id}: ${items.length} contacto(s)`);
    for (const contact of items.slice(0, 5)) {
      const name = [contact.name, contact.lastName].filter(Boolean).join(' ');
      console.log(`  #${contact.id}  ${name}${contact.post ? ` (${contact.post})` : ''}`);
    }
  });

  const target = await step('3. Etapas de Prospectos (crm.status.list, ENTITY_ID=STATUS)', async () => {
    const resolved = await service.resolveTarget();
    for (const stage of await service.getLeadStages()) {
      const mark = stage.statusId === resolved.stageId ? '  <- aquí nacen las oportunidades' : '';
      console.log(`  ${stage.statusId.padEnd(18)} ${stage.semantics.padEnd(8)} ${stage.name}${mark}`);
    }
    console.log('\n  Opcional, para fijarla en .env:');
    console.log(`  BITRIX_LEAD_STAGE_ID=${resolved.stageId}`);
    return resolved;
  });

  await step('4. Fuentes de los prospectos (crm.status.list, ENTITY_ID=SOURCE)', async () => {
    for (const source of await service.getLeadSources()) {
      console.log(`  ${source.statusId.padEnd(18)} ${source.name}`);
    }
    console.log('\n  Opcional: elija una y cópiela en BITRIX_LEAD_SOURCE_ID.');
  });

  await step('5. Campos de Prospectos (crm.item.fields, entityTypeId=1)', async () => {
    const fields = await service.getLeadFields();
    const byId = new Map(fields.map((field) => [field.id, field]));
    for (const standard of ['stageId', 'companyId', 'contactIds', 'originatorId', 'originId', 'sourceId']) {
      console.log(`  ${standard.padEnd(20)} ${byId.has(standard) ? 'disponible' : 'NO disponible'}`);
    }
    const custom = fields.filter((field) => field.isCustom);
    console.log(`\n  Campos personalizados (${custom.length}):`);
    for (const field of custom) {
      const required = field.isRequired ? '  [OBLIGATORIO]' : '';
      console.log(`  ${field.id.padEnd(28)} ${field.type.padEnd(12)} ${field.title}${required}`);
      for (const item of field.items ?? []) {
        console.log(`      ${String(item.ID ?? item.id).padStart(6)}  ${item.VALUE ?? item.value}`);
      }
    }
    // Un campo obligatorio sin valor haría fallar la creación del prospecto.
    const required = fields.filter((field) => field.isRequired && !field.isReadOnly);
    console.log('\n  Campos obligatorios al crear:');
    if (!required.length) console.log('  (ninguno)');
    for (const field of required) console.log(`  ${field.id.padEnd(28)} ${field.title}`);
    console.log('\n  Mapeo configurado:');
    const mapping = Object.entries(config.fieldMap);
    if (!mapping.length) console.log('  (ninguno: todo viaja en el comentario)');
    for (const [key, fieldId] of mapping) {
      const field = byId.get(fieldId);
      console.log(`  ${key.padEnd(18)} -> ${fieldId} ${field ? `(${field.type}) OK` : 'NO EXISTE'}`);
    }
  });

  if (!flag('--crear-prueba')) {
    console.log('\nListo. Para crear un prospecto de prueba agregue --crear-prueba --empresa-id <ID>.');
    return;
  }

  await step('6. Prospecto de prueba (crm.item.add, entityTypeId=1)', async () => {
    if (!target) throw new Error('Primero debe resolverse la etapa inicial.');
    const companyId = Number(argument('--empresa-id'));
    const contactId = argument('--contacto-id') ? Number(argument('--contacto-id')) : null;
    const result = await service.createOpportunity({
      uuid: crypto.randomUUID(),
      companyId,
      contactId,
      city: argument('--ciudad') || 'La Paz',
      opportunityType: { key: 'otro', label: 'Otro' },
      title: 'PRUEBA ServiceMET - puede eliminarse',
      description: 'Prospecto de prueba creado por bitrix-discovery.js para verificar la integración.',
      priority: 'baja',
      service: {
        serviceType: 'calibracion',
        serviceName: 'Calibración',
        seca: 'PRUEBA',
        technician: 'Script de verificación',
        serviceDate: new Date().toISOString().slice(0, 10),
      },
    }, { user: 'bitrix-discovery' });
    console.log(`  Prospecto #${result.leadId} creado en la etapa ${result.stageId}.`);
    console.log('  Revíselo en CRM › Prospectos y elimínelo cuando termine la prueba.');
  });
}

main().catch((error) => {
  console.error(`No se pudo completar el descubrimiento: ${error.message}`);
  process.exitCode = 1;
});
