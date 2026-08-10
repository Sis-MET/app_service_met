USE [DataMET_prueba];
GO

IF USER_ID(N'ServiceMET') IS NULL
    THROW 51000, 'El usuario ServiceMET no existe en DataMET_prueba.', 1;
GO

GRANT SELECT, INSERT
    ON OBJECT::[dbo].[DATA_SERVICIOS_DATOS_CALIBRACION]
    TO [ServiceMET];

GRANT SELECT, INSERT
    ON OBJECT::[dbo].[DATA_SERVICIOS_DATOS]
    TO [ServiceMET];
GO

SELECT
    permission_name,
    state_desc,
    OBJECT_SCHEMA_NAME(major_id) AS schema_name,
    OBJECT_NAME(major_id) AS object_name
FROM sys.database_permissions
WHERE grantee_principal_id = USER_ID(N'ServiceMET')
  AND major_id IN (
      OBJECT_ID(N'dbo.DATA_SERVICIOS_DATOS_CALIBRACION'),
      OBJECT_ID(N'dbo.DATA_SERVICIOS_DATOS')
  )
ORDER BY object_name, permission_name;
GO
