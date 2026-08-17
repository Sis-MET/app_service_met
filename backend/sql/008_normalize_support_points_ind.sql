USE [DataMET];
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

-- Solo se migran las columnas que forman parte del esquema real de cada
-- módulo; no se agregan campos ajenos a módulos que no usan excentricidad.
DECLARE @columnasEsperadas TABLE (
  [tabla] sysname NOT NULL,
  [columna] sysname NOT NULL,
  PRIMARY KEY ([tabla], [columna])
);
INSERT INTO @columnasEsperadas ([tabla], [columna]) VALUES
  (N'DATA_SERVICIOS_DATOS_INT', N'puntos_ind_inicial'),
  (N'DATA_SERVICIOS_DATOS_MCR', N'puntos_ind_final'),
  (N'DATA_SERVICIOS_DATOS_MPA_STAC', N'puntos_ind_inicial'),
  (N'DATA_SERVICIOS_DATOS_MPA_STAC', N'puntos_ind_final'),
  (N'DATA_SERVICIOS_DATOS_MPR_STIL', N'puntos_ind_inicial'),
  (N'DATA_SERVICIOS_DATOS_MPR_STIL', N'puntos_ind_final'),
  (N'DATA_SERVICIOS_DATOS_RVD', N'puntos_ind'),
  (N'DATA_SERVICIOS_DATOS_VFI', N'puntos_ind_inicial');

IF EXISTS (
  SELECT 1
  FROM @tablas AS objetivo
  LEFT JOIN sys.tables AS tabla
    ON tabla.[name] = objetivo.[nombre]
   AND tabla.[schema_id] = SCHEMA_ID(N'dbo')
  WHERE tabla.[object_id] IS NULL
)
  THROW 51000, 'Falta una de las ocho tablas de soporte. No se realizaron cambios.', 1;

IF EXISTS (
  SELECT 1
  FROM @columnasEsperadas AS objetivo
  JOIN sys.tables AS tabla
    ON tabla.[name] = objetivo.[tabla]
   AND tabla.[schema_id] = SCHEMA_ID(N'dbo')
  LEFT JOIN sys.columns AS columna
    ON columna.[object_id] = tabla.[object_id]
   AND columna.[name] = objetivo.[columna]
  LEFT JOIN sys.types AS tipo
    ON tipo.[user_type_id] = columna.[user_type_id]
  WHERE columna.[object_id] IS NULL OR tipo.[name] NOT IN (N'int', N'nvarchar')
)
  THROW 51001, 'Falta una columna de puntos de indicador esperada o tiene un tipo inesperado. No se realizaron cambios.', 1;

DECLARE @sql nvarchar(max);
SELECT @sql = STRING_AGG(
  CONVERT(nvarchar(max),
    N'ALTER TABLE [dbo].' + QUOTENAME(tabla.[name])
    + N' ALTER COLUMN ' + QUOTENAME(columna.[name])
    + N' nvarchar(50) NULL;'),
  NCHAR(13) + NCHAR(10)
)
FROM @columnasEsperadas AS objetivo
JOIN sys.tables AS tabla
  ON tabla.[name] = objetivo.[tabla]
 AND tabla.[schema_id] = SCHEMA_ID(N'dbo')
JOIN sys.columns AS columna
  ON columna.[object_id] = tabla.[object_id]
 AND columna.[name] = objetivo.[columna];

BEGIN TRY
  BEGIN TRANSACTION;
  IF NULLIF(@sql, N'') IS NOT NULL EXEC sys.sp_executesql @sql;
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
FROM @columnasEsperadas AS objetivo
JOIN sys.tables AS tabla
  ON tabla.[name] = objetivo.[tabla]
 AND tabla.[schema_id] = SCHEMA_ID(N'dbo')
JOIN sys.columns AS columna
  ON columna.[object_id] = tabla.[object_id]
 AND columna.[name] = objetivo.[columna]
JOIN sys.types AS tipo
  ON tipo.[user_type_id] = columna.[user_type_id]
ORDER BY tabla.[name], columna.[name];
GO
