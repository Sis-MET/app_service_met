/*
  Cambia la carga de la prueba de repetibilidad de soporte de int a decimal.

  La carga de repetibilidad es la suma de las pesas colocadas y, en la unidad
  de la balanza, suele tener decimales (525.5 kg, 0.5 kg). En tres módulos la
  columna era int y ServiceMET no podía subir esos servicios: el backend los
  rechazaba con "El valor debe ser un número entero". Los demás módulos
  (Instalación, Mantenimiento correctivo y Verificaciones internas) ya la
  tienen como decimal(16,6).

    DATA_SERVICIOS_DATOS_MPA_STAC  repetibilidad1_inicial  decimal(16,6)
    DATA_SERVICIOS_DATOS_MPA_STAC  repetibilidad1_final    decimal(16,6)
    DATA_SERVICIOS_DATOS_MPR_STIL  repetibilidad1_inicial  decimal(16,6)
    DATA_SERVICIOS_DATOS_MPR_STIL  repetibilidad1_final    decimal(16,6)
    DATA_SERVICIOS_DATOS_RVD       repetibilidad1          decimal(15,6)

  Cada columna toma la precisión de las indicaciones de su propia tabla.

  Orden de despliegue:
    1. Este script, en cada base que reciba servicios de soporte (para
       DataMET_prueba, cambie el USE de abajo).
    2. backend/DataMET_prueba_esquema.md actualizado en el servidor y
       `pm2 restart servicemet-api`: el backend valida contra ese archivo al
       arrancar, no contra SQL Server.
  La app no cambia: ya envía la carga con decimales.
  Si el backend se adelanta, SQL Server rechaza la carga con decimales (error
  de conversión a int) y la subida falla sin escribir nada; no trunca el
  valor.

  Puede ejecutarse de nuevo: las columnas que ya tienen el tipo final no se
  tocan. El ALTER reescribe las columnas en todas las filas y bloquea las
  tablas mientras dura: ejecútelo cuando nadie esté subiendo servicios.
*/
USE [DataMET];
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @objetivo TABLE (
  [tabla] sysname NOT NULL,
  [columna] sysname NOT NULL,
  [precision] tinyint NOT NULL,
  [escala] tinyint NOT NULL,
  [tipo_actual] sysname NULL,
  [precision_actual] tinyint NULL,
  [escala_actual] tinyint NULL,
  [permite_null] bit NULL,
  PRIMARY KEY ([tabla], [columna])
);
INSERT INTO @objetivo ([tabla], [columna], [precision], [escala]) VALUES
  (N'DATA_SERVICIOS_DATOS_MPA_STAC', N'repetibilidad1_inicial', 16, 6),
  (N'DATA_SERVICIOS_DATOS_MPA_STAC', N'repetibilidad1_final', 16, 6),
  (N'DATA_SERVICIOS_DATOS_MPR_STIL', N'repetibilidad1_inicial', 16, 6),
  (N'DATA_SERVICIOS_DATOS_MPR_STIL', N'repetibilidad1_final', 16, 6),
  (N'DATA_SERVICIOS_DATOS_RVD', N'repetibilidad1', 15, 6);

UPDATE objetivo
SET
  [tipo_actual] = tipo.[name],
  [precision_actual] = columna.[precision],
  [escala_actual] = columna.[scale],
  [permite_null] = columna.[is_nullable]
FROM @objetivo AS objetivo
JOIN sys.tables AS tabla
  ON tabla.[name] = objetivo.[tabla]
 AND tabla.[schema_id] = SCHEMA_ID(N'dbo')
JOIN sys.columns AS columna
  ON columna.[object_id] = tabla.[object_id]
 AND columna.[name] = objetivo.[columna]
JOIN sys.types AS tipo
  ON tipo.[user_type_id] = columna.[user_type_id];

IF EXISTS (SELECT 1 FROM @objetivo WHERE [tipo_actual] IS NULL)
  THROW 51000, 'Falta una de las columnas de carga de repetibilidad. No se realizaron cambios.', 1;

DECLARE @pendientes TABLE (
  [tabla] sysname NOT NULL,
  [columna] sysname NOT NULL,
  [precision] tinyint NOT NULL,
  [escala] tinyint NOT NULL,
  PRIMARY KEY ([tabla], [columna])
);
INSERT INTO @pendientes ([tabla], [columna], [precision], [escala])
SELECT [tabla], [columna], [precision], [escala]
FROM @objetivo
WHERE NOT (
  [tipo_actual] = N'decimal'
  AND [precision_actual] = [precision]
  AND [escala_actual] = [escala]
);

IF EXISTS (
  SELECT 1
  FROM @objetivo AS objetivo
  JOIN @pendientes AS pendiente
    ON pendiente.[tabla] = objetivo.[tabla]
   AND pendiente.[columna] = objetivo.[columna]
  WHERE objetivo.[tipo_actual] <> N'int' OR objetivo.[permite_null] = 0
)
  THROW 51000, 'Una columna de carga de repetibilidad no es int NULL como indica el esquema. No se realizaron cambios.', 1;

IF NOT EXISTS (SELECT 1 FROM @pendientes)
BEGIN
  PRINT N'Las cinco columnas ya tienen el tipo decimal final. No se realizaron cambios.';
END
ELSE
BEGIN
  -- Un int puede tener 10 cifras; decimal(15,6) admite 9 enteras.
  DECLARE @tabla sysname;
  DECLARE @columna sysname;
  DECLARE @limite bigint;
  DECLARE @fuera int;
  DECLARE @consulta nvarchar(max);
  DECLARE @mensaje nvarchar(2048);

  DECLARE revision CURSOR LOCAL FAST_FORWARD FOR
    SELECT [tabla], [columna], POWER(CONVERT(bigint, 10), [precision] - [escala])
    FROM @pendientes;
  OPEN revision;
  FETCH NEXT FROM revision INTO @tabla, @columna, @limite;
  WHILE @@FETCH_STATUS = 0
  BEGIN
    SET @consulta = N'SELECT @fuera = COUNT(*) FROM [dbo].' + QUOTENAME(@tabla)
      + N' WHERE ABS(CONVERT(bigint, ' + QUOTENAME(@columna) + N')) >= @limite;';
    EXEC sys.sp_executesql
      @consulta,
      N'@limite bigint, @fuera int OUTPUT',
      @limite = @limite,
      @fuera = @fuera OUTPUT;
    IF @fuera > 0
    BEGIN
      SET @mensaje = CONCAT(
        N'Hay ', @fuera, N' valores de ', @tabla, N'.', @columna,
        N' que no caben en el tipo decimal final. No se realizaron cambios.');
      THROW 51000, @mensaje, 1;
    END;
    FETCH NEXT FROM revision INTO @tabla, @columna, @limite;
  END;
  CLOSE revision;
  DEALLOCATE revision;

  DECLARE @sql nvarchar(max);
  SELECT @sql = STRING_AGG(
    CONVERT(nvarchar(max),
      N'ALTER TABLE [dbo].' + QUOTENAME([tabla])
      + N' ALTER COLUMN ' + QUOTENAME([columna])
      + N' decimal(' + CONVERT(nvarchar(3), [precision])
      + N',' + CONVERT(nvarchar(3), [escala]) + N') NULL;'),
    NCHAR(13) + NCHAR(10)
  )
  FROM @pendientes;

  BEGIN TRY
    BEGIN TRANSACTION;
    EXEC sys.sp_executesql @sql;
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
FROM @objetivo AS objetivo
JOIN sys.tables AS tabla
  ON tabla.[name] = objetivo.[tabla]
 AND tabla.[schema_id] = SCHEMA_ID(N'dbo')
JOIN sys.columns AS columna
  ON columna.[object_id] = tabla.[object_id]
 AND columna.[name] = objetivo.[columna]
JOIN sys.types AS tipo
  ON tipo.[user_type_id] = columna.[user_type_id]
ORDER BY tabla.[name], columna.[column_id];

-- Solo para revisar: procedimientos, vistas, funciones y disparadores que
-- leen estas tablas y mencionan la carga de repetibilidad. Si guardan el valor
-- en una variable int o lo convierten a int, perderían los decimales.
SELECT
  OBJECT_SCHEMA_NAME(modulo.[object_id]) AS [esquema],
  OBJECT_NAME(modulo.[object_id]) AS [objeto],
  objeto.[type_desc] AS [tipo_objeto]
FROM sys.sql_modules AS modulo
JOIN sys.objects AS objeto
  ON objeto.[object_id] = modulo.[object_id]
WHERE (
    modulo.[definition] LIKE N'%DATA_SERVICIOS_DATOS_MPA_STAC%'
    OR modulo.[definition] LIKE N'%DATA_SERVICIOS_DATOS_MPR_STIL%'
    OR modulo.[definition] LIKE N'%DATA_SERVICIOS_DATOS_RVD%'
  )
  AND modulo.[definition] LIKE N'%repetibilidad1%'
ORDER BY [esquema], [objeto];
GO
