# Configuración de Bitrix24 para las oportunidades de ServiceMET

Guía para dejar funcionando el registro de oportunidades comerciales desde
Calibración y Soporte técnico hacia **CRM › Prospectos** del Bitrix24 de
METRICA.

En el Bitrix24 en español, **Prospectos** son los *Leads* (la URL es
`/crm/lead/kanban/`) y **Negociaciones** son los *Deals*. ServiceMET crea
cada oportunidad como un **Lead** en la primera etapa en curso de Prospectos
(normalmente la columna "Sin asignar"), vinculado a la empresa y al contacto
que elige el técnico.

```
ServiceMET (Flutter) ──HTTPS + JWT──▶ API METRICA (backend/) ──webhook──▶ Bitrix24 CRM › Prospectos
```

La app **nunca** conoce el webhook: solo habla con la API interna. El webhook
vive únicamente en `backend/.env`.

---

## 1. Antes de empezar

- Un usuario administrador del Bitrix24 de METRICA (o un usuario al que el
  administrador haya habilitado la creación de webhooks en
  **Configuración → Seguridad → Integraciones de Bitrix24**).
- Acceso al servidor de la API (`192.168.1.5`), donde está `backend/.env`.
- El servidor necesita salida a Internet por HTTPS (puerto 443) hacia el
  portal (`b24-….bitrix24.es`).

## 2. Usuario de integración

Los webhooks ejecutan cada llamada **con los permisos del usuario que los
creó**. Se recomienda:

1. Crear (o reutilizar) un usuario de integración, por ejemplo
   `integracion.servicemet@metrica.com.bo`, en lugar de una cuenta personal:
   si esa persona deja la empresa y se desactiva su cuenta, el webhook deja de
   funcionar.
2. Darle en **CRM → Configuración → Permisos de acceso** un rol que permita:
   - **Empresas**: leer (todas las que deban aparecer en la búsqueda).
   - **Contactos**: leer.
   - **Prospectos (Leads)**: leer y **agregar**.
3. Si no se indica otro responsable, los prospectos quedan asignados a este
   usuario (ver `BITRIX_LEAD_ASSIGNED_BY_ID`).

Si el usuario no ve una empresa, tampoco aparecerá en la búsqueda de la app.

## 3. Crear el webhook entrante

1. Ingresar al Bitrix24 de METRICA **con el usuario de integración**.
2. En la barra lateral: **Aplicaciones → Recursos para desarrolladores →
   Otros → Webhook entrante**. Si la opción no aparece o Bitrix muestra un
   aviso de plan, el usuario no tiene permiso o el plan no lo incluye.
3. En **Permisos** marcar **solo `CRM (crm)`**.
4. Nombre sugerido: `ServiceMET - oportunidades`.
5. **Guardar**. Bitrix24 muestra una URL con esta forma:

   ```
   https://b24-xxxxxx.bitrix24.es/rest/USUARIO/SECRETO/
   ```

   Esa URL **es la credencial**. Quien la tenga puede operar el CRM con los
   permisos del usuario de integración.

## 4. Guardar el webhook: `.env` y `.env.example`

`backend/` tiene dos archivos con nombres parecidos y funciones distintas:

| Archivo | Qué es | ¿Va a Git? |
|---------|--------|-----------|
| `.env.example` | Plantilla con **todas** las variables y valores de ejemplo, sin secretos. Sirve para saber qué hay que configurar. | Sí |
| `.env` | El archivo **real** que leen la API y `pnpm bitrix:discover`, con contraseñas y el webhook. | **Nunca** (está en `.gitignore`) |

Ni la API ni el script leen `.env.example`. Por eso, mientras solo exista la
plantilla, el script responde "Falta BITRIX_WEBHOOK_URL".

**En el servidor de la API** ya existe `backend/.env` (con SQL, JWT y TLS).
Agregue al final:

```
BITRIX_WEBHOOK_URL=https://b24-xxxxxx.bitrix24.es/rest/USUARIO/SECRETO/
```

**Para probar solo el webhook desde su PC**, cree `backend/.env` con esa única
línea: `pnpm bitrix:discover` no necesita el resto. (Para `pnpm start` sí
hacen falta las variables de SQL y JWT.)

Si la URL se filtra: en Bitrix24, en la misma pantalla del webhook,
**regenerar el código** (o eliminarlo y crear otro) y actualizar `.env`.

## 5. Verificar paso a paso

En `backend/`:

```
pnpm bitrix:discover
```

El script recorre, en orden, las pruebas recomendadas y **nunca imprime el
secreto**:

| Paso | Método | Qué comprobar |
|------|--------|---------------|
| 1 | `crm.item.list` (`entityTypeId=4`) | Aparecen empresas. Para buscar: `pnpm bitrix:discover -- --empresa "embol"` |
| 2 | `crm.company.contact.items.get` + `crm.item.list` (`entityTypeId=3`) | Aparecen los contactos de la primera empresa |
| 3 | `crm.status.list` (`ENTITY_ID=STATUS`) | Las columnas de Prospectos con su ID; marca dónde nacerán las oportunidades |
| 4 | `crm.status.list` (`ENTITY_ID=SOURCE`) | Las fuentes, por si quiere fijar una |
| 5 | `crm.item.fields` (`entityTypeId=1`) | `originatorId` y `originId` figuran como disponibles; lista los campos personalizados |

Si algún paso muestra `ERROR`:

| Código | Causa probable |
|--------|----------------|
| `BITRIX_AUTH_ERROR` | URL mal copiada o webhook eliminado/regenerado |
| `BITRIX_ACCESS_DENIED` / `BITRIX_METHOD_NOT_FOUND` | El webhook no tiene el permiso `crm` o el usuario no tiene permisos de CRM |
| `BITRIX_STAGE_NOT_FOUND` | La etapa de `BITRIX_LEAD_STAGE_ID` no existe, o el CRM está en modo simple (sin Prospectos) |
| `BITRIX_UNAVAILABLE` / `BITRIX_TIMEOUT` | Sin salida a Internet hacia el portal |

Finalmente, crear un prospecto de prueba con una empresa real (el ID aparece
en el paso 1, o en la URL de la empresa en Bitrix24: `/crm/company/details/ID/`):

```
pnpm bitrix:discover -- --crear-prueba --empresa-id 120 --contacto-id 55
```

Abrirlo en **CRM › Prospectos** y comprobar columna, empresa, contacto,
fuente "ServiceMET" y cómo se ve el comentario. Si el comentario muestra
etiquetas o todo en una sola línea, cambie `BITRIX_COMMENTS_FORMAT` a
`bbcode` o `html` y repita. Luego **elimine el prospecto de prueba**.

## 6. Etapa, fuente y responsable (opcionales)

Sin configuración, la API usa la primera etapa en curso de Prospectos
("Sin asignar"). Para fijarla, o para elegir fuente y responsable, copie los
valores que imprimió el script:

```
BITRIX_LEAD_STAGE_ID=NEW
BITRIX_LEAD_SOURCE_ID=
BITRIX_LEAD_ASSIGNED_BY_ID=
```

La API comprueba que la etapa exista antes de usarla. No invente valores.

**Fuente "ServiceMET" (decidido para METRICA).** Para distinguir en los
reportes lo que llega desde campo:

1. En Bitrix24, abrir la configuración del CRM y la lista de **Fuentes**
   (según la versión: *CRM → ⚙ Configuración → Configuración del CRM →
   Listas de selección / Estados y listas desplegables → Fuentes*).
2. Agregar la fuente `ServiceMET` y guardar. Debe hacerlo un administrador:
   el webhook no puede crearla (Bitrix24 responde "Access denied").
3. Ejecutar `pnpm bitrix:discover`: en el paso 4 aparece con su ID (del tipo
   `UC_XXXXXX`). Copiarlo en `BITRIX_LEAD_SOURCE_ID`.

Sin fuente configurada, Bitrix24 asigna la primera de su lista (en METRICA,
"Email"), lo que confunde los reportes.

## 7. Campos personalizados (cuando existan)

Mientras no se configure un campo, el dato viaja ordenado dentro del
**comentario** del prospecto, así que no se pierde nada. Para usar campos
propios:

1. En **CRM › Prospectos**, abrir un prospecto y usar "Crear campo" (o la
   configuración de campos de Prospectos). Tipo **Cadena**, o **Lista** para
   tipo de oportunidad y prioridad, con exactamente los mismos textos que usa
   la app. Sugeridos: *SECA/OTST, Planta, Código métrica, Marca, Modelo,
   Serie, Capacidad, División, Tipo de servicio, Técnico ServiceMET, Tipo de
   oportunidad, Prioridad, ServiceMET UUID*.
2. Ejecutar `pnpm bitrix:discover` y copiar el ID real de cada campo (paso 5,
   forma `ufCrm_...`).
3. Completar en `.env` solo los que existan, por ejemplo:

   ```
   BITRIX_FIELD_SECA=ufCrm_1712345678
   BITRIX_FIELD_CODIGO_METRICA=ufCrm_1712345690
   ```

4. Reiniciar la API y volver a ejecutar el script: el bloque "Mapeo
   configurado" debe decir `OK` en cada campo.

Si un campo configurado no existe, es de solo lectura o de un tipo que no
admite texto (número, fecha…), la API no lo inventa: registra un aviso y deja
el dato en el comentario.

### Campos del Bitrix24 de METRICA (verificados con el script, 29/09/2026)

| Campo en Prospectos | Variable | Qué envía ServiceMET |
|---|---|---|
| TIPO DE OPORTUNIDAD (`ufCrm_1790601080`) | `BITRIX_FIELD_TIPO_OPORTUNIDAD` | La línea del tipo elegido: VENTA, SOPORTE TECNICO o CALIBRACIÓN. El detalle (p. ej. "Reemplazo de indicador") va en el título y el comentario. |
| Ciudad del prospecto (`ufCrm_LEAD_1790626227373`), **obligatorio** | `BITRIX_FIELD_CIUDAD` | La ciudad elegida por el técnico o, si la deja en "Automática", la del departamento de la planta (reconoce "LA PAZ", "LPZ", "SCZ", "CBBA", "Chuquisaca" → Sucre, etc.). |
| MES DE SERVICIO USUAL (`ufCrm_1735591283504`) | `BITRIX_FIELD_MES_SERVICIO` | El mes del servicio en curso. |

Como "Ciudad del prospecto" es obligatorio, **sin `BITRIX_FIELD_CIUDAD` la
API no puede crear prospectos** y responde `BITRIX_REQUIRED_FIELD`. Si la
ciudad no se puede deducir, la app pide elegirla.

Si alguien cambia las opciones de estas listas en Bitrix24, no hace falta
tocar la app: las ciudades se descargan solas y una línea que ya no exista
queda en el comentario.

## 8. Reiniciar la API y probar desde la app

1. Reiniciar el servicio de la API. En el arranque debe verse
   `Bitrix24 habilitado en b24-….bitrix24.es.`
2. En la app, cerrar sesión e ingresar de nuevo (el nuevo token incluye el
   permiso `bitrix:opportunity`; si no, la app pide la contraseña al primer
   uso).
3. Abrir una calibración o un servicio de soporte, tocar ⋮ ›
   **Registrar oportunidad comercial** en el encabezado y completar el
   formulario.

## Duplicados

Cada oportunidad lleva un UUID generado en el teléfono. La API lo guarda en
los campos estándar del Lead `originatorId = SERVICEMET` y `originId = UUID`
y, antes de crear, busca si ya existe. Así, reenviar una oportunidad
pendiente (por ejemplo, después de perder la conexión en medio del envío) no
crea un segundo prospecto. Solo desactive `BITRIX_DEDUPE_BY_ORIGIN` si el
paso 5 indica que esos campos no están disponibles.
