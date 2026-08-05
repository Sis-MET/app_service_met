'use strict';

const fs = require('node:fs');
const path = require('node:path');

const CALIBRATION_TABLE = 'DATA_SERVICIOS_DATOS_CALIBRACION';

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

  if (columns.size !== 426) {
    throw new Error(`Esquema de calibración incompleto: se esperaban 426 columnas y se leyeron ${columns.size}`);
  }
  return columns;
}

module.exports = { CALIBRATION_TABLE, loadTableSchema };
