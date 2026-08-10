# ServiceMET Backend

API interna para validar y subir servicios de calibración desde Flutter hacia
`DataMET_prueba` sin usar CSV. No recibe fotografías ni archivos ZIP.

## Configuración

1. Instalar Node.js 18 o superior en el servidor principal.
2. Copiar `.env.example` como `.env` y completar las credenciales SQL y un
   `JWT_SECRET` aleatorio de al menos 32 caracteres.
3. Ejecutar `pnpm install --frozen-lockfile` dentro de `backend/`.
4. Ejecutar `pnpm test` y luego `pnpm start`.

La API no requiere crear índices, restricciones ni otros objetos en
`DataMET_prueba`. El archivo `sql/001_calibration_data_audit.sql` es únicamente
de consulta y permite conocer los duplicados históricos sin modificar datos.

En producción, publicar la API detrás de HTTPS (IIS, Nginx u otro proxy
inverso). La contraseña del usuario y el JWT no deben viajar por HTTP fuera de
un entorno de prueba controlado.

## Endpoints

- `GET /health`: verifica API y SQL Server.
- `POST /api/auth/login`: valida `data_users` y emite un JWT temporal.
- `POST /api/calibracion/validar`: valida el lote sin insertar.
- `POST /api/calibracion/subir`: vuelve a validar y usa una transacción SQL.

Los endpoints de calibración requieren `Authorization: Bearer <token>`. La
subida acepta `mode: "all"` o `mode: "valid_only"`. En ambos casos, todos los
registros efectivamente elegidos se insertan o se revierten juntos.

## Asignación de identificadores

Dentro de una transacción serializable, la API obtiene el máximo `n`, asigna
correlativos consecutivos y genera `codigo_registro` como
`SECA-COD_METRICA`. Los duplicados históricos permanecen intactos. Antes de
insertar, la API impide repetir códigos dentro del lote o agregar un código que
ya exista en DataMET, sin exigir cambios en el esquema de la base.
