'use strict';

const express = require('express');
const cors = require('cors');
const { sql, getPool } = require('./database');
const {
  signJwt,
  authMiddleware,
  requireScope,
  createLoginLimiter,
} = require('./security');
const { validateAgainstDatabase, uploadRecords } = require('./calibration-service');
const {
  validateAgainstDatabase: validateSupportAgainstDatabase,
  uploadSupportRecords,
} = require('./support-service');
const { readBootstrap } = require('./bootstrap-service');
const { createBitrixClient } = require('./bitrix/bitrix-client');
const { createBitrixService } = require('./bitrix/bitrix-service');
const { BITRIX_SCOPE, createBitrixRouter } = require('./bitrix/bitrix-routes');
const { defaultExtrasService } = require('./extras/extras-service');
const { EXTRAS_SCOPE, createExtrasRouter } = require('./extras/extras-routes');

function defaultBitrixService(bitrixConfig) {
  if (!bitrixConfig?.enabled) return null;
  const client = createBitrixClient({
    webhookUrl: bitrixConfig.webhookUrl,
    webhookSecret: bitrixConfig.webhookSecret,
    timeoutMs: bitrixConfig.timeoutMs,
    logRequests: bitrixConfig.logRequests,
  });
  return createBitrixService({ client, config: bitrixConfig });
}

function createApp(config, schema, supportSchemas = new Map(), options = {}) {
  const app = express();
  if (config.trustProxy) app.set('trust proxy', 1);
  app.disable('x-powered-by');
  app.use(cors({
    origin(origin, callback) {
      if (!origin || config.corsOrigins.length === 0 || config.corsOrigins.includes(origin)) {
        return callback(null, true);
      }
      return callback(new Error('Origen no permitido'));
    },
  }));
  app.use(express.json({ limit: '10mb' }));

  app.get('/health', async (_req, res, next) => {
    try {
      const pool = await getPool(config);
      await pool.request().query('SELECT 1 AS ok');
      res.json({ status: 'ok' });
    } catch (error) {
      next(error);
    }
  });

  app.post('/api/auth/login', createLoginLimiter(), async (req, res, next) => {
    const usuario = String(req.body?.usuario ?? '').trim();
    const password = String(req.body?.password ?? '');
    if (!usuario || !password) {
      return res.status(400).json({ error: 'MISSING_CREDENTIALS', message: 'Usuario y contraseña son obligatorios.' });
    }
    try {
      const pool = await getPool(config);
      const request = pool.request();
      request.input('usuario', sql.NVarChar(100), usuario);
      request.input('password', sql.NVarChar(255), password);
      const result = await request.query(`
        SELECT TOP 1 [usuario], [nombre1], [apellido1], [apellido2], [titulo_abr], [estado], [acceso_app]
        FROM [dbo].[data_users]
        WHERE [usuario] = @usuario AND [pass] = @password
      `);
      const user = result.recordset[0];
      if (!user) {
        return res.status(401).json({ error: 'INVALID_CREDENTIALS', message: 'Usuario o contraseña incorrectos.' });
      }
      if (String(user.acceso_app) !== '1' || String(user.estado).toUpperCase() !== 'ACTIVO') {
        return res.status(403).json({ error: 'ACCESS_DENIED', message: 'El usuario no está habilitado para ServiceMET.' });
      }
      const token = signJwt(
        {
          sub: user.usuario,
          scope: [
            'calibracion:upload',
            'soporte:upload',
            'bootstrap:read',
            BITRIX_SCOPE,
            EXTRAS_SCOPE,
          ],
        },
        config.jwtSecret,
        config.jwtTtlSeconds,
      );
      return res.json({
        token,
        expiresIn: config.jwtTtlSeconds,
        user: {
          usuario: user.usuario,
          nombre1: user.nombre1,
          apellido1: user.apellido1,
          apellido2: user.apellido2,
          tituloAbr: user.titulo_abr,
          estado: user.estado,
          accesoApp: String(user.acceso_app),
          nombre: [user.titulo_abr, user.nombre1, user.apellido1, user.apellido2].filter(Boolean).join(' '),
        },
      });
    } catch (error) {
      return next(error);
    }
  });

  const requireAuth = authMiddleware(config);

  app.get('/api/bootstrap', requireAuth, async (_req, res, next) => {
    try {
      const pool = await getPool(config);
      return res.json(await readBootstrap(pool));
    } catch (error) {
      return next(error);
    }
  });

  app.post('/api/calibracion/validar', requireAuth, async (req, res, next) => {
    try {
      const validation = await validateAgainstDatabase(
        config,
        schema,
        req.body?.records,
        req.auth.sub,
      );
      const validCount = validation.records.filter((record) => record.valid).length;
      return res.json({
        valid: validation.batchErrors.length === 0 && validCount === validation.records.length,
        total: validation.records.length,
        validCount,
        invalidCount: validation.records.length - validCount,
        batchErrors: validation.batchErrors,
        records: validation.records.map(({ normalized, location, ...record }) => record),
      });
    } catch (error) {
      return next(error);
    }
  });

  app.post('/api/calibracion/subir', requireAuth, async (req, res, next) => {
    try {
      const result = await uploadRecords(
        config,
        schema,
        req.body?.records,
        req.body?.mode ?? 'all',
        req.auth.sub,
        req.body?.ubicaciones,
      );
      const invalidRecords = result.validation.records
        .filter((record) => !record.valid)
        .map(({ normalized, location, ...record }) => record);
      if (result.rejected) {
        return res.status(422).json({
          error: 'BATCH_REJECTED',
          message: 'No se insertó ningún registro.',
          uploaded: [],
          invalidRecords,
          batchErrors: result.validation.batchErrors,
        });
      }
      return res.status(201).json({
        message: `${result.uploaded.length} registro(s) insertado(s) correctamente.`,
        uploaded: result.uploaded,
        invalidRecords,
      });
    } catch (error) {
      return next(error);
    }
  });

  app.post('/api/soporte/validar', requireAuth, async (req, res, next) => {
    try {
      const validation = await validateSupportAgainstDatabase(
        config,
        supportSchemas,
        req.body?.records,
        req.auth.sub,
      );
      const validCount = validation.records.filter((record) => record.valid).length;
      return res.json({
        valid: validation.batchErrors.length === 0 && validCount === validation.records.length,
        total: validation.records.length,
        validCount,
        invalidCount: validation.records.length - validCount,
        batchErrors: validation.batchErrors,
        records: validation.records.map(({ normalized, location, ...record }) => record),
      });
    } catch (error) {
      return next(error);
    }
  });

  app.post('/api/soporte/subir', requireAuth, async (req, res, next) => {
    try {
      const result = await uploadSupportRecords(
        config,
        supportSchemas,
        req.body?.records,
        req.body?.mode ?? 'all',
        req.auth.sub,
      );
      const invalidRecords = result.validation.records
        .filter((record) => !record.valid)
        .map(({ normalized, location, ...record }) => record);
      if (result.rejected) {
        return res.status(422).json({
          error: 'BATCH_REJECTED',
          message: 'No se insertó ningún registro de soporte.',
          uploaded: [],
          invalidRecords,
          batchErrors: result.validation.batchErrors,
        });
      }
      return res.status(201).json({
        message: `${result.uploaded.length} registro(s) de soporte insertado(s) correctamente.`,
        uploaded: result.uploaded,
        invalidRecords,
      });
    } catch (error) {
      return next(error);
    }
  });

  // Formularios adicionales (RIM y copia de las oportunidades de Bitrix24),
  // en la base servicios_extras.
  const extrasService = options.extrasService !== undefined
    ? options.extrasService
    : defaultExtrasService(config);

  app.use('/api/bitrix', createBitrixRouter({
    service: options.bitrixService !== undefined
      ? options.bitrixService
      : defaultBitrixService(config.bitrix),
    bitrixConfig: config.bitrix,
    requireAuth,
    requireScope,
    // La oportunidad ya está en Bitrix24: la copia en form_bitrix no debe
    // hacer fallar la respuesta.
    onOpportunityRegistered: extrasService
      ? (opportunity, registered) => extrasService.saveBitrixOpportunity(opportunity, registered)
      : undefined,
  }));

  if (extrasService) {
    app.use('/api/extras', createExtrasRouter({
      service: extrasService,
      requireAuth,
      requireScope,
    }));
  }

  app.use((_req, res) => {
    res.status(404).json({ error: 'NOT_FOUND', message: 'Ruta no encontrada.' });
  });

  app.use((error, _req, res, _next) => {
    console.error('[ServiceMET API]', error);
    const status = error.statusCode || 500;
    res.status(status).json({
      error: error.code || 'INTERNAL_ERROR',
      message: status >= 500 ? 'No se pudo completar la operación en el servidor.' : error.message,
    });
  });
  return app;
}

module.exports = { createApp };
