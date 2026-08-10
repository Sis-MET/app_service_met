'use strict';

const { sql, getPool } = require('./database');
const { CALIBRATION_TABLE } = require('./schema');
const { validateRecords } = require('./validation');

const qualifiedTable = `[dbo].[${CALIBRATION_TABLE}]`;
const uploadLockResource = 'ServiceMET:calibracion:upload';

async function acquireUploadLock(transaction) {
  const request = new sql.Request(transaction);
  request.input('resource', sql.NVarChar(255), uploadLockResource);
  request.input('timeout', sql.Int, 30000);
  const result = await request.query(`
    DECLARE @lockResult int;
    EXEC @lockResult = sys.sp_getapplock
      @Resource = @resource,
      @LockMode = 'Exclusive',
      @LockOwner = 'Transaction',
      @LockTimeout = @timeout,
      @DbPrincipal = 'public';
    SELECT @lockResult AS [lockResult];
  `);
  const lockResult = Number(result.recordset[0]?.lockResult);
  if (!Number.isFinite(lockResult) || lockResult < 0) {
    const error = new Error('Otra subida está en curso. Espere y vuelva a validar el lote.');
    error.statusCode = 503;
    error.code = 'UPLOAD_LOCK_TIMEOUT';
    throw error;
  }
}

function addDatabaseDuplicates(validation, existingCodes) {
  for (const record of validation.records) {
    if (!record.codigoRegistro || !existingCodes.has(record.codigoRegistro)) continue;
    record.errors.push({
      column: 'codigo_registro',
      value: record.codigoRegistro,
      code: 'ALREADY_EXISTS',
      message: 'El servicio ya existe en DataMET.',
      expected: 'SECA-COD_METRICA no registrado previamente',
    });
    record.valid = false;
  }
  return validation;
}

async function findExistingCodes(executor, codes) {
  const uniqueCodes = [...new Set(codes.filter(Boolean))];
  const found = new Set();
  for (let offset = 0; offset < uniqueCodes.length; offset += 500) {
    const chunk = uniqueCodes.slice(offset, offset + 500);
    const request = new sql.Request(executor);
    const parameters = chunk.map((code, index) => {
      const name = `code${index}`;
      request.input(name, sql.NVarChar(100), code);
      return `@${name}`;
    });
    const result = await request.query(
      `SELECT DISTINCT incoming.[codigo_registro]
       FROM (VALUES ${parameters.map((parameter) => `(${parameter})`).join(',')})
         AS incoming([codigo_registro])
       WHERE EXISTS (
         SELECT 1
         FROM ${qualifiedTable} AS stored
         WHERE stored.[codigo_registro] = incoming.[codigo_registro]
       )`,
    );
    for (const row of result.recordset) found.add(row.codigo_registro);
  }
  return found;
}

async function validateAgainstDatabase(config, schema, records) {
  const validation = validateRecords(records, schema);
  if (validation.records.length === 0) return validation;
  const pool = await getPool(config);
  const existing = await findExistingCodes(
    pool,
    validation.records.map((record) => record.codigoRegistro),
  );
  return addDatabaseDuplicates(validation, existing);
}

function inputValue(request, name, definition, value) {
  if (value === null || value === undefined) {
    request.input(name, sql.NVarChar(1), null);
    return;
  }
  if (definition.type === 'int') {
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

function buildInsertQuery(columns, parameters) {
  return `
    INSERT INTO ${qualifiedTable} (${columns.join(',')})
    VALUES (${parameters.join(',')});
    SELECT CONVERT(int, SCOPE_IDENTITY()) AS [n];
  `;
}

async function insertRecord(transaction, schema, record) {
  // n es IDENTITY en SQL Server; nunca debe enviarse explícitamente.
  const data = { ...record.normalized };
  delete data.n;
  delete data.id;
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
  const result = await request.query(buildInsertQuery(columns, parameters));
  const assignedN = Number(result.recordset[0]?.n);
  if (!Number.isSafeInteger(assignedN)) {
    const error = new Error('SQL Server no devolvió el correlativo n asignado.');
    error.statusCode = 500;
    error.code = 'IDENTITY_NOT_RETURNED';
    throw error;
  }
  return assignedN;
}

async function uploadRecords(config, schema, records, mode) {
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
    // Serializa todas las cargas realizadas por esta API, incluso si hay varias
    // instancias o varios celulares, sin crear objetos en DataMET_prueba.
    await acquireUploadLock(transaction);
    const validation = validateRecords(records, schema);
    const existing = await findExistingCodes(
      transaction,
      validation.records.map((record) => record.codigoRegistro),
    );
    addDatabaseDuplicates(validation, existing);

    const valid = validation.records.filter((record) => record.valid);
    const invalid = validation.records.filter((record) => !record.valid);
    if ((mode === 'all' && invalid.length > 0) || valid.length === 0) {
      await transaction.rollback();
      return { uploaded: [], validation, rejected: true };
    }

    const uploaded = [];
    for (const record of valid) {
      const assignedN = await insertRecord(transaction, schema, record);
      uploaded.push({
        index: record.index,
        codigoRegistro: record.codigoRegistro,
        n: assignedN,
        sessionId: record.normalized.session_id ?? null,
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
  acquireUploadLock,
  addDatabaseDuplicates,
  buildInsertQuery,
  findExistingCodes,
  validateAgainstDatabase,
  uploadRecords,
};
