'use strict';

const crypto = require('node:crypto');

function base64Url(value) {
  return Buffer.from(value).toString('base64url');
}

function signJwt(payload, secret, ttlSeconds) {
  const now = Math.floor(Date.now() / 1000);
  const header = base64Url(JSON.stringify({ alg: 'HS256', typ: 'JWT' }));
  const body = base64Url(JSON.stringify({ ...payload, iat: now, exp: now + ttlSeconds }));
  const unsigned = `${header}.${body}`;
  const signature = crypto.createHmac('sha256', secret).update(unsigned).digest('base64url');
  return `${unsigned}.${signature}`;
}

function verifyJwt(token, secret) {
  const parts = token.split('.');
  if (parts.length !== 3) throw new Error('Token inválido');
  const unsigned = `${parts[0]}.${parts[1]}`;
  const expected = crypto.createHmac('sha256', secret).update(unsigned).digest();
  const received = Buffer.from(parts[2], 'base64url');
  if (expected.length !== received.length || !crypto.timingSafeEqual(expected, received)) {
    throw new Error('Firma inválida');
  }
  const payload = JSON.parse(Buffer.from(parts[1], 'base64url').toString('utf8'));
  if (!payload.exp || payload.exp <= Math.floor(Date.now() / 1000)) {
    throw new Error('Token vencido');
  }
  return payload;
}

function authMiddleware(config) {
  return (req, res, next) => {
    const value = req.headers.authorization || '';
    if (!value.startsWith('Bearer ')) {
      return res.status(401).json({ error: 'AUTH_REQUIRED', message: 'Se requiere autenticación.' });
    }
    try {
      req.auth = verifyJwt(value.slice(7), config.jwtSecret);
      next();
    } catch (_) {
      return res.status(401).json({ error: 'INVALID_TOKEN', message: 'La sesión venció o no es válida.' });
    }
  };
}

function createLoginLimiter({ maxAttempts = 8, windowMs = 15 * 60 * 1000 } = {}) {
  const attempts = new Map();
  return (req, res, next) => {
    const key = req.ip || req.socket.remoteAddress || 'unknown';
    const now = Date.now();
    const current = attempts.get(key);
    if (!current || current.resetAt <= now) {
      attempts.set(key, { count: 1, resetAt: now + windowMs });
      return next();
    }
    current.count += 1;
    if (current.count > maxAttempts) {
      return res.status(429).json({ error: 'TOO_MANY_ATTEMPTS', message: 'Demasiados intentos. Intente nuevamente más tarde.' });
    }
    next();
  };
}

module.exports = { signJwt, verifyJwt, authMiddleware, createLoginLimiter };
