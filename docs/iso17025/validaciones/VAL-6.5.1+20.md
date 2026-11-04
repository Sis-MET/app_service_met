# Registro de validación — ServiceMET 6.5.1+20

Documento controlado según NB/ISO/IEC 17025 7.11.2. Estado: **borrador**. Lo que
solo puede aportar el laboratorio figura como `[PENDIENTE]`.

| Campo | Valor |
|---|---|
| Versión (pubspec) | 6.5.1+20 (Android: versionCode 20, versionName 6.5.1) |
| Commit | [se completa al fijar la versión] (`chore: versión 6.5.1+20`) |
| Versión anterior registrada | 6.4.1+19 (commit 646ec67) |
| Fecha de validación | [PENDIENTE] (pruebas automáticas: 2026-10-29) |
| Clase del cambio | A (crítico): agrega un registro técnico nuevo (calibración de temperatura) con su captura, su esquema local y del servidor y su subida, y cambia el lector del indicador que usa la calibración de balanzas |
| Validó (desarrollo) | [PENDIENTE] |
| Entorno de las pruebas automáticas | Flutter 3.44.2, Dart 3.12.2, Node.js 24.22.1, Windows 11 |
| Entorno de las pruebas funcionales | [PENDIENTE: modelo del teléfono, versión de Android, perfil de conexión, base de SQL Server, equipo calibrado y tipo de display (LED y LCD)] |

## Cambios incluidos

| Commit | Descripción | Clase | Impacto en datos / registros | Incidencia relacionada |
|---|---|---|---|---|
| 5d5b6bd | Lector del indicador: recuadro movible y redimensionable que se recuerda, ajustes de cámara (zoom, exposición, bloqueo), displays de color, unidad °C/°F, mensajes sin valor, varias regiones, voto de ráfaga y "Verificar lectura" | A | En balanzas el lector sigue leyendo igual (sin unidades ni color); cambia solo cómo se encuadra el display. El valor sigue pasando por el técnico antes de guardarse. | — |
| 9641114 | Script 017: tablas de la calibración de temperatura en DataMET | A (servidor) | Seis tablas nuevas `DATA_SERVICIOS_DATOS_CAL_TE` (cabecera, patrones, canales, puntos, lecturas y correcciones). La API recibe `SELECT, INSERT` y `DENY UPDATE, DELETE`; DataMET+ (opcional) `SELECT` y el mismo `DENY`. No cambia ninguna tabla existente. | — |
| 4abcc79 | API: `POST /api/calibracion/temperatura` | A | Valida el registro completo y lo inserta en una transacción, más la fila de resumen en `DATA_SERVICIOS_DATOS` con `tipo_servicio = 'CAL.TE'`. Con el mismo uuid responde que ya estaba, sin duplicar; un código de registro ya usado se rechaza; sin el script 017 responde que falta. | — |
| 88d7878 | App: tipo de calibración y calibración de temperatura | A | Tablas locales `temp_*` dentro de `calibracion.db`. Cada lectura se guarda al momento con la hora del teléfono (con milisegundos), el texto leído, el origen, la coincidencia y la imagen del display; una lectura no tomada queda "sin lectura" con motivo. Las correcciones y exclusiones agregan filas con motivo y conservan el valor original; un registro finalizado ya no se modifica. La calibración de balanzas no cambia. | — |
| defa62c | Manual, cambios sin liberar y matriz | C | Ninguno. | — |

Esta versión incluye todo lo de 6.4.1+19 (ver `VAL-6.4.1+19.md`).

## Pruebas automáticas

| Suite | Comando | Resultado | Observaciones |
|---|---|---|---|
| App | `flutter test` | 565 aprobadas / 0 fallidas (2026-10-29) | Incluye `test/screens/indicator_profiles_test.dart` (perfiles, color, unidades y mensajes sin valor, voto de ráfaga, PNG de evidencia), `test/screens/temperatura/temperatura_store_test.dart` (91 lecturas en 45 min cada 30 s, las lecturas solo se agregan, corregir conserva el original y deja el historial, canales y puntos medidos quedan fijos, un registro finalizado se bloquea, código de un equipo nuevo con historial, JSON de subida sin lo que es solo del teléfono), `captura_programada_test.dart` (horario, voto de 3 cuadros, lectura manual hasta la siguiente, "sin lectura" con motivo, app en segundo plano o cerrada, resultados comparados con valores calculados a mano), `temperatura_subida_test.dart` (sube una vez, sin red queda pendiente, rechazo del servidor, sesión vencida, no se sube en curso ni con código provisional) y `temperatura_flujo_test.dart` (recorrido completo hasta un registro finalizado y bloqueado, QR del equipo, selector de tipo). También la consistencia del historial, la matriz y el manual con `pubspec.yaml`. |
| Backend | `node --test` (en `backend/`) | 129 aprobadas / 0 fallidas (2026-10-29) | Incluye `test/temperatura.test.js`: validación, número de lecturas programadas igual que en la app, inserción por lotes, mismo uuid sin duplicar, código repetido y respuesta sin el script 017. |
| Compilación Android (release) | `flutter build appbundle --release` | Compilado sin errores (2026-10-29), con la versión 6.5.1+20 aún sin confirmar sobre el commit defa62c: `ServiceMET_v6.5.1+20.aab`, 114,7 MB, SHA-256 `2032e75d5d5e475109fcf5ee8a5c67fcbafd0bbe5eff919d1162618d72eb5117` | El manifiesto de release declara `bo.metrica.smet`, versionCode 20 y versionName 6.5.1. `jarsigner -verify`: firma válida, con la misma llave de subida que 6.4.1+19 (certificado SHA-256 `5C:FF:7E:75:DD:67:EC:91:71:7F:A2:B0:93:3A:F5:A5:02:0D:CC:10:A9:8C:5C:5D:92:25:E2:53:92:9E:13:68`). |

## Casos funcionales (clase A/B)

| ID | Objetivo | Datos de entrada | Resultado esperado | Resultado obtenido | Conforme |
|---|---|---|---|---|---|
| F-01 | Tipo de calibración | Servicios › Calibración | Aparece "Tipo de calibración"; con "CALIBRACIÓN DE BALANZAS" el flujo de balanzas es el mismo de 6.4.1 | [PENDIENTE] | [PENDIENTE] |
| F-02 | Lector en balanzas | Calibración de balanzas, leer el indicador moviendo y agrandando el recuadro; salir y volver a abrir el lector | Lee el mismo valor que en 6.4.1; el recuadro vuelve donde quedó | [PENDIENTE] | [PENDIENTE] |
| F-03 | Pasos de temperatura | Cliente, Planta, SECA, un equipo de la planta (Digital), un patrón de temperatura, dos sensores con posición, la referencia del registrador y el ambiente inicial | En patrones solo aparecen equipos de temperatura (ninguna pesa); el asistente no deja avanzar sin patrón, sensor, indicador y ambiente | [PENDIENTE] | [PENDIENTE] |
| F-04 | Medición con la cámara (LED) | Punto de 5 min cada 30 s, teléfono fijo frente a un controlador LED rojo; registrador de los sensores iniciado a la vez | 11 lecturas, cada una con su hora y su imagen; los valores coinciden con el display | [PENDIENTE] | [PENDIENTE] |
| F-05 | Medición con la cámara (LCD) | Lo mismo con un display LCD | Igual que F-04 | [PENDIENTE] | [PENDIENTE] |
| F-06 | Lectura que la cámara no toma | Tapar el display durante una lectura y escribirla a mano; tapar otra y no escribir nada | La primera queda con origen manual y su hora real; la segunda queda "sin lectura" con motivo | [PENDIENTE] | [PENDIENTE] |
| F-07 | App en segundo plano | Durante un punto, pasar a otra app 2 minutos y volver | Las lecturas de ese lapso quedan "sin lectura" con el motivo de la app en segundo plano; la medición sigue | [PENDIENTE] | [PENDIENTE] |
| F-08 | Corrección y exclusión | En "Ver lecturas", corregir una lectura y excluir otra, con motivo; finalizar e intentar corregir de nuevo | Queda el valor original y el historial con técnico y fecha; después de "Finalizar" ya no se corrige | [PENDIENTE] | [PENDIENTE] |
| F-09 | Subida a DataMET | Subir F-04 desde el Resumen y reintentar | Las seis tablas y `DATA_SERVICIOS_DATOS` (`CAL.TE`) tienen lo mismo que el teléfono; el reintento responde que ya estaba, sin duplicar | [PENDIENTE] | [PENDIENTE] |
| F-10 | Equipo nuevo | Calibrar un equipo "Nuevo" e intentar subirlo; asignarle su código y subir | No se sube con el código provisional; después de "Asignar código" sube con el definitivo y el cambio queda en la auditoría | [PENDIENTE] | [PENDIENTE] |
| F-11 | Exportar CSV | Exportar F-04 desde el Resumen | El CSV abre en Excel con las lecturas, las horas, los canales leídos y los sensores en la ficha | [PENDIENTE] | [PENDIENTE] |

## Verificaciones adicionales

- [ ] Script 017 ejecutado en DataMET_prueba y luego en DataMET, y backend
      desplegado con `DataMET_prueba_esquema.md` actualizado. [PENDIENTE]
- [ ] Ida y vuelta contra DataMET: comparar F-09 lectura por lectura con lo
      registrado en el teléfono. [PENDIENTE]
- [ ] Migración: instalar 6.5.1+20 sobre 6.4.1+19 con calibraciones de balanzas
      y servicios de soporte en curso; continuarlos, guardarlos y subirlos sin
      perder datos. [PENDIENTE]
- [ ] Respaldo y restauración con una calibración de temperatura en curso: las
      tablas `temp_*` vuelven completas. [PENDIENTE]
- [x] Manual de uso actualizado: revisión 04 (borrador), aplica a 6.5.1 o
      posterior.

## Problemas conocidos y restricciones de uso

- Los resultados del Resumen de temperatura son preliminares y solo del
  indicador: el error de indicación y la incertidumbre se calculan con los
  datos de los sensores, que están en el software del registrador.
- Las imágenes de las lecturas quedan en el teléfono; a DataMET llegan los
  valores, el texto leído y la coincidencia.
- DataMET+ todavía no muestra las calibraciones de temperatura, el tablero de
  Inicio no las cuenta y desde ellas no se emite un RIM.
- Lo de 6.4.1+19 sigue vigente.

## Decisión

- [ ] Liberada para uso  - [ ] No liberada
- Autorizó (responsable técnico o de calidad del laboratorio): [PENDIENTE: nombre, cargo, fecha]
- Fecha de puesta en uso: [PENDIENTE]
- Dispositivos actualizados: [PENDIENTE]
