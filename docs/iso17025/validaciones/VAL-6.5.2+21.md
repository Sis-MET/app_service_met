# Registro de validación — ServiceMET 6.5.2+21

Documento controlado según NB/ISO/IEC 17025 7.11.2. Estado: **borrador**. Lo que
solo puede aportar el laboratorio figura como `[PENDIENTE]`.

| Campo | Valor |
|---|---|
| Versión (pubspec) | 6.5.2+21 (Android: versionCode 21, versionName 6.5.2) |
| Commit | [se completa al fijar la versión] (`chore: versión 6.5.2+21`) |
| Versión anterior registrada | 6.5.1+20 (commit 94c3cb6, `VAL-6.5.1+20.md`; su .aab ya se subió a Play Console, por eso esta versión lleva el código 21) |
| Fecha de validación | [PENDIENTE] (pruebas automáticas: 2026-11-04) |
| Clase del cambio | A (crítico): cambia cómo se obtienen las lecturas del indicador en la calibración de temperatura (nuevo origen `ocr_aguja`) y amplía una restricción del script 017 |
| Validó (desarrollo) | [PENDIENTE] |
| Entorno de las pruebas automáticas | Flutter 3.44.2, Dart 3.12.2, Node.js 24.22.1, Windows 11 |
| Entorno de las pruebas funcionales | [PENDIENTE: modelo del teléfono, versión de Android, perfil de conexión, base de SQL Server, equipo calibrado con indicador de aguja (marca, escala y división)] |

## Cambios incluidos

| Commit | Descripción | Clase | Impacto en datos / registros | Incidencia relacionada |
|---|---|---|---|---|
| 3b0435a | Lectura de indicadores de aguja (analógicos) con la cámara: el técnico ajusta el recuadro al dial y marca el eje y tres valores de la escala; la app convierte el ángulo de la aguja en valor (lineal entre marcas) y lo redondea a la resolución del indicador. La línea amarilla muestra la aguja que ve el lector y "Verificar lectura" la compara con lo que ve el técnico. | A | Lecturas con origen `ocr_aguja` ("Cámara (aguja)"); como `texto_leido` guardan el valor sin redondear, el ángulo desde la primera marca y los valores de las marcas (`aguja 24.24 · 41.7° · escala 0/80/160`), más la imagen del dial en el teléfono. Una aguja fuera de las marcas queda "sin lectura" con el motivo "La aguja estaba fuera de la escala marcada". Antes un indicador "Analógico" se tomaba a mano por defecto; ahora con la cámara ("A mano" sigue disponible). Las lecturas de displays digitales no cambian. | — |
| 00675b8, a6ac0af | Script 017 y API: origen `ocr_aguja` | A (servidor) | La tabla `DATA_SERVICIOS_DATOS_CAL_TE_LECTURAS` admite `ocr_aguja` en `CK_CAL_TE_LECTURAS_origen`. Si el 017 ya se ejecutó, al volver a ejecutarlo rehace solo esa restricción (las filas existentes la cumplen); no cambia permisos ni otras tablas. La API valida el origen nuevo y rechaza uno desconocido. | — |
| este commit (`chore: versión 6.5.2+21`) | Manual (revisión 05), historial y matriz | C | Ninguno. | — |

Esta versión incluye todo lo de 6.5.1+20 (ver `VAL-6.5.1+20.md`).

## Pruebas automáticas

| Suite | Comando | Resultado | Observaciones |
|---|---|---|---|
| App | `flutter test` | 586 aprobadas / 0 fallidas (2026-11-04) | Incluye `test/screens/needle_reader_test.dart` (escala del dial: sentido de giro, zona muerta, tramos entre marcas, marcas inválidas, recuadro que se mueve, perfil guardado; lector: toda la escala de 0 a 160 con error ≤ 0,3, la cola y los números no se confunden con la aguja, eje corrido 3 px, dial oscuro, luz despareja con reflejo y ruido, dial grande, escala al revés y bajo cero, aguja fuera de escala; redondeo a la resolución), la lectura de un dial en un cuadro del sensor girado (`indicator_frame_test.dart`) y el registro con origen `ocr_aguja` o "sin lectura" fuera de escala (`captura_programada_test.dart`), además de todo lo de 6.5.1+20. |
| Backend | `node --test` (en `backend/`) | 130 aprobadas / 0 fallidas (2026-11-04) | `test/temperatura.test.js` acepta el origen `ocr_aguja` y rechaza uno desconocido. |
| Lector de aguja con una foto real | Prueba local (la foto, de un banco de imágenes, no se guarda en el repositorio) | Termómetro de dial 0–160 °C con divisiones de 2 °C: lee 24,2 °C, lo mismo que a ojo (dos rayas sobre el 20); con el eje marcado 5–6 px corrido, entre 24,1 y 24,7 °C | Falta la prueba con la cámara frente a un horno real (F-01). |
| Compilación Android (release) | `flutter build appbundle --release` | Compilado sin errores (2026-11-04) sobre 3b0435a, con la versión 6.5.2+21 aún sin confirmar: `ServiceMET_v6.5.2+21.aab`, 120,5 MB, SHA-256 `f16dc75c372ea7da0718b3c76da92aa361feaca08a4b246bb8f0c25725f98ecb` | El manifiesto de release declara `bo.metrica.smet`, versionCode 21 y versionName 6.5.2. `jarsigner -verify`: firma válida, con la misma llave de subida que 6.5.1+20 (certificado SHA-256 `5C:FF:7E:75:DD:67:EC:91:71:7F:A2:B0:93:3A:F5:A5:02:0D:CC:10:A9:8C:5C:5D:92:25:E2:53:92:9E:13:68`). |

## Casos funcionales (clase A/B)

| ID | Objetivo | Datos de entrada | Resultado esperado | Resultado obtenido | Conforme |
|---|---|---|---|---|---|
| F-01 | Indicador de aguja | Equipo con indicador "Analógico" (horno o mufla con termómetro de dial); teléfono fijo y de frente; recuadro al dial, cruz en el eje, marcas en tres valores de la escala; "Verificar lectura"; punto de 5 min cada 30 s | La línea amarilla sigue a la aguja; "Verificar lectura" dice que coincide; 11 lecturas con origen "Cámara (aguja)", su imagen y lo leído con la escala; los valores coinciden con la lectura a ojo dentro de la resolución | [PENDIENTE] | [PENDIENTE] |
| F-02 | Marcas mal puestas y aguja fuera de escala | Escribir en una marca un valor menor que el de la anterior; poner la marca de inicio por encima de la aguja | La app no acepta el valor y explica por qué; con la aguja fuera de las marcas el canal dice "La aguja está fuera de la escala marcada" y la lectura queda "sin lectura" con ese motivo | [PENDIENTE] | [PENDIENTE] |
| F-03 | Recuadro movido con la escala | Mover y agrandar el recuadro con las marcas ya puestas; salir de la medición y volver a entrar | La escala acompaña al recuadro; al volver, el recuadro y las marcas están donde quedaron | [PENDIENTE] | [PENDIENTE] |
| F-04 | Indicador analógico a mano | En Patrones y sensores elegir "A mano" para el indicador analógico | La medición pide escribir cada lectura, con origen manual, como en 6.5.1+20 | [PENDIENTE] | [PENDIENTE] |
| F-05 | Displays digitales sin cambios | Repetir F-04 de 6.5.1+20 (controlador LED) | Mismos resultados que en 6.5.1+20 | [PENDIENTE] | [PENDIENTE] |
| F-06 | Subida con lecturas de aguja | Volver a ejecutar el 017, desplegar el backend y subir F-01 | `DATA_SERVICIOS_DATOS_CAL_TE_LECTURAS` tiene las lecturas con origen `ocr_aguja` y el mismo `texto_leido` que el teléfono | [PENDIENTE] | [PENDIENTE] |

## Verificaciones adicionales

- [ ] Script 017 ejecutado (o vuelto a ejecutar) en DataMET_prueba y luego en
      DataMET: `CK_CAL_TE_LECTURAS_origen` incluye `ocr_aguja`. [PENDIENTE]
- [ ] Backend desplegado con la validación del origen `ocr_aguja`. [PENDIENTE]
- [ ] Migración: instalar 6.5.2+21 sobre 6.5.1+20 con una calibración de
      temperatura en curso; continuarla sin perder lecturas. [PENDIENTE]
- [x] Manual de uso actualizado: revisión 05 (borrador), aplica a 6.5.2 o
      posterior.

## Problemas conocidos y restricciones de uso

- La lectura de aguja necesita el teléfono fijo y de frente al dial (de lado,
  la aguja se ve corrida) y una aguja que contraste con la cara del dial. Si
  la cámara no la ve con claridad, no registra nada y la lectura se escribe a
  mano.
- Las posiciones de las marcas quedan en el teléfono; a DataMET llegan sus
  valores dentro de lo leído.
- Lo de 6.5.1+20 sigue vigente.

## Decisión

- [ ] Liberada para uso  - [ ] No liberada
- Autorizó (responsable técnico o de calidad del laboratorio): [PENDIENTE: nombre, cargo, fecha]
- Fecha de puesta en uso: [PENDIENTE]
- Dispositivos actualizados: [PENDIENTE]
