'use strict';

const sql = require('mssql');

let poolPromise;

function getPool(config) {
  if (!poolPromise) {
    poolPromise = new sql.ConnectionPool(config.database)
      .connect()
      .catch((error) => {
        poolPromise = undefined;
        throw error;
      });
  }
  return poolPromise;
}

async function closePool() {
  if (!poolPromise) return;
  const pool = await poolPromise;
  poolPromise = undefined;
  await pool.close();
}

module.exports = { sql, getPool, closePool };
