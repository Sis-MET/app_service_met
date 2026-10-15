# Registro de validación — ServiceMET 6.3.5+17

Documento controlado según NB/ISO/IEC 17025 7.11.2. Estado: **borrador**. Lo que
solo puede aportar el laboratorio figura como `[PENDIENTE]`.

| Campo | Valor |
|---|---|
| Versión (pubspec) | 6.3.5+17 (Android: versionCode 17, versionName 6.3.5) |
| Commit | [PENDIENTE: commit `chore: versión 6.3.5+17`] |
| Versión anterior en uso | 6.3.4+16 (commit 8825ff7) |
| Fecha de validación | [PENDIENTE] (pruebas automáticas: 2026-10-15) |
| Clase del cambio | A (crítico): cambia qué datos se capturan, el esquema local y del servidor, la subida y los permisos |
| Validó (desarrollo) | [PENDIENTE] |
| Entorno de las pruebas automáticas | Flutter 3.44.2, Dart 3.12.2, Node.js 24.12.0, Windows 11 |
| Entorno de las pruebas funcionales | [PENDIENTE: modelo del teléfono, versión de Android, perfil de conexión y base de SQL Server] |

## Cambios incluidos

| Commit | Descripción | Clase | Impacto en datos / registros | Incidencia relacionada |
|---|---|---|---|---|
| 5aa26c8 | Ubicación GPS de cada servicio de calibración y de los 8 módulos de soporte | A | Columnas nuevas `latitud`, `longitud`, `precision_gps` y `fecha_gps` en la fila local de cada registro y en `DATA_SERVICIOS_DATOS` (script 013). La primera ubicación no se reemplaza. Lo subido desde versiones anteriores queda sin coordenadas. | — |
| 107c972 | Balanzas nuevas con código definitivo antes de subir; Registros de solo lectura | A | Se retira el editor de registros. Las balanzas con código provisional no se suben; asignar el código definitivo es la única corrección y queda en `auditoria_registros` (anterior, nuevo, usuario, fecha, motivo y versión), en la misma transacción. | — |
| 2d94b94 | Ficha del instrumento con los rangos de menor a mayor | B | Solo visual: `cap_max1..3` y sus `d`, `e` y decimales no se reordenan ni se migran. | — |
| a9e9cee | Aviso previo a cada permiso; servicio bloqueado sin ubicación | A | Sin permiso de ubicación, o con la ubicación del teléfono apagada, no se inicia ni continúa un servicio. Notificaciones y cámara se piden después del aviso de la app. | — |
| 9cb03b0 | Manual, matriz de cumplimiento y cambios sin liberar | C | Ninguno. | — |

## Pruebas automáticas

| Suite | Comando | Resultado | Observaciones |
|---|---|---|---|
| App | `flutter test` | 456 aprobadas / 0 fallidas (2026-10-15) | Incluye: ubicación en calibración y en cada uno de los 8 módulos de soporte, alineación de ubicaciones en la subida, creación de columnas con guardados simultáneos, asignación del código con historial atómico, hoja de asignación, orden visual de rangos, ficha del instrumento, aviso previo y bloqueo sin ubicación, y consistencia del historial y la matriz con `pubspec.yaml`. |
| Backend | `node --test` (en `backend/`) | 97 aprobadas / 0 fallidas (2026-10-15) | Incluye `test/location.test.js`: normalización y descarte de ubicaciones inválidas, consulta del resumen con y sin columnas, ubicación de soporte fuera del registro técnico. |
| Compilación Android | `flutter build apk --debug` | Compiló sin errores (2026-10-15) | Verifica el canal nativo que consulta el permiso de cámara. |

Durante una corrida de la suite completa falló una vez
`test/database/precarga_schema_recovery_test.dart` ("tras cerrar, reabrir ve el
archivo intercambiado por debajo"). Al repetirla sola pasó 5 de 5 veces y la
suite completa volvió a pasar entera: es una prueba intermitente que depende de
que Windows libere el archivo de la base; no la afectan los cambios de esta
versión.

## Casos funcionales (clase A/B)

| ID | Objetivo | Datos de entrada | Resultado esperado | Resultado obtenido | Conforme |
|---|---|---|---|---|---|
| F-01 | Aviso previo de ubicación al abrir un servicio | Teléfono sin permiso de ubicación; abrir Servicios › Calibración | Aparece "Permiso de ubicación" antes de la ventana del sistema; con "Continuar" y permitir, se abre el servicio | [PENDIENTE] | [PENDIENTE] |
| F-02 | Bloqueo sin ubicación | Rechazar el permiso; luego rechazarlo "para siempre"; luego apagar la ubicación del teléfono | "Ubicación requerida" con "Permitir ubicación", "Abrir ajustes" y "Activar ubicación"; el servicio se abre solo al volver con el permiso concedido | [PENDIENTE] | [PENDIENTE] |
| F-03 | Ubicación en calibración | Calibración de prueba completa | En Registros, el detalle muestra latitud, longitud, precisión y fecha del GPS | [PENDIENTE] | [PENDIENTE] |
| F-04 | Ubicación en soporte | Un servicio de prueba en cada módulo de soporte usado por el laboratorio | Igual que F-03 | [PENDIENTE] | [PENDIENTE] |
| F-05 | Aviso de notificaciones y cámara | Primera entrada al inicio; primer escaneo QR y primera foto | Aviso de la app antes de cada ventana del sistema; con "Ahora no" no se abre la cámara | [PENDIENTE] | [PENDIENTE] |
| F-06 | Rangos de menor a mayor | Balanza del catálogo con `cap_max1` mayor que `cap_max2` | En el paso Instrumento y en "Información del instrumento" el Rango 1 es el menor; lo subido conserva el orden guardado | [PENDIENTE] | [PENDIENTE] |
| F-07 | Balanza nueva en la subida | Calibración de una balanza nueva (código provisional) y otra registrada en la misma SECA | La nueva aparece aparte con "Asignar código"; "SUBIR REGISTRADAS" sube solo la registrada | [PENDIENTE] | [PENDIENTE] |
| F-08 | Asignación del código definitivo | Registrar la balanza en DataMET y asignar su código en la app | El detalle muestra "Historial de cambios" (código anterior, nuevo, usuario, fecha, motivo); la balanza se valida y sube | [PENDIENTE] | [PENDIENTE] |
| F-09 | Registros de solo lectura | Abrir un registro en Registros | No existe "Editar"; el detalle indica "Solo lectura" | [PENDIENTE] | [PENDIENTE] |

## Verificaciones adicionales

- [ ] Ida y vuelta contra DataMET: subir F-03, F-04 y F-08 y comparar en
      `DATA_SERVICIOS_DATOS` y en la tabla de detalle lo capturado con lo
      almacenado (coordenadas con 6 decimales, `fecha_gps` con su desfase,
      `codigo_registro` con el código definitivo). [PENDIENTE]
- [ ] Migración: instalar 6.3.5+17 sobre 6.3.4+16 con datos existentes y
      verificar que los registros abren, se consultan y se suben, y que las
      tablas locales reciben las columnas de ubicación. [PENDIENTE]
- [x] Manual de uso actualizado: revisión 01 (borrador), aplica a 6.3.5 o
      posterior.
- [ ] Script `backend/sql/013_add_service_location.sql` ejecutado. Informado
      por el usuario el 2026-10-15, junto con el despliegue del backend
      (`pm2 restart servicemet-api`). [PENDIENTE: base en que se ejecutó
      (`DataMET_prueba` o `DataMET`) y salida de verificación del script]

## Problemas conocidos y restricciones de uso

- El historial de cambios (asignación del código definitivo) se guarda solo en
  el teléfono; no viaja a DataMET (requisito RT-08 de la matriz, parcial).
- Un servicio subido desde una versión anterior de la app no tiene
  coordenadas en `DATA_SERVICIOS_DATOS`.
- La app no pide los permisos de ubicación en segundo plano: la ubicación se
  toma solo con la app abierta, al guardar la balanza.

## Decisión

- [ ] Liberada para uso  - [ ] No liberada
- Autorizó (responsable técnico o de calidad del laboratorio): [PENDIENTE: nombre, cargo, fecha]
- Fecha de puesta en uso: [PENDIENTE]
- Dispositivos actualizados: [PENDIENTE]
