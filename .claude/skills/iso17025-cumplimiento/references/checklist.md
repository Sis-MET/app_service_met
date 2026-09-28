# Lista de verificación NB/ISO/IEC 17025 para ServiceMET

Cada ítem tiene un ID estable para usarlo en la matriz y en el seguimiento. En
"Cómo verificar" se indica qué leer o ejecutar; si no se puede verificar, el
estado es `Sin evidencia`, no `Cumple`.

Estados: `Cumple` · `Parcial` · `No cumple` · `No aplica` · `Sin evidencia`.

## RT: Registros técnicos (7.5)

| ID | Requisito | Cómo verificar |
|---|---|---|
| RT-01 | Cada registro se identifica de forma única y se vincula al servicio y al ítem | Claves y columnas de identificación en `app_database.dart` y soporte (`seca`, `session_id`, `cod_metrica`); `codigo_registro` generado en el servidor (`calibration-service.js`, `support-service.js`) |
| RT-02 | Fecha y hora registradas en el momento de la captura | Dónde se asignan `fecha_servicio`, `hora_inicio` y `hora_fin` (providers y steps): ¿al capturar o al exportar? ¿El técnico puede editarlas libremente? ¿Se guarda también la hora de recepción en el servidor? |
| RT-03 | El técnico responsable sale de la sesión autenticada | Origen de `personal`: ¿viene del usuario logueado o de un campo de texto editable? |
| RT-04 | Queda registrado quién revisa o verifica datos y resultados | Buscar revisión técnica en la app, la API o DataMET; si no está en el software, pedir el procedimiento |
| RT-05 | Información suficiente para repetir y estimar la incertidumbre: equipo, patrones con certificado, condiciones ambientales inicial y final, método | Columnas de `registros_calibracion` y de cada módulo de soporte; pasos de la captura |
| RT-06 | Patrones vencidos o sin fecha no pueden usarse sin advertencia ni justificación | `WeightCertificateStatus` y la lógica de selección en `patron_weights_selector.dart` |
| RT-07 | Las observaciones originales se conservan; los valores sugeridos, autollenados u obtenidos por OCR son confirmados por el técnico | `suggestion_helper.dart`, `editable_suggestion_field.dart`, `indicator_reader_screen.dart`: ¿se guarda la foto del indicador? ¿el técnico confirma el valor? |
| RT-08 | Toda modificación conserva valor anterior, valor nuevo, fecha, responsable y motivo | Todos los `update` y `rawUpdate` sobre tablas de registros (inventario); `RegistroEditorScreen._guardar`; existencia de una tabla de auditoría |
| RT-09 | No hay sobrescritura silenciosa de registros capturados | Cada `ConflictAlgorithm.replace` o `INSERT OR REPLACE` del inventario: ¿qué tabla es? ¿puede pisar un registro técnico? |
| RT-10 | Los registros técnicos no se borran físicamente; se anulan con motivo | `delete` y `rawDelete` del inventario; UI de eliminar; scripts SQL con `DELETE` |
| RT-11 | Un registro subido no puede modificarse localmente sin control | Editor y detalles: ¿consultan `calibration_upload_status` o el estado de subida de soporte? |
| RT-12 | Las fotos y evidencias quedan vinculadas al registro y no se pierden al editar | Columnas `*_foto`, `foto_viewer.dart`, `registro_editor_screen.dart` (las fotos no se editan como texto) |
| RT-13 | El registro indica la versión de la app que lo capturó | Columna `app_version` o equivalente en los registros o en la auditoría |

## DI: Datos y gestión de la información (7.11)

| ID | Literal | Requisito | Cómo verificar |
|---|---|---|---|
| DI-01 | 7.11.1 | La precarga offline de clientes, balanzas y patrones está disponible y se sabe cuán actualizada está | `descarga_de_datos.dart`, `precarga_bd.dart`, `/api/bootstrap`; ¿se muestra la fecha de la última descarga? |
| DI-02 | 7.11.2 | Cada versión puesta en uso tiene un registro de validación con pruebas y resultado | `docs/iso17025/validaciones/`; resultados de `flutter test` y `pnpm test` |
| DI-03 | 7.11.2 | Los cambios están autorizados y documentados: quién aprobó la liberación, CHANGELOG | `lib/screens/calidad/data/historial_versiones.dart` (campo `validacion`), `docs/iso17025/validaciones/`, commits |
| DI-04 | 7.11.2 | La versión se identifica sin ambigüedad y es visible | `pubspec.yaml`, `configuracion_screen.dart`, informes PDF |
| DI-05 | 7.11.3 a | Cuentas individuales, sesión con vencimiento, límite de intentos, cuentas inactivas bloqueadas | `security.js`, login en `app.js`, `lib/login/**`; ¿qué pasa con un usuario desactivado que tiene sesión offline? |
| DI-06 | 7.11.3 a | Contraseñas almacenadas con hash, nunca en texto plano ni en logs | `password_verifier.dart`, consulta de login en `app.js`, `debugPrint` y `console.*` con credenciales |
| DI-07 | 7.11.3 b | Transporte protegido y sin posibilidad de manipulación en tránsito | `service_met_http_client.dart` (huella), sin `http://` en producción, sin aceptar cualquier certificado |
| DI-08 | 7.11.3 b | Permisos mínimos en el servidor; la API no puede alterar ni borrar | `backend/sql/006_servicemet_api_permissions.sql`, SQL del backend sin `UPDATE` ni `DELETE` |
| DI-09 | 7.11.3 b | Protección contra la pérdida: respaldo de las bases locales y de las fotos, restauración probada | `respaldo.dart`, `database_import_service.dart`; evidencia de una prueba de restauración |
| DI-10 | 7.11.3 c | Entorno de operación especificado: Android mínimo, permisos, dispositivos, servidor | `android/app/build.gradle*` (minSdk), manifest, README del backend; ¿está en el manual? |
| DI-11 | 7.11.3 d | Integridad: tipos, decimales, fechas y zona horaria consistentes entre la app y el servidor | `calibration_data_normalizer.dart`, `validation.js`, pruebas de normalización |
| DI-12 | 7.11.3 e | Las fallas del sistema quedan registradas con acción inmediata y correctiva | Tabla o registro de incidencias, manejo global de errores en `main.dart`, UI de reporte, seguimiento hasta el cierre |
| DI-13 | 7.11.4 | Servicios externos identificados y controlados | `pubspec.yaml` (Firebase, ML Kit y otros), `main.dart`; ¿algún SDK envía datos fuera? |
| DI-14 | 7.11.5 | Manual de uso vigente, controlado y disponible en campo sin conexión | `lib/screens/calidad/data/manual_servicemet.dart` (control y aprobación), Ajustes > Manual de uso, exportación PDF |
| DI-15 | 7.11.6 | Los cálculos están cubiertos por pruebas con valores de referencia | Pruebas de `metrological_tests_provider.dart`, `soporte_metrologia_utils.dart` y de los cálculos de errores y promedios |
| DI-16 | 7.11.6 | Las transferencias se verifican: validar antes de subir, recuentos, ida y vuelta | `calibration_upload_api_service.dart`, `/validar` y `/subir`, `upload_record_deduplicator.dart`, pruebas del backend |
| DI-17 | 7.11.6 | Importar y exportar (BD, CSV) no altera los datos | `database_import_service.dart`, `service_exporter.dart`, pruebas |

## CR: Control de registros (8.4)

| ID | Requisito | Cómo verificar |
|---|---|---|
| CR-01 | Registros legibles y recuperables en la app (historial, detalle, PDF) | `servicio_detalles_screen.dart`, `pdf_generator.dart`, historial |
| CR-02 | Archivos identificados de forma trazable (BD, CSV, ZIP, PDF, fotos, respaldos) | Nombres de archivo en `respaldo.dart`, `service_exporter.dart`, `foto_helper.dart` |
| CR-03 | Almacenamiento protegido; datos sensibles fuera de almacenamiento público | Rutas (`getDatabasesPath`, `.soporte_tec`), `saf_storage.dart`, `flutter_secure_storage` |
| CR-04 | Respaldo definido: qué, cada cuánto, dónde y quién | `respaldo.dart` más el procedimiento del laboratorio; respaldo del servidor DataMET (procedimiento de TI) |
| CR-05 | Retención definida y respetada; la app no elimina antes del plazo (fotos incluidas) | `database_maintenance_service.dart`, borrados de archivos del inventario; plazo en el procedimiento del laboratorio |
| CR-06 | Disposición controlada: autorizada y registrada | Scripts `backend/sql/*` con `DELETE`; borrado de archivos en `respaldo.dart` |
| CR-07 | Acceso acorde con la confidencialidad; exportar y compartir, controlado | `share_plus`, `export_helper.dart`; datos de clientes en `debugPrint` |
| CR-08 | Registros fácilmente disponibles para el laboratorio y el evaluador | Búsqueda por SECA, código o cliente en la app y en DataMET |

## Transversales

| ID | Requisito | Cómo verificar |
|---|---|---|
| TX-01 | Solo el personal autorizado usa la app (6.2.6) | `acceso_app` y `estado` en `data_users`; ¿autorización por tipo de servicio? |
| TX-02 | El manual y los procedimientos son documentos controlados (8.3) | Encabezado de control, revisión y aprobación |
| TX-03 | Una falla que pudo afectar resultados se evalúa como trabajo no conforme (7.10) | Campo "¿afectó datos o resultados?" en la incidencia y flujo de seguimiento |
| TX-04 | Los PDF o informes generados cumplen 7.8 (si aplica) | `pdf_generator.dart` |
