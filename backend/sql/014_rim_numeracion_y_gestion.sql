/*
  Numeración única del RIM (RIM-AA-NNNN), anulaciones y RIM registrados desde
  el formulario web de DataMET+, en DataMET (la misma base del backend; para
  las pruebas, DataMET_prueba).

  Código del RIM:  RIM-{AA}-{NNNN}   p. ej. RIM-26-0042
    AA    gestión (año de emisión, dos dígitos)
    NNNN  número dentro de la gestión, único para todos los RIM: calibración,
          soporte, registro directo y DataMET+. Cuatro dígitos (cinco si
          alguna vez pasa de 9999).

  Talonarios: la app trabaja sin conexión, así que el número no puede pedirse
  al servidor en el momento de emitir. Cuando tiene conexión, la app recibe un
  talonario (un rango de números libres de la gestión, p. ej. 0041–0050) y los
  usa en orden aunque no tenga red. El servidor reparte los rangos sin
  repetirlos (dbo.rim_reservar_talonario, con un bloqueo exclusivo) y un índice
  único impide que dos RIM tengan el mismo número. DataMET+ registra en línea:
  pide un talonario de un solo número en la misma transacción del RIM.

    - dbo.rim_talonarios           rangos entregados: a quién, a qué
                                   instalación de la app y cuándo.
    - dbo.rim_talonarios_cierres   números de un talonario que ya no se usarán
                                   (fin de gestión, teléfono perdido o
                                   reinstalado), para explicar cada número que
                                   no tiene RIM.
    - dbo.form_rim_anulaciones     anulación de un RIM, con motivo, quién y
                                   cuándo. El RIM no se modifica: queda
                                   anulado porque tiene su fila aquí.
    - dbo.form_rim_fotos           fotos del RIM registrado desde DataMET+.
    - dbo.form_rim                 + origen, gestión, número, talonario e
                                   instalación; + NIT, correo del contacto y
                                   observaciones (formulario web).

  Los RIM ya registrados con el código anterior (RIM-{planta}-{AA}) conservan
  su código: es el que figura en el PDF firmado. Quedan con gestión y número
  vacíos y se identifican por su N.º (columna n).

  Solo se agrega: ningún login recibe UPDATE ni DELETE sobre estas tablas, y
  los dos reciben un DENY de UPDATE y DELETE para que ningún rol que tengan
  en DataMET se los dé.
    - API de ServiceMET (@loginApi): SELECT e INSERT en las tablas nuevas y
      EXECUTE en dbo.rim_reservar_talonario.
    - DataMET+ (@loginDataMetPlus): SELECT en todo; INSERT en form_rim,
      form_rim_fotos, form_rim_anulaciones y rim_talonarios_cierres; EXECUTE
      en dbo.rim_reservar_talonario.

  Requisitos: haber ejecutado 012_create_form_rim_y_form_bitrix.sql en la
  misma base. Ejecutar con una cuenta administradora, en cada base que use el
  backend (para DataMET_prueba, cambie el USE de abajo). Puede ejecutarse de
  nuevo: solo agrega lo que falte y vuelve a otorgar los permisos.

  Orden de despliegue:
    1. Este script (complete @loginDataMetPlus más abajo).
    2. El backend de ServiceMET (rutas /api/extras/rim/talonarios).
    3. DataMET+ (backend y frontend con Registros RIM).
    4. La versión de ServiceMET que numera el RIM con talonarios.
  La app no debe adelantarse: sin el paso 2 no recibe talonarios y no puede
  emitir RIM nuevos (los ya emitidos siguen pendientes y no se pierden).
*/

USE [DataMET];
GO

-- El índice único filtrado y el procedimiento exigen estas opciones; sqlcmd
-- usa QUOTED_IDENTIFIER OFF si no se le pasa -I. Rigen para todos los lotes
-- de esta conexión.
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
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRANSACTION;

IF OBJECT_ID(N'dbo.rim_talonarios', N'U') IS NULL
BEGIN
  CREATE TABLE [dbo].[rim_talonarios] (
    [id]           int IDENTITY(1,1) NOT NULL,
    -- Identificador que genera quien pide el talonario: si la respuesta se
    -- pierde y vuelve a pedirlo, recibe el mismo rango y no otro.
    [solicitud]    uniqueidentifier  NOT NULL,
    [gestion]      smallint          NOT NULL,
    [desde]        int               NOT NULL,
    [hasta]        int               NOT NULL,
    [origen]       nvarchar(20)      NOT NULL,  -- servicemet | datametplus
    -- Instalación de ServiceMET que lo recibió; solo ella puede usarlo.
    [instalacion]  uniqueidentifier  NULL,
    [dispositivo]  nvarchar(120)     NULL,
    [usuario]      nvarchar(100)     NOT NULL,
    [reg_por]      nvarchar(150)     NULL,
    [app_version]  nvarchar(30)      NULL,
    [fecha_reg]    datetime2(0)      NOT NULL
      CONSTRAINT [DF_rim_talonarios_fecha_reg] DEFAULT (SYSDATETIME()),
    CONSTRAINT [PK_rim_talonarios] PRIMARY KEY CLUSTERED ([id]),
    CONSTRAINT [UQ_rim_talonarios_solicitud] UNIQUE ([solicitud]),
    CONSTRAINT [UQ_rim_talonarios_desde] UNIQUE ([gestion], [desde]),
    CONSTRAINT [CK_rim_talonarios_rango]
      CHECK ([gestion] BETWEEN 2020 AND 2099 AND [desde] >= 1
             AND [hasta] >= [desde] AND [hasta] <= 99999),
    CONSTRAINT [CK_rim_talonarios_origen]
      CHECK ([origen] IN (N'servicemet', N'datametplus')),
    CONSTRAINT [CK_rim_talonarios_instalacion]
      CHECK ([origen] = N'datametplus' OR [instalacion] IS NOT NULL)
  );
  CREATE INDEX [IX_rim_talonarios_instalacion]
    ON [dbo].[rim_talonarios] ([instalacion], [gestion]);
  PRINT N'Tabla dbo.rim_talonarios creada.';
END
ELSE
  PRINT N'La tabla dbo.rim_talonarios ya existe.';

IF OBJECT_ID(N'dbo.rim_talonarios_cierres', N'U') IS NULL
BEGIN
  CREATE TABLE [dbo].[rim_talonarios_cierres] (
    [id]            int IDENTITY(1,1) NOT NULL,
    [talonario_id]  int               NOT NULL,
    -- Último número usado según quien cierra; NULL si no se usó ninguno o no
    -- se sabe (teléfono perdido). Los números sin RIM quedan «no utilizados».
    [ultimo_usado]  int               NULL,
    [motivo]        nvarchar(30)      NOT NULL,
    [detalle]       nvarchar(500)     NULL,
    [origen]        nvarchar(20)      NOT NULL,  -- servicemet | datametplus
    [usuario]       nvarchar(100)     NOT NULL,
    [reg_por]       nvarchar(150)     NULL,
    [fecha_reg]     datetime2(0)      NOT NULL
      CONSTRAINT [DF_rim_talonarios_cierres_fecha_reg] DEFAULT (SYSDATETIME()),
    CONSTRAINT [PK_rim_talonarios_cierres] PRIMARY KEY CLUSTERED ([id]),
    -- Un talonario se cierra una sola vez; el cierre no se edita.
    CONSTRAINT [UQ_rim_talonarios_cierres_talonario] UNIQUE ([talonario_id]),
    CONSTRAINT [FK_rim_talonarios_cierres_talonario]
      FOREIGN KEY ([talonario_id]) REFERENCES [dbo].[rim_talonarios] ([id]),
    CONSTRAINT [CK_rim_talonarios_cierres_motivo]
      CHECK ([motivo] IN (N'fin_gestion', N'telefono_perdido', N'reinstalacion', N'otro')),
    CONSTRAINT [CK_rim_talonarios_cierres_origen]
      CHECK ([origen] IN (N'servicemet', N'datametplus'))
  );
  PRINT N'Tabla dbo.rim_talonarios_cierres creada.';
END
ELSE
  PRINT N'La tabla dbo.rim_talonarios_cierres ya existe.';

-- Columnas nuevas de form_rim. Los RIM anteriores quedan con origen
-- servicemet y sin gestión ni número (código anterior).
IF COL_LENGTH(N'dbo.form_rim', N'origen') IS NULL
BEGIN
  ALTER TABLE [dbo].[form_rim] ADD [origen] nvarchar(20) NOT NULL
    CONSTRAINT [DF_form_rim_origen] DEFAULT (N'servicemet');
  PRINT N'dbo.form_rim tiene ahora la columna origen.';
END
IF COL_LENGTH(N'dbo.form_rim', N'gestion') IS NULL
  ALTER TABLE [dbo].[form_rim] ADD [gestion] smallint NULL;
IF COL_LENGTH(N'dbo.form_rim', N'numero') IS NULL
  ALTER TABLE [dbo].[form_rim] ADD [numero] int NULL;
IF COL_LENGTH(N'dbo.form_rim', N'talonario_id') IS NULL
  ALTER TABLE [dbo].[form_rim] ADD [talonario_id] int NULL;
IF COL_LENGTH(N'dbo.form_rim', N'instalacion') IS NULL
  ALTER TABLE [dbo].[form_rim] ADD [instalacion] uniqueidentifier NULL;
IF COL_LENGTH(N'dbo.form_rim', N'nit') IS NULL
  ALTER TABLE [dbo].[form_rim] ADD [nit] nvarchar(30) NULL;
IF COL_LENGTH(N'dbo.form_rim', N'contacto_correo') IS NULL
  ALTER TABLE [dbo].[form_rim] ADD [contacto_correo] nvarchar(150) NULL;
IF COL_LENGTH(N'dbo.form_rim', N'observaciones') IS NULL
  ALTER TABLE [dbo].[form_rim] ADD [observaciones] nvarchar(2000) NULL;

IF OBJECT_ID(N'dbo.form_rim_anulaciones', N'U') IS NULL
BEGIN
  CREATE TABLE [dbo].[form_rim_anulaciones] (
    [id]                  int IDENTITY(1,1) NOT NULL,
    [rim_uuid]            uniqueidentifier  NOT NULL,
    [motivo]              nvarchar(1000)    NOT NULL,
    -- Cuándo y quién lo anuló: en el teléfono (antes de subirlo) o en
    -- DataMET+.
    [anulado_en]          datetimeoffset(0) NOT NULL,
    [anulado_por]         nvarchar(100)     NOT NULL,
    [anulado_por_nombre]  nvarchar(150)     NULL,
    [origen]              nvarchar(20)      NOT NULL,  -- servicemet | datametplus
    -- Código del RIM que se emitió en su lugar, si lo hay.
    [reemplazado_por]     nvarchar(60)      NULL,
    -- Lo impone el servidor: cuándo se registró y con qué usuario.
    [fecha_reg]           datetime2(0)      NOT NULL
      CONSTRAINT [DF_form_rim_anulaciones_fecha_reg] DEFAULT (SYSDATETIME()),
    [reg_usuario]         nvarchar(100)     NOT NULL,
    CONSTRAINT [PK_form_rim_anulaciones] PRIMARY KEY CLUSTERED ([id]),
    -- Un RIM se anula una sola vez; la anulación no se edita ni se borra.
    CONSTRAINT [UQ_form_rim_anulaciones_rim] UNIQUE ([rim_uuid]),
    CONSTRAINT [FK_form_rim_anulaciones_rim]
      FOREIGN KEY ([rim_uuid]) REFERENCES [dbo].[form_rim] ([uuid]),
    CONSTRAINT [CK_form_rim_anulaciones_origen]
      CHECK ([origen] IN (N'servicemet', N'datametplus'))
  );
  PRINT N'Tabla dbo.form_rim_anulaciones creada.';
END
ELSE
  PRINT N'La tabla dbo.form_rim_anulaciones ya existe.';

IF OBJECT_ID(N'dbo.form_rim_fotos', N'U') IS NULL
BEGIN
  CREATE TABLE [dbo].[form_rim_fotos] (
    [id]         int IDENTITY(1,1) NOT NULL,
    [rim_uuid]   uniqueidentifier  NOT NULL,
    [orden]      tinyint           NOT NULL,
    [nombre]     nvarchar(255)     NULL,
    [tipo]       nvarchar(50)      NOT NULL,  -- image/jpeg | image/png | image/webp
    [contenido]  varbinary(max)    NOT NULL,
    [fecha_reg]  datetime2(0)      NOT NULL
      CONSTRAINT [DF_form_rim_fotos_fecha_reg] DEFAULT (SYSDATETIME()),
    CONSTRAINT [PK_form_rim_fotos] PRIMARY KEY CLUSTERED ([id]),
    CONSTRAINT [UQ_form_rim_fotos_orden] UNIQUE ([rim_uuid], [orden]),
    CONSTRAINT [FK_form_rim_fotos_rim]
      FOREIGN KEY ([rim_uuid]) REFERENCES [dbo].[form_rim] ([uuid]),
    CONSTRAINT [CK_form_rim_fotos_orden] CHECK ([orden] BETWEEN 1 AND 5),
    CONSTRAINT [CK_form_rim_fotos_tipo]
      CHECK ([tipo] IN (N'image/jpeg', N'image/png', N'image/webp'))
  );
  PRINT N'Tabla dbo.form_rim_fotos creada.';
END
ELSE
  PRINT N'La tabla dbo.form_rim_fotos ya existe.';

COMMIT TRANSACTION;
GO

-- Restricciones e índices sobre las columnas nuevas, en otro lote: SQL Server
-- compila cada lote completo y no reconoce las columnas agregadas en el mismo.
SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRANSACTION;

IF OBJECT_ID(N'dbo.CK_form_rim_origen', N'C') IS NULL
  ALTER TABLE [dbo].[form_rim] ADD CONSTRAINT [CK_form_rim_origen]
    CHECK ([origen] IN (N'servicemet', N'datametplus'));

IF OBJECT_ID(N'dbo.CK_form_rim_numero', N'C') IS NULL
  ALTER TABLE [dbo].[form_rim] ADD CONSTRAINT [CK_form_rim_numero]
    CHECK (([gestion] IS NULL AND [numero] IS NULL AND [talonario_id] IS NULL)
        OR ([gestion] BETWEEN 2020 AND 2099 AND [numero] BETWEEN 1 AND 99999
            AND [talonario_id] IS NOT NULL));

IF OBJECT_ID(N'dbo.FK_form_rim_talonario', N'F') IS NULL
  ALTER TABLE [dbo].[form_rim] ADD CONSTRAINT [FK_form_rim_talonario]
    FOREIGN KEY ([talonario_id]) REFERENCES [dbo].[rim_talonarios] ([id]);

-- Último resguardo: dos RIM nunca comparten número en la gestión.
IF NOT EXISTS (
  SELECT 1 FROM sys.indexes
  WHERE [name] = N'UX_form_rim_numero' AND [object_id] = OBJECT_ID(N'dbo.form_rim')
)
  CREATE UNIQUE INDEX [UX_form_rim_numero]
    ON [dbo].[form_rim] ([gestion], [numero])
    WHERE [numero] IS NOT NULL;

-- Historial de DataMET+: del más reciente al más antiguo.
IF NOT EXISTS (
  SELECT 1 FROM sys.indexes
  WHERE [name] = N'IX_form_rim_emitido_en' AND [object_id] = OBJECT_ID(N'dbo.form_rim')
)
  CREATE INDEX [IX_form_rim_emitido_en] ON [dbo].[form_rim] ([emitido_en] DESC);

COMMIT TRANSACTION;
GO

-- Reserva un talonario de @cantidad números de la @gestion. Reenviar la misma
-- @solicitud devuelve el talonario ya reservado. El bloqueo exclusivo hace
-- que dos pedidos simultáneos reciban rangos consecutivos y nunca el mismo.
IF OBJECT_ID(N'dbo.rim_reservar_talonario', N'P') IS NULL
  EXEC (N'CREATE PROCEDURE [dbo].[rim_reservar_talonario] AS RETURN 0;');
GO

ALTER PROCEDURE [dbo].[rim_reservar_talonario]
  @solicitud    uniqueidentifier,
  @gestion      smallint,
  @cantidad     int,
  @origen       nvarchar(20),
  @usuario      nvarchar(100),
  @instalacion  uniqueidentifier = NULL,
  @dispositivo  nvarchar(120) = NULL,
  @reg_por      nvarchar(150) = NULL,
  @app_version  nvarchar(30) = NULL
AS
BEGIN
  SET NOCOUNT ON;
  SET XACT_ABORT ON;

  IF @solicitud IS NULL OR @gestion IS NULL OR @gestion NOT BETWEEN 2020 AND 2099
    THROW 51010, N'Talonario de RIM: solicitud o gestión inválida.', 1;
  IF @cantidad IS NULL OR @cantidad NOT BETWEEN 1 AND 100
    THROW 51010, N'Talonario de RIM: la cantidad debe estar entre 1 y 100.', 1;
  IF @origen NOT IN (N'servicemet', N'datametplus')
    OR (@origen = N'servicemet' AND @instalacion IS NULL)
    OR NULLIF(LTRIM(RTRIM(@usuario)), N'') IS NULL
    THROW 51010, N'Talonario de RIM: falta el origen, la instalación o el usuario.', 1;

  BEGIN TRANSACTION;

  DECLARE @bloqueo int;
  EXEC @bloqueo = sys.sp_getapplock
    @Resource = N'rim_talonarios',
    @LockMode = N'Exclusive',
    @LockOwner = N'Transaction',
    @LockTimeout = 15000;
  IF @bloqueo < 0
    THROW 51012, N'La numeración del RIM está ocupada; intente de nuevo.', 1;

  DECLARE @nuevo bit = 0;
  IF NOT EXISTS (SELECT 1 FROM [dbo].[rim_talonarios] WHERE [solicitud] = @solicitud)
  BEGIN
    DECLARE @desde int = 1 + ISNULL(
      (SELECT MAX([hasta]) FROM [dbo].[rim_talonarios] WHERE [gestion] = @gestion), 0);
    IF @desde + @cantidad - 1 > 99999
      THROW 51011, N'Se agotó la numeración del RIM de esta gestión.', 1;

    INSERT INTO [dbo].[rim_talonarios]
      ([solicitud], [gestion], [desde], [hasta], [origen], [instalacion],
       [dispositivo], [usuario], [reg_por], [app_version])
    VALUES
      (@solicitud, @gestion, @desde, @desde + @cantidad - 1, @origen, @instalacion,
       @dispositivo, @usuario, @reg_por, @app_version);
    SET @nuevo = 1;
  END

  SELECT [id], [solicitud], [gestion], [desde], [hasta], [origen], [instalacion],
         [usuario], [fecha_reg], @nuevo AS [nuevo]
  FROM [dbo].[rim_talonarios]
  WHERE [solicitud] = @solicitud;

  COMMIT TRANSACTION;
END
GO

-- Permisos mínimos. Si un login tiene otro nombre, cámbielo aquí.
SET NOCOUNT ON;
DECLARE @loginApi sysname = N'ServiceMET';
-- Login con el que DataMET+ se conecta a SQL Server (DB_USER de su .env).
-- Vacío: se omiten sus permisos y el módulo Registros RIM no podrá leer.
DECLARE @loginDataMetPlus sysname = N'';
DECLARE @sql nvarchar(max);
DECLARE @usuario sysname;
DECLARE @usuarioApi sysname;
DECLARE @usuarioPlus sysname;

IF SUSER_ID(@loginApi) IS NULL
BEGIN
  DECLARE @mensajeApi nvarchar(400) = CONCAT(
    N'El login ', @loginApi, N' no existe en el servidor. Las tablas quedaron ',
    N'creadas; corrija @loginApi y ejecute el script de nuevo para dar los permisos.');
  THROW 51000, @mensajeApi, 1;
END

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE [sid] = SUSER_SID(@loginApi))
BEGIN
  SET @sql = CONCAT(N'CREATE USER ', QUOTENAME(@loginApi), N' FOR LOGIN ', QUOTENAME(@loginApi), N';');
  EXEC sys.sp_executesql @sql;
END
SET @usuarioApi = (SELECT TOP (1) [name] FROM sys.database_principals WHERE [sid] = SUSER_SID(@loginApi));

-- DENY prevalece sobre los permisos que el usuario reciba por un rol de
-- DataMET (salvo db_owner): un RIM no se modifica ni se borra.
SET @sql = CONCAT(
  N'GRANT SELECT, INSERT ON OBJECT::[dbo].[rim_talonarios] TO ', QUOTENAME(@usuarioApi), N';',
  N'GRANT SELECT, INSERT ON OBJECT::[dbo].[rim_talonarios_cierres] TO ', QUOTENAME(@usuarioApi), N';',
  N'GRANT SELECT, INSERT ON OBJECT::[dbo].[form_rim_anulaciones] TO ', QUOTENAME(@usuarioApi), N';',
  N'GRANT EXECUTE ON OBJECT::[dbo].[rim_reservar_talonario] TO ', QUOTENAME(@usuarioApi), N';',
  N'DENY UPDATE, DELETE ON OBJECT::[dbo].[form_rim] TO ', QUOTENAME(@usuarioApi), N';',
  N'DENY UPDATE, DELETE ON OBJECT::[dbo].[form_rim_fotos] TO ', QUOTENAME(@usuarioApi), N';',
  N'DENY UPDATE, DELETE ON OBJECT::[dbo].[form_rim_anulaciones] TO ', QUOTENAME(@usuarioApi), N';',
  N'DENY UPDATE, DELETE ON OBJECT::[dbo].[rim_talonarios] TO ', QUOTENAME(@usuarioApi), N';',
  N'DENY UPDATE, DELETE ON OBJECT::[dbo].[rim_talonarios_cierres] TO ', QUOTENAME(@usuarioApi), N';');
EXEC sys.sp_executesql @sql;
PRINT CONCAT(N'Permisos otorgados a ', @usuarioApi, N' (API de ServiceMET).');

IF NULLIF(LTRIM(RTRIM(@loginDataMetPlus)), N'') IS NULL
  PRINT N'AVISO: @loginDataMetPlus está vacío. Complételo con el DB_USER de DataMET+ y ejecute el script de nuevo.';
ELSE
BEGIN
  IF SUSER_ID(@loginDataMetPlus) IS NULL
  BEGIN
    DECLARE @mensajePlus nvarchar(400) = CONCAT(
      N'El login ', @loginDataMetPlus, N' no existe en el servidor. Corrija ',
      N'@loginDataMetPlus y ejecute el script de nuevo.');
    THROW 51000, @mensajePlus, 1;
  END
  IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE [sid] = SUSER_SID(@loginDataMetPlus))
  BEGIN
    SET @sql = CONCAT(N'CREATE USER ', QUOTENAME(@loginDataMetPlus), N' FOR LOGIN ', QUOTENAME(@loginDataMetPlus), N';');
    EXEC sys.sp_executesql @sql;
  END
  SET @usuarioPlus = (SELECT TOP (1) [name] FROM sys.database_principals WHERE [sid] = SUSER_SID(@loginDataMetPlus));

  SET @sql = CONCAT(
    N'GRANT SELECT, INSERT ON OBJECT::[dbo].[form_rim] TO ', QUOTENAME(@usuarioPlus), N';',
    N'GRANT SELECT, INSERT ON OBJECT::[dbo].[form_rim_fotos] TO ', QUOTENAME(@usuarioPlus), N';',
    N'GRANT SELECT, INSERT ON OBJECT::[dbo].[form_rim_anulaciones] TO ', QUOTENAME(@usuarioPlus), N';',
    N'GRANT SELECT, INSERT ON OBJECT::[dbo].[rim_talonarios_cierres] TO ', QUOTENAME(@usuarioPlus), N';',
    N'GRANT SELECT ON OBJECT::[dbo].[rim_talonarios] TO ', QUOTENAME(@usuarioPlus), N';',
    N'GRANT EXECUTE ON OBJECT::[dbo].[rim_reservar_talonario] TO ', QUOTENAME(@usuarioPlus), N';',
    N'DENY UPDATE, DELETE ON OBJECT::[dbo].[form_rim] TO ', QUOTENAME(@usuarioPlus), N';',
    N'DENY UPDATE, DELETE ON OBJECT::[dbo].[form_rim_fotos] TO ', QUOTENAME(@usuarioPlus), N';',
    N'DENY UPDATE, DELETE ON OBJECT::[dbo].[form_rim_anulaciones] TO ', QUOTENAME(@usuarioPlus), N';',
    N'DENY UPDATE, DELETE ON OBJECT::[dbo].[rim_talonarios] TO ', QUOTENAME(@usuarioPlus), N';',
    N'DENY UPDATE, DELETE ON OBJECT::[dbo].[rim_talonarios_cierres] TO ', QUOTENAME(@usuarioPlus), N';');
  EXEC sys.sp_executesql @sql;
  PRINT CONCAT(N'Permisos otorgados a ', @usuarioPlus, N' (DataMET+).');
END

-- Verificación con los permisos efectivos de cada usuario (incluidos sus
-- roles): leer e insertar en 1 donde corresponde; actualizar y eliminar
-- siempre en 0. Si figuran en 1, el usuario es db_owner de DataMET y el DENY
-- no lo alcanza: quítele ese rol.
DECLARE @tablas nvarchar(400) = N'(N''form_rim''), (N''form_rim_fotos''), (N''form_rim_anulaciones''), (N''rim_talonarios''), (N''rim_talonarios_cierres'')';
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
    PRINT CONCAT(N'AVISO: ', @usuario, N' todavía puede modificar o borrar registros del RIM ',
      N'(es db_owner de la base). Quítele ese rol: los RIM no deben poder modificarse.');
  FETCH NEXT FROM usuarios INTO @usuario;
END
CLOSE usuarios;
DEALLOCATE usuarios;
GO
