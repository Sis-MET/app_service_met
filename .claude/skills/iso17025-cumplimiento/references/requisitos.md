# Requisitos NB/ISO/IEC 17025 aplicables al software

Interpretación de las cláusulas 7.5, 7.11 y 8.4 para una app de captura de
datos de calibración. Los requisitos están **parafraseados**: el texto oficial
tiene derechos de autor y no debe copiarse literal. Ante una duda de redacción,
pide al usuario que consulte su ejemplar de la norma.

## Contenido

1. Contexto: IBMETRO, DTA y la norma
2. 7.5 Registros técnicos
3. 7.11 Control de los datos y gestión de la información
4. 8.4 Control de registros
5. Cláusulas relacionadas
6. Qué suele pedir un evaluador

---

## 1. Contexto

- **IBMETRO** es el Instituto Boliviano de Metrología. Su **DTA** (Dirección
  Técnica de Acreditación) acredita a los laboratorios de ensayo y calibración
  bajo la NB/ISO/IEC 17025.
- La **NB/ISO/IEC 17025** es la adopción nacional, idéntica, de la
  **ISO/IEC 17025:2017**. La numeración de cláusulas es la misma.
- La DTA puede publicar criterios, políticas o listas de verificación propias
  que complementan la norma. No inventes sus códigos ni su contenido: si hacen
  falta, pide al usuario el documento vigente.
- En la terminología de la norma, un **LIMS** es cualquier sistema de gestión
  de la información del laboratorio, informático o no. ServiceMET, junto con su
  API y la base DataMET, forma parte del LIMS del laboratorio.

## 2. Cláusula 7.5 — Registros técnicos

### 7.5.1 Contenido de los registros técnicos

El laboratorio debe asegurar que el registro técnico de cada actividad contenga
los resultados, el informe y la información suficiente para:

- identificar, cuando sea posible, los factores que afectan el resultado de la
  medición y su incertidumbre;
- repetir la actividad en condiciones lo más cercanas posible a las originales.

También debe incluir:

- la **fecha** y la **identidad del personal responsable** de cada actividad;
- la identidad de quien **verifica los datos y los resultados**.

Las **observaciones originales, los datos y los cálculos** se registran **en el
momento en que se generan** y deben poder vincularse con la tarea concreta.

**Para una app de calibración de balanzas significa:**

| Qué | Por qué | Ejemplos en un registro de calibración |
|---|---|---|
| Identificación única del servicio e ítem | Vincular observación ↔ tarea | SECA, `cod_metrica`, `session_id`, `codigo_registro`, cliente y planta |
| Equipo calibrado | Repetibilidad | marca, modelo, serie, capacidad, división (d, e), ubicación |
| Patrones usados | Trazabilidad e incertidumbre | código de pesa o juego, certificado, vigencia |
| Condiciones ambientales | Factores que afectan la medición | temperatura y humedad inicial y final, vibración, corrientes de aire |
| Método | Repetibilidad | procedimiento y revisión, puntos de carga, secuencia |
| Lecturas originales | Observación original | cada lectura de excentricidad, repetibilidad, linealidad y precargas, tal como se leyó |
| Técnico y fecha y hora | Responsabilidad | usuario autenticado, fecha y hora de inicio y fin |
| Revisión técnica | Verificación de datos y resultados | quién revisó y cuándo (puede vivir en DataMET) |
| Evidencias | Soporte de la observación | fotos del indicador, de la placa, del entorno |
| Versión del software | Repetir el procesamiento | versión de la app que capturó y calculó |

Puntos finos:

- **"En el momento"**: el dato se guarda al capturarlo. Una transcripción
  posterior desde papel convierte al papel en el registro original y hay que
  conservarlo.
- **Autollenado y sugerencias**: son ayudas de captura. El registro debe
  reflejar lo que el técnico realmente observó y confirmó; el técnico debe
  poder ver y corregir el valor sugerido antes de guardar.
- **Lectura automática (OCR del indicador)**: la foto es la observación
  original y el número leído es un dato derivado. Conservar la foto y exigir que
  el técnico confirme el valor fortalece mucho el registro.

### 7.5.2 Modificaciones

Las modificaciones de los registros técnicos deben poder rastrearse hasta la
versión anterior o la observación original. Se conservan **tanto los datos
originales como los modificados**, con:

- la **fecha** de la modificación;
- la **indicación de qué se modificó**;
- el **personal responsable** de la modificación.

La norma no menciona el **motivo**, pero conviene pedirlo: es lo primero que
pregunta el evaluador y permite distinguir un error de transcripción de una
corrección técnica.

**Consecuencias para el software:**

- Un `UPDATE` que pisa el valor sin guardar el anterior **incumple**.
- Un `DELETE` físico de un registro técnico **incumple** (el original
  desaparece). Lo correcto es anular con motivo, o una disposición controlada
  según 8.4.
- La sobrescritura silenciosa (`INSERT OR REPLACE`, `ConflictAlgorithm.replace`)
  sobre registros ya capturados equivale a un `UPDATE` sin rastro.
- En el servidor, corregir un registro subido debe dejar el original y el
  corregido, por ejemplo con un registro nuevo que referencie al anterior, o
  con el procedimiento de DataMET que Calidad defina.

## 3. Cláusula 7.11 — Control de los datos y gestión de la información

### 7.11.1 Acceso a datos
El laboratorio debe tener acceso a los datos y la información necesarios para
sus actividades. En la app: la precarga offline de clientes, plantas, balanzas y
patrones debe estar disponible y actualizada en campo, e indicar su antigüedad.

### 7.11.2 Validación y control de cambios
El LIMS se valida en su funcionalidad, incluidas las interfaces entre sus
partes (app ↔ API ↔ DataMET), **antes de ponerse en uso**. Todo cambio (código,
configuración, dependencias) debe ser **autorizado, documentado y validado
antes de implementarse**.

- El software comercial de uso general, dentro de su campo de aplicación
  previsto (sistema operativo, SQLite, Flutter como framework, SQL Server), se
  considera suficientemente validado. **El código propio de ServiceMET no lo
  es**: debe validarse.
- Evidencia esperada: registro de validación por versión, pruebas ejecutadas con
  resultado, quién autorizó la liberación y cuándo entró en uso. Ver
  `validacion-y-cambios.md`.

### 7.11.3 Requisitos del sistema
El LIMS debe:

| Literal | Requisito | En la app |
|---|---|---|
| a) | Estar protegido contra el acceso no autorizado | Cuentas individuales, sesión con vencimiento, límite de intentos, credenciales cifradas, contraseñas del servidor nunca en texto plano, cuentas inactivas bloqueadas |
| b) | Estar protegido contra la manipulación y la pérdida | TLS con huella fijada, API con permisos mínimos (solo `INSERT`), validación en el servidor, respaldos, conservación de fotos |
| c) | Operar en un entorno conforme con las especificaciones del proveedor o del laboratorio | Versión mínima de Android, permisos, dispositivos autorizados, servidor con Node y HTTPS según el README del backend |
| d) | Mantenerse de modo que se asegure la integridad de los datos | Normalización y validación de esquema, transacciones, deduplicación, sin pérdida de decimales ni de zona horaria |
| e) | **Registrar las fallas del sistema y las acciones inmediatas y correctivas** | **Reporte de incidencias**: registro automático de errores más reporte manual, con seguimiento hasta el cierre. Ver `incidencias.md` |

### 7.11.4 Sistemas gestionados fuera del laboratorio
Si el LIMS o una parte se gestiona fuera de las instalaciones o lo mantiene un
proveedor externo, el laboratorio asegura que ese proveedor cumpla los
requisitos aplicables de la norma. Para la app: servicios en la nube (Firebase),
hosting del servidor, tiendas de distribución y SDK que envían datos fuera del
dispositivo. El OCR de ML Kit funciona en el dispositivo; confirmarlo si se
cambia de modelo.

### 7.11.5 Manuales e instrucciones
Las instrucciones, los manuales y los datos de referencia del LIMS deben estar
**fácilmente disponibles** para el personal. En la app: un **manual de uso**
controlado y accesible en campo, sin conexión, desde la propia app. Ver
`manual-de-uso.md`.

### 7.11.6 Cálculos y transferencias
Los cálculos y las transferencias de datos se verifican de forma **apropiada y
sistemática**:

- **Cálculos**: pruebas automatizadas con valores de referencia (resultado
  conocido, contrastado con una hoja de cálculo validada o un cálculo manual
  documentado) para cada cálculo, redondeo y conversión.
- **Transferencias**: app → API → DataMET; importación y exportación de bases;
  CSV; precarga desde el servidor. Verificar recuentos, validar antes de
  insertar y hacer pruebas de ida y vuelta (lo que se ve en DataMET es lo que se
  capturó).

## 4. Cláusula 8.4 — Control de registros

### 8.4.1
Registros **legibles** que demuestren el cumplimiento de la norma.

### 8.4.2
Controles para: **identificación, almacenamiento, protección, respaldo,
archivo, recuperación, tiempo de retención y disposición**. Retención acorde con
las obligaciones contractuales. Acceso acorde con los compromisos de
**confidencialidad**. Registros **fácilmente disponibles**.

| Control | Pregunta a la app |
|---|---|
| Identificación | ¿Cada registro y archivo (BD, CSV, PDF, foto, respaldo) tiene un nombre o código trazable? |
| Almacenamiento | ¿Dónde vive cada dato: teléfono, servidor, respaldo? ¿Hasta cuándo? |
| Protección | ¿Quién puede leerlo o cambiarlo? ¿Está cifrado lo sensible? |
| Respaldo | ¿Qué se respalda, cada cuánto, dónde? ¿Se probó restaurar? |
| Archivo y recuperación | ¿Un registro de hace años se puede encontrar y leer? |
| Retención | ¿Hay plazo definido por el laboratorio? ¿La app evita borrar antes de ese plazo, fotos incluidas? |
| Disposición | ¿Eliminar queda autorizado y registrado? ¿Existen borrados "libres"? |
| Confidencialidad | ¿Exportar y compartir datos de clientes está controlado? ¿Hay datos de clientes en los logs? |

El **plazo de retención** lo fija el laboratorio en su procedimiento, según sus
contratos y lo que exija la DTA. No lo asumas: pregúntalo.

## 5. Cláusulas relacionadas

| Cláusula | Relación con la app |
|---|---|
| 4.2 Confidencialidad | Datos de clientes en el teléfono, exportaciones, compartir, logs |
| 6.2.6 Autorización del personal | Solo el personal autorizado usa la app (`acceso_app` y `estado` en `data_users`); idealmente, autorización por tipo de servicio |
| 7.10 Trabajo no conforme | Una falla que pudo afectar resultados se evalúa como trabajo no conforme |
| 8.3 Control de documentos | El manual de uso y los procedimientos son documentos controlados |
| 8.7 Acciones correctivas | Las incidencias con causa sistemática derivan en acción correctiva |
| 7.8 Informe de resultados | Si la app genera informes o certificados (PDF), su contenido lo rige 7.8 |

## 6. Qué suele pedir un evaluador

Preguntas típicas en una evaluación con software de captura:

1. "Muéstreme un registro de calibración y dígame quién lo hizo, cuándo, con
   qué patrones y en qué condiciones."
2. "Modifique un dato. ¿Dónde queda el valor original? ¿Quién lo cambió y por
   qué?"
3. "¿Puede un técnico borrar un registro? Muéstreme qué pasa."
4. "¿Qué versión del software usa? ¿Cómo se validó? ¿Quién autorizó ponerla en
   uso?"
5. "¿Qué pasó la última vez que el sistema falló? ¿Dónde está registrado y qué
   acción se tomó?"
6. "¿Dónde está el manual? ¿Lo tiene el técnico en campo?"
7. "¿Cómo sabe que lo que llega a la base es lo que se midió?"
8. "¿Dónde están los respaldos? ¿Cuándo se probó una restauración?"
9. "¿Quién tiene acceso? ¿Qué pasa con la cuenta de un técnico que se fue?"
10. "¿Cuánto tiempo conservan los registros y las fotos?"

Una buena auditoría interna contesta cada una con evidencia concreta.
