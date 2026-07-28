import 'dart:io';
import 'package:flutter/material.dart';
import 'package:service_met/screens/soporte/models/campo_estado.dart';
import 'package:service_met/screens/soporte/widgets/shared/all_good_checkbox.dart';
import 'package:service_met/screens/soporte/widgets/shared/campo_inspeccion_widget.dart';

class PasoTerminal extends StatefulWidget {
  final Map<String, CampoEstado> camposEstado;
  final VoidCallback onChanged;
  final void Function(String label, File foto) onAddPhoto;
  final void Function(String label, int index) onRemovePhoto;

  const PasoTerminal({
    super.key,
    required this.camposEstado,
    required this.onChanged,
    required this.onAddPhoto,
    required this.onRemovePhoto,
  });

  @override
  State<PasoTerminal> createState() => _PasoTerminalState();
}

class _PasoTerminalState extends State<PasoTerminal> {
  final List<String> _campos = [
    'Carcasa',
    'Teclado Fisico',
    'Display Fisico',
    'Fuente de poder',
    'Bateria operacional',
    'Bracket',
    'Teclado Operativo',
    'Display Operativo',
    'Contector de celda',
    'Bateria de memoria',
  ];

  bool _isAllGood = false;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context, isDarkMode),
          AllGoodCheckbox(value: _isAllGood, onChanged: (v) => _toggleAllGood(v, _campos)),
          const SizedBox(height: 24),
          ..._campos.map((campo) => CampoInspeccionWidget(
            label: campo,
            campo: widget.camposEstado[campo]!,
            onAddPhoto: widget.onAddPhoto,
            onRemovePhoto: widget.onRemovePhoto,
          )),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.purple.withOpacity(0.1) : Colors.purple.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple.withOpacity(0.3), width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.computer_outlined, color: Colors.purple, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('TERMINAL DE PESAJE', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Inspeccione el estado físico y operacional del terminal',
                    style: TextStyle(fontSize: 13, color: isDarkMode ? Colors.white70 : Colors.black54)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _toggleAllGood(bool isGood, List<String> campos) {
    setState(() {
      _isAllGood = isGood;
      if (isGood) {
        for (final fieldName in campos) {
          final campo = widget.camposEstado[fieldName];
          if (campo != null) {
            campo.initialValue = '1 Bueno';
            campo.comentario = 'En buen estado';
            campo.solutionValue = 'No aplica';
          }
        }
        widget.onChanged();
      }
    });
  }
}

class PasoBalanza extends StatefulWidget {
  final Map<String, CampoEstado> camposEstado;
  final VoidCallback onChanged;
  final void Function(String label, File foto) onAddPhoto;
  final void Function(String label, int index) onRemovePhoto;

  const PasoBalanza({
    super.key,
    required this.camposEstado,
    required this.onChanged,
    required this.onAddPhoto,
    required this.onRemovePhoto,
  });

  @override
  State<PasoBalanza> createState() => _PasoBalanzaState();
}

class _PasoBalanzaState extends State<PasoBalanza> {
  final List<String> _campos = [
    'Limpieza general',
    'Golpes al terminal',
    'Nivelacion',
    'Limpieza receptor',
    'Golpes al receptor de carga',
    'Encendido',
  ];

  bool _isAllGood = false;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context, isDarkMode),
          AllGoodCheckbox(value: _isAllGood, onChanged: (v) => _toggleAllGood(v, _campos)),
          const SizedBox(height: 24),
          ..._campos.map((campo) => CampoInspeccionWidget(
            label: campo,
            campo: widget.camposEstado[campo]!,
            onAddPhoto: widget.onAddPhoto,
            onRemovePhoto: widget.onRemovePhoto,
          )),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.teal.withOpacity(0.1) : Colors.teal.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.teal.withOpacity(0.3), width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.balance_outlined, color: Colors.teal, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('ESTADO GENERAL DE LA BALANZA', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Inspeccione el estado general del instrumento',
                    style: TextStyle(fontSize: 13, color: isDarkMode ? Colors.white70 : Colors.black54)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _toggleAllGood(bool isGood, List<String> campos) {
    setState(() {
      _isAllGood = isGood;
      if (isGood) {
        for (final fieldName in campos) {
          final campo = widget.camposEstado[fieldName];
          if (campo != null) {
            campo.initialValue = '1 Bueno';
            campo.comentario = 'En buen estado';
            campo.solutionValue = 'No aplica';
          }
        }
        widget.onChanged();
      }
    });
  }
}

class PasoCajaSumadora extends StatefulWidget {
  final Map<String, CampoEstado> camposEstado;
  final VoidCallback onChanged;
  final void Function(String label, File foto) onAddPhoto;
  final void Function(String label, int index) onRemovePhoto;

  const PasoCajaSumadora({
    super.key,
    required this.camposEstado,
    required this.onChanged,
    required this.onAddPhoto,
    required this.onRemovePhoto,
  });

  @override
  State<PasoCajaSumadora> createState() => _PasoCajaSumadoraState();
}

class _PasoCajaSumadoraState extends State<PasoCajaSumadora> {
  final List<String> _camposPlataforma = [
    'Limitador de movimiento',
    'Suspensión',
    'Limitador de carga',
    'Celda de carga',
  ];

  final List<String> _camposCajaSumadora = [
    'Tapa de caja sumadora',
    'Humedad Interna',
    'Estado de prensacables',
    'Estado de borneas',
  ];

  bool _isAllGood = false;

  @override
  Widget build(BuildContext context) {
    final allCampos = [..._camposPlataforma, ..._camposCajaSumadora];
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AllGoodCheckbox(value: _isAllGood, onChanged: (v) => _toggleAllGood(v, allCampos)),
          const SizedBox(height: 16),
          _buildSection(
            context, isDarkMode,
            title: 'BALANZA | PLATAFORMA',
            subtitle: 'Inspeccione los componentes de la plataforma',
            icon: Icons.square_outlined,
            color: Colors.orange,
            campos: _camposPlataforma,
          ),
          const SizedBox(height: 32),
          _buildSection(
            context, isDarkMode,
            title: 'CAJA SUMADORA',
            subtitle: 'Inspeccione el estado de la caja sumadora',
            icon: Icons.electrical_services_outlined,
            color: Colors.amber[700]!,
            campos: _camposCajaSumadora,
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, bool isDarkMode, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required List<String> campos,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDarkMode ? color.withOpacity(0.1) : color.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3), width: 1),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: TextStyle(fontSize: 13, color: isDarkMode ? Colors.white70 : Colors.black54)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ...campos.map((campo) => CampoInspeccionWidget(
          label: campo,
          campo: widget.camposEstado[campo]!,
          onAddPhoto: widget.onAddPhoto,
          onRemovePhoto: widget.onRemovePhoto,
        )),
      ],
    );
  }

  void _toggleAllGood(bool isGood, List<String> campos) {
    setState(() {
      _isAllGood = isGood;
      if (isGood) {
        for (final fieldName in campos) {
          final campo = widget.camposEstado[fieldName];
          if (campo != null) {
            campo.initialValue = '1 Bueno';
            campo.comentario = 'En buen estado';
            campo.solutionValue = 'No aplica';
          }
        }
        widget.onChanged();
      }
    });
  }
}
