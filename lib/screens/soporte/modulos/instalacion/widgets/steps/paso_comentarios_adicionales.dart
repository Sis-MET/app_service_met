import 'package:flutter/material.dart';

import '../../models/instalacion_model.dart';

class PasoComentariosAdicionales extends StatefulWidget {
  final InstalacionModel model;
  final VoidCallback onChanged;

  const PasoComentariosAdicionales({
    super.key,
    required this.model,
    required this.onChanged,
  });

  @override
  State<PasoComentariosAdicionales> createState() =>
      _PasoComentariosAdicionalesState();
}

class _PasoComentariosAdicionalesState
    extends State<PasoComentariosAdicionales> {
  final List<TextEditingController> _controllers = [];

  @override
  void initState() {
    super.initState();
    // Inicializar controladores con valores existentes
    for (var comentario in widget.model.comentariosAdicionales) {
      if (comentario != null) {
        _controllers.add(TextEditingController(text: comentario));
      }
    }
  }

  @override
  void dispose() {
    for (var c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _agregarComentario() {
    if (_controllers.length >= 10) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Máximo 10 comentarios permitidos')));
      return;
    }
    setState(() {
      _controllers.add(TextEditingController());
      _actualizarModelo();
    });
  }

  void _eliminarComentario(int index) {
    setState(() {
      _controllers[index].dispose();
      _controllers.removeAt(index);
      _actualizarModelo();
    });
  }

  void _actualizarModelo() {
    // Limpiar lista del modelo
    widget.model.comentariosAdicionales = List.filled(10, null);
    // Llenar con valores actuales
    for (int i = 0; i < _controllers.length; i++) {
      widget.model.comentariosAdicionales[i] = _controllers[i].text;
    }
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'COMENTARIOS ADICIONALES',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFf5b041),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _agregarComentario,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Agregar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFeCA400),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_controllers.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Text('No hay comentarios adicionales.',
                    style: TextStyle(color: Colors.grey)),
              ),
            ),
          ...List.generate(_controllers.length, (index) {
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _controllers[index],
                        decoration: InputDecoration(
                          labelText: 'Comentario ${index + 1}',
                          border: InputBorder.none,
                        ),
                        maxLines: 2,
                        onChanged: (_) => _actualizarModelo(),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _eliminarComentario(index),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
