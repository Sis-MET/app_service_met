'use strict';

const { sql, getPool } = require('../database');
const { resolveRegisteredBy } = require('../calibration-service');
const {
  ExtrasError,
  validateRim,
  validateTalonarioClosure,
  validateTalonarioRequest,
} = require('./extras-validation');

/** Base de los formularios adicionales, en la misma instancia que DataMET. */
const DEFAULT_EXTRAS_DATABASE = 'servicios_extras';
const DATABASE_NAME_PATTERN = /^[A-Za-z_][A-Za-z0-9_]{0,63}$/;

/** Números de RIM por talonario que se entregan a la app. */
const DEFAULT_TALONARIO_SIZE = 10;

/** Violación de clave o índice único: el UUID ya estaba registrado. */
const UNIQUE_VIOLATION = new Set([2601, 2627]);

/**
 * La base, la tabla o el permiso todavía no existen: falta ejecutar
 * sql/012_create_servicios_extras.sql.
 */
const NOT_READY = new Set([208, 229, 911, 916, 4060]);

/**
 * Falta la numeración del RIM (columna o procedimiento inexistentes): falta
 * ejecutar sql/014_rim_numeracion_y_gestion.sql.
 */
const NUMBERING_NOT_READY = new Set([...NOT_READY, 207, 2812]);
const NUMBERING_SCRIPT = '014_rim_numeracion_y_gestion.sql';

/** Errores que lanzan las consultas de numeración (THROW 510xx). */
const SQL_ERRORS = Object.freeze({
  51010: { code: 'VALIDATION_ERROR', statusCode: 400 },
  51011: { code: 'RIM_NUMBERS_EXHAUSTED', statusCode: 409 },
  51012: { code: 'RIM_NUMBERING_BUSY', statusCode: 503 },
  51020: { code: 'RIM_NUMBER_NOT_ASSIGNED', statusCode: 409 },
  51021: { code: 'RIM_TALONARIO_NOT_FOUND', statusCode: 404 },
  51022: { code: 'VALIDATION_ERROR', statusCode: 400 },
});

function readExtrasConfig(env = process.env) {
  const database = String(env.EXTRAS_DB_NAME ?? '').trim() || DEFAULT_EXTRAS_DATABASE;
  if (!DATABASE_NAME_PATTERN.test(database)) {
    throw new Error('EXTRAS_DB_NAME solo admite letras, números y guion bajo.');
  }
  const sizeText = String(env.RIM_TALONARIO_SIZE ?? '').trim();
  const talonarioSize = sizeText ? Number(sizeText) : DEFAULT_TALONARIO_SIZE;
  if (!Number.isInteger(talonarioSize) || talonarioSize < 1 || talonarioSize > 100) {
    throw new Error('RIM_TALONARIO_SIZE debe ser un entero entre 1 y 100.');
  }
  return { database, talonarioSize };
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
    { name: 'firma_cliente', type: sql.VarBinary(sql.MAX), value: rim.clientSignature },
    { name: 'firma_representante', type: sql.VarBinary(sql.MAX), value: rim.metricaSignature },
    // Numeración por talonario. El talonario lo resuelve la consulta a
    // partir de la gestión, el número y la instalación.
    ...(rim.numbering ? [
      text('origen', 20, 'servicemet'),
      { name: 'gestion', type: sql.SmallInt, value: rim.numbering.year },
      { name: 'numero', type: sql.Int, value: rim.numbering.number },
      { name: 'instalacion', type: sql.UniqueIdentifier, value: rim.installationId },
    ] : []),
  ];
}

/** Parámetros de la anulación hecha en el teléfono antes de subir el RIM. */
function voidedParams(voided) {
  return [
    { name: 'anulacion_motivo', type: sql.NVarChar(1000), value: voided.reason },
    { name: 'anulacion_en', type: sql.DateTimeOffset(0), value: voided.at },
    { name: 'anulacion_por', type: sql.NVarChar(100), value: voided.by },
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

/**
 * Inserta el RIM solo si su UUID no existe, en una transacción que además:
 *  - con número (RIM-AA-NNNN), comprueba que el número sea de un talonario
 *    entregado a la instalación que lo emitió y guarda ese talonario;
 *  - si llega anulado, registra su anulación junto con el RIM.
 * Solo usa INSERT; el índice único de (gestion, numero) impide que dos RIM
 * compartan número.
 */
function buildRimInsertQuery(tables, columns, { numbered, voided }) {
  const names = columns.map((column) => `[${column.name}]`);
  const values = columns.map((column) => `@${column.name}`);
  if (numbered) {
    names.push('[talonario_id]');
    values.push('@talonario_id');
  }
  return `
    SET XACT_ABORT ON;
    DECLARE @inserted bit = 0;${numbered ? `
    DECLARE @talonario_id int = NULL;` : ''}
    BEGIN TRANSACTION;
    IF NOT EXISTS (SELECT 1 FROM ${tables.rim} WHERE [uuid] = @uuid)
    BEGIN${numbered ? `
      SELECT @talonario_id = [id] FROM ${tables.talonarios}
      WHERE [gestion] = @gestion AND @numero BETWEEN [desde] AND [hasta]
        AND [origen] = N'servicemet' AND [instalacion] = @instalacion;
      IF @talonario_id IS NULL
        THROW 51020, N'El número del RIM no pertenece a un talonario entregado a este teléfono.', 1;` : ''}
      INSERT INTO ${tables.rim} (${names.join(', ')}) VALUES (${values.join(', ')});${voided ? `
      INSERT INTO ${tables.anulaciones}
        ([rim_uuid], [motivo], [anulado_en], [anulado_por], [origen], [reg_usuario])
      VALUES (@uuid, @anulacion_motivo, @anulacion_en, @anulacion_por, N'servicemet', @reg_usuario);` : ''}
      SET @inserted = 1;
    END
    COMMIT TRANSACTION;
    SELECT TOP (1) [n], @inserted AS [inserted] FROM ${tables.rim} WHERE [uuid] = @uuid;
  `;
}

function buildFindQuery(table) {
  return `SELECT TOP (1) [n], CONVERT(bit, 0) AS [inserted] FROM ${table} WHERE [uuid] = @uuid;`;
}

/** Reserva un talonario con dbo.rim_reservar_talonario (script 014). */
function buildReserveQuery(procedure) {
  return `
    EXEC ${procedure}
      @solicitud = @solicitud, @gestion = @gestion, @cantidad = @cantidad,
      @origen = N'servicemet', @usuario = @usuario, @instalacion = @instalacion,
      @dispositivo = @dispositivo, @reg_por = @reg_por, @app_version = @app_version;
  `;
}

/**
 * Registra una sola vez el cierre de un talonario de la instalación: los
 * números posteriores a @ultimo_usado ya no se usarán.
 */
function buildClosureQuery(tables) {
  return `
    SET XACT_ABORT ON;
    DECLARE @inserted bit = 0, @desde int = NULL, @hasta int = NULL;
    SELECT @desde = [desde], @hasta = [hasta] FROM ${tables.talonarios}
    WHERE [id] = @talonario_id AND [origen] = N'servicemet' AND [instalacion] = @instalacion;
    IF @desde IS NULL
      THROW 51021, N'El talonario no existe o no fue entregado a este teléfono.', 1;
    IF @ultimo_usado IS NOT NULL AND @ultimo_usado NOT BETWEEN @desde AND @hasta
      THROW 51022, N'El último número usado no pertenece al talonario.', 1;
    IF NOT EXISTS (SELECT 1 FROM ${tables.cierres} WHERE [talonario_id] = @talonario_id)
    BEGIN
      INSERT INTO ${tables.cierres}
        ([talonario_id], [ultimo_usado], [motivo], [origen], [usuario], [reg_por])
      VALUES (@talonario_id, @ultimo_usado, @motivo, N'servicemet', @usuario, @reg_por);
      SET @inserted = 1;
    END
    SELECT TOP (1) [id], @inserted AS [inserted] FROM ${tables.cierres}
    WHERE [talonario_id] = @talonario_id;
  `;
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

function notReadyError(database, script = '012_create_servicios_extras.sql') {
  return new ExtrasError(
    `El servidor todavía no tiene lista la base ${database} (falta ejecutar sql/${script}).`,
    { code: 'EXTRAS_NOT_READY', statusCode: 503 },
  );
}

/** Error de un THROW 510xx de las consultas de numeración, o null. */
function sqlError(error) {
  const known = SQL_ERRORS[error?.number];
  if (!known) return null;
  return new ExtrasError(error.message, known);
}

function requirePositive(value, message) {
  const number = Number(value);
  if (!Number.isSafeInteger(number) || number <= 0) {
    throw new ExtrasError(message, { code: 'IDENTITY_NOT_RETURNED', statusCode: 500 });
  }
  return number;
}

/**
 * Guarda los formularios adicionales de ServiceMET (RIM y oportunidades de
 * Bitrix24) en la base `servicios_extras` y entrega los talonarios con los
 * que la app numera los RIM. Solo inserta: un formulario ya registrado no se
 * modifica.
 *
 * @param {object} options
 * @param {string} options.database Nombre de la base de formularios.
 * @param {Function} options.run `(texto, parámetros) => filas`.
 * @param {Function} [options.resolveUserName] Nombre del usuario autenticado.
 * @param {number} [options.talonarioSize] Números por talonario.
 */
function createExtrasService({
  database,
  run,
  resolveUserName = async () => '',
  talonarioSize = DEFAULT_TALONARIO_SIZE,
}) {
  if (!DATABASE_NAME_PATTERN.test(database)) {
    throw new Error('Nombre de base de formularios inválido.');
  }
  const tables = {
    rim: `[${database}].[dbo].[form_rim]`,
    bitrix: `[${database}].[dbo].[form_bitrix]`,
    anulaciones: `[${database}].[dbo].[form_rim_anulaciones]`,
    talonarios: `[${database}].[dbo].[rim_talonarios]`,
    cierres: `[${database}].[dbo].[rim_talonarios_cierres]`,
  };
  const reserveProcedure = `[${database}].[dbo].[rim_reservar_talonario]`;

  async function registeredName(user) {
    try {
      return await resolveUserName(user);
    } catch (_) {
      // El nombre es una referencia; el usuario autenticado siempre se guarda.
      return '';
    }
  }

  /**
   * Ejecuta un INSERT que solo inserta si el UUID no existe. Si otro envío
   * del mismo UUID ganó la carrera, devuelve su fila; si el UUID no existe,
   * la violación fue del número del RIM.
   */
  async function insertOnce(table, query, params, { notReady = NOT_READY, script } = {}) {
    const uuid = params.find((param) => param.name === 'uuid');
    let rows;
    try {
      rows = await run(query, params);
    } catch (error) {
      if (notReady.has(error?.number)) throw notReadyError(database, script);
      const known = sqlError(error);
      if (known) throw known;
      if (!UNIQUE_VIOLATION.has(error?.number)) throw error;
      rows = await run(buildFindQuery(table), [uuid]);
      if (!rows.length) {
        throw new ExtrasError(
          'Ya hay otro RIM registrado con el mismo número. Revise el talonario del teléfono.',
          { code: 'RIM_NUMBER_TAKEN', statusCode: 409 },
        );
      }
    }
    const n = requirePositive(rows[0]?.n, 'SQL Server no devolvió el correlativo del formulario.');
    return { n, duplicate: !rows[0].inserted };
  }

  /**
   * Registra un RIM. Reenviar el mismo UUID devuelve el ya registrado. Un
   * RIM numerado debe tener un número del talonario entregado a la
   * instalación que lo emitió; uno anulado en el teléfono llega con su
   * anulación y ambas se registran juntas.
   */
  async function saveRim(input, { user } = {}) {
    const rim = validateRim(input);
    const registeredBy = await registeredName(user);
    const columns = rimColumns(rim, { user, registeredBy });
    const params = rim.voided ? [...columns, ...voidedParams(rim.voided)] : columns;
    const numbered = Boolean(rim.numbering);
    const query = buildRimInsertQuery(tables, columns, { numbered, voided: Boolean(rim.voided) });
    const needsNumbering = numbered || Boolean(rim.voided);
    return insertOnce(tables.rim, query, params, needsNumbering
      ? { notReady: NUMBERING_NOT_READY, script: NUMBERING_SCRIPT }
      : {});
  }

  /** Deja constancia de una oportunidad ya registrada en Bitrix24. */
  async function saveBitrixOpportunity(opportunity, { leadId, stageId, user } = {}) {
    const columns = bitrixColumns(opportunity, { leadId, stageId, user });
    return insertOnce(tables.bitrix, buildInsertOnceQuery(tables.bitrix, columns), columns);
  }

  /**
   * Entrega a la instalación de la app un talonario de números de RIM.
   * Repetir la misma solicitud devuelve el mismo talonario.
   */
  async function reserveTalonario(input, { user, now } = {}) {
    const request = validateTalonarioRequest(input, { now });
    const registeredBy = await registeredName(user);
    const params = [
      { name: 'solicitud', type: sql.UniqueIdentifier, value: request.requestId },
      { name: 'gestion', type: sql.SmallInt, value: request.year },
      { name: 'cantidad', type: sql.Int, value: talonarioSize },
      { name: 'usuario', type: sql.NVarChar(100), value: user },
      { name: 'instalacion', type: sql.UniqueIdentifier, value: request.installationId },
      { name: 'dispositivo', type: sql.NVarChar(120), value: nullable(request.device) },
      { name: 'reg_por', type: sql.NVarChar(150), value: nullable(registeredBy) },
      { name: 'app_version', type: sql.NVarChar(30), value: nullable(request.appVersion) },
    ];
    let rows;
    try {
      rows = await run(buildReserveQuery(reserveProcedure), params);
    } catch (error) {
      if (NUMBERING_NOT_READY.has(error?.number)) throw notReadyError(database, NUMBERING_SCRIPT);
      throw sqlError(error) ?? error;
    }
    const row = rows[0] ?? {};
    const id = requirePositive(row.id, 'SQL Server no devolvió el talonario.');
    if (String(row.instalacion ?? '').toLowerCase() !== request.installationId) {
      // La misma solicitud ya se usó desde otra instalación.
      throw new ExtrasError('La solicitud de talonario pertenece a otro teléfono.', {
        code: 'RIM_TALONARIO_CONFLICT',
        statusCode: 409,
      });
    }
    return {
      id,
      year: Number(row.gestion),
      from: Number(row.desde),
      to: Number(row.hasta),
      duplicate: !row.nuevo,
    };
  }

  /**
   * Registra que la instalación ya no usará el resto del talonario (por
   * ejemplo, al terminar la gestión). Repetirlo no crea otro cierre.
   */
  async function closeTalonario(id, input, { user } = {}) {
    const closure = validateTalonarioClosure(id, input);
    const registeredBy = await registeredName(user);
    const params = [
      { name: 'talonario_id', type: sql.Int, value: closure.talonarioId },
      { name: 'instalacion', type: sql.UniqueIdentifier, value: closure.installationId },
      { name: 'ultimo_usado', type: sql.Int, value: closure.lastUsed },
      { name: 'motivo', type: sql.NVarChar(30), value: closure.reason },
      { name: 'usuario', type: sql.NVarChar(100), value: user },
      { name: 'reg_por', type: sql.NVarChar(150), value: nullable(registeredBy) },
    ];
    const query = buildClosureQuery(tables);
    let rows;
    try {
      rows = await run(query, params);
    } catch (error) {
      if (NUMBERING_NOT_READY.has(error?.number)) throw notReadyError(database, NUMBERING_SCRIPT);
      const known = sqlError(error);
      if (known) throw known;
      if (!UNIQUE_VIOLATION.has(error?.number)) throw error;
      // Dos cierres simultáneos del mismo talonario: queda el primero.
      rows = await run(query, params);
    }
    return {
      id: requirePositive(rows[0]?.id, 'SQL Server no devolvió el cierre del talonario.'),
      duplicate: !rows[0].inserted,
    };
  }

  return { saveRim, saveBitrixOpportunity, reserveTalonario, closeTalonario };
}

/** Servicio conectado al SQL Server de la API. */
function defaultExtrasService(config) {
  return createExtrasService({
    database: config.extras?.database ?? DEFAULT_EXTRAS_DATABASE,
    talonarioSize: config.extras?.talonarioSize ?? DEFAULT_TALONARIO_SIZE,
    run: createSqlRunner(config),
    resolveUserName: async (user) => resolveRegisteredBy(await getPool(config), user),
  });
}

module.exports = {
  DEFAULT_EXTRAS_DATABASE,
  DEFAULT_TALONARIO_SIZE,
  bitrixColumns,
  buildClosureQuery,
  buildFindQuery,
  buildInsertOnceQuery,
  buildReserveQuery,
  buildRimInsertQuery,
  createExtrasService,
  defaultExtrasService,
  readExtrasConfig,
  rimColumns,
};
