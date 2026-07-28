import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:service_met/screens/soporte_new/models/shared_metrology_models.dart';
import 'package:service_met/screens/soporte_new/widgets/shared/excentricidad_widget.dart';
import 'package:service_met/screens/soporte_new/widgets/shared/repetibilidad_widget.dart';
import 'package:service_met/screens/soporte_new/widgets/shared/linealidad_widget.dart';

class PruebasMetrologicasWidget extends StatefulWidget {
  final PruebasMetrologicas pruebas;
  final String title;
  final VoidCallback onDataChanged;

  const PruebasMetrologicasWidget({
    super.key,
    required this.pruebas,
    required this.title,
    required this.onDataChanged,
  });

  @override
  State<PruebasMetrologicasWidget> createState() =>
      _PruebasMetrologicasWidgetState();
}

class _PruebasMetrologicasWidgetState extends State<PruebasMetrologicasWidget>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 14),

          // Custom Segmented TabBar
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1E1E1E)
                  : const Color(0xFFF0F2F5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(
                color: const Color(0xFF46824B),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF46824B).withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              labelColor: Colors.white,
              unselectedLabelColor:
                  isDark ? Colors.white54 : Colors.black54,
              labelStyle: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              tabs: const [
                Tab(text: 'Excentricidad'),
                Tab(text: 'Repetibilidad'),
                Tab(text: 'Linealidad'),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Tab Content
          AnimatedBuilder(
            animation: _tabController,
            builder: (context, _) {
              switch (_tabController.index) {
                case 0:
                  return ExcentricidadWidget(
                    excentricidad: widget.pruebas.excentricidad,
                    onChanged: widget.onDataChanged,
                  );
                case 1:
                  return RepetibilidadWidget(
                    repetibilidad: widget.pruebas.repetibilidad,
                    onChanged: widget.onDataChanged,
                  );
                case 2:
                  return LinealidadWidget(
                    linealidad: widget.pruebas.linealidad,
                    onChanged: widget.onDataChanged,
                  );
                default:
                  return const SizedBox.shrink();
              }
            },
          ),
        ],
      ),
    );
  }
}
