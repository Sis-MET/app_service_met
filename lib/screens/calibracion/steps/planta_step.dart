// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:service_met/models/service_session.dart';
import 'package:service_met/providers/service_session_provider.dart';
import 'package:service_met/repositories/calibration_repository.dart';
import 'package:service_met/widgets/service_ui/nav_pill.dart';

class PlantaStep extends StatefulWidget {
  const PlantaStep({super.key});

  @override
  State<PlantaStep> createState() => _PlantaStepState();
}

class _PlantaStepState extends State<PlantaStep> {
  final TextEditingController _plantaDirController = TextEditingController();
  final TextEditingController _plantaDepController = TextEditingController();
  final TextEditingController _nombrePlantaController = TextEditingController();
  final CalibrationRepository _repository = CalibrationRepository();

  List<Map<String, dynamic>>? _plantas;
  bool _isLoading = false;
  bool _isNewPlanta = false;
  String? _loadedClienteKey;
  bool _loadScheduled = false;
  int _loadRequest = 0;

  String? _clienteKey(ClienteInfo? cliente) {
    if (cliente == null) return null;
    if (cliente.isNew == true) return '__nuevo__';
    return cliente.id;
  }

  void _scheduleLoad(ClienteInfo? cliente) {
    final key = _clienteKey(cliente);
    if (_loadScheduled || key == _loadedClienteKey) return;
    _loadScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadScheduled = false;
      if (mounted) _loadPlantas(cliente);
    });
  }

  Future<void> _loadPlantas(ClienteInfo? cliente) async {
    final request = ++_loadRequest;
    _loadedClienteKey = _clienteKey(cliente);

    // Si el cliente es nuevo, forzamos la creación de planta nueva
    if (cliente?.isNew == true) {
      setState(() {
        _isNewPlanta = true;
        _plantas = [];
      });
      return;
    }

    if (cliente != null && cliente.id != null) {
      setState(() => _isLoading = true);
      try {
        final result = await _repository.getPlantas(cliente.id!);
        if (!mounted || request != _loadRequest) return;
        setState(() {
          _plantas = result;
          _isLoading = false;
          _isNewPlanta = result.isEmpty;
        });
      } catch (_) {
        if (!mounted || request != _loadRequest) return;
        setState(() {
          _plantas = [];
          _isLoading = false;
        });
      }
    } else {
      setState(() {
        _plantas = [];
        _isLoading = false;
      });
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

    return Consumer<ServiceSessionProvider>(
      builder: (context, provider, child) {
        final cliente = provider.session?.cliente;
        _scheduleLoad(cliente);
        final isNewClient = cliente?.isNew ?? false;
        final selectedPlanta = provider.session?.planta;
        final hasSelection =
            selectedPlanta?.codigo != null || selectedPlanta?.nombre != null;

        return SingleChildScrollView(
          padding: ServiceNavPill.pagePadding(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              _buildHeader(isDark),
              const SizedBox(height: 24),

              // Cliente info banner
              _buildClienteBanner(cliente, isDark),
              const SizedBox(height: 24),

              // Mode selector (only if client is not new and has existing plantas)
              if (!isNewClient && _plantas != null && _plantas!.isNotEmpty) ...[
                _buildModeSelector(provider, isDark),
                const SizedBox(height: 20),
              ],

              // Content
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: (!_isNewPlanta)
                    ? _buildExistingPlantaSection(provider, isDark)
                    : _buildNewPlantaSection(provider, isDark, isNewClient),
              ),

              // Selected planta card
              if (hasSelection) ...[
                const SizedBox(height: 24),
                _buildSelectedPlantaCard(provider, isDark),
              ],
            ],
          ),
        );
      },
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
          'Selecciona o registra la planta del servicio',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: isDark ? Colors.white54 : Colors.black45,
            fontWeight: FontWeight.w400,
          ),
        ).animate(delay: 100.ms).fadeIn(duration: 400.ms),
      ],
    );
  }

  Widget _buildClienteBanner(ClienteInfo? cliente, bool isDark) {
    if (cliente == null || cliente.nombreComercial == null) {
      return const SizedBox.shrink();
    }

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
                  cliente.nombreComercial!,
                  style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF1A1A1A)),
                ),
              ],
            ),
          ),
          if (cliente.isNew ?? false)
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

  Widget _buildModeSelector(ServiceSessionProvider provider, bool isDark) {
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
                provider.updatePlanta(PlantaInfo());
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
                provider.updatePlanta(PlantaInfo(isNew: true));
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
      ServiceSessionProvider provider, bool isDark) {
    if (_isLoading) {
      return const Padding(
        key: ValueKey('planta_loading'),
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_plantas == null || _plantas!.isEmpty) {
      return const SizedBox.shrink(
          key:
              ValueKey('planta_empty')); // Handled by forced _isNewPlanta state
    }

    return Column(
      key: const ValueKey('existing_planta'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _plantas!.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final planta = _plantas![index];
            final isSelected =
                provider.session?.planta?.codigo == planta['codigo_planta'];
            final nombre = planta['planta']?.toString() ?? 'Planta sin nombre';
            final direccion = planta['dir']?.toString() ?? '';
            final departamento = planta['dep']?.toString() ?? '';
            final codigo = planta['codigo_planta']?.toString() ?? '';
            final initials = nombre.isNotEmpty ? nombre[0].toUpperCase() : 'P';

            return GestureDetector(
              onTap: () {
                provider.updatePlanta(PlantaInfo(
                  id: planta['planta_id']?.toString() ??
                      planta['unique_key']?.toString(),
                  codigo: codigo,
                  nombre: nombre,
                  direccion: direccion,
                  departamento: departamento,
                  isNew: false,
                ));
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
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isSelected ? 0.06 : 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Avatar
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
                          if (direccion.isNotEmpty ||
                              departamento.isNotEmpty) ...[
                            const SizedBox(height: 2),
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
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: isSelected
                          ? Container(
                              key: const ValueKey('check'),
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Color(0xFFf9e300),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.check_rounded,
                                  size: 14, color: Color(0xFF1A1A1A)),
                            )
                          : Icon(
                              key: const ValueKey('arrow'),
                              Icons.chevron_right_rounded,
                              size: 20,
                              color: isDark ? Colors.white24 : Colors.black26,
                            ),
                    ),
                  ],
                ),
              ),
            )
                .animate(delay: Duration(milliseconds: 50 * index))
                .fadeIn()
                .slideX(begin: 0.05);
          },
        ),
      ],
    );
  }

  Widget _buildNewPlantaSection(
      ServiceSessionProvider provider, bool isDark, bool isNewClient) {
    return Column(
      key: const ValueKey('new_planta'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isNewClient || _plantas?.isEmpty == true) ...[
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
          onChanged: (value) => _updateNewPlanta(provider),
        ).animate(delay: 300.ms).fadeIn().slideX(begin: -0.1),
        const SizedBox(height: 12),

        _inputField(
          controller: _plantaDirController,
          label: 'Dirección',
          hint: 'Ej. Av. Industrial 123',
          icon: Icons.location_on_rounded,
          isDark: isDark,
          required: true,
          onChanged: (value) => _updateNewPlanta(provider),
        ).animate(delay: 380.ms).fadeIn().slideX(begin: 0.1),
        const SizedBox(height: 12),

        _inputField(
          controller: _plantaDepController,
          label: 'Departamento',
          hint: 'Ej. Lima',
          icon: Icons.map_rounded,
          isDark: isDark,
          required: true,
          onChanged: (value) => _updateNewPlanta(provider),
        ).animate(delay: 460.ms).fadeIn().slideX(begin: -0.1),

        const SizedBox(height: 16),
        // Info banner about temporary code
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
                  'El código de planta definitivo se asignará después en el sistema. Por ahora se usará un código temporal (NNNN-NN).',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    height: 1.5,
                    color: isDark ? Colors.amber[300] : Colors.amber[800],
                  ),
                ),
              ),
            ],
          ),
        )
            .animate(delay: 540.ms)
            .fadeIn()
            .scale(begin: const Offset(0.97, 0.97)),
      ],
    );
  }

  void _updateNewPlanta(ServiceSessionProvider provider) {
    provider.updatePlanta(PlantaInfo(
      nombre: _nombrePlantaController.text,
      direccion: _plantaDirController.text,
      departamento: _plantaDepController.text,
      codigo: 'NNNN-NN',
      isNew: true,
    ));
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
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
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
          hintStyle: GoogleFonts.inter(
              fontSize: 13, color: isDark ? Colors.white24 : Colors.black26),
          prefixIcon: Icon(icon,
              size: 20, color: isDark ? Colors.white38 : Colors.black38),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
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
      ServiceSessionProvider provider, bool isDark) {
    final planta = provider.session!.planta!;
    final isNew = planta.isNew == true;
    final accentColor = isNew ? Colors.orange[700]! : const Color(0xFFf9e300);
    final bgColor = isNew
        ? (isDark ? Colors.orange.withOpacity(0.08) : Colors.orange[50]!)
        : (isDark
            ? const Color(0xFFf9e300).withOpacity(0.08)
            : const Color(0xFFFFFDE6));

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentColor.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isNew ? Icons.add_business_rounded : Icons.check_rounded,
                  color: isNew ? Colors.white : const Color(0xFF1A1A1A),
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isNew ? 'Planta Nueva' : 'Planta Seleccionada',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isNew
                            ? accentColor
                            : (isDark
                                ? const Color(0xFFf9e300)
                                : const Color(0xFF5A4E00)),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      planta.nombre ?? 'Planta sin nombre',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                      ),
                    ),
                    if (planta.codigo != null && planta.codigo!.isNotEmpty)
                      Text(
                        'Código: ${planta.codigo}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if ((planta.direccion != null && planta.direccion!.isNotEmpty) ||
              (planta.departamento != null &&
                  planta.departamento!.isNotEmpty)) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.black12 : Colors.white.withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  if (planta.direccion != null && planta.direccion!.isNotEmpty)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.location_on_rounded,
                            size: 14, color: accentColor.withOpacity(0.8)),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(planta.direccion!,
                                style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black87))),
                      ],
                    ),
                  if (planta.direccion != null &&
                      planta.direccion!.isNotEmpty &&
                      planta.departamento != null &&
                      planta.departamento!.isNotEmpty)
                    const SizedBox(height: 6),
                  if (planta.departamento != null &&
                      planta.departamento!.isNotEmpty)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.map_rounded,
                            size: 14, color: accentColor.withOpacity(0.8)),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(planta.departamento!,
                                style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black87))),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.2);
  }
}
