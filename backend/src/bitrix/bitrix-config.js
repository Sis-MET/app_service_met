'use strict';

/**
 * Configuración de la integración con Bitrix24.
 *
 * Es opcional: si falta el webhook, la API sigue sirviendo calibración y
 * soporte y las rutas de Bitrix responden 503 BITRIX_NOT_CONFIGURED. Un valor
 * inválido tampoco detiene el servidor; queda en `configError`/`warnings`
 * para que se vea al iniciar sin exponer el secreto.
 */

/**
 * Mapeo centralizado ServiceMET → campo personalizado del Lead (Prospecto).
 *
 * Cada clave es un dato que ServiceMET conoce; el valor es la variable de
 * entorno donde se configura el ID real del campo en Bitrix (camelCase, tal
 * como lo devuelve `crm.item.fields`, p. ej. `ufCrm_1712345678`). Mientras una
 * variable esté vacía, o el campo no exista en Bitrix, el dato viaja dentro de
 * `comments` para no perderse.
 */
const FIELD_MAPPING_ENV = Object.freeze({
  serviceMetUuid: 'BITRIX_FIELD_SERVICEMET_UUID',
  tipoServicio: 'BITRIX_FIELD_TIPO_SERVICIO',
  seca: 'BITRIX_FIELD_SECA',
  clienteServiceMet: 'BITRIX_FIELD_CLIENTE_SERVICEMET',
  planta: 'BITRIX_FIELD_PLANTA',
  codigoMetrica: 'BITRIX_FIELD_CODIGO_METRICA',
  tipoEquipo: 'BITRIX_FIELD_TIPO_EQUIPO',
  marca: 'BITRIX_FIELD_MARCA',
  modelo: 'BITRIX_FIELD_MODELO',
  serie: 'BITRIX_FIELD_SERIE',
  capacidad: 'BITRIX_FIELD_CAPACIDAD',
  divisionEscala: 'BITRIX_FIELD_DIVISION_ESCALA',
  ubicacion: 'BITRIX_FIELD_UBICACION',
  tecnico: 'BITRIX_FIELD_TECNICO',
  tipoOportunidad: 'BITRIX_FIELD_TIPO_OPORTUNIDAD',
  prioridad: 'BITRIX_FIELD_PRIORIDAD',
  ciudad: 'BITRIX_FIELD_CIUDAD',
  mesServicio: 'BITRIX_FIELD_MES_SERVICIO',
});

const COMMENT_FORMATS = new Set(['text', 'bbcode', 'html']);
const CUSTOM_FIELD_PATTERN = /^ufCrm[A-Za-z0-9_]+$/;
const STATUS_ID_PATTERN = /^[A-Za-z0-9_:-]{1,50}$/;

function text(env, name) {
  const value = env[name];
  return typeof value === 'string' ? value.trim() : '';
}

function bool(env, name, fallback) {
  const value = text(env, name).toLowerCase();
  if (!value) return fallback;
  return value === 'true';
}

function integer(env, name, { fallback = null, min = 0, warnings }) {
  const raw = text(env, name);
  if (!raw) return fallback;
  if (!/^\d+$/.test(raw) || Number(raw) < min) {
    warnings.push(`${name} debe ser un entero mayor o igual a ${min}; se ignora.`);
    return fallback;
  }
  return Number(raw);
}

function statusId(env, name, warnings) {
  const raw = text(env, name);
  if (!raw) return null;
  if (!STATUS_ID_PATTERN.test(raw)) {
    warnings.push(`${name} tiene un formato inválido; se ignora.`);
    return null;
  }
  return raw;
}

/**
 * Normaliza la URL del webhook entrante. Acepta `BITRIX_WEBHOOK_URL` completa
 * o las tres partes `BITRIX_BASE_URL`, `BITRIX_USER_ID` y
 * `BITRIX_WEBHOOK_SECRET`. Devuelve siempre la URL terminada en `/`.
 */
function resolveWebhookUrl(env) {
  let raw = text(env, 'BITRIX_WEBHOOK_URL');
  if (!raw) {
    const base = text(env, 'BITRIX_BASE_URL').replace(/\/+$/, '');
    const userId = text(env, 'BITRIX_USER_ID');
    const secret = text(env, 'BITRIX_WEBHOOK_SECRET');
    if (!base && !userId && !secret) return { url: null };
    if (!base || !userId || !secret) {
      return {
        url: null,
        error: 'Faltan BITRIX_BASE_URL, BITRIX_USER_ID o BITRIX_WEBHOOK_SECRET.',
      };
    }
    raw = `${base}/rest/${userId}/${secret}/`;
  }

  let parsed;
  try {
    parsed = new URL(raw);
  } catch (_) {
    return { url: null, error: 'BITRIX_WEBHOOK_URL no es una URL válida.' };
  }
  if (parsed.protocol !== 'https:') {
    return { url: null, error: 'El webhook de Bitrix24 debe usar HTTPS.' };
  }
  const match = parsed.pathname.match(/^\/rest\/(\d+)\/([A-Za-z0-9]+)\/?$/);
  if (!match || parsed.search || parsed.hash) {
    return {
      url: null,
      error: 'BITRIX_WEBHOOK_URL debe tener la forma https://PORTAL/rest/USUARIO/SECRETO/.',
    };
  }
  return {
    url: `${parsed.origin}/rest/${match[1]}/${match[2]}/`,
    secret: match[2],
  };
}

function readFieldMap(env, warnings) {
  const map = {};
  for (const [key, envName] of Object.entries(FIELD_MAPPING_ENV)) {
    const value = text(env, envName);
    if (!value) continue;
    if (!CUSTOM_FIELD_PATTERN.test(value)) {
      warnings.push(
        `${envName}="${value}" no parece un campo personalizado en camelCase (ufCrm...); se ignora.`,
      );
      continue;
    }
    map[key] = value;
  }
  return Object.freeze(map);
}

function readBitrixConfig(env = process.env) {
  const warnings = [];
  const webhook = resolveWebhookUrl(env);
  const commentsFormat = text(env, 'BITRIX_COMMENTS_FORMAT').toLowerCase() || 'text';
  if (!COMMENT_FORMATS.has(commentsFormat)) {
    warnings.push('BITRIX_COMMENTS_FORMAT debe ser text, bbcode o html; se usa text.');
  }

  return Object.freeze({
    enabled: Boolean(webhook.url),
    configError: webhook.error ?? null,
    webhookUrl: webhook.url,
    webhookSecret: webhook.secret ?? null,
    // Etapa de Prospectos donde nace el Lead; vacía = primera "en curso".
    stageId: statusId(env, 'BITRIX_LEAD_STAGE_ID', warnings),
    sourceId: statusId(env, 'BITRIX_LEAD_SOURCE_ID', warnings),
    assignedById: integer(env, 'BITRIX_LEAD_ASSIGNED_BY_ID', { min: 1, warnings }),
    timeoutMs: integer(env, 'BITRIX_TIMEOUT_MS', { fallback: 15000, min: 1000, warnings }),
    metadataCacheMs: integer(env, 'BITRIX_METADATA_CACHE_MS', {
      fallback: 10 * 60 * 1000,
      warnings,
    }),
    dedupeByOrigin: bool(env, 'BITRIX_DEDUPE_BY_ORIGIN', true),
    commentsFormat: COMMENT_FORMATS.has(commentsFormat) ? commentsFormat : 'text',
    logRequests: bool(env, 'BITRIX_LOG_REQUESTS', (env.NODE_ENV || 'development') !== 'production'),
    fieldMap: readFieldMap(env, warnings),
    warnings: Object.freeze(warnings),
  });
}

module.exports = { FIELD_MAPPING_ENV, readBitrixConfig, resolveWebhookUrl };
