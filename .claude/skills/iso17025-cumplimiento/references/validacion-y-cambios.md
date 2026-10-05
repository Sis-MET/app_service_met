# Validación de versiones y control de cambios

Cierra 7.11.2: el sistema se valida antes de ponerse en uso, y cada cambio se
autoriza, documenta y valida antes de implementarse. También aporta a 7.11.6
(cálculos y transferencias verificados).

## Contenido

1. Qué hay que validar y qué no
2. Clasificación de cambios
3. Evidencias por tipo de cambio
4. Registro de validación (plantilla)
5. CHANGELOG
6. Flujo de liberación

---

## 1. Qué hay que validar y qué no

- **Se considera validado** el software comercial de uso general dentro de su
  campo previsto: Android, SQLite, Flutter y Dart como plataforma, SQL Server,
  Node.js. Basta con identificar las versiones usadas.
- **Hay que validar** todo el código propio: la app, la API del backend, los
  scripts SQL y el generador de esquema. Las bibliotecas de terceros que
  **procesan datos metrológicos** (por ejemplo, el OCR de ML Kit que lee el
  indicador) se validan en el uso concreto que se les da, con datos de prueba
  como los de `test/fixtures/indicators`.

## 2. Clasificación de cambios

Clasifica cada versión por su cambio de mayor impacto:

| Clase | Cambios que la definen | Validación mínima |
|---|---|---|
| **A: crítico** | Cálculos, redondeos, unidades; qué datos se capturan o cómo se guardan; esquema local o del servidor; subida, importación y exportación; login, permisos y seguridad; historial y anulación | Pruebas automáticas completas más casos funcionales con datos de referencia, prueba de ida y vuelta contra DataMET y prueba de migración con datos existentes |
| **B: funcional** | Flujo o pantallas sin cambiar datos ni cálculos; nuevas validaciones de entrada; notificaciones | Pruebas automáticas completas más una verificación funcional del flujo tocado; revisar el manual |
| **C: menor** | Textos, estilos, dependencias sin efecto funcional, compilación | Pruebas automáticas completas |

Los mensajes de commit del proyecto ya distinguen `feat`, `fix` y `chore` con
ámbito (por ejemplo, `fix(subida): …`); úsalos para armar la lista de cambios,
pero la clase la decide el impacto sobre los datos, no el prefijo.

## 3. Evidencias por tipo de cambio

- **Pruebas automáticas**: salida de `flutter test` (en la raíz) y de
  `pnpm test` (en `backend/`), con fecha, commit y resumen de aprobadas y
  fallidas. Si alguna falla, la versión no se libera o la falla se justifica
  por escrito.
- **Casos funcionales con datos de referencia** (clase A): por ejemplo, una
  calibración con lecturas conocidas cuyos resultados se contrastan con la hoja
  de cálculo validada del laboratorio o con un cálculo manual documentado.
  Registra la entrada, el resultado esperado, el obtenido y la conclusión.
- **Ida y vuelta** (clase A que toque la subida): capturar, subir y consultar
  la fila en DataMET; comparar campo por campo lo capturado con lo almacenado,
  con especial atención a decimales, fechas y textos largos.
- **Migración** (clase A que toque el esquema local): instalar la versión
  nueva sobre la anterior con datos reales anonimizados o de prueba y verificar
  que no se pierde nada. Las migraciones del proyecto añaden columnas con
  `PRAGMA table_info` + `ALTER TABLE`; verifica que los registros existentes
  siguen abriendo, editándose y subiéndose.
- **Scripts SQL**: ejecutados primero en `DataMET_prueba`, conservando la
  salida de verificación que imprimen.

## 4. Registro de validación (plantilla)

Guárdalo como `docs/iso17025/validaciones/VAL-<versión>.md`, por ejemplo
`VAL-6.3.3+15.md`.

```markdown
# Registro de validación — ServiceMET <versión>

| Campo | Valor |
|---|---|
| Versión (pubspec) | 6.3.3+15 |
| Commit | bf004af |
| Versión anterior en uso | 6.3.2+14 |
| Fecha de validación | AAAA-MM-DD |
| Clase del cambio | A / B / C |
| Validó (desarrollo) | Nombre |
| Entorno | Flutter x.y, Dart x.y, Node x.y, dispositivo y versión de Android, servidor de prueba |

## Cambios incluidos
| Commit | Descripción | Clase | Impacto en datos / registros | Incidencia relacionada |
|---|---|---|---|---|

## Pruebas automáticas
| Suite | Comando | Resultado | Observaciones |
|---|---|---|---|
| App | flutter test | NN aprobadas / 0 fallidas | |
| Backend | pnpm test | NN aprobadas / 0 fallidas | |

## Casos funcionales (clase A/B)
| ID | Objetivo | Datos de entrada | Resultado esperado | Resultado obtenido | Conforme |
|---|---|---|---|---|---|

## Verificaciones adicionales
- [ ] Ida y vuelta contra DataMET (si aplica)
- [ ] Migración sobre la versión anterior con datos existentes (si aplica)
- [ ] Manual de uso actualizado o confirmado vigente (revisión: __)
- [ ] Scripts SQL ejecutados en prueba (si aplica)

## Problemas conocidos y restricciones de uso
<o "Ninguno">

## Decisión
- [ ] Liberada para uso  - [ ] No liberada
- Autorizó (responsable técnico o de calidad del laboratorio): Nombre, cargo, fecha
- Fecha de puesta en uso: AAAA-MM-DD
- Dispositivos actualizados: <lista o referencia>
```

Cuando pidan preparar este registro, completa tú lo que sale del repositorio:
versión, commits, clasificación propuesta, impacto en datos y resultados de las
pruebas si puedes ejecutarlas. Deja como `[PENDIENTE]` lo que solo puede aportar
el laboratorio: autorización, fechas de puesta en uso, dispositivos y casos con
datos de referencia que no puedas reproducir. Nunca marques una prueba como
aprobada sin haberla ejecutado o sin ver su resultado.

## 5. Historial de versiones (CHANGELOG)

Vive en `lib/screens/calidad/data/historial_versiones.dart`, se ve en Otros
> "Historial de versiones" y se exporta en PDF. Mientras se desarrolla, cada
cambio relevante se anota en `cambiosSinLiberar`. Al subir la versión en
`pubspec.yaml`:

1. Crea una `VersionApp` al principio de `historialVersiones`, con versión y
   build exactos, fecha, commit, `ClaseCambio`, resumen, listas `nuevo` y
   `corregido` e `impactoRegistros`.
2. Vacía `cambiosSinLiberar`.
3. Cuando exista el registro de validación, completa `validacion` (por
   ejemplo, `'VAL-6.4.0+16'`). La app muestra "Registro de validación
   pendiente" hasta entonces.
4. Actualiza `version` y `fecha` de `evaluacionCumplimiento` tras revisar la
   matriz.

`calidad_datos_test.dart` falla si la primera entrada del historial no coincide
con `pubspec.yaml`, o si el orden de versiones o fechas no es descendente.

Redacta para el laboratorio, no para programadores: qué cambia para el técnico
y para los registros. Construye la lista con
`git log <versión anterior>..<versión nueva> --oneline`; las versiones se marcan
con commits `chore: versión X`.

## 6. Flujo de liberación

1. Terminar los cambios con sus pruebas.
2. Subir la versión en `pubspec.yaml` (commit `chore: versión X`).
3. Ejecutar las pruebas y reunir las evidencias según la clase.
4. Completar `VAL-<versión>.md` y pasar `cambiosSinLiberar` a una nueva
   entrada de `historialVersiones`.
5. Revisar o actualizar el manual de uso.
6. Autorización del laboratorio y registro de la fecha de puesta en uso.
7. Distribuir la versión a los dispositivos. Un dispositivo con una versión no
   liberada es un hallazgo: conviene poder ver qué versión tiene cada técnico
   (por ejemplo, enviando `app_version` en el login o en la subida).
