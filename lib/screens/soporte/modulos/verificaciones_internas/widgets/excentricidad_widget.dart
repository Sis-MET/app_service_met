// ignore_for_file: library_private_types_in_public_api

import 'package:flutter/material.dart';
import '../models/verificaciones_internas_model.dart';

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

  // Opciones de cantidad de puntos solicitadas
  final List<int> _puntosOptions = [2, 4, 6, 8, 10, 12];

  @override
  void initState() {
    super.initState();
    _initializeControllers();

    // Asegurar que el tipo de plataforma sea correcto por defecto
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

    // Calcular puntos por lado (Ida y Vuelta)
    int puntosPorLado = totalPuntos ~/ 2;

    // Generar puntos de IDA
    for (int i = 1; i <= puntosPorLado; i++) {
      _addPosition('Ida $i');
    }

    // Generar puntos de VUELTA (Inverso: 3, 2, 1...)
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
    // Obtener valor actual de puntos para el dropdown
    int? currentPuntos;
    if (widget.excentricidad.puntosIndicador != null &&
        widget.excentricidad.puntosIndicador!.isNotEmpty) {
      currentPuntos = int.tryParse(widget.excentricidad.puntosIndicador!);
    }

    return Column(
      children: [
        const SizedBox(height: 20),
        const Text(
          'PRUEBA DE EXCENTRICIDAD',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        const Text(
          'Báscula de camión',
          style: TextStyle(fontSize: 14, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),

        // Selección de Cantidad de Puntos
        DropdownButtonFormField<int>(
          value: _puntosOptions.contains(currentPuntos) ? currentPuntos : null,
          decoration: _buildInputDecoration('Cantidad de Puntos'),
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
            // Actualizar indicaciones
            for (int i = 0; i < _indicationControllers.length; i++) {
              _indicationControllers[i].text = value;
              widget.excentricidad.posiciones[i].indicacion = value;
            }
            widget.onChanged();
          },
          initialValue: widget.excentricidad.carga,
          decoration: _buildInputDecoration('Carga aplicada'),
          keyboardType: TextInputType.number,
        ),

        const SizedBox(height: 20),

        // Diagrama Visual de la Báscula
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
    // Determinar etiqueta segura
    String label = widget.excentricidad.posiciones[index].posicion;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          // Posición como texto (read-only)
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
                  decoration: _buildInputDecoration(
                    'Indicación',
                    suffixIcon: FutureBuilder<double>(
                      future: widget.getD1FromDatabase(),
                      builder: (context, snapshot) {
                        // Mostrar loader mientras carga
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

                        // Manejar errores
                        if (snapshot.hasError) {
                          return const Tooltip(
                            message: 'Error al cargar d1',
                            child: Icon(Icons.error_outline, color: Colors.red),
                          );
                        }
                        // Obtener d1 o usar valor por defecto
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

                            // Si está vacío, usa la carga como base
                            final baseValue = double.tryParse(
                                  (currentText.isEmpty
                                          ? widget.excentricidad.carga
                                          : currentText)
                                      .replaceAll(',', '.'),
                                ) ??
                                0.0;

                            // Generar 11 opciones (5 abajo, actual, 5 arriba)
                            return List.generate(11, (i) {
                              final value = baseValue + ((i - 5) * d1);

                              // Calcular decimales basados en d1
                              int decimals = 0;
                              if (d1 % 1 != 0) {
                                String d1Str = d1.toString();
                                if (d1Str.contains('.')) {
                                  decimals = d1Str.split('.')[1].length;
                                } else {
                                  decimals = 1; // Fallback
                                }
                              }

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

  Widget _buildVisualDiagram(int totalPuntos) {
    int puntosIda = totalPuntos ~/ 2;
    // int puntosVuelta = totalPuntos ~/ 2;

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

          // Fila de IDA
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

          // Divisor central (centro de plataforma)
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            height: 2,
            color: Colors.grey[400],
          ),

          // Fila de VUELTA
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              const Text('⬅ VUELTA',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                      fontSize: 12)),
              ...List.generate(puntosIda, (index) {
                // Invertimos el orden visual para que "Vuelta 1" esté alineado lógicamente si se desea,
                // o mantenemos 1..N. Generalmente Ida va en un sentido y Vuelta regresa.
                // Para simplificar visualización, mostraremos 1..N también.
                // CORRECCION: Mostrar en orden inverso (3, 2, 1...)
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
