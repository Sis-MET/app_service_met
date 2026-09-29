'use strict';

const { BitrixError } = require('./bitrix-client');

/** Identifica a ServiceMET como sistema de origen del Lead (`originatorId`). */
const ORIGINATOR_ID = 'SERVICEMET';
const SOURCE_DESCRIPTION = 'ServiceMET';

const SERVICE_TYPES = Object.freeze({
  calibracion: 'Calibración',
  soporte: 'Soporte técnico',
});

const PRIORITIES = Object.freeze({ baja: 'Baja', media: 'Media', alta: 'Alta' });

const MONTHS = Object.freeze([
  'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
  'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
]);

/**
 * Formas en que DataMET puede escribir el departamento de una planta, y la
 * ciudad que le corresponde en la lista "Ciudad del prospecto" de Bitrix24.
 * Se comparan sin mayúsculas ni tildes.
 */
const CITIES = Object.freeze([
  { name: 'La Paz', aliases: ['lp', 'lpz', 'el alto'] },
  { name: 'Cochabamba', aliases: ['cb', 'cba', 'cbb', 'cbba'] },
  { name: 'Santa Cruz', aliases: ['sc', 'scz', 'santa cruz de la sierra'] },
  { name: 'Oruro', aliases: ['or', 'oru'] },
  { name: 'Potosí', aliases: ['pt', 'pts', 'pot'] },
  { name: 'Sucre', aliases: ['chuquisaca', 'ch', 'chq', 'suc'] },
  { name: 'Tarija', aliases: ['tj', 'tja', 'tar'] },
  { name: 'Beni', aliases: ['bn', 'be', 'trinidad'] },
  { name: 'Pando', aliases: ['pd', 'pa', 'cobija'] },
]);

const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const TYPE_KEY_PATTERN = /^[a-z0-9_]{1,50}$/;

/** Datos del servicio que acepta la API y su longitud máxima. */
const SERVICE_TEXT_FIELDS = Object.freeze({
  serviceName: 100,
  seca: 60,
  sessionId: 60,
  clientName: 255,
  clientLegalName: 255,
  plantName: 255,
  plantDepartment: 120,
  metricCode: 80,
  equipmentType: 120,
  brand: 120,
  model: 120,
  serial: 120,
  capacity: 120,
  division: 120,
  unit: 20,
  location: 255,
  technician: 150,
  serviceDate: 30,
  capturedAt: 40,
});

function cleanText(value, max) {
  if (value === null || value === undefined) return '';
  if (typeof value !== 'string' && typeof value !== 'number') return null;
  const output = String(value).replace(/\r\n?/g, '\n').trim();
  return output.length > max ? null : output;
}

function positiveInteger(value) {
  const number = typeof value === 'string' && /^\d+$/.test(value.trim())
    ? Number(value.trim())
    : value;
  return Number.isInteger(number) && number > 0 ? number : null;
}

/**
 * Valida y normaliza lo que envía la app. Nunca confía en los nombres de
 * empresa o contacto para decidir nada: solo viajan como referencia.
 */
function validateOpportunity(input) {
  const errors = [];
  const fail = (field, message) => errors.push({ field, message });
  const body = input && typeof input === 'object' ? input : {};

  const uuid = String(body.uuid ?? '').trim();
  if (!UUID_PATTERN.test(uuid)) fail('uuid', 'Identificador de oportunidad inválido.');

  const companyId = positiveInteger(body.companyId);
  if (!companyId) fail('companyId', 'Seleccione la empresa de Bitrix24.');

  let contactId = null;
  if (body.contactId !== null && body.contactId !== undefined && body.contactId !== '') {
    contactId = positiveInteger(body.contactId);
    if (!contactId) fail('contactId', 'Contacto de Bitrix24 inválido.');
  }

  const type = body.opportunityType && typeof body.opportunityType === 'object'
    ? body.opportunityType
    : {};
  const typeKey = String(type.key ?? '').trim();
  const typeLabel = cleanText(type.label, 100);
  if (!TYPE_KEY_PATTERN.test(typeKey) || !typeLabel) {
    fail('opportunityType', 'Seleccione el tipo de oportunidad.');
  }
  // Línea comercial de Bitrix24 (VENTA, SOPORTE TECNICO, CALIBRACIÓN).
  const typeLine = cleanText(type.line, 60);
  if (typeLine === null) fail('opportunityType', 'Línea de oportunidad inválida.');

  // Ciudad elegida por el técnico; vacía = se deduce del departamento.
  const city = cleanText(body.city, 60);
  if (city === null) fail('city', 'Ciudad inválida.');

  const title = cleanText(body.title, 255);
  if (title === null) fail('title', 'El título no puede superar 255 caracteres.');
  else if (title.length < 3) fail('title', 'Escriba un título.');

  const description = cleanText(body.description, 4000);
  if (description === null) fail('description', 'La descripción no puede superar 4000 caracteres.');
  else if (description.length < 5) fail('description', 'Describa la oportunidad detectada.');

  const notes = cleanText(body.notes, 2000);
  if (notes === null) fail('notes', 'Las observaciones no pueden superar 2000 caracteres.');

  let priority = null;
  if (body.priority !== null && body.priority !== undefined && body.priority !== '') {
    priority = String(body.priority).trim().toLowerCase();
    if (!PRIORITIES[priority]) fail('priority', 'La prioridad debe ser baja, media o alta.');
  }

  const rawService = body.service && typeof body.service === 'object' ? body.service : null;
  const service = {};
  if (!rawService) {
    fail('service', 'Faltan los datos del servicio.');
  } else {
    service.serviceType = String(rawService.serviceType ?? '').trim();
    if (!SERVICE_TYPES[service.serviceType]) {
      fail('service.serviceType', 'El tipo de servicio debe ser calibracion o soporte.');
    }
    for (const [field, max] of Object.entries(SERVICE_TEXT_FIELDS)) {
      const value = cleanText(rawService[field], max);
      if (value === null) fail(`service.${field}`, `Valor inválido o mayor a ${max} caracteres.`);
      else service[field] = value;
    }
  }

  const appVersion = cleanText(body.appVersion, 30);
  const createdAt = cleanText(body.createdAt, 40);

  if (errors.length) {
    throw new BitrixError('Los datos de la oportunidad están incompletos o no son válidos.', {
      code: 'VALIDATION_ERROR',
      statusCode: 400,
      details: errors,
    });
  }

  return {
    uuid: uuid.toLowerCase(),
    companyId,
    companyName: cleanText(body.companyName, 255) || '',
    contactId,
    contactName: cleanText(body.contactName, 255) || '',
    opportunityType: { key: typeKey, label: typeLabel, line: typeLine || '' },
    city: city || '',
    title,
    description,
    notes: notes || '',
    priority,
    service,
    appVersion: appVersion || '',
    createdAt: createdAt || '',
  };
}

function serviceLabel(service) {
  const base = SERVICE_TYPES[service.serviceType] || service.serviceType;
  if (!service.serviceName || service.serviceName === base) return base;
  return `${base} - ${service.serviceName}`;
}

function withUnit(value, unit) {
  if (!value) return '';
  if (!unit || /[a-z]\s*$/i.test(value)) return value;
  return `${value} ${unit}`;
}

/**
 * Ciudad de Bitrix24 para un departamento de DataMET ("LA PAZ", "LPZ",
 * "Chuquisaca" → "Sucre"). Vacío si no se reconoce: nunca se adivina.
 */
function cityFromDepartment(department) {
  const wanted = normalizeName(department);
  if (!wanted) return '';
  const city = CITIES.find((candidate) =>
    normalizeName(candidate.name) === wanted || candidate.aliases.includes(wanted));
  return city ? city.name : '';
}

/** Mes en español de una fecha AAAA-MM-DD o ISO. */
function monthName(...dates) {
  for (const date of dates) {
    const match = /^\d{4}-(\d{2})-\d{2}/.exec(String(date ?? ''));
    const month = match ? Number(match[1]) : 0;
    if (month >= 1 && month <= 12) return MONTHS[month - 1];
  }
  return '';
}

/** Valores de ServiceMET que pueden ir a campos personalizados. */
function mappableValues(opportunity) {
  const { service } = opportunity;
  const client = service.clientName || service.clientLegalName;
  return {
    serviceMetUuid: opportunity.uuid,
    tipoServicio: serviceLabel(service),
    seca: service.seca,
    clienteServiceMet: client,
    planta: [service.plantName, service.plantDepartment].filter(Boolean).join(' - '),
    codigoMetrica: service.metricCode,
    tipoEquipo: service.equipmentType,
    marca: service.brand,
    modelo: service.model,
    serie: service.serial,
    capacidad: withUnit(service.capacity, service.unit),
    divisionEscala: withUnit(service.division, service.unit),
    ubicacion: service.location,
    tecnico: service.technician,
    tipoOportunidad: opportunity.opportunityType.line,
    prioridad: opportunity.priority ? PRIORITIES[opportunity.priority] : '',
    ciudad: opportunity.city || cityFromDepartment(service.plantDepartment),
    mesServicio: monthName(service.serviceDate, service.capturedAt, opportunity.createdAt),
  };
}

/** Secciones legibles de `comments`; cada línea puede ir a un campo propio. */
function commentSections(opportunity, values, user) {
  const { service } = opportunity;
  const secaLabel = service.serviceType === 'soporte' ? 'OTST' : 'SECA';
  const registeredBy = [values.tecnico, user ? `(usuario ${user})` : '']
    .filter(Boolean)
    .join(' ');
  return [
    {
      title: 'SERVICIO',
      lines: [
        ['tipoServicio', 'Tipo de servicio', values.tipoServicio],
        ['seca', secaLabel, values.seca],
        [null, 'Fecha del servicio', service.serviceDate],
      ],
    },
    {
      title: 'CLIENTE SERVICEMET',
      lines: [
        ['clienteServiceMet', 'Cliente', values.clienteServiceMet],
        [null, 'Razón social', service.clientLegalName !== values.clienteServiceMet
          ? service.clientLegalName
          : ''],
        ['planta', 'Planta', values.planta],
        ['ciudad', 'Ciudad', values.ciudad],
      ],
    },
    {
      title: 'EQUIPO',
      lines: [
        ['codigoMetrica', 'Código métrica', values.codigoMetrica],
        ['tipoEquipo', 'Tipo', values.tipoEquipo],
        ['marca', 'Marca', values.marca],
        ['modelo', 'Modelo', values.modelo],
        ['serie', 'Serie', values.serie],
        ['capacidad', 'Capacidad', values.capacidad],
        ['divisionEscala', 'División', values.divisionEscala],
        ['ubicacion', 'Ubicación', values.ubicacion],
      ],
    },
    {
      title: 'OPORTUNIDAD',
      lines: [
        [null, 'Tipo', opportunity.opportunityType.label],
        ['tipoOportunidad', 'Línea', values.tipoOportunidad],
        ['prioridad', 'Prioridad', values.prioridad],
      ],
      paragraphs: [
        ['Descripción', opportunity.description],
        ['Observaciones', opportunity.notes],
      ],
    },
    {
      title: 'REGISTRO',
      lines: [
        ['tecnico', 'Registrado por', registeredBy],
        [null, 'Origen', ['ServiceMET', opportunity.appVersion].filter(Boolean).join(' ')],
        ['serviceMetUuid', 'ID ServiceMET', values.serviceMetUuid],
      ],
    },
  ];
}

function escapeHtml(value) {
  return String(value)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

/**
 * Descripción legible del prospecto. Los datos que ya viajan en un campo
 * personalizado ([skip]) no se repiten: `comments` queda para lo narrativo.
 */
function buildComments(opportunity, { values, skip = new Set(), format = 'text', user } = {}) {
  const sections = commentSections(opportunity, values ?? mappableValues(opportunity), user);
  const heading = 'OPORTUNIDAD GENERADA DESDE SERVICEMET';
  const blocks = [];
  const bold = (value) => {
    if (format === 'html') return `<b>${escapeHtml(value)}</b>`;
    if (format === 'bbcode') return `[B]${value}[/B]`;
    return value;
  };
  const plain = (value) => (format === 'html' ? escapeHtml(value) : value);
  const newline = format === 'html' ? '<br>' : '\n';

  blocks.push(bold(heading));
  for (const section of sections) {
    const lines = section.lines
      .filter(([key, , value]) => value && !(key && skip.has(key)))
      .map(([, label, value]) => `${plain(label)}: ${plain(value)}`);
    const paragraphs = (section.paragraphs ?? [])
      .filter(([, value]) => value)
      .map(([label, value]) => `${plain(label)}:${newline}${plain(value).split('\n').join(newline)}`);
    if (!lines.length && !paragraphs.length) continue;
    blocks.push([bold(section.title), ...lines, ...paragraphs].join(newline));
  }
  return blocks.join(newline + newline);
}

/**
 * Convierte un valor al formato del campo de Bitrix. Solo se escriben campos
 * de texto y listas (resolviendo el ID del ítem por su texto); cualquier otro
 * tipo se deja en `comments` en vez de arriesgar un dato mal convertido.
 */
function coerceFieldValue(field, value) {
  const type = String(field.type || '').toLowerCase();
  if (type === 'string' || type === 'text') return value;
  if (type === 'enumeration' || type === 'crm_status') {
    const wanted = normalizeName(value);
    const items = Array.isArray(field.items) ? field.items : [];
    const item = items.find((candidate) => normalizeName(candidate.VALUE ?? candidate.value) === wanted);
    return item ? String(item.ID ?? item.id) : undefined;
  }
  return undefined;
}

function normalizeName(value) {
  return String(value ?? '')
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .replace(/\s+/g, ' ')
    .trim()
    .toLowerCase();
}

/**
 * Arma el payload de `crm.item.add` para un Lead (entityTypeId 1), que en el
 * Bitrix24 en español aparece en CRM › Prospectos. Los Leads no tienen
 * pipelines: solo etapa (`stageId`, p. ej. la columna "Sin asignar").
 *
 * @param {object} args
 * @param {object} args.opportunity Resultado de [validateOpportunity].
 * @param {{stageId:string}} args.target Etapa inicial resuelta.
 * @param {Map<string, object>} args.leadFields Campos de `crm.item.fields`.
 * @param {object} args.config Configuración de Bitrix.
 * @param {string} [args.user] Usuario autenticado de ServiceMET.
 */
function buildLeadPayload({ opportunity, target, leadFields, config, user }) {
  const values = mappableValues(opportunity);
  const fields = {
    title: opportunity.title,
    stageId: target.stageId,
    // Con empresa o contacto existentes Bitrix24 lo marca como repetido.
    companyId: opportunity.companyId,
    sourceDescription: SOURCE_DESCRIPTION,
  };
  if (opportunity.contactId) fields.contactIds = [opportunity.contactId];
  if (config.sourceId) fields.sourceId = config.sourceId;
  if (config.assignedById) fields.assignedById = config.assignedById;
  if (config.dedupeByOrigin) {
    fields.originatorId = ORIGINATOR_ID;
    fields.originId = opportunity.uuid;
  }

  const mapped = [];
  const warnings = [];
  for (const [key, fieldId] of Object.entries(config.fieldMap ?? {})) {
    const value = values[key];
    if (!value) continue;
    const field = leadFields.get(fieldId);
    if (!field) {
      warnings.push(`El campo ${fieldId} (${key}) no existe en los Prospectos de Bitrix24.`);
      continue;
    }
    if (field.isReadOnly) {
      warnings.push(`El campo ${fieldId} (${key}) es de solo lectura.`);
      continue;
    }
    const converted = coerceFieldValue(field, value);
    if (converted === undefined) {
      warnings.push(`El campo ${fieldId} (${key}) es de tipo ${field.type} y no admite "${value}".`);
      continue;
    }
    fields[fieldId] = field.isMultiple ? [converted] : converted;
    mapped.push(key);
  }

  fields.comments = buildComments(opportunity, {
    values,
    skip: new Set(mapped),
    format: config.commentsFormat,
    user,
  });

  // Campos personalizados que Bitrix24 exige y quedaron sin valor: crear el
  // prospecto fallaría, así que se informa antes de llamar a Bitrix.
  const keyByField = new Map(Object.entries(config.fieldMap ?? {}).map(([key, id]) => [id, key]));
  const missingRequired = [...leadFields.values()]
    .filter((field) => field.isCustom && field.isRequired && !field.isReadOnly)
    .filter((field) => fields[field.id] === undefined)
    .map((field) => ({ key: keyByField.get(field.id) ?? null, fieldId: field.id, title: field.title }));

  return { payload: { entityTypeId: 1, fields }, mapped, warnings, missingRequired };
}

module.exports = {
  ORIGINATOR_ID,
  PRIORITIES,
  SERVICE_TYPES,
  buildComments,
  buildLeadPayload,
  cityFromDepartment,
  coerceFieldValue,
  mappableValues,
  monthName,
  normalizeName,
  validateOpportunity,
};
