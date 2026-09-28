# Manual de uso de ServiceMET

Cierra 7.11.5 (instrucciones y manuales disponibles para el personal) y aporta
a 7.11.3 c) (entorno de operación especificado). El manual es un **documento
controlado** según 8.3.

## Contenido

1. Dónde vive y cómo llega al técnico
2. Cómo escribirlo
3. Encabezado de control
4. Índice propuesto
5. Mantenerlo vigente

---

## 1. Dónde vive y cómo llega al técnico

Ya está implementado:

- **Fuente**: `lib/screens/calidad/data/manual_servicemet.dart`. Es un
  `ManualUso` con su `ControlDocumento` (código, revisión, fecha, "Aplica a",
  elaboró, revisó, aprobó e historial) y secciones formadas por bloques
  `Parrafo`, `Pasos`/`Paso`, `Lista` y `Nota` (consejo, importante o norma, con
  la cláusula). Los modelos están en `lib/screens/calidad/models/manual.dart`.
- **Dentro de la app**: Ajustes > "Manual de uso" (`manual_screen.dart`), sin
  conexión, con búsqueda que resalta el texto, pasos que se marcan al
  completarlos y navegación entre secciones.
- **Copia controlada**: se exporta en PDF desde la propia pantalla
  (`CalidadPdf.manualDeUso`, con el bloque de control y el historial de
  revisiones). Calidad firma y archiva esa copia.
- Mientras `aprobo` empiece por "PENDIENTE", la app muestra "Pendiente de
  aprobación". Al aprobarse, completa el control, sube la revisión y agrega
  la entrada al historial.
- Una prueba exige que "Aplica a" coincida con la versión menor de
  `pubspec.yaml`: al pasar, por ejemplo, a 6.4, hay que revisar el manual.

Para agregar o cambiar contenido, edita el archivo de datos. No hace falta
tocar la UI: los tipos de bloque cubren pasos, listas y notas.

## 2. Cómo escribirlo

- **Desde el código, no de memoria.** Los nombres de botones, pasos y mensajes
  se toman de los textos reales de las pantallas (`lib/screens/**`,
  `lib/home/**`, `lib/login/**`). Si el manual dice "Pulse Finalizar" y la app
  dice "Terminar servicio", el evaluador lo nota.
- **Para quien lo usa.** El lector es un técnico de calibración en planta, no
  un programador: frases cortas, pasos numerados, una captura por pantalla
  clave.
- **Qué registrar y cuándo.** Además del "cómo", en cada paso de captura
  indica qué dato es observación original, cuándo debe registrarse (en el
  momento) y qué hacer si se equivoca (corrección con motivo, no borrar).
- **Remite a los procedimientos técnicos.** El manual explica la herramienta,
  no el método de calibración: para eso, remite al procedimiento del
  laboratorio `[PENDIENTE: código]`.
- **Capturas**: si se necesitan, se pueden tomar ejecutando la app (skill
  `run`) o pedirlas al usuario. No inventes pantallas.

## 3. Encabezado de control

En la app vive en `ControlDocumento`; esta es su forma en un documento:

```markdown
| Código | [PENDIENTE: código asignado por Calidad] |
|---|---|
| Título | Manual de uso de ServiceMET |
| Revisión | 00 |
| Fecha de emisión | AAAA-MM-DD |
| Aplica a la versión de la app | 6.3.3+15 (o "6.3.x") |
| Elaboró | Nombre, cargo |
| Revisó | Nombre, cargo |
| Aprobó | Nombre, cargo |

### Historial de revisiones
| Rev. | Fecha | Descripción del cambio | Versión de la app |
|---|---|---|---|
| 00 | AAAA-MM-DD | Emisión inicial | 6.3.3+15 |
```

## 4. Índice propuesto

1. **Objetivo y alcance**: servicios cubiertos. Calibración de balanzas
   (`CAL.BL`) y soporte: mantenimiento preventivo regular (`MPR.BL`),
   preventivo avanzado (`MPA.SP`), correctivo (`MCR.BL`), diagnóstico
   (`DIG.BL`), verificaciones internas (`VIN.SP`), relevamiento de datos
   (`REL.BL`), instalación (`INS.BL`) y ajuste y verificaciones (`IBM.BL`).
   Confirma las siglas en `backend/src/schema.js`.
2. **Referencias**: NB/ISO/IEC 17025, procedimiento de calibración, de control
   de registros y de incidencias del laboratorio.
3. **Definiciones**: SECA, código métrica, sesión, precarga, patrón, balanza
   nueva, subida.
4. **Requisitos de uso (entorno, 7.11.3 c)**: dispositivo y versión mínima de
   Android (`minSdk` en `android/app/build.gradle*`), permisos que pide la app
   (cámara, notificaciones, biometría), red interna o VPN, cuenta habilitada
   (`acceso_app`).
5. **Configuración inicial**: perfil de conexión y credenciales
   (`initial_setup_screen.dart`, `connection_step.dart`, `user_credentials_step.dart`).
6. **Inicio de sesión y responsabilidad de la cuenta**: contraseña, biometría,
   cuenta personal e intransferible, cierre de sesión.
7. **Precarga para trabajo sin conexión**: descargar y actualizar, cómo saber si
   está vigente, qué hacer con patrones vencidos o por vencer.
8. **Calibración paso a paso**, con una subsección por paso (según
   `lib/screens/calibracion/steps/`): cliente, planta, SECA, balanza, inspección
   visual, precargas y ajuste, excentricidad, repetibilidad, linealidad,
   condiciones finales y exportación. En cada una: qué registrar, observaciones
   originales, fotos y validaciones que pueden bloquear el guardado.
   - **Lector del indicador (OCR)**: cuándo usarlo, verificar siempre el valor
     leído contra el indicador y conservar la foto.
   - **Sugerencias y autollenado**: qué se completa solo y cómo confirmarlo.
9. **Servicios de soporte**, uno por módulo.
10. **Correcciones y anulaciones**: cómo corregir un dato (motivo obligatorio),
    qué queda en el historial, por qué no se borra y qué no se puede corregir
    tras la subida.
11. **Subida al servidor**: validar, interpretar errores, subir, balanzas
    nuevas y qué hacer si falla.
12. **Respaldo y restauración**: cuándo respaldar, dónde guardar la copia y cómo
    restaurar.
13. **Fotografías**: dónde se guardan, cómo verlas y compartirlas y su
    conservación.
14. **Reporte de incidencias**: cuándo reportar, cómo hacerlo y el formulario
    en papel si la app no funciona.
15. **Problemas frecuentes y mensajes de error**: tabla "mensaje → qué
    significa → qué hacer", a partir de los textos reales de la app.
16. **Anexos**: capturas y glosario.

## 5. Mantenerlo vigente

- **Cada cambio que altere un flujo o una pantalla descrita actualiza el manual
  en el mismo cambio.** Es un ítem de la revisión de cambios del `SKILL.md` y
  del registro de validación.
- Cada nueva revisión del manual incrementa "Revisión", actualiza el historial y
  pasa por la aprobación de Calidad antes de liberarse con la nueva versión
  de la app.
- Si el cambio de la app es solo interno (sin efecto visible), no hace falta una
  nueva revisión; basta con registrar en la validación que el manual sigue
  vigente.
