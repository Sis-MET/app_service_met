USE [DataMET_prueba];
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @tablas TABLE ([nombre] sysname NOT NULL PRIMARY KEY);
INSERT INTO @tablas ([nombre]) VALUES
  (N'DATA_SERVICIOS_DATOS_DIG'),
  (N'DATA_SERVICIOS_DATOS_IBM'),
  (N'DATA_SERVICIOS_DATOS_INT'),
  (N'DATA_SERVICIOS_DATOS_MCR'),
  (N'DATA_SERVICIOS_DATOS_MPA_STAC'),
  (N'DATA_SERVICIOS_DATOS_MPR_STIL'),
  (N'DATA_SERVICIOS_DATOS_RVD'),
  (N'DATA_SERVICIOS_DATOS_VFI');

IF EXISTS (
  SELECT 1
  FROM @tablas AS objetivo
  LEFT JOIN sys.tables AS tabla
    ON tabla.[name] = objetivo.[nombre]
   AND tabla.[schema_id] = SCHEMA_ID(N'dbo')
  LEFT JOIN sys.columns AS columna
    ON columna.[object_id] = tabla.[object_id]
   AND columna.[name] = N'session_id'
  LEFT JOIN sys.types AS tipo
    ON tipo.[user_type_id] = columna.[user_type_id]
  WHERE columna.[object_id] IS NULL OR tipo.[name] <> N'nvarchar'
)
  THROW 51000, 'Falta una tabla/columna session_id o su tipo no es nvarchar. No se realizaron cambios.', 1;

BEGIN TRY
  BEGIN TRANSACTION;

  ALTER TABLE [dbo].[DATA_SERVICIOS_DATOS_DIG]
    ALTER COLUMN [session_id] nvarchar(30) NULL;
  ALTER TABLE [dbo].[DATA_SERVICIOS_DATOS_IBM]
    ALTER COLUMN [session_id] nvarchar(30) NULL;
  ALTER TABLE [dbo].[DATA_SERVICIOS_DATOS_INT]
    ALTER COLUMN [session_id] nvarchar(30) NULL;
  ALTER TABLE [dbo].[DATA_SERVICIOS_DATOS_MCR]
    ALTER COLUMN [session_id] nvarchar(30) NULL;
  ALTER TABLE [dbo].[DATA_SERVICIOS_DATOS_MPA_STAC]
    ALTER COLUMN [session_id] nvarchar(30) NULL;
  ALTER TABLE [dbo].[DATA_SERVICIOS_DATOS_MPR_STIL]
    ALTER COLUMN [session_id] nvarchar(30) NULL;
  ALTER TABLE [dbo].[DATA_SERVICIOS_DATOS_RVD]
    ALTER COLUMN [session_id] nvarchar(30) NULL;
  ALTER TABLE [dbo].[DATA_SERVICIOS_DATOS_VFI]
    ALTER COLUMN [session_id] nvarchar(30) NULL;

  COMMIT TRANSACTION;
END TRY
BEGIN CATCH
  IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
  THROW;
END CATCH;

SELECT
  tabla.[name] AS [tabla],
  columna.[name] AS [columna],
  tipo.[name] AS [tipo],
  columna.[max_length] / 2 AS [longitud_caracteres],
  columna.[is_nullable] AS [permite_null]
FROM @tablas AS objetivo
JOIN sys.tables AS tabla
  ON tabla.[name] = objetivo.[nombre]
 AND tabla.[schema_id] = SCHEMA_ID(N'dbo')
JOIN sys.columns AS columna
  ON columna.[object_id] = tabla.[object_id]
 AND columna.[name] = N'session_id'
JOIN sys.types AS tipo
  ON tipo.[user_type_id] = columna.[user_type_id]
ORDER BY tabla.[name];
GO
