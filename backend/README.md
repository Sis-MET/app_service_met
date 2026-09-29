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
