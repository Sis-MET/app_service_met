// Perfil de la API interna. Los campos de base de datos se conservan únicamente
// para migrar instalaciones antiguas y ya no se utilizan desde Flutter.

class ConnectionProfile {
  final String id;
  final String nombre;
  final String ip;
  final String puerto;
  final String baseDatos;
  final String usuarioBD;
  final String contrasenaBD;
  final String apiUrl;
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
    required this.apiUrl,
    this.esPredeterminado = false,
    DateTime? fechaCreacion,
  }) : fechaCreacion = fechaCreacion ?? DateTime.now();

  factory ConnectionProfile.fromJson(Map<String, dynamic> json) {
    return ConnectionProfile(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      ip: json['ip']?.toString() ?? '',
      puerto: json['puerto']?.toString() ?? '',
      baseDatos: json['baseDatos']?.toString() ?? '',
      usuarioBD: json['usuarioBD']?.toString() ?? '',
      contrasenaBD: json['contrasenaBD']?.toString() ?? '',
      apiUrl: json['apiUrl']?.toString() ??
          'https://${json['ip']}:${json['apiPort'] ?? '3100'}',
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
      'apiUrl': apiUrl,
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
    String? apiUrl,
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
      apiUrl: apiUrl ?? this.apiUrl,
      esPredeterminado: esPredeterminado ?? this.esPredeterminado,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
    );
  }
}
