/*
  Ejecución (6.2) y entrega (6.3) de cada RIM, en DataMET (la misma base del
  backend; para las pruebas, DataMET_prueba).

  El RIM emitido no se modifica (NB/ISO/IEC 17025, 7.5.2): lo que pasa después
  de la recepción se registra en tablas propias a las que solo se agregan filas.
  Cada fila guarda quién la registró y cuándo (hora del servidor). Una fila
  nueva reemplaza a la vigente sin borrarla, apuntando a ella (anterior_id), así
  que el historial completo queda en la tabla.

    - dbo.form_rim_ejecucion   cada fila es la versión completa de la sección
                               6.2: quién recibió en S.T., fecha de ingreso,
                               técnico asignado, fechas de inicio, informe y
                               conclusión, y N.º de cotización, informe y
                               factura.
                                 registro    primera versión
                                 avance      completa campos vacíos
                                 correccion  cambia o borra un dato ya
                                             registrado (puede dejar la
                                             sección vacía); exige motivo
    - dbo.form_rim_entregas    la sección 6.3: quién recibe por el cliente,
                               quién entrega por Métrica, fecha, lugar,
                               observaciones y las dos firmas (PNG).
                                 registro    entrega con las dos firmas
                                 correccion  cambia nombres, fecha, lugar u
                                             observaciones; conserva las firmas
                                             de la versión anterior; motivo
                                 anulacion   la entrega se registró por error
                                             (p. ej. en otro RIM); motivo.
                                             Después puede registrarse la
                                             entrega correcta.

  Cadena lineal por RIM: una sola primera fila (anterior_id NULL) y cada fila
  se reemplaza una sola vez (índices únicos filtrados). Si dos usuarios guardan
  a la vez sobre la misma versión, el segundo INSERT falla y DataMET+ le pide
  recargar. La versión vigente es la única que nadie reemplazó.

  Solo se agrega: ningún login recibe UPDATE ni DELETE, y los dos reciben un
  DENY de UPDATE y DELETE para que ningún rol que tengan en DataMET se los dé.
    - DataMET+ (@loginDataMetPlus): SELECT e INSERT en las dos tablas.
    - API de ServiceMET (@loginApi): ningún permiso (la app no registra estas
      etapas), solo el DENY.

  Requisitos: haber ejecutado 012_create_form_rim_y_form_bitrix.sql y
  014_rim_numeracion_y_gestion.sql en la misma base. Ejecutar con una cuenta
  administradora, en cada base que use el backend (para DataMET_prueba,
  cambie el USE de abajo). Puede ejecutarse de nuevo: solo agrega lo que
  falte y vuelve a otorgar los permisos.

  Orden de despliegue:
    1. Este script (complete @loginDataMetPlus más abajo).
    2. DataMET+ (backend y frontend con Ejecución y Entrega en la ficha).
  Si DataMET+ se adelanta, la ficha del RIM se sigue viendo y las secciones de
  ejecución y entrega avisan que falta este script. La app no cambia.
*/

USE [DataMET];
GO

-- Los índices únicos filtrados exigen estas opciones; sqlcmd usa
-- QUOTED_IDENTIFIER OFF si no se le pasa -I. Rigen para todos los lotes de
-- esta conexión.
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

IF OBJECT_ID(N'dbo.form_rim', N'U') IS NULL
  THROW 51000, N'No existe dbo.form_rim: ejecute primero 012_create_form_rim_y_form_bitrix.sql. No se realizaron cambios.', 1;
IF OBJECT_ID(N'dbo.form_rim_anulaciones', N'U') IS NULL
  THROW 51000, N'No existe dbo.form_rim_anulaciones: ejecute primero 014_rim_numeracion_y_gestion.sql. No se realizaron cambios.', 1;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRANSACTION;

IF OBJECT_ID(N'dbo.form_rim_ejecucion', N'U') IS NULL
BEGIN
  CREATE TABLE [dbo].[form_rim_ejecucion] (
    [id]                int IDENTITY(1,1) NOT NULL,
    [rim_uuid]          uniqueidentifier  NOT NULL,
    -- Versión que esta fila reemplaza; NULL en la primera.
    [anterior_id]       int               NULL,
    [tipo]              nvarchar(20)      NOT NULL,  -- registro | avance | correccion
    [motivo]            nvarchar(1000)    NULL,
    [recepcion_st]      nvarchar(150)     NULL,  -- quién recibió en S.T.
    [fecha_ingreso]     date              NULL,  -- ingreso a S.T.
    [tecnico_asignado]  nvarchar(150)     NULL,
    [fecha_inicio]      date              NULL,
    [fecha_informe]     date              NULL,
    [fecha_conclusion]  date              NULL,
    [nro_cotizacion]    nvarchar(60)      NULL,
    [nro_informe]       nvarchar(60)      NULL,
    [nro_factura]       nvarchar(60)      NULL,
    [origen]            nvarchar(20)      NOT NULL
      CONSTRAINT [DF_form_rim_ejecucion_origen] DEFAULT (N'datametplus'),
    -- Lo impone el servidor: usuario de la sesión, su nombre y la hora.
    [usuario]           nvarchar(100)     NOT NULL,
    [usuario_nombre]    nvarchar(150)     NULL,
    [fecha_reg]         datetime2(0)      NOT NULL
      CONSTRAINT [DF_form_rim_ejecucion_fecha_reg] DEFAULT (SYSDATETIME()),
    CONSTRAINT [PK_form_rim_ejecucion] PRIMARY KEY CLUSTERED ([id]),
    -- Destino de la referencia a la versión anterior del mismo RIM.
    CONSTRAINT [UQ_form_rim_ejecucion_id_rim] UNIQUE ([id], [rim_uuid]),
    CONSTRAINT [FK_form_rim_ejecucion_rim]
      FOREIGN KEY ([rim_uuid]) REFERENCES [dbo].[form_rim] ([uuid]),
    CONSTRAINT [CK_form_rim_ejecucion_tipo]
      CHECK (([tipo] = N'registro' AND [anterior_id] IS NULL)
          OR ([tipo] IN (N'avance', N'correccion') AND [anterior_id] IS NOT NULL)),
    CONSTRAINT [CK_form_rim_ejecucion_motivo]
      CHECK ([tipo] <> N'correccion' OR LEN(ISNULL([motivo], N'')) >= 10),
    -- Solo una corrección puede dejar la sección vacía (p. ej. se cargó en
    -- otro RIM); con su motivo queda en el historial.
    CONSTRAINT [CK_form_rim_ejecucion_datos]
      CHECK ([tipo] = N'correccion'
          OR [recepcion_st] IS NOT NULL OR [fecha_ingreso] IS NOT NULL
          OR [tecnico_asignado] IS NOT NULL OR [fecha_inicio] IS NOT NULL
          OR [fecha_informe] IS NOT NULL OR [fecha_conclusion] IS NOT NULL
          OR [nro_cotizacion] IS NOT NULL OR [nro_informe] IS NOT NULL
          OR [nro_factura] IS NOT NULL),
    CONSTRAINT [CK_form_rim_ejecucion_origen]
      CHECK ([origen] IN (N'servicemet', N'datametplus'))
  );
  PRINT N'Tabla dbo.form_rim_ejecucion creada.';
END
ELSE
  PRINT N'La tabla dbo.form_rim_ejecucion ya existe.';

IF OBJECT_ID(N'dbo.form_rim_entregas', N'U') IS NULL
BEGIN
  CREATE TABLE [dbo].[form_rim_entregas] (
    [id]                   int IDENTITY(1,1) NOT NULL,
    [rim_uuid]             uniqueidentifier  NOT NULL,
    -- Fila que esta reemplaza; NULL en la primera entrega del RIM.
    [anterior_id]          int               NULL,
    [tipo]                 nvarchar(20)      NOT NULL,  -- registro | correccion | anulacion
    [motivo]               nvarchar(1000)    NULL,
    [recibe_nombre]        nvarchar(150)     NULL,  -- quién recibe por el cliente
    [entrega_por]          nvarchar(150)     NULL,  -- quién entrega por Métrica
    [fecha_entrega]        date              NULL,
    [lugar_entrega]        nvarchar(255)     NULL,
    [observaciones]        nvarchar(1000)    NULL,
    [firma_cliente]        varbinary(max)    NULL,
    [firma_representante]  varbinary(max)    NULL,
    [origen]               nvarchar(20)      NOT NULL
      CONSTRAINT [DF_form_rim_entregas_origen] DEFAULT (N'datametplus'),
    -- Lo impone el servidor: usuario de la sesión, su nombre y la hora.
    [usuario]              nvarchar(100)     NOT NULL,
    [usuario_nombre]       nvarchar(150)     NULL,
    [fecha_reg]            datetime2(0)      NOT NULL
      CONSTRAINT [DF_form_rim_entregas_fecha_reg] DEFAULT (SYSDATETIME()),
    CONSTRAINT [PK_form_rim_entregas] PRIMARY KEY CLUSTERED ([id]),
    CONSTRAINT [UQ_form_rim_entregas_id_rim] UNIQUE ([id], [rim_uuid]),
    CONSTRAINT [FK_form_rim_entregas_rim]
      FOREIGN KEY ([rim_uuid]) REFERENCES [dbo].[form_rim] ([uuid]),
    -- Una entrega registrada después de anular otra apunta a la anulación.
    CONSTRAINT [CK_form_rim_entregas_tipo]
      CHECK ([tipo] = N'registro'
          OR ([tipo] IN (N'correccion', N'anulacion') AND [anterior_id] IS NOT NULL)),
    CONSTRAINT [CK_form_rim_entregas_motivo]
      CHECK ([tipo] = N'registro' OR LEN(ISNULL([motivo], N'')) >= 10),
    -- Una entrega vigente tiene todos sus datos y las dos firmas; la
    -- anulación no lleva datos.
    CONSTRAINT [CK_form_rim_entregas_datos]
      CHECK (([tipo] = N'anulacion'
              AND [recibe_nombre] IS NULL AND [entrega_por] IS NULL
              AND [fecha_entrega] IS NULL AND [lugar_entrega] IS NULL
              AND [observaciones] IS NULL
              AND [firma_cliente] IS NULL AND [firma_representante] IS NULL)
          OR ([tipo] <> N'anulacion'
              AND [recibe_nombre] IS NOT NULL AND [entrega_por] IS NOT NULL
              AND [fecha_entrega] IS NOT NULL AND [lugar_entrega] IS NOT NULL
              AND [firma_cliente] IS NOT NULL AND [firma_representante] IS NOT NULL)),
    CONSTRAINT [CK_form_rim_entregas_origen]
      CHECK ([origen] IN (N'servicemet', N'datametplus'))
  );
  PRINT N'Tabla dbo.form_rim_entregas creada.';
END
ELSE
  PRINT N'La tabla dbo.form_rim_entregas ya existe.';

COMMIT TRANSACTION;
GO

-- Referencia a la fila anterior e índices de la cadena, en otro lote y cada
-- uno con su verificación: si una ejecución anterior se interrumpió, se
-- completan sin tocar los datos.
SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRANSACTION;

-- La fila anterior es del mismo RIM.
IF OBJECT_ID(N'dbo.FK_form_rim_ejecucion_anterior', N'F') IS NULL
  ALTER TABLE [dbo].[form_rim_ejecucion] ADD CONSTRAINT [FK_form_rim_ejecucion_anterior]
    FOREIGN KEY ([anterior_id], [rim_uuid])
    REFERENCES [dbo].[form_rim_ejecucion] ([id], [rim_uuid]);
IF OBJECT_ID(N'dbo.FK_form_rim_entregas_anterior', N'F') IS NULL
  ALTER TABLE [dbo].[form_rim_entregas] ADD CONSTRAINT [FK_form_rim_entregas_anterior]
    FOREIGN KEY ([anterior_id], [rim_uuid])
    REFERENCES [dbo].[form_rim_entregas] ([id], [rim_uuid]);

-- Cadena lineal: una sola primera fila por RIM, y cada fila se reemplaza una
-- sola vez.
IF NOT EXISTS (SELECT 1 FROM sys.indexes
  WHERE [name] = N'UX_form_rim_ejecucion_primera' AND [object_id] = OBJECT_ID(N'dbo.form_rim_ejecucion'))
  CREATE UNIQUE INDEX [UX_form_rim_ejecucion_primera]
    ON [dbo].[form_rim_ejecucion] ([rim_uuid])
    WHERE [anterior_id] IS NULL;
IF NOT EXISTS (SELECT 1 FROM sys.indexes
  WHERE [name] = N'UX_form_rim_ejecucion_anterior' AND [object_id] = OBJECT_ID(N'dbo.form_rim_ejecucion'))
  CREATE UNIQUE INDEX [UX_form_rim_ejecucion_anterior]
    ON [dbo].[form_rim_ejecucion] ([anterior_id])
    WHERE [anterior_id] IS NOT NULL;
IF NOT EXISTS (SELECT 1 FROM sys.indexes
  WHERE [name] = N'UX_form_rim_entregas_primera' AND [object_id] = OBJECT_ID(N'dbo.form_rim_entregas'))
  CREATE UNIQUE INDEX [UX_form_rim_entregas_primera]
    ON [dbo].[form_rim_entregas] ([rim_uuid])
    WHERE [anterior_id] IS NULL;
IF NOT EXISTS (SELECT 1 FROM sys.indexes
  WHERE [name] = N'UX_form_rim_entregas_anterior' AND [object_id] = OBJECT_ID(N'dbo.form_rim_entregas'))
  CREATE UNIQUE INDEX [UX_form_rim_entregas_anterior]
    ON [dbo].[form_rim_entregas] ([anterior_id])
    WHERE [anterior_id] IS NOT NULL;

COMMIT TRANSACTION;
GO

-- Permisos mínimos. Si un login tiene otro nombre, cámbielo aquí.
SET NOCOUNT ON;
-- Login de la API de ServiceMET: no usa estas tablas; solo recibe el DENY.
DECLARE @loginApi sysname = N'ServiceMET';
-- Login con el que DataMET+ se conecta a SQL Server (DB_USER de su .env).
-- Vacío: se omiten sus permisos y la ficha del RIM avisará que falta este
-- script.
DECLARE @loginDataMetPlus sysname = N'';
DECLARE @sql nvarchar(max);
DECLARE @usuario sysname;
DECLARE @usuarioApi sysname;
DECLARE @usuarioPlus sysname;

-- DENY prevalece sobre los permisos que un usuario reciba por un rol de
-- DataMET (salvo db_owner): la ejecución y la entrega no se modifican ni se
-- borran.
SET @usuarioApi = (SELECT TOP (1) [name] FROM sys.database_principals WHERE [sid] = SUSER_SID(@loginApi));
IF @usuarioApi IS NULL
  PRINT CONCAT(N'El login ', @loginApi, N' no tiene usuario en esta base: no hay nada que restringirle.');
ELSE
BEGIN
  SET @sql = CONCAT(
    N'DENY UPDATE, DELETE ON OBJECT::[dbo].[form_rim_ejecucion] TO ', QUOTENAME(@usuarioApi), N';',
    N'DENY UPDATE, DELETE ON OBJECT::[dbo].[form_rim_entregas] TO ', QUOTENAME(@usuarioApi), N';');
  EXEC sys.sp_executesql @sql;
  PRINT CONCAT(N'UPDATE y DELETE denegados a ', @usuarioApi, N' (API de ServiceMET).');
END

IF NULLIF(LTRIM(RTRIM(@loginDataMetPlus)), N'') IS NULL
  PRINT N'AVISO: @loginDataMetPlus está vacío. Complételo con el DB_USER de DataMET+ y ejecute el script de nuevo.';
ELSE
BEGIN
  IF SUSER_ID(@loginDataMetPlus) IS NULL
  BEGIN
    DECLARE @mensajePlus nvarchar(400) = CONCAT(
      N'El login ', @loginDataMetPlus, N' no existe en el servidor. Las tablas quedaron ',
      N'creadas; corrija @loginDataMetPlus y ejecute el script de nuevo para dar los permisos.');
    THROW 51000, @mensajePlus, 1;
  END
  IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE [sid] = SUSER_SID(@loginDataMetPlus))
  BEGIN
    SET @sql = CONCAT(N'CREATE USER ', QUOTENAME(@loginDataMetPlus), N' FOR LOGIN ', QUOTENAME(@loginDataMetPlus), N';');
    EXEC sys.sp_executesql @sql;
  END
  SET @usuarioPlus = (SELECT TOP (1) [name] FROM sys.database_principals WHERE [sid] = SUSER_SID(@loginDataMetPlus));

  SET @sql = CONCAT(
    N'GRANT SELECT, INSERT ON OBJECT::[dbo].[form_rim_ejecucion] TO ', QUOTENAME(@usuarioPlus), N';',
    N'GRANT SELECT, INSERT ON OBJECT::[dbo].[form_rim_entregas] TO ', QUOTENAME(@usuarioPlus), N';',
    N'DENY UPDATE, DELETE ON OBJECT::[dbo].[form_rim_ejecucion] TO ', QUOTENAME(@usuarioPlus), N';',
    N'DENY UPDATE, DELETE ON OBJECT::[dbo].[form_rim_entregas] TO ', QUOTENAME(@usuarioPlus), N';');
  EXEC sys.sp_executesql @sql;
  PRINT CONCAT(N'Permisos otorgados a ', @usuarioPlus, N' (DataMET+).');
END

-- Verificación con los permisos efectivos de cada usuario (incluidos sus
-- roles): DataMET+ lee e inserta; nadie actualiza ni elimina. Si actualizar o
-- eliminar figuran en 1, el usuario es db_owner de DataMET y el DENY no lo
-- alcanza: quítele ese rol.
DECLARE @tablas nvarchar(200) = N'(N''form_rim_ejecucion''), (N''form_rim_entregas'')';
DECLARE @modificables int;
DECLARE @usuarios TABLE ([nombre] sysname NOT NULL);
INSERT INTO @usuarios ([nombre]) SELECT @usuarioApi WHERE @usuarioApi IS NOT NULL;
INSERT INTO @usuarios ([nombre]) SELECT @usuarioPlus WHERE @usuarioPlus IS NOT NULL;

DECLARE usuarios CURSOR LOCAL FAST_FORWARD FOR SELECT [nombre] FROM @usuarios;
OPEN usuarios;
FETCH NEXT FROM usuarios INTO @usuario;
WHILE @@FETCH_STATUS = 0
BEGIN
  SET @sql = CONCAT(N'EXECUTE AS USER = ', QUOTENAME(@usuario, ''''), N';
SELECT USER_NAME() AS [usuario], t.[tabla],
    HAS_PERMS_BY_NAME(N''dbo.'' + t.[tabla], N''OBJECT'', N''SELECT'') AS [puede_leer],
    HAS_PERMS_BY_NAME(N''dbo.'' + t.[tabla], N''OBJECT'', N''INSERT'') AS [puede_insertar],
    HAS_PERMS_BY_NAME(N''dbo.'' + t.[tabla], N''OBJECT'', N''UPDATE'') AS [puede_actualizar],
    HAS_PERMS_BY_NAME(N''dbo.'' + t.[tabla], N''OBJECT'', N''DELETE'') AS [puede_eliminar]
FROM (VALUES ', @tablas, N') AS t([tabla]);
SELECT @n = COUNT(*) FROM (VALUES ', @tablas, N') AS t([tabla])
WHERE HAS_PERMS_BY_NAME(N''dbo.'' + t.[tabla], N''OBJECT'', N''UPDATE'') = 1
   OR HAS_PERMS_BY_NAME(N''dbo.'' + t.[tabla], N''OBJECT'', N''DELETE'') = 1;
REVERT;');
  EXEC sys.sp_executesql @sql, N'@n int OUTPUT', @n = @modificables OUTPUT;
  IF @modificables > 0
    PRINT CONCAT(N'AVISO: ', @usuario, N' todavía puede modificar o borrar la ejecución o la entrega ',
      N'(es db_owner de la base). Quítele ese rol: estos registros no deben poder modificarse.');
  FETCH NEXT FROM usuarios INTO @usuario;
END
CLOSE usuarios;
DEALLOCATE usuarios;
GO
