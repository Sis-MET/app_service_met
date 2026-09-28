# Reporte de incidencias y registro de fallas del sistema

Cierra 7.11.3 e): el LIMS debe registrar las fallas del sistema y las acciones
inmediatas y correctivas que se tomaron. Conecta con 7.10 (trabajo no
conforme), cuando la falla pudo afectar resultados, y con 8.7 (acciones
correctivas), cuando la causa es sistemática.

## Contenido

1. Qué se considera incidencia
2. Arquitectura propuesta
3. Datos de una incidencia
4. Captura automática
5. Reporte manual
6. Sincronización con el servidor
7. Seguimiento y cierre
8. Respaldo en papel
9. Evidencia para el evaluador

---

## 1. Qué se considera incidencia

- Cierres inesperados y excepciones no controladas.
- Fallas al guardar, finalizar, subir, respaldar, importar o migrar la base.
- Datos que aparecen perdidos, duplicados o alterados.
- Cálculos o resultados sospechosos.
- Fallas del OCR del indicador que llevaron a un valor incorrecto.
- Problemas de acceso: no poder iniciar sesión, sesión de otro usuario.
- Fallas del servidor o de la red que impidieron trabajar.

No son incidencias las validaciones normales, como "el campo X no admite
decimales": son la app funcionando bien.

## 2. Arquitectura propuesta

```
Error no controlado ─┐
Falla en punto crítico ─┼─► IncidenciaService.registrar(...) ─► incidencias.db (local, propia)
Reporte del técnico ─┘                                             │  cola offline
                                                                   ▼
                                           POST /api/incidencias (JWT, solo INSERT)
                                                                   ▼
                                           DataMET: SERVICEMET_INCIDENCIAS
                                                                   ▼
                                     Seguimiento de Sistemas y Calidad (análisis, acción, cierre)
```

- **Base propia (`incidencias.db`)**, separada de `calibracion.db` y de las de
  soporte: si la base principal es la que falla, la incidencia igual se puede
  registrar.
- **Un solo servicio** (`lib/services/incidencia_service.dart`) como punto de
  entrada. Nunca debe lanzar excepciones: si registrar la incidencia falla, se
  degrada a `debugPrint` sin romper el flujo del técnico.
- El historial de incidencias **solo se agrega**, igual que la auditoría.

## 3. Datos de una incidencia

```sql
CREATE TABLE IF NOT EXISTS incidencias (
  id                 INTEGER PRIMARY KEY AUTOINCREMENT,
  uuid               TEXT NOT NULL UNIQUE,   -- idempotencia al sincronizar
  fecha_hora         TEXT NOT NULL,          -- ISO-8601 con desfase horario
  origen             TEXT NOT NULL,          -- AUTOMATICA | MANUAL
  usuario            TEXT DEFAULT '',        -- vacío si ocurrió antes del login
  app_version        TEXT NOT NULL,
  dispositivo        TEXT DEFAULT '',        -- modelo y versión de Android
  modulo             TEXT DEFAULT '',        -- CAL.BL, MPR.BL, subida, respaldo, login…
  pantalla           TEXT DEFAULT '',
  seca               TEXT DEFAULT '',        -- servicio afectado, si aplica
  cod_metrica        TEXT DEFAULT '',
  descripcion        TEXT NOT NULL,          -- del técnico, o mensaje del error
  detalle_tecnico    TEXT DEFAULT '',        -- tipo de excepción y stack recortado, sin credenciales
  afecta_datos       TEXT DEFAULT 'NO_SABE', -- SI | NO | NO_SABE
  accion_inmediata   TEXT DEFAULT '',        -- qué hizo el técnico en el momento
  severidad          TEXT DEFAULT 'MEDIA',   -- BAJA | MEDIA | ALTA
  adjuntos           TEXT DEFAULT '',        -- rutas de capturas o fotos
  ocurrencias        INTEGER DEFAULT 1,      -- repeticiones agrupadas
  sincronizado       INTEGER DEFAULT 0,
  sincronizado_en    TEXT DEFAULT ''
);
```

Privacidad (4.2): el `detalle_tecnico` nunca incluye contraseñas, tokens, el
contenido de las peticiones HTTP ni datos personales de clientes. Filtra
cabeceras `Authorization` y campos `password`/`pass` antes de guardar.

## 4. Captura automática

En `lib/main.dart`, antes de `runApp`:

- `FlutterError.onError`: errores del framework; conservar también el
  comportamiento por defecto (`FlutterError.presentError`) en modo debug.
- `PlatformDispatcher.instance.onError`: errores asíncronos no capturados;
  devolver `true` tras registrarlos.
- Agrupar repeticiones del mismo error (tipo + primera línea propia del stack)
  dentro de una ventana, por ejemplo 10 minutos, incrementando `ocurrencias`,
  para no inundar la base.

Además, en los **puntos críticos**, registrar explícitamente con módulo y
servicio afectado (hoy la mayoría termina solo en `debugPrint`):

- guardado y finalización de servicios (calibración y soporte);
- subida (`calibration_upload_api_service.dart`, `support_upload_api_service.dart`)
  cuando falle por causas distintas de la validación de datos;
- migraciones y aperturas de base (`app_database.dart`, helpers de soporte, `precarga_bd.dart`);
- respaldo, importación y restauración (`respaldo.dart`, `database_import_service.dart`);
- descarga de precarga (`descarga_de_datos.dart`).

Cuando una falla crítica interrumpe al técnico, el diálogo de error ofrece
"Reportar", que abre el formulario manual precargado con los datos
automáticos.

## 5. Reporte manual

Reemplaza `_showComingSoon('Soporte técnico')` en
`lib/home/screens/configuracion_screen.dart` por una pantalla
"Soporte técnico" con:

- **Reportar incidencia**: formulario con módulo (lista), servicio afectado
  (SECA o código, opcional, con sugerencias de los servicios recientes),
  descripción, "¿Afectó datos o resultados?" (Sí / No / No sé), "¿Qué hiciste
  en el momento?", severidad y adjuntar captura o foto.
- **Mis incidencias**: lista con estado de sincronización y, si el servidor lo
  informa, estado de seguimiento.
- **Contacto** del administrador del sistema.

Diseño: pocos campos obligatorios (descripción y "¿afectó datos?"). El
técnico está en planta; si reportar es pesado, no reportará.

## 6. Sincronización con el servidor

- Endpoint `POST /api/incidencias` en `backend/src/app.js`, con
  `authMiddleware`. El servidor fija el `usuario` desde el JWT y agrega su
  propia fecha de recepción. Acepta lotes y es idempotente por `uuid`.
- Tabla nueva en DataMET mediante el siguiente script numerado de
  `backend/sql/` (hoy el último es `011`), siguiendo la convención: validar la
  estructura, operar en transacción y conceder solo `SELECT, INSERT` al usuario
  `ServiceMET`.
- La app envía las pendientes al iniciar sesión, al subir servicios y desde
  "Mis incidencias". Sin conexión quedan en cola; nunca se pierden por falta de
  red.
- Pruebas en `backend/test/` (validación, idempotencia, rechazo sin token) y en
  `test/services/` (agrupación, filtrado de datos sensibles, cola offline).

## 7. Seguimiento y cierre

La app **captura**; el seguimiento lo hacen Sistemas y Calidad según el
procedimiento del laboratorio, ya sea en DataMET, en un tablero o en el sistema
de gestión. Cada incidencia debe llegar a:

| Campo de seguimiento | Contenido |
|---|---|
| Estado | ABIERTA → EN ANÁLISIS → EN CORRECCIÓN → CERRADA |
| Análisis de causa | Por qué ocurrió |
| Evaluación de impacto | ¿Afectó resultados emitidos? Si sí → trabajo no conforme (7.10) |
| Acción correctiva | Qué se cambió: versión que la corrige y commit |
| Verificación de eficacia | Cómo se comprobó que no se repite |
| Responsable y fecha de cierre | Quién cerró y cuándo |

Vincula incidencias y versiones: en el CHANGELOG, "Corrige INC-0007", y en el
registro de validación de esa versión, la prueba que lo demuestra.

## 8. Respaldo en papel

Si la app no abre o el teléfono no está disponible, el técnico usa el formulario
controlado del laboratorio `[PENDIENTE: código asignado por Calidad]` con los
mismos campos del apartado 3. Luego se transcribe al sistema indicando
"transcrito de formulario en papel", y el papel se conserva como registro
original.

## 9. Evidencia para el evaluador

- Listado de incidencias de un período, con estado y acciones.
- Una incidencia de ejemplo trazada de principio a fin: reporte → análisis →
  versión que la corrige → validación → cierre.
- El procedimiento del laboratorio que describe este flujo.
- La sección del manual de uso que enseña a reportar.
