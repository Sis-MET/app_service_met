'use strict';

/** Error de los formularios adicionales, con código estable para la app. */
class ExtrasError extends Error {
  constructor(message, { code, statusCode = 400, details } = {}) {
    super(message);
    this.name = 'ExtrasError';
    this.code = code;
    this.statusCode = statusCode;
    this.details = details;
    this.expose = true;
  }
}

const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const KEY_PATTERN = /^[A-Za-z][A-Za-z0-9_]{0,39}$/;
const PNG_SIGNATURE = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);

/** La firma es un PNG pequeño; nada legítimo se acerca a este tamaño. */
const MAX_SIGNATURE_BYTES = 1024 * 1024;
const MAX_INVENTORY_ITEMS = 60;
const MAX_OTHER_ITEMS = 30;

const SERVICE_TYPES = Object.freeze(['calibracion', 'soporte', 'directo']);

/**
 * Código del RIM numerado por talonarios: `RIM-{AA}-{NNNN}` ("RIM-26-0042").
 * AA es la gestión y NNNN el número, único en la gestión para todos los RIM.
 */
const RIM_CODE_PATTERN = /^RIM-(\d{2})-(\d{4,5})$/;

/**
 * Código anterior a la numeración, `RIM-{planta}-{AA}` ("RIM-0103-11-26"):
 * se acepta para subir los RIM emitidos con versiones anteriores de la app.
 */
const LEGACY_RIM_CODE_PATTERN = /^RIM-[0-9A-Za-z][0-9A-Za-z-]{0,48}-\d{2}$/;

/** Bolivia no tiene horario de verano: UTC−4 todo el año. */
const LA_PAZ_OFFSET_MS = -4 * 60 * 60 * 1000;

/** Motivos con los que la app cierra un talonario que ya no usará. */
const APP_CLOSURE_REASONS = Object.freeze(['fin_gestion']);

const COMPONENT_STATES = Object.freeze(['present', 'missing', 'na']);
const DAMAGE_LEVELS = Object.freeze(['excellent', 'good', 'fair', 'poor', 'critical']);
const CLEANLINESS_LEVELS = Object.freeze(['clean', 'light', 'moderate', 'heavy']);

/** Datos del servicio que acompañan al RIM y su longitud máxima. */
const SERVICE_TEXT_FIELDS = Object.freeze({
  serviceName: 100,
  seca: 60,
  sessionId: 60,
  clientCode: 30,
  clientName: 255,
  clientLegalName: 255,
  plantCode: 30,
  plantName: 255,
  plantAddress: 255,
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
});

function cleanText(value, max) {
  if (value === null || value === undefined) return '';
  if (typeof value !== 'string' && typeof value !== 'number') return null;
  const output = String(value).replace(/\r\n?/g, '\n').trim();
  return output.length > max ? null : output;
}

function isPlainObject(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

/** Fecha y hora de [date] en La Paz, en los campos UTC de otra fecha. */
function laPazParts(date) {
  const local = new Date(date.getTime() + LA_PAZ_OFFSET_MS);
  return { year: local.getUTCFullYear(), month: local.getUTCMonth() + 1 };
}

/**
 * Gestión y número de un código `RIM-AA-NNNN`, o null si el código no tiene
 * ese formato (por ejemplo, el código anterior).
 */
function parseRimCode(code) {
  const match = RIM_CODE_PATTERN.exec(String(code ?? '').trim());
  if (!match) return null;
  const number = Number(match[2]);
  if (!Number.isSafeInteger(number) || number < 1) return null;
  return { year: 2000 + Number(match[1]), number };
}

/** `RIM-26-0042` para la gestión 2026 y el número 42. */
function formatRimCode(year, number) {
  return `RIM-${String(year % 100).padStart(2, '0')}-${String(number).padStart(4, '0')}`;
}

function isUuid(value) {
  return UUID_PATTERN.test(String(value ?? '').trim());
}

function validationError(subject, errors) {
  return new ExtrasError(`Los datos ${subject} están incompletos o no son válidos.`, {
    code: 'VALIDATION_ERROR',
    statusCode: 400,
    details: errors,
  });
}

/**
 * Valida y normaliza un RIM enviado por la app. Devuelve solo lo que se
 * guarda; cualquier clave desconocida se descarta.
 */
function validateRim(input) {
  const errors = [];
  const fail = (field, message) => errors.push({ field, message });
  const body = isPlainObject(input) ? input : {};

  const text = (field, max, { required = false, min = 1, label } = {}) => {
    const value = cleanText(body[field], max);
    if (value === null) {
      fail(field, `${label ?? field}: valor inválido o mayor a ${max} caracteres.`);
      return '';
    }
    if (required && value.length < min) fail(field, `Falta ${label ?? field}.`);
    return value;
  };

  const uuid = String(body.uuid ?? '').trim();
  if (!UUID_PATTERN.test(uuid)) fail('uuid', 'Identificador de RIM inválido.');

  const code = text('code', 60, { required: true, label: 'el código del RIM' });
  // Numerado por talonario (RIM-AA-NNNN) o, en RIM emitidos antes de la
  // numeración, el código anterior: este no tiene número ni talonario.
  const numbering = parseRimCode(code);
  if (code && !numbering && !LEGACY_RIM_CODE_PATTERN.test(code)) {
    fail('code', 'El código del RIM no tiene un formato válido.');
  }
  const installationId = String(body.installationId ?? '').trim().toLowerCase();
  if (numbering && !isUuid(installationId)) {
    fail('installationId', 'Falta la instalación de la app que emitió el RIM.');
  }

  const rawService = isPlainObject(body.service) ? body.service : null;
  const service = {};
  if (!rawService) {
    fail('service', 'Faltan los datos del servicio.');
  } else {
    service.serviceType = String(rawService.serviceType ?? '').trim();
    if (!SERVICE_TYPES.includes(service.serviceType)) {
      fail('service.serviceType', 'El tipo de servicio debe ser calibracion, soporte o directo.');
    }
    for (const [field, max] of Object.entries(SERVICE_TEXT_FIELDS)) {
      const value = cleanText(rawService[field], max);
      if (value === null) fail(`service.${field}`, `Valor inválido o mayor a ${max} caracteres.`);
      else service[field] = value;
    }
    if (!service.metricCode) fail('service.metricCode', 'Falta el código métrica del instrumento.');
  }

  const reason = text('reason', 2000, { required: true, min: 5, label: 'el motivo de la recepción' });

  const inventory = { items: {}, quantities: {}, others: [] };
  const rawItems = isPlainObject(body.inventory) ? body.inventory : {};
  if (Object.keys(rawItems).length > MAX_INVENTORY_ITEMS) {
    fail('inventory', 'Demasiados componentes en el inventario.');
  } else {
    for (const [key, state] of Object.entries(rawItems)) {
      if (!KEY_PATTERN.test(key) || !COMPONENT_STATES.includes(state)) {
        fail('inventory', `Componente o estado inválido: ${String(key).slice(0, 40)}.`);
        break;
      }
      inventory.items[key] = state;
    }
  }
  const rawQuantities = isPlainObject(body.quantities) ? body.quantities : {};
  for (const [key, quantity] of Object.entries(rawQuantities).slice(0, MAX_INVENTORY_ITEMS)) {
    const value = cleanText(quantity, 10);
    if (!KEY_PATTERN.test(key) || value === null || !/^\d*$/.test(value)) {
      fail('quantities', `Cantidad inválida: ${String(key).slice(0, 40)}.`);
      break;
    }
    if (value) inventory.quantities[key] = value;
  }
  const rawOthers = Array.isArray(body.otherItems) ? body.otherItems : [];
  if (rawOthers.length > MAX_OTHER_ITEMS) {
    fail('otherItems', 'Demasiados componentes adicionales.');
  } else {
    for (const item of rawOthers) {
      const name = isPlainObject(item) ? cleanText(item.name, 80) : null;
      if (!name || !COMPONENT_STATES.includes(item.status)) {
        fail('otherItems', 'Componente adicional inválido.');
        break;
      }
      inventory.others.push({ name, status: item.status });
    }
  }
  const inventoryNotes = text('inventoryNotes', 1000);

  const damageLevel = String(body.damageLevel ?? '').trim();
  if (!DAMAGE_LEVELS.includes(damageLevel)) fail('damageLevel', 'Seleccione el estado general.');

  const damageTypes = {};
  const rawDamage = isPlainObject(body.damageTypes) ? body.damageTypes : {};
  for (const [type, places] of Object.entries(rawDamage).slice(0, 30)) {
    const valid = KEY_PATTERN.test(type) && Array.isArray(places) && places.length <= 30
      && places.every((place) => typeof place === 'string' && KEY_PATTERN.test(place));
    if (!valid) {
      fail('damageTypes', `Daño inválido: ${String(type).slice(0, 40)}.`);
      break;
    }
    damageTypes[type] = [...new Set(places)];
  }
  const damageDescription = text('damageDescription', 2000);

  const cleanlinessLevel = String(body.cleanlinessLevel ?? '').trim();
  if (!CLEANLINESS_LEVELS.includes(cleanlinessLevel)) {
    fail('cleanlinessLevel', 'Seleccione el nivel de suciedad.');
  }

  if (typeof body.functionalityTestPerformed !== 'boolean') {
    fail('functionalityTestPerformed', 'Indique si se realizaron pruebas de funcionamiento.');
  }
  const functionalityTestDescription = text('functionalityTestDescription', 2000);

  const contactName = text('contactName', 150, {
    required: true, min: 3, label: 'el nombre de quien entrega el instrumento',
  });
  const contactPosition = text('contactPosition', 100);
  const contactPhone = text('contactPhone', 30);
  const metricaRepresentative = text('metricaRepresentative', 150, {
    required: true, label: 'el representante de Métrica',
  });
  const receptionLocation = text('receptionLocation', 255, {
    required: true, label: 'el lugar de recepción',
  });
  const assignedTechnician = text('assignedTechnician', 150);

  const issuedAtText = cleanText(body.issuedAt, 40);
  const issuedAt = issuedAtText ? new Date(issuedAtText) : null;
  if (!issuedAt || Number.isNaN(issuedAt.getTime())) {
    fail('issuedAt', 'Fecha de emisión inválida.');
  } else if (numbering
      && numbering.year !== laPazParts(issuedAt).year
      && numbering.year !== issuedAt.getUTCFullYear()) {
    fail('code', 'La gestión del código no coincide con la fecha de emisión.');
  }

  // RIM anulado en el teléfono antes de subirlo: se sube igual, para que su
  // número no quede como un hueco, con quién lo anuló, cuándo y por qué.
  let voided = null;
  if (body.voided !== undefined && body.voided !== null) {
    const raw = isPlainObject(body.voided) ? body.voided : {};
    const by = cleanText(raw.by, 100);
    const voidReason = cleanText(raw.reason, 1000);
    const atText = cleanText(raw.at, 40);
    const at = atText ? new Date(atText) : null;
    if (!by) fail('voided.by', 'Falta quién anuló el RIM.');
    if (!voidReason || voidReason.length < 5) {
      fail('voided.reason', 'Falta el motivo de la anulación.');
    }
    if (!at || Number.isNaN(at.getTime())) fail('voided.at', 'Fecha de anulación inválida.');
    voided = { by: by || '', reason: voidReason || '', at };
  }

  /** Firma en PNG, enviada en base64. */
  const signature = (field, owner) => {
    const raw = typeof body[field] === 'string' ? body[field].trim() : '';
    if (!raw) {
      fail(field, `Falta la firma ${owner}.`);
      return null;
    }
    if (raw.length > Math.ceil(MAX_SIGNATURE_BYTES / 3) * 4 + 4
        || !/^[A-Za-z0-9+/]+={0,2}$/.test(raw)) {
      fail(field, `La firma ${owner} no es válida.`);
      return null;
    }
    const png = Buffer.from(raw, 'base64');
    if (png.length > MAX_SIGNATURE_BYTES
        || !png.subarray(0, PNG_SIGNATURE.length).equals(PNG_SIGNATURE)) {
      fail(field, `La firma ${owner} debe ser una imagen PNG.`);
      return null;
    }
    return png;
  };
  const clientSignature = signature('clientSignature', 'del cliente');
  // Un RIM de prueba anterior a la segunda firma solo se acepta anulado.
  const metricaSignature = voided && !body.metricaSignature
    ? null
    : signature('metricaSignature', 'del representante de Métrica');

  const createdBy = cleanText(body.createdBy, 100);
  const appVersion = cleanText(body.appVersion, 30);

  if (errors.length) throw validationError('del RIM', errors);

  return {
    uuid: uuid.toLowerCase(),
    code,
    numbering,
    installationId: isUuid(installationId) ? installationId : null,
    voided,
    service,
    reason,
    inventory,
    inventoryNotes,
    damageLevel,
    damageTypes,
    damageDescription,
    cleanlinessLevel,
    functionalityTestPerformed: body.functionalityTestPerformed,
    functionalityTestDescription: body.functionalityTestPerformed
      ? functionalityTestDescription
      : '',
    contactName,
    contactPosition,
    contactPhone,
    metricaRepresentative,
    receptionLocation,
    assignedTechnician,
    issuedAt,
    createdBy: createdBy || '',
    appVersion: appVersion || '',
    clientSignature,
    metricaSignature,
  };
}

/**
 * Pedido de un talonario de números de RIM desde la app. Solo se entregan
 * talonarios de la gestión en curso y, en diciembre, de la siguiente.
 */
function validateTalonarioRequest(input, { now = new Date() } = {}) {
  const errors = [];
  const fail = (field, message) => errors.push({ field, message });
  const body = isPlainObject(input) ? input : {};

  const requestId = String(body.requestId ?? '').trim().toLowerCase();
  if (!isUuid(requestId)) fail('requestId', 'Identificador de solicitud inválido.');
  const installationId = String(body.installationId ?? '').trim().toLowerCase();
  if (!isUuid(installationId)) fail('installationId', 'Identificador de instalación inválido.');

  const year = Number(body.year);
  const today = laPazParts(now);
  const allowed = today.month === 12 ? [today.year, today.year + 1] : [today.year];
  if (!Number.isInteger(year) || !allowed.includes(year)) {
    fail('year', `Solo se entregan talonarios de la gestión ${allowed.join(' o ')}. Revise la fecha del teléfono.`);
  }

  const device = cleanText(body.device, 120);
  const appVersion = cleanText(body.appVersion, 30);
  if (device === null) fail('device', 'Dispositivo inválido.');
  if (appVersion === null) fail('appVersion', 'Versión inválida.');

  if (errors.length) throw validationError('del talonario', errors);
  return { requestId, installationId, year, device, appVersion };
}

/** Cierre de un talonario que la app ya no usará (fin de gestión). */
function validateTalonarioClosure(id, input) {
  const errors = [];
  const fail = (field, message) => errors.push({ field, message });
  const body = isPlainObject(input) ? input : {};

  const talonarioId = Number(id);
  if (!Number.isSafeInteger(talonarioId) || talonarioId <= 0) fail('id', 'Talonario inválido.');
  const installationId = String(body.installationId ?? '').trim().toLowerCase();
  if (!isUuid(installationId)) fail('installationId', 'Identificador de instalación inválido.');
  const lastUsed = body.lastUsed === null || body.lastUsed === undefined
    ? null
    : Number(body.lastUsed);
  if (lastUsed !== null && (!Number.isSafeInteger(lastUsed) || lastUsed < 1)) {
    fail('lastUsed', 'Último número usado inválido.');
  }
  const reason = String(body.reason ?? '').trim();
  if (!APP_CLOSURE_REASONS.includes(reason)) fail('reason', 'Motivo de cierre inválido.');

  if (errors.length) throw validationError('del cierre del talonario', errors);
  return { talonarioId, installationId, lastUsed, reason };
}

module.exports = {
  ExtrasError,
  MAX_SIGNATURE_BYTES,
  formatRimCode,
  parseRimCode,
  validateRim,
  validateTalonarioClosure,
  validateTalonarioRequest,
};
