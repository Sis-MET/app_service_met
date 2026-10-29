'use strict';

const { sql, getPool } = require('../database');
const { normalizeLocation, LOCATION_COLUMNS } = require('../location');
const { SERVICE_SUMMARY_TABLE } = require('../schema');
const {
  TEMPERATURE_SERVICE_CODE,
  TemperaturaError,
  validateTemperatura,
} = require('./temperatura-validation');

const TABLES = Object.freeze({
  header: '[dbo].[DATA_SERVICIOS_DATOS_CAL_TE]',
  patrones: '[dbo].[DATA_SERVICIOS_DATOS_CAL_TE_PATRONES]',
  canales: '[dbo].[DATA_SERVICIOS_DATOS_CAL_TE_CANALES]',
  puntos: '[dbo].[DATA_SERVICIOS_DATOS_CAL_TE_PUNTOS]',
  lecturas: '[dbo].[DATA_SERVICIOS_DATOS_CAL_TE_LECTURAS]',
  correcciones: '[dbo].[DATA_SERVICIOS_DATOS_CAL_TE_CORRECCIONES]',
  summary: `[dbo].[${SERVICE_SUMMARY_TABLE}]`,
});

const LOCK_RESOURCE = 'ServiceMET:calibracion-temperatura:upload';
const SCRIPT = '017_calibracion_temperatura.sql';

/** SQL Server admite 2100 parámetros por consulta; se deja margen. */
const MAX_PARAMETERS = 2000;
const MAX_ROWS = 1000;

/** La tabla o el permiso todavía no existen: falta el script 017. */
const NOT_READY = new Set([208, 229, 230, 4060]);
const UNIQUE_VIOLATION = new Set([2601, 2627]);

const offset = (precision) => (parameter) =>
  `CONVERT(datetimeoffset(${precision}), ${parameter})`;

// Columnas de cada tabla: nombre, tipo y, si hace falta, cómo convertir el
// parámetro (las fechas llegan como texto ISO con su desfase y así lo
// conservan).
const COLUMNS = Object.freeze({
  header: [
    ['uuid', () => sql.UniqueIdentifier],
    ['codigo_registro', () => sql.NVarChar(100)],
    ['seca', () => sql.NVarChar(50)],
    ['session_id', () => sql.NVarChar(100)],
    ['cod_metrica', () => sql.NVarChar(50)],
    ['equipo_nuevo', () => sql.Bit],
    ['codigo_cliente', () => sql.NVarChar(20)],
    ['cliente', () => sql.NVarChar(255)],
    ['razon_social', () => sql.NVarChar(255)],
    ['cod_planta', () => sql.NVarChar(20)],
    ['planta', () => sql.NVarChar(255)],
    ['dep', () => sql.NVarChar(100)],
    ['dir', () => sql.NVarChar(255)],
    ['tipo_equipo', () => sql.NVarChar(60)],
    ['instrumento', () => sql.NVarChar(150)],
    ['marca', () => sql.NVarChar(100)],
    ['modelo', () => sql.NVarChar(100)],
    ['serie', () => sql.NVarChar(100)],
    ['cod_interno', () => sql.NVarChar(100)],
    ['ubicacion', () => sql.NVarChar(255)],
    ['rango_min', () => sql.Decimal(9, 3)],
    ['rango_max', () => sql.Decimal(9, 3)],
    ['unidad', () => sql.NVarChar(5)],
    ['resolucion', () => sql.Decimal(9, 4)],
    ['indicador', () => sql.NVarChar(30)],
    ['temp_amb_inicio', () => sql.Decimal(6, 2)],
    ['hr_inicio', () => sql.Decimal(6, 2)],
    ['temp_amb_fin', () => sql.Decimal(6, 2)],
    ['hr_fin', () => sql.Decimal(6, 2)],
    ['fecha_servicio', () => sql.NVarChar(10), (p) => `CONVERT(date, ${p}, 23)`],
    ['hora_inicio', () => sql.NVarChar(40), offset(0)],
    ['hora_fin', () => sql.NVarChar(40), offset(0)],
    ['finalizado_en', () => sql.NVarChar(40), offset(0)],
    ['personal', () => sql.NVarChar(150)],
    ['observaciones', () => sql.NVarChar(2000)],
    ['registro_sensores', () => sql.NVarChar(255)],
    ['app_version', () => sql.NVarChar(30)],
    ['reg_usuario', () => sql.NVarChar(100)],
    ['reg_por', () => sql.NVarChar(50)],
  ],
  patrones: [
    ['servicio_uuid', () => sql.UniqueIdentifier],
    ['n', () => sql.Int],
    ['cod_instrumento', () => sql.NVarChar(50)],
    ['instrumento', () => sql.NVarChar(150)],
    ['cert_fecha', () => sql.NVarChar(30)],
    ['ente_calibrador', () => sql.NVarChar(150)],
    ['estado', () => sql.NVarChar(50)],
    ['uso', () => sql.NVarChar(20)],
  ],
  canales: [
    ['servicio_uuid', () => sql.UniqueIdentifier],
    ['n_canal', () => sql.Int],
    ['nombre', () => sql.NVarChar(60)],
    ['rol', () => sql.NVarChar(10)],
    ['cod_patron', () => sql.NVarChar(50)],
    ['posicion', () => sql.NVarChar(100)],
    ['metodo', () => sql.NVarChar(10)],
    ['decimales', () => sql.TinyInt],
  ],
  puntos: [
    ['servicio_uuid', () => sql.UniqueIdentifier],
    ['n_punto', () => sql.Int],
    ['temperatura_nominal', () => sql.Decimal(9, 3)],
    ['estabilizacion_min', () => sql.Decimal(9, 2)],
    ['duracion_min', () => sql.Decimal(9, 2)],
    ['intervalo_s', () => sql.Int],
    ['lecturas_programadas', () => sql.Int],
    ['estado', () => sql.NVarChar(20)],
    ['inicio_medicion', () => sql.NVarChar(40), offset(3)],
    ['fin_medicion', () => sql.NVarChar(40), offset(3)],
    ['motivo_interrupcion', () => sql.NVarChar(500)],
    ['observaciones', () => sql.NVarChar(1000)],
  ],
  lecturas: [
    ['servicio_uuid', () => sql.UniqueIdentifier],
    ['n_punto', () => sql.Int],
    ['n_lectura', () => sql.Int],
    ['n_canal', () => sql.Int],
    ['tiempo_programado_s', () => sql.Int],
    ['capturada_en', () => sql.NVarChar(40), offset(3)],
    ['valor', () => sql.Decimal(9, 3)],
    ['valor_original', () => sql.Decimal(9, 3)],
    ['texto_leido', () => sql.NVarChar(60)],
    ['origen', () => sql.NVarChar(20)],
    ['coincidencia', () => sql.Decimal(4, 3)],
    ['cuadros', () => sql.SmallInt],
    ['alerta', () => sql.NVarChar(100)],
    ['estado', () => sql.NVarChar(20)],
    ['motivo', () => sql.NVarChar(200)],
  ],
  correcciones: [
    ['servicio_uuid', () => sql.UniqueIdentifier],
    ['n_punto', () => sql.Int],
    ['n_lectura', () => sql.Int],
    ['n_canal', () => sql.Int],
    ['tipo', () => sql.NVarChar(20)],
    ['valor_anterior', () => sql.Decimal(9, 3)],
    ['valor_nuevo', () => sql.Decimal(9, 3)],
    ['motivo', () => sql.NVarChar(500)],
    ['usuario', () => sql.NVarChar(150)],
    ['fecha', () => sql.NVarChar(40), offset(0)],
  ],
});

/**
 * Consultas INSERT de [rows] en [table], en lotes que respetan el límite de
 * parámetros de SQL Server. Cada consulta: `{ text, params }`.
 */
function buildInserts(table, columns, rows, { output = false } = {}) {
  if (rows.length === 0) return [];
  const perRow = columns.length;
  const chunk = Math.max(1, Math.min(MAX_ROWS, Math.floor(MAX_PARAMETERS / perRow)));
  const names = columns.map(([name]) => `[${name}]`).join(', ');
  const queries = [];
  for (let start = 0; start < rows.length; start += chunk) {
    const params = [];
    const values = rows.slice(start, start + chunk).map((row, r) => {
      const cells = columns.map(([name, type, wrap], c) => {
        const parameter = `p${r}_${c}`;
        params.push({ name: parameter, type: type(), value: row[name] ?? null });
        return wrap ? wrap(`@${parameter}`) : `@${parameter}`;
      });
      return `(${cells.join(', ')})`;
    });
    queries.push({
      text: `INSERT INTO ${table} (${names})${output ? ' OUTPUT INSERTED.[n]' : ''}\nVALUES ${values.join(',\n')};`,
      params,
    });
  }
  return queries;
}

function summaryInsert({ codigoRegistro, regPor, nombreCsv, location, withLocation }) {
  const locationColumns = withLocation ? ', [latitud], [longitud], [precision_gps], [fecha_gps]' : '';
  const locationValues = withLocation ? ', @latitud, @longitud, @precisionGps, @fechaGps' : '';
  const params = [
    { name: 'codigoRegistro', type: sql.NVarChar(100), value: codigoRegistro },
    { name: 'regPor', type: sql.NVarChar(50), value: regPor },
    { name: 'nombreCsv', type: sql.NVarChar(100), value: nombreCsv },
    { name: 'estadoServicio', type: sql.NVarChar(50), value: 'EN OBSERVACION' },
    { name: 'tipoServicio', type: sql.NVarChar(10), value: TEMPERATURE_SERVICE_CODE },
  ];
  if (withLocation) {
    params.push(
      { name: 'latitud', type: sql.Decimal(9, 6), value: location?.latitud ?? null },
      { name: 'longitud', type: sql.Decimal(9, 6), value: location?.longitud ?? null },
      { name: 'precisionGps', type: sql.Decimal(7, 1), value: location?.precisionGps ?? null },
      { name: 'fechaGps', type: sql.DateTimeOffset(0), value: location?.fechaGps ?? null },
    );
  }
  return {
    text: `
      INSERT INTO ${TABLES.summary}
        ([codigo_registro], [fecha_reg], [reg_por], [nombre_csv], [estado_servicio], [tipo_servicio]${locationColumns})
      OUTPUT INSERTED.[n]
      VALUES
        (@codigoRegistro, CONVERT(date, GETDATE()), @regPor, @nombreCsv, @estadoServicio, @tipoServicio${locationValues});
    `,
    params,
  };
}

function notReady() {
  return new TemperaturaError(
    `El servidor todavía no recibe calibraciones de temperatura (falta ejecutar sql/${SCRIPT}).`,
    { code: 'TEMPERATURA_NOT_READY', statusCode: 503 },
  );
}

/**
 * Guarda en DataMET las calibraciones de temperatura que sube la app, en una
 * sola transacción y solo con INSERT: una calibración subida no se modifica.
 * Con el mismo uuid responde que ya estaba (la app reintenta sin duplicar).
 *
 * @param {object} options
 * @param {Function} options.transaction `(trabajo) => resultado`; el
 *   trabajo recibe `exec(texto, parámetros) => filas` dentro de una
 *   transacción, que se confirma si el trabajo termina y se revierte si
 *   lanza.
 */
function createTemperaturaService({ transaction }) {
  async function save(body, { user }) {
    const { value, issues } = validateTemperatura(body);
    if (issues.length > 0) {
      throw new TemperaturaError('El registro de temperatura no es válido.', {
        code: 'VALIDATION_ERROR',
        statusCode: 422,
        details: issues,
      });
    }
    const { header } = value;
    const uuid = header.uuid;

    return transaction(async (exec) => {
      // Serializa las subidas de temperatura de todos los teléfonos.
      const lock = await exec(`
        DECLARE @lockResult int;
        EXEC @lockResult = sys.sp_getapplock
          @Resource = @resource, @LockMode = 'Exclusive',
          @LockOwner = 'Transaction', @LockTimeout = 30000,
          @DbPrincipal = 'public';
        SELECT @lockResult AS [lockResult];
      `, [{ name: 'resource', type: sql.NVarChar(255), value: LOCK_RESOURCE }]);
      if (!(Number(lock[0]?.lockResult) >= 0)) {
        throw new TemperaturaError('Otra subida está en curso. Intente en unos segundos.', {
          code: 'UPLOAD_LOCK_TIMEOUT',
          statusCode: 503,
        });
      }

      const ready = await exec(
        `SELECT OBJECT_ID(N'dbo.DATA_SERVICIOS_DATOS_CAL_TE_CORRECCIONES', N'U') AS [id];`,
        [],
      );
      if (ready[0]?.id === null || ready[0]?.id === undefined) throw notReady();

      const uuidParam = [{ name: 'uuid', type: sql.UniqueIdentifier, value: uuid }];
      const existing = await exec(
        `SELECT TOP (1) [n] FROM ${TABLES.header} WHERE [uuid] = @uuid;`,
        uuidParam,
      );
      if (existing.length > 0) return { n: Number(existing[0].n), duplicate: true };

      const taken = await exec(`
        SELECT CASE WHEN EXISTS (SELECT 1 FROM ${TABLES.header} WHERE [codigo_registro] = @codigo)
                      OR EXISTS (SELECT 1 FROM ${TABLES.summary} WHERE [codigo_registro] = @codigo)
               THEN 1 ELSE 0 END AS [taken];
      `, [{ name: 'codigo', type: sql.NVarChar(100), value: header.codigo_registro }]);
      if (Number(taken[0]?.taken) === 1) {
        throw new TemperaturaError(
          `El equipo ${header.cod_metrica} ya tiene una calibración en DataMET con la SECA ${header.seca}.`,
          { code: 'ALREADY_EXISTS', statusCode: 409 },
        );
      }

      const users = await exec(`
        SELECT TOP (1) [titulo_abr], [nombre1], [apellido1], [apellido2]
        FROM [dbo].[data_users] WHERE [usuario] = @usuario;
      `, [{ name: 'usuario', type: sql.NVarChar(100), value: user }]);
      const regPor = users[0]
        ? ['titulo_abr', 'nombre1', 'apellido1', 'apellido2']
          .map((key) => String(users[0][key] ?? '').trim())
          .filter(Boolean)
          .join(' ')
        : '';
      if (!regPor || regPor.length > 50) {
        throw new TemperaturaError(
          regPor ? 'El nombre del usuario supera la longitud permitida.' : 'No se encontró el nombre del usuario autenticado.',
          { code: 'REGISTERED_USER_NOT_FOUND', statusCode: 422 },
        );
      }

      const [headerInsert] = buildInserts(TABLES.header, COLUMNS.header, [{
        ...header,
        reg_usuario: user,
        reg_por: regPor,
      }], { output: true });
      const inserted = await exec(headerInsert.text, headerInsert.params);
      const n = Number(inserted[0]?.n);
      if (!Number.isSafeInteger(n)) {
        throw new TemperaturaError('SQL Server no devolvió el número del registro.', {
          code: 'IDENTITY_NOT_RETURNED',
          statusCode: 500,
        });
      }

      const withUuid = (rows) => rows.map((row) => ({ ...row, servicio_uuid: uuid }));
      for (const table of ['patrones', 'canales', 'puntos', 'lecturas', 'correcciones']) {
        for (const query of buildInserts(TABLES[table], COLUMNS[table], withUuid(value[table]))) {
          await exec(query.text, query.params);
        }
      }

      const support = await exec(`
        SELECT CASE WHEN ${LOCATION_COLUMNS.map((column) => `COL_LENGTH(N'dbo.${SERVICE_SUMMARY_TABLE}', N'${column}') IS NOT NULL`).join(' AND ')}
          THEN 1 ELSE 0 END AS [ok];
      `, []);
      const summary = summaryInsert({
        codigoRegistro: header.codigo_registro,
        regPor,
        nombreCsv: `TEMP_${header.codigo_registro}`.slice(0, 100),
        location: normalizeLocation(value.gps),
        withLocation: Number(support[0]?.ok) === 1,
      });
      const summaryRows = await exec(summary.text, summary.params);
      return { n, summaryN: Number(summaryRows[0]?.n) || null, duplicate: false };
    });
  }

  return { save };
}

/** Transacción sobre el pool de la API, con los errores de SQL traducidos. */
function createSqlTransaction(config) {
  return async function transaction(work) {
    const pool = await getPool(config);
    const tx = new sql.Transaction(pool);
    try {
      await tx.begin(sql.ISOLATION_LEVEL.SERIALIZABLE);
    } catch (error) {
      throw translate(error);
    }
    const exec = async (text, params) => {
      const request = new sql.Request(tx);
      for (const param of params) request.input(param.name, param.type, param.value);
      const result = await request.query(text);
      return result.recordset ?? [];
    };
    try {
      const result = await work(exec);
      await tx.commit();
      return result;
    } catch (error) {
      try { await tx.rollback(); } catch (_) { /* ya cerrada */ }
      throw translate(error);
    }
  };
}

function translate(error) {
  if (error instanceof TemperaturaError) return error;
  if (NOT_READY.has(error?.number)) return notReady();
  if (UNIQUE_VIOLATION.has(error?.number)) {
    return new TemperaturaError('El registro ya existe en DataMET.', {
      code: 'ALREADY_EXISTS',
      statusCode: 409,
    });
  }
  return error;
}

function defaultTemperaturaService(config) {
  return createTemperaturaService({ transaction: createSqlTransaction(config) });
}

module.exports = {
  COLUMNS,
  MAX_PARAMETERS,
  TABLES,
  buildInserts,
  createSqlTransaction,
  createTemperaturaService,
  defaultTemperaturaService,
  translate,
};
