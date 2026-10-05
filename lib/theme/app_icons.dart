import 'package:flutter/widgets.dart';

/// Íconos de ServiceMET: una sola familia de línea fina y puntas
/// redondeadas (Lucide, trazo 300).
///
/// La fuente es propia de la app (assets/fonts/lucide_300.ttf, con su
/// licencia al lado) y al compilar quedan solo los íconos que se usan.
/// Use siempre estos nombres en vez de `Icons` o Font Awesome: así toda la
/// app conserva el mismo estilo y se cambia en un solo lugar. Para un ícono
/// nuevo, agréguelo aquí con un nombre que diga para qué sirve y el punto
/// de código del ícono de Lucide (lucide.dev).
abstract final class AppIcons {
  static const fuente = 'Lucide300';

  // ── Navegación ────────────────────────────────────────────────────────
  /// Volver (Lucide: arrow-left).
  static const IconData atras = IconData(0xe048, fontFamily: fuente);

  /// Paso o página anterior (Lucide: chevron-left).
  static const IconData anterior = IconData(0xe06e, fontFamily: fuente);

  /// Continuar (Lucide: arrow-right).
  static const IconData adelante = IconData(0xe049, fontFamily: fuente);

  /// Abrir el detalle, paso siguiente (Lucide: chevron-right).
  static const IconData siguiente = IconData(0xe06f, fontFamily: fuente);

  /// Subir, orden ascendente (Lucide: arrow-up).
  static const IconData arriba = IconData(0xe04a, fontFamily: fuente);

  /// Bajar, orden descendente (Lucide: arrow-down).
  static const IconData abajo = IconData(0xe042, fontFamily: fuente);

  /// Desplegar una lista o sección (Lucide: chevron-down).
  static const IconData desplegar = IconData(0xe06d, fontFamily: fuente);

  /// Plegar una sección (Lucide: chevron-up).
  static const IconData plegar = IconData(0xe070, fontFamily: fuente);

  /// Selector que despliega opciones (Lucide: chevrons-up-down).
  static const IconData expandir = IconData(0xe211, fontFamily: fuente);

  /// Cambiar o intercambiar (Lucide: arrow-left-right).
  static const IconData cambiar = IconData(0xe24a, fontFamily: fuente);

  /// Lista de pasos (Lucide: menu).
  static const IconData menu = IconData(0xe115, fontFamily: fuente);

  /// Más opciones (Lucide: ellipsis).
  static const IconData mas = IconData(0xe0b6, fontFamily: fuente);

  /// Menú de opciones (Lucide: ellipsis-vertical).
  static const IconData masVertical = IconData(0xe0b7, fontFamily: fuente);

  /// Vista en cuadrícula (Lucide: layout-grid).
  static const IconData cuadricula = IconData(0xe0ff, fontFamily: fuente);

  /// Conocer la app (Lucide: compass).
  static const IconData explorar = IconData(0xe09b, fontFamily: fuente);

  // ── Acciones ──────────────────────────────────────────────────────────
  /// Cerrar o cancelar (Lucide: x).
  static const IconData cerrar = IconData(0xe1b2, fontFamily: fuente);

  /// Agregar (Lucide: plus).
  static const IconData agregar = IconData(0xe13d, fontFamily: fuente);

  /// Agregar un elemento (Lucide: circle-plus).
  static const IconData agregarCirculo = IconData(0xe081, fontFamily: fuente);

  /// Quitar un elemento (Lucide: circle-minus).
  static const IconData quitarCirculo = IconData(0xe07e, fontFamily: fuente);

  /// Confirmar (Lucide: check).
  static const IconData listo = IconData(0xe06c, fontFamily: fuente);

  /// Editar (Lucide: pencil).
  static const IconData editar = IconData(0xe1f9, fontFamily: fuente);

  /// Editar un registro (Lucide: square-pen).
  static const IconData editarRegistro = IconData(0xe172, fontFamily: fuente);

  /// Eliminar (Lucide: trash-2).
  static const IconData eliminar = IconData(0xe18e, fontFamily: fuente);

  /// Borrar el último carácter (Lucide: delete).
  static const IconData borrar = IconData(0xe0ae, fontFamily: fuente);

  /// Deshacer (Lucide: undo-2).
  static const IconData deshacer = IconData(0xe2a1, fontFamily: fuente);

  /// Copiar (Lucide: copy).
  static const IconData copiar = IconData(0xe09e, fontFamily: fuente);

  /// Compartir (Lucide: share-2).
  static const IconData compartir = IconData(0xe156, fontFamily: fuente);

  /// Guardar (Lucide: save).
  static const IconData guardar = IconData(0xe14d, fontFamily: fuente);

  /// Descargar o guardar en el teléfono (Lucide: download).
  static const IconData descargar = IconData(0xe0b2, fontFamily: fuente);

  /// Imprimir (Lucide: printer).
  static const IconData imprimir = IconData(0xe141, fontFamily: fuente);

  /// Enviar (Lucide: send).
  static const IconData enviar = IconData(0xe152, fontFamily: fuente);

  /// Buscar (Lucide: search).
  static const IconData buscar = IconData(0xe151, fontFamily: fuente);

  /// Buscar dentro de un texto (Lucide: text-search).
  static const IconData buscarTexto = IconData(0xe5ad, fontFamily: fuente);

  /// Búsqueda sin resultados (Lucide: search-x).
  static const IconData sinResultados = IconData(0xe4ad, fontFamily: fuente);

  /// Filtros y ajustes (Lucide: sliders-horizontal).
  static const IconData filtros = IconData(0xe29a, fontFamily: fuente);

  /// Quitar filtros (Lucide: funnel-x).
  static const IconData sinFiltro = IconData(0xe3b5, fontFamily: fuente);

  /// Actualizar o sincronizar (Lucide: refresh-cw).
  static const IconData actualizar = IconData(0xe145, fontFamily: fuente);

  /// Repetir (Lucide: repeat).
  static const IconData repetir = IconData(0xe146, fontFamily: fuente);

  /// Mostrar (Lucide: eye).
  static const IconData ver = IconData(0xe0ba, fontFamily: fuente);

  /// Ocultar (Lucide: eye-off).
  static const IconData ocultar = IconData(0xe0bb, fontFamily: fuente);

  /// Iniciar sesión (Lucide: log-in).
  static const IconData ingresar = IconData(0xe10d, fontFamily: fuente);

  /// Cerrar sesión o salir (Lucide: log-out).
  static const IconData salir = IconData(0xe10e, fontFamily: fuente);

  /// Ocultar el teclado (Lucide: keyboard-off).
  static const IconData ocultarTeclado = IconData(0xe5de, fontFamily: fuente);

  /// Agregar una tarea (Lucide: list-plus).
  static const IconData agregarTarea = IconData(0xe23f, fontFamily: fuente);

  // ── Estados y avisos ──────────────────────────────────────────────────
  /// Información (Lucide: info).
  static const IconData info = IconData(0xe0f9, fontFamily: fuente);

  /// Ayuda (Lucide: circle-help).
  static const IconData ayuda = IconData(0xe082, fontFamily: fuente);

  /// Consejo (Lucide: lightbulb).
  static const IconData consejo = IconData(0xe1c2, fontFamily: fuente);

  /// Advertencia (Lucide: triangle-alert).
  static const IconData advertencia = IconData(0xe193, fontFamily: fuente);

  /// Error (Lucide: circle-alert).
  static const IconData error = IconData(0xe077, fontFamily: fuente);

  /// Requiere atención (Lucide: badge-alert).
  static const IconData urgente = IconData(0xe475, fontFamily: fuente);

  /// Completo o correcto (Lucide: circle-check).
  static const IconData completo = IconData(0xe226, fontFamily: fuente);

  /// Tarea terminada (Lucide: circle-check-big).
  static const IconData tareaLista = IconData(0xe07c, fontFamily: fuente);

  /// Cancelado o rechazado (Lucide: circle-x).
  static const IconData cancelar = IconData(0xe084, fontFamily: fuente);

  /// Bloqueado o no permitido (Lucide: ban).
  static const IconData bloquear = IconData(0xe051, fontFamily: fuente);

  /// No aplica (Lucide: circle-slash).
  static const IconData noAplica = IconData(0xe402, fontFamily: fuente);

  /// Pendiente (Lucide: clipboard-clock).
  static const IconData pendiente = IconData(0xe688, fontFamily: fuente);

  /// En espera (Lucide: hourglass).
  static const IconData espera = IconData(0xe296, fontFamily: fuente);

  /// Parcial (Lucide: circle-dashed).
  static const IconData parcial = IconData(0xe4b0, fontFamily: fuente);

  /// Sin marcar (Lucide: circle).
  static const IconData circulo = IconData(0xe076, fontFamily: fuente);

  /// Casilla o componente (Lucide: square).
  static const IconData cuadro = IconData(0xe167, fontFamily: fuente);

  /// Verificado (Lucide: badge-check).
  static const IconData verificado = IconData(0xe241, fontFamily: fuente);

  /// Seguridad (Lucide: shield).
  static const IconData seguridad = IconData(0xe158, fontFamily: fuente);

  /// Acceso verificado (Lucide: shield-check).
  static const IconData seguridadVerificada =
      IconData(0xe1ff, fontFamily: fuente);

  /// Bloqueado o de solo lectura (Lucide: lock).
  static const IconData bloqueado = IconData(0xe10b, fontFamily: fuente);

  /// Contraseña (Lucide: key-round).
  static const IconData clave = IconData(0xe4a3, fontFamily: fuente);

  /// Acceso biométrico (Lucide: fingerprint).
  static const IconData huella = IconData(0xe2cb, fontFamily: fuente);

  /// Notificaciones (Lucide: bell).
  static const IconData notificaciones = IconData(0xe059, fontFamily: fuente);

  /// Sin conexión (Lucide: cloud-off).
  static const IconData sinConexion = IconData(0xe08d, fontFamily: fuente);

  /// Listo para trabajar sin conexión (Lucide: zap).
  static const IconData listoSinConexion = IconData(0xe1b4, fontFamily: fuente);

  // ── Documentos y datos ────────────────────────────────────────────────
  /// Documento o PDF (Lucide: file-text).
  static const IconData documento = IconData(0xe0cc, fontFamily: fuente);

  /// Archivo (Lucide: file).
  static const IconData archivo = IconData(0xe0c0, fontFamily: fuente);

  /// Exportar o descargar un archivo (Lucide: file-down).
  static const IconData exportarArchivo = IconData(0xe318, fontFamily: fuente);

  /// Exportar (Lucide: file-output).
  static const IconData exportar = IconData(0xe0c8, fontFamily: fuente);

  /// Subir un archivo (Lucide: file-up).
  static const IconData subirArchivo = IconData(0xe32a, fontFamily: fuente);

  /// Leer texto con la cámara (Lucide: scan-text).
  static const IconData escanearDocumento =
      IconData(0xe538, fontFamily: fuente);

  /// Formulario (Lucide: clipboard-list).
  static const IconData formulario = IconData(0xe086, fontFamily: fuente);

  /// Formulario completo (Lucide: clipboard-check).
  static const IconData formularioCompleto =
      IconData(0xe219, fontFamily: fuente);

  /// Verificación (Lucide: file-check).
  static const IconData verificacion = IconData(0xe0c1, fontFamily: fuente);

  /// Lista de control (Lucide: list-checks).
  static const IconData lista = IconData(0xe1d0, fontFamily: fuente);

  /// Lista numerada (Lucide: list-ordered).
  static const IconData listaNumerada = IconData(0xe1d1, fontFamily: fuente);

  /// Resumen (Lucide: scroll-text).
  static const IconData resumen = IconData(0xe45f, fontFamily: fuente);

  /// Nota u observación (Lucide: notebook-pen).
  static const IconData nota = IconData(0xe596, fontFamily: fuente);

  /// Comentario (Lucide: message-square).
  static const IconData comentario = IconData(0xe117, fontFamily: fuente);

  /// Manual de uso (Lucide: book-open).
  static const IconData manual = IconData(0xe05f, fontFamily: fuente);

  /// Tabla o CSV (Lucide: sheet).
  static const IconData tabla = IconData(0xe157, fontFamily: fuente);

  /// Base de datos (Lucide: database).
  static const IconData datos = IconData(0xe0ad, fontFamily: fuente);

  /// Respaldo (Lucide: database-backup).
  static const IconData respaldo = IconData(0xe3ab, fontFamily: fuente);

  /// Servidor (Lucide: server).
  static const IconData servidor = IconData(0xe153, fontFamily: fuente);

  /// Red (Lucide: network).
  static const IconData red = IconData(0xe125, fontFamily: fuente);

  /// Conexión con la API (Lucide: plug).
  static const IconData api = IconData(0xe37f, fontFamily: fuente);

  /// Puerto de comunicación (Lucide: ethernet-port).
  static const IconData puerto = IconData(0xe620, fontFamily: fuente);

  /// Etiqueta o sticker (Lucide: tag).
  static const IconData etiqueta = IconData(0xe17f, fontFamily: fuente);

  /// Código o número (Lucide: hash).
  static const IconData numero = IconData(0xe0ef, fontFamily: fuente);

  /// Número de serie (Lucide: barcode).
  static const IconData serie = IconData(0xe533, fontFamily: fuente);

  /// Clase de exactitud (Lucide: layers).
  static const IconData clase = IconData(0xe529, fontFamily: fuente);

  /// Categoría (Lucide: shapes).
  static const IconData categoria = IconData(0xe4b3, fontFamily: fuente);

  /// Texto (Lucide: type).
  static const IconData texto = IconData(0xe198, fontFamily: fuente);

  /// Historial (Lucide: history).
  static const IconData historial = IconData(0xe1f5, fontFamily: fuente);

  /// Carpeta (Lucide: folder).
  static const IconData carpeta = IconData(0xe0d7, fontFamily: fuente);

  /// Carpeta abierta (Lucide: folder-open).
  static const IconData carpetaAbierta = IconData(0xe247, fontFamily: fuente);

  /// Bandeja vacía (Lucide: inbox).
  static const IconData bandeja = IconData(0xe0f7, fontFamily: fuente);

  /// Sin elementos (Lucide: package-open).
  static const IconData vacio = IconData(0xe2cc, fontFamily: fuente);

  // ── Fotos y cámara ────────────────────────────────────────────────────
  /// Tomar una foto (Lucide: camera).
  static const IconData camara = IconData(0xe064, fontFamily: fuente);

  /// Agregar una foto (Lucide: image-plus).
  static const IconData agregarFoto = IconData(0xe1f7, fontFamily: fuente);

  /// Fotografías (Lucide: images).
  static const IconData fotos = IconData(0xe5c4, fontFamily: fuente);

  /// Imagen (Lucide: image).
  static const IconData imagen = IconData(0xe0f6, fontFamily: fuente);

  /// Imagen no disponible (Lucide: image-off).
  static const IconData imagenNoDisponible =
      IconData(0xe1c0, fontFamily: fuente);

  /// Sin fotografías (Lucide: camera-off).
  static const IconData sinFotos = IconData(0xe065, fontFamily: fuente);

  /// Cambiar de cámara (Lucide: switch-camera).
  static const IconData cambiarCamara = IconData(0xe17c, fontFamily: fuente);

  /// Flash (Lucide: zap).
  static const IconData flash = IconData(0xe1b4, fontFamily: fuente);

  /// Linterna encendida (Lucide: flashlight).
  static const IconData linterna = IconData(0xe0d3, fontFamily: fuente);

  /// Linterna apagada (Lucide: flashlight-off).
  static const IconData linternaApagada = IconData(0xe0d4, fontFamily: fuente);

  /// Enfocar o leer el indicador (Lucide: focus).
  static const IconData enfocar = IconData(0xe29e, fontFamily: fuente);

  /// Código QR (Lucide: qr-code).
  static const IconData qr = IconData(0xe1df, fontFamily: fuente);

  /// Escanear un código QR (Lucide: scan-qr-code).
  static const IconData escanearQr = IconData(0xe5f6, fontFamily: fuente);

  /// Firma (Lucide: signature).
  static const IconData firma = IconData(0xe5f2, fontFamily: fuente);

  // ── Servicios y balanzas ──────────────────────────────────────────────
  /// Balanza o calibración (Lucide: scale).
  static const IconData balanza = IconData(0xe212, fontFamily: fuente);

  /// Pesa o carga (Lucide: weight).
  static const IconData pesa = IconData(0xe530, fontFamily: fuente);

  /// Soporte técnico o ajuste (Lucide: wrench).
  static const IconData soporte = IconData(0xe1b1, fontFamily: fuente);

  /// Herramientas (Lucide: hammer).
  static const IconData herramientas = IconData(0xe0ec, fontFamily: fuente);

  /// Reparación (Lucide: bandage).
  static const IconData reparacion = IconData(0xe61d, fontFamily: fuente);

  /// Equipo o modelo (Lucide: cog).
  static const IconData equipo = IconData(0xe30b, fontFamily: fuente);

  /// Electrónica (Lucide: cpu).
  static const IconData chip = IconData(0xe0a9, fontFamily: fuente);

  /// Computadora o indicador (Lucide: monitor).
  static const IconData computadora = IconData(0xe11d, fontFamily: fuente);

  /// Instalación eléctrica (Lucide: cable).
  static const IconData electrico = IconData(0xe4e3, fontFamily: fuente);

  /// Sensor (Lucide: radio).
  static const IconData sensor = IconData(0xe142, fontFamily: fuente);

  /// Cimientos y estructura (Lucide: brick-wall).
  static const IconData cimientos = IconData(0xe581, fontFamily: fuente);

  /// Suciedad o limpieza (Lucide: sparkles).
  static const IconData suciedad = IconData(0xe412, fontFamily: fuente);

  /// Limpieza (Lucide: spray-can).
  static const IconData limpieza = IconData(0xe495, fontFamily: fuente);

  /// Excentricidad (Lucide: crosshair).
  static const IconData excentricidad = IconData(0xe0ac, fontFamily: fuente);

  /// Rango o medida (Lucide: ruler).
  static const IconData medida = IconData(0xe14b, fontFamily: fuente);

  /// Gráfico o linealidad (Lucide: chart-line).
  static const IconData grafico = IconData(0xe2a5, fontFamily: fuente);

  /// Cálculo (Lucide: calculator).
  static const IconData calcular = IconData(0xe1bc, fontFamily: fuente);

  /// Laboratorio o metrología (Lucide: flask-conical).
  static const IconData laboratorio = IconData(0xe0d5, fontFamily: fuente);

  /// Temperatura (Lucide: thermometer).
  static const IconData temperatura = IconData(0xe186, fontFamily: fuente);

  /// Humedad (Lucide: droplet).
  static const IconData humedad = IconData(0xe0b4, fontFamily: fuente);

  /// Recepción de instrumentos (RIM) (Lucide: package).
  static const IconData rim = IconData(0xe129, fontFamily: fuente);

  /// Trabajo o servicio (Lucide: briefcase).
  static const IconData trabajo = IconData(0xe062, fontFamily: fuente);

  /// Oportunidad comercial (Lucide: handshake).
  static const IconData oportunidad = IconData(0xe5c0, fontFamily: fuente);

  /// Venta (Lucide: store).
  static const IconData venta = IconData(0xe3e4, fontFamily: fuente);

  /// Configuración de equipos (Lucide: settings-2).
  static const IconData configurarEquipo = IconData(0xe245, fontFamily: fuente);

  /// Accesorio o extensión (Lucide: puzzle).
  static const IconData extension = IconData(0xe29c, fontFamily: fuente);

  // ── Clientes y lugares ────────────────────────────────────────────────
  /// Empresa o cliente (Lucide: building-2).
  static const IconData empresa = IconData(0xe290, fontFamily: fuente);

  /// Agregar una planta o balanza nueva (Lucide: square-plus).
  static const IconData agregarEmpresa = IconData(0xe173, fontFamily: fuente);

  /// Planta (Lucide: factory).
  static const IconData planta = IconData(0xe29f, fontFamily: fuente);

  /// Ciudad (Lucide: building).
  static const IconData ciudad = IconData(0xe1cc, fontFamily: fuente);

  /// Ubicación (Lucide: map-pin).
  static const IconData ubicacion = IconData(0xe111, fontFamily: fuente);

  /// Mapa (Lucide: map).
  static const IconData mapa = IconData(0xe110, fontFamily: fuente);

  /// Persona o usuario (Lucide: user).
  static const IconData persona = IconData(0xe19f, fontFamily: fuente);

  /// Personas (Lucide: users).
  static const IconData personas = IconData(0xe1a4, fontFamily: fuente);

  /// Agregar una persona (Lucide: user-plus).
  static const IconData agregarPersona = IconData(0xe1a2, fontFamily: fuente);

  /// Quitar una persona (Lucide: user-minus).
  static const IconData quitarPersona = IconData(0xe1a1, fontFamily: fuente);

  /// Buscar una persona (Lucide: user-search).
  static const IconData buscarPersona = IconData(0xe579, fontFamily: fuente);

  /// Teléfono (Lucide: smartphone).
  static const IconData telefono = IconData(0xe163, fontFamily: fuente);

  /// Soporte al usuario (Lucide: headset).
  static const IconData soporteAgente = IconData(0xe5bd, fontFamily: fuente);

  // ── Fechas y tiempo ───────────────────────────────────────────────────
  /// Fecha (Lucide: calendar).
  static const IconData calendario = IconData(0xe063, fontFamily: fuente);

  /// Fecha cumplida (Lucide: calendar-check).
  static const IconData fechaLista = IconData(0xe2b7, fontFamily: fuente);

  /// Vencimientos (Lucide: calendar-clock).
  static const IconData vencimientos = IconData(0xe304, fontFamily: fuente);

  /// Próxima fecha (Lucide: calendar-sync).
  static const IconData proximaFecha = IconData(0xe636, fontFamily: fuente);

  /// Hora (Lucide: clock).
  static const IconData hora = IconData(0xe087, fontFamily: fuente);

  // ── Nube ──────────────────────────────────────────────────────────────
  /// Subir al servidor (Lucide: cloud-upload).
  static const IconData subir = IconData(0xe091, fontFamily: fuente);

  /// Descargar del servidor (Lucide: cloud-download).
  static const IconData descargarNube = IconData(0xe089, fontFamily: fuente);

  /// Subido (Lucide: cloud-check).
  static const IconData nubeLista = IconData(0xe66e, fontFamily: fuente);

  /// Sincronizar (Lucide: refresh-ccw).
  static const IconData sincronizar = IconData(0xe144, fontFamily: fuente);

  // ── Ajustes ───────────────────────────────────────────────────────────
  /// Ajustes (Lucide: settings).
  static const IconData ajustes = IconData(0xe154, fontFamily: fuente);

  /// Tema (Lucide: sun-moon).
  static const IconData tema = IconData(0xe2b2, fontFamily: fuente);

  /// Tema del sistema (Lucide: contrast).
  static const IconData temaAuto = IconData(0xe09d, fontFamily: fuente);

  /// Tema claro (Lucide: sun).
  static const IconData claro = IconData(0xe178, fontFamily: fuente);

  /// Tema oscuro (Lucide: moon).
  static const IconData oscuro = IconData(0xe11e, fontFamily: fuente);
}
