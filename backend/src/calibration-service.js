'use strict';

const { sql, getPool } = require('./database');
const { CALIBRATION_TABLE } = require('./schema');
const { validateRecords } = require('./validation');

const qualifiedTable = `[dbo].[${CALIBRATION_TABLE}]`;

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
      `SELECT [codigo_registro] FROM ${qualifiedTable} WHERE [codigo_registro] IN (${parameters.join(',')})`,
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

async function insertRecord(transaction, schema, record, n) {
  const data = { ...record.normalized, n };
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
  await request.query(
    `INSERT INTO ${qualifiedTable} (${columns.join(',')}) VALUES (${parameters.join(',')})`,
  );
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

    const maxResult = await new sql.Request(transaction).query(
      `SELECT ISNULL(MAX([n]), 0) AS [maxN] FROM ${qualifiedTable} WITH (UPDLOCK, HOLDLOCK)`,
    );
    let nextN = Number(maxResult.recordset[0].maxN) + 1;
    const uploaded = [];
    for (const record of valid) {
      const assignedN = nextN;
      nextN += 1;
      await insertRecord(transaction, schema, record, assignedN);
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

module.exports = { addDatabaseDuplicates, findExistingCodes, validateAgainstDatabase, uploadRecords };
