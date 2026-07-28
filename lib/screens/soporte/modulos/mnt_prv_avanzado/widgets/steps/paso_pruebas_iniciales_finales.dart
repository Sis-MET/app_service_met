import 'package:flutter/material.dart';
import 'package:service_met/screens/soporte/widgets/shared/paso_pruebas_iniciales_widget.dart';
import 'package:service_met/screens/soporte/widgets/shared/paso_pruebas_finales_widget.dart';
import '../../models/mnt_prv_avanzado_model.dart';
import '../../controllers/mnt_prv_avanzado_controller.dart';

class PasoPruebasIniciales extends StatelessWidget {
  final MntPrvAvanzadoModel model;
  final MntPrvAvanzadoController controller;
  final Future<double> Function() getD1FromDatabase;
  final VoidCallback onChanged;

  const PasoPruebasIniciales({
    super.key,
    required this.model,
    required this.controller,
    required this.getD1FromDatabase,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return PasoPruebasInicialesWidget(
      pruebas: model.pruebasIniciales,
      horaInicio: model.horaInicio,
      onChanged: onChanged,
      getD1FromDatabase: getD1FromDatabase,
    );
  }
}

class PasoPruebasFinales extends StatelessWidget {
  final MntPrvAvanzadoModel model;
  final MntPrvAvanzadoController controller;
  final Future<double> Function() getD1FromDatabase;
  final VoidCallback onChanged;

  const PasoPruebasFinales({
    super.key,
    required this.model,
    required this.controller,
    required this.getD1FromDatabase,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return PasoPruebasFinalesWidget(
      pruebas: model.pruebasFinales,
      horaInicio: model.horaInicio,
      onChanged: onChanged,
      getD1FromDatabase: getD1FromDatabase,
      onCopyFromInitial: () {
        controller.copiarPruebasInicialesAFinales();
        onChanged();
      },
    );
  }
}
