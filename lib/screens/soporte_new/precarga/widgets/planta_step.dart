// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:service_met/screens/soporte_new/precarga/precarga_controller.dart';
import 'package:service_met/widgets/service_ui/nav_pill.dart';

class PlantaStep extends StatefulWidget {
  final PrecargaController controller;

  const PlantaStep({
    super.key,
    required this.controller,
  });

  @override
  State<PlantaStep> createState() => _PlantaStepState();
}

class _PlantaStepState extends State<PlantaStep> {
  final TextEditingController _plantaDirController = TextEditingController();
  final TextEditingController _plantaDepController = TextEditingController();
  final TextEditingController _nombrePlantaController = TextEditingController();

  bool _isNewPlanta = false;

  @override
  void initState() {
    super.initState();
    final c = widget.controller;
    if (c.selectedCliente?['isNew'] == true || c.plantas.isEmpty) {
      _isNewPlanta = true;
    }
  }

  @override
  void dispose() {
    _plantaDirController.dispose();
    _plantaDepController.dispose();
    _nombrePlantaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = widget.controller;
    final cliente = c.selectedCliente;
    final isNewClient = cliente?['isNew'] == true;
    final selectedPlanta = c.selectedPlanta;
    final hasSelection = selectedPlanta != null &&
        (selectedPlanta['nombre']?.toString().isNotEmpty ?? false);

    // Si no hay plantas o el cliente es nuevo, forzamos modo nueva planta
    if ((isNewClient || c.plantas.isEmpty) && !_isNewPlanta) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _isNewPlanta = true);
      });
    }

    return SingleChildScrollView(
      padding: ServiceNavPill.pagePadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          _buildHeader(isDark),
          const SizedBox(height: 24),

          // Cliente Info Banner
          _buildClienteBanner(cliente, isDark),
          const SizedBox(height: 24),

          // Mode Selector (si el cliente tiene plantas existentes)
          if (!isNewClient && c.plantas.isNotEmpty) ...[
            _buildModeSelector(c, isDark),
            const SizedBox(height: 20),
          ],

          // Contenido principal
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: (!_isNewPlanta)
                ? _buildExistingPlantaSection(c, isDark)
                : _buildNewPlantaSection(c, isDark, isNewClient),
          ),

          // Card de Planta seleccionada
          if (hasSelection) ...[
            const SizedBox(height: 24),
            _buildSelectedPlantaCard(selectedPlanta, isDark),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Planta',
          style: GoogleFonts.poppins(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF1A1A1A),
            height: 1.1,
          ),
        ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.2),
        const SizedBox(height: 4),
        Text(
          'Selecciona o registra la planta donde se realizará el servicio',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: isDark ? Colors.white54 : Colors.black45,
            fontWeight: FontWeight.w400,
          ),
        ).animate(delay: 100.ms).fadeIn(duration: 400.ms),
      ],
    );
  }

  Widget _buildClienteBanner(Map<String, dynamic>? cliente, bool isDark) {
    if (cliente == null || cliente['nombre'] == null) {
      return const SizedBox.shrink();
    }

    final nombre = cliente['nombre']?.toString() ?? 'N/A';
    final isNew = cliente['isNew'] == true;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? Colors.white12 : const Color(0xFFF0F2F5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.business_rounded,
                color: isDark ? Colors.white70 : Colors.black54, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cliente para este servicio',
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      color: isDark ? Colors.white54 : Colors.black45,
                      fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  nombre,
                  style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF1A1A1A)),
                ),
              ],
            ),
          ),
          if (isNew)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'NUEVO',
                style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.orange[700]),
              ),
            ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms).slideY(begin: -0.2);
  }

  Widget _buildModeSelector(PrecargaController provider, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF0F2F5),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _modeTab(
            label: 'Existente',
            icon: Icons.factory_outlined,
            isActive: !_isNewPlanta,
            isDark: isDark,
            onTap: () {
              setState(() {
                _isNewPlanta = false;
              });
            },
          ),
          _modeTab(
            label: 'Nueva',
            icon: Icons.add_business_rounded,
            isActive: _isNewPlanta,
            isDark: isDark,
            onTap: () {
              setState(() {
                _isNewPlanta = true;
                _nombrePlantaController.clear();
                _plantaDirController.clear();
                _plantaDepController.clear();
              });
            },
          ),
        ],
      ),
    ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.2);
  }

  Widget _modeTab({
    required String label,
    required IconData icon,
    required bool isActive,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFFf9e300) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isActive
                ? [
                    BoxShadow(
                        color: const Color(0xFFf9e300).withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 3))
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 18,
                  color: isActive
                      ? const Color(0xFF1A1A1A)
                      : (isDark ? Colors.white54 : Colors.black45)),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                  color: isActive
                      ? const Color(0xFF1A1A1A)
                      : (isDark ? Colors.white54 : Colors.black45),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExistingPlantaSection(
      PrecargaController provider, bool isDark) {
    if (provider.isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final plantas = provider.plantas;

    return Column(
      key: const ValueKey('existing_planta'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: plantas.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final planta = plantas[index];
            final isSelected = provider.selectedPlanta != null &&
                (provider.selectedPlanta!['codigo_planta'] ==
                        planta['codigo_planta'] ||
                    provider.selectedPlanta!['codigo'] == planta['codigo']);

            final nombre = planta['nombre']?.toString() ?? 'Planta sin nombre';
            final direccion = planta['dir']?.toString() ?? '';
            final departamento = planta['dep']?.toString() ?? '';
            final codigo = planta['codigo']?.toString() ??
                planta['codigo_planta']?.toString() ??
                '';
            final initials = nombre.isNotEmpty ? nombre[0].toUpperCase() : 'P';

            return GestureDetector(
              onTap: () {
                provider.selectPlanta(planta);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark
                          ? const Color(0xFFf9e300).withOpacity(0.08)
                          : const Color(0xFFFFFDE6))
                      : (isDark ? const Color(0xFF2A2A2A) : Colors.white),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFFf9e300)
                        : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFf9e300)
                            : (isDark
                                ? Colors.white12
                                : const Color(0xFFF0F2F5)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          initials,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: isSelected
                                ? const Color(0xFF1A1A1A)
                                : (isDark ? Colors.white60 : Colors.black45),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nombre,
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: isSelected
                                  ? (isDark
                                      ? const Color(0xFFf9e300)
                                      : const Color(0xFF5A4E00))
                                  : (isDark
                                      ? Colors.white
                                      : const Color(0xFF1A1A1A)),
                            ),
                          ),
                          if (codigo.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Código: $codigo',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.white54 : Colors.black54,
                              ),
                            ),
                          ],
                          if (direccion.isNotEmpty || departamento.isNotEmpty)
                            Text(
                              [
                                if (direccion.isNotEmpty) direccion,
                                if (departamento.isNotEmpty) departamento
                              ].join(', '),
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: isDark ? Colors.white38 : Colors.black45,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Color(0xFFf9e300),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check_rounded,
                            size: 14, color: Color(0xFF1A1A1A)),
                      ),
                  ],
                ),
              ),
            )
                .animate(delay: Duration(milliseconds: 40 * index))
                .fadeIn()
                .slideX(begin: 0.05);
          },
        ),
      ],
    );
  }

  Widget _buildNewPlantaSection(
      PrecargaController provider, bool isDark, bool isNewClient) {
    return Column(
      key: const ValueKey('new_planta'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isNewClient || provider.plantas.isEmpty) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? Colors.blue.withOpacity(0.1) : Colors.blue[50],
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 18, color: Colors.blue[600]),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isNewClient
                        ? 'Como el cliente es nuevo, debe registrar al menos una planta.'
                        : 'Este cliente aún no tiene plantas registradas. Registre una nueva.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: isDark ? Colors.blue[300] : Colors.blue[800],
                    ),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn().scale(begin: const Offset(0.97, 0.97)),
        ],

        _inputField(
          controller: _nombrePlantaController,
          label: 'Nombre de la Planta',
          hint: 'Ej. Planta Principal',
          icon: Icons.factory_rounded,
          isDark: isDark,
          required: true,
          onChanged: (_) => _updateNewPlanta(provider),
        ).animate(delay: 300.ms).fadeIn().slideX(begin: -0.1),
        const SizedBox(height: 12),

        _inputField(
          controller: _plantaDirController,
          label: 'Dirección',
          hint: 'Ej. Av. Industrial 123',
          icon: Icons.location_on_rounded,
          isDark: isDark,
          required: true,
          onChanged: (_) => _updateNewPlanta(provider),
        ).animate(delay: 380.ms).fadeIn().slideX(begin: 0.1),
        const SizedBox(height: 12),

        _inputField(
          controller: _plantaDepController,
          label: 'Departamento',
          hint: 'Ej. Lima',
          icon: Icons.map_rounded,
          isDark: isDark,
          required: true,
          onChanged: (_) => _updateNewPlanta(provider),
        ).animate(delay: 460.ms).fadeIn().slideX(begin: -0.1),

        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? Colors.amber.withOpacity(0.1) : Colors.amber[50],
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.amber.withOpacity(0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber_rounded,
                  size: 18, color: Colors.amber[600]),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'El código de planta definitivo se asignará en el sistema. Por ahora se utilizará un código temporal (NNNN-NN).',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    height: 1.5,
                    color: isDark ? Colors.amber[300] : Colors.amber[800],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _updateNewPlanta(PrecargaController provider) {
    provider.selectPlanta({
      'nombre': _nombrePlantaController.text,
      'dir': _plantaDirController.text,
      'dep': _plantaDepController.text,
      'codigo_planta': 'NNNN-NN',
      'codigo': 'NNNN-NN',
      'isNew': true,
    });
  }

  Widget _inputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool isDark,
    required ValueChanged<String> onChanged,
    bool required = false,
  }) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: GoogleFonts.inter(
            fontSize: 14,
            color: isDark ? Colors.white : const Color(0xFF1A1A1A)),
        decoration: InputDecoration(
          labelText: required ? '$label *' : label,
          labelStyle: GoogleFonts.inter(
              fontSize: 13, color: isDark ? Colors.white54 : Colors.black45),
          hintText: hint,
          prefixIcon: Icon(icon,
              size: 20, color: isDark ? Colors.white38 : Colors.black38),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
        ),
      ),
    );
  }

  Widget _buildSelectedPlantaCard(
      Map<String, dynamic> planta, bool isDark) {
    final nombre = planta['nombre']?.toString() ?? 'Planta sin nombre';
    final codigo = planta['codigo']?.toString() ?? planta['codigo_planta']?.toString() ?? '';
    final dir = planta['dir']?.toString() ?? '';
    final dep = planta['dep']?.toString() ?? '';
    final isNew = planta['isNew'] == true;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFFf9e300).withOpacity(0.08)
            : const Color(0xFFFFFDE6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFf9e300).withOpacity(0.5)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFf9e300),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.check_rounded,
                    color: Color(0xFF1A1A1A), size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isNew ? 'Planta Nueva Registrada' : 'Planta Seleccionada',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? const Color(0xFFf9e300)
                            : const Color(0xFF5A4E00),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      nombre,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                      ),
                    ),
                    if (codigo.isNotEmpty)
                      Text(
                        'Código: $codigo',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (dir.isNotEmpty || dep.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? Colors.black12 : Colors.white.withOpacity(0.6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on_outlined,
                      size: 14, color: Color(0xFF5A4E00)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      [if (dir.isNotEmpty) dir, if (dep.isNotEmpty) dep].join(', '),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
