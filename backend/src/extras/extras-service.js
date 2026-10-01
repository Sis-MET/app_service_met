'use strict';

const { sql, getPool } = require('../database');
const { resolveRegisteredBy } = require('../calibration-service');
const { ExtrasError, validateRim } = require('./extras-validation');

/** Base de los formularios adicionales, en la misma instancia que DataMET. */
const DEFAULT_EXTRAS_DATABASE = 'servicios_extras';
const DATABASE_NAME_PATTERN = /^[A-Za-z_][A-Za-z0-9_]{0,63}$/;

/** Violación de clave o índice único: el UUID ya estaba registrado. */
const UNIQUE_VIOLATION = new Set([2601, 2627]);

/**
 * La base, la tabla o el permiso todavía no existen: falta ejecutar
 * sql/012_create_servicios_extras.sql.
 */
const NOT_READY = new Set([208, 229, 911, 916, 4060]);

function readExtrasConfig(env = process.env) {
  const database = String(env.EXTRAS_DB_NAME ?? '').trim() || DEFAULT_EXTRAS_DATABASE;
  if (!DATABASE_NAME_PATTERN.test(database)) {
    throw new Error('EXTRAS_DB_NAME solo admite letras, números y guion bajo.');
  }
  return { database };
}

function nullable(value) {
  return value === '' || value === undefined ? null : value;
}

/** Columnas de `form_rim` para un RIM ya validado. */
function rimColumns(rim, { user, registeredBy }) {
  const { service } = rim;
  const text = (name, max, value) => ({ name, type: sql.NVarChar(max), value: nullable(value) });
  return [
    { name: 'uuid', type: sql.UniqueIdentifier, value: rim.uuid },
    text('codigo_rim', 60, rim.code),
    text('reg_usuario', 100, user),
    text('reg_por', 150, registeredBy),
    { name: 'emitido_en', type: sql.DateTimeOffset(0), value: rim.issuedAt },
    text('usuario_app', 100, rim.createdBy),
    text('app_version', 30, rim.appVersion),
    text('tipo_servicio', 20, service.serviceType),
    text('servicio', 100, service.serviceName),
    text('seca_otst', 60, service.seca),
    text('session_id', 60, service.sessionId),
    text('cod_cliente', 30, service.clientCode),
    text('cliente', 255, service.clientName),
    text('razon_social', 255, service.clientLegalName),
    text('cod_planta', 30, service.plantCode),
    text('planta', 255, service.plantName),
    text('dir_planta', 255, service.plantAddress),
    text('dep_planta', 120, service.plantDepartment),
    text('cod_metrica', 80, service.metricCode),
    text('instrumento', 120, service.equipmentType),
    text('marca', 120, service.brand),
    text('modelo', 120, service.model),
    text('serie', 120, service.serial),
    text('capacidad', 120, service.capacity),
    text('division', 120, service.division),
    text('unidad', 20, service.unit),
    text('ubicacion', 255, service.location),
    text('motivo', 2000, rim.reason),
    { name: 'inventario', type: sql.NVarChar(sql.MAX), value: JSON.stringify(rim.inventory) },
    text('obs_inventario', 1000, rim.inventoryNotes),
    text('estado_general', 20, rim.damageLevel),
    { name: 'danos', type: sql.NVarChar(sql.MAX), value: JSON.stringify(rim.damageTypes) },
    text('descripcion_danos', 2000, rim.damageDescription),
    text('nivel_suciedad', 20, rim.cleanlinessLevel),
    { name: 'pruebas_funcionamiento', type: sql.Bit, value: rim.functionalityTestPerformed },
    text('descripcion_pruebas', 2000, rim.functionalityTestDescription),
    text('contacto_nombre', 150, rim.contactName),
    text('contacto_cargo', 100, rim.contactPosition),
    text('contacto_telefono', 30, rim.contactPhone),
    text('representante_metrica', 150, rim.metricaRepresentative),
    text('lugar_recepcion', 255, rim.receptionLocation),
    text('tecnico_asignado', 150, rim.assignedTechnician),
    { name: 'firma_cliente', type: sql.VarBinary(sql.MAX), value: rim.signature },
  ];
}

/**
 * Columnas de `form_bitrix` para una oportunidad ya validada por
 * `validateOpportunity` y registrada en Bitrix24.
 */
function bitrixColumns(opportunity, { leadId, stageId, user }) {
  const { service } = opportunity;
  const text = (name, max, value) => ({ name, type: sql.NVarChar(max), value: nullable(value) });
  const createdAt = opportunity.createdAt ? new Date(opportunity.createdAt) : null;
  return [
    { name: 'uuid', type: sql.UniqueIdentifier, value: opportunity.uuid },
    { name: 'bitrix_lead_id', type: sql.Int, value: leadId },
    text('etapa', 50, stageId),
    text('reg_usuario', 100, user),
    {
      name: 'creado_en',
      type: sql.DateTimeOffset(0),
      value: createdAt && !Number.isNaN(createdAt.getTime()) ? createdAt : null,
    },
    text('app_version', 30, opportunity.appVersion),
    text('tipo_servicio', 20, service.serviceType),
    text('servicio', 100, service.serviceName),
    text('seca_otst', 60, service.seca),
    text('session_id', 60, service.sessionId),
    text('cliente', 255, service.clientName),
    text('razon_social', 255, service.clientLegalName),
    text('planta', 255, service.plantName),
    text('dep_planta', 120, service.plantDepartment),
    text('cod_metrica', 80, service.metricCode),
    text('instrumento', 120, service.equipmentType),
    text('marca', 120, service.brand),
    text('modelo', 120, service.model),
    text('serie', 120, service.serial),
    text('capacidad', 120, service.capacity),
    text('division', 120, service.division),
    text('unidad', 20, service.unit),
    text('ubicacion', 255, service.location),
    text('tecnico', 150, service.technician),
    { name: 'company_id', type: sql.Int, value: opportunity.companyId },
    text('company_name', 255, opportunity.companyName),
    { name: 'contact_id', type: sql.Int, value: opportunity.contactId ?? null },
    text('contact_name', 255, opportunity.contactName),
    text('tipo_oportunidad', 50, opportunity.opportunityType.key),
    text('tipo_oportunidad_nombre', 100, opportunity.opportunityType.label),
    text('linea', 60, opportunity.opportunityType.line),
    text('ciudad', 60, opportunity.city),
    text('titulo', 255, opportunity.title),
    text('descripcion', 4000, opportunity.description),
    text('prioridad', 10, opportunity.priority),
    text('observaciones', 2000, opportunity.notes),
  ];
}

/**
 * Inserta la fila solo si su UUID no existe y devuelve su correlativo. No usa
 * UPDATE ni sugerencias de bloqueo: el usuario de la API solo tiene SELECT e
 * INSERT, y la restricción única de `uuid` resuelve dos envíos simultáneos.
 */
function buildInsertOnceQuery(table, columns) {
  const names = columns.map((column) => `[${column.name}]`).join(', ');
  const values = columns.map((column) => `@${column.name}`).join(', ');
  return `
    DECLARE @inserted bit = 0;
    IF NOT EXISTS (SELECT 1 FROM ${table} WHERE [uuid] = @uuid)
    BEGIN
      INSERT INTO ${table} (${names}) VALUES (${values});
      SET @inserted = 1;
    END
    SELECT TOP (1) [n], @inserted AS [inserted] FROM ${table} WHERE [uuid] = @uuid;
  `;
}

function buildFindQuery(table) {
  return `SELECT TOP (1) [n], CONVERT(bit, 0) AS [inserted] FROM ${table} WHERE [uuid] = @uuid;`;
}

/** Ejecuta consultas parametrizadas contra el pool de la API. */
function createSqlRunner(config) {
  return async function run(text, params) {
    const pool = await getPool(config);
    const request = pool.request();
    for (const param of params) request.input(param.name, param.type, param.value);
    const result = await request.query(text);
    return result.recordset ?? [];
  };
}

function notReadyError(database) {
  return new ExtrasError(
    `El servidor todavía no tiene lista la base ${database} (falta ejecutar sql/012_create_servicios_extras.sql).`,
    { code: 'EXTRAS_NOT_READY', statusCode: 503 },
  );
}

/**
 * Guarda los formularios adicionales de ServiceMET (RIM y oportunidades de
 * Bitrix24) en la base `servicios_extras`. Solo inserta: un formulario ya
 * registrado no se modifica.
 *
 * @param {object} options
 * @param {string} options.database Nombre de la base de formularios.
 * @param {Function} options.run `(texto, parámetros) => filas`.
 * @param {Function} [options.resolveUserName] Nombre del usuario autenticado.
 */
function createExtrasService({ database, run, resolveUserName = async () => '' }) {
  if (!DATABASE_NAME_PATTERN.test(database)) {
    throw new Error('Nombre de base de formularios inválido.');
  }
  const rimTable = `[${database}].[dbo].[form_rim]`;
  const bitrixTable = `[${database}].[dbo].[form_bitrix]`;

  async function insertOnce(table, columns) {
    const uuid = columns.find((column) => column.name === 'uuid');
    let rows;
    try {
      rows = await run(buildInsertOnceQuery(table, columns), columns);
    } catch (error) {
      if (NOT_READY.has(error?.number)) throw notReadyError(database);
      if (!UNIQUE_VIOLATION.has(error?.number)) throw error;
      // Otro envío del mismo UUID ganó la carrera: se devuelve su fila.
      rows = await run(buildFindQuery(table), [uuid]);
    }
    const n = Number(rows[0]?.n);
    if (!Number.isSafeInteger(n) || n <= 0) {
      throw new ExtrasError('SQL Server no devolvió el correlativo del formulario.', {
        code: 'IDENTITY_NOT_RETURNED',
        statusCode: 500,
      });
    }
    return { n, duplicate: !rows[0].inserted };
  }

  /** Registra un RIM. Reenviar el mismo UUID devuelve el ya registrado. */
  async function saveRim(input, { user } = {}) {
    const rim = validateRim(input);
    let registeredBy = '';
    try {
      registeredBy = await resolveUserName(user);
    } catch (_) {
      // El nombre es una referencia; el usuario autenticado siempre se guarda.
    }
    return insertOnce(rimTable, rimColumns(rim, { user, registeredBy }));
  }

  /** Deja constancia de una oportunidad ya registrada en Bitrix24. */
  async function saveBitrixOpportunity(opportunity, { leadId, stageId, user } = {}) {
    return insertOnce(bitrixTable, bitrixColumns(opportunity, { leadId, stageId, user }));
  }

  return { saveRim, saveBitrixOpportunity };
}

/** Servicio conectado al SQL Server de la API. */
function defaultExtrasService(config) {
  return createExtrasService({
    database: config.extras?.database ?? DEFAULT_EXTRAS_DATABASE,
    run: createSqlRunner(config),
    resolveUserName: async (user) => resolveRegisteredBy(await getPool(config), user),
  });
}

module.exports = {
  DEFAULT_EXTRAS_DATABASE,
  bitrixColumns,
  buildFindQuery,
  buildInsertOnceQuery,
  createExtrasService,
  defaultExtrasService,
  readExtrasConfig,
  rimColumns,
};
