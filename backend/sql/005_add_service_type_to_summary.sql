USE [DataMET_prueba];
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'dbo.DATA_SERVICIOS_DATOS', N'U') IS NULL
  THROW 51000, 'No existe dbo.DATA_SERVICIOS_DATOS. No se realizaron cambios.', 1;

IF COL_LENGTH(N'dbo.DATA_SERVICIOS_DATOS', N'tipo_servicio') IS NULL
BEGIN
  ALTER TABLE [dbo].[DATA_SERVICIOS_DATOS]
    ADD [tipo_servicio] nvarchar(10) NULL;
END;
ELSE
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM sys.columns AS columna
    JOIN sys.types AS tipo
      ON tipo.[user_type_id] = columna.[user_type_id]
    WHERE columna.[object_id] = OBJECT_ID(N'dbo.DATA_SERVICIOS_DATOS')
      AND columna.[name] = N'tipo_servicio'
      AND tipo.[name] = N'nvarchar'
  )
    THROW 51001, 'dbo.DATA_SERVICIOS_DATOS.tipo_servicio existe, pero no es nvarchar.', 1;

  IF COL_LENGTH(N'dbo.DATA_SERVICIOS_DATOS', N'tipo_servicio') > 0
     AND COL_LENGTH(N'dbo.DATA_SERVICIOS_DATOS', N'tipo_servicio') < 20
  BEGIN
    ALTER TABLE [dbo].[DATA_SERVICIOS_DATOS]
      ALTER COLUMN [tipo_servicio] nvarchar(10) NULL;
  END;
END;

SELECT
  tabla.[name] AS [tabla],
  columna.[name] AS [columna],
  tipo.[name] AS [tipo],
  columna.[max_length] / 2 AS [longitud_caracteres],
  columna.[is_nullable] AS [permite_null]
FROM sys.tables AS tabla
JOIN sys.columns AS columna
  ON columna.[object_id] = tabla.[object_id]
JOIN sys.types AS tipo
  ON tipo.[user_type_id] = columna.[user_type_id]
WHERE tabla.[schema_id] = SCHEMA_ID(N'dbo')
  AND tabla.[name] = N'DATA_SERVICIOS_DATOS'
  AND columna.[name] = N'tipo_servicio';
GO
