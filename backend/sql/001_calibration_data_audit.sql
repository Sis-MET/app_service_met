/*
  Auditoría de solo lectura para DataMET_prueba.
  No crea índices, no actualiza y no elimina registros.
*/

SET NOCOUNT ON;

SELECT
  [codigo_registro],
  COUNT(*) AS [cantidad],
  MIN([n]) AS [n_minimo],
  MAX([n]) AS [n_maximo]
FROM [dbo].[DATA_SERVICIOS_DATOS_CALIBRACION]
WHERE [codigo_registro] IS NOT NULL
GROUP BY [codigo_registro]
HAVING COUNT(*) > 1
ORDER BY [cantidad] DESC, [codigo_registro];

SELECT
  [n],
  COUNT(*) AS [cantidad]
FROM [dbo].[DATA_SERVICIOS_DATOS_CALIBRACION]
GROUP BY [n]
HAVING COUNT(*) > 1
ORDER BY [cantidad] DESC, [n];
