'use strict';

const { isNewScaleCode } = require('../validation');

/** Código del servicio en DATA_SERVICIOS_DATOS.tipo_servicio. */
const TEMPERATURE_SERVICE_CODE = 'CAL.TE';

/** Límites de un registro: más que esto no es una medición de la app. */
const MAX_CHANNELS = 20;
const MAX_POINTS = 30;
const MAX_READINGS = 60000;
const MAX_CORRECTIONS = 5000;
const MAX_DETAILS = 50;

class TemperaturaError extends Error {
  constructor(message, { code, statusCode, details } = {}) {
    super(message);
    this.code = code;
    this.statusCode = statusCode;
    this.details = details;
    this.expose = true;
  }
}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const DATE = /^\d{4}-\d{2}-\d{2}$/;
const DATETIME = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,3})?(Z|[+-]\d{2}:\d{2})$/;

/**
 * Lee los campos de [source] según [spec] y deja los problemas en [issues].
 * Tipos: string (max), number (abs: valor absoluto máximo), int (min, max),
 * bool, date (AAAA-MM-DD), datetime (ISO con desfase), uuid, enum (values).
 */
function readFields(source, spec, prefix, issues) {
  const out = {};
  const object = source && typeof source === 'object' && !Array.isArray(source) ? source : {};
  for (const [field, rule] of Object.entries(spec)) {
    const name = prefix ? `${prefix}.${field}` : field;
    const raw = object[field];
    const empty = raw === undefined || raw === null || (typeof raw === 'string' && raw.trim() === '');
    if (empty) {
      if (rule.required) issues.push({ field: name, message: 'Falta el dato.' });
      out[field] = rule.type === 'bool' ? false : null;
      continue;
    }
    switch (rule.type) {
      case 'string': {
        const text = String(raw).trim();
        if (text.length > rule.max) {
          issues.push({ field: name, message: `Supera ${rule.max} caracteres.` });
        }
        out[field] = text;
        break;
      }
      case 'number': {
        const number = typeof raw === 'number' ? raw : Number(String(raw).replace(',', '.'));
        if (!Number.isFinite(number) || Math.abs(number) >= rule.abs) {
          issues.push({ field: name, message: 'No es un número válido.' });
        } else if (rule.min !== undefined && number < rule.min) {
          issues.push({ field: name, message: `Debe ser al menos ${rule.min}.` });
        }
        out[field] = number;
        break;
      }
      case 'int': {
        const number = Number(raw);
        if (!Number.isSafeInteger(number)
          || (rule.min !== undefined && number < rule.min)
          || (rule.max !== undefined && number > rule.max)) {
          issues.push({ field: name, message: 'No es un entero válido.' });
        }
        out[field] = number;
        break;
      }
      case 'bool':
        if (typeof raw !== 'boolean') issues.push({ field: name, message: 'Debe ser verdadero o falso.' });
        out[field] = raw === true;
        break;
      case 'date':
        if (!DATE.test(String(raw)) || Number.isNaN(Date.parse(String(raw)))) {
          issues.push({ field: name, message: 'Fecha inválida (AAAA-MM-DD).' });
        }
        out[field] = String(raw);
        break;
      case 'datetime':
        if (!DATETIME.test(String(raw)) || Number.isNaN(Date.parse(String(raw)))) {
          issues.push({ field: name, message: 'Fecha y hora inválida (ISO con desfase).' });
        }
        out[field] = String(raw);
        break;
      case 'uuid':
        if (!UUID.test(String(raw))) issues.push({ field: name, message: 'No es un UUID.' });
        out[field] = String(raw).toLowerCase();
        break;
      case 'enum':
        if (!rule.values.includes(raw)) {
          issues.push({ field: name, message: `Debe ser ${rule.values.join(', ')}.` });
        }
        out[field] = raw;
        break;
      default:
        throw new Error(`Tipo desconocido: ${rule.type}`);
    }
  }
  return out;
}

const HEADER = Object.freeze({
  uuid: { type: 'uuid', required: true },
  codigo_registro: { type: 'string', max: 100, required: true },
  seca: { type: 'string', max: 50, required: true },
  session_id: { type: 'string', max: 100, required: true },
  estado: { type: 'enum', values: ['finalizado'], required: true },
  cod_metrica: { type: 'string', max: 50, required: true },
  equipo_nuevo: { type: 'bool' },
  codigo_cliente: { type: 'string', max: 20 },
  cliente: { type: 'string', max: 255 },
  razon_social: { type: 'string', max: 255 },
  cod_planta: { type: 'string', max: 20 },
  planta: { type: 'string', max: 255 },
  dep: { type: 'string', max: 100 },
  dir: { type: 'string', max: 255 },
  tipo_equipo: { type: 'string', max: 60, required: true },
  instrumento: { type: 'string', max: 150 },
  marca: { type: 'string', max: 100 },
  modelo: { type: 'string', max: 100 },
  serie: { type: 'string', max: 100 },
  cod_interno: { type: 'string', max: 100 },
  ubicacion: { type: 'string', max: 255 },
  rango_min: { type: 'number', abs: 1e6, required: true },
  rango_max: { type: 'number', abs: 1e6, required: true },
  unidad: { type: 'enum', values: ['°C', '°F'], required: true },
  resolucion: { type: 'number', abs: 1e5, required: true },
  indicador: { type: 'string', max: 30 },
  temp_amb_inicio: { type: 'number', abs: 1e4 },
  hr_inicio: { type: 'number', abs: 1e4, min: 0 },
  temp_amb_fin: { type: 'number', abs: 1e4 },
  hr_fin: { type: 'number', abs: 1e4, min: 0 },
  fecha_servicio: { type: 'date', required: true },
  hora_inicio: { type: 'datetime' },
  hora_fin: { type: 'datetime' },
  finalizado_en: { type: 'datetime' },
  personal: { type: 'string', max: 150, required: true },
  observaciones: { type: 'string', max: 2000 },
  registro_sensores: { type: 'string', max: 255 },
  app_version: { type: 'string', max: 30 },
});

const PATRON = Object.freeze({
  n: { type: 'int', min: 1, max: 1000, required: true },
  cod_instrumento: { type: 'string', max: 50, required: true },
  instrumento: { type: 'string', max: 150 },
  cert_fecha: { type: 'string', max: 30 },
  ente_calibrador: { type: 'string', max: 150 },
  estado: { type: 'string', max: 50 },
  uso: { type: 'enum', values: ['temperatura', 'ambiente'], required: true },
});

const CANAL = Object.freeze({
  n_canal: { type: 'int', min: 1, max: 1000, required: true },
  nombre: { type: 'string', max: 60, required: true },
  rol: { type: 'enum', values: ['patron', 'equipo'], required: true },
  cod_patron: { type: 'string', max: 50 },
  posicion: { type: 'string', max: 100 },
  // externo: un sensor del patrón que graba en el software de su
  // registrador; la app no lo lee.
  metodo: { type: 'enum', values: ['camara', 'manual', 'externo'], required: true },
  decimales: { type: 'int', min: 0, max: 4, required: true },
});

const PUNTO = Object.freeze({
  n_punto: { type: 'int', min: 1, max: 1000, required: true },
  temperatura_nominal: { type: 'number', abs: 1e6, required: true },
  estabilizacion_min: { type: 'number', abs: 1e7, min: 0 },
  duracion_min: { type: 'number', abs: 1e7, min: 0, required: true },
  intervalo_s: { type: 'int', min: 1, max: 86400, required: true },
  lecturas_programadas: { type: 'int', min: 1, max: MAX_READINGS, required: true },
  estado: {
    type: 'enum',
    values: ['pendiente', 'en_curso', 'completo', 'interrumpido'],
    required: true,
  },
  inicio_medicion: { type: 'datetime' },
  fin_medicion: { type: 'datetime' },
  motivo_interrupcion: { type: 'string', max: 500 },
  observaciones: { type: 'string', max: 1000 },
});

const LECTURA = Object.freeze({
  n_punto: { type: 'int', min: 1, required: true },
  n_lectura: { type: 'int', min: 0, required: true },
  n_canal: { type: 'int', min: 1, required: true },
  tiempo_programado_s: { type: 'int', min: 0, required: true },
  capturada_en: { type: 'datetime', required: true },
  valor: { type: 'number', abs: 1e6 },
  valor_original: { type: 'number', abs: 1e6 },
  texto_leido: { type: 'string', max: 60 },
  origen: {
    type: 'enum',
    values: ['ocr_segmentos', 'ocr_texto', 'ocr_aguja', 'manual', 'sin_lectura'],
    required: true,
  },
  coincidencia: { type: 'number', abs: 10, min: 0 },
  cuadros: { type: 'int', min: 0, max: 32767 },
  alerta: { type: 'string', max: 100 },
  estado: { type: 'enum', values: ['valida', 'sin_lectura', 'excluida'], required: true },
  motivo: { type: 'string', max: 200 },
});

const CORRECCION = Object.freeze({
  n_punto: { type: 'int', min: 1, required: true },
  n_lectura: { type: 'int', min: 0, required: true },
  n_canal: { type: 'int', min: 1, required: true },
  tipo: { type: 'enum', values: ['correccion', 'exclusion', 'restitucion'], required: true },
  valor_anterior: { type: 'number', abs: 1e6 },
  valor_nuevo: { type: 'number', abs: 1e6 },
  motivo: { type: 'string', max: 500, required: true },
  usuario: { type: 'string', max: 150, required: true },
  fecha: { type: 'datetime', required: true },
});

function list(body, field, max, issues) {
  const value = body?.[field];
  if (value === undefined || value === null) return [];
  if (!Array.isArray(value)) {
    issues.push({ field, message: 'Debe ser una lista.' });
    return [];
  }
  if (value.length > max) {
    issues.push({ field, message: `Tiene más de ${max} elementos.` });
    return [];
  }
  return value;
}

/** Lecturas de un punto: en t = 0, i, 2i… hasta la duración (como la app). */
function scheduledReadings(durationMin, intervalS) {
  if (!(durationMin > 0) || !(intervalS > 0)) return 0;
  return Math.floor((durationMin * 60) / intervalS + 1e-9) + 1;
}

/**
 * Valida una calibración de temperatura completa. Devuelve el registro
 * normalizado y la lista de problemas (vacía si se puede insertar).
 */
function validateTemperatura(body) {
  const issues = [];
  if (!body || typeof body !== 'object' || Array.isArray(body)) {
    return { value: null, issues: [{ field: '', message: 'El cuerpo debe ser un objeto JSON.' }] };
  }
  const header = readFields(body, HEADER, '', issues);
  const patrones = list(body, 'patrones', 100, issues)
    .map((row, i) => readFields(row, PATRON, `patrones[${i}]`, issues));
  const canales = list(body, 'canales', MAX_CHANNELS, issues)
    .map((row, i) => readFields(row, CANAL, `canales[${i}]`, issues));
  const puntos = list(body, 'puntos', MAX_POINTS, issues)
    .map((row, i) => readFields(row, PUNTO, `puntos[${i}]`, issues));
  const lecturas = list(body, 'lecturas', MAX_READINGS, issues)
    .map((row, i) => readFields(row, LECTURA, `lecturas[${i}]`, issues));
  const correcciones = list(body, 'correcciones', MAX_CORRECTIONS, issues)
    .map((row, i) => readFields(row, CORRECCION, `correcciones[${i}]`, issues));

  // Coherencia de la cabecera.
  if (header.seca && header.cod_metrica
    && header.codigo_registro !== `${header.seca}-${header.cod_metrica}`) {
    issues.push({ field: 'codigo_registro', message: 'Debe ser SECA-COD_METRICA.' });
  }
  if (header.cod_metrica && isNewScaleCode(header.cod_metrica)) {
    issues.push({
      field: 'cod_metrica',
      message: 'El equipo tiene un código provisional: asígnele el código métrica de DataMET antes de subir.',
    });
  }
  if (Number.isFinite(header.rango_min) && Number.isFinite(header.rango_max)
    && header.rango_min >= header.rango_max) {
    issues.push({ field: 'rango_min', message: 'El mínimo debe ser menor que el máximo.' });
  }
  if (Number.isFinite(header.resolucion) && header.resolucion <= 0) {
    issues.push({ field: 'resolucion', message: 'La resolución debe ser mayor que cero.' });
  }
  if (!patrones.some((p) => p.uso === 'temperatura')) {
    issues.push({ field: 'patrones', message: 'Falta el patrón de temperatura.' });
  }
  const patronNs = new Set();
  for (const [i, p] of patrones.entries()) {
    if (patronNs.has(p.n)) issues.push({ field: `patrones[${i}].n`, message: 'Número repetido.' });
    patronNs.add(p.n);
  }

  const canalesPorN = new Map();
  for (const [i, c] of canales.entries()) {
    if (canalesPorN.has(c.n_canal)) {
      issues.push({ field: `canales[${i}].n_canal`, message: 'Canal repetido.' });
    }
    canalesPorN.set(c.n_canal, c);
  }
  if (!canales.some((c) => c.rol === 'patron')) {
    issues.push({ field: 'canales', message: 'Falta un canal del patrón.' });
  }

  const puntosPorN = new Map();
  for (const [i, p] of puntos.entries()) {
    if (puntosPorN.has(p.n_punto)) {
      issues.push({ field: `puntos[${i}].n_punto`, message: 'Punto repetido.' });
    }
    puntosPorN.set(p.n_punto, p);
    if (Number.isFinite(p.duracion_min) && Number.isSafeInteger(p.intervalo_s)
      && p.lecturas_programadas !== scheduledReadings(p.duracion_min, p.intervalo_s)) {
      issues.push({
        field: `puntos[${i}].lecturas_programadas`,
        message: 'No coincide con la duración y el intervalo.',
      });
    }
    if (p.estado === 'en_curso') {
      issues.push({ field: `puntos[${i}].estado`, message: 'El punto sigue en medición.' });
    }
    if (p.estado === 'interrumpido' && (p.motivo_interrupcion ?? '').length < 5) {
      issues.push({ field: `puntos[${i}].motivo_interrupcion`, message: 'Falta el motivo de la interrupción.' });
    }
    if ((p.estado === 'completo' || p.estado === 'interrumpido') && !p.inicio_medicion) {
      issues.push({ field: `puntos[${i}].inicio_medicion`, message: 'Falta la hora de inicio.' });
    }
  }
  if (!puntos.some((p) => p.estado === 'completo' || p.estado === 'interrumpido')) {
    issues.push({ field: 'puntos', message: 'Ningún punto se midió.' });
  }

  const claves = new Set();
  for (const [i, l] of lecturas.entries()) {
    const punto = puntosPorN.get(l.n_punto);
    if (!punto) {
      issues.push({ field: `lecturas[${i}].n_punto`, message: 'El punto no existe.' });
    } else {
      if (punto.estado === 'pendiente') {
        issues.push({ field: `lecturas[${i}].n_punto`, message: 'El punto no se midió.' });
      }
      if (Number.isSafeInteger(l.n_lectura) && l.n_lectura >= punto.lecturas_programadas) {
        issues.push({ field: `lecturas[${i}].n_lectura`, message: 'Fuera de las lecturas programadas.' });
      }
    }
    const canal = canalesPorN.get(l.n_canal);
    if (!canal) {
      issues.push({ field: `lecturas[${i}].n_canal`, message: 'El canal no existe.' });
    } else if (canal.metodo === 'externo') {
      issues.push({
        field: `lecturas[${i}].n_canal`,
        message: 'Ese sensor graba en su software: no lleva lecturas de la app.',
      });
    }
    const clave = `${l.n_punto}/${l.n_lectura}/${l.n_canal}`;
    if (claves.has(clave)) issues.push({ field: `lecturas[${i}]`, message: 'Lectura repetida.' });
    claves.add(clave);
    if (l.estado === 'sin_lectura' && l.valor !== null) {
      issues.push({ field: `lecturas[${i}].valor`, message: 'Una lectura sin valor no lleva valor.' });
    }
    if (l.estado !== 'sin_lectura' && l.valor === null) {
      issues.push({ field: `lecturas[${i}].valor`, message: 'Falta el valor.' });
    }
    if (l.coincidencia !== null && l.coincidencia > 1) {
      issues.push({ field: `lecturas[${i}].coincidencia`, message: 'Debe estar entre 0 y 1.' });
    }
  }

  for (const [i, c] of correcciones.entries()) {
    if (!claves.has(`${c.n_punto}/${c.n_lectura}/${c.n_canal}`)) {
      issues.push({ field: `correcciones[${i}]`, message: 'La lectura corregida no existe.' });
    }
    if ((c.motivo ?? '').length < 5) {
      issues.push({ field: `correcciones[${i}].motivo`, message: 'El motivo es muy corto.' });
    }
  }

  return {
    value: { header, patrones, canales, puntos, lecturas, correcciones, gps: body.gps ?? null },
    issues: issues.slice(0, MAX_DETAILS),
  };
}

module.exports = {
  MAX_READINGS,
  TEMPERATURE_SERVICE_CODE,
  TemperaturaError,
  scheduledReadings,
  validateTemperatura,
};
