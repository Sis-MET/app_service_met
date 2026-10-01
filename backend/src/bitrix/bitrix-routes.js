'use strict';

const express = require('express');

/** Scope del JWT que habilita las rutas de oportunidades comerciales. */
const BITRIX_SCOPE = 'bitrix:opportunity';

/**
 * Rutas `/api/bitrix/*`. Solo traducen HTTP ↔ BitrixService: la lógica de
 * Bitrix vive en el servicio.
 *
 * @param {object} options
 * @param {object|null} options.service BitrixService, o null si no está configurado.
 * @param {object} options.bitrixConfig Configuración leída de `.env`.
 * @param {Function} options.requireAuth Middleware JWT de la API.
 * @param {Function} options.requireScope Fábrica de middleware de scope.
 * @param {Function} [options.onOpportunityRegistered] Recibe la oportunidad
 *   validada y `{ leadId, stageId, user }` cuando ya está en Bitrix24.
 * @param {object} [options.logger]
 */
function createBitrixRouter({
  service,
  bitrixConfig,
  requireAuth,
  requireScope,
  onOpportunityRegistered,
  logger = console,
}) {
  const router = express.Router();
  router.use(requireAuth, requireScope(BITRIX_SCOPE));

  router.get('/status', async (_req, res) => {
    if (!service) {
      return res.json({
        configured: false,
        message: bitrixConfig?.configError || 'La integración con Bitrix24 no está configurada.',
      });
    }
    return res.json(await service.status());
  });

  router.use((_req, res, next) => {
    if (service) return next();
    return res.status(503).json({
      error: 'BITRIX_NOT_CONFIGURED',
      message: 'La integración con Bitrix24 no está configurada en el servidor.',
    });
  });

  router.get('/companies', async (req, res) => {
    res.json(await service.searchCompanies(req.query.q, { limit: req.query.limit }));
  });

  router.get('/companies/:id/contacts', async (req, res) => {
    res.json(await service.getContactsByCompany(req.params.id));
  });

  router.get('/form-options', async (_req, res) => {
    res.json(await service.formOptions());
  });

  router.get('/lead-stages', async (_req, res) => {
    const [stages, target] = await Promise.all([
      service.getLeadStages(),
      service.resolveTarget().catch(() => null),
    ]);
    res.json({ items: stages, target });
  });

  router.get('/lead-sources', async (_req, res) => {
    res.json({ items: await service.getLeadSources() });
  });

  router.get('/lead-fields', async (_req, res) => {
    res.json({ items: await service.getLeadFields() });
  });

  router.post('/opportunities', async (req, res) => {
    const result = await service.createOpportunity(req.body, { user: req.auth.sub });
    if (result.warnings?.length) {
      for (const warning of result.warnings) logger.warn?.(`[Bitrix] ${warning}`);
    }
    if (onOpportunityRegistered && result.opportunity) {
      try {
        await onOpportunityRegistered(result.opportunity, {
          leadId: result.leadId,
          stageId: result.stageId,
          user: req.auth.sub,
        });
      } catch (error) {
        // El prospecto ya existe en Bitrix24; reenviar la oportunidad vuelve
        // a intentar esta copia.
        logger.warn?.(`[Extras] no se registró la oportunidad ${result.leadId} en form_bitrix: ${error.message}`);
      }
    }
    res.status(result.duplicate ? 200 : 201).json({
      leadId: result.leadId,
      duplicate: result.duplicate,
      stageId: result.stageId,
      mappedFields: result.mappedFields,
      message: result.duplicate
        ? `La oportunidad ya estaba registrada como prospecto #${result.leadId}.`
        : `Prospecto #${result.leadId} registrado en Bitrix24.`,
    });
  });

  // Errores de Bitrix y de validación: mensaje claro y código estable para la
  // app. Lo demás sigue al manejador general, que oculta los detalles.
  router.use((error, _req, res, next) => {
    if (!error?.expose || !error.code) return next(error);
    if (error.statusCode >= 500) logger.warn?.(`[Bitrix] ${error.code}: ${error.message}`);
    return res.status(error.statusCode).json({
      error: error.code,
      message: error.message,
      ...(error.details ? { details: error.details } : {}),
    });
  });

  return router;
}

module.exports = { BITRIX_SCOPE, createBitrixRouter };
