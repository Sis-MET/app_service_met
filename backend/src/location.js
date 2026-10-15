'use strict';

const { sql } = require('./database');
const { SERVICE_SUMMARY_TABLE } = require('./schema');

/*
  Ubicación GPS de cada servicio (calibración o soporte).

  El teléfono la captura al registrar la balanza y la envía aparte del
  registro técnico: en calibración, en `ubicaciones` (un elemento por registro,
  en el mismo orden); en soporte, en `ubicacion` dentro de cada sobre. Se
  guarda en el resumen DATA_SERVICIOS_DATOS, que tiene una fila por servicio
  de cualquier tipo, y no en las tablas de detalle. Un backend anterior ignora
  esos campos, así que la app y el backend pueden actualizarse en cualquier
  orden.

  La ubicación es un dato auxiliar: si llega incompleta o fuera de rango se
  descarta, pero nunca impide subir el registro técnico.
*/

const LOCATION_COLUMNS = Object.freeze([
  'latitud',
  'longitud',
  'precision_gps',
  'fecha_gps',
]);

// Si el resumen todavía no tiene las columnas (falta el script 013), se
// vuelve a consultar cada cinco minutos para no exigir reiniciar el backend.
const RECHECK_MS = 5 * 60 * 1000;
let support = { value: null, checkedAt: 0, warned: false };

function finiteNumber(raw) {
  if (raw === null || raw === undefined || raw === '') return null;
  const value = typeof raw === 'number' ? raw : Number(String(raw).trim().replace(',', '.'));
  return Number.isFinite(value) ? value : null;
}

function round(value, decimals) {
  const factor = 10 ** decimals;
  return Math.round(value * factor) / factor;
}

/**
 * Devuelve `{ latitud, longitud, precisionGps, fechaGps }` o null.
 * `fechaGps` es un Date (instante del fijado GPS en el teléfono).
 */
function normalizeLocation(raw) {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) return null;
  const latitud = finiteNumber(raw.latitud);
  const longitud = finiteNumber(raw.longitud);
  if (latitud === null || longitud === null) return null;
  if (latitud < -90 || latitud > 90 || longitud < -180 || longitud > 180) return null;
  // 0,0 es lo que devuelve un GPS sin fijado real, no una planta.
  if (latitud === 0 && longitud === 0) return null;

  const precision = finiteNumber(raw.precision_gps);
  const fecha = raw.fecha_gps ? new Date(String(raw.fecha_gps)) : null;
  return {
    latitud: round(latitud, 6),
    longitud: round(longitud, 6),
    // decimal(7,1): hasta 999 999,9 m.
    precisionGps: precision !== null && precision >= 0 && precision < 1e6
      ? round(precision, 1)
      : null,
    fechaGps: fecha && !Number.isNaN(fecha.getTime()) ? fecha : null,
  };
}

/** Ubicaciones de calibración: arreglo paralelo a `records`. */
function locationsByIndex(rawLocations, count) {
  const list = Array.isArray(rawLocations) ? rawLocations : [];
  return Array.from({ length: count }, (_, index) => normalizeLocation(list[index]));
}

async function summarySupportsLocation(executor) {
  const now = Date.now();
  if (support.value === true) return true;
  if (support.value === false && now - support.checkedAt < RECHECK_MS) return false;
  const request = new sql.Request(executor);
  const result = await request.query(`
    SELECT CASE WHEN ${LOCATION_COLUMNS.map((column) => `COL_LENGTH(N'dbo.${SERVICE_SUMMARY_TABLE}', N'${column}') IS NOT NULL`).join(' AND ')}
      THEN 1 ELSE 0 END AS [ok];
  `);
  const ok = Number(result.recordset[0]?.ok) === 1;
  if (!ok && !support.warned) {
    console.warn(
      `[ServiceMET] ${SERVICE_SUMMARY_TABLE} no tiene las columnas de ubicación. `
      + 'Ejecute backend/sql/013_add_service_location.sql; mientras tanto los '
      + 'servicios se suben sin coordenadas.',
    );
  }
  support = { value: ok, checkedAt: now, warned: support.warned || !ok };
  return ok;
}

/** Columnas y parámetros extra del INSERT del resumen. */
function summaryLocationSql(withLocation) {
  if (!withLocation) return { columns: '', values: '' };
  return {
    columns: ', [latitud], [longitud], [precision_gps], [fecha_gps]',
    values: ', @latitud, @longitud, @precisionGps, @fechaGps',
  };
}

function addLocationInputs(request, location) {
  request.input('latitud', sql.Decimal(9, 6), location?.latitud ?? null);
  request.input('longitud', sql.Decimal(9, 6), location?.longitud ?? null);
  request.input('precisionGps', sql.Decimal(7, 1), location?.precisionGps ?? null);
  request.input('fechaGps', sql.DateTimeOffset(0), location?.fechaGps ?? null);
}

function resetLocationSupportCache() {
  support = { value: null, checkedAt: 0, warned: false };
}

module.exports = {
  LOCATION_COLUMNS,
  addLocationInputs,
  locationsByIndex,
  normalizeLocation,
  resetLocationSupportCache,
  summaryLocationSql,
  summarySupportsLocation,
};
