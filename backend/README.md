# ServiceMET Backend

API interna para validar y subir servicios de calibración y soporte desde Flutter hacia
`DataMET_prueba` sin usar CSV. No recibe fotografías ni archivos ZIP.

## Configuración

1. Instalar Node.js 18 o superior en el servidor principal.
2. Copiar `.env.example` como `.env` y completar las credenciales SQL y un
   `JWT_SECRET` aleatorio de al menos 32 caracteres. En producción también se
   requieren `TLS_PFX_PATH` y `TLS_PFX_PASSWORD` para servir HTTPS.
3. Ejecutar `pnpm install --frozen-lockfile` dentro de `backend/`.
4. Ejecutar `pnpm test` y luego `pnpm start`.

La API no requiere crear índices ni restricciones en `DataMET_prueba`. Antes de
habilitar la subida de soporte, un administrador debe ejecutar una sola vez
`sql/003_expand_support_session_id.sql` para ampliar `session_id` a
`nvarchar(30)` en las ocho tablas. El script valida la estructura y aplica todos
los cambios dentro de una transacción.

También debe ejecutar una sola vez `sql/005_add_service_type_to_summary.sql`
para agregar `tipo_servicio` al resumen general `DATA_SERVICIOS_DATOS`.

Para admitir las etiquetas de plataforma como `8F` y comentarios técnicos
extensos, deben ejecutarse una sola vez, y en este orden:

1. `sql/008_normalize_support_points_ind.sql`, que audita las ocho tablas y
   convierte cada columna real de puntos/posición del indicador
   (`puntos_ind`, `puntos_ind_inicial` o `puntos_ind_final`, según el módulo)
   a `nvarchar(50)`.
2. `sql/009_expand_support_comentario_general.sql`, que amplía
   `comentario_general` a `nvarchar(1000)` en las ocho tablas.
3. `sql/010_expand_installation_comments.sql`, que amplía a
   `nvarchar(1000)` los nueve comentarios de condiciones de instalación y
   reafirma el mismo límite para `comentario_general` en
   `DATA_SERVICIOS_DATOS_INT`.

Los scripts validan la estructura y aplican todos los cambios dentro de una
transacción antes de mostrar el esquema resultante.

Para registrar cargas de excentricidad con decimales (por ejemplo 0.5 kg en una
balanza de 1.5 kg), debe ejecutarse una sola vez
`sql/011_expand_excentricidad_carga.sql` **antes** de desplegar el backend con
este esquema y la versión de ServiceMET que los admite. Cambia `carga` de `int`
a `decimal(15,6)`, la misma precisión que `cap_max1` a `cap_max3`; conserva los
valores existentes y puede volver a ejecutarse sin efecto. Al terminar lista
los procedimientos, vistas y funciones que mencionan `carga`, para revisar que
ninguno la convierta a entero.

Para guardar la ubicación GPS de cada servicio (desde ServiceMET 6.3.5),
debe ejecutarse una sola vez `sql/013_add_service_location.sql` **antes** de
desplegar el backend. Agrega a `DATA_SERVICIOS_DATOS` las columnas
`latitud`, `longitud` (`decimal(9,6)`), `precision_gps` (`decimal(7,1)`, en
metros) y `fecha_gps` (`datetimeoffset(0)`), todas con nulos permitidos y con
restricciones de rango. El resumen tiene una fila por servicio subido, de
calibración o de cualquier módulo de soporte, y se une con la tabla de detalle
por `codigo_registro`. La app envía la ubicación aparte del registro técnico
(`ubicaciones` en calibración, `ubicacion` en cada sobre de soporte), así que
una app anterior sigue subiendo sin coordenadas. Si el backend se despliega
antes que el script, sube igual sin coordenadas y lo avisa en su consola.

Para registrar cargas de repetibilidad con decimales en Mantenimiento
preventivo avanzado, Mantenimiento preventivo regular y Relevamiento de datos
(por ejemplo 525.5 kg), debe ejecutarse una sola vez
`sql/015_expand_support_repetibilidad_carga.sql` **antes** de desplegar el
backend con este esquema. Cambia de `int` a `decimal` `repetibilidad1_inicial`
y `repetibilidad1_final` en `DATA_SERVICIOS_DATOS_MPA_STAC` y
`DATA_SERVICIOS_DATOS_MPR_STIL` (`decimal(16,6)`), y `repetibilidad1` en
`DATA_SERVICIOS_DATOS_RVD` (`decimal(15,6)`), la precisión de las indicaciones
de cada tabla; los demás módulos ya la tenían como decimal. Conserva los
valores existentes y puede volver a ejecutarse sin efecto. El backend valida
contra `DataMET_prueba_esquema.md` al arrancar: después del script hay que
copiar ese archivo al servidor y reiniciar el proceso. La app no cambia.

El archivo `sql/001_calibration_data_audit.sql` es únicamente de consulta y
permite conocer los duplicados históricos sin modificar datos.

El usuario SQL de la API necesita permisos mínimos sobre las tablas de destino
y de precarga. El script `sql/006_servicemet_api_permissions.sql` valida los
objetos, concede esos permisos y muestra una comprobación final. No concede
`UPDATE`, `DELETE` ni permisos de estructura:

```sql
GRANT SELECT, INSERT ON OBJECT::dbo.DATA_SERVICIOS_DATOS_CALIBRACION TO ServiceMET;
GRANT SELECT, INSERT ON OBJECT::dbo.DATA_SERVICIOS_DATOS TO ServiceMET;
GRANT SELECT, INSERT ON OBJECT::dbo.DATA_SERVICIOS_DATOS_DIG TO ServiceMET;
GRANT SELECT, INSERT ON OBJECT::dbo.DATA_SERVICIOS_DATOS_IBM TO ServiceMET;
GRANT SELECT, INSERT ON OBJECT::dbo.DATA_SERVICIOS_DATOS_INT TO ServiceMET;
GRANT SELECT, INSERT ON OBJECT::dbo.DATA_SERVICIOS_DATOS_MCR TO ServiceMET;
GRANT SELECT, INSERT ON OBJECT::dbo.DATA_SERVICIOS_DATOS_MPA_STAC TO ServiceMET;
GRANT SELECT, INSERT ON OBJECT::dbo.DATA_SERVICIOS_DATOS_MPR_STIL TO ServiceMET;
GRANT SELECT, INSERT ON OBJECT::dbo.DATA_SERVICIOS_DATOS_RVD TO ServiceMET;
GRANT SELECT, INSERT ON OBJECT::dbo.DATA_SERVICIOS_DATOS_VFI TO ServiceMET;
```

En producción, publicar la API detrás de HTTPS (IIS, Nginx u otro proxy
inverso). La contraseña del usuario y el JWT no deben viajar por HTTP fuera de
un entorno de prueba controlado.

En la red interna de ServiceMET, Node sirve HTTPS directamente con un PFX que
incluye las IP `192.168.1.5` y `10.50.8.1`. La app fija la huella SHA-256 del
certificado; nunca desactive la validación TLS ni acepte cualquier certificado.

## Endpoints

- `GET /health`: verifica API y SQL Server.
- `POST /api/auth/login`: valida `data_users` y emite un JWT temporal.
- `GET /api/bootstrap`: descarga autenticada de los datos necesarios para trabajar offline.
- `POST /api/calibracion/validar`: valida el lote sin insertar.
- `POST /api/calibracion/subir`: vuelve a validar y usa una transacción SQL.
- `POST /api/soporte/validar`: valida registros de los ocho módulos de soporte sin insertar.
- `POST /api/soporte/subir`: inserta el lote de soporte y sus resúmenes en una transacción.

### Oportunidades comerciales en Bitrix24

Opcional. Crea cada oportunidad como **Lead**, que en el Bitrix24 en español
aparece en **CRM › Prospectos**. Requiere `BITRIX_WEBHOOK_URL` en `.env` (ver
[docs/bitrix24-configuracion.md](docs/bitrix24-configuracion.md)). Sin webhook
la API funciona igual y estas rutas responden `503 BITRIX_NOT_CONFIGURED`.
Todas exigen el JWT con el scope `bitrix:opportunity`.

- `GET /api/bitrix/status`: etapa inicial resuelta y estado del mapeo de campos.
- `GET /api/bitrix/companies?q=texto`: busca empresas por nombre (`crm.item.list`, 4).
- `GET /api/bitrix/companies/:id/contacts`: contactos vinculados a la empresa.
- `GET /api/bitrix/lead-stages` y `GET /api/bitrix/lead-sources`: etapas y fuentes de Prospectos.
- `GET /api/bitrix/lead-fields`: campos de Prospectos, incluidos los personalizados.
- `POST /api/bitrix/opportunities`: crea el prospecto (`crm.item.add`, 1).
  Responde `201`, o `200` si el UUID ya estaba registrado.

`pnpm bitrix:discover` verifica el webhook y muestra los IDs reales de etapas,
fuentes y campos personalizados sin imprimir el secreto. El código vive en
`src/bitrix/`: el cliente HTTP (único que conoce el webhook), `BitrixService`,
el mapeo de campos (`bitrix-mapping.js`) y las rutas.

### Formularios adicionales (RIM y oportunidades)

Los formularios que el técnico llena dentro de un servicio se guardan en sus
propias tablas, **en la misma base del backend** (`DB_NAME`: DataMET en
producción, DataMET_prueba en las pruebas). No se usa ninguna otra base:

- `dbo.form_rim`: recepción de instrumentos de pesaje (RIM), con el estado
  físico, el inventario, los datos de la recepción y las firmas del cliente
  y del representante de Métrica (PNG en `firma_cliente` y
  `firma_representante`; la API exige las dos).
- `dbo.form_bitrix`: copia de cada oportunidad comercial registrada en
  Bitrix24, con el número de prospecto.

Antes de habilitarlos, un administrador debe ejecutar una sola vez
`sql/012_create_form_rim_y_form_bitrix.sql` en DataMET (para DataMET_prueba,
cambie su `USE`): crea las dos tablas, da al login de la API solo `SELECT` e
`INSERT` y le deniega `UPDATE` y `DELETE`, para que ningún rol que tenga en
DataMET le permita modificar un formulario. Mientras el script no se ejecute,
la subida del RIM responde `503 EXTRAS_NOT_READY` y el RIM queda pendiente en
el teléfono. La variable `EXTRAS_DB_NAME` ya no existe: si quedó en el `.env`,
se ignora con un aviso en el log.

Un formulario puede venir de una calibración, de un soporte o de un
**registro directo** (llenado desde la pestaña Servicios, sin servicio en
curso): `tipo_servicio` vale `calibracion`, `soporte` o `directo`. Si las
tablas se crearon antes de admitir `directo`, vuelva a ejecutar el script 012:
actualiza la restricción sin tocar los datos.

- `POST /api/extras/rim`: registra un RIM. Exige el JWT con el scope
  `extras:upload`. Responde `201`, o `200` si el UUID ya estaba registrado
  (reenviar no duplica). El servidor impone `fecha_reg`, `reg_usuario` (usuario
  del token) y `reg_por` (su nombre en `data_users`); `emitido_en` es la hora
  del teléfono al emitir.

#### Numeración del RIM (`RIM-AA-NNNN`)

Desde la versión de ServiceMET que numera el RIM, cada RIM tiene un código
único para todas las áreas y orígenes: `RIM-{gestión de 2 dígitos}-{número de
4 dígitos}` (`RIM-26-0042`). El número es único en la gestión. Como la app
trabaja sin conexión, recibe por adelantado **talonarios** de números libres
(10 por defecto, `RIM_TALONARIO_SIZE` de 1 a 100) y los usa en orden al
emitir, aunque no tenga red; así el cliente firma con el código definitivo.

Requiere ejecutar `sql/014_rim_numeracion_y_gestion.sql` **antes** de desplegar
este backend (complete en el script el login de DataMET+). Crea
`rim_talonarios`, `rim_talonarios_cierres`, `form_rim_anulaciones`,
`form_rim_fotos`, el procedimiento `rim_reservar_talonario` (reparte rangos
sin repetirlos, con un bloqueo exclusivo) y agrega a `form_rim` la gestión, el
número, el talonario, la instalación y el origen, con un índice único que
impide que dos RIM compartan número. Va en DataMET, como el 012. La API
recibe `EXECUTE` sobre el procedimiento e `INSERT` en las tablas nuevas, y un
`DENY` de `UPDATE` y `DELETE` en todas las del RIM, igual que DataMET+; al final
el script muestra los permisos efectivos de cada usuario y avisa si alguno
todavía puede modificar (por ejemplo, si es `db_owner`).

- `POST /api/extras/rim/talonarios`: entrega un talonario a la instalación de
  la app (`requestId`, `installationId`, `year`, `device`, `appVersion`).
  Repetir el mismo `requestId` devuelve el mismo talonario (`200`). Solo se
  entregan talonarios de la gestión en curso y, en diciembre, de la siguiente
  (hora de La Paz).
- `POST /api/extras/rim/talonarios/:id/cierre`: la app informa que ya no usará
  el resto del talonario (`reason: fin_gestion`, `lastUsed`). Los números sin
  RIM de un talonario cerrado se muestran en DataMET+ como no utilizados.
- Al subir un RIM numerado, la API comprueba que su número pertenezca a un
  talonario entregado a la misma instalación (`installationId`) y que la
  gestión coincida con la fecha de emisión; si no, responde `409
  RIM_NUMBER_NOT_ASSIGNED` o `409 RIM_NUMBER_TAKEN`. Los RIM con el código
  anterior (`RIM-{planta}-{AA}`) se siguen aceptando, sin número.
- Un RIM anulado en el teléfono antes de subirse llega con `voided` (quién,
  cuándo y motivo) y se registra junto con su fila en `form_rim_anulaciones`,
  para que su número no quede como un hueco.

Sin el script 014, los RIM numerados y los talonarios responden `503
EXTRAS_NOT_READY` y quedan pendientes en el teléfono.

#### Ejecución y entrega del RIM (DataMET+)

Lo que pasa después de la recepción (sección 6.2, ejecución en Soporte
Técnico, y 6.3, entrega al cliente con dos firmas) se registra en DataMET+,
desde la ficha del RIM, sin modificar el RIM. El script
`sql/016_rim_ejecucion_y_entrega.sql` crea `form_rim_ejecucion` y
`form_rim_entregas`: cada guardado es una fila nueva que apunta a la vigente
(`anterior_id`), con usuario, hora del servidor y, si corrige, motivo; dos
índices únicos filtrados mantienen una sola cadena por RIM. Va en DataMET.
Da `SELECT` e `INSERT` solo al login de DataMET+ (complete
`@loginDataMetPlus`) y deniega `UPDATE` y `DELETE` a DataMET+ y a esta API,
que no usa esas tablas; la app no cambia. Ejecútelo antes de desplegar la
versión de DataMET+ que muestra la ejecución y la entrega.

Cuando `POST /api/bitrix/opportunities` crea (o reconoce) un prospecto, la API
inserta además su fila en `form_bitrix`. Si esa copia falla, la oportunidad
responde igual y el servidor lo registra como advertencia; reenviarla vuelve a
intentarlo. El código vive en `src/extras/`.

Los endpoints de calibración y soporte requieren `Authorization: Bearer <token>`. La
subida acepta `mode: "all"` o `mode: "valid_only"`. En ambos casos, todos los
registros efectivamente elegidos se insertan o se revierten juntos.

En cada tabla detallada, la API impone `estado_servicio_csv = ACTIVO` al
insertar. El valor es administrado por el servidor y reemplaza cualquier valor
que pudiera enviar la app.

## Asignación de identificadores

Dentro de una transacción serializable, SQL Server asigna el correlativo `n`
mediante su columna `IDENTITY`, y la API recupera el valor real con
`SCOPE_IDENTITY()`. En calibración, la API genera `codigo_registro` como
`SECA-COD_METRICA`. En soporte usa
`OTST-CODIGO_MODULO-COD_METRICA` (por ejemplo,
`26-0090-11-S02-MPR.BL-0090-11-014`).
Los duplicados históricos permanecen intactos. Antes de insertar, la API impide
repetir códigos dentro del lote o agregar un código que ya exista en DataMET,
sin exigir cambios en el esquema de la base.

Cada fila de calibración genera además una fila en `DATA_SERVICIOS_DATOS`
dentro de la misma transacción. El resumen usa la fecha del servidor, el nombre
del usuario autenticado y el nombre lógico del CSV conservado por la app. El
estado es `EN OBSERVACION`, salvo para una balanza nueva, cuyo resumen usa
`BALANZA NUEVA`. También guarda `tipo_servicio`: `CAL.BL` para
calibración o la sigla oficial del módulo de soporte (`MPR.BL`, `MPA.SP`,
`MCR.BL`, `DIG.BL`, `VIN.SP`, `REL.BL`, `INS.BL` o `IBM.BL`). Si cualquiera de
los dos `INSERT` falla, se
revierte el lote completo.

Las balanzas nuevas usan el código métrica
`COD_CLIENTE-COD_PLANTA-DDMMAAHHMMSS`. Se insertan normalmente en su tabla de
detalle y conservan la misma estructura de `codigo_registro`; únicamente el
resumen general se guarda con `estado_servicio = BALANZA NUEVA`.
La respuesta de subida marca cada registro nuevo para que la app muestre al
técnico cuántas balanzas debe completar posteriormente en DataMET.

Las subidas adquieren además un bloqueo transaccional con `sp_getapplock`. De
esta forma, dos dispositivos o instancias de la API no pueden validar e insertar
el mismo código simultáneamente. El bloqueo existe solo durante la transacción y
no crea ni modifica objetos de la base.
