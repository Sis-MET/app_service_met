'use strict';

const fs = require('node:fs');
const http = require('node:http');
const https = require('node:https');
const { getConfig } = require('./config');
const { loadTableSchema, loadSupportSchemas } = require('./schema');
const { createApp } = require('./app');
const { closePool } = require('./database');

function logBitrixStatus(bitrix) {
  for (const warning of bitrix.warnings) console.warn(`Bitrix24: ${warning}`);
  if (bitrix.configError) {
    console.warn(`Bitrix24 deshabilitado: ${bitrix.configError}`);
  } else if (!bitrix.enabled) {
    console.log('Bitrix24 deshabilitado: falta BITRIX_WEBHOOK_URL.');
  } else {
    // Solo el dominio del portal: la ruta del webhook contiene el secreto.
    console.log(`Bitrix24 habilitado en ${new URL(bitrix.webhookUrl).host}.`);
  }
}

async function main() {
  const config = getConfig();
  const schema = loadTableSchema();
  const supportSchemas = loadSupportSchemas();
  const app = createApp(config, schema, supportSchemas);
  logBitrixStatus(config.bitrix);
  const server = config.tls.enabled
    ? https.createServer({
      pfx: fs.readFileSync(config.tls.pfxPath),
      passphrase: config.tls.pfxPassword,
      minVersion: 'TLSv1.2',
    }, app)
    : http.createServer(app);
  server.listen(config.port, () => {
    const protocol = config.tls.enabled ? 'HTTPS' : 'HTTP';
    console.log(`ServiceMET API escuchando con ${protocol} en el puerto ${config.port}`);
  });

  async function shutdown(signal) {
    console.log(`${signal}: cerrando ServiceMET API`);
    server.close(async () => {
      await closePool();
      process.exit(0);
    });
  }
  process.on('SIGINT', () => shutdown('SIGINT'));
  process.on('SIGTERM', () => shutdown('SIGTERM'));
}

main().catch((error) => {
  console.error('No se pudo iniciar ServiceMET API:', error);
  process.exit(1);
});
