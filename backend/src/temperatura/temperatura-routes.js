'use strict';

const express = require('express');

/** Las calibraciones de temperatura se suben con el permiso de calibración. */
const TEMPERATURE_SCOPE = 'calibracion:upload';

/**
 * `POST /api/calibracion/temperatura`: una calibración de temperatura
 * completa. 201 si se registró; 200 si ese uuid ya estaba.
 */
function createTemperaturaRouter({ service, requireAuth, requireScope, logger = console }) {
  const router = express.Router();
  router.use(requireAuth, requireScope(TEMPERATURE_SCOPE));

  router.post('/', async (req, res) => {
    const result = await service.save(req.body, { user: req.auth.sub });
    res.status(result.duplicate ? 200 : 201).json({
      n: result.n,
      duplicate: result.duplicate,
      message: result.duplicate
        ? `La calibración ya estaba registrada con el N.º ${result.n}.`
        : `Calibración de temperatura registrada con el N.º ${result.n}.`,
    });
  });

  router.use((error, _req, res, next) => {
    if (!error?.expose || !error.code) return next(error);
    if (error.statusCode >= 500) logger.warn?.(`[Temperatura] ${error.code}: ${error.message}`);
    return res.status(error.statusCode).json({
      error: error.code,
      message: error.message,
      ...(error.details ? { details: error.details } : {}),
    });
  });

  return router;
}

module.exports = { TEMPERATURE_SCOPE, createTemperaturaRouter };
