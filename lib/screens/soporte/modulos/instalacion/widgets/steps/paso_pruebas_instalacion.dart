import 'package:flutter/material.dart';
import '../../controllers/instalacion_controller.dart';
import '../../models/instalacion_model.dart';
import '../pruebas_metrologicas_instalacion_widget.dart';

class PasoPruebasInstalacion extends StatelessWidget {
  final InstalacionModel model;
  final InstalacionController controller;
  final VoidCallback onChanged;

  const PasoPruebasInstalacion({
    super.key,
    required this.model,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pruebas Metrológicas
          PruebasMetrologicasInstalacionWidget(
            pruebas: model.pruebasIniciales,
            onChanged: onChanged,
            getIndicationSuggestions: controller.getIndicationSuggestions,
            getD1FromDatabase: controller.getD1FromDatabase,
          ),
        ],
      ),
    );
  }
}
