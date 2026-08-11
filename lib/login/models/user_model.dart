// lib/login/models/user_model.dart

class UserModel {
  final String usuario;
  final String nombre1;
  final String apellido1;
  final String apellido2;
  final String tituloAbr;
  final String estado;
  final String accesoApp;
  final DateTime? savedAt;
  final DateTime? lastVerifiedAt;

  UserModel({
    required this.usuario,
    required this.nombre1,
    required this.apellido1,
    required this.apellido2,
    required this.tituloAbr,
    required this.estado,
    this.accesoApp = '0',
    this.savedAt,
    this.lastVerifiedAt,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      usuario: map['usuario']?.toString() ?? '',
      nombre1: map['nombre1']?.toString() ?? '',
      apellido1: map['apellido1']?.toString() ?? '',
      apellido2: map['apellido2']?.toString() ?? '',
      tituloAbr:
          map['titulo_abr']?.toString() ?? map['tituloAbr']?.toString() ?? '',
      estado: map['estado']?.toString() ?? '',
      accesoApp:
          map['acceso_app']?.toString() ?? map['accesoApp']?.toString() ?? '0',
      savedAt: DateTime.tryParse(map['fecha_guardado']?.toString() ?? ''),
      lastVerifiedAt:
          DateTime.tryParse(map['last_verified_at']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'usuario': usuario,
      'nombre1': nombre1,
      'apellido1': apellido1,
      'apellido2': apellido2,
      'titulo_abr': tituloAbr,
      'estado': estado,
      'acceso_app': accesoApp, // Guardar nuevo campo
      'fecha_guardado': DateTime.now().toIso8601String(),
    };
  }

  String get fullName => '$tituloAbr $nombre1 $apellido1 $apellido2'
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  bool get isActive => estado.toUpperCase() == 'ACTIVO';

  bool get hasAppAccess => accesoApp == '1';

  bool get isSelectable => isActive && hasAppAccess;
}
