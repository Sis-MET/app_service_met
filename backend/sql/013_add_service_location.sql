/*
  Agrega la ubicación GPS de cada servicio al resumen DATA_SERVICIOS_DATOS.

  El resumen tiene una fila por servicio subido, sea calibración (CAL.BL) o
  cualquier módulo de soporte, así que las coordenadas se guardan una sola vez
  y se consultan igual para todos los tipos, unidas por codigo_registro:

    latitud        decimal(9,6)   grados, -90 a 90 (6 decimales ≈ 0,1 m)
    longitud       decimal(9,6)   grados, -180 a 180
    precision_gps  decimal(7,1)   radio de precisión informado por el teléfono, en metros
    fecha_gps      datetimeoffset(0)  instante del fijado GPS en el teléfono

  Las cuatro admiten NULL: un servicio sin señal GPS, sin permiso de ubicación
  o subido desde una versión anterior de la app se registra sin coordenadas.

  Orden de despliegue:
    1. Este script, en cada base que reciba servicios (para DataMET_prueba,
       cambie el USE de abajo).
    2. El backend que guarda la ubicación (backend/src/location.js).
    3. La versión de ServiceMET que captura la ubicación.
  Si el backend se despliega antes que este script, sigue subiendo los
  servicios sin coordenadas y lo avisa en su consola; no falla. Una app
  anterior o un backend anterior simplemente no envían ni guardan la ubicación.

  La API ya tiene SELECT e INSERT sobre la tabla completa
  (006_servicemet_api_permissions.sql): no hace falta otro permiso.

  Puede ejecutarse de nuevo: solo agrega lo que falte.
*/
USE [DataMET];
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'dbo.DATA_SERVICIOS_DATOS', N'U') IS NULL
  THROW 51000, 'No existe dbo.DATA_SERVICIOS_DATOS. No se realizaron cambios.', 1;

BEGIN TRANSACTION;

IF COL_LENGTH(N'dbo.DATA_SERVICIOS_DATOS', N'latitud') IS NULL
  ALTER TABLE [dbo].[DATA_SERVICIOS_DATOS] ADD [latitud] decimal(9,6) NULL;

IF COL_LENGTH(N'dbo.DATA_SERVICIOS_DATOS', N'longitud') IS NULL
  ALTER TABLE [dbo].[DATA_SERVICIOS_DATOS] ADD [longitud] decimal(9,6) NULL;

IF COL_LENGTH(N'dbo.DATA_SERVICIOS_DATOS', N'precision_gps') IS NULL
  ALTER TABLE [dbo].[DATA_SERVICIOS_DATOS] ADD [precision_gps] decimal(7,1) NULL;

IF COL_LENGTH(N'dbo.DATA_SERVICIOS_DATOS', N'fecha_gps') IS NULL
  ALTER TABLE [dbo].[DATA_SERVICIOS_DATOS] ADD [fecha_gps] datetimeoffset(0) NULL;

COMMIT TRANSACTION;
GO

-- Las restricciones se crean en otro lote: SQL Server compila cada lote
-- completo y no reconoce las columnas agregadas en el mismo.
SET NOCOUNT ON;
SET XACT_ABORT ON;

-- Si alguna columna ya existía con otro tipo, se detiene aquí sin crear las
-- restricciones; revise la columna a mano.
IF EXISTS (
  SELECT 1
  FROM sys.columns AS columna
  JOIN sys.types AS tipo
    ON tipo.[user_type_id] = columna.[user_type_id]
  WHERE columna.[object_id] = OBJECT_ID(N'dbo.DATA_SERVICIOS_DATOS')
    AND (
      (columna.[name] IN (N'latitud', N'longitud')
        AND NOT (tipo.[name] = N'decimal' AND columna.[precision] = 9 AND columna.[scale] = 6))
      OR (columna.[name] = N'precision_gps'
        AND NOT (tipo.[name] = N'decimal' AND columna.[precision] = 7 AND columna.[scale] = 1))
      OR (columna.[name] = N'fecha_gps' AND tipo.[name] <> N'datetimeoffset')
    )
)
  THROW 51001, 'Una columna de ubicación ya existe en dbo.DATA_SERVICIOS_DATOS con otro tipo. No se crearon las restricciones.', 1;

BEGIN TRANSACTION;

IF OBJECT_ID(N'dbo.CK_DATA_SERVICIOS_DATOS_latitud', N'C') IS NULL
  ALTER TABLE [dbo].[DATA_SERVICIOS_DATOS] WITH CHECK
    ADD CONSTRAINT [CK_DATA_SERVICIOS_DATOS_latitud]
    CHECK ([latitud] IS NULL OR [latitud] BETWEEN -90 AND 90);

IF OBJECT_ID(N'dbo.CK_DATA_SERVICIOS_DATOS_longitud', N'C') IS NULL
  ALTER TABLE [dbo].[DATA_SERVICIOS_DATOS] WITH CHECK
    ADD CONSTRAINT [CK_DATA_SERVICIOS_DATOS_longitud]
    CHECK ([longitud] IS NULL OR [longitud] BETWEEN -180 AND 180);

IF OBJECT_ID(N'dbo.CK_DATA_SERVICIOS_DATOS_precision_gps', N'C') IS NULL
  ALTER TABLE [dbo].[DATA_SERVICIOS_DATOS] WITH CHECK
    ADD CONSTRAINT [CK_DATA_SERVICIOS_DATOS_precision_gps]
    CHECK ([precision_gps] IS NULL OR [precision_gps] >= 0);

COMMIT TRANSACTION;

SELECT
  columna.[name] AS [columna],
  tipo.[name] AS [tipo],
  columna.[precision] AS [precision],
  columna.[scale] AS [escala],
  columna.[is_nullable] AS [permite_null]
FROM sys.columns AS columna
JOIN sys.types AS tipo
  ON tipo.[user_type_id] = columna.[user_type_id]
WHERE columna.[object_id] = OBJECT_ID(N'dbo.DATA_SERVICIOS_DATOS')
  AND columna.[name] IN (N'latitud', N'longitud', N'precision_gps', N'fecha_gps')
ORDER BY columna.[column_id];
GO
