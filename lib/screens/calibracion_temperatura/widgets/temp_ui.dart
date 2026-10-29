// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_icons.dart';
import '../../../widgets/service_ui/calibracion_ui.dart';
import '../../../widgets/service_ui/nav_pill.dart';

/// Un paso del submódulo con la forma de los pasos de Calibración:
/// encabezado Poppins y contenido desplazable por debajo de la píldora.
class TempStepPage extends StatelessWidget {
  const TempStepPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: ServiceNavPill.pagePadding(context, top: 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CalStepHeader(title: title, subtitle: subtitle),
              const SizedBox(height: 24),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

/// Un panel de formulario con su título de grupo, como "Identificación" en
/// Instrumento.
class TempSection extends StatelessWidget {
  const TempSection({
    super.key,
    required this.title,
    this.icon,
    this.trailing,
    required this.child,
  });

  final String title;
  final IconData? icon;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: CalPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CalGroupTitle(title, icon ?? AppIcons.info, trailing: trailing),
            child,
          ],
        ),
      ),
    );
  }
}

/// Una fila etiqueta · valor, como en "Resumen de la Información".
class TempDato extends StatelessWidget {
  const TempDato(this.etiqueta, this.valor,
      {super.key, this.destacado = false});

  final String etiqueta;
  final String? valor;
  final bool destacado;

  @override
  Widget build(BuildContext context) {
    final isDark = CalUi.dark(context);
    final texto = (valor ?? '').trim();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              etiqueta,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
          ),
          Expanded(
            child: Text(
              texto.isEmpty ? '—' : texto,
              style: GoogleFonts.inter(
                fontSize: destacado ? 15 : 13,
                fontWeight: destacado ? FontWeight.w700 : FontWeight.w600,
                color: CalUi.texto(isDark),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Un aviso dentro de un paso, como el del código temporal de SECA.
class TempAviso extends StatelessWidget {
  const TempAviso({
    super.key,
    required this.texto,
    this.icon = AppIcons.info,
    this.color = AppColors.shimmerGold,
  });

  const TempAviso.bloqueado(this.texto, {super.key})
      : icon = AppIcons.bloqueado,
        color = AppColors.shimmerGold;

  const TempAviso.error(this.texto, {super.key})
      : icon = AppIcons.advertencia,
        color = AppColors.actionNegative;

  final String texto;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = CalUi.dark(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              texto,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                height: 1.4,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Campo de número con el estilo de Instrumento.
class TempNumeroField extends StatelessWidget {
  const TempNumeroField({
    super.key,
    required this.label,
    required this.valor,
    required this.onChanged,
    this.sufijo,
    this.enabled = true,
    this.decimales = true,
    this.negativos = true,
    this.icon,
  });

  final String label;
  final double? valor;
  final ValueChanged<double?> onChanged;
  final String? sufijo;
  final bool enabled;
  final bool decimales;
  final bool negativos;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => CalNumberField(
        label: label,
        value: valor,
        onChanged: onChanged,
        suffix: sufijo,
        icon: icon,
        decimals: decimales,
        signed: negativos,
        readOnly: !enabled,
      );
}

/// Campo de texto con el estilo de Instrumento.
class TempTextoField extends StatelessWidget {
  const TempTextoField({
    super.key,
    required this.label,
    required this.valor,
    required this.onChanged,
    this.enabled = true,
    this.maxLines = 1,
    this.icon,
    this.maxLength,
    this.hint,
  });

  final String label;
  final String? valor;
  final ValueChanged<String> onChanged;
  final bool enabled;
  final int maxLines;
  final IconData? icon;
  final int? maxLength;
  final String? hint;

  @override
  Widget build(BuildContext context) => CalTextField(
        label: label,
        value: valor,
        onChanged: onChanged,
        icon: icon,
        readOnly: !enabled,
        maxLines: maxLines,
        maxLength: maxLength,
        hint: hint,
      );
}

/// Opciones exclusivas con el selector de modo de Cliente
/// (Existente / Nuevo): la elegida en amarillo.
class TempOpciones<T> extends StatelessWidget {
  const TempOpciones({
    super.key,
    required this.opciones,
    required this.seleccion,
    required this.etiqueta,
    required this.onChanged,
    this.enabled = true,
    this.iconos,
  });

  final List<T> opciones;
  final T? seleccion;
  final String Function(T) etiqueta;
  final ValueChanged<T> onChanged;
  final bool enabled;
  final IconData Function(T)? iconos;

  @override
  Widget build(BuildContext context) {
    final isDark = CalUi.dark(context);
    Widget tab(T opcion) {
      final activa = opcion == seleccion;
      final color =
          activa ? CalUi.ink : (isDark ? Colors.white54 : Colors.black45);
      return GestureDetector(
        onTap: enabled ? () => onChanged(opcion) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 10),
          decoration: BoxDecoration(
            color: activa ? CalUi.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: activa
                ? [
                    BoxShadow(
                      color: CalUi.accent.withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (iconos != null) ...[
                Icon(iconos!(opcion), size: 16, color: color),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  etiqueta(opcion),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: activa ? FontWeight.w700 : FontWeight.w500,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final fondo = BoxDecoration(
      color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF0F2F5),
      borderRadius: BorderRadius.circular(16),
    );
    // Pocas opciones: una fila como Existente / Nuevo; muchas, en líneas.
    if (opciones.length <= 3) {
      return Container(
        decoration: fondo,
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [for (final o in opciones) Expanded(child: tab(o))],
        ),
      );
    }
    return Container(
      decoration: fondo,
      padding: const EdgeInsets.all(4),
      width: double.infinity,
      child: Wrap(
        spacing: 2,
        runSpacing: 2,
        children: [for (final o in opciones) tab(o)],
      ),
    );
  }
}

/// Insignia de estado, como "Confirmado y Registrado" en SECA.
class TempEstado extends StatelessWidget {
  const TempEstado(this.texto, {super.key, required this.color, this.icon});

  final String texto;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final isDark = CalUi.dark(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.18 : 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon ?? AppIcons.circulo, size: 14, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              texto,
              style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : CalUi.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pide un motivo (corrección, detener la medición…). Null si se cancela.
Future<String?> pedirMotivo(
  BuildContext context, {
  required String titulo,
  required String mensaje,
  String accion = 'Confirmar',
  bool destructivo = false,
}) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) {
        final isDark = CalUi.dark(context);
        final valido = controller.text.trim().length >= 5;
        return AlertDialog(
          title: Text(titulo,
              style: GoogleFonts.poppins(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: CalUi.texto(isDark))),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(mensaje,
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      color: isDark ? Colors.white70 : Colors.black87)),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                maxLines: 3,
                maxLength: 500,
                textCapitalization: TextCapitalization.sentences,
                style: CalUi.valorCampo(isDark),
                decoration: CalUi.campo('Motivo', isDark),
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: destructivo
                  ? FilledButton.styleFrom(
                      backgroundColor: AppColors.actionNegative,
                      foregroundColor: AppColors.actionNegativeInk)
                  : null,
              onPressed: valido
                  ? () => Navigator.pop(dialogContext, controller.text.trim())
                  : null,
              child: Text(accion),
            ),
          ],
        );
      },
    ),
  );
}
