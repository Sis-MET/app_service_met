// ignore_for_file: library_private_types_in_public_api, avoid_function_literals_in_foreach_calls

import 'package:flutter/material.dart';
import '../models/mnt_prv_regular_stac_model.dart';

class ExcentricidadWidget extends StatefulWidget {
  final Excentricidad excentricidad;
  final Future<double> Function() getD1FromDatabase;
  final Function onChanged;

  const ExcentricidadWidget({
    super.key,
    required this.excentricidad,
    required this.getD1FromDatabase,
    required this.onChanged,
  });

  @override
  _ExcentricidadWidgetState createState() => _ExcentricidadWidgetState();
}

class _ExcentricidadWidgetState extends State<ExcentricidadWidget> {
  final List<TextEditingController> _positionControllers = [];
  final List<TextEditingController> _indicationControllers = [];
  final List<TextEditingController> _returnControllers = [];

  @override
  void initState() {
    super.initState();
    // Default to 'Báscula de camión' if not set
    if (widget.excentricidad.tipoPlataforma == null ||
        widget.excentricidad.tipoPlataforma!.isEmpty) {
      widget.excentricidad.tipoPlataforma = 'Báscula de camión';
    }
    _initializeControllers();
  }

  void _initializeControllers() {
    _positionControllers.clear();
    _indicationControllers.clear();
    _returnControllers.clear();

    for (var posicion in widget.excentricidad.posiciones) {
      _positionControllers.add(TextEditingController(text: posicion.posicion));
      _indicationControllers
          .add(TextEditingController(text: posicion.indicacion));
      _returnControllers.add(TextEditingController(text: posicion.retorno));
    }
  }

  void _updatePositions() {
    if (widget.excentricidad.puntosIndicador == null) return;

    int numberOfPositions =
        int.tryParse(widget.excentricidad.puntosIndicador!) ?? 0;

    // SAFETY LIMIT: Regular DB only has columns for 6 positions
    if (numberOfPositions > 6) numberOfPositions = 6;

    widget.excentricidad.posiciones.clear();

    // Re-initialize controllers
    _positionControllers.forEach((c) => c.dispose());
    _indicationControllers.forEach((c) => c.dispose());
    _returnControllers.forEach((c) => c.dispose());

    _positionControllers.clear();
    _indicationControllers.clear();
    _returnControllers.clear();

    for (int i = 0; i < numberOfPositions; i++) {
      // Logic for Ida/Vuelta naming based on index
      // If total is 6: 0,1,2 are Ida 1,2,3; 3,4,5 are Vuelta 1,2,3
      bool isIda = i < (numberOfPositions / 2);
      int number = (i % (numberOfPositions ~/ 2)) + 1;

      String label = isIda ? 'Ida $number' : 'Vuelta $number';

      widget.excentricidad.posiciones.add(PosicionExcentricidad(
        posicion: label,
        indicacion: widget.excentricidad.carga,
        retorno: '0',
      ));

      _positionControllers.add(TextEditingController(text: label));
      _indicationControllers
          .add(TextEditingController(text: widget.excentricidad.carga));
      _returnControllers.add(TextEditingController(text: '0'));
    }

    widget.onChanged();
    setState(() {});
  }

  InputDecoration _buildInputDecoration(String labelText,
      {Widget? suffixIcon}) {
    return InputDecoration(
      labelText: labelText,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20.0)),
      suffixIcon: suffixIcon,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 20),
        const Text(
          'INFORMACIÓN DE PLATAFORMA',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),

        // Removed "Tipo de Plataforma" selection, hardcoded/hidden.
        // Or we can show it as read-only text if desired.
        // For now, implicit.

        DropdownButtonFormField<String>(
          value: widget.excentricidad.puntosIndicador,
          decoration: _buildInputDecoration('Cantidad de Puntos'),
          // Only allow 2, 4, 6 for Regular module
          items: ['2', '4', '6'].map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            );
          }).toList(),
          onChanged: (String? newValue) {
            setState(() {
              widget.excentricidad.puntosIndicador = newValue;
              _updatePositions();
            });
          },
        ),
        const SizedBox(height: 20),

        TextFormField(
          initialValue: widget.excentricidad.carga,
          onChanged: (value) {
            widget.excentricidad.carga = value;
            // Update all indication fields with new load value if they haven't been modified?
            // The original logic updated ALL of them. We'll keep that behavior.
            for (int i = 0; i < _indicationControllers.length; i++) {
              _indicationControllers[i].text = value;
              widget.excentricidad.posiciones[i].indicacion = value;
            }
            widget.onChanged();
          },
          decoration: _buildInputDecoration('Carga Aplicada'),
          keyboardType: TextInputType.number,
        ),

        // Visual Diagram
        _buildVisualDiagram(),

        const SizedBox(height: 20),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: widget.excentricidad.posiciones.length,
          itemBuilder: (context, index) {
            return _buildPositionRow(index);
          },
        ),
      ],
    );
  }

  Widget _buildPositionRow(int index) {
    // Generate label dynamically if stored position is just a number (backwards compatibility)
    // But since we are setting text in UpdatePositions, it should be fine.
    // However, if loading from DB where position was "1", display might be weird.
    // For now trust the controller text.
    String label = _positionControllers[index].text;
    if (label.isEmpty) {
      // Fallback logic if needed
      label = 'Posición ${index + 1}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                // Color separation for Ida/Vuelta based on string content
                color: label.toLowerCase().contains('ida')
                    ? Colors.blue
                    : (label.toLowerCase().contains('vuelta')
                        ? Colors.green
                        : null),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _indicationControllers[index],
                  decoration: _buildInputDecoration(
                    'Indicación',
                    suffixIcon: FutureBuilder<double>(
                      future: widget.getD1FromDatabase(),
                      builder: (context, snapshot) {
                        final d1 = snapshot.data ?? 0.1;

                        return PopupMenuButton<String>(
                          icon: const Icon(Icons.arrow_drop_down),
                          onSelected: (String newValue) {
                            setState(() {
                              _indicationControllers[index].text = newValue;
                              widget.excentricidad.posiciones[index]
                                  .indicacion = newValue;
                              widget.onChanged();
                            });
                          },
                          itemBuilder: (BuildContext context) {
                            final baseValue = double.tryParse(widget
                                    .excentricidad
                                    .posiciones[index]
                                    .indicacion) ??
                                double.tryParse(widget.excentricidad.carga) ??
                                0.0;

                            // Decimal logic
                            int decimals = 0;
                            if (d1 % 1 != 0) {
                              String d1Str = d1.toString();
                              if (d1Str.contains('.')) {
                                decimals = d1Str.split('.')[1].length;
                              } else {
                                decimals = 1;
                              }
                            }

                            return List.generate(11, (i) {
                              final multiplier = i - 5;
                              final value = baseValue + (multiplier * d1);
                              final txt = value.toStringAsFixed(decimals);
                              return PopupMenuItem<String>(
                                value: txt,
                                child: Text(txt),
                              );
                            });
                          },
                        );
                      },
                    ),
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (value) {
                    widget.excentricidad.posiciones[index].indicacion = value;
                    widget.onChanged();
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _returnControllers[index],
                  decoration: _buildInputDecoration('Retorno'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (value) {
                    widget.excentricidad.posiciones[index].retorno = value;
                    widget.onChanged();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVisualDiagram() {
    if (widget.excentricidad.tipoPlataforma != 'Báscula de camión' ||
        widget.excentricidad.puntosIndicador == null) {
      if (widget.excentricidad.puntosIndicador == null &&
          widget.excentricidad.tipoPlataforma == 'Báscula de camión') {
        // Allow if just puntos is missing (will wait for selection)
      } else {
        return const SizedBox.shrink();
      }
    }

    final int numPuntos =
        int.tryParse(widget.excentricidad.puntosIndicador ?? '0') ?? 0;

    if (numPuntos == 0) return const SizedBox.shrink();

    return Column(
      children: [
        const SizedBox(height: 20),
        const Text(
          'DIAGRAMA DE POSICIONES',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 10),
        Container(
          width: 300,
          height: 180,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8),
            color: Colors.grey[200],
          ),
          child: Stack(
            children: [
              Center(
                child: Container(
                  width: 260,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.black54),
                  ),
                  child: Center(
                    child: Text(
                      'PLATAFORMA',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
                ),
              ),
              ..._generateVisualPoints(numPuntos),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLegendItem(Colors.blue, 'Ida'),
            const SizedBox(width: 20),
            _buildLegendItem(Colors.green, 'Vuelta'),
          ],
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        CircleAvatar(backgroundColor: color, radius: 6),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  List<Widget> _generateVisualPoints(int totalPoints) {
    List<Widget> widgets = [];
    int pairs = totalPoints ~/ 2;

    // We assume 3 pairs max for Regular (6 points)
    // 260 width.
    double stepX = 260 / (pairs + 1);

    for (int i = 0; i < pairs; i++) {
      double x =
          stepX * (i + 1) + 20 - 12; // +20 margin, -12 (half width of marker)

      // Ida (Top)
      widgets.add(Positioned(
        top: 40 -
            12, // Center of marker on top edge/inside. 40 is top offset of platform.
        // Let's put it slightly above or inside.
        // Platform top is at (180-100)/2 = 40.
        // So top: 40 puts it at the edge.
        left: x,
        child: _buildPointMarker(i + 1, Colors.blue),
      ));

      // Vuelta (Bottom)
      widgets.add(Positioned(
        bottom: 40 -
            12, // Platform bottom is at 140. Bottom property is from bottom of container.
        // Container height 180. Platform height 100.
        // Space below platform = 40.
        left: x,
        child: _buildPointMarker(i + 1, Colors.green),
      ));
    }
    return widgets;
  }

  Widget _buildPointMarker(int number, Color color) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: const [BoxShadow(blurRadius: 2, color: Colors.black26)],
      ),
      child: Center(
        child: Text(
          number.toString(),
          style: const TextStyle(
              color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  @override
  void dispose() {
    for (var controller in _positionControllers) {
      controller.dispose();
    }
    for (var controller in _indicationControllers) {
      controller.dispose();
    }
    for (var controller in _returnControllers) {
      controller.dispose();
    }
    super.dispose();
  }
}
