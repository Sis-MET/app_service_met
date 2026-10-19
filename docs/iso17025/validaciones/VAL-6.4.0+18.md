# Registro de validación — ServiceMET 6.4.0+18

Documento controlado según NB/ISO/IEC 17025 7.11.2. Estado: **borrador**. Lo que
solo puede aportar el laboratorio figura como `[PENDIENTE]`.

| Campo | Valor |
|---|---|
| Versión (pubspec) | 6.4.0+18 (Android: versionCode 18, versionName 6.4.0) |
| Commit | (`chore: versión 6.4.0+18`) |
| Versión anterior en uso | 6.3.5+17 (commit 3692570) |
| Fecha de validación | [PENDIENTE] (pruebas automáticas: 2026-10-19) |
| Clase del cambio | A (crítico): cambia qué datos se capturan en el RIM, el esquema local y del servidor, la subida y los permisos en la base |
| Validó (desarrollo) | [PENDIENTE] |
| Entorno de las pruebas automáticas | Flutter 3.44.2, Dart 3.12.2, Node.js 24.12.0, Windows 11 |
| Entorno de las pruebas funcionales | [PENDIENTE: modelo del teléfono, versión de Android, perfil de conexión y base de SQL Server] |

## Cambios incluidos

| Commit | Descripción | Clase | Impacto en datos / registros | Incidencia relacionada |
|---|---|---|---|---|
| e402ba7, c61d797 | Script 014: numeración del RIM por talonarios, anulaciones y fotos del RIM web | A | Tablas nuevas `rim_talonarios`, `rim_talonarios_cierres`, `form_rim_anulaciones` y `form_rim_fotos`; `form_rim` agrega origen, gestión, número, talonario e instalación, con un índice único que impide que dos RIM compartan número. | — |
| 3dd533b | API: entrega de talonarios y validación del código numerado | A | La subida del RIM comprueba que el número sea de un talonario de esa instalación y que la gestión coincida con la emisión; un RIM anulado en el teléfono se registra con su anulación. Los códigos anteriores se siguen aceptando. | — |
| c4e9f62 | App: código RIM-AA-NNNN con talonarios | A | La base local del RIM agrega la instalación, los talonarios y sus solicitudes, y la numeración de cada RIM. El RIM se emite sin red con el número del talonario; sin números no se emite. | — |
| 49f20f5 | Soporte: carga de repetibilidad con decimales (script 015 y esquema del backend) | A | Cinco columnas pasan de `int` a `decimal` en `DATA_SERVICIOS_DATOS_MPA_STAC`, `DATA_SERVICIOS_DATOS_MPR_STIL` y `DATA_SERVICIOS_DATOS_RVD`; los valores existentes se conservan. La app no cambia. | Servicio de soporte rechazado por el servidor con carga 525.5 (2026-10-19) |
| 7cfce84 | Script 016: ejecución y entrega del RIM (las registra DataMET+) | A (servidor) | Tablas `form_rim_ejecucion` y `form_rim_entregas`, solo de inserción: cada cambio es una fila nueva que apunta a la anterior, con usuario, hora del servidor y motivo si corrige. La app no las usa. | — |
| 87a0728, 6142af7 | RIM y oportunidades en DataMET, sin base aparte; `DENY UPDATE, DELETE` | A | Las tablas del RIM y de las oportunidades se crean dentro de DataMET (la base `servicios_extras` no llegó a crearse). Los usuarios de la API y de DataMET+ tienen denegado modificar y borrar; los scripts 014 y 016 muestran los permisos efectivos. | — |
| 6650883, 36439ce, f5f0bf8 | Manual, matriz de cumplimiento y README del backend | C | Ninguno. | — |

## Pruebas automáticas

| Suite | Comando | Resultado | Observaciones |
|---|---|---|---|
| App | `flutter test` | 469 aprobadas / 0 fallidas (2026-10-19) | Incluye la numeración del RIM: numera en orden con los talonarios y nunca repite un número; sin talonario no se emite; una base copiada a otra instalación no usa los talonarios copiados; el pedido de talonario se repite sin pedir otro; los de gestiones pasadas se informan como cerrados; el formulario avisa sin números y los toma al reintentar; un RIM anulado se sube con su anulación; una tabla local anterior a la numeración se completa sin perder RIM; el PDF lleva el código. También la consistencia del historial, la matriz y el manual con `pubspec.yaml`. |
| Backend | `node --test` (en `backend/`) | 115 aprobadas / 0 fallidas (2026-10-19) | Incluye `test/extras-service.test.js`: talonarios repetibles por solicitud, validación del número y de la gestión, anulaciones, la base de los formularios igual a `DB_NAME`, y la carga de repetibilidad decimal en soporte. |
| Compilación Android (release) | `flutter build appbundle --release` | [PENDIENTE: se genera con la autorización del usuario] | — |

Sistema relacionado (no se distribuye con la app): DataMET+, que registra la
ejecución y la entrega del RIM, pasó el 2026-10-19 sus pruebas del backend
(128), de vitest (132) y las e2e del RIM (8), con la API simulada.

## Casos funcionales (clase A/B)

| ID | Objetivo | Datos de entrada | Resultado esperado | Resultado obtenido | Conforme |
|---|---|---|---|---|---|
| F-01 | Recepción del talonario | Instalar 6.4.0+18 y abrir la app con conexión a la red de METRICA | El teléfono recibe un talonario de 10 números; en DataMET+ › RIM › Numeración aparece con el usuario, el dispositivo y la versión | [PENDIENTE] | [PENDIENTE] |
| F-02 | Emisión sin red | Modo avión; emitir un RIM fuera de un servicio y otro dentro de una calibración | Cada RIM recibe el siguiente número del talonario (RIM-26-NNNN), visible desde que se abre el formulario, en las firmas y en el PDF | [PENDIENTE] | [PENDIENTE] |
| F-03 | Sin números | Instalación sin talonario y sin conexión; abrir "Nuevo RIM" | Aparece "Sin números de RIM en este teléfono" y no deja emitir; con conexión y "Reintentar" recibe números | [PENDIENTE] | [PENDIENTE] |
| F-04 | Cancelar no gasta número | Abrir el formulario y cancelarlo; abrir otro y emitirlo | El RIM emitido usa el número que mostraba el formulario cancelado | [PENDIENTE] | [PENDIENTE] |
| F-05 | Subida del RIM numerado | Subir F-02 con conexión; volver a subirlo | En DataMET+ › Registros aparece con su código y su número; la segunda subida no lo duplica | [PENDIENTE] | [PENDIENTE] |
| F-06 | RIM anulado antes de subir | Emitir un RIM, anularlo en el teléfono con motivo y subir | En DataMET+ figura "Anulado" con el motivo, quién y cuándo; su número queda justificado en Numeración | [PENDIENTE] | [PENDIENTE] |
| F-07 | RIM con código anterior | RIM emitido con 6.3.5+17 y pendiente de subir al actualizar | Se sube con su código anterior (RIM-{planta}-{AA}), sin número | [PENDIENTE] | [PENDIENTE] |
| F-08 | Carga de repetibilidad decimal | Servicio de prueba de Mantenimiento preventivo regular con carga 525.5 | Se sube sin error y DataMET guarda 525.5 | [PENDIENTE] | [PENDIENTE] |

## Verificaciones adicionales

- [ ] Ida y vuelta contra DataMET: comparar F-02 y F-05 en `form_rim`
      (`codigo_rim`, `gestion`, `numero`, `talonario_id`, `instalacion`,
      `emitido_en`) con lo que muestra el PDF firmado. [PENDIENTE]
- [ ] Migración: instalar 6.4.0+18 sobre 6.3.5+17 con RIM emitidos, pendientes
      y anulados; verificar que se listan, se abren, se suben y que la base
      local agrega los talonarios sin perder datos. [PENDIENTE]
- [ ] Scripts `backend/sql/012_create_form_rim_y_form_bitrix.sql`,
      `014_rim_numeracion_y_gestion.sql`, `015_expand_support_repetibilidad_carga.sql`
      y `016_rim_ejecucion_y_entrega.sql` ejecutados en DataMET, con
      `puede_actualizar` y `puede_eliminar` en 0 para los usuarios de la API y
      de DataMET+ en la verificación de los scripts. [PENDIENTE: fecha, base y
      salida de la verificación]
- [ ] Backend de ServiceMET desplegado antes de distribuir la app (sin él la
      app no recibe talonarios). [PENDIENTE]
- [x] Manual de uso actualizado: revisión 02 (borrador), aplica a 6.4.0 o
      posterior.

## Problemas conocidos y restricciones de uso

- Los talonarios pertenecen a la instalación de la app: al reinstalarla o al
  usar una base copiada se piden talonarios nuevos. Los números que quedaron
  sin usar se cierran en DataMET+ › RIM › Numeración ("Cerrar talonario") para
  que queden como no utilizados.
- Un teléfono sin conexión y sin números no puede emitir RIM hasta conectarse.
- Si la verificación de los scripts 014 o 016 avisa que un usuario es
  `db_owner` de DataMET, el `DENY` no lo alcanza y ese usuario podría modificar
  los RIM: hay que quitarle ese rol.
- El historial de cambios de un registro técnico (asignación del código
  definitivo) sigue guardándose solo en el teléfono (requisito RT-08,
  parcial).

## Decisión

- [ ] Liberada para uso  - [ ] No liberada
- Autorizó (responsable técnico o de calidad del laboratorio): [PENDIENTE: nombre, cargo, fecha]
- Fecha de puesta en uso: [PENDIENTE]
- Dispositivos actualizados: [PENDIENTE]
