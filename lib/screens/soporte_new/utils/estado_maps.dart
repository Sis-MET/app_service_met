import 'package:flutter/material.dart';
import '../../../theme/app_icons.dart';

const Map<String, Color> estadoColorMap = {
  'Bueno': Colors.green,
  'Regular': Colors.orange,
  'Malo': Colors.red,
  'No aplica': Colors.grey,
};

const Map<String, IconData> estadoIconMap = {
  'Bueno': AppIcons.completo,
  'Regular': AppIcons.advertencia,
  'Malo': AppIcons.error,
  'No aplica': AppIcons.bloquear,
};
