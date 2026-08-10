'use strict';

const fs = require('node:fs');
const http = require('node:http');
const https = require('node:https');
const { getConfig } = require('./config');
const { loadTableSchema } = require('./schema');
const { createApp } = require('./app');
const { closePool } = require('./database');

async function main() {
  const config = getConfig();
  const schema = loadTableSchema();
  const app = createApp(config, schema);
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
