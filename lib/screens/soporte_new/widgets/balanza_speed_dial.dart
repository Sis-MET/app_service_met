import 'package:flutter/material.dart';

class BalanzaSpeedDial extends StatefulWidget {
  final VoidCallback onTomarFoto;
  final VoidCallback onSeleccionarBalanza;

  const BalanzaSpeedDial({
    super.key,
    required this.onTomarFoto,
    required this.onSeleccionarBalanza,
  });

  @override
  State<BalanzaSpeedDial> createState() => _BalanzaSpeedDialState();
}

class _BalanzaSpeedDialState extends State<BalanzaSpeedDial>
    with SingleTickerProviderStateMixin {
  bool _isOpen = false;
  late AnimationController _controller;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isOpen = !_isOpen;
      if (_isOpen) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  void _close() {
    if (_isOpen) {
      _toggle();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 200,
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          if (_isOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: _close,
                child: Container(color: Colors.black12),
              ),
            ),
          _buildChild(
            icon: Icons.monitor_weight_outlined,
            label: 'Seleccionar Balanza',
            color: Colors.orange,
            onTap: () {
              _close();
              widget.onSeleccionarBalanza();
            },
            index: 0,
          ),
          _buildChild(
            icon: Icons.camera_alt_outlined,
            label: 'Tomar Foto',
            color: Colors.blue,
            onTap: () {
              _close();
              widget.onTomarFoto();
            },
            index: 1,
          ),
          _buildFab(),
        ],
      ),
    );
  }

  Widget _buildChild({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    required int index,
  }) {
    final double startBottom = 16;
    final double offset = 64;

    return AnimatedBuilder(
      animation: _expandAnimation,
      builder: (context, child) {
        double animationValue = _expandAnimation.value;
        double translateY = -offset * (index + 1) * animationValue;
        double opacity = animationValue;
        double scale = 0.5 + (0.5 * animationValue);

        return Positioned(
          bottom: startBottom + translateY.abs(),
          right: 16,
          child: Transform.scale(
            scale: scale,
            child: Opacity(
              opacity: opacity,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(24),
                color: color,
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: onTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFab() {
    return FloatingActionButton(
      onPressed: _toggle,
      backgroundColor: const Color(0xFF46824B),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.rotate(
            angle: _controller.value * 3.14159,
            child: Icon(
              _isOpen ? Icons.close : Icons.add,
              color: Colors.white,
            ),
          );
        },
      ),
    );
  }
}
