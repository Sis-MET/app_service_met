import 'package:flutter/material.dart';
import '../../../theme/app_icons.dart';

/// Datos de control del manual como documento controlado (NB/ISO/IEC 17025
/// 8.3). Lo que asigna Calidad queda como pendiente hasta que se apruebe.
class ControlDocumento {
  const ControlDocumento({
    required this.codigo,
    required this.titulo,
    required this.revision,
    required this.fechaEmision,
    required this.aplicaA,
    required this.elaboro,
    required this.reviso,
    required this.aprobo,
    required this.historial,
  });

  final String codigo;
  final String titulo;
  final String revision;
  final String fechaEmision;

  /// Versión de la app que describe, p. ej. "6.3.x".
  final String aplicaA;
  final String elaboro;
  final String reviso;
  final String aprobo;
  final List<RevisionDocumento> historial;

  bool get aprobado => !aprobo.startsWith('PENDIENTE');
}

class RevisionDocumento {
  const RevisionDocumento(this.revision, this.fecha, this.descripcion);

  final String revision;
  final String fecha;
  final String descripcion;
}

/// Bloques de contenido de una sección del manual.
sealed class BloqueManual {
  const BloqueManual();

  /// Texto plano del bloque, para búsqueda y exportación.
  String get texto;
}

class Parrafo extends BloqueManual {
  const Parrafo(this.contenido);
  final String contenido;

  @override
  String get texto => contenido;
}

/// Pasos numerados que el técnico sigue en orden.
class Pasos extends BloqueManual {
  const Pasos(this.titulo, this.pasos);
  final String? titulo;
  final List<Paso> pasos;

  @override
  String get texto => [
        titulo ?? '',
        ...pasos.map((p) => '${p.accion} ${p.detalle ?? ''}')
      ].join(' ');
}

class Paso {
  const Paso(this.accion, [this.detalle]);

  /// Qué hacer, empezando por el verbo.
  final String accion;
  final String? detalle;
}

class Lista extends BloqueManual {
  const Lista(this.titulo, this.items);
  final String? titulo;
  final List<String> items;

  @override
  String get texto => [titulo ?? '', ...items].join(' ');
}

enum TipoNota {
  consejo('Consejo', AppIcons.consejo, Color(0xFF3D7BD9)),
  importante('Importante', AppIcons.advertencia, Color(0xFFE0A100)),
  norma('NB/ISO/IEC 17025', AppIcons.verificado, Color(0xFF8BC251));

  const TipoNota(this.etiqueta, this.icono, this.color);
  final String etiqueta;
  final IconData icono;
  final Color color;
}

class Nota extends BloqueManual {
  const Nota(this.tipo, this.contenido, {this.referencia});
  final TipoNota tipo;
  final String contenido;

  /// Cláusula relacionada, para las notas de tipo norma.
  final String? referencia;

  @override
  String get texto => contenido;
}

class SeccionManual {
  const SeccionManual({
    required this.id,
    required this.titulo,
    required this.icono,
    required this.resumen,
    required this.bloques,
    this.grupo = GrupoManual.primerosPasos,
  });

  final String id;
  final String titulo;
  final IconData icono;
  final String resumen;
  final List<BloqueManual> bloques;
  final GrupoManual grupo;

  bool coincide(String consulta) {
    final q = consulta.trim().toLowerCase();
    if (q.isEmpty) return true;
    return titulo.toLowerCase().contains(q) ||
        resumen.toLowerCase().contains(q) ||
        bloques.any((b) => b.texto.toLowerCase().contains(q));
  }
}

enum GrupoManual {
  primerosPasos('Primeros pasos'),
  servicios('Servicios'),
  datos('Datos y registros'),
  ayuda('Ayuda');

  const GrupoManual(this.etiqueta);
  final String etiqueta;
}

class ManualUso {
  const ManualUso({required this.control, required this.secciones});

  final ControlDocumento control;
  final List<SeccionManual> secciones;
}
