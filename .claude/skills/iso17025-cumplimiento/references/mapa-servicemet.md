# Mapa de ServiceMET frente a la NB/ISO/IEC 17025

Dónde vive cada requisito en el código y la línea base de brechas. Las rutas son
relativas a la raíz del repositorio. Los números de línea son orientativos: busca
por el nombre de la función o clase.

## Contenido

1. Arquitectura relevante
2. Dónde mirar para cada requisito
3. Línea base (2026-09-28, v6.3.3+15, commit bf004af)

---

## 1. Arquitectura relevante

```
Técnico (Android, offline en planta)
  │  captura: lib/screens/calibracion/steps/*        (calibración, CAL.BL)
  │           lib/screens/soporte_new/modulos/*      (8 módulos de soporte)
  │  OCR del indicador: lib/screens/calibracion/widgets/indicator_reader_screen.dart
  │                     lib/screens/calibracion/utils/seven_segment_reader.dart
  ▼
SQLite local
  ├─ lib/database/app_database.dart     registros_calibracion, servicio_status,
  │                                     calibration_upload_status
  ├─ lib/database/precarga_bd.dart      catálogos offline (clientes, plantas,
  │                                     balanzas, equipamientos = patrones)
  ├─ lib/screens/soporte_new/database/database_helper_soporte.dart  (soporte)
  └─ lib/login/services/database_service.dart  usuarios locales (PBKDF2)
  │
  │  edición y eliminación: lib/home/screens/registro_editor_screen.dart
  │                         lib/home/screens/servicio_detalles_screen.dart
  │                         lib/home/services/local_service_record_repository.dart
  │  respaldo: lib/screens/respaldo/respaldo.dart
  │            lib/screens/respaldo/services/database_import_service.dart
  ▼  HTTPS con huella fijada: lib/core/network/service_met_http_client.dart
API Node (backend/src)
  ├─ app.js            login, /api/bootstrap, validar y subir calibración y soporte
  ├─ security.js       JWT HS256 con vencimiento, limitador de intentos de login
  ├─ calibration-service.js / support-service.js   transacción serializable,
  │                    sp_getapplock, código de registro, resumen general
  ├─ validation.js / schema.js     validación contra el esquema de DataMET
  └─ sql/0xx_*.sql     migraciones y permisos (numeradas, idempotentes, con transacción)
  ▼
SQL Server DataMET (DATA_SERVICIOS_DATOS_*, DATA_SERVICIOS_DATOS, data_users)
```

Otros puntos:

- Versión: `version:` en `pubspec.yaml`; se muestra en
  `lib/home/screens/configuracion_screen.dart` (`_loadAppInfo`, con `PackageInfo`).
- Esquema que acepta el servidor: `lib/database/calibration_server_schema.dart`
  (se genera con `tool/generate_calibration_schema.js`).
  `lib/database/calibration_data_normalizer.dart` rechaza columnas desconocidas;
  las columnas solo locales van en `_uploadExcludedFields`.
- Validación previa a guardar y subir: `lib/database/calibration_record_validator.dart`.
- Informes PDF: `lib/home/utils/pdf_generator.dart`. CSV y exportaciones:
  `lib/utils/service_exporter.dart`, `lib/home/utils/export_helper.dart`.
- Pruebas: `test/` (Flutter) y `backend/test/` (`node --test`).
- Formularios adicionales (no son tablas de DataMET; se llenan dentro de un
  servicio, desde el menu de tres puntos, y se revisan en Servicios):
  - RIM, recepcion de instrumentos de pesaje con firmas del cliente y del
    representante de Metrica:
    `lib/screens/rim/`. Local en `servicios_extras.db` > `form_rim`
    (`services/rim_store.dart`): solo insercion, sin edicion ni borrado;
    anulacion con usuario, fecha y motivo. Servidor: base `servicios_extras`
    (`backend/sql/012_create_servicios_extras.sql`, `backend/src/extras/`),
    solo `SELECT` e `INSERT`.
  - Oportunidades de Bitrix24: `lib/screens/oportunidades/`; copia en
    `servicios_extras.form_bitrix`.
- Calidad y normativa (pestaña Otros, `lib/home/tabs/otros_tab.dart`):
  `lib/screens/calidad/`, con el tablero de
  cumplimiento, el manual de uso y el historial de versiones, sus datos en
  `data/` y la exportación a PDF en `services/calidad_pdf.dart`.

## 2. Dónde mirar para cada requisito

| Requisito | Archivos |
|---|---|
| 7.5.1 identificación, técnico, fecha y hora | `app_database.dart` (`personal`, `fecha_servicio`, `hora_inicio`, `hora_fin`, `session_id`), `lib/models/service_session.dart`, `lib/providers/service_session_provider.dart`; en el servidor, `calibration-service.js` (fecha del servidor, usuario del JWT, `codigo_registro`) |
| 7.5.1 patrones y condiciones | `patron_weights_selector.dart` (`WeightCertificateStatus`, vigencia de 365 días), columnas `certificado1..7`, `temp`, `humedad`, `hri`, `ti`, `hri_fin` en `app_database.dart`, `condiciones_finales_step.dart` |
| 7.5.1 observaciones originales y OCR | `indicator_reader_screen.dart`, `indicator_frame.dart`, `foto_helper.dart`, columnas `*_foto` |
| 7.5.2 modificaciones | `registro_editor_screen.dart` (`_buildChanges`, `_guardar`), `local_service_record_repository.dart` (`update`) |
| 7.5.2 y 8.4 eliminación | `local_service_record_repository.dart` (`delete`), `servicio_detalles_screen.dart` (`_confirmarEliminarRegistro`), `respaldo.dart` (`_deleteFile`, `_deleteSelectedFiles`), `backend/sql/007_delete_last_calibration_upload.sql` |
| 7.5.2 sobrescritura silenciosa | usos de `ConflictAlgorithm.replace` (ejecuta el inventario) |
| 7.11.2 versión y validación | `pubspec.yaml`, `configuracion_screen.dart`, `test/`, `backend/test/`, historial de git |
| 7.11.3 a) acceso | `lib/login/**` (`auth_service.dart`, `password_verifier.dart`, `credential_storage.dart`, `biometric_service.dart`), `backend/src/security.js`, login en `backend/src/app.js` |
| 7.11.3 b) manipulación y pérdida | `service_met_http_client.dart` (huella TLS), `backend/sql/006_servicemet_api_permissions.sql`, `respaldo.dart` |
| 7.11.3 d) integridad | `calibration_data_normalizer.dart`, `calibration_record_validator.dart`, `upload_record_deduplicator.dart`, `backend/src/validation.js` |
| 7.11.3 e) fallas | `configuracion_screen.dart` (entrada "Soporte técnico"), bloques `catch` en toda la app, `lib/main.dart` (manejo global de errores) |
| 7.11.4 proveedores externos | `lib/main.dart` (`Firebase.initializeApp`), dependencias de `pubspec.yaml` |
| 7.11.5 manual | (no existe; ver brechas) |
| 7.11.6 cálculos y transferencias | `lib/providers/metrological_tests_provider.dart`, `soporte_metrologia_utils.dart`, `calibration_upload_api_service.dart`, endpoints `validar` y `subir`, `database_import_service.dart` |
| 8.4 respaldo, retención y disposición | `respaldo.dart`, `database_maintenance_service.dart`, rutas de fotos (`foto_helper.dart`, `foto_storage_dialog.dart`) |
| 4.2 confidencialidad | exportar y compartir (`share_plus`, `saf_storage.dart`), `debugPrint` con datos |

## 3. Línea base (2026-09-28, v6.3.3+15, commit bf004af)

Revisión inicial al crear la skill. **Confirma cada punto en el código actual
antes de citarlo**: pudo corregirse o moverse. Cuando se cierre una brecha,
actualiza esta sección y el requisito en
`lib/screens/calidad/data/requisitos_17025.dart`, que es la matriz que ve el
laboratorio.

### Fortalezas (ya aportan evidencia)

- **La API solo inserta**: el usuario SQL de ServiceMET tiene solo `SELECT` e
  `INSERT` (`backend/sql/006_servicemet_api_permissions.sql`). Los registros
  subidos no se pueden alterar desde la app. (7.11.3 b, 7.5.2)
- **El servidor impone** la fecha, el usuario autenticado,
  `estado_servicio_csv = ACTIVO` y `codigo_registro`; usa transacción
  serializable y `sp_getapplock`; impide duplicados de código. (7.5.1, 7.11.3 d)
- **Validar antes de subir**: los endpoints `/validar` se separan de `/subir`, y
  la app aplica las mismas reglas de esquema con `CalibrationRecordValidator`.
  (7.11.6)
- **TLS con huella SHA-256 fijada** en `service_met_http_client.dart`. (7.11.3 b)
- **Login del servidor** con JWT con vencimiento, límite de intentos y
  verificación de `estado = ACTIVO` y `acceso_app = 1`. (7.11.3 a, 6.2.6)
- **Login offline** con PBKDF2 (60 000 iteraciones) y almacenamiento seguro de
  credenciales. (7.11.3 a)
- **Vigencia de patrones** calculada y mostrada al seleccionarlos
  (`WeightCertificateStatus`). (7.5.1)
- **Versión visible** en Configuración. (7.11.2)
- **Pruebas automatizadas** amplias en `test/` y `backend/test/`. (7.11.2, 7.11.6)
- **Importación de base con vista previa** antes de aplicar
  (`database_import_service.dart`). (7.11.6)

### Brechas probables

| ID | Cláusula | Hallazgo | Dónde | Riesgo | Cierre |
|---|---|---|---|---|---|
| G1 | 7.5.2 | La edición local sobrescribe el valor sin guardar el anterior, ni quién, ni cuándo, ni el motivo. El editor ya calcula `changes` contra `_original`, así que el historial es fácil de añadir. | `LocalServiceRecordRepository.update`, `RegistroEditorScreen._guardar` | Alto | Software |
| G2 | 7.5.2, 8.4 | Borrado físico de registros locales desde la UI ("borra el registro de forma permanente"). | `LocalServiceRecordRepository.delete`, `_confirmarEliminarRegistro` | Alto | Software + procedimiento |
| G3 | 7.5.2, 8.4 | Script administrativo que borra registros ya subidos sin dejar copia ni registro de la eliminación. | `backend/sql/007_delete_last_calibration_upload.sql` | Alto | Ambos (archivar antes de borrar, registrar quién y por qué) |
| G4 | 7.5.2 | No se observó un bloqueo para editar registros ya subidos: la copia local puede divergir de DataMET. | `registro_editor_screen.dart`, `servicio_detalles_screen.dart` (verificar) | Medio | Software |
| G5 | 7.11.3 e | No hay registro de fallas ni reporte de incidencias: "Soporte técnico" muestra "próximamente" y los errores solo van a `debugPrint`. Sin manejo global de errores en `main.dart`. | `configuracion_screen.dart` (`_showComingSoon('Soporte técnico')`) | Alto | Ambos |
| G6 | 7.11.5 | **Parcialmente cerrada (2026-09-28)**: hay manual interactivo en la app, exportable en PDF. Falta que Calidad le asigne código y lo apruebe. | `lib/screens/calidad/data/manual_servicemet.dart` | Medio | Procedimiento |
| G7 | 7.11.2 | **Parcialmente cerrada (2026-09-28)**: el historial de versiones está en la app y una prueba lo sincroniza con `pubspec.yaml`. Faltan los registros de validación (VAL-…) y la autorización de cada liberación. | `lib/screens/calidad/data/historial_versiones.dart` | Medio | Ambos |
| G8 | 7.5.1, 7.11.2 | Los registros no guardan la versión de la app que los capturó. | `app_database.dart` | Medio | Software |
| G9 | 7.11.3 a | El login del servidor compara `[pass] = @password` contra `data_users`: indica contraseñas en texto plano en DataMET (tabla heredada). Verificar con el administrador de DataMET. | `backend/src/app.js` (login) | Alto si se confirma | Ambos |
| G10 | 8.4, 7.5.1 | Las fotos (evidencia de observaciones) no llegan al servidor: viven solo en el teléfono y dependen del respaldo manual. | README del backend, `foto_helper.dart` | Medio | Ambos |
| G11 | 7.5.1 | No se observó dónde se registra quién revisa o verifica los datos y resultados; puede estar en DataMET. | — (verificar) | Medio | Procedimiento o software |
| G12 | 7.11.4 | Firebase se inicializa en `main.dart`; confirmar si se usa. Si no se usa, retirarlo; si se usa, declararlo como proveedor externo. | `lib/main.dart` | Bajo | Software |
| G13 | 7.5.2 | `ConflictAlgorithm.replace` en varios puntos: revisar que ninguno pise registros técnicos ya capturados. | `app_database.dart`, `database_helper_soporte.dart`, otros (inventario) | Medio (a confirmar) | Software |
| G14 | 8.4 | El respaldo es manual y queda a criterio del usuario; no hay respaldo automático ni prueba de restauración documentada. | `respaldo.dart` | Medio | Ambos |
| G15 | 7.5.1 | Un patrón "Sin fecha válida" no se marca como vencido; verificar si puede seleccionarse. | `WeightCertificateStatus` | Bajo | Software |
| G16 | 7.11.3 a | La pantalla de Respaldo, que permite borrar e importar bases, se protege con una "clave" igual a la fecha y hora actuales (DDMMAA-HHMM): cualquiera que conozca el formato entra. No documentes ese formato en el manual. | `DateTimeAuthService` en `lib/screens/respaldo/respaldo.dart` | Alto | Software |
