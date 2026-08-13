/*
  Elimina los últimos cuatro registros de una carga de calibración y sus
  correspondientes filas en dbo.DATA_SERVICIOS_DATOS.

  IMPORTANTE:
    1. Complete @Seca con la SECA exacta del servicio que desea repetir.
    2. Ejecute primero con @Confirmar = 0 y revise los dos resultados.
    3. Cambie @Confirmar a 1 únicamente si son exactamente los registros
       correctos.
    4. Ejecute con una cuenta administradora; ServiceMET no tiene DELETE.

  El script no elimina balanzas ni catálogos. Solo elimina el detalle del
  servicio y su resumen general.
*/

USE [DataMET_prueba];
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @Seca nvarchar(100) = N'REEMPLAZAR_POR_LA_SECA';
DECLARE @Confirmar bit = 0;

IF @Seca = N'REEMPLAZAR_POR_LA_SECA' OR LTRIM(RTRIM(@Seca)) = N''
    THROW 51000, 'Debe indicar la SECA exacta antes de ejecutar el script.', 1;

IF OBJECT_ID(N'dbo.DATA_SERVICIOS_DATOS_CALIBRACION', N'U') IS NULL
    THROW 51001, 'No existe dbo.DATA_SERVICIOS_DATOS_CALIBRACION.', 1;

IF OBJECT_ID(N'dbo.DATA_SERVICIOS_DATOS', N'U') IS NULL
    THROW 51002, 'No existe dbo.DATA_SERVICIOS_DATOS.', 1;

DROP TABLE IF EXISTS #CalibracionObjetivo;
DROP TABLE IF EXISTS #ResumenObjetivo;

SELECT TOP (4)
    detalle.[n],
    detalle.[codigo_registro],
    detalle.[seca],
    detalle.[cod_metrica],
    detalle.[fecha_servicio],
    detalle.[personal],
    detalle.[estado_servicio_bal],
    detalle.[estado_servicio_csv]
INTO #CalibracionObjetivo
FROM [dbo].[DATA_SERVICIOS_DATOS_CALIBRACION] AS detalle
WHERE detalle.[seca] = @Seca
ORDER BY detalle.[n] DESC;

IF (SELECT COUNT(*) FROM #CalibracionObjetivo) <> 4
    THROW 51003,
        'La SECA indicada no tiene al menos cuatro registros de calibración. No se eliminó nada.',
        1;

-- Los registros creados por la API tienen codigo_registro único dentro de
-- una misma carga. Esta protección evita emparejamientos ambiguos.
IF (SELECT COUNT(DISTINCT [codigo_registro]) FROM #CalibracionObjetivo) <> 4
    THROW 51004,
        'Los cuatro registros tienen codigo_registro duplicado. Revise manualmente; no se eliminó nada.',
        1;

SELECT
    resumen.[n],
    resumen.[codigo_registro],
    resumen.[fecha_reg],
    resumen.[reg_por],
    resumen.[nombre_csv],
    resumen.[estado_servicio],
    resumen.[tipo_servicio]
INTO #ResumenObjetivo
FROM #CalibracionObjetivo AS calibracion
CROSS APPLY (
    SELECT TOP (1)
        datos.[n],
        datos.[codigo_registro],
        datos.[fecha_reg],
        datos.[reg_por],
        datos.[nombre_csv],
        datos.[estado_servicio],
        datos.[tipo_servicio]
    FROM [dbo].[DATA_SERVICIOS_DATOS] AS datos
    WHERE datos.[codigo_registro] = calibracion.[codigo_registro]
      AND (
          datos.[tipo_servicio] = N'CAL.BL'
          OR datos.[tipo_servicio] IS NULL
      )
    ORDER BY datos.[n] DESC
) AS resumen;

IF (SELECT COUNT(*) FROM #ResumenObjetivo) <> 4
    THROW 51005,
        'No se encontraron los cuatro resúmenes correspondientes. No se eliminó nada.',
        1;

IF (SELECT COUNT(DISTINCT [n]) FROM #ResumenObjetivo) <> 4
    THROW 51006,
        'El emparejamiento de resúmenes no es único. No se eliminó nada.',
        1;

-- Vista previa obligatoria.
SELECT
    N'CALIBRACION' AS [tabla],
    objetivo.*
FROM #CalibracionObjetivo AS objetivo
ORDER BY objetivo.[n] DESC;

SELECT
    N'RESUMEN_GENERAL' AS [tabla],
    objetivo.*
FROM #ResumenObjetivo AS objetivo
ORDER BY objetivo.[n] DESC;

IF @Confirmar = 0
BEGIN
    PRINT N'VISTA PREVIA: no se eliminó ningún registro.';
    PRINT N'Si los registros son correctos, cambie @Confirmar a 1 y vuelva a ejecutar todo el script.';
    RETURN;
END;

BEGIN TRY
    BEGIN TRANSACTION;

    DELETE resumen
    FROM [dbo].[DATA_SERVICIOS_DATOS] AS resumen
    INNER JOIN #ResumenObjetivo AS objetivo
        ON objetivo.[n] = resumen.[n];

    IF @@ROWCOUNT <> 4
        THROW 51007,
            'No se eliminaron exactamente cuatro resúmenes. Se revertirá la operación.',
            1;

    DELETE detalle
    FROM [dbo].[DATA_SERVICIOS_DATOS_CALIBRACION] AS detalle
    INNER JOIN #CalibracionObjetivo AS objetivo
        ON objetivo.[n] = detalle.[n];

    IF @@ROWCOUNT <> 4
        THROW 51008,
            'No se eliminaron exactamente cuatro detalles. Se revertirá la operación.',
            1;

    COMMIT TRANSACTION;

    SELECT
        N'ELIMINACIÓN COMPLETADA' AS [resultado],
        @Seca AS [seca],
        4 AS [detalles_eliminados],
        4 AS [resumenes_eliminados];
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
