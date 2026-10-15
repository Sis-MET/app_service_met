'use strict';

const { sql, getPool } = require('./database');
const { SERVICE_SUMMARY_TABLE, SUPPORT_MODULES } = require('./schema');
const {
  ACTIVE_CSV_STATUS,
  canonicalCode,
  isNewScaleCode,
  normalizeValue,
  summaryServiceStatus,
} = require('./validation');
const { resolveRegisteredBy, addRegisteredByErrors } = require('./calibration-service');
const {
  addLocationInputs,
  normalizeLocation,
  summaryLocationSql,
  summarySupportsLocation,
} = require('./location');

const qualifiedSummaryTable = `[dbo].[${SERVICE_SUMMARY_TABLE}]`;
const uploadLockResource = 'ServiceMET:soporte:upload';
const excludedFields = new Set([
  'n',
  'id',
  'codigo_registro',
  'nombre_csv',
  'nombre_zip',
  'estado_servicio_csv',
  '_support_module',
  '_support_label',
  '_source_database',
  '_source_table',
]);
const ignoredLegacyFieldsByModule = new Map([
  ['mnt_prv_avanzado', new Set([
    'retorno_cero_inicial_unidad',
    'retorno_cero_final_unidad',
  ])],
]);

function issue(column, value, code, message, expected) {
  return {
    column,
    value: value === undefined ? null : value,
    code,
    message,
    expected,
  };
}

function isPhotoField(column) {
  return column === 'foto_balanza' || column.endsWith('_foto');
}

function normalizeLegacyPosition(column, raw, definition) {
  if (definition.type !== 'int' || raw === null || raw === undefined) return raw;
  const isPositionColumn = /^(?:posicion_(?:inicial|final)_\d+|posicion\d+|excentricidad_(?:inicial|final)_pos\d+_numero)$/.test(column);
  if (!isPositionColumn) return raw;
  const match = /^(?:posici[oó]n|ida|vuelta)\s+(\d+)$/i.exec(String(raw).trim());
  return match ? match[1] : raw;
}

function isCompleted(module, record) {
  if (module === 'diagnostico') {
    return ['reporte', 'evaluacion', 'comentario_general', 'hora_fin']
      .every((column) => String(record[column] ?? '').trim().length > 0);
  }
  if (module === 'relevamiento_de_datos') {
    return String(record.estado_servicio ?? '').trim() === 'Balanza Realizada';
  }
  return String(record.estado_servicio ?? '').trim() === 'Completo';
}

function logicalCsvName(module, record) {
  const provided = String(record.nombre_csv ?? record.nombre_zip ?? '').trim();
  if (provided) return provided.replace(/\.zip$/i, '.csv');
  const otst = String(record.otst ?? '').trim();
  const session = String(record.session_id ?? '').trim();
  return `${otst}_${module}${session ? `_${session}` : ''}.csv`;
}

function supportRegistrationCode(module, otst, codMetrica) {
  const serviceCode = SUPPORT_MODULES[module]?.serviceCode;
  if (!serviceCode || !otst || !codMetrica) return null;
  return `${otst}-${serviceCode}-${codMetrica}`;
}

function validateSupportRecords(records, schemas) {
  if (!Array.isArray(records) || records.length === 0) {
    return {
      records: [],
      batchErrors: [{ code: 'EMPTY_BATCH', message: 'No se recibieron registros.' }],
    };
  }

  const prepared = records.map((envelope) => ({
    module: String(envelope?.module ?? '').trim(),
    data: envelope?.data,
    location: normalizeLocation(envelope?.ubicacion),
  }));
  const counts = new Map();
  for (const { module, data } of prepared) {
    if (!data || typeof data !== 'object' || Array.isArray(data)) continue;
    const otst = String(data.otst ?? '').trim();
    const codMetrica = String(data.cod_metrica ?? '').trim();
    if (!otst || !codMetrica) continue;
    const code = supportRegistrationCode(module, otst, codMetrica);
    if (!code) continue;
    const canonical = canonicalCode(code);
    counts.set(canonical, (counts.get(canonical) ?? 0) + 1);
  }

  const results = prepared.map(({ module, data, location }, index) => {
    const errors = [];
    const normalized = {};
    const schema = schemas.get(module);
    if (!SUPPORT_MODULES[module] || !schema) {
      errors.push(issue('module', module, 'UNKNOWN_MODULE', 'El módulo de soporte no está configurado.', 'uno de los 8 módulos habilitados'));
    }
    if (!data || typeof data !== 'object' || Array.isArray(data)) {
      return {
        index,
        module,
        codigoRegistro: null,
        otst: null,
        codMetrica: null,
        valid: false,
        errors: [...errors, issue(null, data, 'INVALID_RECORD', 'El registro debe ser un objeto.', 'objeto JSON')],
        normalized,
      };
    }

    const otst = String(data.otst ?? '').trim();
    const codMetrica = String(data.cod_metrica ?? '').trim();
    const codigoRegistro = supportRegistrationCode(module, otst, codMetrica);
    const nombreCsv = logicalCsvName(module, data);
    if (!otst) errors.push(issue('otst', data.otst, 'REQUIRED', 'Falta el OTST.', 'texto no vacío'));
    if (!codMetrica) errors.push(issue('cod_metrica', data.cod_metrica, 'REQUIRED', 'Falta el código métrica.', 'texto no vacío'));
    if (!isCompleted(module, data)) {
      const expectedState = module === 'diagnostico'
        ? 'reporte, evaluación, comentario y hora final completos'
        : module === 'relevamiento_de_datos'
          ? 'Balanza Realizada'
          : 'Completo';
      errors.push(issue('estado_servicio', data.estado_servicio, 'INCOMPLETE_SERVICE', 'El servicio aún no está completo.', expectedState));
    }
    if (nombreCsv.length > 100) {
      errors.push(issue('nombre_csv', nombreCsv, 'MAX_LENGTH', 'El nombre lógico del CSV supera la longitud permitida.', 'máximo 100 caracteres'));
    }
    if (codigoRegistro && (counts.get(canonicalCode(codigoRegistro)) ?? 0) > 1) {
      errors.push(issue('codigo_registro', codigoRegistro, 'DUPLICATE_IN_BATCH', 'El mismo equipo aparece más de una vez en el lote.', 'OTST-CODIGO_MODULO-COD_METRICA único'));
    }

    if (schema) {
      for (const [column, raw] of Object.entries(data)) {
        if (excludedFields.has(column) || isPhotoField(column)) continue;
        if (ignoredLegacyFieldsByModule.get(module)?.has(column)) continue;
        const definition = schema.get(column);
        if (!definition) {
          errors.push(issue(column, raw, 'UNKNOWN_COLUMN', 'La columna no existe en la tabla destino.', SUPPORT_MODULES[module].table));
          continue;
        }
        const result = normalizeValue(
          column,
          normalizeLegacyPosition(column, raw, definition),
          definition,
        );
        if (result.issue) errors.push(result.issue);
        else normalized[column] = result.value;
      }
      if (codigoRegistro) {
        const codeResult = normalizeValue(
          'codigo_registro',
          codigoRegistro,
          schema.get('codigo_registro'),
        );
        if (codeResult.issue) errors.push(codeResult.issue);
        else normalized.codigo_registro = codeResult.value;
      }
      const serviceCodeResult = normalizeValue(
        'tipo_servicio',
        SUPPORT_MODULES[module].serviceCode,
        schema.get('tipo_servicio'),
      );
      if (serviceCodeResult.issue) errors.push(serviceCodeResult.issue);
      else normalized.tipo_servicio = serviceCodeResult.value;
      normalized.estado_servicio_csv = ACTIVE_CSV_STATUS;
    }
    return {
      index,
      module,
      codigoRegistro,
      otst,
      codMetrica,
      nombreCsv,
      valid: errors.length === 0,
      errors,
      normalized,
      location,
    };
  });
  return { records: results, batchErrors: [] };
}

async function acquireUploadLock(transaction) {
  const request = new sql.Request(transaction);
  request.input('resource', sql.NVarChar(255), uploadLockResource);
  const result = await request.query(`
    DECLARE @lockResult int;
    EXEC @lockResult = sys.sp_getapplock
      @Resource = @resource,
      @LockMode = 'Exclusive',
      @LockOwner = 'Transaction',
      @LockTimeout = 30000,
      @DbPrincipal = 'public';
    SELECT @lockResult AS [lockResult];
  `);
  if (Number(result.recordset[0]?.lockResult) < 0) {
    const error = new Error('Otra subida de soporte está en curso. Espere y vuelva a validar.');
    error.statusCode = 503;
    error.code = 'UPLOAD_LOCK_TIMEOUT';
    throw error;
  }
}

async function findExistingCodes(executor, validation) {
  const found = new Set();
  const grouped = new Map();
  for (const record of validation.records) {
    if (!record.codigoRegistro || !SUPPORT_MODULES[record.module]) continue;
    if (!grouped.has(record.module)) grouped.set(record.module, []);
    grouped.get(record.module).push(record.codigoRegistro);
  }
  for (const [module, rawCodes] of grouped) {
    const table = SUPPORT_MODULES[module].table;
    const codes = [...new Set(rawCodes)];
    for (let offset = 0; offset < codes.length; offset += 500) {
      const chunk = codes.slice(offset, offset + 500);
      const request = new sql.Request(executor);
      const parameters = chunk.map((code, index) => {
        const name = `code${index}`;
        request.input(name, sql.NVarChar(100), code);
        return `(@${name})`;
      });
      const result = await request.query(`
        SELECT DISTINCT incoming.[codigo_registro]
        FROM (VALUES ${parameters.join(',')}) AS incoming([codigo_registro])
        WHERE EXISTS (
          SELECT 1 FROM [dbo].[${table}] stored
          WHERE stored.[codigo_registro] = incoming.[codigo_registro]
        ) OR EXISTS (
          SELECT 1 FROM ${qualifiedSummaryTable} summary
          WHERE summary.[codigo_registro] = incoming.[codigo_registro]
        )
      `);
      for (const row of result.recordset) {
        found.add(canonicalCode(String(row.codigo_registro)));
      }
    }
  }
  return found;
}

function addDatabaseDuplicates(validation, existingCodes) {
  for (const record of validation.records) {
    if (!record.codigoRegistro || !existingCodes.has(canonicalCode(record.codigoRegistro))) continue;
    record.errors.push(issue('codigo_registro', record.codigoRegistro, 'ALREADY_EXISTS', 'El servicio ya existe en DataMET.', 'OTST-CODIGO_MODULO-COD_METRICA no registrado previamente'));
    record.valid = false;
  }
  return validation;
}

function inputValue(request, name, definition, value) {
  if (value === null || value === undefined) {
    request.input(name, sql.NVarChar(1), null);
  } else if (definition.type === 'int') {
    request.input(name, sql.Int, value);
  } else if (definition.type === 'bit') {
    request.input(name, sql.Bit, value);
  } else {
    const length = definition.type === 'nvarchar' && definition.maxLength
      ? definition.maxLength
      : sql.MAX;
    request.input(name, sql.NVarChar(length), String(value));
  }
}

async function tableUsesIdentityN(executor, table) {
  const request = new sql.Request(executor);
  request.input('table', sql.NVarChar(255), `dbo.${table}`);
  const result = await request.query(`
    SELECT CONVERT(int, COLUMNPROPERTY(OBJECT_ID(@table), 'n', 'IsIdentity')) AS [isIdentity]
  `);
  return Number(result.recordset[0]?.isIdentity) === 1;
}

async function nextCorrelative(executor, table) {
  const result = await new sql.Request(executor).query(`
    SELECT ISNULL(MAX([n]), 0) + 1 AS [nextN]
    FROM [dbo].[${table}] WITH (UPDLOCK, HOLDLOCK)
  `);
  const next = Number(result.recordset[0]?.nextN);
  if (!Number.isSafeInteger(next)) throw new Error(`No se pudo calcular el correlativo de ${table}.`);
  return next;
}

async function insertSupportRecord(transaction, schema, record, identityN) {
  const table = SUPPORT_MODULES[record.module].table;
  const data = { ...record.normalized };
  delete data.n;
  delete data.id;
  data.estado_servicio_csv = ACTIVE_CSV_STATUS;
  if (!identityN) data.n = await nextCorrelative(transaction, table);
  const entries = Object.entries(data).filter(([column]) => schema.has(column));
  const request = new sql.Request(transaction);
  const columns = [];
  const parameters = [];
  for (let index = 0; index < entries.length; index += 1) {
    const [column, value] = entries[index];
    const parameter = `p${index}`;
    columns.push(`[${column}]`);
    parameters.push(`@${parameter}`);
    inputValue(request, parameter, schema.get(column), value);
  }
  const result = await request.query(`
    INSERT INTO [dbo].[${table}] (${columns.join(',')})
    OUTPUT INSERTED.[n] AS [n]
    VALUES (${parameters.join(',')});
  `);
  const assigned = Number(result.recordset[0]?.n);
  if (!Number.isSafeInteger(assigned)) throw new Error(`SQL Server no devolvió el correlativo de ${table}.`);
  return assigned;
}

function buildSummaryInsertQuery(withLocation = false) {
  const location = summaryLocationSql(withLocation);
  return `
    INSERT INTO ${qualifiedSummaryTable}
      ([codigo_registro], [fecha_reg], [reg_por], [nombre_csv], [estado_servicio], [tipo_servicio]${location.columns})
    OUTPUT INSERTED.[n] AS [n]
    VALUES (@codigo, CONVERT(date, GETDATE()), @usuario, @csv, @estado, @tipoServicio${location.values});
  `;
}

async function insertSummary(transaction, record, registeredBy, withLocation = false) {
  const request = new sql.Request(transaction);
  if (withLocation) addLocationInputs(request, record.location);
  request.input('codigo', sql.NVarChar(100), record.codigoRegistro);
  request.input('usuario', sql.NVarChar(50), registeredBy);
  request.input('csv', sql.NVarChar(100), record.nombreCsv);
  request.input(
    'estado',
    sql.NVarChar(50),
    summaryServiceStatus(record.codMetrica),
  );
  request.input(
    'tipoServicio',
    sql.NVarChar(10),
    SUPPORT_MODULES[record.module].serviceCode,
  );
  const result = await request.query(buildSummaryInsertQuery(withLocation));
  const assigned = Number(result.recordset[0]?.n);
  if (!Number.isSafeInteger(assigned)) throw new Error('SQL Server no devolvió el identificador del resumen.');
  return assigned;
}

async function validateAgainstDatabase(config, schemas, records, username) {
  const validation = validateSupportRecords(records, schemas);
  if (validation.records.length === 0) return validation;
  const pool = await getPool(config);
  const [existing, registeredBy] = await Promise.all([
    findExistingCodes(pool, validation),
    resolveRegisteredBy(pool, username),
  ]);
  addDatabaseDuplicates(validation, existing);
  return addRegisteredByErrors(validation, registeredBy);
}

async function uploadSupportRecords(config, schemas, records, mode, username) {
  if (mode !== 'all' && mode !== 'valid_only') {
    const error = new Error('Modo de subida inválido');
    error.statusCode = 400;
    error.code = 'INVALID_MODE';
    throw error;
  }
  const pool = await getPool(config);
  const transaction = new sql.Transaction(pool);
  await transaction.begin(sql.ISOLATION_LEVEL.SERIALIZABLE);
  try {
    await acquireUploadLock(transaction);
    const validation = validateSupportRecords(records, schemas);
    const existing = await findExistingCodes(transaction, validation);
    const registeredBy = await resolveRegisteredBy(transaction, username);
    addDatabaseDuplicates(validation, existing);
    addRegisteredByErrors(validation, registeredBy);
    const valid = validation.records.filter((record) => record.valid);
    const invalid = validation.records.filter((record) => !record.valid);
    if ((mode === 'all' && invalid.length > 0) || valid.length === 0) {
      await transaction.rollback();
      return { uploaded: [], validation, rejected: true };
    }

    const identityByModule = new Map();
    for (const record of valid) {
      if (!identityByModule.has(record.module)) {
        const table = SUPPORT_MODULES[record.module].table;
        identityByModule.set(record.module, await tableUsesIdentityN(transaction, table));
      }
    }
    const withLocation = await summarySupportsLocation(transaction);
    const uploaded = [];
    for (const record of valid) {
      const assignedN = await insertSupportRecord(
        transaction,
        schemas.get(record.module),
        record,
        identityByModule.get(record.module),
      );
      const summaryN = await insertSummary(
        transaction,
        record,
        registeredBy,
        withLocation,
      );
      uploaded.push({
        index: record.index,
        module: record.module,
        codigoRegistro: record.codigoRegistro,
        n: assignedN,
        summaryN,
        sessionId: record.normalized.session_id ?? null,
        isNewScale: isNewScaleCode(record.codMetrica),
      });
    }
    await transaction.commit();
    return { uploaded, validation, rejected: false };
  } catch (error) {
    try { await transaction.rollback(); } catch (_) { /* transaction already closed */ }
    throw error;
  }
}

module.exports = {
  addDatabaseDuplicates,
  buildSummaryInsertQuery,
  insertSupportRecord,
  logicalCsvName,
  supportRegistrationCode,
  validateSupportRecords,
  validateAgainstDatabase,
  uploadSupportRecords,
};
