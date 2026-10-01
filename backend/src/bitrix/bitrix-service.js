'use strict';

const { BitrixError } = require('./bitrix-client');
const {
  ORIGINATOR_ID,
  buildLeadPayload,
  validateOpportunity,
} = require('./bitrix-mapping');

/**
 * Tipos de CRM que usa la integración. Las oportunidades de ServiceMET se
 * crean como Leads, que en el Bitrix24 en español se llaman "Prospectos".
 */
const ENTITY = Object.freeze({ lead: 1, contact: 3, company: 4 });

/** Directorio de `crm.status.list` con las etapas de los Leads. */
const LEAD_STAGES_ENTITY_ID = 'STATUS';
const SOURCES_ENTITY_ID = 'SOURCE';

const PAGE_SIZE = 50;
const MAX_CONTACTS = 100;

function validationError(field, message) {
  return new BitrixError(message, {
    code: 'VALIDATION_ERROR',
    statusCode: 400,
    details: [{ field, message }],
  });
}

function configError(code, message) {
  return new BitrixError(message, { code, statusCode: 503 });
}

/**
 * La ciudad la puede corregir el técnico; cualquier otro campo obligatorio
 * sin valor es un problema de configuración del servidor o de Bitrix24.
 */
function missingRequiredError(missing, opportunity) {
  if (missing.some((field) => field.key === 'ciudad')) {
    const department = opportunity.service.plantDepartment;
    return validationError(
      'city',
      department
        ? `Elija la ciudad del prospecto: no se reconoce el departamento "${department}" de la planta.`
        : 'Elija la ciudad del prospecto: la planta no tiene departamento.',
    );
  }
  const names = missing.map((field) => `"${field.title}" (${field.fieldId})`).join(', ');
  return configError(
    'BITRIX_REQUIRED_FIELD',
    `Bitrix24 exige ${names} en Prospectos y ServiceMET no lo tiene configurado.`,
  );
}

function toId(value) {
  const number = Number(value);
  return Number.isInteger(number) && number > 0 ? number : null;
}

function items(body) {
  const list = body?.result?.items;
  return Array.isArray(list) ? list : [];
}

/** Primer teléfono o correo de los multicampos (`fm` o el formato antiguo). */
function firstCommunication(item, type) {
  const fm = Array.isArray(item.fm) ? item.fm : [];
  const fromFm = fm.find((entry) => String(entry.typeId ?? entry.TYPE_ID).toUpperCase() === type);
  if (fromFm) return String(fromFm.value ?? fromFm.VALUE ?? '');
  const legacy = item[type.toLowerCase()] ?? item[type];
  if (Array.isArray(legacy) && legacy.length) return String(legacy[0].VALUE ?? legacy[0].value ?? '');
  return '';
}

function stageSemantics(status) {
  const semantics = String(status.SEMANTICS ?? '').toUpperCase();
  if (semantics === 'S') return 'success';
  if (semantics === 'F') return 'failure';
  const extra = String(status.EXTRA?.SEMANTICS ?? '').toLowerCase();
  if (['success', 'failure', 'apology'].includes(extra)) return extra;
  return 'process';
}

/**
 * Capa responsable exclusivamente de hablar con Bitrix24.
 *
 * Los metadatos (etapas, fuentes y campos de los Leads) se guardan en memoria
 * durante `metadataCacheMs` para no gastar el límite de solicitudes de
 * Bitrix en cada oportunidad. Un error nunca queda en caché.
 */
function createBitrixService({ client, config, now = () => Date.now() }) {
  const cache = new Map();
  const inFlight = new Map();

  function cached(key, loader) {
    const entry = cache.get(key);
    if (entry && entry.expiresAt > now()) return entry.promise;
    const promise = loader().catch((error) => {
      cache.delete(key);
      throw error;
    });
    cache.set(key, { promise, expiresAt: now() + config.metadataCacheMs });
    return promise;
  }

  /** Serializa operaciones con la misma clave (doble envío simultáneo). */
  async function withLock(key, operation) {
    while (inFlight.has(key)) {
      try {
        await inFlight.get(key);
      } catch (_) {
        // El resultado del intento anterior no importa; se vuelve a comprobar.
      }
    }
    const promise = operation();
    inFlight.set(key, promise);
    try {
      return await promise;
    } finally {
      inFlight.delete(key);
    }
  }

  async function searchCompanies(query, { limit = 20 } = {}) {
    const text = String(query ?? '').replace(/\s+/g, ' ').trim();
    if (text.length < 2) throw validationError('q', 'Escriba al menos 2 letras para buscar.');
    if (text.length > 80) throw validationError('q', 'La búsqueda no puede superar 80 caracteres.');
    const body = await client.call('crm.item.list', {
      entityTypeId: ENTITY.company,
      select: ['id', 'title', 'companyTypeId', 'industry'],
      filter: { '%title': text },
      order: { title: 'ASC' },
      start: 0,
    });
    const found = items(body)
      .map((item) => ({
        id: toId(item.id),
        title: String(item.title ?? '').trim(),
        companyTypeId: item.companyTypeId ? String(item.companyTypeId) : null,
        industry: item.industry ? String(item.industry) : null,
      }))
      .filter((company) => company.id);
    const total = Number.isInteger(body?.total) ? body.total : found.length;
    const max = Math.min(Math.max(Number(limit) || 20, 1), PAGE_SIZE);
    return { items: found.slice(0, max), total, truncated: total > max };
  }

  async function contactIdsOfCompany(companyId) {
    const body = await client.call('crm.company.contact.items.get', { id: companyId });
    const bindings = Array.isArray(body?.result) ? body.result : [];
    const primary = new Set();
    const ids = [];
    for (const binding of bindings) {
      const id = toId(binding.CONTACT_ID);
      if (!id || ids.includes(id)) continue;
      ids.push(id);
      if (String(binding.IS_PRIMARY).toUpperCase() === 'Y') primary.add(id);
    }
    return { ids, primary };
  }

  async function getContactsByCompany(companyIdValue) {
    const companyId = toId(companyIdValue);
    if (!companyId) throw validationError('companyId', 'Empresa de Bitrix24 inválida.');
    const { ids, primary } = await contactIdsOfCompany(companyId);
    const wanted = ids.slice(0, MAX_CONTACTS);
    const contacts = [];
    for (let index = 0; index < wanted.length; index += PAGE_SIZE) {
      const body = await client.call('crm.item.list', {
        entityTypeId: ENTITY.contact,
        // `fm` (teléfonos y correos) solo llega con '*'.
        select: ['*'],
        filter: { '@id': wanted.slice(index, index + PAGE_SIZE) },
        start: 0,
      });
      for (const item of items(body)) {
        const id = toId(item.id);
        if (!id) continue;
        contacts.push({
          id,
          name: String(item.name ?? '').trim(),
          secondName: String(item.secondName ?? '').trim(),
          lastName: String(item.lastName ?? '').trim(),
          post: String(item.post ?? '').trim(),
          phone: firstCommunication(item, 'PHONE'),
          email: firstCommunication(item, 'EMAIL'),
          isPrimary: primary.has(id),
        });
      }
    }
    contacts.sort((a, b) => Number(b.isPrimary) - Number(a.isPrimary) ||
      `${a.name} ${a.lastName}`.localeCompare(`${b.name} ${b.lastName}`, 'es'));
    return { items: contacts, total: ids.length, truncated: ids.length > MAX_CONTACTS };
  }

  function statusList(entityId) {
    return cached(`status:${entityId}`, async () => {
      const body = await client.call('crm.status.list', {
        filter: { ENTITY_ID: entityId },
        order: { SORT: 'ASC' },
      });
      const statuses = Array.isArray(body?.result) ? body.result : [];
      return statuses
        .map((status) => ({
          statusId: String(status.STATUS_ID ?? ''),
          name: String(status.NAME ?? ''),
          sort: Number(status.SORT ?? 0),
          semantics: stageSemantics(status),
        }))
        .filter((status) => status.statusId)
        .sort((a, b) => a.sort - b.sort);
    });
  }

  /** Columnas del kanban de Prospectos: "Sin asignar", "En Progreso"... */
  function getLeadStages() {
    return statusList(LEAD_STAGES_ENTITY_ID);
  }

  /** Fuentes de los Leads (para BITRIX_LEAD_SOURCE_ID). */
  function getLeadSources() {
    return statusList(SOURCES_ENTITY_ID);
  }

  function getLeadFields() {
    return cached('leadFields', async () => {
      const body = await client.call('crm.item.fields', { entityTypeId: ENTITY.lead });
      const fields = body?.result?.fields && typeof body.result.fields === 'object'
        ? body.result.fields
        : {};
      return Object.entries(fields).map(([id, field]) => ({
        id,
        title: String(field.title ?? field.formLabel ?? field.listLabel ?? id),
        type: String(field.type ?? ''),
        upperName: field.upperName ? String(field.upperName) : null,
        isRequired: Boolean(field.isRequired),
        isReadOnly: Boolean(field.isReadOnly),
        isMultiple: Boolean(field.isMultiple),
        isCustom: id.startsWith('ufCrm'),
        items: Array.isArray(field.items) ? field.items : undefined,
      }));
    });
  }

  /**
   * Etapa inicial real de Prospectos: la configurada (si existe en Bitrix24)
   * o la primera "en curso" según su orden. Si no se encuentra, se descarta
   * la lista en caché: el administrador puede corregir las etapas y el
   * siguiente intento debe verlo.
   */
  function resolveTarget() {
    return cached('target', () => findTarget().catch((error) => {
      cache.delete(`status:${LEAD_STAGES_ENTITY_ID}`);
      throw error;
    }));
  }

  async function findTarget() {
    const stages = await getLeadStages();
    let stage;
    if (config.stageId) {
      stage = stages.find((candidate) => candidate.statusId === config.stageId);
      if (!stage) {
        throw configError(
          'BITRIX_STAGE_NOT_FOUND',
          `La etapa ${config.stageId} (BITRIX_LEAD_STAGE_ID) no existe en Prospectos.`,
        );
      }
    } else {
      stage = stages.find((candidate) => candidate.semantics === 'process');
      if (!stage) {
        throw configError(
          'BITRIX_STAGE_NOT_FOUND',
          'No se encontró una etapa en curso en Prospectos. ¿Están habilitados los Leads (modo CRM clásico)?',
        );
      }
    }
    return { stageId: stage.statusId, stageName: stage.name };
  }

  async function findByOrigin(uuid) {
    const body = await client.call('crm.item.list', {
      entityTypeId: ENTITY.lead,
      select: ['id', 'stageId'],
      filter: { originatorId: ORIGINATOR_ID, originId: uuid },
      start: 0,
    });
    const [existing] = items(body);
    return existing && toId(existing.id) ? existing : null;
  }

  async function createOpportunity(input, { user } = {}) {
    const opportunity = validateOpportunity(input);
    return withLock(opportunity.uuid, async () => {
      if (config.dedupeByOrigin) {
        const existing = await findByOrigin(opportunity.uuid);
        if (existing) {
          return {
            leadId: toId(existing.id),
            duplicate: true,
            stageId: existing.stageId ? String(existing.stageId) : null,
            mappedFields: [],
            warnings: [],
            opportunity,
          };
        }
      }

      const target = await resolveTarget();
      const leadFields = new Map((await getLeadFields()).map((field) => [field.id, field]));

      if (opportunity.contactId) {
        const { ids } = await contactIdsOfCompany(opportunity.companyId);
        if (!ids.includes(opportunity.contactId)) {
          throw validationError('contactId', 'El contacto no pertenece a la empresa seleccionada.');
        }
      }

      const { payload, mapped, warnings, missingRequired } = buildLeadPayload({
        opportunity,
        target,
        leadFields,
        config,
        user,
      });
      if (missingRequired.length) throw missingRequiredError(missingRequired, opportunity);
      const body = await client.call('crm.item.add', payload);
      const leadId = toId(body?.result?.item?.id);
      if (!leadId) {
        throw new BitrixError('Bitrix24 no devolvió el número del prospecto.', {
          code: 'BITRIX_INVALID_RESPONSE',
          statusCode: 502,
        });
      }
      return {
        leadId,
        duplicate: false,
        stageId: target.stageId,
        mappedFields: mapped,
        warnings,
        // La oportunidad validada, para dejar constancia en form_bitrix.
        opportunity,
      };
    });
  }

  /**
   * Opciones que el formulario de la app toma de Bitrix24: hoy, las
   * ciudades de la lista configurada en BITRIX_FIELD_CIUDAD.
   */
  async function formOptions() {
    const cityFieldId = config.fieldMap?.ciudad;
    const field = cityFieldId
      ? (await getLeadFields()).find((candidate) => candidate.id === cityFieldId)
      : null;
    if (!field) return { city: null };
    const options = (field.items ?? [])
      .map((item) => String(item.VALUE ?? item.value ?? '').trim())
      .filter(Boolean);
    return { city: { required: field.isRequired, options } };
  }

  async function status() {
    const target = await resolveTarget();
    const fields = await getLeadFields();
    const byId = new Map(fields.map((field) => [field.id, field]));
    return {
      configured: true,
      entity: 'lead',
      target,
      dedupeByOrigin: config.dedupeByOrigin,
      mapping: Object.fromEntries(
        Object.entries(config.fieldMap ?? {}).map(([key, fieldId]) => [
          key,
          { field: fieldId, exists: byId.has(fieldId), type: byId.get(fieldId)?.type ?? null },
        ]),
      ),
    };
  }

  return {
    createOpportunity,
    formOptions,
    getContactsByCompany,
    getLeadFields,
    getLeadSources,
    getLeadStages,
    resolveTarget,
    searchCompanies,
    status,
  };
}

module.exports = { ENTITY, createBitrixService };
