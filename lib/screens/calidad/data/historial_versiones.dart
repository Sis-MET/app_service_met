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
