/*
  Cambia la carga de la prueba de excentricidad de int a decimal(15,6).

  La carga de excentricidad es la suma de las pesas colocadas (al menos 1/3 de
  la capacidad) y en la unidad de la balanza suele tener decimales: 0.5 kg en
  una de 1.5 kg, 66.65 kg en una de 200 kg con d = 0.05. Con la columna int,
  ServiceMET no podía registrarlas. Se usa la misma precisión que
  cap_max1..cap_max3, porque la carga nunca supera la capacidad.

  Orden de despliegue:
    1. Este script, en cada base que reciba calibraciones (para
       DataMET_prueba, cambie el USE de abajo).
    2. El backend con backend/DataMET_prueba_esquema.md actualizado.
    3. La versión de ServiceMET que admite decimales en la carga.
  Si el backend o la app se adelantan, SQL Server rechaza la carga con
  decimales (error de conversión a int) y la subida falla sin escribir nada;
  no trunca el valor.

  Puede ejecutarse de nuevo: si la columna ya es decimal(15,6) no cambia nada.
  El ALTER reescribe la columna en todas las filas y bloquea la tabla mientras
  dura: ejecútelo cuando nadie esté subiendo calibraciones.
*/
USE [DataMET];
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @tipo sysname;
DECLARE @precision tinyint;
DECLARE @escala tinyint;
DECLARE @permiteNull bit;

SELECT
  @tipo = tipo.[name],
  @precision = columna.[precision],
  @escala = columna.[scale],
  @permiteNull = columna.[is_nullable]
FROM sys.tables AS tabla
JOIN sys.columns AS columna
  ON columna.[object_id] = tabla.[object_id]
 AND columna.[name] = N'carga'
JOIN sys.types AS tipo
  ON tipo.[user_type_id] = columna.[user_type_id]
WHERE tabla.[name] = N'DATA_SERVICIOS_DATOS_CALIBRACION'
  AND tabla.[schema_id] = SCHEMA_ID(N'dbo');

IF @tipo IS NULL
  THROW 51000, 'Falta la columna carga en dbo.DATA_SERVICIOS_DATOS_CALIBRACION. No se realizaron cambios.', 1;

IF @tipo = N'decimal' AND @precision = 15 AND @escala = 6
BEGIN
  PRINT N'La columna carga ya es decimal(15,6). No se realizaron cambios.';
END
ELSE
BEGIN
  IF @tipo <> N'int' OR @permiteNull = 0
    THROW 51000, 'La columna carga no es int NULL como indica el esquema. No se realizaron cambios.', 1;

  -- decimal(15,6) admite 9 cifras enteras; un int puede tener 10.
  IF EXISTS (
    SELECT 1
    FROM [dbo].[DATA_SERVICIOS_DATOS_CALIBRACION]
    WHERE ABS(CONVERT(bigint, [carga])) >= 1000000000
  )
    THROW 51000, 'Hay cargas de 10 cifras que no caben en decimal(15,6). No se realizaron cambios.', 1;

  BEGIN TRY
    BEGIN TRANSACTION;

    ALTER TABLE [dbo].[DATA_SERVICIOS_DATOS_CALIBRACION]
      ALTER COLUMN [carga] decimal(15,6) NULL;

    COMMIT TRANSACTION;
  END TRY
  BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
  END CATCH;
END;

SELECT
  tabla.[name] AS [tabla],
  columna.[name] AS [columna],
  tipo.[name] AS [tipo],
  columna.[precision] AS [precision],
  columna.[scale] AS [escala],
  columna.[is_nullable] AS [permite_null]
FROM sys.tables AS tabla
JOIN sys.columns AS columna
  ON columna.[object_id] = tabla.[object_id]
 AND columna.[name] = N'carga'
JOIN sys.types AS tipo
  ON tipo.[user_type_id] = columna.[user_type_id]
WHERE tabla.[name] = N'DATA_SERVICIOS_DATOS_CALIBRACION'
  AND tabla.[schema_id] = SCHEMA_ID(N'dbo');

-- Solo para revisar: procedimientos, vistas, funciones y disparadores que
-- leen la tabla y mencionan carga. Si guardan el valor en una variable int o
-- lo convierten a int, perderían los decimales.
SELECT
  OBJECT_SCHEMA_NAME(modulo.[object_id]) AS [esquema],
  OBJECT_NAME(modulo.[object_id]) AS [objeto],
  objeto.[type_desc] AS [tipo_objeto]
FROM sys.sql_modules AS modulo
JOIN sys.objects AS objeto
  ON objeto.[object_id] = modulo.[object_id]
WHERE modulo.[definition] LIKE N'%DATA_SERVICIOS_DATOS_CALIBRACION%'
  AND modulo.[definition] LIKE N'%[^a-z0-9_]carga[^a-z0-9_]%'
ORDER BY [esquema], [objeto];
GO
