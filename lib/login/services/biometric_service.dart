// Servicio centralizado para autenticación biométrica (huella digital / Face ID)
// Gestiona detección de hardware, autenticación y persistencia de preferencias
// mediante flutter_secure_storage para garantizar almacenamiento seguro.

import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class BiometricService {
  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // ── Constantes de almacenamiento seguro ──
  static const String _biometricEnabledKey = 'biometric_enabled';
  static const String _biometricUserKey = 'biometric_user';

  // ── Verifica si el dispositivo SOPORTA y tiene huellas ENROLADAS ──
  Future<bool> isBiometricAvailable() async {
    try {
      // 1. ¿El dispositivo soporta biometría?
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      if (!isDeviceSupported) return false;

      // 2. ¿Puede usar biometría?
      final canCheck = await _localAuth.canCheckBiometrics;
      if (!canCheck) return false;

      // 3. ¿Hay algún método biométrico enrolado (huella, face)?
      final enrolled = await _localAuth.getAvailableBiometrics();
      return enrolled.isNotEmpty;
    } on PlatformException catch (e) {
      // ignore: avoid_print
      print('[BiometricService] isBiometricAvailable error: ${e.code}');
      return false;
    } catch (_) {
      return false;
    }
  }

  // ── Obtiene los tipos biométricos disponibles (fingerprint, face, etc.) ──
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } on PlatformException catch (_) {
      return [];
    } catch (_) {
      return [];
    }
  }

  // ── Autentica al usuario biométricamente ──
  Future<bool> authenticate({
    required String reason,
  }) async {
    try {
      // stickyAuth: true → el diálogo NO se descarta si el usuario cambia de app momentáneamente
      // Este acceso fue habilitado expresamente como biométrico. El fallback
      // del sistema (PIN/patrón) se mantiene fuera de este flujo.
      final result = await _localAuth.authenticate(
        localizedReason: reason,
        persistAcrossBackgrounding: true,
        biometricOnly: true,
        sensitiveTransaction: false,
      );
      return result;
    } on PlatformException catch (e) {
      // Errores comunes: NotAvailable, NotEnrolled, LockedOut, PermanentlyLockedOut
      // Retornamos false silenciosamente; el llamante mostrará el mensaje apropiado
      // ignore: avoid_print
      print('[BiometricService] PlatformException: ${e.code} - ${e.message}');
      return false;
    } catch (e) {
      // ignore: avoid_print
      print('[BiometricService] Error inesperado: $e');
      return false;
    }
  }

  // ── Habilita la preferencia biométrica para un usuario ──
  Future<void> enableBiometric(String usuario) async {
    await _secureStorage.write(key: _biometricEnabledKey, value: 'true');
    await _secureStorage.write(key: _biometricUserKey, value: usuario);
  }

  // ── Deshabilita la preferencia biométrica ──
  Future<void> disableBiometric() async {
    await _secureStorage.delete(key: _biometricEnabledKey);
    await _secureStorage.delete(key: _biometricUserKey);
  }

  // ── Verifica si la biometría está habilitada para algún usuario ──
  Future<bool> isBiometricEnabled() async {
    final enabled = await _secureStorage.read(key: _biometricEnabledKey);
    return enabled == 'true';
  }

  // ── Obtiene el usuario asociado a la preferencia biométrica ──
  Future<String?> getBiometricUser() async {
    return await _secureStorage.read(key: _biometricUserKey);
  }

  // ── Verifica si la biometría está habilitada PARA UN USUARIO ESPECÍFICO ──
  Future<bool> isBiometricEnabledForUser(String usuario) async {
    final enabled = await isBiometricEnabled();
    if (!enabled) return false;
    final storedUser = await getBiometricUser();
    return storedUser == usuario;
  }

  // ── Obtiene el estado completo (disponible + habilitado para usuario) ──
  Future<({bool available, bool enabled})> checkFullStatus(
      String? usuario) async {
    final available = await isBiometricAvailable();
    bool enabled = false;
    if (available && usuario != null) {
      enabled = await isBiometricEnabledForUser(usuario);
    }
    return (available: available, enabled: enabled);
  }
}
