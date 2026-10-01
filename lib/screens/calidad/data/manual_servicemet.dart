import 'package:flutter/material.dart';

import '../models/manual.dart';

/// Manual de uso de ServiceMET (NB/ISO/IEC 17025 7.11.5).
///
/// Los nombres de botones y pantallas se copian de la app tal como los ve el
/// técnico. Cuando un cambio altere un flujo descrito aquí, actualice la
/// sección correspondiente en el mismo cambio y registre la nueva revisión en
/// [ControlDocumento.historial].
const manualServiceMet = ManualUso(
  control: ControlDocumento(
    codigo: 'PENDIENTE: código asignado por Calidad',
    titulo: 'Manual de uso de ServiceMET',
    revision: '00 (borrador)',
    fechaEmision: '2026-09-28',
    aplicaA: '6.3.x',
    elaboro: 'Desarrollo ServiceMET',
    reviso: 'PENDIENTE',
    aprobo: 'PENDIENTE',
    historial: [
      RevisionDocumento('00', '2026-09-28', 'Emisión inicial (borrador).'),
    ],
  ),
  secciones: [
    // ── Primeros pasos ──────────────────────────────────────────────────
    SeccionManual(
      id: 'introduccion',
      grupo: GrupoManual.primerosPasos,
      titulo: 'Acerca de ServiceMET',
      icono: Icons.info_outline_rounded,
      resumen: 'Qué hace la app, qué servicios cubre y cómo viajan los datos.',
      bloques: [
        Parrafo('ServiceMET es la herramienta con la que los técnicos del '
            'laboratorio registran en campo las calibraciones de balanzas y '
            'los servicios de soporte técnico. Funciona sin conexión: los '
            'datos se guardan en el teléfono y después se validan y suben a '
            'la base del laboratorio (DataMET).'),
        Lista('Servicios que cubre', [
          'Calibración de balanzas (CAL.BL).',
          'Mantenimiento preventivo regular (MPR.BL) y avanzado (MPA.SP).',
          'Mantenimiento correctivo (MCR.BL) y diagnóstico (DIG.BL).',
          'Verificaciones internas (VIN.SP) y relevamiento de datos (REL.BL).',
          'Instalación (INS.BL) y ajuste de verificaciones (IBM.BL).',
        ]),
        Pasos('Recorrido de los datos', [
          Paso(
              'Precarga',
              'Antes de salir se descargan clientes, plantas, '
                  'balanzas y patrones al teléfono.'),
          Paso(
              'Captura',
              'En planta, el técnico registra cada dato en el '
                  'momento en que lo observa.'),
          Paso(
              'Validación',
              'El servidor revisa el lote sin guardar nada y '
                  'señala lo que falta corregir.'),
          Paso(
              'Subida',
              'Los registros válidos se guardan en DataMET, que '
                  'asigna el código de registro definitivo.'),
        ]),
        Nota(
          TipoNota.norma,
          'Lo que se registra en la app son registros técnicos del '
          'laboratorio: deben reflejar lo observado, en el momento, y por '
          'quien lo observó.',
          referencia: '7.5.1',
        ),
      ],
    ),
    SeccionManual(
      id: 'requisitos',
      grupo: GrupoManual.primerosPasos,
      titulo: 'Antes de empezar',
      icono: Icons.checklist_rounded,
      resumen: 'Teléfono, permisos, red y cuenta que necesita.',
      bloques: [
        Lista('Necesita', [
          'Un teléfono Android autorizado por el laboratorio, con cámara y '
              'bloqueo de pantalla activado.',
          'La versión de ServiceMET liberada por el laboratorio (se ve en '
              'Ajustes).',
          'Una cuenta personal habilitada para ServiceMET.',
          'Acceso a la red interna o a la VPN del laboratorio para vincular '
              'la cuenta, descargar la precarga y subir datos.',
        ]),
        Lista('Permisos que pide la app', [
          'Cámara: fotografías de evidencia, lectura de códigos QR y lectura '
              'del indicador.',
          'Notificaciones: avisos de servicios pendientes y vencimientos.',
          'Huella o rostro (opcional): acceso rápido sin escribir la '
              'contraseña.',
        ]),
        Nota(
          TipoNota.importante,
          'La cuenta es personal e intransferible. Todo lo que se registra '
          'queda a nombre del usuario que inició la sesión.',
        ),
        Nota(
          TipoNota.norma,
          'El laboratorio define el entorno en el que se usa el sistema: '
          'dispositivos, versión instalada y red.',
          referencia: '7.11.3 c',
        ),
      ],
    ),
    SeccionManual(
      id: 'acceso',
      grupo: GrupoManual.primerosPasos,
      titulo: 'Configuración inicial e inicio de sesión',
      icono: Icons.login_rounded,
      resumen: 'Vincular la cuenta, ingresar y activar el acceso biométrico.',
      bloques: [
        Pasos('Primera vez en el teléfono', [
          Paso('Conéctese a la red interna o a la VPN del laboratorio.',
              'La vinculación indica "Requiere conexión al servidor".'),
          Paso(
              'Elija el perfil de conexión.',
              'Si el servidor no responde, use "Configurar servidor" y '
                  'seleccione Red Local o VPN.'),
          Paso('Escriba su usuario y su contraseña.'),
          Paso('Pulse "Vincular usuario" o "Ingresar".'),
          Paso('Decida si activa el acceso biométrico.',
              'En "Acceso rápido y seguro" elija "Habilitar" o "Ahora no".'),
        ]),
        Pasos('Uso diario', [
          Paso('Abra la app y confirme su usuario.'),
          Paso(
              'Ingrese con la contraseña o con la huella.',
              'Para entrar con otra cuenta use "Cambiar usuario" o '
                  '"Vincular otro usuario".'),
        ]),
        Nota(
          TipoNota.consejo,
          'Después de vincularse puede ingresar sin conexión. La conexión solo '
          'se necesita para descargar la precarga y subir datos.',
        ),
        Nota(
          TipoNota.importante,
          'Tras varios intentos fallidos, el servidor bloquea temporalmente '
          'el inicio de sesión. Espere unos minutos antes de reintentar.',
        ),
      ],
    ),
    SeccionManual(
      id: 'navegacion',
      grupo: GrupoManual.primerosPasos,
      titulo: 'Conociendo la app',
      icono: Icons.explore_outlined,
      resumen: 'Inicio, Servicios, Precarga y Ajustes.',
      bloques: [
        Lista('Barra inferior', [
          'Inicio: resumen de la actividad local, pendientes de subir y '
              'servicios guardados en el teléfono.',
          'Servicios: aquí se empieza una calibración o un servicio de '
              'soporte, y se revisan y envían los formularios adicionales '
              '(RIM y oportunidades comerciales).',
          'Precarga: descarga de datos para trabajar sin conexión y '
              'vencimientos.',
        ]),
        Lista('En Inicio', [
          'Tarjetas de resumen: balanzas calibradas, servicios de soporte y '
              'pendientes de subir.',
          '"Pendientes por SECA": lleva directo a subir cada servicio.',
          '"Actividad local": servicios guardados, separados en Calibración '
              'y Soporte Técnico.',
          'El engranaje de la parte superior abre Ajustes.',
        ]),
        Lista('En Ajustes', [
          'Apariencia: tema claro u oscuro y tamaño del texto.',
          'Respaldo de datos y conexión al servidor.',
          'Calidad y normativa: cumplimiento, este manual e historial de '
              'versiones.',
          'La versión instalada, al final de la pantalla.',
        ]),
        Lista('Dentro de una calibración o un servicio de soporte', [
          'Bajo el título se ve el paso actual ("Paso 3 de 11 · SECA").',
          '≡, arriba a la izquierda, abre la lista de pasos: los completos '
              'llevan ✓, los que quedaron sin completar llevan "!" y los que '
              'todavía no se pueden abrir, un candado. Toque un paso para ir '
              'a él.',
          '"Anterior" y el gesto Atrás del teléfono retroceden un paso. '
              'Nunca sacan del servicio: un gesto accidental no interrumpe el '
              'trabajo.',
          'Para salir a medias use ⋮ › "Salir (queda guardado)". Lo '
              'registrado queda en el teléfono y se continúa desde Servicios.',
          '⋮ › "Registrar oportunidad comercial" envía una oportunidad a '
              'Bitrix24 sin dejar el servicio.',
          '⋮ › "Emitir RIM (recepción de instrumento)" deja constancia, con '
              'la firma del cliente, del estado en que se recibe una balanza.',
        ]),
      ],
    ),
    SeccionManual(
      id: 'precarga',
      grupo: GrupoManual.primerosPasos,
      titulo: 'Precarga para trabajar sin conexión',
      icono: Icons.cloud_download_outlined,
      resumen: 'Descargar clientes, plantas, balanzas y patrones.',
      bloques: [
        Pasos(null, [
          Paso('Conéctese a la red del laboratorio.'),
          Paso('Abra la pestaña Precarga y pulse "Actualizar datos".'),
          Paso(
              'Espere a que termine la descarga.',
              'La app confirma con "Datos precargados exitosamente" y muestra '
                  'cuántos clientes, plantas y equipos descargó.'),
          Paso(
              'Revise Vencimientos.',
              'Allí aparecen los patrones y las balanzas vencidos o por '
                  'vencer.'),
        ]),
        Nota(
          TipoNota.consejo,
          'Actualice la precarga antes de cada salida a planta. Así trabaja con '
          'los patrones y los certificados vigentes.',
        ),
        Nota(
          TipoNota.norma,
          'El personal debe tener acceso a los datos que necesita para '
          'trabajar, también en campo.',
          referencia: '7.11.1',
        ),
      ],
    ),

    // ── Servicios ───────────────────────────────────────────────────────
    SeccionManual(
      id: 'calibracion',
      grupo: GrupoManual.servicios,
      titulo: 'Calibración de balanzas',
      icono: Icons.scale_outlined,
      resumen: 'El asistente paso a paso, de Cliente a Finalizar.',
      bloques: [
        Parrafo('Abra Servicios y elija Calibración. Si había una calibración '
            'sin terminar, la app pregunta si desea "Continuar" o "Descartar '
            'y crear otro". El asistente avanza con el botón inferior '
            '("Siguiente", "Confirmar SECA" o "Guardar Datos") y guarda '
            'automáticamente.'),
        Pasos('Pasos del asistente', [
          Paso(
              'Cliente y Planta',
              'Selecciónelos de la precarga o escanee '
                  'el código QR.'),
          Paso(
              'SECA',
              'Ingrese la SECA y pulse "Confirmar SECA". Desde ese '
                  'momento, todas las balanzas del servicio quedan asociadas a '
                  'ella.'),
          Paso(
              'Instrumento',
              'Seleccione la balanza (o identifíquela por QR), '
                  'revise su información y pulse "Guardar Datos". Si la balanza '
                  'no está en la precarga, regístrela como nueva.'),
          Paso(
              'Inspección visual',
              'La hora de inicio se toma del reloj. '
                  'Registre el estado de la balanza y del entorno (vibración, '
                  'polvo, temperatura, humedad, mesada, iluminación) con fotos '
                  'y comentarios. "Establecer todo en Buen Estado" marca todo de '
                  'una vez; revise cada punto antes de usarlo.'),
          Paso('Precarga/Ajuste', 'Registre las precargas y si hubo ajuste.'),
          Paso(
              'Excentricidad, Repetibilidad y Linealidad',
              'Registre cada '
                  'lectura en el momento en que la observa. En linealidad elija '
                  'el método de carga.'),
          Paso(
              'Final',
              'Registre las condiciones finales, la hora de fin y '
                  'las pesas patrón utilizadas. La app muestra la vigencia de '
                  'cada certificado y avisa si alguno está vencido.'),
          Paso(
              'Finalizar',
              'Revise "Revisión de esta balanza". Si faltan '
                  'datos, la app lo indica. Luego elija "SELECCIONAR OTRA BALANZA" '
                  'o "FINALIZAR SERVICIO".'),
        ]),
        Nota(
          TipoNota.importante,
          'Si aparece "Datos pendientes", corrija los campos listados antes de '
          'continuar. Si al salir (⋮ › "Salir (queda guardado)") no se pudo '
          'guardar, la app pregunta "Corregir" o "Salir sin guardar".',
        ),
        Nota(
          TipoNota.norma,
          'Registre las lecturas en el momento en que las observa, no al '
          'final del servicio. Con un patrón vencido, consulte al responsable '
          'técnico antes de seguir.',
          referencia: '7.5.1',
        ),
      ],
    ),
    SeccionManual(
      id: 'lector-indicador',
      grupo: GrupoManual.servicios,
      titulo: 'Leer el indicador con la cámara',
      icono: Icons.document_scanner_outlined,
      resumen: 'Captura asistida de lecturas de displays de 7 segmentos.',
      bloques: [
        Parrafo('Funciona en calibración y en las pruebas metrológicas de '
            'soporte técnico (excentricidad, repetibilidad y linealidad, '
            'incluida la carga sustitutiva): en indicaciones y retornos, el '
            'teclado numérico de la app ofrece "Leer del indicador". Las '
            'cargas se escriben a mano.'),
        Pasos(null, [
          Paso('Toque el campo de la lectura.',
              'Se abre el teclado numérico de la app.'),
          Paso('Pulse "Leer del indicador".'),
          Paso('Encuadre el display de la balanza.',
              'En lugares oscuros use "Encender linterna".'),
          Paso('Compare el valor leído con el indicador.',
              'Si no coincide, pulse "Reintentar" o escríbalo a mano.'),
          Paso('Confirme el valor y continúe con "Siguiente".'),
        ]),
        Nota(
          TipoNota.importante,
          'La lectura automática es una ayuda. El técnico es responsable de '
          'que el valor registrado sea el que muestra el indicador.',
        ),
        Nota(
          TipoNota.norma,
          'Una ayuda de captura no reemplaza la observación original: lo que '
          'queda registrado debe ser lo que el técnico vio y confirmó.',
          referencia: '7.5.1',
        ),
      ],
    ),
    SeccionManual(
      id: 'soporte',
      grupo: GrupoManual.servicios,
      titulo: 'Servicios de soporte técnico',
      icono: Icons.build_outlined,
      resumen: 'Mantenimientos, diagnóstico, verificaciones e instalación.',
      bloques: [
        Pasos('Iniciar un servicio', [
          Paso(
              'Abra Servicios y elija Soporte técnico.',
              'Si hay uno sin terminar, la app ofrece "Continuar" o '
                  '"Descartar y crear otro".'),
          Paso('En "Tipo de Servicio", elija la modalidad a ejecutar.'),
          Paso('Seleccione Cliente, Planta, OTST e Instrumento.',
              'Puede escanear el código QR del instrumento.'),
          Paso('En el Resumen, pulse "Confirmar datos".',
              '"Verifique todos los datos precargados antes de iniciar".'),
        ]),
        Pasos('Durante el servicio', [
          Paso(
              'Complete cada paso del módulo con estados, fotos y '
                  'comentarios.',
              'Como en la calibración, se avanza solo con el paso completo y '
                  'guardado en el teléfono, y un paso adelante se abre solo '
                  'con los anteriores completos. Si falta algo, la app dice '
                  'qué y lleva a ese paso.'),
          Paso(
              'En las pruebas metrológicas, escriba con el teclado de la app.',
              '"Siguiente" pasa al campo que sigue; en indicaciones y retornos '
                  'puede usar "Leer del indicador". Atrás o tocar fuera de un '
                  'campo cierran el teclado sin borrar lo escrito.'),
          Paso(
              'Registre todas las lecturas de cada prueba que realice.',
              'Excentricidad, repetibilidad y linealidad se exigen completas. '
                  'Si una prueba no se hizo, desmárquela; no la deje a medias.'),
          Paso('Use "Todo en buen estado" o "Marcar todo como No aplica" solo '
              'después de revisar cada punto.'),
          Paso('Al terminar, elija "SELECCIONAR OTRA BALANZA" o '
              '"FINALIZAR SERVICIO".'),
        ]),
        Nota(
          TipoNota.consejo,
          'Los comentarios admiten hasta 1000 caracteres: describa lo '
          'encontrado y lo realizado con el detalle necesario.',
        ),
      ],
    ),
    SeccionManual(
      id: 'oportunidades',
      grupo: GrupoManual.servicios,
      titulo: 'Registrar una oportunidad comercial',
      icono: Icons.handshake_outlined,
      resumen: 'Enviar a Bitrix24 una necesidad del cliente sin dejar el '
          'servicio.',
      bloques: [
        Parrafo('Si durante una calibración o un servicio de soporte detecta '
            'una necesidad comercial (reemplazo de equipo o de indicador, '
            'repuestos, reparación, accesorios, una cotización), regístrela '
            'como oportunidad en CRM › Prospectos de Bitrix24. Es '
            'opcional, no es un paso del servicio y no cambia ningún dato '
            'del registro técnico.'),
        Pasos('Registrar', [
          Paso(
              'En el encabezado del servicio, toque ⋮ › "Registrar '
                  'oportunidad comercial".',
              'Se abre "Nueva oportunidad" con el servicio, el cliente, la '
                  'planta y el equipo ya cargados.'),
          Paso(
              'En "Empresa Bitrix24", busque y elija la empresa.',
              'La app sugiere buscar con el nombre del cliente, pero en '
                  'Bitrix24 puede figurar distinto: elija siempre la empresa '
                  'correcta.'),
          Paso('Elija el contacto, o deje "Sin contacto".'),
          Paso(
              'Revise la "Ciudad del prospecto".',
              'En "Automática" se toma del departamento de la planta; elija '
                  'otra si corresponde. Si no se puede deducir, la app pide '
                  'elegirla.'),
          Paso(
              'Elija el "Tipo de oportunidad" y escriba la "Descripción".',
              'El título se arma solo y puede editarse. Bitrix24 recibe además '
                  'la línea (VENTA, SOPORTE TECNICO o CALIBRACIÓN) y el mes '
                  'del servicio. La prioridad y las observaciones son '
                  'opcionales.'),
          Paso(
              'Toque "Registrar oportunidad".',
              'Al terminar vuelve al mismo paso del servicio, con el número '
                  'de la oportunidad creada.'),
        ]),
        Pasos('Sin conexión', [
          Paso(
              'Si no hay conexión con el servidor o con Bitrix24, la '
                  'oportunidad queda guardada en el teléfono como pendiente.',
              'También puede tocar "Guardar pendiente" y elegir la empresa '
                  'más tarde.'),
          Paso(
              'Con conexión, abra Servicios › "Oportunidades comerciales" y '
                  'toque "Enviar" o "Enviar todas".',
              'Las pendientes nunca se envían solas. Reenviar no duplica la '
                  'oportunidad en Bitrix24.'),
        ]),
        Nota(
          TipoNota.importante,
          'La oportunidad llega a Bitrix24 con los datos del servicio y del '
          'equipo. Describa solo lo que el cliente necesita; no copie '
          'resultados de la calibración en la descripción.',
        ),
      ],
    ),
    SeccionManual(
      id: 'rim',
      grupo: GrupoManual.servicios,
      titulo: 'Recepción de instrumentos (RIM)',
      icono: Icons.inventory_2_outlined,
      resumen: 'Dejar constancia, con la firma del cliente, del estado de una '
          'balanza cuyo servicio no se puede concluir.',
      bloques: [
        Parrafo('El RIM (recepción de instrumentos de pesaje) registra en qué '
            'estado se recibe una balanza: qué componentes la acompañan, qué '
            'daños y suciedad presenta y por qué se recibe. Emítalo cuando la '
            'balanza presente un problema que impida concluir la calibración '
            'o el servicio de soporte, antes de pasar a otra balanza. No es '
            'un paso del servicio y no cambia sus datos.'),
        Pasos('Emitir', [
          Paso(
              'Con la balanza ya elegida, toque ⋮ › "Emitir RIM (recepción de '
                  'instrumento)".',
              'Se abre "Recepción de instrumento" con el código del RIM, el '
                  'servicio, el cliente, la planta y el instrumento ya '
                  'cargados: no se vuelven a escribir.'),
          Paso(
              'Paso 1, "Estado físico": marque el inventario de componentes.',
              'Cada componente puede quedar "Presente", "Faltante" o "N/A"; '
                  '"Marcar todos" los marca de una vez. En celdas y patas '
                  'anote la cantidad. Con "Agregar otro componente" incluya '
                  'lo que no esté en la lista.'),
          Paso(
              'Elija el estado general, los daños detectados con su ubicación '
                  'y el nivel de suciedad.',
              'El estado general y el nivel de suciedad son obligatorios.'),
          Paso('Paso 2, "Recepción y firma": escriba el "Motivo de la '
              'recepción" e indique si se realizaron pruebas de '
              'funcionamiento.'),
          Paso(
              'Escriba el nombre de quien entrega el instrumento y revise el '
                  '"Lugar de recepción".',
              'El representante de Métrica es el usuario con sesión iniciada; '
                  'no se escribe.'),
          Paso(
              'Toque "Tocar para firmar" y entregue el teléfono al cliente.',
              'La pantalla gira a horizontal. El cliente firma con el dedo; '
                  '"Limpiar" borra el trazo y "Aceptar firma" lo guarda.'),
          Paso(
              'Toque "Emitir RIM" y confirme.',
              'El RIM queda guardado en el teléfono. Desde "RIM emitido" '
                  'puede ver o compartir el PDF.'),
        ]),
        Pasos('Después de emitir', [
          Paso('"Seguir con esta balanza" vuelve al paso en el que estaba.',
              'Use esta opción si el servicio todavía puede continuar.'),
          Paso(
              '"Cambiar de balanza" cierra esta balanza sin concluir el '
                  'servicio.',
              'Lo registrado se conserva en el teléfono, pero no se sube como '
                  'servicio terminado. La app vuelve a la selección del '
                  'instrumento con el mismo cliente, planta y SECA u OTST.'),
        ]),
        Lista('Cuándo lo sugiere la app', [
          'Al salir de un servicio a medias (⋮ › "Salir (queda guardado)"), '
              'si la balanza todavía no tiene RIM.',
          'Al elegir "Descartar y crear otro" en una calibración o un '
              'servicio de soporte pendiente.',
        ]),
        Pasos('Subir, consultar y anular', [
          Paso('Abra Servicios › "Recepción de instrumentos (RIM)".',
              'Los RIM aparecen en "Por subir", "Subidos" y "Anulados".'),
          Paso(
              'Con conexión, toque "Subir" o "Subir todos".',
              'Los RIM nunca se suben solos. Volver a subir no duplica el RIM '
                  'en el servidor.'),
          Paso('"PDF" guarda, comparte o imprime el documento.',
              'Se guarda en la carpeta ServiceMET/RIM.'),
          Paso(
              'Si un RIM tiene un error, toque "Anular" y escriba el motivo.',
              'El RIM no se borra: queda marcado como anulado y no se sube. '
                  'Emita otro desde el servicio. Un RIM ya subido no se anula '
                  'en la app: consulte a Calidad.'),
        ]),
        Nota(
          TipoNota.importante,
          'Un RIM emitido no se puede modificar: es lo que el cliente firmó. '
          'Revise los datos antes de pedir la firma.',
        ),
        Nota(
          TipoNota.norma,
          'Al recibir un ítem se registran las anomalías y las desviaciones '
          'de las condiciones especificadas. Un registro no se sobrescribe: '
          'se conserva el original junto con su corrección.',
          referencia: '7.4.3 y 7.5.2',
        ),
      ],
    ),

    // ── Datos y registros ───────────────────────────────────────────────
    SeccionManual(
      id: 'registros',
      grupo: GrupoManual.datos,
      titulo: 'Consultar, corregir y exportar',
      icono: Icons.folder_open_outlined,
      resumen: 'Registros de un servicio, fotos, PDF y CSV.',
      bloques: [
        Pasos('Abrir un servicio', [
          Paso('En Inicio, vaya a "Actividad local".'),
          Paso('Elija Calibración o Soporte Técnico y toque el servicio.'),
          Paso(
              'En "Registros", abra el menú de cada registro.',
              'Las opciones son Editar, Exportar CSV (una copia de ese '
                  'registro) y Eliminar.'),
        ]),
        Lista('Opciones del servicio completo', [
          'Exportar PDF: "Generar un informe para compartir o imprimir", con '
              'todos los datos o solo los completos.',
          'Respaldo CSV: "Guardar una copia editable de los datos".',
          'Subir datos: "Validar y enviar los registros al servidor".',
          'Los archivos se guardan en la carpeta ServiceMET, organizados por '
              'código de servicio.',
        ]),
        Parrafo('Las fotos se ven en la galería del registro, donde también '
            'se pueden compartir o guardar.'),
        Nota(
          TipoNota.importante,
          'Eliminar un registro lo borra del teléfono de forma permanente. No '
          'elimine registros técnicos sin la autorización del responsable.',
        ),
        Nota(
          TipoNota.norma,
          'Toda corrección debe poder rastrearse hasta el dato original: '
          'valor anterior, valor nuevo, fecha, responsable y motivo. Mientras '
          'la app no guarde ese historial, registre cada corrección según el '
          'procedimiento del laboratorio.',
          referencia: '7.5.2',
        ),
      ],
    ),
    SeccionManual(
      id: 'subida',
      grupo: GrupoManual.datos,
      titulo: 'Subir datos al servidor',
      icono: Icons.cloud_upload_outlined,
      resumen: 'Validar, corregir y subir a DataMET.',
      bloques: [
        Pasos(null, [
          Paso('Conéctese a la red del laboratorio.'),
          Paso(
              'Abra la subida.',
              'Desde "Pendientes por SECA" en Inicio, o con "Subir datos" en '
                  'el menú del servicio.'),
          Paso('Pulse "VALIDAR DATOS".',
              'El servidor revisa el lote sin guardar nada.'),
          Paso('Corrija lo que se marque como inválido y pulse "VALIDAR '
              'NUEVAMENTE".'),
          Paso('Elija "SUBIR LOTE COMPLETO" o "SUBIR SOLO VÁLIDOS".'),
          Paso(
              'Confirme en "Confirmar subida".',
              'Si la sesión venció, la app pide su contraseña en "Autenticar '
                  'subida".'),
        ]),
        Parrafo('Si el lote incluye balanzas nuevas, la app muestra cuántas '
            'deben completarse después en DataMET.'),
        Nota(
          TipoNota.norma,
          'La transferencia se verifica en dos etapas: validación sin inserción '
          'y subida en una transacción que guarda todo o nada.',
          referencia: '7.11.6',
        ),
      ],
    ),
    SeccionManual(
      id: 'respaldo',
      grupo: GrupoManual.datos,
      titulo: 'Respaldo y restauración',
      icono: Icons.backup_outlined,
      resumen: 'Copias de las bases del teléfono e importación.',
      bloques: [
        Pasos('Guardar una copia', [
          Paso('Abra Ajustes y luego "Respaldo de datos".'),
          Paso('En "Acceso restringido", ingrese la clave que le entregue el '
              'administrador y pulse "Ingresar".'),
          Paso(
              'En "Archivos del dispositivo", seleccione las bases y pulse '
                  '"Descargar".',
              'Así se guarda una copia fuera de la app.'),
        ]),
        Pasos('Recuperar registros', [
          Paso('Pulse "Importar base" y elija el archivo .db.'),
          Paso(
              'Revise el resumen.',
              'Muestra los registros leídos, los nuevos a importar y los que '
                  'ya existen en el teléfono, que se omiten.'),
          Paso('Confirme con "Importar N registro(s)".'),
        ]),
        Nota(
          TipoNota.importante,
          'No elimine archivos de respaldo ni bases sin autorización: pueden '
          'ser la única copia de registros aún no subidos.',
        ),
        Nota(
          TipoNota.norma,
          'Los registros deben protegerse contra la pérdida y respaldarse '
          'según el procedimiento del laboratorio.',
          referencia: '7.11.3 b · 8.4.2',
        ),
      ],
    ),
    SeccionManual(
      id: 'calidad',
      grupo: GrupoManual.datos,
      titulo: 'Cumplimiento, manual y versiones',
      icono: Icons.verified_outlined,
      resumen: 'Consultar y exportar la información de calidad.',
      bloques: [
        Parrafo('En Ajustes, la sección "Calidad y normativa" reúne la '
            'información que el laboratorio necesita frente a la '
            'NB/ISO/IEC 17025.'),
        Lista(null, [
          'Cumplimiento: estado de cada requisito de las cláusulas 7.5, 7.11 y '
              '8.4, con evidencias, brechas y acciones. Se filtra por cláusula '
              'o por estado.',
          'Manual de uso: este documento, disponible sin conexión.',
          'Historial de versiones: qué cambió en cada versión y su impacto en '
              'los registros.',
        ]),
        Pasos('Exportar un documento', [
          Paso('Pulse el botón de exportar en la parte superior.'),
          Paso('Elija "Guardar PDF", "Compartir" o "Imprimir".',
              'Los PDF se guardan en ServiceMET/Calidad.'),
        ]),
        Nota(
          TipoNota.consejo,
          'La matriz de cumplimiento es una evaluación interna: ayuda a '
          'preparar la evaluación de la DTA, pero no la reemplaza.',
        ),
      ],
    ),

    // ── Ayuda ───────────────────────────────────────────────────────────
    SeccionManual(
      id: 'incidencias',
      grupo: GrupoManual.ayuda,
      titulo: 'Qué hacer ante una falla',
      icono: Icons.report_problem_outlined,
      resumen: 'Cómo actuar y reportar cuando algo no funciona.',
      bloques: [
        Pasos(null, [
          Paso('No borre datos ni reinstale la app.',
              'Podría perder registros que aún no se subieron.'),
          Paso('Anote la fecha y la hora, la pantalla, la SECA u OTST y qué '
              'estaba haciendo.'),
          Paso('Tome una captura de pantalla del mensaje de error.'),
          Paso('Indique si la falla pudo afectar datos o resultados.'),
          Paso('Informe al administrador del sistema y registre la falla en el '
              'formulario de incidencias del laboratorio.'),
        ]),
        Nota(
          TipoNota.importante,
          'El reporte de incidencias dentro de la app todavía no está '
          'disponible. Mientras tanto, use el formulario del laboratorio '
          '(código pendiente de asignar por Calidad).',
        ),
        Nota(
          TipoNota.norma,
          'Las fallas del sistema deben registrarse junto con las acciones '
          'inmediatas y correctivas que se tomaron.',
          referencia: '7.11.3 e',
        ),
      ],
    ),
    SeccionManual(
      id: 'problemas',
      grupo: GrupoManual.ayuda,
      titulo: 'Problemas frecuentes',
      icono: Icons.help_outline_rounded,
      resumen: 'Mensajes habituales y cómo resolverlos.',
      bloques: [
        Lista('"Datos pendientes"', [
          'Hay campos incompletos o con formato inválido en el paso. Corrija '
              'los que aparecen en la lista.',
        ]),
        Lista('"Requiere conexión al servidor"', [
          'Verifique la red o la VPN y el perfil en Ajustes > Conexión al '
              'servidor.',
        ]),
        Lista('"La sesión venció o no es válida"', [
          'Vuelva a autenticarse cuando la app lo pida en "Autenticar subida".',
        ]),
        Lista('"Demasiados intentos"', [
          'Espere unos minutos antes de volver a intentar el inicio de sesión.',
        ]),
        Lista('"certificado vencido"', [
          'El patrón elegido no está vigente. Use uno vigente o consulte al '
              'responsable técnico.',
        ]),
        Lista('"Calibración pendiente" o "Servicio de soporte pendiente"', [
          'Hay un trabajo sin terminar. "Continuar" lo recupera con sus fotos; '
              '"Descartar y crear otro" empieza uno nuevo.',
        ]),
      ],
    ),
  ],
);
