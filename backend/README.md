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

La API no requiere crear índices, restricciones ni otros objetos en
`DataMET_prueba`. El archivo `sql/001_calibration_data_audit.sql` es únicamente
de consulta y permite conocer los duplicados históricos sin modificar datos.

El usuario SQL de la API necesita permisos mínimos sobre las dos tablas de la
subida:

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

Los endpoints de calibración y soporte requieren `Authorization: Bearer <token>`. La
subida acepta `mode: "all"` o `mode: "valid_only"`. En ambos casos, todos los
registros efectivamente elegidos se insertan o se revierten juntos.

## Asignación de identificadores

Dentro de una transacción serializable, SQL Server asigna el correlativo `n`
mediante su columna `IDENTITY`, y la API recupera el valor real con
`SCOPE_IDENTITY()`. La API genera `codigo_registro` como `SECA-COD_METRICA`.
Los duplicados históricos permanecen intactos. Antes de insertar, la API impide
repetir códigos dentro del lote o agregar un código que ya exista en DataMET,
sin exigir cambios en el esquema de la base.

Cada fila de calibración genera además una fila en `DATA_SERVICIOS_DATOS`
dentro de la misma transacción. El resumen usa la fecha del servidor, el nombre
del usuario autenticado, el nombre lógico del CSV conservado por la app y el
estado fijo `EN OBSERVACION`. Si cualquiera de los dos `INSERT` falla, se
revierte el lote completo.

Las subidas adquieren además un bloqueo transaccional con `sp_getapplock`. De
esta forma, dos dispositivos o instancias de la API no pueden validar e insertar
el mismo código simultáneamente. El bloqueo existe solo durante la transacción y
no crea ni modifica objetos de la base.
