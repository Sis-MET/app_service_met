/*
  Permisos mínimos requeridos por ServiceMET API.

  Ejecutar con una cuenta administradora sobre DataMET_prueba.
  El script es idempotente: puede ejecutarse nuevamente sin duplicar permisos.

  Tablas de destino:
    - SELECT: validación de duplicados y cálculo de correlativos.
    - INSERT: registro transaccional de servicios.

  Tablas auxiliares:
    - SELECT únicamente: autenticación y descarga de datos de precarga.

  Deliberadamente NO concede UPDATE, DELETE, ALTER ni CONTROL.
*/

USE [DataMET_prueba];
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

IF USER_ID(N'ServiceMET') IS NULL
    THROW 51000,
        'El usuario de base de datos ServiceMET no existe en DataMET_prueba.',
        1;
GO

-- Validar todos los objetos antes de modificar permisos.
IF OBJECT_ID(N'dbo.DATA_SERVICIOS_DATOS', N'U') IS NULL
    THROW 51001, 'No existe dbo.DATA_SERVICIOS_DATOS.', 1;
IF OBJECT_ID(N'dbo.DATA_SERVICIOS_DATOS_CALIBRACION', N'U') IS NULL
    THROW 51002, 'No existe dbo.DATA_SERVICIOS_DATOS_CALIBRACION.', 1;
IF OBJECT_ID(N'dbo.DATA_SERVICIOS_DATOS_DIG', N'U') IS NULL
    THROW 51003, 'No existe dbo.DATA_SERVICIOS_DATOS_DIG.', 1;
IF OBJECT_ID(N'dbo.DATA_SERVICIOS_DATOS_IBM', N'U') IS NULL
    THROW 51004, 'No existe dbo.DATA_SERVICIOS_DATOS_IBM.', 1;
IF OBJECT_ID(N'dbo.DATA_SERVICIOS_DATOS_INT', N'U') IS NULL
    THROW 51005, 'No existe dbo.DATA_SERVICIOS_DATOS_INT.', 1;
IF OBJECT_ID(N'dbo.DATA_SERVICIOS_DATOS_MCR', N'U') IS NULL
    THROW 51006, 'No existe dbo.DATA_SERVICIOS_DATOS_MCR.', 1;
IF OBJECT_ID(N'dbo.DATA_SERVICIOS_DATOS_MPA_STAC', N'U') IS NULL
    THROW 51007, 'No existe dbo.DATA_SERVICIOS_DATOS_MPA_STAC.', 1;
IF OBJECT_ID(N'dbo.DATA_SERVICIOS_DATOS_MPR_STIL', N'U') IS NULL
    THROW 51008, 'No existe dbo.DATA_SERVICIOS_DATOS_MPR_STIL.', 1;
IF OBJECT_ID(N'dbo.DATA_SERVICIOS_DATOS_RVD', N'U') IS NULL
    THROW 51009, 'No existe dbo.DATA_SERVICIOS_DATOS_RVD.', 1;
IF OBJECT_ID(N'dbo.DATA_SERVICIOS_DATOS_VFI', N'U') IS NULL
    THROW 51010, 'No existe dbo.DATA_SERVICIOS_DATOS_VFI.', 1;

BEGIN TRANSACTION;

-- Tabla general/resumen y tabla detallada de calibración.
GRANT SELECT, INSERT ON OBJECT::[dbo].[DATA_SERVICIOS_DATOS]
    TO [ServiceMET];
GRANT SELECT, INSERT ON OBJECT::[dbo].[DATA_SERVICIOS_DATOS_CALIBRACION]
    TO [ServiceMET];

-- Ocho tablas detalladas de soporte técnico.
GRANT SELECT, INSERT ON OBJECT::[dbo].[DATA_SERVICIOS_DATOS_DIG]
    TO [ServiceMET];
GRANT SELECT, INSERT ON OBJECT::[dbo].[DATA_SERVICIOS_DATOS_IBM]
    TO [ServiceMET];
GRANT SELECT, INSERT ON OBJECT::[dbo].[DATA_SERVICIOS_DATOS_INT]
    TO [ServiceMET];
GRANT SELECT, INSERT ON OBJECT::[dbo].[DATA_SERVICIOS_DATOS_MCR]
    TO [ServiceMET];
GRANT SELECT, INSERT ON OBJECT::[dbo].[DATA_SERVICIOS_DATOS_MPA_STAC]
    TO [ServiceMET];
GRANT SELECT, INSERT ON OBJECT::[dbo].[DATA_SERVICIOS_DATOS_MPR_STIL]
    TO [ServiceMET];
GRANT SELECT, INSERT ON OBJECT::[dbo].[DATA_SERVICIOS_DATOS_RVD]
    TO [ServiceMET];
GRANT SELECT, INSERT ON OBJECT::[dbo].[DATA_SERVICIOS_DATOS_VFI]
    TO [ServiceMET];

COMMIT TRANSACTION;
GO

-- Verificación de permisos efectivos usando el propio usuario de la API.
EXECUTE AS USER = N'ServiceMET';

SELECT
    permisos.[tabla],
    HAS_PERMS_BY_NAME(N'dbo.' + permisos.[tabla], N'OBJECT', N'SELECT')
        AS [puede_leer],
    HAS_PERMS_BY_NAME(N'dbo.' + permisos.[tabla], N'OBJECT', N'INSERT')
        AS [puede_insertar],
    HAS_PERMS_BY_NAME(N'dbo.' + permisos.[tabla], N'OBJECT', N'UPDATE')
        AS [puede_actualizar],
    HAS_PERMS_BY_NAME(N'dbo.' + permisos.[tabla], N'OBJECT', N'DELETE')
        AS [puede_eliminar]
FROM (VALUES
    (N'DATA_SERVICIOS_DATOS'),
    (N'DATA_SERVICIOS_DATOS_CALIBRACION'),
    (N'DATA_SERVICIOS_DATOS_DIG'),
    (N'DATA_SERVICIOS_DATOS_IBM'),
    (N'DATA_SERVICIOS_DATOS_INT'),
    (N'DATA_SERVICIOS_DATOS_MCR'),
    (N'DATA_SERVICIOS_DATOS_MPA_STAC'),
    (N'DATA_SERVICIOS_DATOS_MPR_STIL'),
    (N'DATA_SERVICIOS_DATOS_RVD'),
    (N'DATA_SERVICIOS_DATOS_VFI')
) AS permisos([tabla])
ORDER BY permisos.[tabla];

REVERT;
GO
