'use strict';

const { sql } = require('./database');

/*
  Pasos de las cargas sustitutivas de linealidad (EURAMET cg-18 v4.0, 4.3.3;
  Guía SIM, 7.1.2.6).

  El teléfono los envía aparte del registro técnico, en `sustituciones`: un
  arreglo por registro, en el mismo orden que `records`. Cada paso trae lo
  que se leyó (la indicación de la carga sustitutiva sola) y los valores de
  las filas que usó al subir:

      carga sustitutiva = indicación sustitutiva − error de la referencia
      carga resultante  = carga base + carga sustitutiva       (= lin{fila})

  Se guardan en dbo.DATA_SERVICIOS_DATOS_CALIBRACION_SUSTITUCION (script
  018), en la misma transacción que el registro, para que DataMET+ pueda
  rehacer la cadena y su incertidumbre (NB/ISO/IEC 17025, 7.5.1 y 7.11.2).

  Un paso que no concuerda con el registro lo invalida: la carga de la fila no
  sería la que resulta de sus datos. Un backend anterior ignora el campo, por
  eso el orden de despliegue es script, backend y después la app.
*/

const SUBSTITUTION_TABLE = 'DATA_SERVICIOS_DATOS_CALIBRACION_SUSTITUCION';
const qualifiedSubstitutionTable = `[dbo].[${SUBSTITUTION_TABLE}]`;
const MAX_FILAS = 60;
// decimal(18,8): hasta 10 cifras enteras.
const MAX_ABS = 1e10;
const METODOS = Object.freeze({ M1: 'Método 1', M2: 'Método 2' });

const DECIMAL_FIELDS = Object.freeze([
  'indicacion_sustitutiva',
  'carga_referencia',
  'indicacion_referencia',
  'error_referencia',
  'carga_sustitutiva',
  'carga_base',
  'carga_resultante',
]);

function issue(column, value, code, message, expected) {
  return { column, value: value === undefined ? null : value, code, message, expected };
}

function finiteNumber(raw) {
  if (raw === null || raw === undefined || raw === '') return null;
  const value = typeof raw === 'number' ? raw : Number(String(raw).trim().replace(',', '.'));
  return Number.isFinite(value) ? value : null;
}

function integer(raw) {
  const value = finiteNumber(raw);
  return value !== null && Number.isInteger(value) ? value : null;
}

/** Decimales con que quedó escrita una carga: fija la tolerancia de redondeo. */
function decimalsOf(raw) {
  const text = String(raw ?? '').trim();
  const dot = text.indexOf('.');
  if (dot < 0) return 0;
  const exponent = text.search(/e/i);
  return (exponent < 0 ? text.length : exponent) - dot - 1;
}

const close = (a, b, tolerance = 1e-6) => Math.abs(a - b) <= tolerance;

/**
 * Valida los pasos de un registro contra sus columnas ya normalizadas.
 * Devuelve `{ pasos, issues }`; `pasos` va listo para insertar.
 */
function normalizeSubstitution(raw, normalized = {}) {
  if (raw === null || raw === undefined) return { pasos: [], issues: [] };
  if (!Array.isArray(raw)) {
    return {
      pasos: [],
      issues: [issue('sustituciones', raw, 'INVALID_SUBSTITUTION', 'Los pasos de sustitución deben ser una lista.', 'arreglo')],
    };
  }
  if (raw.length === 0) return { pasos: [], issues: [] };
  if (raw.length > MAX_FILAS) {
    return {
      pasos: [],
      issues: [issue('sustituciones', raw.length, 'INVALID_SUBSTITUTION', 'Hay más pasos de sustitución que filas de linealidad.', `máximo ${MAX_FILAS}`)],
    };
  }

  const issues = [];
  const pasos = [];
  const recordNumber = (column) => finiteNumber(normalized[column]);
  const metodoCarga = String(normalized.metodo_carga ?? '').trim();
  let filaAnterior = 0;

  raw.forEach((step, index) => {
    const at = (field) => `sustituciones[${index}].${field}`;
    if (!step || typeof step !== 'object' || Array.isArray(step)) {
      issues.push(issue(`sustituciones[${index}]`, step, 'INVALID_SUBSTITUTION', 'El paso de sustitución debe ser un objeto.', 'objeto JSON'));
      return;
    }
    const before = issues.length;
    const paso = integer(step.paso);
    const fila = integer(step.fila);
    const filaReferencia = integer(step.fila_referencia);
    const filaBase = integer(step.fila_base);
    const metodo = String(step.metodo ?? '').trim();

    if (paso !== index + 1) {
      issues.push(issue(at('paso'), step.paso, 'INVALID_SUBSTITUTION', 'Los pasos deben ir numerados en orden desde 1.', String(index + 1)));
    }
    if (fila === null || fila < 2 || fila > MAX_FILAS || fila <= filaAnterior) {
      issues.push(issue(at('fila'), step.fila, 'INVALID_SUBSTITUTION', 'La fila del paso no es válida o no sigue a la del paso anterior.', `entero creciente entre 2 y ${MAX_FILAS}`));
    }
    for (const [field, value] of [['fila_referencia', filaReferencia], ['fila_base', filaBase]]) {
      if (value === null || value < 1 || (fila !== null && value >= fila)) {
        issues.push(issue(at(field), step[field], 'INVALID_SUBSTITUTION', 'La fila usada debe estar antes de la fila del paso.', 'entero entre 1 y fila − 1'));
      }
    }
    if (!METODOS[metodo]) {
      issues.push(issue(at('metodo'), step.metodo, 'INVALID_SUBSTITUTION', 'Método de sustitución desconocido.', 'M1 o M2'));
    } else if (metodoCarga !== METODOS[metodo]) {
      issues.push(issue(at('metodo'), step.metodo, 'SUBSTITUTION_METHOD_MISMATCH', 'El método del paso no es el declarado en metodo_carga.', metodoCarga || 'Método 1 o Método 2'));
    } else if (fila !== null) {
      // Método 1: la referencia es la carga anterior; Método 2, la base.
      const anterior = metodo === 'M1' ? filaReferencia : filaBase;
      if (anterior !== fila - 1) {
        issues.push(issue(at(metodo === 'M1' ? 'fila_referencia' : 'fila_base'), anterior, 'SUBSTITUTION_METHOD_MISMATCH', `En el ${METODOS[metodo]} esta fila es la carga anterior.`, String(fila - 1)));
      }
    }

    const values = {};
    for (const field of DECIMAL_FIELDS) {
      const value = finiteNumber(step[field]);
      if (value === null || Math.abs(value) >= MAX_ABS) {
        issues.push(issue(at(field), step[field], 'INVALID_SUBSTITUTION', 'Falta el valor o no es un número válido.', 'número de hasta 10 cifras enteras'));
      } else {
        values[field] = value;
      }
    }

    let registradoEn = null;
    if (step.registrado_en !== null && step.registrado_en !== undefined && step.registrado_en !== '') {
      registradoEn = new Date(String(step.registrado_en));
      if (Number.isNaN(registradoEn.getTime())) {
        issues.push(issue(at('registrado_en'), step.registrado_en, 'INVALID_SUBSTITUTION', 'La hora del paso no es una fecha válida.', 'ISO-8601 con desfase'));
        registradoEn = null;
      }
    }

    if (issues.length === before) {
      // Lo que el paso dice de sus filas debe ser lo que dice el registro.
      const copies = [
        ['carga_resultante', `lin${fila}`],
        ['carga_referencia', `lin${filaReferencia}`],
        ['indicacion_referencia', `ind${filaReferencia}`],
        ['carga_base', `lin${filaBase}`],
      ];
      for (const [field, column] of copies) {
        const recorded = recordNumber(column);
        if (recorded === null || !close(recorded, values[field], 1e-8)) {
          issues.push(issue(at(field), step[field], 'SUBSTITUTION_MISMATCH', `No coincide con ${column} del registro.`, recorded === null ? `${column} registrado` : String(recorded)));
        }
      }
      if (!close(values.error_referencia, values.indicacion_referencia - values.carga_referencia)) {
        issues.push(issue(at('error_referencia'), step.error_referencia, 'SUBSTITUTION_MISMATCH', 'El error de la referencia no es su indicación menos su carga.', String(values.indicacion_referencia - values.carga_referencia)));
      }
      if (!close(values.carga_sustitutiva, values.indicacion_sustitutiva - values.error_referencia)) {
        issues.push(issue(at('carga_sustitutiva'), step.carga_sustitutiva, 'SUBSTITUTION_MISMATCH', 'La carga sustitutiva no es su indicación menos el error de la referencia.', String(values.indicacion_sustitutiva - values.error_referencia)));
      }
      // La carga resultante se registró con los decimales de d.
      const rounding = 0.5 * 10 ** -decimalsOf(normalized[`lin${fila}`]) + 1e-6;
      if (!close(values.carga_base + values.carga_sustitutiva, values.carga_resultante, rounding)) {
        issues.push(issue(at('carga_resultante'), step.carga_resultante, 'SUBSTITUTION_MISMATCH', 'La carga resultante no es la carga base más la carga sustitutiva.', String(values.carga_base + values.carga_sustitutiva)));
      }
    }

    if (fila !== null) filaAnterior = Math.max(filaAnterior, fila);
    if (issues.length === before) {
      pasos.push({ paso, fila, metodo, filaReferencia, filaBase, registradoEn, ...values });
    }
  });

  return { pasos: issues.length === 0 ? pasos : [], issues };
}

/** Agrega a cada registro validado sus pasos y, si los hay, sus errores. */
function addSubstitutionValidation(validation, rawSubstitutions) {
  const list = Array.isArray(rawSubstitutions) ? rawSubstitutions : [];
  for (const record of validation.records) {
    const { pasos, issues } = normalizeSubstitution(list[record.index], record.normalized);
    record.sustitucion = pasos;
    if (issues.length > 0) {
      record.errors = [...(record.errors ?? []), ...issues];
      record.valid = false;
    }
  }
  return validation;
}

// Si la tabla todavía no existe (falta el script 018), se vuelve a consultar
// cada minuto para no exigir reiniciar el backend.
const RECHECK_MS = 60 * 1000;
let support = { value: null, checkedAt: 0 };

async function substitutionTableExists(executor) {
  const now = Date.now();
  if (support.value === true) return true;
  if (support.value === false && now - support.checkedAt < RECHECK_MS) return false;
  const request = new sql.Request(executor);
  const result = await request.query(
    `SELECT CASE WHEN OBJECT_ID(N'dbo.${SUBSTITUTION_TABLE}', N'U') IS NULL THEN 0 ELSE 1 END AS [ok];`,
  );
  support = { value: Number(result.recordset[0]?.ok) === 1, checkedAt: now };
  return support.value;
}

function resetSubstitutionSupportCache() {
  support = { value: null, checkedAt: 0 };
}

function missingTableError() {
  const error = new Error(
    `Falta ${SUBSTITUTION_TABLE} en la base (backend/sql/018_calibracion_sustitucion.sql): `
    + 'los pasos de las cargas sustitutivas no se pueden guardar. Avise a Sistemas; '
    + 'los registros quedan en el teléfono.',
  );
  error.statusCode = 503;
  error.code = 'SUBSTITUTION_TABLE_MISSING';
  return error;
}

function buildSubstitutionInsertQuery() {
  return `
    INSERT INTO ${qualifiedSubstitutionTable}
      ([calibracion_n], [codigo_registro], [paso], [fila], [metodo],
       [indicacion_sustitutiva], [fila_referencia], [carga_referencia],
       [indicacion_referencia], [error_referencia], [carga_sustitutiva],
       [fila_base], [carga_base], [carga_resultante], [registrado_en])
    VALUES
      (@calibracionN, @codigoRegistro, @paso, @fila, @metodo,
       @indicacionSustitutiva, @filaReferencia, @cargaReferencia,
       @indicacionReferencia, @errorReferencia, @cargaSustitutiva,
       @filaBase, @cargaBase, @cargaResultante, @registradoEn);
  `;
}

async function insertSubstitutionSteps(transaction, calibracionN, codigoRegistro, pasos) {
  const query = buildSubstitutionInsertQuery();
  for (const paso of pasos) {
    const request = new sql.Request(transaction);
    request.input('calibracionN', sql.Int, calibracionN);
    request.input('codigoRegistro', sql.NVarChar(100), codigoRegistro);
    request.input('paso', sql.Int, paso.paso);
    request.input('fila', sql.Int, paso.fila);
    request.input('metodo', sql.NVarChar(2), paso.metodo);
    request.input('indicacionSustitutiva', sql.Decimal(18, 8), paso.indicacion_sustitutiva);
    request.input('filaReferencia', sql.Int, paso.filaReferencia);
    request.input('cargaReferencia', sql.Decimal(18, 8), paso.carga_referencia);
    request.input('indicacionReferencia', sql.Decimal(18, 8), paso.indicacion_referencia);
    request.input('errorReferencia', sql.Decimal(18, 8), paso.error_referencia);
    request.input('cargaSustitutiva', sql.Decimal(18, 8), paso.carga_sustitutiva);
    request.input('filaBase', sql.Int, paso.filaBase);
    request.input('cargaBase', sql.Decimal(18, 8), paso.carga_base);
    request.input('cargaResultante', sql.Decimal(18, 8), paso.carga_resultante);
    request.input('registradoEn', sql.DateTimeOffset(0), paso.registradoEn);
    await request.query(query);
  }
  return pasos.length;
}

module.exports = {
  SUBSTITUTION_TABLE,
  addSubstitutionValidation,
  buildSubstitutionInsertQuery,
  insertSubstitutionSteps,
  missingTableError,
  normalizeSubstitution,
  resetSubstitutionSupportCache,
  substitutionTableExists,
};
