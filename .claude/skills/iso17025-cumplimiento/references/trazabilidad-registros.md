# Trazabilidad de registros: historial, anulación y versión

Diseño de referencia para cerrar 7.5.2 y la parte de disposición de 8.4 en
ServiceMET. Adáptalo al código vigente; los nombres son propuestas.

## Contenido

1. Principios
2. Historial de cambios (auditoría)
3. Anulación en vez de borrado
4. Registros ya subidos
5. Versión de la app en cada registro
6. Lado servidor
7. Pruebas que demuestran el cierre

---

## 1. Principios

- **Solo se agrega.** El historial nunca se edita ni se borra desde el código.
  Si una entrada está mal, se agrega otra que la corrige.
- **Atómico.** El cambio del dato y su entrada de historial se escriben en la
  **misma transacción**. Si una falla, fallan las dos; un cambio sin rastro es
  peor que un error visible.
- **Quién sale de la sesión**, no de un campo editable. Hoy la sesión se lee
  de `SharedPreferences` (`logged_user`, ver `home_screen.dart`); confirma la
  fuente canónica antes de usarla y centralízala en un solo lugar.
- **El motivo es obligatorio** al modificar o anular. Ofrece motivos frecuentes
  para elegir, más texto libre.
- **Sin sobrecarga en la captura inicial.** Mientras el técnico llena el
  asistente, los guardados intermedios del borrador no necesitan motivo. El
  historial con motivo aplica a registros **finalizados** (con `finalized_at`
  o estado de servicio completo) y a toda edición desde el editor de
  registros. Así no se castiga el flujo normal de captura y sí se protege el
  registro ya cerrado.

## 2. Historial de cambios

### Tabla

`LocalServiceRecordRepository` escribe en varias bases (`calibracion.db` y las
de soporte). SQLite no garantiza transacciones entre conexiones distintas, así
que la tabla de historial vive **en la misma base que el registro** y se crea
con `CREATE TABLE IF NOT EXISTS` al resolver el destino. Para consultarla
entera se unen las bases.

```sql
CREATE TABLE IF NOT EXISTS auditoria_registros (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  fecha_hora      TEXT NOT NULL,   -- ISO-8601 con desfase horario: 2026-09-28T10:15:00-04:00
  usuario         TEXT NOT NULL,   -- usuario de la sesión
  accion          TEXT NOT NULL,   -- MODIFICAR | ANULAR | RESTAURAR | IMPORTAR | DESCARTAR
  tabla           TEXT NOT NULL,
  registro_clave  TEXT NOT NULL,   -- p. ej. "seca=…|session_id=…|cod_metrica=…"
  campo           TEXT,            -- NULL en acciones sobre el registro completo
  valor_anterior  TEXT,
  valor_nuevo     TEXT,
  motivo          TEXT,            -- obligatorio en MODIFICAR y ANULAR
  app_version     TEXT NOT NULL,   -- versión+build de pubspec (PackageInfo)
  dispositivo     TEXT             -- modelo e identificador de instalación, sin datos personales
);
CREATE INDEX IF NOT EXISTS idx_auditoria_clave ON auditoria_registros (tabla, registro_clave);
```

Una fila por campo modificado: así se lee directamente "campo X pasó de A a B".

### Flujo en el editor

`RegistroEditorScreen._buildChanges()` ya compara `_values` con `_original`. En
`_guardar()`:

1. Si hay cambios, pedir el motivo en un diálogo (motivos frecuentes: "Error de
   transcripción", "Dato mal ingresado en campo", "Corrección por revisión
   técnica", "Otro", este último con texto obligatorio).
2. Llamar a un método de repositorio que reciba el motivo, por ejemplo
   `LocalServiceRecordRepository.update(tipo, row, changes, motivo: …)`, y que
   haga dentro de `target.db.transaction`:
   - releer la fila actual (el valor anterior se toma de la base, no de la
     pantalla, por si cambió mientras tanto);
   - insertar una entrada de historial por cada campo cuyo valor cambió de
     verdad;
   - aplicar el `UPDATE`.
3. Mostrar en el editor una sección "Historial de cambios" de solo lectura con
   fecha, usuario, campo, anterior → nuevo y motivo. Es lo que el evaluador pide
   ver.

Mantén `kLocalRecordSystemKeys` fuera del historial y de la edición.

### Otros puntos de escritura

Ejecuta el inventario (`scripts/inventario.mjs`) y clasifica cada `update`,
`rawUpdate` o `replace` sobre tablas de registros técnicos:

- **Guardado de borrador durante la captura**: no requiere historial (ver
  principios), siempre que el registro no esté finalizado.
- **Cualquier escritura sobre un registro finalizado**: requiere historial.
- **Tablas de estado o de control** (`servicio_status`,
  `calibration_upload_status`, catálogos de precarga): no son registros
  técnicos; no requieren historial campo a campo, aunque conviene registrar
  eventos relevantes (por ejemplo, finalizar o subir).

## 3. Anulación en vez de borrado

Columnas nuevas en cada tabla de registros técnicos (migración con
`PRAGMA table_info` + `ALTER TABLE`, como `_ensureFotoColumns`):

```sql
ALTER TABLE registros_calibracion ADD COLUMN anulado INTEGER DEFAULT 0;
ALTER TABLE registros_calibracion ADD COLUMN anulado_por TEXT DEFAULT '';
ALTER TABLE registros_calibracion ADD COLUMN anulado_en TEXT DEFAULT '';
ALTER TABLE registros_calibracion ADD COLUMN motivo_anulacion TEXT DEFAULT '';
```

- `LocalServiceRecordRepository.delete` pasa a **anular**: marca las columnas y
  escribe `ANULAR` en el historial, en la misma transacción.
- Las consultas de trabajo (pendientes, dashboard, subida) excluyen
  `anulado = 1`; el historial y el detalle pueden mostrarlos con una marca
  "Anulado".
- Un registro anulado **no se sube**. Si ya estaba subido, anularlo en el
  teléfono no toca DataMET: se trata como en la sección 6.
- Estas columnas son solo locales: agrégalas a `_uploadExcludedFields` en
  `calibration_data_normalizer.dart` o el normalizador rechazará el registro.
- El texto del diálogo cambia de "borra de forma permanente" a "El registro
  quedará anulado y visible en el historial".
- **Borradores nunca finalizados** (un servicio iniciado por error): pueden
  descartarse, pero dejando una entrada `DESCARTAR` con motivo en el historial.
- **Borrado físico real** (liberar espacio, retención vencida): solo mediante
  un proceso de disposición autorizado según el procedimiento de control de
  registros del laboratorio, y después de confirmar que existe copia en el
  servidor o en un respaldo archivado.

## 4. Registros ya subidos

Tras una subida exitosa, `calibration_upload_status` guarda `codigo_registro`,
`server_n`, `uploaded_at` y `uploaded_by`.

- En el editor y en el detalle, si el registro está subido, ábrelo **en solo
  lectura** con un aviso: "Este registro ya está en DataMET. Las correcciones
  se gestionan según el procedimiento de Calidad."
- Si se permite corregir y volver a subir, debe hacerse como **registro nuevo
  que referencia al anterior**, nunca como un `UPDATE` en el servidor. La API
  solo tiene `INSERT`, y eso es una fortaleza que conviene conservar.
- Haz la misma verificación en soporte con su servicio de estado de subida
  (`support_upload_status_service.dart`).

## 5. Versión de la app en cada registro

- Guarda `app_version` (por ejemplo, `6.3.3+15`, leída con `PackageInfo`) al
  **crear** el registro y en cada entrada del historial.
- Si debe llegar a DataMET: script en `backend/sql/` que agregue la columna,
  actualizar `backend/DataMET_prueba_esquema.md`, regenerar
  `calibration_server_schema.dart` con `node tool/generate_calibration_schema.js`
  y ajustar las pruebas. Una alternativa menos invasiva es registrarla solo en
  el resumen `DATA_SERVICIOS_DATOS`.
- Mientras no llegue al servidor, déjala en `_uploadExcludedFields`.

## 6. Lado servidor

- **Scripts de borrado** (por ejemplo, `backend/sql/007_delete_last_calibration_upload.sql`):
  antes del `DELETE`, copiar las filas completas a una tabla de archivo
  (`…_ANULADOS` o `SERVICEMET_REGISTROS_ELIMINADOS`) con quién ejecutó
  (`SUSER_SNAME()`), cuándo (`SYSDATETIMEOFFSET()`) y un motivo obligatorio
  como variable del script, todo en la misma transacción. Mejor aún: reemplazar
  el borrado por una marca de estado si DataMET lo admite.
- El script de borrado se ejecuta solo con autorización documentada (quién la
  pidió y quién la aprobó), según el procedimiento de control de registros.
- La hora de recepción en el servidor ya se registra en el resumen. Conviene
  conservar también la fecha y hora de captura del dispositivo, para detectar
  relojes mal configurados.

## 7. Pruebas que demuestran el cierre

Agrégalas en `test/home/local_service_record_repository_test.dart` (ya usa una
base en memoria con `resolverOverride`) o en un archivo nuevo:

- Editar un campo crea una entrada con el valor anterior, el nuevo, el usuario,
  el motivo y la versión.
- Editar sin cambios reales no crea entradas.
- Si el `UPDATE` falla, no queda entrada de historial (y al revés).
- "Eliminar" deja la fila con `anulado = 1` y una entrada `ANULAR`; la fila
  sigue existiendo.
- Las consultas de pendientes y de subida excluyen los anulados.
- Un registro subido no se puede editar desde el editor.
- El normalizador no envía `anulado`, `anulado_por`, `anulado_en`,
  `motivo_anulacion` ni `app_version` (mientras sean solo locales).

Estas pruebas, con su resultado, son evidencia directa para 7.5.2 en el
registro de validación de la versión.
