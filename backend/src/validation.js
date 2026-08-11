'use strict';

const EXCLUDED_FIELDS = new Set([
  'n',
  'codigo_registro',
  'id',
  'foto_balanza',
  'nombre_zip',
  'nombre_csv',
  'finalized_at',
  'directorio_zip',
  'estado_servicio_csv',
]);

function isPhotoField(name) {
  return name.endsWith('_foto');
}

function error(column, value, code, message, expected) {
  return { column, value: value === undefined ? null : value, code, message, expected };
}

function normalizeDecimal(raw) {
  const text = String(raw).trim();
  if (/^-?\d+,\d+$/.test(text)) return text.replace(',', '.');
  return text;
}

function canonicalCode(value) {
  return value.normalize('NFKC').toUpperCase();
}

function normalizeDate(raw) {
  const value = String(raw).trim();
  let year;
  let month;
  let day;

  let match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(value);
  if (match) {
    [, year, month, day] = match;
  } else {
    match = /^(\d{2})\/(\d{2})\/(\d{4})$/.exec(value);
    if (!match) return null;
    [, day, month, year] = match;
  }

  const numericYear = Number(year);
  const numericMonth = Number(month);
  const numericDay = Number(day);
  const parsed = new Date(Date.UTC(numericYear, numericMonth - 1, numericDay));
  if (
    parsed.getUTCFullYear() !== numericYear ||
    parsed.getUTCMonth() !== numericMonth - 1 ||
    parsed.getUTCDate() !== numericDay
  ) {
    return null;
  }
  return `${year}-${month}-${day}`;
}

function validateDecimal(column, raw, definition) {
  const value = normalizeDecimal(raw);
  if (!/^-?(?:\d+\.?\d*|\.\d+)$/.test(value)) {
    return { issue: error(column, raw, 'INVALID_DECIMAL', 'El valor no es un número decimal válido.', `decimal(${definition.precision},${definition.scale})`) };
  }
  const unsigned = value.replace('-', '');
  const [integerPartRaw, fraction = ''] = unsigned.split('.');
  const integerPart = integerPartRaw.replace(/^0+(?=\d)/, '') || '0';
  const integerLimit = definition.precision - definition.scale;
  if (integerPart.length > integerLimit || fraction.length > definition.scale) {
    return { issue: error(column, raw, 'DECIMAL_OVERFLOW', 'El valor excede la precisión permitida.', `máximo ${integerLimit} enteros y ${definition.scale} decimales`) };
  }
  return { value };
}

function normalizeValue(column, raw, definition) {
  if (raw === null || raw === undefined || String(raw).trim() === '') {
    if (!definition.nullable) {
      return { issue: error(column, raw, 'REQUIRED', 'La columna no admite valores vacíos.', 'valor obligatorio') };
    }
    return { value: null };
  }

  switch (definition.type) {
    case 'nvarchar': {
      const value = String(raw).trim();
      if (definition.maxLength !== null && value.length > definition.maxLength) {
        return { issue: error(column, raw, 'MAX_LENGTH', 'El texto supera la longitud de la columna.', `máximo ${definition.maxLength} caracteres`) };
      }
      return { value };
    }
    case 'int': {
      const value = String(raw).trim().replace(',', '.');
      if (!/^-?\d+(?:\.0+)?$/.test(value)) {
        return { issue: error(column, raw, 'INVALID_INTEGER', 'El valor debe ser un número entero.', 'entero de 32 bits') };
      }
      const parsed = Number(value.split('.')[0]);
      if (!Number.isSafeInteger(parsed) || parsed < -2147483648 || parsed > 2147483647) {
        return { issue: error(column, raw, 'INTEGER_OVERFLOW', 'El entero excede el rango de SQL Server.', '-2147483648 a 2147483647') };
      }
      return { value: parsed };
    }
    case 'decimal':
    case 'numeric':
      return validateDecimal(column, raw, definition);
    case 'date': {
      const value = normalizeDate(raw);
      if (value === null) {
        return { issue: error(column, raw, 'INVALID_DATE', 'La fecha no tiene un formato válido.', 'AAAA-MM-DD o DD/MM/AAAA') };
      }
      return { value };
    }
    case 'time': {
      const value = String(raw).trim();
      if (!/^(?:[01]\d|2[0-3]):[0-5]\d(?::[0-5]\d(?:\.\d{1,7})?)?$/.test(value)) {
        return { issue: error(column, raw, 'INVALID_TIME', 'La hora no tiene un formato válido.', 'HH:mm o HH:mm:ss') };
      }
      return { value };
    }
    case 'bit': {
      if (raw === true || raw === false) return { value: raw };
      if (raw === 1 || raw === '1') return { value: true };
      if (raw === 0 || raw === '0') return { value: false };
      return { issue: error(column, raw, 'INVALID_BOOLEAN', 'El valor no es booleano.', '0, 1, true o false') };
    }
    default:
      return { issue: error(column, raw, 'UNSUPPORTED_TYPE', `El tipo SQL ${definition.type} no está soportado.`, definition.type) };
  }
}

function validateRecords(records, schema) {
  if (!Array.isArray(records) || records.length === 0) {
    return { records: [], batchErrors: [{ code: 'EMPTY_BATCH', message: 'No se recibieron registros.' }] };
  }

  const codeCounts = new Map();
  for (const record of records) {
    if (!record || typeof record !== 'object' || Array.isArray(record)) continue;
    const seca = String(record.seca ?? '').trim();
    const codMetrica = String(record.cod_metrica ?? '').trim();
    if (!seca || !codMetrica) continue;
    const code = canonicalCode(`${seca}-${codMetrica}`);
    codeCounts.set(code, (codeCounts.get(code) ?? 0) + 1);
  }

  const results = records.map((record, index) => {
    const issues = [];
    const normalized = {};
    if (!record || typeof record !== 'object' || Array.isArray(record)) {
      return { index, codigoRegistro: null, seca: null, codMetrica: null, valid: false, errors: [error(null, record, 'INVALID_RECORD', 'El registro debe ser un objeto.', 'objeto JSON')], normalized };
    }

    const seca = String(record.seca ?? '').trim();
    const codMetrica = String(record.cod_metrica ?? '').trim();
    const codigoRegistro = seca && codMetrica ? `${seca}-${codMetrica}` : null;
    const nombreCsv = String(record.nombre_csv ?? '').trim();
    if (!seca) issues.push(error('seca', record.seca, 'REQUIRED', 'Falta el SECA.', 'texto no vacío'));
    if (!codMetrica) issues.push(error('cod_metrica', record.cod_metrica, 'REQUIRED', 'Falta el código métrica.', 'texto no vacío'));
    if (String(record.estado_servicio_bal ?? '').trim() !== 'Balanza Calibrada') {
      issues.push(error('estado_servicio_bal', record.estado_servicio_bal, 'INCOMPLETE_SERVICE', 'La balanza no está marcada como servicio completo.', 'Balanza Calibrada'));
    }
    if (nombreCsv.length > 100) {
      issues.push(error('nombre_csv', nombreCsv, 'MAX_LENGTH', 'El nombre lógico del CSV supera la longitud permitida.', 'máximo 100 caracteres'));
    }
    if (codigoRegistro) {
      if ((codeCounts.get(canonicalCode(codigoRegistro)) ?? 0) > 1) {
        issues.push(error('codigo_registro', codigoRegistro, 'DUPLICATE_IN_BATCH', 'La misma balanza aparece más de una vez en el lote.', 'SECA-COD_METRICA único'));
      }
    }

    for (const [column, raw] of Object.entries(record)) {
      if (EXCLUDED_FIELDS.has(column) || isPhotoField(column)) continue;
      const definition = schema.get(column);
      if (!definition) {
        issues.push(error(column, raw, 'UNKNOWN_COLUMN', 'La columna no existe en la tabla destino.', 'columna definida en DataMET'));
        continue;
      }
      const result = normalizeValue(column, raw, definition);
      if (result.issue) issues.push(result.issue);
      else normalized[column] = result.value;
    }

    normalized.codigo_registro = codigoRegistro;
    return {
      index,
      codigoRegistro,
      seca,
      codMetrica,
      nombreCsv: nombreCsv || null,
      valid: issues.length === 0,
      errors: issues,
      normalized,
    };
  });
  return { records: results, batchErrors: [] };
}

module.exports = {
  EXCLUDED_FIELDS,
  canonicalCode,
  normalizeDate,
  normalizeValue,
  validateRecords,
};
