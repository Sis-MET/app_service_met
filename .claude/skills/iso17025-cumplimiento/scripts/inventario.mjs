#!/usr/bin/env node
// Inventario de puntos sensibles para NB/ISO/IEC 17025 (7.5, 7.11, 8.4).
//
// Recorre lib/ y backend/ y lista dónde se escriben, sobrescriben o borran
// datos, dónde se silencian errores y qué toca seguridad o servicios externos.
// Es un listado para revisar a mano, no un veredicto de cumplimiento.
//
// Uso (desde la raíz del repositorio):
//   node .claude/skills/iso17025-cumplimiento/scripts/inventario.mjs [--root <dir>] [--json] [--max <n>]

import { execSync } from 'node:child_process';
import { readdirSync, readFileSync, statSync } from 'node:fs';
import { join, relative, sep } from 'node:path';

const args = process.argv.slice(2);
const argValue = (name, fallback) => {
  const i = args.indexOf(name);
  return i >= 0 && args[i + 1] ? args[i + 1] : fallback;
};
const root = argValue('--root', process.cwd());
const asJson = args.includes('--json');
const maxPerCategory = Number.parseInt(argValue('--max', '150'), 10);

const SCAN_DIRS = ['lib', 'backend/src', 'backend/sql', 'tool'];
const EXTENSIONS = ['.dart', '.js', '.mjs', '.sql'];
const SKIP_DIRS = new Set(['node_modules', 'build', '.dart_tool', '.git']);
const SKIP_FILES = [/calibration_server_schema\.dart$/];

const CATEGORIES = [
  {
    id: 'actualizacion',
    titulo: 'Actualizaciones de datos',
    clausula: '7.5.2',
    pregunta: '¿Toca un registro técnico finalizado? ¿Guarda el valor anterior, quién, cuándo y el motivo?',
    ext: ['.dart'],
    test: (l) =>
      /\.(update|rawUpdate)\s*\(/.test(l) &&
      !/\.update\(\s*[\w'"]+\s*,\s*\(/.test(l) && // Map.update(key, (v) => …)
      !/\bsetState\b/.test(l),
  },
  {
    id: 'sobrescritura',
    titulo: 'Sobrescritura silenciosa',
    clausula: '7.5.2',
    pregunta: '¿Puede reemplazar un registro ya capturado o subido sin dejar rastro?',
    test: (l) => /ConflictAlgorithm\.replace|INSERT\s+OR\s+REPLACE|\bREPLACE\s+INTO\b/i.test(l),
  },
  {
    id: 'borrado',
    titulo: 'Borrado de datos o archivos',
    clausula: '7.5.2 / 8.4',
    pregunta: '¿Es un registro técnico, una foto o un respaldo? ¿Debería anularse o pasar por disposición controlada?',
    test: (l, ext) =>
      ext === '.dart'
        ? /\.(delete|rawDelete|deleteSync)\s*\(|deleteDatabase\s*\(|DELETE\s+FROM|DROP\s+TABLE/i.test(l) &&
          !/\.delete\(\s*key\s*:/.test(l) // claves de almacenamiento seguro, no registros
        : // En .sql incluye "DELETE alias" al inicio de línea (en JS sería el
          // operador delete); excluye tablas temporales (#…).
          (ext === '.sql' && /^\s*DELETE\b/i.test(l)) ||
          /\bDELETE\s+(FROM\b|\[|dbo\.|TOP\b)|\bTRUNCATE\s+TABLE\b|\bDROP\s+(TABLE|COLUMN)\b(?!\s+IF\s+EXISTS\s+#)/i.test(l),
  },
  {
    id: 'sql-escritura-servidor',
    titulo: 'Escritura en el servidor (SQL)',
    clausula: '7.5.2 / 7.11.3 b',
    pregunta: 'La API debería limitarse a INSERT. ¿Algún UPDATE, ALTER o GRANT amplía lo que puede hacer?',
    ext: ['.js', '.mjs', '.sql'],
    test: (l) => /\bUPDATE\s+(\[|dbo\.|\w+\s+SET\b)|\bALTER\s+TABLE\b|\bGRANT\b/i.test(l),
  },
  {
    id: 'catch-vacio',
    titulo: 'Errores ignorados (catch vacío)',
    clausula: '7.11.3 e',
    pregunta: 'Si la falla puede afectar datos, ¿debería registrarse como incidencia?',
    ext: ['.dart', '.js', '.mjs'],
    test: (l) => /catch\s*(\([^)]*\))?\s*\{\s*\}/.test(l),
  },
  {
    id: 'seguridad',
    titulo: 'Seguridad y credenciales',
    clausula: '7.11.3 a / b',
    pregunta: '¿Se validan certificados? ¿Hay contraseñas en texto plano o datos sensibles en logs?',
    test: (l) =>
      /badCertificateCallback|rejectUnauthorized\s*:\s*false|\[pass\]\s*=|['"]http:\/\//.test(l) ||
      (/(debugPrint|print|console\.(log|error|warn))\s*\(/.test(l) &&
        /(password|contraseña|\btoken\b|\bpass\b|authorization)/i.test(l)),
  },
  {
    id: 'externos',
    titulo: 'Servicios externos',
    clausula: '7.11.4',
    pregunta: '¿Envía datos fuera del dispositivo o del servidor del laboratorio? ¿Está declarado y controlado?',
    ext: ['.dart'],
    test: (l) =>
      /import\s+'package:(firebase_|cloud_firestore|google_mlkit|googleapis|sentry)/.test(l) ||
      /Firebase\.initializeApp/.test(l),
  },
  {
    id: 'pendientes',
    titulo: 'Funciones pendientes',
    clausula: '7.11.3 e / 7.11.5',
    pregunta: '¿Es soporte, manual o incidencias sin implementar?',
    comentarios: true,
    // TODO/FIXME en mayúsculas y aislados: evita "MÉTODO" y la palabra "todo".
    test: (l) =>
      /_showComingSoon\s*\(|pr[oó]ximamente/i.test(l) ||
      /(^|[\s/*])(TODO|FIXME)(?![\wÁÉÍÓÚáéíóúÑñ])/.test(l),
  },
];

function walk(dir, out) {
  let entries;
  try {
    entries = readdirSync(dir);
  } catch {
    return out;
  }
  for (const name of entries) {
    if (SKIP_DIRS.has(name)) continue;
    const full = join(dir, name);
    const st = statSync(full);
    if (st.isDirectory()) walk(full, out);
    else if (EXTENSIONS.some((e) => name.endsWith(e)) && !SKIP_FILES.some((r) => r.test(full))) {
      out.push(full);
    }
  }
  return out;
}

// Cuenta los catch cuyo cuerpo solo imprime (debugPrint/print/console) o está
// vacío: la falla no queda registrada en ningún lado persistente.
function countSilentCatches(text) {
  const re = /catch\s*(\([^)]*\))?\s*\{/g;
  let total = 0;
  let silent = 0;
  let m;
  while ((m = re.exec(text))) {
    total++;
    let depth = 1;
    let i = re.lastIndex;
    while (i < text.length && depth > 0) {
      if (text[i] === '{') depth++;
      else if (text[i] === '}') depth--;
      i++;
    }
    const body = text
      .slice(re.lastIndex, i - 1)
      .replace(/\/\/.*$/gm, '')
      .replace(/(debugPrint|print|console\.(log|error|warn))\s*\((?:[^()]|\([^()]*\))*\)\s*;/g, '')
      .replace(/\breturn\b[^;]*;/g, '')
      .trim();
    if (body === '') silent++;
  }
  return { total, silent };
}

function extOf(file) {
  const i = file.lastIndexOf('.');
  return i >= 0 ? file.slice(i) : '';
}

const files = SCAN_DIRS.flatMap((d) => walk(join(root, d), []));
const results = Object.fromEntries(CATEGORIES.map((c) => [c.id, []]));
const catchStats = [];

for (const file of files) {
  const rel = relative(root, file).split(sep).join('/');
  const ext = extOf(file);
  const text = readFileSync(file, 'utf8');
  const lines = text.split(/\r?\n/);
  lines.forEach((line, idx) => {
    const trimmed = line.trim();
    const isComment = /^(\/\/|--|\*|\/\*)/.test(trimmed);
    for (const cat of CATEGORIES) {
      if (cat.ext && !cat.ext.includes(ext)) continue;
      if (isComment && !cat.comentarios) continue;
      if (cat.test(line, ext)) {
        results[cat.id].push({ archivo: rel, linea: idx + 1, codigo: trimmed.slice(0, 160) });
      }
    }
  });
  if (ext === '.dart' || ext === '.js') {
    const { total, silent } = countSilentCatches(text);
    if (silent > 0) catchStats.push({ archivo: rel, catch_total: total, solo_imprimen_o_vacios: silent });
  }
}
catchStats.sort((a, b) => b.solo_imprimen_o_vacios - a.solo_imprimen_o_vacios);

let commit = '';
let version = '';
try {
  commit = execSync('git log -1 --format="%h %s"', { cwd: root }).toString().trim();
} catch {}
try {
  version = (readFileSync(join(root, 'pubspec.yaml'), 'utf8').match(/^version:\s*(.+)$/m) || [])[1] || '';
} catch {}

if (asJson) {
  console.log(JSON.stringify({ version, commit, categorias: results, catch_silenciosos: catchStats }, null, 2));
  process.exit(0);
}

const out = [];
out.push('# Inventario NB/ISO/IEC 17025 — puntos a revisar');
out.push('');
out.push(`- Versión: \`${version || '¿?'}\``);
out.push(`- Commit: \`${commit || '¿?'}\``);
out.push(`- Archivos analizados: ${files.length} (${SCAN_DIRS.join(', ')})`);
out.push('');
out.push('Es un listado para revisar, no un veredicto: confirma cada caso leyendo el código.');
out.push('');
out.push('| Categoría | Cláusula | Coincidencias |');
out.push('|---|---|---|');
for (const cat of CATEGORIES) out.push(`| ${cat.titulo} | ${cat.clausula} | ${results[cat.id].length} |`);
out.push(
  `| Catch que solo imprimen o están vacíos | 7.11.3 e | ${catchStats.reduce((s, x) => s + x.solo_imprimen_o_vacios, 0)} en ${catchStats.length} archivos |`,
);
out.push('');

for (const cat of CATEGORIES) {
  const items = results[cat.id];
  out.push(`## ${cat.titulo} (${cat.clausula}) — ${items.length}`);
  out.push('');
  out.push(`> ${cat.pregunta}`);
  out.push('');
  if (items.length === 0) out.push('_Sin coincidencias._');
  for (const it of items.slice(0, maxPerCategory)) out.push(`- \`${it.archivo}:${it.linea}\` — \`${it.codigo.replace(/`/g, "'")}\``);
  if (items.length > maxPerCategory) out.push(`- … ${items.length - maxPerCategory} más (usa --max o --json)`);
  out.push('');
}

out.push('## Catch que solo imprimen o están vacíos (7.11.3 e)');
out.push('');
out.push('> La falla no queda registrada de forma persistente. Prioriza los de guardado, subida, migración y respaldo.');
out.push('');
out.push('| Archivo | Silenciosos | Total catch |');
out.push('|---|---|---|');
for (const s of catchStats.slice(0, maxPerCategory)) out.push(`| \`${s.archivo}\` | ${s.solo_imprimen_o_vacios} | ${s.catch_total} |`);
out.push('');

console.log(out.join('\n'));
