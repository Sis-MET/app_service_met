'use strict';

const fs = require('node:fs');
const path = require('node:path');

function loadEnvFile() {
  const envPath = path.join(__dirname, '..', '.env');
  if (!fs.existsSync(envPath)) return;

  for (const rawLine of fs.readFileSync(envPath, 'utf8').split(/\r?\n/)) {
    const line = rawLine.trim();
    if (!line || line.startsWith('#')) continue;
    const separator = line.indexOf('=');
    if (separator < 1) continue;
    const key = line.slice(0, separator).trim();
    let value = line.slice(separator + 1).trim();
    if ((value.startsWith('"') && value.endsWith('"')) ||
        (value.startsWith("'") && value.endsWith("'"))) {
      value = value.slice(1, -1);
    }
    if (process.env[key] === undefined) process.env[key] = value;
  }
}

function required(name) {
  const value = process.env[name]?.trim();
  if (!value) throw new Error(`Falta la variable de entorno ${name}`);
  return value;
}

function bool(name, fallback) {
  const value = process.env[name];
  if (value === undefined || value === '') return fallback;
  return value.toLowerCase() === 'true';
}

function integer(name, fallback) {
  const value = Number.parseInt(process.env[name] ?? '', 10);
  return Number.isFinite(value) ? value : fallback;
}

loadEnvFile();

function getConfig() {
  const nodeEnv = process.env.NODE_ENV || 'development';
  const jwtSecret = required('JWT_SECRET');
  if (jwtSecret.length < 32) {
    throw new Error('JWT_SECRET debe tener al menos 32 caracteres');
  }

  return {
    nodeEnv,
    port: integer('PORT', 3000),
    trustProxy: bool('TRUST_PROXY', false),
    corsOrigins: (process.env.CORS_ORIGINS || '')
      .split(',')
      .map((value) => value.trim())
      .filter(Boolean),
    jwtSecret,
    jwtTtlSeconds: integer('JWT_TTL_SECONDS', 28800),
    database: {
      server: required('DB_HOST'),
      port: integer('DB_PORT', 1433),
      database: required('DB_NAME'),
      user: required('DB_USER'),
      password: required('DB_PASSWORD'),
      pool: {
        max: integer('DB_POOL_MAX', 10),
        min: 0,
        idleTimeoutMillis: 30000,
      },
      options: {
        encrypt: bool('DB_ENCRYPT', false),
        trustServerCertificate: bool('DB_TRUST_SERVER_CERTIFICATE', true),
      },
    },
  };
}

module.exports = { getConfig };
