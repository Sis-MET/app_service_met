import '../models/version_app.dart';

/// Cambios hechos después de la última versión liberada. Al subir la versión
/// en pubspec.yaml, muévalos a una nueva entrada de [historialVersiones] y
/// deje esta lista vacía.
const cambiosSinLiberar = <String>[];

/// Historial de versiones liberadas, de la más reciente a la más antigua
/// (control de cambios, NB/ISO/IEC 17025 7.11.2).
///
/// La primera entrada debe coincidir con `version:` de pubspec.yaml; una
/// prueba lo comprueba para que ninguna versión se distribuya sin registrar.
/// Redacte para el laboratorio: qué cambia para el técnico y para los
/// registros, no detalles de programación.
const historialVersiones = <VersionApp>[
  VersionApp(
    version: '6.5.1+20',
    fecha: '2026-10-29',
    clase: ClaseCambio.critico,
    resumen: 'Calibración de temperatura (muflas, hornos, estufas) con '
        'lecturas programadas del indicador y subida a DataMET, selección del '
        'tipo de calibración y un lector del indicador más capaz.',
    nuevo: [
      'Calibración: al entrar se elige el tipo, "CALIBRACIÓN DE BALANZAS" o '
          '"CALIBRACIÓN DE TEMPERATURA", con el mismo selector de soporte. '
          'La calibración de balanzas no cambia.',
      'Calibración de temperatura: mismos pasos y diseño que balanzas '
          '(Cliente, Planta, SECA, Equipo, Patrones y sensores, Puntos, '
          'Medición, Cierre y Resumen). Los patrones son solo equipos de '
          'temperatura (nunca pesas) y el termohigrómetro va aparte. Se '
          'registra el indicador del equipo (Digital por defecto, con la '
          'cámara o a mano); los sensores del patrón graban en el software de '
          'su registrador y se anotan con su posición y la referencia de ese '
          'registro.',
      'Lecturas programadas: para cada punto se configura el lapso en '
          'minutos y el intervalo en segundos (por ejemplo 45 min cada 30 s, '
          '91 lecturas). La cámara registra una lectura solo si tres cuadros '
          'coinciden y guarda la imagen del display; si no lee, se escribe a '
          'mano hasta la siguiente o queda "sin lectura" con su motivo, nunca '
          'con un valor inventado. La pantalla se mantiene encendida durante '
          'la medición.',
      'Correcciones y exclusiones de lecturas, siempre con motivo: el valor '
          'original se conserva, cada cambio queda con valor anterior, nuevo, '
          'técnico y fecha, y un registro finalizado ya no se modifica.',
      'Subida de la calibración de temperatura a DataMET, completa y en una '
          'sola transacción, desde su Resumen o desde "Registros de '
          'temperatura"; el resumen del servicio queda con el tipo CAL.TE. '
          'Un equipo nuevo se sube después de "Asignar código".',
      'Lector del indicador (balanzas y temperatura): el recuadro se mueve y '
          'se cambia de tamaño y la app lo recuerda; "Ajustes de cámara" con '
          'zoom, exposición y "Bloquear enfoque y exposición". En temperatura '
          'lee displays de color (rojo o verde), quita la unidad °C/°F, '
          'reconoce los mensajes sin valor (----, OPEn, HHHH) y ofrece '
          '"Verificar lectura" para ajustarse a un display difícil.',
    ],
    impactoRegistros: 'La calibración de temperatura es un registro técnico '
        'nuevo: la base local agrega sus tablas (temp_*) dentro de la base de '
        'calibración, que el respaldo ya incluye, y DataMET agrega seis '
        'tablas DATA_SERVICIOS_DATOS_CAL_TE* (script 017) en las que la API '
        'solo puede leer e insertar y DataMET+ solo leer. Cada lectura guarda '
        'la hora '
        'del teléfono con milisegundos, lo que leyó la cámara y su imagen '
        '(las imágenes quedan en el teléfono). Los registros de balanzas y de '
        'soporte no cambian. Antes de subir calibraciones de temperatura hay '
        'que ejecutar el script 017 en DataMET y desplegar el backend; sin '
        'ellos quedan pendientes en el teléfono y el servidor responde que '
        'falta el script.',
  ),
  VersionApp(
    version: '6.4.1+19',
    fecha: '2026-10-20',
    commit: '646ec67',
    clase: ClaseCambio.critico,
    resumen: 'Soporte técnico: el interruptor de las pruebas metrológicas '
        'avisa y guarda en el acto, una prueba omitida ya no se guarda ni se '
        'sube, y volver a activar la linealidad ya no deja la pantalla en '
        'blanco.',
    nuevo: [
      'Soporte técnico: al activar u omitir una prueba metrológica con el '
          'interruptor "Realizar ...", la tarjeta muestra "Activando la '
          'prueba…" u "Omitiendo la prueba…" y el cambio se guarda en el '
          'acto; antes la pantalla tardaba en reaccionar, sin aviso, hasta el '
          'autoguardado. Aplica a los 7 módulos con pruebas metrológicas.',
    ],
    corregido: [
      'Soporte técnico: volver a activar la linealidad cuando tenía una sola '
          'carga (o al reabrir el servicio así) dejaba la pantalla en blanco; '
          'ahora se abre con la carga registrada. La repetibilidad reabierta '
          'con un número de lecturas que no está en la lista (por ejemplo 4) '
          'muestra la opción que las contiene.',
      'Soporte técnico: una prueba metrológica omitida ya no guarda ni sube '
          'sus lecturas, y sigue omitida al continuar el servicio; antes, si '
          'ya tenía datos, volvía activa con ellos y podían subirse (en '
          'Relevamiento de datos se guardaban siempre). Una prueba aún sin '
          'llenar sigue activa al continuar. Además, las cargas o lecturas '
          'quitadas no dejan su valor en el registro, y al continuar vuelven '
          'las que siguen a una vacía (antes se perdían) y la repetibilidad '
          'inicial de Instalación y Verificaciones internas vuelve con sus '
          'mediciones (antes con 10). Aplica a los 7 módulos con pruebas '
          'metrológicas.',
    ],
    impactoRegistros: 'En los 7 módulos de soporte con pruebas metrológicas, '
        'una prueba omitida queda vacía en el registro y no llega a DataMET, '
        'y tampoco las cargas o lecturas que el técnico quitó. La base local '
        'agrega a cada tabla de soporte la columna pruebas_omitidas, que no '
        'se sube; un registro guardado con una versión anterior se lee como '
        'antes. El servidor no cambia. Incluye todo lo de 6.4.0+18: si esa '
        'versión no se distribuyó, antes de distribuir esta hay que ejecutar '
        'sus scripts (012, 014 y 015) en DataMET y desplegar el backend.',
  ),
  VersionApp(
    version: '6.4.0+18',
    fecha: '2026-10-19',
    commit: '8b18cb6',
    clase: ClaseCambio.critico,
    resumen: 'RIM con código único RIM-AA-NNNN por talonarios, RIM anulados '
        'que se suben con su anulación, y los RIM guardados en DataMET.',
    nuevo: [
      'RIM con código único RIM-AA-NNNN (gestión y número), igual para '
          'calibración, soporte, registro directo y DataMET+. El teléfono '
          'recibe del servidor talonarios de números (al abrir la app, al '
          'volver la conexión o desde el formulario) y los usa en orden '
          'aunque no tenga red, así el cliente firma con el código '
          'definitivo. Sin números, el formulario muestra "Sin números de '
          'RIM en este teléfono" y no deja emitir. Los RIM ya emitidos '
          'conservan su código anterior.',
      'RIM anulado antes de subirse: se sube marcado como anulado, con '
          'quién, cuándo y por qué, para que su número no quede como un '
          'hueco. Un RIM ya subido se anula en DataMET+ (Registros RIM), '
          'donde también se registran su ejecución en Soporte Técnico y su '
          'entrega al cliente.',
    ],
    corregido: [
      'Soporte técnico (servidor): las cargas de repetibilidad con decimales '
          '(525.5 kg) de Mantenimiento preventivo avanzado, Mantenimiento '
          'preventivo regular y Relevamiento de datos ya se aceptan; antes el '
          'servidor rechazaba esos servicios. La app no cambia; requiere el '
          'script 015.',
    ],
    impactoRegistros: 'Cada RIM nuevo guarda su gestión, su número, el '
        'talonario del que salió y la instalación de la app; dos RIM no '
        'pueden compartir número (índice único en el servidor). Los RIM y la '
        'copia de las oportunidades se guardan en tablas propias dentro de '
        'DataMET (scripts 012 y 014), y los usuarios de la API y de DataMET+ '
        'tienen denegado modificarlas o borrarlas. La base local del teléfono '
        'agrega los talonarios y la numeración del RIM. Antes de distribuir '
        'la app hay que ejecutar los scripts 012, 014 y 015 en DataMET y '
        'desplegar el backend: sin ellos la app no recibe talonarios y no '
        'puede emitir RIM nuevos.',
  ),
  VersionApp(
    version: '6.3.5+17',
    fecha: '2026-10-15',
    commit: '3692570',
    clase: ClaseCambio.critico,
    resumen: 'Ubicación de cada servicio, ficha del instrumento con los rangos '
        'de menor a mayor, balanzas nuevas que se suben con su código '
        'definitivo, registros de solo lectura y aviso antes de cada permiso.',
    nuevo: [
      'Ubicación de cada servicio de calibración y de los 8 módulos de '
          'soporte: al guardar la balanza se toma una vez la ubicación del '
          'teléfono (latitud, longitud, precisión y hora). Si el servicio se '
          'continúa en otro lugar, se conserva la primera. Se envía al subir, '
          'aparte del registro técnico.',
      'Permisos: antes de cada solicitud del teléfono (ubicación, '
          'notificaciones y cámara) la app muestra su propio aviso; ninguno se '
          'pide en silencio. Sin permiso de ubicación, o con la ubicación del '
          'teléfono apagada, no se puede iniciar ni continuar un servicio: '
          'aparece "Ubicación requerida".',
      'Ficha del instrumento, en el paso Instrumento y en el botón ámbar de '
          'información (calibración y soporte): código, estado (catálogo o '
          'nueva), datos clave, escala de capacidades y tabla de rangos. El '
          'Rango 1 es siempre el de menor capacidad; es solo visual, los '
          'datos guardados no cambian.',
      'Paso Instrumento con los campos agrupados, rangos editables de menor a '
          'mayor y "Agregar rango". La búsqueda de balanzas muestra su '
          'capacidad.',
      'Balanzas nuevas en la subida: aparecen aparte con los pasos a seguir y '
          '"Asignar código". Se suben solo con el código métrica que asignó '
          'DataMET; mientras tanto se pueden subir las balanzas ya '
          'registradas. Al asignarlo, la app avisa si no corresponde al '
          'cliente y la planta, si ya lo tiene otra balanza del servicio y si '
          'figura en la precarga.',
      'Registros de solo lectura: se retiró "Editar". El detalle muestra '
          '"Historial de cambios" cuando al registro se le asignó el código '
          'de una balanza nueva, y las balanzas nuevas llevan la marca '
          '"Nueva".',
    ],
    corregido: [
      'Las notificaciones ya no se piden al abrir la app sin aviso: se piden '
          'desde el inicio, después del aviso de la app.',
      'La "Información del instrumento" de calibración y la de soporte '
          'mostraban los rangos en el orden guardado; ahora van de menor a '
          'mayor capacidad.',
    ],
    impactoRegistros: 'Cada registro de calibración y soporte guarda su '
        'ubicación en el teléfono, y el resumen DATA_SERVICIOS_DATOS la recibe '
        'en latitud, longitud, precision_gps y fecha_gps (requiere el script '
        '013 antes de desplegar el backend; lo subido desde versiones '
        'anteriores queda sin coordenadas). Las balanzas nuevas ya no se suben '
        'con código provisional. Asignar el código definitivo es la única '
        'corrección de un registro técnico, y queda en la tabla '
        'auditoria_registros con el valor anterior, el nuevo, el usuario, la '
        'fecha, el motivo y la versión de la app.',
  ),
  VersionApp(
    version: '6.3.4+16',
    fecha: '2026-10-05',
    commit: '8825ff7',
    clase: ClaseCambio.critico,
    resumen: 'Recepción de instrumentos (RIM) con las firmas del cliente y '
        'de Métrica, oportunidades en Bitrix24, soporte técnico con la misma '
        'seguridad que la calibración, fotos sin entrar a Editar y nueva '
        'navegación.',
    nuevo: [
      'Sección "Calidad y normativa" en la pestaña Otros de la barra inferior: '
          'tablero de cumplimiento NB/ISO/IEC 17025, manual de uso interactivo '
          'e historial de versiones.',
      'Exportación en PDF de la matriz de cumplimiento, el manual y el '
          'historial de versiones.',
      'Soporte técnico: teclado numérico propio y lectura del indicador con la '
          'cámara en excentricidad, repetibilidad y linealidad (también la '
          'carga sustitutiva), como en calibración. Atrás cierra primero el '
          'teclado.',
      'Registro de oportunidades comerciales en Bitrix24 (CRM › Prospectos) '
          'desde calibración y soporte, sin salir del servicio. No modifica '
          'los registros técnicos.',
      'Calibración y soporte técnico: título centrado con el paso actual '
          'debajo; ≡ abre la lista de pasos, marca los completos y lleva a '
          'cualquiera habilitado (reemplaza a la barra de pasos). "Anterior" y '
          'el gesto Atrás retroceden un paso y nunca sacan del servicio; ⋮ '
          'reúne "Registrar oportunidad comercial" y "Salir (queda guardado)", '
          'que guarda antes de cerrar.',
      'Recepción de instrumentos de pesaje (RIM) desde calibración y soporte: '
          '⋮ › "Emitir RIM (recepción de instrumento)". El cliente, la planta '
          'y el instrumento se toman del servicio; el técnico registra el '
          'inventario, los daños, la suciedad y el motivo, y firman en la '
          'pantalla, a pantalla completa, el cliente y el representante de '
          'Métrica. El RIM queda guardado en el teléfono, con su PDF, y no se '
          'modifica: si tiene un error se anula con motivo.',
      'La app sugiere el RIM cuando el servicio de una balanza se corta: al '
          'salir a medias y al descartar un servicio pendiente. Después de '
          'emitirlo, "Cambiar de balanza" cierra esa balanza sin concluirla y '
          'permite seguir con otra en la misma SECA u OTST.',
      'Servicios reúne los formularios adicionales: "Recepción de instrumentos '
          '(RIM)" y "Oportunidades comerciales" (antes en Precarga), con sus '
          'pendientes de enviar.',
      'RIM y oportunidades también fuera de un servicio: en Servicios, "Nuevo '
          'RIM" y "Nueva oportunidad" abren una selección rápida de cliente, '
          'planta e instrumento (o el código QR del instrumento). El RIM '
          'admite un instrumento no registrado, con código provisional. Estos '
          'registros se guardan como "Registro directo".',
      'Oportunidades sin conexión: se registran con el cliente de ServiceMET y '
          'quedan pendientes. Al volver la conexión con el servidor la app les '
          'asigna la empresa de Bitrix24 (la elegida antes para ese cliente o '
          'una coincidencia exacta de nombre) y las envía sola; si no hay una '
          'coincidencia segura, pide que el técnico la elija. Reemplaza al '
          'botón "Guardar pendiente".',
      'Fotos de calibración y soporte técnico sin entrar a Editar: en '
          '"Registros" cada balanza muestra sus fotos en miniatura; "+N" o el '
          'menú › "Ver fotos" las reúne por sección, y el visor permite '
          'deslizar, acercar, saltar con la tira de miniaturas, compartir y '
          'guardar. Ver las fotos no modifica el registro. El detalle del '
          'registro muestra las fotos en lugar de sus rutas en el teléfono.',
      'Nueva barra de navegación inferior: una cápsula más angosta que flota '
          'sobre la pantalla, clara u oscura según el tema, con íconos nuevos; '
          'la pestaña abierta se resalta en gris con su nombre y las demás '
          'muestran solo su ícono.',
      'Íconos nuevos en toda la app: una sola familia de línea fina y '
          'redondeada en lugar de los íconos de Material y Font Awesome. No '
          'cambia ningún flujo ni ningún dato.',
    ],
    corregido: [
      'Soporte técnico con la misma seguridad que la calibración: se avanza '
          'solo con el paso completo y guardado en el teléfono; un paso '
          'adelante se abre solo con los anteriores completos, y "Finalizar" '
          'revisa todos los pasos y lleva al primero incompleto (antes '
          'revisaba solo el actual y se podía finalizar con pasos saltados). '
          'Las pruebas de excentricidad, repetibilidad y linealidad marcadas '
          'como realizadas se exigen con todas sus lecturas.',
      'Soporte técnico: Relevamiento de datos exige inspección, pruebas y '
          'cierre (antes se podía finalizar vacío); al continuarlo recupera la '
          'repetibilidad y las posiciones de excentricidad en su lugar. El '
          'panel ≡ marca como completos los pasos llenos también al reabrir el '
          'servicio.',
      'Soporte técnico: al elegir otra balanza se cierra el servicio recién '
          'finalizado, que antes quedaba abierto debajo y aceptaba cambios.',
      'Calibración: de Inspección en adelante los pasos se abren con el '
          'instrumento confirmado.',
    ],
    impactoRegistros: 'Nuevos registros en la base servicios_extras: RIM '
        '(form_rim, con las firmas del cliente y del representante de '
        'Métrica) y copia de cada oportunidad registrada en Bitrix24 '
        '(form_bitrix). Requiere ejecutar el script 012 antes de desplegar '
        'el backend. En soporte técnico, cada paso debe quedar completo y '
        'guardado para avanzar.',
  ),
  VersionApp(
    version: '6.3.3+15',
    fecha: '2026-09-24',
    commit: 'bf004af',
    clase: ClaseCambio.critico,
    resumen: 'Lectura del indicador con la cámara, teclado numérico propio y '
        'asistente de calibración unificado.',
    nuevo: [
      'Lectura del indicador de la balanza con la cámara, incluidos los '
          'displays de 7 segmentos.',
      'Teclado numérico propio con navegación entre campos.',
      'Revisión de datos pendientes antes de finalizar y nuevo selector de '
          'pesas patrón con su vigencia.',
      'Visor de fotografías con opciones de compartir y guardar.',
      'Notificaciones de servicios y vencimientos con icono y canales '
          'propios.',
      'En soporte, el código QR selecciona cliente, planta e instrumento.',
      'Indicador de guardado automático en el asistente.',
    ],
    corregido: [
      'La carga de excentricidad admite decimales.',
      'La subida ya no envía al servidor columnas de progreso local.',
      '"Balanza Calibrada" significa lo mismo en toda la app.',
      'Continuar una calibración o un servicio de soporte pendiente recupera '
          'fotos, balanza y pruebas iniciales.',
      'El mantenimiento correctivo avisa cuando no pudo guardar.',
      'Las indicaciones vuelven a replicar la carga.',
    ],
    impactoRegistros: 'La carga de excentricidad se guarda con decimales '
        '(requiere el script 011 en DataMET). Se reorganizó el guardado del '
        'asistente de calibración.',
  ),
  VersionApp(
    version: '6.3.1+13',
    fecha: '2026-09-18',
    commit: '6273e8f',
    clase: ClaseCambio.critico,
    resumen: 'Recuperación de registros desde bases .db y ajustes de soporte.',
    nuevo: [
      'Importación de bases .db desde Respaldo, con vista previa de lo que '
          'se recupera.',
      'Comentarios de instalación de hasta 1000 caracteres.',
      'Interruptor para marcar todos los campos como "No aplica" en soporte.',
    ],
    corregido: [
      'Diagnóstico y mantenimiento correctivo guardan el estado del servicio.',
      'La precarga cierra la conexión antes de reemplazar la base.',
    ],
    impactoRegistros: 'Diagnóstico y correctivo registran estado_servicio; '
        'los comentarios de instalación admiten 1000 caracteres (script 010).',
  ),
  VersionApp(
    version: '6.2.0+10',
    fecha: '2026-08-17',
    commit: '7213956',
    clase: ClaseCambio.critico,
    resumen: 'Prevención de duplicados y normalización de datos de soporte.',
    nuevo: [
      'Se evitan servicios y cargas duplicados por módulo y OTST.',
    ],
    corregido: [
      'Fechas e indicadores de soporte se normalizan por módulo.',
      'Se retiraron los permisos de fotos, video y almacenamiento total de '
          'Android.',
    ],
    impactoRegistros: 'Las fechas e indicadores de soporte se guardan con un '
        'formato único; no se admiten duplicados por módulo y OTST.',
  ),
  VersionApp(
    version: '6.1.1+9',
    fecha: '2026-08-14',
    commit: 'f7c176d',
    clase: ClaseCambio.critico,
    resumen: 'Tipo de servicio en la subida y manejo de balanzas nuevas.',
    nuevo: [
      'La subida registra el tipo de servicio en el resumen general.',
      'Las balanzas nuevas se suben y se señalan para completarlas en '
          'DataMET.',
    ],
    corregido: [
      'Resúmenes y formularios de la versión 6.1.0.',
    ],
    impactoRegistros: 'El resumen general guarda tipo_servicio (script 005); '
        'las balanzas nuevas quedan con estado BALANZA NUEVA.',
  ),
  VersionApp(
    version: '6.1.0+8',
    fecha: '2026-08-12',
    commit: '4740593',
    clase: ClaseCambio.critico,
    resumen: 'Nueva experiencia de inicio, subida directa a DataMET y '
        'recuperación de trabajos pendientes.',
    nuevo: [
      'Rediseño del inicio de sesión, del inicio y de las pantallas de '
          'servicio.',
      'Validación y subida de todos los módulos de soporte al servidor.',
      'Conexión al servidor con certificado fijado.',
      'Recuperación de calibraciones y servicios de soporte pendientes.',
      'Finalización de servicios sin exportar CSV.',
    ],
    impactoRegistros: 'Los registros se suben directamente a DataMET '
        'mediante la API, que valida y asigna el código de registro.',
  ),
];

/// Nota para las versiones sin registro formal.
const notaVersionesAnteriores = 'Las versiones anteriores a la 6.1.0 no '
    'tienen registro formal de cambios; su historial está en el control de '
    'versiones del código.';
