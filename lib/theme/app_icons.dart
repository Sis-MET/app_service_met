import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Íconos de ServiceMET: una sola familia de línea fina y puntas
/// redondeadas (Lucide, trazo 300).
///
/// Use siempre estos nombres en vez de `Icons` o Font Awesome: así toda la
/// app conserva el mismo estilo y se cambia en un solo lugar. Para un ícono
/// nuevo, agréguelo aquí con un nombre que diga para qué sirve.
abstract final class AppIcons {
  // ── Navegación ────────────────────────────────────────────────────────
  /// Volver.
  static const IconData atras = LucideIcons.arrowLeft300;

  /// Paso o página anterior.
  static const IconData anterior = LucideIcons.chevronLeft300;

  /// Continuar.
  static const IconData adelante = LucideIcons.arrowRight300;

  /// Abrir el detalle, paso siguiente.
  static const IconData siguiente = LucideIcons.chevronRight300;

  /// Subir, orden ascendente.
  static const IconData arriba = LucideIcons.arrowUp300;

  /// Bajar, orden descendente.
  static const IconData abajo = LucideIcons.arrowDown300;

  /// Desplegar una lista o sección.
  static const IconData desplegar = LucideIcons.chevronDown300;

  /// Plegar una sección.
  static const IconData plegar = LucideIcons.chevronUp300;

  /// Selector que despliega opciones.
  static const IconData expandir = LucideIcons.chevronsUpDown300;

  /// Cambiar o intercambiar.
  static const IconData cambiar = LucideIcons.arrowLeftRight300;

  /// Lista de pasos.
  static const IconData menu = LucideIcons.menu300;

  /// Más opciones.
  static const IconData mas = LucideIcons.ellipsis300;

  /// Menú de opciones.
  static const IconData masVertical = LucideIcons.ellipsisVertical300;

  /// Vista en cuadrícula.
  static const IconData cuadricula = LucideIcons.layoutGrid300;

  /// Conocer la app.
  static const IconData explorar = LucideIcons.compass300;

  // ── Acciones ──────────────────────────────────────────────────────────
  /// Cerrar o cancelar.
  static const IconData cerrar = LucideIcons.x300;

  /// Agregar.
  static const IconData agregar = LucideIcons.plus300;

  /// Agregar un elemento.
  static const IconData agregarCirculo = LucideIcons.circlePlus300;

  /// Quitar un elemento.
  static const IconData quitarCirculo = LucideIcons.circleMinus300;

  /// Confirmar.
  static const IconData listo = LucideIcons.check300;

  /// Editar.
  static const IconData editar = LucideIcons.pencil300;

  /// Editar un registro.
  static const IconData editarRegistro = LucideIcons.squarePen300;

  /// Eliminar.
  static const IconData eliminar = LucideIcons.trash2300;

  /// Borrar el último carácter.
  static const IconData borrar = LucideIcons.delete300;

  /// Deshacer.
  static const IconData deshacer = LucideIcons.undo2300;

  /// Copiar.
  static const IconData copiar = LucideIcons.copy300;

  /// Compartir.
  static const IconData compartir = LucideIcons.share2300;

  /// Guardar.
  static const IconData guardar = LucideIcons.save300;

  /// Descargar o guardar en el teléfono.
  static const IconData descargar = LucideIcons.download300;

  /// Imprimir.
  static const IconData imprimir = LucideIcons.printer300;

  /// Enviar.
  static const IconData enviar = LucideIcons.send300;

  /// Buscar.
  static const IconData buscar = LucideIcons.search300;

  /// Buscar dentro de un texto.
  static const IconData buscarTexto = LucideIcons.textSearch300;

  /// Búsqueda sin resultados.
  static const IconData sinResultados = LucideIcons.searchX300;

  /// Filtros y ajustes.
  static const IconData filtros = LucideIcons.slidersHorizontal300;

  /// Quitar filtros.
  static const IconData sinFiltro = LucideIcons.funnelX300;

  /// Actualizar o sincronizar.
  static const IconData actualizar = LucideIcons.refreshCw300;

  /// Repetir.
  static const IconData repetir = LucideIcons.repeat300;

  /// Mostrar.
  static const IconData ver = LucideIcons.eye300;

  /// Ocultar.
  static const IconData ocultar = LucideIcons.eyeOff300;

  /// Iniciar sesión.
  static const IconData ingresar = LucideIcons.logIn300;

  /// Cerrar sesión o salir.
  static const IconData salir = LucideIcons.logOut300;

  /// Ocultar el teclado.
  static const IconData ocultarTeclado = LucideIcons.keyboardOff300;

  /// Agregar una tarea.
  static const IconData agregarTarea = LucideIcons.listPlus300;

  // ── Estados y avisos ──────────────────────────────────────────────────
  /// Información.
  static const IconData info = LucideIcons.info300;

  /// Ayuda.
  static const IconData ayuda = LucideIcons.circleHelp300;

  /// Consejo.
  static const IconData consejo = LucideIcons.lightbulb300;

  /// Advertencia.
  static const IconData advertencia = LucideIcons.triangleAlert300;

  /// Error.
  static const IconData error = LucideIcons.circleAlert300;

  /// Requiere atención.
  static const IconData urgente = LucideIcons.badgeAlert300;

  /// Completo o correcto.
  static const IconData completo = LucideIcons.circleCheck300;

  /// Tarea terminada.
  static const IconData tareaLista = LucideIcons.circleCheckBig300;

  /// Cancelado o rechazado.
  static const IconData cancelar = LucideIcons.circleX300;

  /// Bloqueado o no permitido.
  static const IconData bloquear = LucideIcons.ban300;

  /// No aplica.
  static const IconData noAplica = LucideIcons.circleSlash300;

  /// Pendiente.
  static const IconData pendiente = LucideIcons.clipboardClock300;

  /// En espera.
  static const IconData espera = LucideIcons.hourglass300;

  /// Parcial.
  static const IconData parcial = LucideIcons.circleDashed300;

  /// Sin marcar.
  static const IconData circulo = LucideIcons.circle300;

  /// Casilla o componente.
  static const IconData cuadro = LucideIcons.square300;

  /// Verificado.
  static const IconData verificado = LucideIcons.badgeCheck300;

  /// Seguridad.
  static const IconData seguridad = LucideIcons.shield300;

  /// Acceso verificado.
  static const IconData seguridadVerificada = LucideIcons.shieldCheck300;

  /// Bloqueado o de solo lectura.
  static const IconData bloqueado = LucideIcons.lock300;

  /// Contraseña.
  static const IconData clave = LucideIcons.keyRound300;

  /// Acceso biométrico.
  static const IconData huella = LucideIcons.fingerprint300;

  /// Notificaciones.
  static const IconData notificaciones = LucideIcons.bell300;

  /// Sin conexión.
  static const IconData sinConexion = LucideIcons.cloudOff300;

  /// Listo para trabajar sin conexión.
  static const IconData listoSinConexion = LucideIcons.zap300;

  // ── Documentos y datos ────────────────────────────────────────────────
  /// Documento o PDF.
  static const IconData documento = LucideIcons.fileText300;

  /// Archivo.
  static const IconData archivo = LucideIcons.file300;

  /// Exportar o descargar un archivo.
  static const IconData exportarArchivo = LucideIcons.fileDown300;

  /// Exportar.
  static const IconData exportar = LucideIcons.fileOutput300;

  /// Subir un archivo.
  static const IconData subirArchivo = LucideIcons.fileUp300;

  /// Leer texto con la cámara.
  static const IconData escanearDocumento = LucideIcons.scanText300;

  /// Formulario.
  static const IconData formulario = LucideIcons.clipboardList300;

  /// Formulario completo.
  static const IconData formularioCompleto = LucideIcons.clipboardCheck300;

  /// Verificación.
  static const IconData verificacion = LucideIcons.fileCheck300;

  /// Lista de control.
  static const IconData lista = LucideIcons.listChecks300;

  /// Lista numerada.
  static const IconData listaNumerada = LucideIcons.listOrdered300;

  /// Resumen.
  static const IconData resumen = LucideIcons.scrollText300;

  /// Nota u observación.
  static const IconData nota = LucideIcons.notebookPen300;

  /// Comentario.
  static const IconData comentario = LucideIcons.messageSquare300;

  /// Manual de uso.
  static const IconData manual = LucideIcons.bookOpen300;

  /// Tabla o CSV.
  static const IconData tabla = LucideIcons.sheet300;

  /// Base de datos.
  static const IconData datos = LucideIcons.database300;

  /// Respaldo.
  static const IconData respaldo = LucideIcons.databaseBackup300;

  /// Servidor.
  static const IconData servidor = LucideIcons.server300;

  /// Red.
  static const IconData red = LucideIcons.network300;

  /// Conexión con la API.
  static const IconData api = LucideIcons.plug300;

  /// Puerto de comunicación.
  static const IconData puerto = LucideIcons.ethernetPort300;

  /// Etiqueta o sticker.
  static const IconData etiqueta = LucideIcons.tag300;

  /// Código o número.
  static const IconData numero = LucideIcons.hash300;

  /// Número de serie.
  static const IconData serie = LucideIcons.barcode300;

  /// Clase de exactitud.
  static const IconData clase = LucideIcons.layers300;

  /// Categoría.
  static const IconData categoria = LucideIcons.shapes300;

  /// Texto.
  static const IconData texto = LucideIcons.type300;

  /// Historial.
  static const IconData historial = LucideIcons.history300;

  /// Carpeta.
  static const IconData carpeta = LucideIcons.folder300;

  /// Carpeta abierta.
  static const IconData carpetaAbierta = LucideIcons.folderOpen300;

  /// Bandeja vacía.
  static const IconData bandeja = LucideIcons.inbox300;

  /// Sin elementos.
  static const IconData vacio = LucideIcons.packageOpen300;

  // ── Fotos y cámara ────────────────────────────────────────────────────
  /// Tomar una foto.
  static const IconData camara = LucideIcons.camera300;

  /// Agregar una foto.
  static const IconData agregarFoto = LucideIcons.imagePlus300;

  /// Fotografías.
  static const IconData fotos = LucideIcons.images300;

  /// Imagen.
  static const IconData imagen = LucideIcons.image300;

  /// Imagen no disponible.
  static const IconData imagenNoDisponible = LucideIcons.imageOff300;

  /// Sin fotografías.
  static const IconData sinFotos = LucideIcons.cameraOff300;

  /// Cambiar de cámara.
  static const IconData cambiarCamara = LucideIcons.switchCamera300;

  /// Flash.
  static const IconData flash = LucideIcons.zap300;

  /// Linterna encendida.
  static const IconData linterna = LucideIcons.flashlight300;

  /// Linterna apagada.
  static const IconData linternaApagada = LucideIcons.flashlightOff300;

  /// Enfocar o leer el indicador.
  static const IconData enfocar = LucideIcons.focus300;

  /// Código QR.
  static const IconData qr = LucideIcons.qrCode300;

  /// Escanear un código QR.
  static const IconData escanearQr = LucideIcons.scanQrCode300;

  /// Firma.
  static const IconData firma = LucideIcons.signature300;

  // ── Servicios y balanzas ──────────────────────────────────────────────
  /// Balanza o calibración.
  static const IconData balanza = LucideIcons.scale300;

  /// Pesa o carga.
  static const IconData pesa = LucideIcons.weight300;

  /// Soporte técnico o ajuste.
  static const IconData soporte = LucideIcons.wrench300;

  /// Herramientas.
  static const IconData herramientas = LucideIcons.hammer300;

  /// Reparación.
  static const IconData reparacion = LucideIcons.bandage300;

  /// Equipo o modelo.
  static const IconData equipo = LucideIcons.cog300;

  /// Electrónica.
  static const IconData chip = LucideIcons.cpu300;

  /// Computadora o indicador.
  static const IconData computadora = LucideIcons.monitor300;

  /// Instalación eléctrica.
  static const IconData electrico = LucideIcons.cable300;

  /// Sensor.
  static const IconData sensor = LucideIcons.radio300;

  /// Cimientos y estructura.
  static const IconData cimientos = LucideIcons.brickWall300;

  /// Suciedad o limpieza.
  static const IconData suciedad = LucideIcons.sparkles300;

  /// Limpieza.
  static const IconData limpieza = LucideIcons.sprayCan300;

  /// Excentricidad.
  static const IconData excentricidad = LucideIcons.crosshair300;

  /// Rango o medida.
  static const IconData medida = LucideIcons.ruler300;

  /// Gráfico o linealidad.
  static const IconData grafico = LucideIcons.chartLine300;

  /// Cálculo.
  static const IconData calcular = LucideIcons.calculator300;

  /// Laboratorio o metrología.
  static const IconData laboratorio = LucideIcons.flaskConical300;

  /// Temperatura.
  static const IconData temperatura = LucideIcons.thermometer300;

  /// Humedad.
  static const IconData humedad = LucideIcons.droplet300;

  /// Recepción de instrumentos (RIM).
  static const IconData rim = LucideIcons.package300;

  /// Trabajo o servicio.
  static const IconData trabajo = LucideIcons.briefcase300;

  /// Oportunidad comercial.
  static const IconData oportunidad = LucideIcons.handshake300;

  /// Venta.
  static const IconData venta = LucideIcons.store300;

  /// Configuración de equipos.
  static const IconData configurarEquipo = LucideIcons.settings2300;

  /// Accesorio o extensión.
  static const IconData extension = LucideIcons.puzzle300;

  // ── Clientes y lugares ────────────────────────────────────────────────
  /// Empresa o cliente.
  static const IconData empresa = LucideIcons.building2300;

  /// Agregar una planta o balanza nueva.
  static const IconData agregarEmpresa = LucideIcons.squarePlus300;

  /// Planta.
  static const IconData planta = LucideIcons.factory300;

  /// Ciudad.
  static const IconData ciudad = LucideIcons.building300;

  /// Ubicación.
  static const IconData ubicacion = LucideIcons.mapPin300;

  /// Mapa.
  static const IconData mapa = LucideIcons.map300;

  /// Persona o usuario.
  static const IconData persona = LucideIcons.user300;

  /// Personas.
  static const IconData personas = LucideIcons.users300;

  /// Agregar una persona.
  static const IconData agregarPersona = LucideIcons.userPlus300;

  /// Quitar una persona.
  static const IconData quitarPersona = LucideIcons.userMinus300;

  /// Buscar una persona.
  static const IconData buscarPersona = LucideIcons.userSearch300;

  /// Teléfono.
  static const IconData telefono = LucideIcons.smartphone300;

  /// Soporte al usuario.
  static const IconData soporteAgente = LucideIcons.headset300;

  // ── Fechas y tiempo ───────────────────────────────────────────────────
  /// Fecha.
  static const IconData calendario = LucideIcons.calendar300;

  /// Fecha cumplida.
  static const IconData fechaLista = LucideIcons.calendarCheck300;

  /// Vencimientos.
  static const IconData vencimientos = LucideIcons.calendarClock300;

  /// Próxima fecha.
  static const IconData proximaFecha = LucideIcons.calendarSync300;

  /// Hora.
  static const IconData hora = LucideIcons.clock300;

  // ── Nube ──────────────────────────────────────────────────────────────
  /// Subir al servidor.
  static const IconData subir = LucideIcons.cloudUpload300;

  /// Descargar del servidor.
  static const IconData descargarNube = LucideIcons.cloudDownload300;

  /// Subido.
  static const IconData nubeLista = LucideIcons.cloudCheck300;

  /// Sincronizar.
  static const IconData sincronizar = LucideIcons.refreshCcw300;

  // ── Ajustes ───────────────────────────────────────────────────────────
  /// Ajustes.
  static const IconData ajustes = LucideIcons.settings300;

  /// Tema.
  static const IconData tema = LucideIcons.sunMoon300;

  /// Tema del sistema.
  static const IconData temaAuto = LucideIcons.contrast300;

  /// Tema claro.
  static const IconData claro = LucideIcons.sun300;

  /// Tema oscuro.
  static const IconData oscuro = LucideIcons.moon300;
}
