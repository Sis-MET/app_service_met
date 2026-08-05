/*
  Ejecutar una sola vez en DataMET_prueba después de revisar el resultado de
  las consultas de duplicados. El script se detiene sin crear índices si hay
  valores repetidos.
*/

SET XACT_ABORT ON;
BEGIN TRANSACTION;

IF EXISTS (
  SELECT [codigo_registro]
  FROM [dbo].[DATA_SERVICIOS_DATOS_CALIBRACION]
  WHERE [codigo_registro] IS NOT NULL
  GROUP BY [codigo_registro]
  HAVING COUNT(*) > 1
)
BEGIN
  THROW 51000, 'Existen codigo_registro duplicados; limpielos antes de crear el índice.', 1;
END;

IF EXISTS (
  SELECT [n]
  FROM [dbo].[DATA_SERVICIOS_DATOS_CALIBRACION]
  GROUP BY [n]
  HAVING COUNT(*) > 1
)
BEGIN
  THROW 51001, 'Existen valores n duplicados; limpielos antes de crear el índice.', 1;
END;

IF NOT EXISTS (
  SELECT 1 FROM sys.indexes
  WHERE [object_id] = OBJECT_ID(N'[dbo].[DATA_SERVICIOS_DATOS_CALIBRACION]')
    AND [name] = N'UX_DATOS_CALIBRACION_codigo_registro'
)
BEGIN
  CREATE UNIQUE INDEX [UX_DATOS_CALIBRACION_codigo_registro]
    ON [dbo].[DATA_SERVICIOS_DATOS_CALIBRACION] ([codigo_registro])
    WHERE [codigo_registro] IS NOT NULL;
END;

IF NOT EXISTS (
  SELECT 1 FROM sys.indexes
  WHERE [object_id] = OBJECT_ID(N'[dbo].[DATA_SERVICIOS_DATOS_CALIBRACION]')
    AND [name] = N'UX_DATOS_CALIBRACION_n'
)
BEGIN
  CREATE UNIQUE INDEX [UX_DATOS_CALIBRACION_n]
    ON [dbo].[DATA_SERVICIOS_DATOS_CALIBRACION] ([n]);
END;

COMMIT TRANSACTION;
