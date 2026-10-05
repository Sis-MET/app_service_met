/*
  Crea la base servicios_extras con los formularios adicionales de ServiceMET:

    - dbo.form_rim     Recepción de instrumentos de pesaje (RIM), con las
                       firmas del cliente y del representante de Métrica.
    - dbo.form_bitrix  Oportunidades comerciales registradas en Bitrix24
                       (CRM › Prospectos): copia de lo que se envió y el
                       número de prospecto asignado.

  Son formularios que el técnico llena dentro de una calibración o de un
  servicio de soporte, o directamente desde la pestaña Servicios, pero que no
  pertenecen a las tablas de DataMET: por eso viven en una base aparte, en la
  misma instancia de SQL Server.

  Ejecutar con una cuenta administradora (crea una base). Puede ejecutarse de
  nuevo: no recrea lo que ya existe ni duplica permisos. Si las tablas se
  crearon con una versión anterior de este script, actualiza la restricción
  de tipo_servicio para admitir los registros directos y agrega la columna
  de la firma del representante de Métrica.

  Permisos: el login de la API (ServiceMET) recibe SELECT e INSERT sobre las
  dos tablas. Deliberadamente NO recibe UPDATE, DELETE, ALTER ni CONTROL: un
  formulario subido no se modifica ni se borra desde la API. Si el login de la
  API tiene otro nombre, cambie @loginApi más abajo.

  Orden de despliegue:
    1. Este script.
    2. El backend con las rutas /api/extras (EXTRAS_DB_NAME en .env si la
       base no se llama servicios_extras).
    3. La versión de ServiceMET que emite RIM.
  Si la app se adelanta, la subida del RIM responde 503 y el RIM queda
  pendiente en el teléfono; no se pierde.
*/

IF DB_ID(N'servicios_extras') IS NULL
BEGIN
  CREATE DATABASE [servicios_extras];
  PRINT N'Base servicios_extras creada.';
END
ELSE
  PRINT N'La base servicios_extras ya existe.';
GO

USE [servicios_extras];
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

BEGIN TRANSACTION;

IF OBJECT_ID(N'dbo.form_rim', N'U') IS NULL
BEGIN
  CREATE TABLE [dbo].[form_rim] (
    [n]                      int IDENTITY(1,1) NOT NULL,
    -- Identificador del RIM generado en el teléfono: subirlo dos veces no
    -- crea dos filas.
    [uuid]                   uniqueidentifier  NOT NULL,
    [codigo_rim]             nvarchar(60)      NOT NULL,

    -- Lo impone el servidor: cuándo se recibió y quién lo subió (usuario
    -- autenticado en la API y su nombre en data_users).
    [fecha_reg]              datetime2(0)      NOT NULL
      CONSTRAINT [DF_form_rim_fecha_reg] DEFAULT (SYSDATETIME()),
    [reg_usuario]            nvarchar(100)     NOT NULL,
    [reg_por]                nvarchar(150)     NULL,

    -- Lo registra el teléfono al emitir.
    [emitido_en]             datetimeoffset(0) NOT NULL,
    [usuario_app]            nvarchar(100)     NULL,
    [app_version]            nvarchar(30)      NULL,

    -- Servicio durante el cual se emitió.
    [tipo_servicio]          nvarchar(20)      NOT NULL,  -- calibracion | soporte | directo
    [servicio]               nvarchar(100)     NULL,
    [seca_otst]              nvarchar(60)      NULL,
    [session_id]             nvarchar(60)      NULL,

    [cod_cliente]            nvarchar(30)      NULL,
    [cliente]                nvarchar(255)     NULL,
    [razon_social]           nvarchar(255)     NULL,
    [cod_planta]             nvarchar(30)      NULL,
    [planta]                 nvarchar(255)     NULL,
    [dir_planta]             nvarchar(255)     NULL,
    [dep_planta]             nvarchar(120)     NULL,

    [cod_metrica]            nvarchar(80)      NOT NULL,
    [instrumento]            nvarchar(120)     NULL,
    [marca]                  nvarchar(120)     NULL,
    [modelo]                 nvarchar(120)     NULL,
    [serie]                  nvarchar(120)     NULL,
    [capacidad]              nvarchar(120)     NULL,
    [division]               nvarchar(120)     NULL,
    [unidad]                 nvarchar(20)      NULL,
    [ubicacion]              nvarchar(255)     NULL,

    [motivo]                 nvarchar(2000)    NOT NULL,

    -- JSON: {"items":{"indicator":"present",...},"quantities":{"loadCells":"4"},
    --        "others":[{"name":"Cable RS232","status":"present"}]}
    [inventario]             nvarchar(max)     NOT NULL,
    [obs_inventario]         nvarchar(1000)    NULL,
    [estado_general]         nvarchar(20)      NOT NULL,  -- excellent | good | fair | poor | critical
    -- JSON: {"scratches":["platform","display"],"corrosion":[]}
    [danos]                  nvarchar(max)     NOT NULL,
    [descripcion_danos]      nvarchar(2000)    NULL,
    [nivel_suciedad]         nvarchar(20)      NOT NULL,  -- clean | light | moderate | heavy

    [pruebas_funcionamiento] bit               NOT NULL,
    [descripcion_pruebas]    nvarchar(2000)    NULL,

    [contacto_nombre]        nvarchar(150)     NOT NULL,
    [contacto_cargo]         nvarchar(100)     NULL,
    [contacto_telefono]      nvarchar(30)      NULL,
    [representante_metrica]  nvarchar(150)     NOT NULL,
    [lugar_recepcion]        nvarchar(255)     NOT NULL,
    [tecnico_asignado]       nvarchar(150)     NULL,

    -- Firmas del cliente y del representante de Métrica, en PNG. La API
    -- exige las dos; la segunda admite NULL solo para poder agregarla a una
    -- tabla creada con una versión anterior de este script.
    [firma_cliente]          varbinary(max)    NOT NULL,
    [firma_representante]    varbinary(max)    NULL,

    CONSTRAINT [PK_form_rim] PRIMARY KEY CLUSTERED ([n]),
    CONSTRAINT [UQ_form_rim_uuid] UNIQUE ([uuid]),
    CONSTRAINT [CK_form_rim_tipo_servicio]
      CHECK ([tipo_servicio] IN (N'calibracion', N'soporte', N'directo'))
  );
  CREATE INDEX [IX_form_rim_cod_metrica]
    ON [dbo].[form_rim] ([cod_metrica], [emitido_en]);
  CREATE INDEX [IX_form_rim_seca_otst] ON [dbo].[form_rim] ([seca_otst]);
  PRINT N'Tabla dbo.form_rim creada.';
END
ELSE
  PRINT N'La tabla dbo.form_rim ya existe.';

IF OBJECT_ID(N'dbo.form_bitrix', N'U') IS NULL
BEGIN
  CREATE TABLE [dbo].[form_bitrix] (
    [n]                       int IDENTITY(1,1) NOT NULL,
    -- Identificador de la oportunidad generado en el teléfono; es también
    -- el originId del prospecto en Bitrix24.
    [uuid]                    uniqueidentifier  NOT NULL,
    [bitrix_lead_id]          int               NOT NULL,
    [etapa]                   nvarchar(50)      NULL,

    [fecha_reg]               datetime2(0)      NOT NULL
      CONSTRAINT [DF_form_bitrix_fecha_reg] DEFAULT (SYSDATETIME()),
    [reg_usuario]             nvarchar(100)     NOT NULL,
    [creado_en]               datetimeoffset(0) NULL,
    [app_version]             nvarchar(30)      NULL,

    [tipo_servicio]           nvarchar(20)      NOT NULL,  -- calibracion | soporte | directo
    [servicio]                nvarchar(100)     NULL,
    [seca_otst]               nvarchar(60)      NULL,
    [session_id]              nvarchar(60)      NULL,
    [cliente]                 nvarchar(255)     NULL,
    [razon_social]            nvarchar(255)     NULL,
    [planta]                  nvarchar(255)     NULL,
    [dep_planta]              nvarchar(120)     NULL,
    [cod_metrica]             nvarchar(80)      NULL,
    [instrumento]             nvarchar(120)     NULL,
    [marca]                   nvarchar(120)     NULL,
    [modelo]                  nvarchar(120)     NULL,
    [serie]                   nvarchar(120)     NULL,
    [capacidad]               nvarchar(120)     NULL,
    [division]                nvarchar(120)     NULL,
    [unidad]                  nvarchar(20)      NULL,
    [ubicacion]               nvarchar(255)     NULL,
    [tecnico]                 nvarchar(150)     NULL,

    [company_id]              int               NOT NULL,
    [company_name]            nvarchar(255)     NULL,
    [contact_id]              int               NULL,
    [contact_name]            nvarchar(255)     NULL,

    [tipo_oportunidad]        nvarchar(50)      NOT NULL,
    [tipo_oportunidad_nombre] nvarchar(100)     NULL,
    [linea]                   nvarchar(60)      NULL,
    [ciudad]                  nvarchar(60)      NULL,
    [titulo]                  nvarchar(255)     NOT NULL,
    [descripcion]             nvarchar(4000)    NOT NULL,
    [prioridad]               nvarchar(10)      NULL,
    [observaciones]           nvarchar(2000)    NULL,

    CONSTRAINT [PK_form_bitrix] PRIMARY KEY CLUSTERED ([n]),
    CONSTRAINT [UQ_form_bitrix_uuid] UNIQUE ([uuid]),
    CONSTRAINT [CK_form_bitrix_tipo_servicio]
      CHECK ([tipo_servicio] IN (N'calibracion', N'soporte', N'directo'))
  );
  CREATE INDEX [IX_form_bitrix_lead] ON [dbo].[form_bitrix] ([bitrix_lead_id]);
  CREATE INDEX [IX_form_bitrix_seca_otst] ON [dbo].[form_bitrix] ([seca_otst]);
  PRINT N'Tabla dbo.form_bitrix creada.';
END
ELSE
  PRINT N'La tabla dbo.form_bitrix ya existe.';

-- Tablas creadas antes de los registros directos (formularios llenados fuera
-- de un servicio): se amplía la restricción de tipo_servicio.
IF EXISTS (
  SELECT 1 FROM sys.check_constraints
  WHERE [name] = N'CK_form_rim_tipo_servicio'
    AND [parent_object_id] = OBJECT_ID(N'dbo.form_rim')
    AND [definition] NOT LIKE N'%directo%'
)
BEGIN
  ALTER TABLE [dbo].[form_rim] DROP CONSTRAINT [CK_form_rim_tipo_servicio];
  ALTER TABLE [dbo].[form_rim] ADD CONSTRAINT [CK_form_rim_tipo_servicio]
    CHECK ([tipo_servicio] IN (N'calibracion', N'soporte', N'directo'));
  PRINT N'dbo.form_rim admite ahora tipo_servicio = directo.';
END

IF EXISTS (
  SELECT 1 FROM sys.check_constraints
  WHERE [name] = N'CK_form_bitrix_tipo_servicio'
    AND [parent_object_id] = OBJECT_ID(N'dbo.form_bitrix')
    AND [definition] NOT LIKE N'%directo%'
)
BEGIN
  ALTER TABLE [dbo].[form_bitrix] DROP CONSTRAINT [CK_form_bitrix_tipo_servicio];
  ALTER TABLE [dbo].[form_bitrix] ADD CONSTRAINT [CK_form_bitrix_tipo_servicio]
    CHECK ([tipo_servicio] IN (N'calibracion', N'soporte', N'directo'));
  PRINT N'dbo.form_bitrix admite ahora tipo_servicio = directo.';
END

-- Tabla creada antes de pedir la firma del representante de Métrica.
IF COL_LENGTH(N'dbo.form_rim', N'firma_representante') IS NULL
BEGIN
  ALTER TABLE [dbo].[form_rim] ADD [firma_representante] varbinary(max) NULL;
  PRINT N'dbo.form_rim tiene ahora la columna firma_representante.';
END

COMMIT TRANSACTION;
GO

-- Permisos mínimos para el login de la API.
DECLARE @loginApi sysname = N'ServiceMET';
DECLARE @sql nvarchar(max);

IF SUSER_ID(@loginApi) IS NULL
BEGIN
  DECLARE @mensaje nvarchar(400) = CONCAT(
    N'El login ', @loginApi, N' no existe en el servidor. Las tablas quedaron ',
    N'creadas; corrija @loginApi y ejecute el script de nuevo para dar los permisos.');
  THROW 51000, @mensaje, 1;
END

IF NOT EXISTS (
  SELECT 1 FROM sys.database_principals WHERE [sid] = SUSER_SID(@loginApi)
)
BEGIN
  SET @sql = CONCAT(
    N'CREATE USER ', QUOTENAME(@loginApi), N' FOR LOGIN ', QUOTENAME(@loginApi), N';');
  EXEC sys.sp_executesql @sql;
END

DECLARE @usuarioApi sysname = (
  SELECT TOP (1) [name] FROM sys.database_principals WHERE [sid] = SUSER_SID(@loginApi)
);

SET @sql = CONCAT(
  N'GRANT SELECT, INSERT ON OBJECT::[dbo].[form_rim] TO ', QUOTENAME(@usuarioApi), N';',
  N'GRANT SELECT, INSERT ON OBJECT::[dbo].[form_bitrix] TO ', QUOTENAME(@usuarioApi), N';');
EXEC sys.sp_executesql @sql;

-- Verificación de permisos efectivos usando el propio usuario de la API.
SET @sql = CONCAT(N'EXECUTE AS USER = ', QUOTENAME(@usuarioApi, ''''), N';
SELECT
    permisos.[tabla],
    HAS_PERMS_BY_NAME(N''dbo.'' + permisos.[tabla], N''OBJECT'', N''SELECT'') AS [puede_leer],
    HAS_PERMS_BY_NAME(N''dbo.'' + permisos.[tabla], N''OBJECT'', N''INSERT'') AS [puede_insertar],
    HAS_PERMS_BY_NAME(N''dbo.'' + permisos.[tabla], N''OBJECT'', N''UPDATE'') AS [puede_actualizar],
    HAS_PERMS_BY_NAME(N''dbo.'' + permisos.[tabla], N''OBJECT'', N''DELETE'') AS [puede_eliminar]
FROM (VALUES (N''form_rim''), (N''form_bitrix'')) AS permisos([tabla])
ORDER BY permisos.[tabla];
REVERT;');
EXEC sys.sp_executesql @sql;
GO
