/*
  Pasos de las cargas sustitutivas del ensayo de linealidad de balanzas, en
  DataMET: la misma base de calibración del backend (para las pruebas,
  DataMET_prueba: cambie el USE de abajo).

  Cuando las pesas no alcanzan, el técnico arma cargas más grandes con
  material de sustitución (EURAMET cg-18 v4.0, 4.3.3; Guía SIM, 4.3.3 y
  7.1.2.6). Hasta ahora DATA_SERVICIOS_DATOS_CALIBRACION solo guardaba la carga
  que resultaba (lin{n}); con eso no se puede rehacer la cadena ni su
  incertidumbre. Esta tabla guarda, por cada fila sustitutiva:

    metodo                  M1 (la sustitutiva se parece a la carga anterior
                            y se suma a la carga de pesas) o M2 (se parece a
                            la carga de pesas y se suma a la carga anterior)
    indicacion_sustitutiva  la indicación con la carga sustitutiva sola
    fila_referencia,        la fila cuyo error corrige esa indicación, con su
    carga_referencia,       carga, indicación y error al subir
    indicacion_referencia,
    error_referencia
    carga_sustitutiva       indicacion_sustitutiva − error_referencia
    fila_base, carga_base   la fila a la que se suma
    carga_resultante        carga_base + carga_sustitutiva, como quedó en
                            lin{fila} (con los decimales de d)
    registrado_en           hora del teléfono al registrar el paso

  La API de ServiceMET los inserta en la misma transacción que el registro
  (calibracion_n = su n) y rechaza un paso que no concuerde con él.

  Solo se agrega: el login de la API recibe SELECT e INSERT y un DENY de
  UPDATE y DELETE, para que ningún rol de DataMET se los dé. DataMET+
  (@loginDataMetPlus, opcional) recibe solo SELECT y el mismo DENY.

  Puede ejecutarse de nuevo: solo crea lo que falte y vuelve a otorgar los
  permisos. Ejecutar con una cuenta administradora.

  Orden de despliegue:
    1. Este script (en DataMET_prueba para probar; luego en DataMET).
    2. El backend de ServiceMET (src/sustitucion.js).
    3. La app que envía `sustituciones`.
  Si la app se adelanta al script, sus registros con cargas sustitutivas
  quedan en el teléfono como «por subir» y la API responde que falta este
  script. Si se adelanta al backend, un backend anterior ignora los pasos: no
  publique la app antes que el backend.
*/

USE [DataMET];
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'dbo.DATA_SERVICIOS_DATOS_CALIBRACION', N'U') IS NULL
  THROW 51000, N'No existe dbo.DATA_SERVICIOS_DATOS_CALIBRACION: ¿es la base correcta? No se realizaron cambios.', 1;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRANSACTION;

IF OBJECT_ID(N'dbo.DATA_SERVICIOS_DATOS_CALIBRACION_SUSTITUCION', N'U') IS NULL
BEGIN
  CREATE TABLE [dbo].[DATA_SERVICIOS_DATOS_CALIBRACION_SUSTITUCION] (
    [id]                      int IDENTITY(1,1)  NOT NULL,
    [calibracion_n]           int                NOT NULL,  -- n del registro
    [codigo_registro]         nvarchar(100)      NOT NULL,  -- SECA-COD_METRICA
    [paso]                    int                NOT NULL,  -- 1, 2, … en orden
    [fila]                    int                NOT NULL,  -- lin{fila}
    [metodo]                  nvarchar(2)        NOT NULL,
    [indicacion_sustitutiva]  decimal(18,8)      NOT NULL,
    [fila_referencia]         int                NOT NULL,
    [carga_referencia]        decimal(18,8)      NOT NULL,
    [indicacion_referencia]   decimal(18,8)      NOT NULL,
    [error_referencia]        decimal(18,8)      NOT NULL,
    [carga_sustitutiva]       decimal(18,8)      NOT NULL,
    [fila_base]               int                NOT NULL,
    [carga_base]              decimal(18,8)      NOT NULL,
    [carga_resultante]        decimal(18,8)      NOT NULL,
    [registrado_en]           datetimeoffset(0)  NULL,
    [fecha_reg]               datetime2(0)       NOT NULL
      CONSTRAINT [DF_CAL_SUST_fecha_reg] DEFAULT (SYSDATETIME()),
    CONSTRAINT [PK_CAL_SUST] PRIMARY KEY CLUSTERED ([id]),
    CONSTRAINT [UQ_CAL_SUST_paso] UNIQUE ([calibracion_n], [paso]),
    CONSTRAINT [UQ_CAL_SUST_fila] UNIQUE ([calibracion_n], [fila]),
    CONSTRAINT [CK_CAL_SUST_metodo] CHECK ([metodo] IN (N'M1', N'M2')),
    CONSTRAINT [CK_CAL_SUST_paso] CHECK ([paso] >= 1),
    CONSTRAINT [CK_CAL_SUST_fila] CHECK ([fila] BETWEEN 2 AND 60),
    CONSTRAINT [CK_CAL_SUST_filas_usadas] CHECK (
      [fila_referencia] BETWEEN 1 AND [fila] - 1
      AND [fila_base] BETWEEN 1 AND [fila] - 1)
  );
  CREATE INDEX [IX_CAL_SUST_codigo_registro]
    ON [dbo].[DATA_SERVICIOS_DATOS_CALIBRACION_SUSTITUCION] ([codigo_registro]);
  PRINT N'Tabla dbo.DATA_SERVICIOS_DATOS_CALIBRACION_SUSTITUCION creada.';
END
ELSE
  PRINT N'La tabla dbo.DATA_SERVICIOS_DATOS_CALIBRACION_SUSTITUCION ya existe.';

COMMIT TRANSACTION;
GO

-- Permisos: solo leer y agregar.
SET NOCOUNT ON;

DECLARE @loginApi sysname = N'ServiceMET';
-- Opcional: el DB_USER de DataMET+, para consultar la tabla. Vacío, no se le
-- da nada.
DECLARE @loginDataMetPlus sysname = N'';
DECLARE @tabla sysname = N'DATA_SERVICIOS_DATOS_CALIBRACION_SUSTITUCION';
DECLARE @sql nvarchar(max);

IF SUSER_ID(@loginApi) IS NULL
BEGIN
  DECLARE @mensaje nvarchar(400) = CONCAT(
    N'El login ', @loginApi, N' no existe en el servidor. La tabla quedó ',
    N'creada; corrija @loginApi y ejecute el script de nuevo para dar los permisos.');
  THROW 51000, @mensaje, 1;
END

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE [sid] = SUSER_SID(@loginApi))
BEGIN
  SET @sql = CONCAT(N'CREATE USER ', QUOTENAME(@loginApi), N' FOR LOGIN ', QUOTENAME(@loginApi), N';');
  EXEC sys.sp_executesql @sql;
END

DECLARE @usuarioApi sysname = (
  SELECT TOP (1) [name] FROM sys.database_principals WHERE [sid] = SUSER_SID(@loginApi)
);

-- DENY prevalece sobre lo que el usuario reciba por un rol de DataMET (salvo
-- db_owner): un paso subido no se modifica ni se borra.
SET @sql = N'GRANT SELECT, INSERT ON OBJECT::[dbo].' + QUOTENAME(@tabla) + N' TO ' + QUOTENAME(@usuarioApi) + N';'
  + N'DENY UPDATE, DELETE ON OBJECT::[dbo].' + QUOTENAME(@tabla) + N' TO ' + QUOTENAME(@usuarioApi) + N';';
EXEC sys.sp_executesql @sql;

IF NULLIF(LTRIM(RTRIM(@loginDataMetPlus)), N'') IS NOT NULL
BEGIN
  IF SUSER_ID(@loginDataMetPlus) IS NULL
    PRINT CONCAT(N'AVISO: el login ', @loginDataMetPlus, N' no existe; no se le dieron permisos.');
  ELSE
  BEGIN
    IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE [sid] = SUSER_SID(@loginDataMetPlus))
    BEGIN
      SET @sql = CONCAT(N'CREATE USER ', QUOTENAME(@loginDataMetPlus), N' FOR LOGIN ', QUOTENAME(@loginDataMetPlus), N';');
      EXEC sys.sp_executesql @sql;
    END
    DECLARE @usuarioPlus sysname = (
      SELECT TOP (1) [name] FROM sys.database_principals WHERE [sid] = SUSER_SID(@loginDataMetPlus)
    );
    SET @sql = N'GRANT SELECT ON OBJECT::[dbo].' + QUOTENAME(@tabla) + N' TO ' + QUOTENAME(@usuarioPlus) + N';'
      + N'DENY UPDATE, DELETE ON OBJECT::[dbo].' + QUOTENAME(@tabla) + N' TO ' + QUOTENAME(@usuarioPlus) + N';';
    EXEC sys.sp_executesql @sql;
  END
END

-- Verificación con el propio usuario de la API: leer e insertar en 1;
-- actualizar y eliminar en 0. Si actualizar o eliminar figuran en 1, el
-- usuario es db_owner de DataMET: quítele ese rol.
SET @sql = CONCAT(N'EXECUTE AS USER = ', QUOTENAME(@usuarioApi, ''''), N';
SELECT
    N''', @tabla, N''' AS [tabla],
    HAS_PERMS_BY_NAME(N''dbo.', @tabla, N''', N''OBJECT'', N''SELECT'') AS [puede_leer],
    HAS_PERMS_BY_NAME(N''dbo.', @tabla, N''', N''OBJECT'', N''INSERT'') AS [puede_insertar],
    HAS_PERMS_BY_NAME(N''dbo.', @tabla, N''', N''OBJECT'', N''UPDATE'') AS [puede_actualizar],
    HAS_PERMS_BY_NAME(N''dbo.', @tabla, N''', N''OBJECT'', N''DELETE'') AS [puede_eliminar];
REVERT;');
EXEC sys.sp_executesql @sql;
GO
