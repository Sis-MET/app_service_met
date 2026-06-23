// Servicio de gestión de perfiles de conexión.
// Administra CRUD y persistencia usando flutter_secure_storage.
// Expone los perfiles como ChangeNotifier para reactividad.

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/connection_profile.dart';

class ConnectionProfileService extends ChangeNotifier {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  static const String _storageKey = 'connection_profiles';
  static const String _selectedProfileKey = 'selected_profile_id';

  List<ConnectionProfile> _perfiles = [];
  String? _perfilSeleccionadoId;

  List<ConnectionProfile> get perfiles => List.unmodifiable(_perfiles);
  String? get perfilSeleccionadoId => _perfilSeleccionadoId;

  ConnectionProfile? get perfilSeleccionado {
    if (_perfilSeleccionadoId == null) return null;
    try {
      return _perfiles.firstWhere((p) => p.id == _perfilSeleccionadoId);
    } catch (_) {
      return null;
    }
  }

  // Perfiles predeterminados
  static final List<ConnectionProfile> perfilesPredeterminados = [
    ConnectionProfile(
      id: 'local_default',
      nombre: 'Local',
      ip: '192.168.1.5',
      puerto: '1433',
      baseDatos: 'DataMET',
      usuarioBD: 'ServiceMET',
      contrasenaBD: 'Met25',
      esPredeterminado: true,
    ),
    ConnectionProfile(
      id: 'vpn_default',
      nombre: 'VPN',
      ip: '10.50.8.1',
      puerto: '1433',
      baseDatos: 'DataMET',
      usuarioBD: 'ServiceMET',
      contrasenaBD: 'Met25',
      esPredeterminado: true,
    ),
  ];

  // Inicializar: cargar perfiles guardados o crear predeterminados
  Future<void> inicializar() async {
    final json = await _secureStorage.read(key: _storageKey);
    final selectedId = await _secureStorage.read(key: _selectedProfileKey);

    if (json != null && json.isNotEmpty) {
      final List<dynamic> decoded = jsonDecode(json);
      _perfiles = decoded
          .map((item) =>
              ConnectionProfile.fromJson(item as Map<String, dynamic>))
          .toList();
    } else {
      _perfiles = List.from(perfilesPredeterminados);
      await _guardar();
    }

    _perfilSeleccionadoId = selectedId;
    if (_perfilSeleccionadoId != null &&
        !_perfiles.any((p) => p.id == _perfilSeleccionadoId)) {
      _perfilSeleccionadoId = null;
    }

    notifyListeners();
  }

  // Seleccionar perfil activo
  Future<void> seleccionarPerfil(String id) async {
    _perfilSeleccionadoId = id;
    await _secureStorage.write(key: _selectedProfileKey, value: id);
    notifyListeners();
  }

  // Guardar o actualizar perfil
  Future<void> guardarPerfil(ConnectionProfile perfil) async {
    final index = _perfiles.indexWhere((p) => p.id == perfil.id);
    if (index >= 0) {
      _perfiles[index] = perfil;
    } else {
      _perfiles.add(perfil);
    }
    await _guardar();
    notifyListeners();
  }

  // Eliminar perfil personalizado (no permite eliminar predeterminados)
  Future<bool> eliminarPerfil(String id) async {
    final perfil = _perfiles.firstWhere(
      (p) => p.id == id,
      orElse: () => ConnectionProfile(
          id: '',
          nombre: '',
          ip: '',
          puerto: '',
          baseDatos: '',
          usuarioBD: '',
          contrasenaBD: ''),
    );
    if (perfil.esPredeterminado) return false;

    _perfiles.removeWhere((p) => p.id == id);
    if (_perfilSeleccionadoId == id) {
      _perfilSeleccionadoId = null;
      await _secureStorage.delete(key: _selectedProfileKey);
    }
    await _guardar();
    notifyListeners();
    return true;
  }

  // Obtener mapa de valores del perfil seleccionado
  Map<String, String> getValoresConexion() {
    final perfil = perfilSeleccionado;
    if (perfil == null) {
      return {
        'ip': '',
        'port': '1433',
        'database': '',
        'username': '',
        'password': '',
      };
    }
    return {
      'ip': perfil.ip,
      'port': perfil.puerto,
      'database': perfil.baseDatos,
      'username': perfil.usuarioBD,
      'password': perfil.contrasenaBD,
    };
  }

  // Generar ID único
  String generarId() {
    return 'profile_${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<void> _guardar() async {
    final json = jsonEncode(_perfiles.map((p) => p.toJson()).toList());
    await _secureStorage.write(key: _storageKey, value: json);
  }
}
