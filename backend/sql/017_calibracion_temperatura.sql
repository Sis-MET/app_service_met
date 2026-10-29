/*
  Calibración de temperatura (muflas, hornos, estufas, incubadoras…), en
  DataMET: la misma base de calibración del backend (para las pruebas,
  DataMET_prueba: cambie el USE de abajo).

  Cada calibración que sube la app es un equipo dentro de una SECA. Se
  guarda completa, en una sola transacción de la API, en seis tablas:

    dbo.DATA_SERVICIOS_DATOS_CAL_TE               cabecera: SECA, cliente,
                                                  planta, equipo (rango,
                                                  resolución), ambiente
                                                  inicial y final, horas,
                                                  técnico, versión de la app
    dbo.DATA_SERVICIOS_DATOS_CAL_TE_PATRONES      patrones y termohigrómetro
                                                  con su certificado
    dbo.DATA_SERVICIOS_DATOS_CAL_TE_CANALES       el indicador del equipo (se
                                                  lee con la cámara o a mano)
                                                  y los sensores del patrón
                                                  que van dentro del equipo
                                                  (graban en el software de
                                                  su registrador: aquí solo
                                                  quedan cuál es y dónde)
    dbo.DATA_SERVICIOS_DATOS_CAL_TE_PUNTOS        cada temperatura medida:
                                                  nominal, lapso, intervalo,
                                                  estado y horas
    dbo.DATA_SERVICIOS_DATOS_CAL_TE_LECTURAS      la observación original de
                                                  cada canal en cada hora
                                                  programada: hora del
                                                  teléfono, valor vigente y
                                                  valor original, lo que leyó
                                                  la cámara, origen, acuerdo
                                                  de la ráfaga, avisos, o el
                                                  motivo de la falta de
                                                  lectura
    dbo.DATA_SERVICIOS_DATOS_CAL_TE_CORRECCIONES  el historial de cada cambio
                                                  de una lectura (corrección,
                                                  exclusión, restitución) con
                                                  valor anterior, nuevo,
                                                  motivo, usuario y fecha
                                                  (NB/ISO/IEC 17025 7.5.2)

  Además, como los demás servicios, la API agrega una fila al resumen
  dbo.DATA_SERVICIOS_DATOS con tipo_servicio = 'CAL.TE' y la ubicación GPS.

  Las fechas de la app van en datetimeoffset: conservan la hora de la planta
  y el instante exacto. Lo que impone el servidor (usuario, nombre y fecha de
  registro) no viene de la app. Los resultados (promedios, error, etc.) no se
  guardan: se recalculan desde las lecturas.

  Solo se agrega: el login de la API recibe SELECT e INSERT en las seis
  tablas y un DENY de UPDATE y DELETE, para que ningún rol de DataMET se los
  dé. DataMET+ (@loginDataMetPlus, opcional) recibe solo SELECT y el mismo
  DENY.

  Puede ejecutarse de nuevo: solo crea lo que falte y vuelve a otorgar los
  permisos. Ejecutar con una cuenta administradora.

  Orden de despliegue:
    1. Este script (en DataMET_prueba para probar; luego en DataMET).
    2. El backend de ServiceMET (ruta POST /api/calibracion/temperatura) y su
       DataMET_prueba_esquema.md.
    3. La app con la calibración de temperatura.
  Si la app se adelanta, sus registros quedan en el teléfono como «por
  subir» y la API responde que falta este script.
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

IF OBJECT_ID(N'dbo.DATA_SERVICIOS_DATOS', N'U') IS NULL
  THROW 51000, N'No existe dbo.DATA_SERVICIOS_DATOS: ¿es la base correcta? No se realizaron cambios.', 1;
IF COL_LENGTH(N'dbo.DATA_SERVICIOS_DATOS', N'tipo_servicio') IS NULL
  THROW 51000, N'dbo.DATA_SERVICIOS_DATOS no tiene tipo_servicio: ejecute primero 005_add_service_type_to_summary.sql.', 1;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRANSACTION;

IF OBJECT_ID(N'dbo.DATA_SERVICIOS_DATOS_CAL_TE', N'U') IS NULL
BEGIN
  CREATE TABLE [dbo].[DATA_SERVICIOS_DATOS_CAL_TE] (
    [n]                int IDENTITY(1,1)  NOT NULL,
    [uuid]             uniqueidentifier   NOT NULL,
    [codigo_registro]  nvarchar(100)      NOT NULL,  -- SECA-COD_METRICA
    [seca]             nvarchar(50)       NOT NULL,
    [session_id]       nvarchar(100)      NOT NULL,
    [cod_metrica]      nvarchar(50)       NOT NULL,
    [equipo_nuevo]     bit                NOT NULL
      CONSTRAINT [DF_CAL_TE_equipo_nuevo] DEFAULT (0),
    [codigo_cliente]   nvarchar(20)       NULL,
    [cliente]          nvarchar(255)      NULL,
    [razon_social]     nvarchar(255)      NULL,
    [cod_planta]       nvarchar(20)       NULL,
    [planta]           nvarchar(255)      NULL,
    [dep]              nvarchar(100)      NULL,
    [dir]              nvarchar(255)      NULL,
    [tipo_equipo]      nvarchar(60)       NOT NULL,  -- Mufla, Horno, Estufa…
    [instrumento]      nvarchar(150)      NULL,
    [marca]            nvarchar(100)      NULL,
    [modelo]           nvarchar(100)      NULL,
    [serie]            nvarchar(100)      NULL,
    [cod_interno]      nvarchar(100)      NULL,
    [ubicacion]        nvarchar(255)      NULL,  -- dentro de la planta
    [rango_min]        decimal(9,3)       NOT NULL,
    [rango_max]        decimal(9,3)       NOT NULL,
    [unidad]           nvarchar(5)        NOT NULL,  -- °C, °F
    [resolucion]       decimal(9,4)       NOT NULL,  -- del indicador del equipo
    [indicador]        nvarchar(30)       NULL,
    [temp_amb_inicio]  decimal(6,2)       NULL,
    [hr_inicio]        decimal(6,2)       NULL,
    [temp_amb_fin]     decimal(6,2)       NULL,
    [hr_fin]           decimal(6,2)       NULL,
    [fecha_servicio]   date               NOT NULL,
    [hora_inicio]      datetimeoffset(0)  NULL,
    [hora_fin]         datetimeoffset(0)  NULL,
    [finalizado_en]    datetimeoffset(0)  NULL,
    [personal]         nvarchar(150)      NOT NULL,  -- técnico de la sesión
    [observaciones]    nvarchar(2000)     NULL,
    -- Archivo o referencia del registro de los sensores en su software.
    [registro_sensores] nvarchar(255)     NULL,
    [app_version]      nvarchar(30)       NULL,
    -- Lo impone el servidor: usuario de la sesión, su nombre y la hora.
    [reg_usuario]      nvarchar(100)      NOT NULL,
    [reg_por]          nvarchar(50)       NOT NULL,
    [fecha_reg]        datetime2(0)       NOT NULL
      CONSTRAINT [DF_CAL_TE_fecha_reg] DEFAULT (SYSDATETIME()),
    CONSTRAINT [PK_CAL_TE] PRIMARY KEY CLUSTERED ([n]),
    CONSTRAINT [UQ_CAL_TE_uuid] UNIQUE ([uuid]),
    CONSTRAINT [UQ_CAL_TE_codigo_registro] UNIQUE ([codigo_registro]),
    CONSTRAINT [CK_CAL_TE_rango] CHECK ([rango_min] < [rango_max]),
    CONSTRAINT [CK_CAL_TE_resolucion] CHECK ([resolucion] > 0),
    CONSTRAINT [CK_CAL_TE_unidad] CHECK ([unidad] IN (N'°C', N'°F'))
  );
  PRINT N'Tabla dbo.DATA_SERVICIOS_DATOS_CAL_TE creada.';
END
ELSE
  PRINT N'La tabla dbo.DATA_SERVICIOS_DATOS_CAL_TE ya existe.';

IF OBJECT_ID(N'dbo.DATA_SERVICIOS_DATOS_CAL_TE_PATRONES', N'U') IS NULL
BEGIN
  CREATE TABLE [dbo].[DATA_SERVICIOS_DATOS_CAL_TE_PATRONES] (
    [servicio_uuid]    uniqueidentifier  NOT NULL,
    [n]                int               NOT NULL,
    [cod_instrumento]  nvarchar(50)      NOT NULL,
    [instrumento]      nvarchar(150)     NULL,
    [cert_fecha]       nvarchar(30)      NULL,
    [ente_calibrador]  nvarchar(150)     NULL,
    [estado]           nvarchar(50)      NULL,
    [uso]              nvarchar(20)      NOT NULL,  -- temperatura | ambiente
    CONSTRAINT [PK_CAL_TE_PATRONES] PRIMARY KEY CLUSTERED ([servicio_uuid], [n]),
    CONSTRAINT [FK_CAL_TE_PATRONES_servicio]
      FOREIGN KEY ([servicio_uuid]) REFERENCES [dbo].[DATA_SERVICIOS_DATOS_CAL_TE] ([uuid]),
    CONSTRAINT [CK_CAL_TE_PATRONES_uso] CHECK ([uso] IN (N'temperatura', N'ambiente'))
  );
  PRINT N'Tabla dbo.DATA_SERVICIOS_DATOS_CAL_TE_PATRONES creada.';
END

IF OBJECT_ID(N'dbo.DATA_SERVICIOS_DATOS_CAL_TE_CANALES', N'U') IS NULL
BEGIN
  CREATE TABLE [dbo].[DATA_SERVICIOS_DATOS_CAL_TE_CANALES] (
    [servicio_uuid]  uniqueidentifier  NOT NULL,
    [n_canal]        int               NOT NULL,
    [nombre]         nvarchar(60)      NOT NULL,
    [rol]            nvarchar(10)      NOT NULL,  -- patron | equipo
    [cod_patron]     nvarchar(50)      NULL,
    [posicion]       nvarchar(100)     NULL,      -- del sensor en el equipo
    [metodo]         nvarchar(10)      NOT NULL,  -- camara | manual | externo
    [decimales]      tinyint           NOT NULL,
    CONSTRAINT [PK_CAL_TE_CANALES] PRIMARY KEY CLUSTERED ([servicio_uuid], [n_canal]),
    CONSTRAINT [FK_CAL_TE_CANALES_servicio]
      FOREIGN KEY ([servicio_uuid]) REFERENCES [dbo].[DATA_SERVICIOS_DATOS_CAL_TE] ([uuid]),
    CONSTRAINT [CK_CAL_TE_CANALES_rol] CHECK ([rol] IN (N'patron', N'equipo')),
    CONSTRAINT [CK_CAL_TE_CANALES_metodo]
      CHECK ([metodo] IN (N'camara', N'manual', N'externo')),
    CONSTRAINT [CK_CAL_TE_CANALES_decimales] CHECK ([decimales] <= 4)
  );
  PRINT N'Tabla dbo.DATA_SERVICIOS_DATOS_CAL_TE_CANALES creada.';
END

IF OBJECT_ID(N'dbo.DATA_SERVICIOS_DATOS_CAL_TE_PUNTOS', N'U') IS NULL
BEGIN
  CREATE TABLE [dbo].[DATA_SERVICIOS_DATOS_CAL_TE_PUNTOS] (
    [servicio_uuid]         uniqueidentifier   NOT NULL,
    [n_punto]               int                NOT NULL,
    [temperatura_nominal]   decimal(9,3)       NOT NULL,
    [estabilizacion_min]    decimal(9,2)       NULL,
    [duracion_min]          decimal(9,2)       NOT NULL,
    [intervalo_s]           int                NOT NULL,
    [lecturas_programadas]  int                NOT NULL,
    [estado]                nvarchar(20)       NOT NULL,
    [inicio_medicion]       datetimeoffset(3)  NULL,  -- hora de la lectura 0
    [fin_medicion]          datetimeoffset(3)  NULL,
    [motivo_interrupcion]   nvarchar(500)      NULL,
    [observaciones]         nvarchar(1000)     NULL,
    CONSTRAINT [PK_CAL_TE_PUNTOS] PRIMARY KEY CLUSTERED ([servicio_uuid], [n_punto]),
    CONSTRAINT [FK_CAL_TE_PUNTOS_servicio]
      FOREIGN KEY ([servicio_uuid]) REFERENCES [dbo].[DATA_SERVICIOS_DATOS_CAL_TE] ([uuid]),
    CONSTRAINT [CK_CAL_TE_PUNTOS_estado]
      CHECK ([estado] IN (N'pendiente', N'en_curso', N'completo', N'interrumpido')),
    CONSTRAINT [CK_CAL_TE_PUNTOS_tiempos]
      CHECK ([duracion_min] > 0 AND [intervalo_s] >= 1 AND [lecturas_programadas] >= 1),
    CONSTRAINT [CK_CAL_TE_PUNTOS_motivo]
      CHECK ([estado] <> N'interrumpido' OR LEN(ISNULL([motivo_interrupcion], N'')) >= 5)
  );
  PRINT N'Tabla dbo.DATA_SERVICIOS_DATOS_CAL_TE_PUNTOS creada.';
END

IF OBJECT_ID(N'dbo.DATA_SERVICIOS_DATOS_CAL_TE_LECTURAS', N'U') IS NULL
BEGIN
  CREATE TABLE [dbo].[DATA_SERVICIOS_DATOS_CAL_TE_LECTURAS] (
    [servicio_uuid]        uniqueidentifier   NOT NULL,
    [n_punto]              int                NOT NULL,
    [n_lectura]            int                NOT NULL,  -- 0 al iniciar
    [n_canal]              int                NOT NULL,
    [tiempo_programado_s]  int                NOT NULL,
    [capturada_en]         datetimeoffset(3)  NOT NULL,  -- hora del teléfono
    [valor]                decimal(9,3)       NULL,      -- vigente
    [valor_original]       decimal(9,3)       NULL,      -- como se tomó
    [texto_leido]          nvarchar(60)       NULL,      -- lo que leyó la cámara
    [origen]               nvarchar(20)       NOT NULL,
    [coincidencia]         decimal(4,3)       NULL,      -- acuerdo de la ráfaga
    [cuadros]              smallint           NULL,
    [alerta]               nvarchar(100)      NULL,
    [estado]               nvarchar(20)       NOT NULL,
    [motivo]               nvarchar(200)      NULL,
    CONSTRAINT [PK_CAL_TE_LECTURAS]
      PRIMARY KEY CLUSTERED ([servicio_uuid], [n_punto], [n_lectura], [n_canal]),
    CONSTRAINT [FK_CAL_TE_LECTURAS_punto]
      FOREIGN KEY ([servicio_uuid], [n_punto])
      REFERENCES [dbo].[DATA_SERVICIOS_DATOS_CAL_TE_PUNTOS] ([servicio_uuid], [n_punto]),
    CONSTRAINT [FK_CAL_TE_LECTURAS_canal]
      FOREIGN KEY ([servicio_uuid], [n_canal])
      REFERENCES [dbo].[DATA_SERVICIOS_DATOS_CAL_TE_CANALES] ([servicio_uuid], [n_canal]),
    CONSTRAINT [CK_CAL_TE_LECTURAS_origen]
      CHECK ([origen] IN (N'ocr_segmentos', N'ocr_texto', N'manual', N'sin_lectura')),
    CONSTRAINT [CK_CAL_TE_LECTURAS_estado]
      CHECK ([estado] IN (N'valida', N'sin_lectura', N'excluida')),
    CONSTRAINT [CK_CAL_TE_LECTURAS_sin_valor]
      CHECK ([estado] <> N'sin_lectura' OR [valor] IS NULL),
    CONSTRAINT [CK_CAL_TE_LECTURAS_coincidencia]
      CHECK ([coincidencia] IS NULL OR ([coincidencia] >= 0 AND [coincidencia] <= 1))
  );
  PRINT N'Tabla dbo.DATA_SERVICIOS_DATOS_CAL_TE_LECTURAS creada.';
END

IF OBJECT_ID(N'dbo.DATA_SERVICIOS_DATOS_CAL_TE_CORRECCIONES', N'U') IS NULL
BEGIN
  CREATE TABLE [dbo].[DATA_SERVICIOS_DATOS_CAL_TE_CORRECCIONES] (
    [id]              int IDENTITY(1,1)  NOT NULL,
    [servicio_uuid]   uniqueidentifier   NOT NULL,
    [n_punto]         int                NOT NULL,
    [n_lectura]       int                NOT NULL,
    [n_canal]         int                NOT NULL,
    [tipo]            nvarchar(20)       NOT NULL,
    [valor_anterior]  decimal(9,3)       NULL,
    [valor_nuevo]     decimal(9,3)       NULL,
    [motivo]          nvarchar(500)      NOT NULL,
    [usuario]         nvarchar(150)      NOT NULL,
    [fecha]           datetimeoffset(0)  NOT NULL,
    CONSTRAINT [PK_CAL_TE_CORRECCIONES] PRIMARY KEY CLUSTERED ([id]),
    CONSTRAINT [FK_CAL_TE_CORRECCIONES_lectura]
      FOREIGN KEY ([servicio_uuid], [n_punto], [n_lectura], [n_canal])
      REFERENCES [dbo].[DATA_SERVICIOS_DATOS_CAL_TE_LECTURAS]
        ([servicio_uuid], [n_punto], [n_lectura], [n_canal]),
    CONSTRAINT [CK_CAL_TE_CORRECCIONES_tipo]
      CHECK ([tipo] IN (N'correccion', N'exclusion', N'restitucion')),
    CONSTRAINT [CK_CAL_TE_CORRECCIONES_motivo] CHECK (LEN([motivo]) >= 5)
  );
  CREATE INDEX [IX_CAL_TE_CORRECCIONES_servicio]
    ON [dbo].[DATA_SERVICIOS_DATOS_CAL_TE_CORRECCIONES] ([servicio_uuid]);
  PRINT N'Tabla dbo.DATA_SERVICIOS_DATOS_CAL_TE_CORRECCIONES creada.';
END

COMMIT TRANSACTION;
GO

-- Permisos: solo leer y agregar.
SET NOCOUNT ON;

DECLARE @loginApi sysname = N'ServiceMET';
-- Opcional: el DB_USER de DataMET+, para consultar estas tablas. Vacío, no
-- se le da nada.
DECLARE @loginDataMetPlus sysname = N'';
DECLARE @sql nvarchar(max);
DECLARE @tablas TABLE ([nombre] sysname);
INSERT INTO @tablas ([nombre]) VALUES
  (N'DATA_SERVICIOS_DATOS_CAL_TE'),
  (N'DATA_SERVICIOS_DATOS_CAL_TE_PATRONES'),
  (N'DATA_SERVICIOS_DATOS_CAL_TE_CANALES'),
  (N'DATA_SERVICIOS_DATOS_CAL_TE_PUNTOS'),
  (N'DATA_SERVICIOS_DATOS_CAL_TE_LECTURAS'),
  (N'DATA_SERVICIOS_DATOS_CAL_TE_CORRECCIONES');

IF SUSER_ID(@loginApi) IS NULL
BEGIN
  DECLARE @mensaje nvarchar(400) = CONCAT(
    N'El login ', @loginApi, N' no existe en el servidor. Las tablas quedaron ',
    N'creadas; corrija @loginApi y ejecute el script de nuevo para dar los permisos.');
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
-- db_owner): una calibración subida no se modifica ni se borra.
SET @sql = N'';
SELECT @sql = @sql
  + N'GRANT SELECT, INSERT ON OBJECT::[dbo].' + QUOTENAME([nombre]) + N' TO ' + QUOTENAME(@usuarioApi) + N';'
  + N'DENY UPDATE, DELETE ON OBJECT::[dbo].' + QUOTENAME([nombre]) + N' TO ' + QUOTENAME(@usuarioApi) + N';'
FROM @tablas;
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
    SET @sql = N'';
    SELECT @sql = @sql
      + N'GRANT SELECT ON OBJECT::[dbo].' + QUOTENAME([nombre]) + N' TO ' + QUOTENAME(@usuarioPlus) + N';'
      + N'DENY UPDATE, DELETE ON OBJECT::[dbo].' + QUOTENAME([nombre]) + N' TO ' + QUOTENAME(@usuarioPlus) + N';'
    FROM @tablas;
    EXEC sys.sp_executesql @sql;
  END
END

-- Verificación con el propio usuario de la API: leer e insertar en 1;
-- actualizar y eliminar en 0. Si actualizar o eliminar figuran en 1, el
-- usuario es db_owner de DataMET: quítele ese rol.
SET @sql = CONCAT(N'EXECUTE AS USER = ', QUOTENAME(@usuarioApi, ''''), N';
SELECT
    permisos.[tabla],
    HAS_PERMS_BY_NAME(N''dbo.'' + permisos.[tabla], N''OBJECT'', N''SELECT'') AS [puede_leer],
    HAS_PERMS_BY_NAME(N''dbo.'' + permisos.[tabla], N''OBJECT'', N''INSERT'') AS [puede_insertar],
    HAS_PERMS_BY_NAME(N''dbo.'' + permisos.[tabla], N''OBJECT'', N''UPDATE'') AS [puede_actualizar],
    HAS_PERMS_BY_NAME(N''dbo.'' + permisos.[tabla], N''OBJECT'', N''DELETE'') AS [puede_eliminar]
FROM (VALUES
    (N''DATA_SERVICIOS_DATOS_CAL_TE''),
    (N''DATA_SERVICIOS_DATOS_CAL_TE_PATRONES''),
    (N''DATA_SERVICIOS_DATOS_CAL_TE_CANALES''),
    (N''DATA_SERVICIOS_DATOS_CAL_TE_PUNTOS''),
    (N''DATA_SERVICIOS_DATOS_CAL_TE_LECTURAS''),
    (N''DATA_SERVICIOS_DATOS_CAL_TE_CORRECCIONES''),
    (N''DATA_SERVICIOS_DATOS'')) AS permisos([tabla])
ORDER BY permisos.[tabla];
REVERT;');
EXEC sys.sp_executesql @sql;
GO
