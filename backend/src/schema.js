'use strict';

const fs = require('node:fs');
const path = require('node:path');

const CALIBRATION_TABLE = 'DATA_SERVICIOS_DATOS_CALIBRACION';
const SERVICE_SUMMARY_TABLE = 'DATA_SERVICIOS_DATOS';
const SUPPORT_MODULES = Object.freeze({
  ajuste_verificaciones: { table: 'DATA_SERVICIOS_DATOS_IBM', columns: 268, serviceCode: 'IBM.BL' },
  diagnostico: { table: 'DATA_SERVICIOS_DATOS_DIG', columns: 47, serviceCode: 'DIG.BL' },
  instalacion: { table: 'DATA_SERVICIOS_DATOS_INT', columns: 168, serviceCode: 'INS.BL' },
  mnt_correctivo: { table: 'DATA_SERVICIOS_DATOS_MCR', columns: 135, serviceCode: 'MCR.BL' },
  mnt_prv_avanzado: { table: 'DATA_SERVICIOS_DATOS_MPA_STAC', columns: 381, serviceCode: 'MPA.SP' },
  mnt_prv_regular: { table: 'DATA_SERVICIOS_DATOS_MPR_STIL', columns: 315, serviceCode: 'MPR.BL' },
  relevamiento_de_datos: { table: 'DATA_SERVICIOS_DATOS_RVD', columns: 188, serviceCode: 'REL.BL' },
  verificaciones_internas: { table: 'DATA_SERVICIOS_DATOS_VFI', columns: 170, serviceCode: 'VIN.SP' },
});

const EXPECTED_COLUMNS = Object.freeze({
  [CALIBRATION_TABLE]: 426,
  ...Object.fromEntries(
    Object.values(SUPPORT_MODULES).map(({ table, columns }) => [table, columns]),
  ),
});

function parsePrecision(raw) {
  if (!raw || raw === '-') return { precision: null, scale: null, maxLength: null };
  if (raw.includes(',')) {
    const [precision, scale] = raw.split(',').map((value) => Number.parseInt(value, 10));
    return { precision, scale, maxLength: null };
  }
  return { precision: null, scale: null, maxLength: Number.parseInt(raw, 10) };
}

function loadTableSchema(tableName = CALIBRATION_TABLE) {
  const schemaPath = path.join(__dirname, '..', 'DataMET_prueba_esquema.md');
  const markdown = fs.readFileSync(schemaPath, 'utf8');
  const marker = `## ${tableName}`;
  const start = markdown.indexOf(marker);
  if (start < 0) throw new Error(`No se encontró ${tableName} en el archivo de esquema`);

  const nextSection = markdown.indexOf('\n---', start);
  const section = markdown.slice(start, nextSection < 0 ? markdown.length : nextSection);
  const columns = new Map();
  const rowPattern = /^\|\s*\d+\s*\|\s*`([^`]+)`\s*\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|/gm;
  let match;
  while ((match = rowPattern.exec(section)) !== null) {
    const name = match[1];
    const type = match[2].trim().toLowerCase();
    const size = parsePrecision(match[3].trim());
    columns.set(name, {
      name,
      type,
      nullable: !match[4].trim().toLowerCase().startsWith('no'),
      ...size,
    });
  }

  const expected = EXPECTED_COLUMNS[tableName];
  if (expected === undefined) {
    throw new Error(`No hay un conteo de columnas configurado para ${tableName}`);
  }
  if (columns.size !== expected) {
    throw new Error(`Esquema de ${tableName} incompleto: se esperaban ${expected} columnas y se leyeron ${columns.size}`);
  }
  return columns;
}

function loadSupportSchemas() {
  return new Map(
    Object.entries(SUPPORT_MODULES).map(([module, definition]) => [
      module,
      loadTableSchema(definition.table),
    ]),
  );
}

module.exports = {
  CALIBRATION_TABLE,
  SERVICE_SUMMARY_TABLE,
  SUPPORT_MODULES,
  loadTableSchema,
  loadSupportSchemas,
};
