import 'package:flutter/material.dart';

const Map<String, IconData> estadoIconMap = {
  '1 Bueno': Icons.check_circle,
  '2 Regular': Icons.warning,
  '3 Malo': Icons.error,
  '4 No aplica': Icons.block,
  '1 Aceptable': Icons.warning,
  'Bueno': Icons.check_circle,
  'Aceptable': Icons.warning,
  'Malo': Icons.error,
  'No aplica': Icons.block,
};

const Map<String, Color> estadoColorMap = {
  '1 Bueno': Colors.green,
  '2 Regular': Colors.orange,
  '3 Malo': Colors.red,
  '4 No aplica': Colors.grey,
  '1 Aceptable': Colors.orange,
  'Bueno': Colors.green,
  'Aceptable': Colors.orange,
  'Malo': Colors.red,
  'No aplica': Colors.grey,
};
