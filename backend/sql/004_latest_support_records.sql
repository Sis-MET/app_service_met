USE [DataMET_prueba];
GO

SET NOCOUNT ON;

-- Resumen general de servicios.
SELECT TOP (10)
  N'DATA_SERVICIOS_DATOS' AS [tabla_origen],
  datos.*
FROM [dbo].[DATA_SERVICIOS_DATOS] AS datos
ORDER BY datos.[n] DESC;

-- Diagnóstico.
SELECT TOP (10)
  N'DATA_SERVICIOS_DATOS_DIG' AS [tabla_origen],
  datos.*
FROM [dbo].[DATA_SERVICIOS_DATOS_DIG] AS datos
ORDER BY datos.[n] DESC;

-- Ajuste de verificaciones.
SELECT TOP (10)
  N'DATA_SERVICIOS_DATOS_IBM' AS [tabla_origen],
  datos.*
FROM [dbo].[DATA_SERVICIOS_DATOS_IBM] AS datos
ORDER BY datos.[n] DESC;

-- Instalación.
SELECT TOP (10)
  N'DATA_SERVICIOS_DATOS_INT' AS [tabla_origen],
  datos.*
FROM [dbo].[DATA_SERVICIOS_DATOS_INT] AS datos
ORDER BY datos.[n] DESC;

-- Mantenimiento correctivo.
SELECT TOP (10)
  N'DATA_SERVICIOS_DATOS_MCR' AS [tabla_origen],
  datos.*
FROM [dbo].[DATA_SERVICIOS_DATOS_MCR] AS datos
ORDER BY datos.[n] DESC;

-- Mantenimiento preventivo avanzado.
SELECT TOP (10)
  N'DATA_SERVICIOS_DATOS_MPA_STAC' AS [tabla_origen],
  datos.*
FROM [dbo].[DATA_SERVICIOS_DATOS_MPA_STAC] AS datos
ORDER BY datos.[n] DESC;

-- Mantenimiento preventivo regular.
SELECT TOP (10)
  N'DATA_SERVICIOS_DATOS_MPR_STIL' AS [tabla_origen],
  datos.*
FROM [dbo].[DATA_SERVICIOS_DATOS_MPR_STIL] AS datos
ORDER BY datos.[n] DESC;

-- Relevamiento de datos.
SELECT TOP (10)
  N'DATA_SERVICIOS_DATOS_RVD' AS [tabla_origen],
  datos.*
FROM [dbo].[DATA_SERVICIOS_DATOS_RVD] AS datos
ORDER BY datos.[n] DESC;

-- Verificaciones internas.
SELECT TOP (10)
  N'DATA_SERVICIOS_DATOS_VFI' AS [tabla_origen],
  datos.*
FROM [dbo].[DATA_SERVICIOS_DATOS_VFI] AS datos
ORDER BY datos.[n] DESC;
GO
