import '../models/version_app.dart';

/// Cambios hechos después de la última versión liberada. Al subir la versión
/// en pubspec.yaml, muévalos a una nueva entrada de [historialVersiones] y
/// deje esta lista vacía.
const cambiosSinLiberar = <String>[
  'Sección "Calidad y normativa" en Ajustes: tablero de cumplimiento '
      'NB/ISO/IEC 17025, manual de uso interactivo e historial de versiones.',
  'Exportación en PDF de la matriz de cumplimiento, el manual y el '
      'historial de versiones.',
  'Soporte técnico: teclado numérico propio y lectura del indicador con la '
      'cámara en excentricidad, repetibilidad y linealidad (también la carga '
      'sustitutiva), como en calibración. Atrás cierra primero el teclado.',
  'Registro de oportunidades comerciales en Bitrix24 (CRM › Prospectos) '
      'desde calibración y soporte, sin salir del servicio. Sin conexión '
      'quedan pendientes en el teléfono y se envían a mano desde Otros '
      'apartados. No modifica los registros técnicos.',
];

/// Historial de versiones liberadas, de la más reciente a la más antigua
/// (control de cambios, NB/ISO/IEC 17025 7.11.2).
///
/// La primera entrada debe coincidir con `version:` de pubspec.yaml; una
/// prueba lo comprueba para que ninguna versión se distribuya sin registrar.
/// Redacte para el laboratorio: qué cambia para el técnico y para los
/// registros, no detalles de programación.
const historialVersiones = <VersionApp>[
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
