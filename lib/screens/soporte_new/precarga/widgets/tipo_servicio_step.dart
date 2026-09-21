import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:service_met/screens/soporte_new/precarga/precarga_controller.dart';
import 'package:service_met/widgets/service_ui/input_decoration.dart';
import 'package:service_met/widgets/service_ui/nav_pill.dart';

class TipoServicioStep extends StatelessWidget {
  final List<ServicioInfo> servicios;
  final String? selectedServicio;
  final ValueChanged<String> onServicioSelected;

  const TipoServicioStep({
    super.key,
    required this.servicios,
    this.selectedServicio,
    required this.onServicioSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: ServiceNavPill.pagePadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ServiceStepHeader(
            title: 'Tipo de Servicio',
            subtitle: 'Seleccione la modalidad de soporte técnico a ejecutar',
          ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.2),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 650;
              if (isWide) {
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 2.2,
                  ),
                  itemCount: servicios.length,
                  itemBuilder: (context, index) {
                    final item = servicios[index];
                    return _buildServicioCard(
                      context: context,
                      item: item,
                      isSelected: selectedServicio == item.nombre,
                      isDark: isDark,
                      index: index,
                    );
                  },
                );
              }
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: servicios.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = servicios[index];
                  return _buildServicioCard(
                    context: context,
                    item: item,
                    isSelected: selectedServicio == item.nombre,
                    isDark: isDark,
                    index: index,
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildServicioCard({
    required BuildContext context,
    required ServicioInfo item,
    required bool isSelected,
    required bool isDark,
    required int index,
  }) {
    final cardBg = isSelected
        ? (isDark
            ? item.color.withOpacity(0.18)
            : item.color.withOpacity(0.08))
        : (isDark ? const Color(0xFF2A2A2A) : Colors.white);

    final borderColor = isSelected
        ? item.color
        : (isDark ? Colors.white12 : const Color(0xFFE2E8F0));

    return GestureDetector(
      onTap: () => onServicioSelected(item.nombre),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: borderColor,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? item.color.withOpacity(0.2)
                  : Colors.black.withOpacity(0.03),
              blurRadius: isSelected ? 12 : 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon Badge
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected
                    ? item.color
                    : (isDark
                        ? item.color.withOpacity(0.2)
                        : item.color.withOpacity(0.12)),
                borderRadius: BorderRadius.circular(14),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: item.color.withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        )
                      ]
                    : null,
              ),
              child: Icon(
                item.icon,
                size: 24,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white : item.color),
              ),
            ),
            const SizedBox(width: 14),
            // Text Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: item.color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.tag,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white70 : item.color,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (isSelected)
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: item.color,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.nombre,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.descripcion,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: isDark ? Colors.white60 : Colors.black54,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate(delay: Duration(milliseconds: 40 * index)).fadeIn().slideY(begin: 0.1);
  }
}
