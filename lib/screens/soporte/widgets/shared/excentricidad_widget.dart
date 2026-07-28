import 'package:flutter/material.dart';
import 'package:service_met/screens/soporte/models/shared_metrology_models.dart';
import 'package:service_met/screens/soporte/widgets/shared/soporte_input_decorations.dart';
import 'package:service_met/screens/soporte/utils/soporte_constants.dart';

class ExcentricidadWidget extends StatefulWidget {
  final Excentricidad excentricidad;
  final Future<double> Function() getD1FromDatabase;
  final VoidCallback onChanged;

  const ExcentricidadWidget({
    super.key,
    required this.excentricidad,
    required this.getD1FromDatabase,
    required this.onChanged,
  });

  @override
  State<ExcentricidadWidget> createState() => _ExcentricidadWidgetState();
}

class _ExcentricidadWidgetState extends State<ExcentricidadWidget> {
  final List<TextEditingController> _positionControllers = [];
  final List<TextEditingController> _indicationControllers = [];
  final List<TextEditingController> _returnControllers = [];

  final List<int> _puntosOptions = [2, 4, 6, 8, 10, 12];

  @override
  void initState() {
    super.initState();
    _initializeControllers();

    if (widget.excentricidad.tipoPlataforma != 'Báscula de camión') {
      widget.excentricidad.tipoPlataforma = 'Báscula de camión';
    }
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

  void _updatePositions(int totalPuntos) {
    widget.excentricidad.puntosIndicador = totalPuntos.toString();
    widget.excentricidad.posiciones.clear();
    _initializeControllers();

    int puntosPorLado = totalPuntos ~/ 2;

    for (int i = 1; i <= puntosPorLado; i++) {
      _addPosition('Ida $i');
    }

    for (int i = puntosPorLado; i >= 1; i--) {
      _addPosition('Vuelta $i');
    }

    widget.onChanged();
    setState(() {});
  }

  void _addPosition(String nombrePosicion) {
    widget.excentricidad.posiciones.add(PosicionExcentricidad(
      posicion: nombrePosicion,
      indicacion: widget.excentricidad.carga,
      retorno: '0',
    ));

    _positionControllers.add(TextEditingController(text: nombrePosicion));
    _indicationControllers
        .add(TextEditingController(text: widget.excentricidad.carga));
    _returnControllers.add(TextEditingController(text: '0'));
  }

  @override
  Widget build(BuildContext context) {
    int? currentPuntos;
    if (widget.excentricidad.puntosIndicador != null &&
        widget.excentricidad.puntosIndicador!.isNotEmpty) {
      currentPuntos = int.tryParse(widget.excentricidad.puntosIndicador!);
    }

    final platformKeys = SoporteConstants.platformOptions.keys.toList();
    final currentPlatform = widget.excentricidad.tipoPlataforma != null &&
            SoporteConstants.platformOptions
                .containsKey(widget.excentricidad.tipoPlataforma)
        ? widget.excentricidad.tipoPlataforma
        : null;

    return Column(
      children: [
        const SizedBox(height: 20),
        const Text(
          'PRUEBA DE EXCENTRICIDAD',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: currentPlatform,
          decoration: SoporteInputDecorations.buildInputDecoration('Tipo de Plataforma'),
          hint: const Text('Seleccione tipo de plataforma'),
          items: platformKeys.map((String key) {
            return DropdownMenuItem<String>(
              value: key,
              child: Text(key),
            );
          }).toList(),
          onChanged: (String? newValue) {
            if (newValue != null) {
              setState(() {
                widget.excentricidad.tipoPlataforma = newValue;
                widget.onChanged();
              });
            }
          },
        ),
        const SizedBox(height: 20),

        DropdownButtonFormField<int>(
          value: _puntosOptions.contains(currentPuntos) ? currentPuntos : null,
          decoration: SoporteInputDecorations.buildInputDecoration('Cantidad de Puntos'),
          hint: const Text('Seleccione cantidad de puntos'),
          items: _puntosOptions.map((int value) {
            return DropdownMenuItem<int>(
              value: value,
              child: Text(
                  '$value puntos (${value ~/ 2} Ida / ${value ~/ 2} Vuelta)'),
            );
          }).toList(),
          onChanged: (int? newValue) {
            if (newValue != null) {
              setState(() {
                _updatePositions(newValue);
              });
            }
          },
        ),

        const SizedBox(height: 20),
        TextFormField(
          onChanged: (value) {
            widget.excentricidad.carga = value;
            for (int i = 0; i < _indicationControllers.length; i++) {
              _indicationControllers[i].text = value;
              widget.excentricidad.posiciones[i].indicacion = value;
            }
            widget.onChanged();
          },
          initialValue: widget.excentricidad.carga,
          decoration: SoporteInputDecorations.buildInputDecoration('Carga aplicada'),
          keyboardType: TextInputType.number,
        ),

        const SizedBox(height: 20),

        if (currentPuntos != null && currentPuntos > 0)
          _buildVisualDiagram(currentPuntos),

        const SizedBox(height: 10),

        if (widget.excentricidad.posiciones.isNotEmpty)
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
    String label = widget.excentricidad.posiciones[index].posicion;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.location_on_outlined,
                    size: 18, color: Colors.blue[700]),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.blue[900],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _indicationControllers[index],
                  decoration: SoporteInputDecorations.buildInputDecoration(
                    'Indicación',
                    suffixIcon: FutureBuilder<double>(
                      future: widget.getD1FromDatabase(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        }

                        if (snapshot.hasError) {
                          return const Tooltip(
                            message: 'Error al cargar d1',
                            child: Icon(Icons.error_outline, color: Colors.red),
                          );
                        }

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
                            final currentText =
                                _indicationControllers[index].text.trim();

                            final baseValue = double.tryParse(
                                  (currentText.isEmpty
                                          ? widget.excentricidad.carga
                                          : currentText)
                                      .replaceAll(',', '.'),
                                ) ??
                                0.0;

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
                              final value = baseValue + ((i - 5) * d1);
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
                  decoration: SoporteInputDecorations.buildInputDecoration('Retorno'),
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

  Widget _buildVisualDiagram(int totalPuntos) {
    int puntosIda = totalPuntos ~/ 2;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        border: Border.all(color: Colors.grey[600]!, width: 2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        children: [
          const Text(
            'ESQUEMA DE PLATAFORMA',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Colors.black54),
          ),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              const Text('IDA ➡',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo,
                      fontSize: 12)),
              ...List.generate(puntosIda, (index) {
                return _buildDot(index + 1, Colors.indigo);
              }),
            ],
          ),

          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            height: 2,
            color: Colors.grey[400],
          ),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              const Text('⬅ VUELTA',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                      fontSize: 12)),
              ...List.generate(puntosIda, (index) {
                return _buildDot(puntosIda - index, Colors.green);
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int number, Color color) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        '$number',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
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
