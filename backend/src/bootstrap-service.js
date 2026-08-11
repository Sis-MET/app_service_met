'use strict';

const BOOTSTRAP_QUERIES = Object.freeze({
  clientes: 'SELECT codigo_cliente, cliente, cliente_id, razonsocial FROM DATA_CLIENTES',
  plantas: 'SELECT cliente_id, codigo_planta, planta_id, dep, dep_id, planta, dir FROM DATA_PLANTAS',
  balanzas: 'SELECT * FROM DATA_EQUIPOS_BALANZAS',
  inf: 'SELECT * FROM DATA_EQUIPOS',
  equipamientos: 'SELECT * FROM DATA_EQUIPOS_CAL',
  servicios: 'SELECT * FROM DATA_SERVICIOS_LEC',
});

async function readBootstrap(pool) {
  const tables = {};
  for (const [name, query] of Object.entries(BOOTSTRAP_QUERIES)) {
    const result = await pool.request().query(query);
    tables[name] = result.recordset ?? [];
  }
  return {
    schemaVersion: 1,
    generatedAt: new Date().toISOString(),
    counts: Object.fromEntries(
      Object.entries(tables).map(([name, rows]) => [name, rows.length]),
    ),
    tables,
  };
}

module.exports = { BOOTSTRAP_QUERIES, readBootstrap };
