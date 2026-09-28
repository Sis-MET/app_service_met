import '../models/cumplimiento.dart';

/// Evaluación interna de ServiceMET frente a la NB/ISO/IEC 17025 (7.5, 7.11 y
/// 8.4).
///
/// Es la matriz de cumplimiento que se muestra en Ajustes y se exporta en PDF.
/// Se actualiza al cerrar una brecha o al liberar una versión: cambie el
/// estado del requisito, sus evidencias y, arriba, la versión y la fecha de
/// evaluación. Las exigencias están parafraseadas; el texto de la norma tiene
/// derechos de autor.
final evaluacionCumplimiento = EvaluacionCumplimiento(
  version: '6.3.3+15',
  fecha: DateTime(2026, 9, 28),
  requisitos: const [
    // ── 7.5 Registros técnicos ────────────────────────────────────────────
    Requisito(
      id: 'RT-01',
      clausula: Clausula.registrosTecnicos,
      literal: '7.5.1',
      titulo: 'Identificación única del registro',
      exige: 'Cada observación debe poder vincularse sin ambigüedad con la '
          'tarea y el ítem a los que pertenece.',
      estado: EstadoCumplimiento.cumple,
      evidencias: [
        'Cada registro se identifica por SECA u OTST, sesión y código métrica.',
        'El servidor asigna el código de registro (SECA-COD_METRICA en '
            'calibración, OTST-MÓDULO-COD_METRICA en soporte).',
        'La API rechaza códigos repetidos dentro del lote y los ya '
            'existentes en DataMET.',
      ],
    ),
    Requisito(
      id: 'RT-02',
      clausula: Clausula.registrosTecnicos,
      literal: '7.5.1',
      titulo: 'Fecha y hora registradas en el momento',
      exige: 'La fecha de cada actividad y los datos originales se registran '
          'cuando se generan.',
      estado: EstadoCumplimiento.parcial,
      evidencias: [
        'La hora de inicio se toma del reloj del teléfono al abrir la '
            'inspección visual.',
        'El servidor guarda su propia fecha al recibir el registro.',
      ],
      brecha: 'La hora de fin se escribe a mano y no se conserva la hora de '
          'captura de cada prueba.',
      accion: 'Tomar la hora de fin del reloj al finalizar, con corrección '
          'justificada, y guardar la marca de tiempo de cada prueba.',
      cierre: TipoCierre.software,
      riesgo: Riesgo.medio,
    ),
    Requisito(
      id: 'RT-03',
      clausula: Clausula.registrosTecnicos,
      literal: '7.5.1',
      titulo: 'Técnico responsable identificado',
      exige: 'El registro indica quién realizó cada actividad.',
      estado: EstadoCumplimiento.cumple,
      evidencias: [
        'El campo "personal" se completa con el usuario de la sesión, no con '
            'texto libre.',
        'En la subida, el servidor toma el usuario del token autenticado.',
      ],
    ),
    Requisito(
      id: 'RT-04',
      clausula: Clausula.registrosTecnicos,
      literal: '7.5.1',
      titulo: 'Revisión de datos y resultados',
      exige:
          'Queda registrado quién verificó los datos y resultados, y cuándo.',
      estado: EstadoCumplimiento.porVerificar,
      evidencias: [
        'La app no registra una revisión técnica; puede estar en DataMET.',
      ],
      brecha: 'No hay evidencia en la app de quién revisa ni cuándo.',
      accion: 'Confirmar con Calidad dónde queda la revisión técnica '
          '(DataMET o procedimiento) y documentarlo.',
      cierre: TipoCierre.procedimiento,
      riesgo: Riesgo.medio,
    ),
    Requisito(
      id: 'RT-05',
      clausula: Clausula.registrosTecnicos,
      literal: '7.5.1',
      titulo: 'Información suficiente para repetir',
      exige: 'El registro permite identificar lo que afecta al resultado y a '
          'su incertidumbre, y repetir la actividad en condiciones parecidas.',
      estado: EstadoCumplimiento.parcial,
      evidencias: [
        'Se registran balanza (marca, modelo, serie, capacidad y división), '
            'patrones con certificado y condiciones ambientales de inicio y fin.',
        'Excentricidad, repetibilidad y linealidad guardan cada lectura, '
            'con fotografías de respaldo.',
      ],
      brecha: 'No se registran el código y la revisión del procedimiento de '
          'calibración aplicado.',
      accion: 'Agregar el procedimiento y su revisión al registro, o '
          'documentar que DataMET lo asocia a cada servicio.',
      cierre: TipoCierre.ambos,
      riesgo: Riesgo.medio,
    ),
    Requisito(
      id: 'RT-06',
      clausula: Clausula.registrosTecnicos,
      literal: '7.5.1',
      titulo: 'Patrones vigentes',
      exige: 'Los patrones que sustentan la trazabilidad deben estar '
          'identificados y ser aptos para su uso.',
      estado: EstadoCumplimiento.parcial,
      evidencias: [
        'El selector muestra la vigencia de cada pesa patrón (365 días desde '
            'el certificado).',
        'Al elegir un patrón vencido, la app muestra una alerta.',
        'La pantalla Vencimientos avisa de patrones vencidos o por vencer.',
      ],
      brecha: 'Un patrón vencido se puede usar sin justificar y uno sin fecha '
          'válida no se marca como vencido.',
      accion: 'Pedir una justificación registrada al usar un patrón vencido y '
          'tratar "sin fecha" como no apto.',
      cierre: TipoCierre.software,
      riesgo: Riesgo.medio,
    ),
    Requisito(
      id: 'RT-07',
      clausula: Clausula.registrosTecnicos,
      literal: '7.5.1',
      titulo: 'Observaciones originales',
      exige: 'Lo observado se conserva tal cual; las ayudas de captura no '
          'reemplazan la observación.',
      estado: EstadoCumplimiento.parcial,
      evidencias: [
        'El técnico ve y puede corregir los valores sugeridos o leídos por '
            'la cámara antes de guardarlos.',
        'Se guardan fotos de la balanza, del entorno y de linealidad.',
      ],
      brecha: 'La lectura del indicador por cámara no guarda la imagen '
          'usada: el valor queda sin su evidencia original.',
      accion: 'Guardar la foto del indicador junto a cada lectura hecha con '
          'la cámara.',
      cierre: TipoCierre.software,
      riesgo: Riesgo.medio,
    ),
    Requisito(
      id: 'RT-08',
      clausula: Clausula.registrosTecnicos,
      literal: '7.5.2',
      titulo: 'Historial de modificaciones',
      exige: 'Todo cambio se rastrea hasta el dato original; se conservan el '
          'valor anterior y el nuevo, la fecha y quién lo cambió.',
      estado: EstadoCumplimiento.noCumple,
      evidencias: [
        'El editor de registros detecta qué campos cambiaron antes de guardar.',
      ],
      brecha: 'Al editar un registro se sobrescribe el valor anterior sin '
          'guardar quién, cuándo ni por qué.',
      accion: 'Tabla de auditoría (solo se agrega) escrita en la misma '
          'transacción, con motivo obligatorio y la sección "Historial de '
          'cambios" en el editor.',
      cierre: TipoCierre.software,
      riesgo: Riesgo.alto,
    ),
    Requisito(
      id: 'RT-09',
      clausula: Clausula.registrosTecnicos,
      literal: '7.5.2',
      titulo: 'Sin sobrescritura silenciosa',
      exige: 'Un registro ya capturado no puede ser reemplazado sin dejar '
          'rastro.',
      estado: EstadoCumplimiento.porVerificar,
      evidencias: [
        'Los guardados de progreso de soporte reemplazan la fila de la sesión.',
      ],
      brecha: 'Falta confirmar que ningún reemplazo automático alcance a un '
          'registro ya finalizado.',
      accion: 'Revisar cada reemplazo automático y limitarlo a borradores no '
          'finalizados.',
      cierre: TipoCierre.software,
      riesgo: Riesgo.medio,
    ),
    Requisito(
      id: 'RT-10',
      clausula: Clausula.registrosTecnicos,
      literal: '7.5.2',
      titulo: 'Anular en lugar de borrar',
      exige: 'El dato original no debe desaparecer: se conserva junto con la '
          'corrección.',
      estado: EstadoCumplimiento.noCumple,
      evidencias: [
        'La eliminación pide confirmación.',
        'La API del servidor no puede borrar: solo tiene permiso de inserción.',
      ],
      brecha: '"Eliminar registro" lo borra de forma permanente del teléfono, '
          'y un script administrativo borra registros ya subidos sin guardar '
          'copia.',
      accion: 'Anular con motivo (el registro queda visible en el historial) '
          'y archivar antes de cualquier borrado en el servidor.',
      cierre: TipoCierre.ambos,
      riesgo: Riesgo.alto,
    ),
    Requisito(
      id: 'RT-11',
      clausula: Clausula.registrosTecnicos,
      literal: '7.5.2',
      titulo: 'Registros subidos protegidos',
      exige: 'Lo que ya está en la base del laboratorio no debe divergir de la '
          'copia local sin control.',
      estado: EstadoCumplimiento.noCumple,
      evidencias: [
        'La app sabe qué registros se subieron, quién los subió y cuándo.',
      ],
      brecha: 'Un registro ya subido todavía puede editarse en el teléfono.',
      accion: 'Abrir en solo lectura los registros subidos; las correcciones '
          'se hacen según el procedimiento de Calidad.',
      cierre: TipoCierre.software,
      riesgo: Riesgo.medio,
    ),
    Requisito(
      id: 'RT-12',
      clausula: Clausula.registrosTecnicos,
      literal: '7.5.1',
      titulo: 'Fotografías vinculadas',
      exige: 'La evidencia fotográfica queda asociada al registro que '
          'respalda.',
      estado: EstadoCumplimiento.cumple,
      evidencias: [
        'Cada foto se guarda por servicio y código métrica, y se ve en la '
            'galería del registro.',
        'El editor no permite cambiar la ruta de una foto como si fuera texto.',
      ],
    ),
    Requisito(
      id: 'RT-13',
      clausula: Clausula.registrosTecnicos,
      literal: '7.5.1 / 7.11.2',
      titulo: 'Versión de la app en el registro',
      exige: 'Para repetir el procesamiento hay que saber con qué versión del '
          'software se capturó.',
      estado: EstadoCumplimiento.noCumple,
      evidencias: [
        'La versión instalada se ve en Ajustes y en el historial de versiones.',
      ],
      brecha: 'Los registros no guardan la versión de la app que los capturó.',
      accion: 'Guardar la versión al crear cada registro y en cada entrada '
          'del historial de cambios.',
      cierre: TipoCierre.software,
      riesgo: Riesgo.medio,
    ),

    // ── 7.11 Control de los datos y gestión de la información ────────────
    Requisito(
      id: 'DI-01',
      clausula: Clausula.gestionInformacion,
      literal: '7.11.1',
      titulo: 'Acceso a los datos necesarios',
      exige: 'El personal dispone de los datos que necesita para trabajar.',
      estado: EstadoCumplimiento.cumple,
      evidencias: [
        'La precarga descarga clientes, plantas, balanzas y patrones para '
            'trabajar sin conexión.',
        'Vencimientos resume patrones y balanzas vencidos o por vencer.',
      ],
    ),
    Requisito(
      id: 'DI-02',
      clausula: Clausula.gestionInformacion,
      literal: '7.11.2',
      titulo: 'Validación antes del uso',
      exige: 'El sistema se valida antes de usarse y después de cada cambio.',
      estado: EstadoCumplimiento.parcial,
      evidencias: [
        'Pruebas automáticas de la app (Flutter) y del servidor (Node).',
        'Historial de versiones con la clase de cada cambio.',
      ],
      brecha: 'No hay un registro de validación por versión con el resultado '
          'de las pruebas y quién autorizó su uso.',
      accion: 'Emitir un registro de validación en cada versión antes de '
          'distribuirla.',
      cierre: TipoCierre.ambos,
      riesgo: Riesgo.medio,
    ),
    Requisito(
      id: 'DI-03',
      clausula: Clausula.gestionInformacion,
      literal: '7.11.2',
      titulo: 'Cambios autorizados y documentados',
      exige: 'Cada cambio se autoriza, se documenta y se valida antes de '
          'implementarse.',
      estado: EstadoCumplimiento.parcial,
      evidencias: [
        'Historial de versiones en la app, exportable en PDF.',
        'Cada cambio del código queda en el control de versiones.',
      ],
      brecha: 'Falta registrar la autorización del laboratorio para poner '
          'cada versión en uso.',
      accion: 'Firmar la liberación de cada versión (responsable técnico o de '
          'calidad).',
      cierre: TipoCierre.procedimiento,
      riesgo: Riesgo.medio,
    ),
    Requisito(
      id: 'DI-04',
      clausula: Clausula.gestionInformacion,
      literal: '7.11.2',
      titulo: 'Versión identificable',
      exige: 'Se sabe qué versión del sistema está en uso.',
      estado: EstadoCumplimiento.cumple,
      evidencias: [
        'La versión instalada aparece en Ajustes.',
        'El historial de versiones marca la versión instalada.',
      ],
    ),
    Requisito(
      id: 'DI-05',
      clausula: Clausula.gestionInformacion,
      literal: '7.11.3 a',
      titulo: 'Protección contra acceso no autorizado',
      exige: 'Solo acceden las personas autorizadas.',
      estado: EstadoCumplimiento.parcial,
      evidencias: [
        'Cuentas personales; el servidor exige usuario activo y habilitado '
            'para ServiceMET.',
        'Sesión con vencimiento y límite de intentos de inicio de sesión.',
        'Credenciales locales protegidas y acceso biométrico opcional.',
      ],
      brecha: 'La pantalla de Respaldo, que permite borrar bases de datos, se '
          'protege con una clave predecible.',
      accion: 'Proteger Respaldo con la cuenta del usuario o una clave de '
          'administrador real, y registrar su uso.',
      cierre: TipoCierre.software,
      riesgo: Riesgo.alto,
    ),
    Requisito(
      id: 'DI-06',
      clausula: Clausula.gestionInformacion,
      literal: '7.11.3 a',
      titulo: 'Contraseñas protegidas',
      exige: 'Las credenciales no deben poder leerse si alguien accede a la '
          'base.',
      estado: EstadoCumplimiento.porVerificar,
      evidencias: [
        'En el teléfono, la contraseña se verifica con un hash PBKDF2 con sal.',
      ],
      brecha: 'El servidor compara la contraseña directamente contra '
          'data_users, lo que sugiere que DataMET la guarda sin cifrar.',
      accion: 'Confirmar con el administrador de DataMET y migrar a hashes.',
      cierre: TipoCierre.ambos,
      riesgo: Riesgo.alto,
    ),
    Requisito(
      id: 'DI-07',
      clausula: Clausula.gestionInformacion,
      literal: '7.11.3 b',
      titulo: 'Transporte seguro',
      exige: 'Los datos no pueden alterarse en tránsito.',
      estado: EstadoCumplimiento.cumple,
      evidencias: [
        'HTTPS con huella del certificado fijada en la app.',
        'Nunca se acepta un certificado distinto al esperado.',
      ],
    ),
    Requisito(
      id: 'DI-08',
      clausula: Clausula.gestionInformacion,
      literal: '7.11.3 b',
      titulo: 'Permisos mínimos en el servidor',
      exige: 'El sistema se protege contra manipulaciones.',
      estado: EstadoCumplimiento.cumple,
      evidencias: [
        'El usuario de la API solo puede consultar e insertar: no modifica '
            'ni borra.',
        'El servidor impone fecha, usuario y estado; la app no puede '
            'falsearlos.',
      ],
    ),
    Requisito(
      id: 'DI-09',
      clausula: Clausula.gestionInformacion,
      literal: '7.11.3 b',
      titulo: 'Protección contra la pérdida',
      exige: 'Los datos no se pierden ante fallas o extravíos.',
      estado: EstadoCumplimiento.parcial,
      evidencias: [
        'Respaldo manual de las bases del teléfono.',
        'Importación de bases con vista previa y sin duplicar registros.',
        'Recuperación de servicios pendientes al volver a abrir la app.',
      ],
      brecha: 'El respaldo depende del técnico, no hay prueba de restauración '
          'documentada y las fotos solo están en el teléfono.',
      accion: 'Respaldo periódico definido por procedimiento, prueba de '
          'restauración anual y copia de las fotos.',
      cierre: TipoCierre.ambos,
      riesgo: Riesgo.medio,
    ),
    Requisito(
      id: 'DI-10',
      clausula: Clausula.gestionInformacion,
      literal: '7.11.3 c',
      titulo: 'Entorno de operación especificado',
      exige: 'El sistema opera en el entorno definido por el laboratorio.',
      estado: EstadoCumplimiento.parcial,
      evidencias: [
        'El manual de uso describe teléfono, permisos y red requeridos.',
        'El servidor tiene documentados sus requisitos (Node.js, HTTPS).',
      ],
      brecha: 'No hay una lista de dispositivos autorizados ni de sus '
          'versiones instaladas.',
      accion: 'Mantener un inventario de dispositivos y de la versión que '
          'tiene cada uno.',
      cierre: TipoCierre.procedimiento,
      riesgo: Riesgo.bajo,
    ),
    Requisito(
      id: 'DI-11',
      clausula: Clausula.gestionInformacion,
      literal: '7.11.3 d',
      titulo: 'Integridad de los datos',
      exige: 'Los datos se mantienen íntegros de extremo a extremo.',
      estado: EstadoCumplimiento.cumple,
      evidencias: [
        'Los datos se validan contra el esquema de DataMET al guardar y antes '
            'de subir.',
        'El servidor vuelve a validar y confirma o revierte cada lote '
            'completo.',
        'Se evitan duplicados por módulo y código, y se conservan los '
            'decimales.',
      ],
    ),
    Requisito(
      id: 'DI-12',
      clausula: Clausula.gestionInformacion,
      literal: '7.11.3 e',
      titulo: 'Registro de fallas del sistema',
      exige: 'Las fallas del sistema quedan registradas junto con las acciones '
          'inmediatas y correctivas.',
      estado: EstadoCumplimiento.noCumple,
      evidencias: [
        'Los errores se muestran al técnico en pantalla.',
      ],
      brecha: 'No hay reporte de incidencias ("Soporte técnico" aún no está '
          'disponible) y los errores no quedan guardados.',
      accion: 'Reporte de incidencias en la app, registro automático de '
          'errores y seguimiento hasta el cierre.',
      cierre: TipoCierre.ambos,
      riesgo: Riesgo.alto,
    ),
    Requisito(
      id: 'DI-13',
      clausula: Clausula.gestionInformacion,
      literal: '7.11.4',
      titulo: 'Servicios externos controlados',
      exige: 'Si parte del sistema depende de terceros, estos cumplen los '
          'requisitos aplicables.',
      estado: EstadoCumplimiento.porVerificar,
      evidencias: [
        'La lectura del indicador (ML Kit) procesa la imagen en el teléfono.',
      ],
      brecha: 'Firebase se inicializa al abrir la app; falta confirmar si se '
          'usa y qué datos envía.',
      accion: 'Retirar Firebase si no se usa o declararlo como proveedor '
          'externo.',
      cierre: TipoCierre.software,
      riesgo: Riesgo.bajo,
    ),
    Requisito(
      id: 'DI-14',
      clausula: Clausula.gestionInformacion,
      literal: '7.11.5',
      titulo: 'Manual de uso disponible',
      exige: 'Las instrucciones y los manuales están al alcance del personal.',
      estado: EstadoCumplimiento.parcial,
      evidencias: [
        'Manual interactivo dentro de la app, disponible sin conexión.',
        'El manual se exporta en PDF para el sistema documental.',
      ],
      brecha: 'El manual aún no tiene código, revisión ni aprobación de '
          'Calidad.',
      accion: 'Asignarle código, aprobarlo y registrar su distribución.',
      cierre: TipoCierre.procedimiento,
      riesgo: Riesgo.medio,
    ),
    Requisito(
      id: 'DI-15',
      clausula: Clausula.gestionInformacion,
      literal: '7.11.6',
      titulo: 'Cálculos verificados',
      exige: 'Los cálculos se verifican de forma apropiada y sistemática.',
      estado: EstadoCumplimiento.porVerificar,
      evidencias: [
        'Hay pruebas automáticas de normalización, validación y lectura del '
            'indicador.',
      ],
      brecha: 'Falta identificar cada cálculo metrológico de la app y '
          'contrastarlo con valores de referencia.',
      accion: 'Inventario de cálculos con una prueba por cada uno, comparada '
          'con la hoja de cálculo validada.',
      cierre: TipoCierre.software,
      riesgo: Riesgo.medio,
    ),
    Requisito(
      id: 'DI-16',
      clausula: Clausula.gestionInformacion,
      literal: '7.11.6',
      titulo: 'Transferencias verificadas',
      exige: 'Lo que llega a la base del laboratorio es lo que se capturó.',
      estado: EstadoCumplimiento.cumple,
      evidencias: [
        '"Validar datos" revisa el lote en el servidor sin insertar nada.',
        'La subida revalida e inserta todo o nada en una transacción.',
        'La app marca lo subido con el código asignado por el servidor.',
      ],
    ),
    Requisito(
      id: 'DI-17',
      clausula: Clausula.gestionInformacion,
      literal: '7.11.6',
      titulo: 'Importación y exportación fieles',
      exige: 'Importar o exportar no altera los datos.',
      estado: EstadoCumplimiento.cumple,
      evidencias: [
        'La importación muestra cuántos registros son nuevos y omite los que '
            'ya existen.',
        'Las exportaciones PDF y CSV se generan desde la base local sin '
            'modificarla.',
      ],
    ),

    // ── 8.4 Control de registros ─────────────────────────────────────────
    Requisito(
      id: 'CR-01',
      clausula: Clausula.controlRegistros,
      literal: '8.4.1',
      titulo: 'Registros legibles y recuperables',
      exige: 'Los registros se pueden leer y consultar.',
      estado: EstadoCumplimiento.cumple,
      evidencias: [
        'El detalle del servicio muestra cada registro con todas sus columnas.',
        'Resumen en PDF por servicio y consulta en DataMET.',
      ],
    ),
    Requisito(
      id: 'CR-02',
      clausula: Clausula.controlRegistros,
      literal: '8.4.2',
      titulo: 'Archivos identificados',
      exige: 'Cada registro y archivo se identifica de forma trazable.',
      estado: EstadoCumplimiento.cumple,
      evidencias: [
        'Las exportaciones se guardan en ServiceMET/<código de servicio>/ con '
            'tipo, código y fecha en el nombre.',
        'Las fotos se organizan por servicio y código métrica.',
      ],
    ),
    Requisito(
      id: 'CR-03',
      clausula: Clausula.controlRegistros,
      literal: '8.4.2',
      titulo: 'Almacenamiento protegido',
      exige: 'Los registros se almacenan protegidos.',
      estado: EstadoCumplimiento.parcial,
      evidencias: [
        'Las bases viven en el almacenamiento privado de la app.',
        'Las credenciales se guardan en el almacenamiento seguro del sistema.',
      ],
      brecha: 'Las bases locales no están cifradas: dependen del bloqueo del '
          'teléfono.',
      accion: 'Exigir bloqueo de pantalla en los dispositivos por '
          'procedimiento y evaluar el cifrado de las bases.',
      cierre: TipoCierre.ambos,
      riesgo: Riesgo.bajo,
    ),
    Requisito(
      id: 'CR-04',
      clausula: Clausula.controlRegistros,
      literal: '8.4.2',
      titulo: 'Respaldo definido',
      exige: 'Está definido qué se respalda, cada cuánto, dónde y quién lo '
          'hace.',
      estado: EstadoCumplimiento.parcial,
      evidencias: [
        'Respaldo de datos en Ajustes: copia de las bases fuera de la app.',
      ],
      brecha: 'No hay frecuencia ni responsable definidos, ni constancia del '
          'respaldo del servidor DataMET.',
      accion: 'Procedimiento de respaldo (teléfonos y servidor) con registro '
          'de cada copia.',
      cierre: TipoCierre.procedimiento,
      riesgo: Riesgo.medio,
    ),
    Requisito(
      id: 'CR-05',
      clausula: Clausula.controlRegistros,
      literal: '8.4.2',
      titulo: 'Tiempo de retención',
      exige: 'Los registros se conservan el tiempo definido por el '
          'laboratorio.',
      estado: EstadoCumplimiento.porVerificar,
      evidencias: [
        'En DataMET, los registros subidos no pueden borrarse desde la app.',
      ],
      brecha: 'No hay un plazo de retención definido para los datos del '
          'teléfono ni para las fotos.',
      accion:
          'Definir el plazo con Calidad y evitar borrar antes de cumplirlo.',
      cierre: TipoCierre.ambos,
      riesgo: Riesgo.medio,
    ),
    Requisito(
      id: 'CR-06',
      clausula: Clausula.controlRegistros,
      literal: '8.4.2',
      titulo: 'Disposición controlada',
      exige: 'Eliminar registros requiere autorización y deja constancia.',
      estado: EstadoCumplimiento.noCumple,
      evidencias: [
        'Borrar pide confirmación en pantalla.',
      ],
      brecha: 'Se pueden borrar registros y bases del teléfono, y registros '
          'del servidor por script, sin que quede constancia.',
      accion: 'Anulación en la app y un procedimiento de disposición con '
          'registro de quién autorizó.',
      cierre: TipoCierre.ambos,
      riesgo: Riesgo.alto,
    ),
    Requisito(
      id: 'CR-07',
      clausula: Clausula.controlRegistros,
      literal: '8.4.2 / 4.2',
      titulo: 'Confidencialidad',
      exige: 'El acceso a los registros respeta los compromisos de '
          'confidencialidad con los clientes.',
      estado: EstadoCumplimiento.parcial,
      evidencias: [
        'Los datos solo salen del teléfono cuando el técnico exporta o '
            'comparte.',
      ],
      brecha: 'Exportar y compartir datos de clientes no deja constancia.',
      accion: 'Establecer en el procedimiento a quién puede enviarse cada '
          'documento; opcionalmente, registrar cada exportación.',
      cierre: TipoCierre.procedimiento,
      riesgo: Riesgo.bajo,
    ),
    Requisito(
      id: 'CR-08',
      clausula: Clausula.controlRegistros,
      literal: '8.4.2',
      titulo: 'Registros disponibles',
      exige: 'Los registros están disponibles cuando se necesitan.',
      estado: EstadoCumplimiento.cumple,
      evidencias: [
        'En la app, los servicios se agrupan por SECA u OTST y se abren con '
            'todos sus registros.',
        'Los registros subidos se consultan en DataMET.',
      ],
    ),
  ],
);
