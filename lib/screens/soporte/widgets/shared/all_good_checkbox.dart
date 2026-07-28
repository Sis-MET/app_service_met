import 'package:flutter/material.dart';

class AllGoodCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;

  const AllGoodCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.label = 'Marcar todo como Buen Estado',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: value
            ? Colors.green.withOpacity(0.1)
            : Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: value
              ? Colors.green.withOpacity(0.3)
              : Colors.grey.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: CheckboxListTile(
        title: Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          value
              ? 'Todos los campos est\u00e1n en "1 Bueno" con comentario "En buen estado"'
              : 'Active esta opci\u00f3n para aplicar "Buen Estado" a todos los campos',
          style: TextStyle(
            fontSize: 12,
            color: value ? Colors.green[700] : Colors.grey[600],
          ),
        ),
        value: value,
        onChanged: (v) => onChanged(v ?? false),
        activeColor: Colors.green,
        controlAffinity: ListTileControlAffinity.leading,
      ),
    );
  }
}
