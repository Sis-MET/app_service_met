import 'package:flutter/material.dart';
import '../../../theme/app_icons.dart';

class SoporteConstants {
  static const Color primaryColor = Color(0xFF46824B);
  static const Color accentColor = Color(0xFF2E7D32);
  static const Color backgroundColor = Color(0xFFF5F5F5);
  static const String dbName = 'service_met.db';

  static const List<String> soluciones = [
    'No aplica',
    'Se ajusta',
    'Se repara',
    'Se cambia',
    'Limpieza',
    'Lubricación',
  ];

  static const Map<String, IconData> solucionIconMap = {
    'No aplica': AppIcons.bloquear,
    'Se ajusta': AppIcons.soporte,
    'Se repara': AppIcons.herramientas,
    'Se cambia': AppIcons.actualizar,
    'Limpieza': AppIcons.limpieza,
    'Lubricación': AppIcons.humedad,
  };

  static const Map<String, Color> solucionColorMap = {
    'No aplica': Colors.grey,
    'Se ajusta': Colors.orange,
    'Se repara': Colors.red,
    'Se cambia': Colors.blue,
    'Limpieza': Colors.lightBlue,
    'Lubricación': Colors.teal,
  };
}
