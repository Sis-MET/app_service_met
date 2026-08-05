'use strict';

const { getConfig } = require('./config');
const { loadTableSchema } = require('./schema');
const { createApp } = require('./app');
const { closePool } = require('./database');

async function main() {
  const config = getConfig();
  const schema = loadTableSchema();
  const app = createApp(config, schema);
  const server = app.listen(config.port, () => {
    console.log(`ServiceMET API escuchando en el puerto ${config.port}`);
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
