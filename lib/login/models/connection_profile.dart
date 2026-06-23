// Modelo de perfil de conexión a la base de datos.
// Representa una configuración guardada con nombre, servidor y credenciales.

class ConnectionProfile {
  final String id;
  final String nombre;
  final String ip;
  final String puerto;
  final String baseDatos;
  final String usuarioBD;
  final String contrasenaBD;
  final bool esPredeterminado;
  final DateTime fechaCreacion;

  ConnectionProfile({
    required this.id,
    required this.nombre,
    required this.ip,
    required this.puerto,
    required this.baseDatos,
    required this.usuarioBD,
    required this.contrasenaBD,
    this.esPredeterminado = false,
    DateTime? fechaCreacion,
  }) : fechaCreacion = fechaCreacion ?? DateTime.now();

  factory ConnectionProfile.fromJson(Map<String, dynamic> json) {
    return ConnectionProfile(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      ip: json['ip'] as String,
      puerto: json['puerto'] as String,
      baseDatos: json['baseDatos'] as String,
      usuarioBD: json['usuarioBD'] as String,
      contrasenaBD: json['contrasenaBD'] as String,
      esPredeterminado: json['esPredeterminado'] as bool? ?? false,
      fechaCreacion: json['fechaCreacion'] != null
          ? DateTime.parse(json['fechaCreacion'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'ip': ip,
      'puerto': puerto,
      'baseDatos': baseDatos,
      'usuarioBD': usuarioBD,
      'contrasenaBD': contrasenaBD,
      'esPredeterminado': esPredeterminado,
      'fechaCreacion': fechaCreacion.toIso8601String(),
    };
  }

  ConnectionProfile copyWith({
    String? id,
    String? nombre,
    String? ip,
    String? puerto,
    String? baseDatos,
    String? usuarioBD,
    String? contrasenaBD,
    bool? esPredeterminado,
    DateTime? fechaCreacion,
  }) {
    return ConnectionProfile(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      ip: ip ?? this.ip,
      puerto: puerto ?? this.puerto,
      baseDatos: baseDatos ?? this.baseDatos,
      usuarioBD: usuarioBD ?? this.usuarioBD,
      contrasenaBD: contrasenaBD ?? this.contrasenaBD,
      esPredeterminado: esPredeterminado ?? this.esPredeterminado,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
    );
  }
}
