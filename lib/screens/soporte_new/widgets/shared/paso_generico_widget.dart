import 'package:flutter/material.dart';

class PasoGenericoWidget extends StatelessWidget {
  final String title;
  final Widget child;

  const PasoGenericoWidget({
    super.key,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}
