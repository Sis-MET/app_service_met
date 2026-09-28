import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

/// Cláusulas de la NB/ISO/IEC 17025 que se evalúan sobre la app.
enum Clausula {
  registrosTecnicos(
    '7.5',
    'Registros técnicos',
    'Qué se registra, cuándo y por quién, y cómo se rastrean los cambios.',
    Icons.fact_check_outlined,
  ),
  gestionInformacion(
    '7.11',
    'Datos y gestión de la información',
    'Validación, acceso, integridad, fallas, manuales y transferencias.',
    Icons.dns_outlined,
  ),
  controlRegistros(
    '8.4',
    'Control de registros',
    'Respaldo, retención, disposición y confidencialidad de los registros.',
    Icons.inventory_2_outlined,
  );

  const Clausula(this.numero, this.nombre, this.resumen, this.icono);

  final String numero;
  final String nombre;
  final String resumen;
  final IconData icono;
}

enum EstadoCumplimiento {
  cumple('Cumple', Icons.check_circle_rounded, AppColors.actionPositive),
  parcial('Parcial', Icons.timelapse_rounded, Color(0xFFE0A100)),
  noCumple('No cumple', Icons.cancel_rounded, AppColors.actionNegative),
  porVerificar('Por verificar', Icons.help_rounded, Color(0xFF7E8A97));

  const EstadoCumplimiento(this.etiqueta, this.icono, this.color);

  final String etiqueta;
  final IconData icono;
  final Color color;
}

/// Cómo se cierra una brecha: con código, con un procedimiento del
/// laboratorio o con ambos.
enum TipoCierre {
  software('Software'),
  procedimiento('Procedimiento'),
  ambos('Software y procedimiento');

  const TipoCierre(this.etiqueta);
  final String etiqueta;
}

enum Riesgo {
  alto('Alto'),
  medio('Medio'),
  bajo('Bajo');

  const Riesgo(this.etiqueta);
  final String etiqueta;
}

/// Un requisito verificable de la norma, tal como aplica a ServiceMET.
///
/// Los IDs (RT-, DI-, CR-) coinciden con la lista de verificación de la skill
/// `.claude/skills/iso17025-cumplimiento/references/checklist.md`.
class Requisito {
  const Requisito({
    required this.id,
    required this.clausula,
    required this.literal,
    required this.titulo,
    required this.exige,
    required this.estado,
    required this.evidencias,
    this.brecha,
    this.accion,
    this.cierre,
    this.riesgo,
  });

  final String id;
  final Clausula clausula;

  /// Subcláusula exacta, por ejemplo "7.5.2" o "7.11.3 e".
  final String literal;
  final String titulo;

  /// Qué pide la norma, parafraseado.
  final String exige;
  final EstadoCumplimiento estado;

  /// Cómo lo cumple hoy la app (o qué existe a favor).
  final List<String> evidencias;
  final String? brecha;
  final String? accion;
  final TipoCierre? cierre;
  final Riesgo? riesgo;

  bool coincide(String consulta) {
    final q = consulta.trim().toLowerCase();
    if (q.isEmpty) return true;
    return [
      id,
      literal,
      titulo,
      exige,
      brecha ?? '',
      accion ?? '',
      ...evidencias
    ].any((texto) => texto.toLowerCase().contains(q));
  }
}

/// Cuántos requisitos hay en cada estado.
class ResumenCumplimiento {
  ResumenCumplimiento(Iterable<Requisito> requisitos)
      : conteo = {
          for (final estado in EstadoCumplimiento.values)
            estado: requisitos.where((r) => r.estado == estado).length,
        },
        total = requisitos.length;

  final Map<EstadoCumplimiento, int> conteo;
  final int total;

  int operator [](EstadoCumplimiento estado) => conteo[estado] ?? 0;

  /// Avance ponderado: un parcial cuenta como medio cumplimiento.
  double get avance => total == 0
      ? 0
      : (this[EstadoCumplimiento.cumple] +
              this[EstadoCumplimiento.parcial] * 0.5) /
          total;
}

/// Evaluación interna completa: cuándo se hizo, sobre qué versión y con qué
/// resultado por requisito.
class EvaluacionCumplimiento {
  const EvaluacionCumplimiento({
    required this.version,
    required this.fecha,
    required this.requisitos,
  });

  final String version;
  final DateTime fecha;
  final List<Requisito> requisitos;

  ResumenCumplimiento get resumen => ResumenCumplimiento(requisitos);

  List<Requisito> deClausula(Clausula clausula) =>
      requisitos.where((r) => r.clausula == clausula).toList();

  ResumenCumplimiento resumenDe(Clausula clausula) =>
      ResumenCumplimiento(deClausula(clausula));
}
