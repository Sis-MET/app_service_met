# Registro de validación — ServiceMET 6.4.1+19

Documento controlado según NB/ISO/IEC 17025 7.11.2. Estado: **borrador**. Lo que
solo puede aportar el laboratorio figura como `[PENDIENTE]`.

| Campo | Valor |
|---|---|
| Versión (pubspec) | 6.4.1+19 (Android: versionCode 19, versionName 6.4.1) |
| Commit | [se completa al fijar la versión] (`chore: versión 6.4.1+19`) |
| Versión anterior registrada | 6.4.0+18 (commit 8b18cb6). [PENDIENTE: indicar si llegó a distribuirse o si los teléfonos pasan de 6.3.5+17 a esta versión] |
| Fecha de validación | [PENDIENTE] (pruebas automáticas: 2026-10-20) |
| Clase del cambio | A (crítico): cambia qué se guarda y qué se sube de las pruebas metrológicas de soporte, y el esquema local de las tablas de soporte |
| Validó (desarrollo) | [PENDIENTE] |
| Entorno de las pruebas automáticas | Flutter 3.44.2, Dart 3.12.2, Node.js 24.12.0, Windows 11 |
| Entorno de las pruebas funcionales | [PENDIENTE: modelo del teléfono, versión de Android, perfil de conexión y base de SQL Server] |

## Cambios incluidos

| Commit | Descripción | Clase | Impacto en datos / registros | Incidencia relacionada |
|---|---|---|---|---|
| 99ec689 | Soporte: volver a activar la linealidad con una sola carga ya no deja la pantalla en blanco; la repetibilidad reabierta con un número de lecturas fuera de la lista elige la opción que las contiene | B | Ninguno: solo cómo se muestra la prueba al armarla de nuevo. | Pantalla en blanco al apagar y volver a encender una prueba en Mnt Preventivo Avanzado (2026-10-20) |
| 950dc0d | Soporte: el interruptor "Realizar ..." avisa ("Activando la prueba…" / "Omitiendo la prueba…") y guarda en el acto, en los 7 módulos con pruebas metrológicas | B | El cambio se guarda al momento en vez de esperar al autoguardado; lo guardado es lo mismo. | Interruptor sin aviso y con retraso (2026-10-20) |
| 56716a8 | Soporte: una prueba omitida no se guarda ni se sube y sigue omitida al continuar; las cargas o lecturas quitadas no dejan su valor; al continuar vuelven las filas que siguen a una vacía | A | En los 7 módulos, una prueba omitida queda vacía en el registro y no llega a DataMET (antes, en Avanzado, Regular y Correctivo quedaban las lecturas anteriores, y Relevamiento las guardaba siempre). Cada tabla local de soporte agrega la columna `pruebas_omitidas`, que no se sube; un registro de una versión anterior se lee como antes. Solo afecta servicios en curso: las pantallas de módulo no reabren uno finalizado. El servidor no cambia. | Hallado al revisar la incidencia anterior (2026-10-20) |
| 258f23d | Manual y cambios sin liberar | C | Ninguno. | — |

Esta versión incluye todo lo de 6.4.0+18 (ver `VAL-6.4.0+18.md`).

## Pruebas automáticas

| Suite | Comando | Resultado | Observaciones |
|---|---|---|---|
| App | `flutter test` | 507 aprobadas / 0 fallidas (2026-10-20) | Incluye `test/screens/soporte_interruptor_pruebas_test.dart` (aviso del interruptor, flujo de Mnt Preventivo Avanzado, linealidad con una sola carga, repetibilidad con 4 lecturas) y `test/screens/soporte_pruebas_omitidas_test.dart` (con las bases de los 7 módulos: omitir y continuar, la subida sin la columna local ni datos de la prueba omitida, una prueba sin llenar sigue activa, filas vacías en medio y filas quitadas). Sin las correcciones fallan 5 y 19 de ellas. También la consistencia del historial, la matriz y el manual con `pubspec.yaml`. |
| Backend | `node --test` (en `backend/`) | 115 aprobadas / 0 fallidas (2026-10-20) | Sin cambios desde 6.4.0+18. |
| Compilación Android (release) | `flutter build appbundle --release` | [resultado de la compilación] | — |

## Casos funcionales (clase A/B)

| ID | Objetivo | Datos de entrada | Resultado esperado | Resultado obtenido | Conforme |
|---|---|---|---|---|---|
| F-01 | Aviso del interruptor | Mnt Preventivo Avanzado, Pruebas Iniciales: apagar y encender "Realizar linealidad" | La tarjeta muestra "Omitiendo la prueba…" / "Activando la prueba…" con el indicador de carga, el interruptor no admite otro toque y la prueba se quita o aparece sin esperar | [PENDIENTE] | [PENDIENTE] |
| F-02 | Linealidad con una sola carga | Llenar la carga 1, quitar la fila 2, apagar y volver a encender la linealidad | La prueba se abre con la carga 1 y una segunda vacía; la pantalla no queda en blanco | [PENDIENTE] | [PENDIENTE] |
| F-03 | Prueba omitida al continuar | Llenar la linealidad, omitirla, salir ("Salir (queda guardado)") y continuar el servicio | La linealidad sigue omitida y sin datos; excentricidad y repetibilidad siguen activas | [PENDIENTE] | [PENDIENTE] |
| F-04 | Prueba sin llenar al continuar | Mnt Correctivo: salir antes del paso de pruebas y continuar | Al llegar a las pruebas, las tres siguen activas y "Siguiente" las exige | [PENDIENTE] | [PENDIENTE] |
| F-05 | Subida con una prueba omitida | Finalizar y subir F-03 (y uno de Relevamiento de datos con la linealidad omitida) | En DataMET las columnas de la linealidad del servicio quedan vacías; la subida no informa columnas desconocidas | [PENDIENTE] | [PENDIENTE] |
| F-06 | Repetibilidad inicial al continuar | Instalación: repetibilidad de 3 mediciones, salir y continuar | Vuelve con 3 mediciones y deja avanzar | [PENDIENTE] | [PENDIENTE] |

## Verificaciones adicionales

- [ ] Ida y vuelta contra DataMET: comparar F-05 en las tablas de soporte con lo
      registrado en el teléfono. [PENDIENTE]
- [ ] Migración: instalar 6.4.1+19 sobre la versión en uso con servicios de
      soporte en curso; continuarlos, guardarlos y subirlos sin perder datos.
      [PENDIENTE]
- [ ] Si 6.4.0+18 no se distribuyó: los pendientes de `VAL-6.4.0+18.md`
      (scripts 012, 014, 015 y 016 en DataMET y backend desplegado) se cumplen
      antes de distribuir esta versión. [PENDIENTE]
- [x] Manual de uso actualizado: revisión 03 (borrador), aplica a 6.4.1 o
      posterior.

## Problemas conocidos y restricciones de uso

- Una prueba omitida pierde sus lecturas al guardar. Si el técnico la vuelve a
  activar en la misma sesión, las recupera; si cierra la app con la prueba
  omitida, ya no.
- Al restaurar un respaldo en un teléfono que todavía no guardó ningún servicio
  de soporte con esta versión, la marca de prueba omitida no se copia: la
  prueba vuelve activa y vacía (nunca con datos anteriores) y hay que omitirla
  de nuevo.
- Lo de 6.4.0+18 sigue vigente (talonarios del RIM, `db_owner` y el historial
  de cambios solo en el teléfono, requisito RT-08 parcial).

## Decisión

- [ ] Liberada para uso  - [ ] No liberada
- Autorizó (responsable técnico o de calidad del laboratorio): [PENDIENTE: nombre, cargo, fecha]
- Fecha de puesta en uso: [PENDIENTE]
- Dispositivos actualizados: [PENDIENTE]
