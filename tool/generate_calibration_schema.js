'use strict';

const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const sourcePath = path.join(root, 'backend', 'DataMET_prueba_esquema.md');
const outputPath = path.join(
  root,
  'lib',
  'database',
  'calibration_server_schema.dart',
);
const tableName = 'DATA_SERVICIOS_DATOS_CALIBRACION';

const markdown = fs.readFileSync(sourcePath, 'utf8');
const sectionMatch = markdown.match(
  new RegExp(`## ${tableName}([\\s\\S]*?)(?=\\r?\\n---)`),
);
if (!sectionMatch) throw new Error(`No se encontró ${tableName}`);

const columns = [];
const rowPattern = /^\|\s*\d+\s*\|\s*`([^`]+)`\s*\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|/gm;
let match;
while ((match = rowPattern.exec(sectionMatch[1])) !== null) {
  const [rawSize, rawScale] = match[3].trim().split(',');
  const type = match[2].trim().toLowerCase();
  columns.push({
    name: match[1],
    type,
    maxLength: type === 'nvarchar' ? Number.parseInt(rawSize, 10) : null,
    precision: type === 'decimal' || type === 'numeric'
      ? Number.parseInt(rawSize, 10)
      : null,
    scale: type === 'decimal' || type === 'numeric'
      ? Number.parseInt(rawScale, 10)
      : null,
    nullable: !match[4].trim().toLowerCase().startsWith('no'),
  });
}

if (columns.length !== 426) {
  throw new Error(`Se esperaban 426 columnas y se encontraron ${columns.length}`);
}

function dartType(type) {
  switch (type) {
    case 'int': return 'integer';
    case 'decimal':
    case 'numeric': return 'decimal';
    case 'nvarchar': return 'nvarchar';
    case 'date': return 'date';
    case 'time': return 'time';
    case 'bit': return 'bit';
    default: throw new Error(`Tipo SQL no soportado: ${type}`);
  }
}

const definitions = columns.map((column) => {
  const options = [
    `type: CalibrationSqlType.${dartType(column.type)}`,
    `nullable: ${column.nullable}`,
  ];
  if (column.maxLength !== null) options.push(`maxLength: ${column.maxLength}`);
  if (column.precision !== null) options.push(`precision: ${column.precision}`);
  if (column.scale !== null) options.push(`scale: ${column.scale}`);
  return `  '${column.name}': CalibrationColumnDefinition(${options.join(', ')}),`;
}).join('\n');

const output = `// GENERATED FILE - DO NOT EDIT.\n// Source: backend/DataMET_prueba_esquema.md\n\nenum CalibrationSqlType { nvarchar, integer, decimal, date, time, bit }\n\nclass CalibrationColumnDefinition {\n  final CalibrationSqlType type;\n  final bool nullable;\n  final int? maxLength;\n  final int? precision;\n  final int? scale;\n\n  const CalibrationColumnDefinition({\n    required this.type,\n    required this.nullable,\n    this.maxLength,\n    this.precision,\n    this.scale,\n  });\n}\n\nconst calibrationServerSchema = <String, CalibrationColumnDefinition>{\n${definitions}\n};\n`;

fs.writeFileSync(outputPath, output, 'utf8');
console.log(`Generadas ${columns.length} columnas en ${outputPath}`);
console.log(`Ejecute: dart format "${outputPath}"`);
