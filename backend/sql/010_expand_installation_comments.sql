USE [DataMET];
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @tabla sysname = N'DATA_SERVICIOS_DATOS_INT';
DECLARE @columnas TABLE ([nombre] sysname NOT NULL PRIMARY KEY);
INSERT INTO @columnas ([nombre]) VALUES
  (N'entorno_comentario'),
  (N'nivelacion_comentario'),
  (N'movilizacion_comentario'),
  (N'flujo_pesadas_comentario'),
  (N'superficie_apoyo_comentario'),
  (N'tension_red_comentario'),
  (N'sistema_tierra_comentario'),
  (N'comunicacion_pc_comentario'),
  (N'vibracion_externa_comentario'),
  (N'comentario_general');

IF EXISTS (
  SELECT 1
  FROM @columnas AS objetivo
  LEFT JOIN sys.tables AS tabla
    ON tabla.[name] = @tabla
   AND tabla.[schema_id] = SCHEMA_ID(N'dbo')
  LEFT JOIN sys.columns AS columna
    ON columna.[object_id] = tabla.[object_id]
   AND columna.[name] = objetivo.[nombre]
  LEFT JOIN sys.types AS tipo
    ON tipo.[user_type_id] = columna.[user_type_id]
  WHERE columna.[object_id] IS NULL OR tipo.[name] <> N'nvarchar'
)
  THROW 51000, 'Falta una columna de comentario de instalación o su tipo no es nvarchar. No se realizaron cambios.', 1;

DECLARE @sql nvarchar(max);
SELECT @sql = STRING_AGG(
  CONVERT(nvarchar(max),
    N'ALTER TABLE [dbo].' + QUOTENAME(@tabla)
    + N' ALTER COLUMN ' + QUOTENAME(objetivo.[nombre])
    + N' nvarchar(1000) NULL;'),
  NCHAR(13) + NCHAR(10)
)
FROM @columnas AS objetivo;

BEGIN TRY
  BEGIN TRANSACTION;
  EXEC sys.sp_executesql @sql;
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
FROM @columnas AS objetivo
JOIN sys.tables AS tabla
  ON tabla.[name] = @tabla
 AND tabla.[schema_id] = SCHEMA_ID(N'dbo')
JOIN sys.columns AS columna
  ON columna.[object_id] = tabla.[object_id]
 AND columna.[name] = objetivo.[nombre]
JOIN sys.types AS tipo
  ON tipo.[user_type_id] = columna.[user_type_id]
ORDER BY columna.[column_id];
GO
