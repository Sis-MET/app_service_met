import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../home/widgets/upload_auth_dialog.dart';

/// Usuario de ServiceMET con sesión activa (el mismo que usa la subida).
Future<String?> loggedServiceMetUser() async =>
    (await SharedPreferences.getInstance()).getString('logged_user');

/// Versión instalada, para dejarla como referencia en la oportunidad.
Future<String?> serviceMetAppVersion() async {
  final info = await PackageInfo.fromPlatform();
  return '${info.version}+${info.buildNumber}';
}

/// Pide la contraseña para renovar la sesión con la API. [error] explica por
/// qué falló el intento anterior. Devuelve null si el técnico cancela.
Future<String?> askOpportunityPassword(
  BuildContext context,
  String? error,
) async {
  final usuario = await loggedServiceMetUser();
  if (!context.mounted || usuario == null || usuario.isEmpty) return null;
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => UploadAuthDialog(
      usuario: usuario,
      title: 'Conectar con Bitrix24',
      message: error ??
          'La sesión con el servidor venció. Ingrese su contraseña para '
              'continuar con la oportunidad.',
    ),
  );
}
