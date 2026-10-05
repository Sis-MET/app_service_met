---
name: iso17025-cumplimiento
description: Cumplimiento de la NB/ISO/IEC 17025 en ServiceMET, la app del laboratorio de calibración acreditado ante la DTA-IBMETRO, centrado en 7.5 (registros técnicos), 7.11 (control de datos y gestión de la información) y 8.4 (control de registros). Úsala al auditar la app frente a la norma o preparar una evaluación de la DTA; al revisar o implementar cualquier cambio que cree, edite, elimine, suba, exporte, respalde o restaure registros de calibración o soporte; al tocar login, permisos, trazabilidad, historial de cambios, versiones y su validación, manual de uso o reporte de incidencias y fallas del sistema; y siempre que alguien pregunte si algo "cumple con la 17025", "qué pediría el evaluador" o "qué falta para la acreditación", aunque no nombre la cláusula.
---

# Cumplimiento NB/ISO/IEC 17025 en ServiceMET

## Por qué importa

ServiceMET es donde los técnicos del laboratorio registran calibraciones de
balanzas y servicios de soporte. Para la norma, la app es parte del sistema de
gestión de la información del laboratorio (lo que la norma llama "LIMS", sea
comercial o propio), y lo que el técnico carga en ella son **observaciones
originales** y **registros técnicos**.

En una evaluación de la DTA (Dirección Técnica de Acreditación del IBMETRO) el
evaluador puede pedir, con la app en la mano, que se demuestre quién registró
cada dato y cuándo, qué se cambió después y por qué, cómo se protegen y
respaldan los datos, cómo se validó la versión en uso y qué pasa cuando el
sistema falla. Si la app no puede mostrarlo, el hallazgo es contra el
laboratorio y puede comprometer la acreditación.

La norma no exige una tecnología concreta: exige resultados demostrables. Cada
requisito puede cubrirse con software, con un procedimiento documentado del
laboratorio o con ambos. El objetivo es que cada requisito tenga una respuesta
clara **con evidencia**, y que ningún cambio de código abra un hueco nuevo.

La NB/ISO/IEC 17025 es la adopción boliviana, idéntica, de la ISO/IEC
17025:2017. El texto de la norma tiene derechos de autor: parafrasea y cita el
número de cláusula; no copies párrafos literales.

## Las tres cláusulas, en corto

| Cláusula | Qué exige, parafraseado | Qué significa para la app |
|---|---|---|
| **7.5.1** | Registros técnicos con resultados e información suficiente para identificar los factores que afectan la medición y su incertidumbre, y para repetir la actividad en condiciones lo más parecidas posible. Fecha e identidad del responsable de cada actividad y de quien revisa datos y resultados. Observaciones originales registradas en el momento e identificables con la tarea. | Cada registro guarda equipo, patrones, condiciones ambientales, lecturas, técnico autenticado, fecha y hora de captura, y se vincula de forma única al servicio (SECA, `cod_metrica`, `session_id`, `codigo_registro`). |
| **7.5.2** | Toda modificación de un registro técnico es rastreable hasta la versión anterior u observación original; se conservan dato original y modificado, con fecha, qué se cambió y quién lo cambió. | Nada se sobrescribe ni se borra sin dejar rastro. La edición guarda valor anterior, valor nuevo, usuario, fecha y motivo. |
| **7.11.1–7.11.6** | Acceso a los datos necesarios; sistema validado antes de usarse y ante cada cambio (cambios autorizados, documentados y validados); protegido contra acceso no autorizado, manipulación y pérdida; operado en el entorno especificado; que preserve la integridad; que registre las fallas del sistema y sus acciones inmediatas y correctivas; control de proveedores externos; manuales e instrucciones disponibles para el personal; cálculos y transferencias de datos verificados sistemáticamente. | Validación por versión, control de cambios, autenticación, TLS, respaldos, **reporte de incidencias**, **manual de uso**, pruebas de cálculos y verificación de la subida al servidor. |
| **8.4** | Registros legibles que demuestren el cumplimiento; controles de identificación, almacenamiento, protección, respaldo, archivo, recuperación, tiempo de retención y disposición; acceso coherente con la confidencialidad; registros fácilmente disponibles. | Respaldo y restauración probados, retención definida (incluidas las fotos), disposición controlada en vez de borrado libre, acceso restringido a datos de clientes. |

Para la interpretación detallada, cláusulas relacionadas (4.2, 6.2.6, 7.10, 8.3,
8.7) y lo que suele pedir un evaluador, lee `references/requisitos.md`.

## Lo que ya vive en la app

En la pestaña Otros > "Calidad y normativa" (`lib/screens/calidad/`) hay tres
pantallas exportables en PDF (`services/calidad_pdf.dart`):

| Pantalla | Fuente de datos (se edita aquí) |
|---|---|
| Tablero de cumplimiento (38 requisitos, IDs iguales a `references/checklist.md`) | `lib/screens/calidad/data/requisitos_17025.dart` |
| Manual de uso interactivo (documento controlado) | `lib/screens/calidad/data/manual_servicemet.dart` |
| Historial de versiones (control de cambios) | `lib/screens/calidad/data/historial_versiones.dart` |

Esos archivos **son** la matriz, el manual y el CHANGELOG oficiales; no
mantengas copias paralelas en Markdown. Las pruebas de
`test/screens/calidad/calidad_datos_test.dart` fallan si `pubspec.yaml`
cambia de versión y no se actualizan la matriz (versión evaluada), el
historial (primera entrada) o el manual ("Aplica a", misma versión menor).
Eso es intencional: obliga a revisar el cumplimiento en cada liberación. Al
cerrar una brecha, cambia el estado y las evidencias del requisito en el mismo
cambio de código; al tocar un flujo descrito, actualiza su sección del manual;
cada cambio relevante va a `cambiosSinLiberar` hasta que se suba la versión.

## Cómo trabajar

Primero identifica qué te piden; cada modo tiene su camino.

### 1. Auditoría o diagnóstico ("¿cumple la app?", "prepárame para la DTA")

1. Anota la versión (`version:` en `pubspec.yaml`) y el commit (`git log -1 --oneline`).
   Toda conclusión vale para esa versión y no para otra.
2. Ejecuta el inventario de puntos sensibles para no omitir ningún lugar que
   escriba, sobrescriba o borre datos:
   ```bash
   node .claude/skills/iso17025-cumplimiento/scripts/inventario.mjs
   ```
   Es un listado para revisar, no un veredicto: cada hallazgo se confirma
   leyendo el código.
3. Lee `references/mapa-servicemet.md`: dónde vive cada requisito en el código
   y la línea base de brechas conocidas. La línea base tiene fecha; **verifica
   cada punto en el código actual antes de citarlo**, porque puede haberse
   corregido o movido.
4. Recorre `references/checklist.md` ítem por ítem. Para cada uno decide:
   `Cumple`, `Parcial`, `No cumple`, `No aplica` o `Sin evidencia`, con
   evidencia `ruta:línea` o, si depende del laboratorio, el procedimiento que
   hace falta.
5. Clasifica cada brecha por cómo se cierra (**Software**, **Procedimiento** o
   **Ambos**) y por riesgo:
   - **Alto**: puede invalidar un registro técnico o perder datos (edición sin
     rastro, borrado físico, sin respaldo, falla no registrada que afectó
     resultados).
   - **Medio**: debilita la demostración (falta la versión de la app en el
     registro, validación sin registro formal).
   - **Bajo**: mejora de forma o de buena práctica.
6. Entrega el informe con el formato de abajo y vuelca los cambios de estado
   en `lib/screens/calidad/data/requisitos_17025.dart` (versión y fecha de
   evaluación incluidas), que es la matriz que ve y exporta el laboratorio.

### 2. Revisión de un cambio (diff, PR o función nueva)

Antes de aprobar o escribir código que toque datos, responde estas preguntas
sobre las líneas que cambian (el inventario completo queda para las
auditorías). Cualquier respuesta que deje un hueco, o un "no sé", es un
hallazgo:

- ¿El cambio escribe, modifica o elimina un registro técnico? Si modifica, ¿se
  conservan el valor anterior, el nuevo, el usuario, la fecha y el motivo?
  Si elimina, ¿es anulación con motivo en vez de borrado físico? (7.5.2, 8.4)
- ¿Algún `ConflictAlgorithm.replace`, `INSERT OR REPLACE` o `update` pisa un
  dato ya capturado o ya subido sin dejar rastro? (7.5.2)
- ¿El técnico responsable sale de la sesión autenticada y no de texto libre? (7.5.1)
- ¿La fecha y hora se registran al capturar, no al exportar o subir? (7.5.1)
- ¿Cambia un cálculo, una regla de redondeo, una conversión de unidades o el
  esquema que se envía al servidor? Entonces hace falta una prueba que lo cubra
  y una entrada en el registro de validación de la versión. (7.11.2, 7.11.6)
- ¿Añade columnas locales (historial, anulación, versión de la app)?
  `CalibrationDataNormalizer` rechaza toda columna que no esté en
  `lib/database/calibration_server_schema.dart`; las que solo existen en el
  teléfono van en `_uploadExcludedFields`
  (`lib/database/calibration_data_normalizer.dart`), como `nombre_csv` o
  `servicio_status`. Si deben llegar al servidor, hacen falta un script en
  `backend/sql/`, actualizar `backend/DataMET_prueba_esquema.md` (lo leen el
  backend y el generador) y regenerar el esquema de la app con
  `node tool/generate_calibration_schema.js`.
- ¿Cambia un flujo o una pantalla que el manual describe? Actualiza la sección
  en `manual_servicemet.dart` en el mismo cambio, con los textos exactos de la
  pantalla, y agrega una línea a `cambiosSinLiberar`. (7.11.5, 7.11.2)
- ¿Cierra o abre una brecha? Actualiza el requisito en `requisitos_17025.dart`.
- ¿Un error nuevo solo termina en `debugPrint`? Si puede afectar datos, debe
  quedar como incidencia registrada (7.11.3 e). Si todavía no existe el
  servicio de incidencias, señálalo como pendiente en vez de bloquear el cambio.
- ¿Expone datos de clientes (exportar, compartir, registros en consola)? (4.2, 8.4)
- ¿Introduce un servicio externo (nube, SDK, API de terceros)? (7.11.4)

### 3. Implementar una capacidad de cumplimiento

Lee la referencia correspondiente antes de diseñar; cada una propone un diseño
que encaja con la arquitectura actual (SQLite local offline, API Node con solo
`INSERT`, SQL Server DataMET):

| Necesidad | Referencia |
|---|---|
| Historial de cambios, anulación en vez de borrado, versión de la app en cada registro, bloqueo de registros ya subidos | `references/trazabilidad-registros.md` |
| Reporte de incidencias y registro de fallas del sistema | `references/incidencias.md` |
| Validación de versiones, control de cambios, CHANGELOG | `references/validacion-y-cambios.md` |
| Manual de uso (documento controlado y ayuda dentro de la app) | `references/manual-de-uso.md` |

Al implementar, respeta cómo está hecho el proyecto: comentarios y textos en
español, migraciones que añaden columnas con `PRAGMA table_info` + `ALTER TABLE`
(como `_ensureFotoColumns` en `lib/database/app_database.dart`), scripts SQL
numerados en `backend/sql/` que validan la estructura y operan dentro de una
transacción, y pruebas en `test/` y `backend/test/`.

### 4. Redactar documentación

Manual de uso, registro de validación de una versión, procedimiento o formulario
de incidencias: usa las plantillas de las referencias. Los documentos del
laboratorio son **documentos controlados** (8.3): llevan código, revisión, fecha,
elaboró, revisó, aprobó e historial de cambios. No inventes códigos de
procedimientos del laboratorio ni de documentos de la DTA; deja
`[PENDIENTE: código asignado por Calidad]` y pregúntalo al usuario.

El manual, la matriz y el historial se editan en los archivos de datos de
`lib/screens/calidad/data/` y se exportan en PDF desde la app. Los registros
de validación por versión van en `docs/iso17025/validaciones/`, salvo que el
usuario indique otro lugar. La copia firmada y vigente la gestiona Calidad en su
sistema documental; el repositorio conserva la fuente.

## Formato del informe de auditoría

```markdown
# Cumplimiento NB/ISO/IEC 17025 — ServiceMET <versión> (<commit>, <fecha>)

## Resumen
<3–5 líneas: estado general, brechas de riesgo alto, qué cerrar antes de la evaluación>

## Matriz
| ID | Cláusula | Requisito | Estado | Evidencia | Brecha | Cierre (Software/Procedimiento/Ambos) | Riesgo |
|----|----------|-----------|--------|-----------|--------|---------------------------------------|--------|

## Brechas priorizadas
### <ID> — <título>
- Qué falta y por qué importa (qué preguntaría el evaluador)
- Propuesta concreta (archivos a tocar o procedimiento a crear)
- Cómo se demostrará el cierre (prueba, registro, captura)

## Lo que depende del laboratorio
<requisitos que no resuelve el código: plazos de retención, quién aprueba versiones, respaldo del servidor, etc.>
```

## Criterio

- **Evidencia o nada.** No marques `Cumple` sin `ruta:línea`, una prueba o un
  documento que lo demuestre. Si no pudiste verificarlo, es `Sin evidencia`.
- **Proporcionalidad.** La 17025 no exige firmas electrónicas avanzadas ni
  validación estilo farmacéutico. Requisitos de otras normas (21 CFR Part 11,
  GAMP 5, ALCOA+) pueden citarse como buena práctica, nunca como exigencia de
  la 17025.
- **La app no es todo el sistema.** Parte del cumplimiento vive en DataMET, en
  el servidor y en los procedimientos del laboratorio. Señálalo en vez de
  forzar una solución en la app.
- **No rompas lo que ya cumple.** El usuario de la API solo tiene `SELECT` e
  `INSERT` (`backend/sql/006_servicemet_api_permissions.sql`), el servidor
  impone fecha, usuario y estado, y la conexión fija la huella TLS. No propongas
  cambios que debiliten eso, como dar `UPDATE` a la API para "corregir"
  registros subidos.
- **Pregunta lo que solo sabe el laboratorio**: plazo de retención, códigos de
  procedimientos, quién autoriza una versión, dónde se respalda el servidor.
