// ignore_for_file: library_private_types_in_public_api, deprecated_member_use

import 'package:flutter/material.dart';

import '../models/instalacion_model.dart';

class LinealidadInstalacionWidget extends StatefulWidget {
  final Linealidad linealidad;
  final Function onChanged;
  final Future<double> Function() getD1FromDatabase;

  const LinealidadInstalacionWidget({
    super.key,
    required this.linealidad,
    required this.onChanged,
    required this.getD1FromDatabase,
  });

  @override
  _LinealidadInstalacionWidgetState createState() =>
      _LinealidadInstalacionWidgetState();
}

class _LinealidadInstalacionWidgetState
    extends State<LinealidadInstalacionWidget> {
  final List<TextEditingController> _ltControllers = [];
  final List<TextEditingController> _indicacionControllers = [];
  final List<TextEditingController> _retornoControllers = [];
  final List<TextEditingController> _differenceControllers = [];

  // Controladores para Método 2
  final TextEditingController _iLsubnController = TextEditingController();
  final TextEditingController _lsubnController = TextEditingController();
  final TextEditingController _ioController = TextEditingController();
  final TextEditingController _ltnController = TextEditingController();
  double _d1 = 0.1; // Initialize with default

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _iLsubnController.text = widget.linealidad.iLsubn;
    _lsubnController.text = widget.linealidad.lsubn;
    _ioController.text = widget.linealidad.io;
    _ltnController.text = widget.linealidad.ltn;
    _loadD1();
  }

  Future<void> _loadD1() async {
    final val = await widget.getD1FromDatabase();
    if (mounted) {
      setState(() {
        _d1 = val;
      });
    }
  }

  void _initializeControllers() {
    _ltControllers.clear();
    _indicacionControllers.clear();
    _retornoControllers.clear();
    _differenceControllers.clear();

    for (var punto in widget.linealidad.puntos) {
      _ltControllers.add(TextEditingController(text: punto.lt));
      _indicacionControllers.add(TextEditingController(text: punto.indicacion));
      _retornoControllers.add(TextEditingController(text: punto.retorno));
      _differenceControllers.add(TextEditingController());
      _calcularDiferencia(_differenceControllers.length - 1);
    }
  }

  void _actualizarUltimaCarga() {
    if (widget.linealidad.puntos.isEmpty) {
      widget.linealidad.ultimaCargaLt = '0';
      return;
    }

    for (int i = widget.linealidad.puntos.length - 1; i >= 0; i--) {
      final ltValue = widget.linealidad.puntos[i].lt;
      if (ltValue.isNotEmpty) {
        widget.linealidad.ultimaCargaLt = ltValue;
        return;
      }
    }

    widget.linealidad.ultimaCargaLt = '0';
  }

  void _calcularMetodo2() {
    final iLsubn = double.tryParse(_iLsubnController.text) ?? 0.0;

    if (widget.linealidad.puntos.isEmpty) {
      _lsubnController.text = iLsubn.toStringAsFixed(2);
      _calcularLtn();
      return;
    }

    // Buscar la carga LT más cercana a I(Lsubn)
    double closestLt = double.infinity;
    double closestDifference = 0.0;

    for (var punto in widget.linealidad.puntos) {
      final lt = double.tryParse(punto.lt) ?? 0.0;
      final indicacion = double.tryParse(punto.indicacion) ?? 0.0;
      final difference = indicacion - lt;

      if ((iLsubn - lt).abs() < (iLsubn - closestLt).abs()) {
        closestLt = lt;
        closestDifference = difference;
      }
    }

    // Calcular Lsubn
    final lsubn = iLsubn - closestDifference;
    _lsubnController.text = lsubn.toStringAsFixed(2);
    widget.linealidad.lsubn = lsubn.toStringAsFixed(2);

    _calcularLtn();
  }

  void _calcularLtn() {
    final lsubn = double.tryParse(_lsubnController.text) ?? 0.0;
    final io = double.tryParse(_ioController.text) ?? 0.0;
    final ltn = lsubn + io;

    _ltnController.text = ltn.toStringAsFixed(2);
    widget.linealidad.ltn = ltn.toStringAsFixed(2);
    widget.onChanged();
  }

  void _agregarFila() {
    if (widget.linealidad.puntos.length >= 12) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Máximo 12 cargas permitidas')));
      return;
    }

    setState(() {
      widget.linealidad.puntos.add(PuntoLinealidad());
      _ltControllers.add(TextEditingController());
      _indicacionControllers.add(TextEditingController());
      _retornoControllers.add(TextEditingController(text: '0'));
      _differenceControllers.add(TextEditingController());
    });
  }

  void _removerFila(int index) {
    if (widget.linealidad.puntos.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Debe mantener al menos 1 fila')));
      return;
    }

    setState(() {
      widget.linealidad.puntos.removeAt(index);
      _ltControllers[index].dispose();
      _indicacionControllers[index].dispose();
      _retornoControllers[index].dispose();
      _differenceControllers[index].dispose();
      _ltControllers.removeAt(index);
      _indicacionControllers.removeAt(index);
      _retornoControllers.removeAt(index);
      _differenceControllers.removeAt(index);
      _actualizarUltimaCarga();
    });
  }

  void _guardarCarga() {
    if (_ltnController.text.isEmpty) return;

    if (widget.linealidad.puntos.length >= 12) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Máximo 12 cargas permitidas')));
      return;
    }

    setState(() {
      // Buscar primera fila vacía
      for (int i = 0; i < widget.linealidad.puntos.length; i++) {
        if (widget.linealidad.puntos[i].lt.isEmpty) {
          widget.linealidad.puntos[i].lt = _ltnController.text;
          widget.linealidad.puntos[i].indicacion = _ltnController.text;
          _ltControllers[i].text = _ltnController.text;
          _indicacionControllers[i].text = _ltnController.text;
          _actualizarUltimaCarga();
          _limpiarCampos();
          return;
        }
      }

      // Si no hay filas vacías, agregar nueva
      if (widget.linealidad.puntos.length < 12) {
        _agregarFila();
        final lastIndex = widget.linealidad.puntos.length - 1;
        widget.linealidad.puntos[lastIndex].lt = _ltnController.text;
        widget.linealidad.puntos[lastIndex].indicacion = _ltnController.text;
        _ltControllers[lastIndex].text = _ltnController.text;
        _indicacionControllers[lastIndex].text = _ltnController.text;
        _actualizarUltimaCarga();
        _limpiarCampos();
      }
    });
  }

  void _limpiarCampos() {
    _iLsubnController.clear();
    _lsubnController.clear();
    _ioController.clear();
    _ltnController.clear();
    widget.linealidad.iLsubn = '';
    widget.linealidad.lsubn = '';
    widget.linealidad.io = '0';
    widget.linealidad.ltn = '';
    widget.onChanged();
  }

  void _calcularDiferencia(int index) {
    if (index < 0 || index >= _ltControllers.length) return;

    final ltText = _ltControllers[index].text.replaceAll(',', '.');
    final indicacionText =
        _indicacionControllers[index].text.replaceAll(',', '.');

    if (ltText.isNotEmpty && indicacionText.isNotEmpty) {
      final lt = double.tryParse(ltText) ?? 0.0;
      final indicacion = double.tryParse(indicacionText) ?? 0.0;
      final diferencia = indicacion - lt;

      // Intentar respetar los decimales de la indicación
      int decimals = 1;
      if (indicacionText.contains('.')) {
        decimals = indicacionText.split('.')[1].length;
      }

      _differenceControllers[index].text = diferencia.toStringAsFixed(decimals);
    } else {
      _differenceControllers[index].text = '';
    }
  }

  InputDecoration _buildInputDecoration(String labelText,
      {Widget? suffixIcon}) {
    return InputDecoration(
      labelText: labelText,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20.0)),
      suffixIcon: suffixIcon,
    );
  }

  Widget _buildFilaLinealidad(int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        children: [
          // Fila 1: Carga (LT) y Error (Diferencia)
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _ltControllers[index],
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (value) {
                    widget.linealidad.puntos[index].lt = value;
                    widget.linealidad.puntos[index].indicacion =
                        value; // Copiar a indicación por defecto
                    _indicacionControllers[index].text =
                        value; // Reflejar en controlador
                    _actualizarUltimaCarga();
                    _calcularDiferencia(index);
                    widget.onChanged();
                  },
                  decoration: _buildInputDecoration('LT ${index + 1}'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _differenceControllers[index],
                  decoration: _buildInputDecoration('Error'),
                  readOnly: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Fila 2: Indicación y Retorno
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _indicacionControllers[index],
                  decoration: _buildInputDecoration(
                    'Indicación ${index + 1}',
                    suffixIcon: PopupMenuButton<String>(
                      icon: const Icon(Icons.arrow_drop_down),
                      onSelected: (String newValue) {
                        setState(() {
                          _indicacionControllers[index].text = newValue;
                          widget.linealidad.puntos[index].indicacion = newValue;
                          _calcularDiferencia(index);
                          widget.onChanged();
                        });
                      },
                      itemBuilder: (BuildContext context) {
                        final currentText =
                            _indicacionControllers[index].text.trim();
                        final baseValue = double.tryParse(
                              (currentText.isEmpty
                                      ? widget.linealidad.puntos[index].lt
                                      : currentText)
                                  .replaceAll(',', '.'),
                            ) ??
                            0.0;

                        // Calcular decimales basados en _d1
                        int decimals = 0;
                        if (_d1 % 1 != 0) {
                          String d1Str = _d1.toString();
                          if (d1Str.contains('.')) {
                            decimals = d1Str.split('.')[1].length;
                          } else {
                            decimals = 1; // Fallback
                          }
                        }

                        return List.generate(11, (i) {
                          final value = baseValue + ((i - 5) * _d1);
                          final txt = value.toStringAsFixed(decimals);
                          return PopupMenuItem<String>(
                            value: txt,
                            child: Text(txt),
                          );
                        });
                      },
                    ),
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (value) {
                    widget.linealidad.puntos[index].indicacion = value;
                    _calcularDiferencia(index);
                    widget.onChanged();
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _retornoControllers[index],
                  decoration: _buildInputDecoration('Retorno (0)'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (value) {
                    widget.linealidad.puntos[index].retorno = value;
                    widget.onChanged();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12.0),
          const Divider(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 20),
        const Text(
          'PRUEBAS DE LINEALIDAD',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),

        // Sección Método 2
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _iLsubnController,
                decoration: _buildInputDecoration('I(Lsubn)'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (value) {
                  widget.linealidad.iLsubn = value;
                  _calcularMetodo2();
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: _lsubnController,
                decoration: _buildInputDecoration('Lsubn'),
                readOnly: true,
                style: const TextStyle(color: Colors.lightGreen),
              ),
            ),
          ],
        ),
        const SizedBox(height: 15.0),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _ioController,
                decoration: _buildInputDecoration('Io'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (value) {
                  widget.linealidad.io = value;
                  _calcularLtn();
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: _ltnController,
                decoration: _buildInputDecoration('LTn'),
                readOnly: true,
                style: const TextStyle(color: Colors.lightGreen),
              ),
            ),
          ],
        ),
        const SizedBox(height: 15.0),
        ElevatedButton(
          onPressed: _guardarCarga,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          child: const Text('GUARDAR LTn'),
        ),
        const SizedBox(height: 20.0),
        const Text(
          'CARGAS REGISTRADAS',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        // Lista de filas
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: widget.linealidad.puntos.length,
          itemBuilder: (context, index) {
            return _buildFilaLinealidad(index);
          },
        ),
        const SizedBox(height: 10),

        // Botones de control
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton.icon(
              onPressed:
                  widget.linealidad.puntos.length < 12 ? _agregarFila : null,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Agregar Fila'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            ),
            ElevatedButton.icon(
              onPressed: widget.linealidad.puntos.length > 1
                  ? () => _removerFila(widget.linealidad.puntos.length - 1)
                  : null,
              icon: const Icon(Icons.remove, color: Colors.white),
              label: const Text('Eliminar Fila'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            ),
          ],
        ),
      ],
    );
  }

  @override
  void dispose() {
    for (var controller in _ltControllers) {
      controller.dispose();
    }
    for (var controller in _indicacionControllers) {
      controller.dispose();
    }
    for (var controller in _retornoControllers) {
      controller.dispose();
    }
    for (var controller in _differenceControllers) {
      controller.dispose();
    }
    _iLsubnController.dispose();
    _lsubnController.dispose();
    _ioController.dispose();
    _ltnController.dispose();
    super.dispose();
  }
}
