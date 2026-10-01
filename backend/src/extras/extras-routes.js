'use strict';

const express = require('express');

/** Scope del JWT que habilita la subida de formularios adicionales. */
const EXTRAS_SCOPE = 'extras:upload';

/**
 * Rutas `/api/extras/*`: formularios que el técnico llena dentro de un
 * servicio y que no pertenecen a las tablas de DataMET.
 *
 * @param {object} options
 * @param {object} options.service ExtrasService.
 * @param {Function} options.requireAuth Middleware JWT de la API.
 * @param {Function} options.requireScope Fábrica de middleware de scope.
 * @param {object} [options.logger]
 */
function createExtrasRouter({ service, requireAuth, requireScope, logger = console }) {
  const router = express.Router();
  router.use(requireAuth, requireScope(EXTRAS_SCOPE));

  // Recepción de instrumentos de pesaje (RIM), con la firma del cliente.
  // 201 si se registró; 200 si ese UUID ya estaba registrado.
  router.post('/rim', async (req, res) => {
    const result = await service.saveRim(req.body, { user: req.auth.sub });
    res.status(result.duplicate ? 200 : 201).json({
      n: result.n,
      duplicate: result.duplicate,
      message: result.duplicate
        ? `El RIM ya estaba registrado con el N.º ${result.n}.`
        : `RIM registrado con el N.º ${result.n}.`,
    });
  });

  // Errores de validación o de configuración: mensaje claro y código estable
  // para la app. Lo demás sigue al manejador general, que oculta los detalles.
  router.use((error, _req, res, next) => {
    if (!error?.expose || !error.code) return next(error);
    if (error.statusCode >= 500) logger.warn?.(`[Extras] ${error.code}: ${error.message}`);
    return res.status(error.statusCode).json({
      error: error.code,
      message: error.message,
      ...(error.details ? { details: error.details } : {}),
    });
  });

  return router;
}

module.exports = { EXTRAS_SCOPE, createExtrasRouter };
