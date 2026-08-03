// ignore_for_file: deprecated_member_use
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:service_met/screens/calibracion/widgets/qr_scanner_screen.dart';
import 'package:service_met/screens/soporte_new/precarga/precarga_controller.dart';
import 'package:service_met/utils/top_alert.dart';

class ClienteStep extends StatefulWidget {
  final PrecargaController controller;

  const ClienteStep({
    super.key,
    required this.controller,
  });

  @override
  State<ClienteStep> createState() => _ClienteStepState();
}

class _ClienteStepState extends State<ClienteStep> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _nombreComercialController =
      TextEditingController();
  final TextEditingController _razonSocialController = TextEditingController();

  bool _isNewClient = false;
  bool _showQrBanner = true;
  List<Map<String, dynamic>>? _filteredClientes;
  Timer? _debounce;
  bool _isSearchEmpty = true;
  bool _isSearching = false;
  int _searchRequest = 0;

  @override
  void initState() {
    super.initState();
    _filteredClientes = widget.controller.clientes;
    _searchController.addListener(() {
      final isEmpty = _searchController.text.isEmpty;
      if (isEmpty != _isSearchEmpty) {
        setState(() {
          _isSearchEmpty = isEmpty;
        });
      }
    });
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    final request = ++_searchRequest;
    _debounce = Timer(const Duration(milliseconds: 250), () {
      _filterClientes(query, request);
    });
  }

  Future<void> _filterClientes(String query, int request) async {
    final search = query.trim();
    if (search.isEmpty) {
      setState(() {
        _filteredClientes = widget.controller.clientes;
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    try {
      final results = await widget.controller.searchClientes(search);
      if (!mounted || request != _searchRequest) return;
      setState(() {
        _filteredClientes = results;
        _isSearching = false;
      });
    } catch (_) {
      if (!mounted || request != _searchRequest) return;
      setState(() => _isSearching = false);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _nombreComercialController.dispose();
    _razonSocialController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = widget.controller;
    final selectedCliente = c.selectedCliente;
    final hasSelection = selectedCliente != null &&
        (selectedCliente['nombre']?.toString().isNotEmpty ?? false);

    // Sincronizar clientes filtrados si cargaron asíncronamente
    final currentAll = c.clientes;
    if (_searchController.text.isEmpty &&
        (_filteredClientes == null || _filteredClientes!.length != currentAll.length)) {
      _filteredClientes = currentAll;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          _buildHeader(isDark),
          const SizedBox(height: 24),

          // QR Banner
          if (_showQrBanner) ...[
            _buildQrBanner(c, isDark),
            const SizedBox(height: 20),
          ],

          // Selector de modo (Segmented)
          _buildModeSelector(c, isDark),
          const SizedBox(height: 20),

          // Contenido principal
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: !_isNewClient
                ? _buildExistingClientSection(c, isDark)
                : _buildNewClientSection(c, isDark),
          ),

          // Tarjeta de cliente seleccionado
          if (hasSelection) ...[
            const SizedBox(height: 24),
            _buildSelectedClientCard(selectedCliente, isDark),
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
          'Cliente',
          style: GoogleFonts.poppins(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF1A1A1A),
            height: 1.1,
          ),
        ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.2),
        const SizedBox(height: 4),
        Text(
          'Selecciona o registra el cliente para el servicio técnico',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: isDark ? Colors.white54 : Colors.black45,
            fontWeight: FontWeight.w400,
          ),
        ).animate(delay: 100.ms).fadeIn(duration: 400.ms),
      ],
    );
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
            icon: Icons.person_search_rounded,
            isActive: !_isNewClient,
            isDark: isDark,
            onTap: () {
              setState(() {
                _isNewClient = false;
                _searchController.clear();
              });
              _onSearchChanged('');
            },
          ),
          _modeTab(
            label: 'Nuevo',
            icon: Icons.person_add_rounded,
            isActive: _isNewClient,
            isDark: isDark,
            onTap: () {
              setState(() {
                _isNewClient = true;
                _nombreComercialController.clear();
                _razonSocialController.clear();
              });
              provider.selectCliente({
                'id': 'NUEVO_${DateTime.now().millisecondsSinceEpoch}',
                'cliente': '',
                'nombre': '',
                'razonsocial': '',
                'isNew': true,
              });
            },
          ),
          Container(
            width: 1,
            height: 24,
            color: isDark ? Colors.white12 : Colors.black12,
          ),
          _qrTab(provider, isDark),
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

  Widget _qrTab(PrecargaController provider, bool isDark) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _scanQrAndProcess(provider),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF04376E).withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.qr_code_scanner,
                  size: 18, color: Color(0xFF04376E)),
              const SizedBox(width: 6),
              Text(
                'QR',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF04376E),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQrBanner(PrecargaController provider, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF001B36), const Color(0xFF0A1628)]
              : [const Color(0xFFE3F2FD), const Color(0xFFE8EAF6)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF04376E).withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF04376E).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.qr_code_scanner,
                size: 28, color: Color(0xFF04376E)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '¿Tienes el código QR del equipo?',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Escanea para auto-completar cliente, planta e instrumento',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _scanQrAndProcess(provider),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF04376E),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Escanear',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => setState(() => _showQrBanner = false),
            child: Icon(
              Icons.close_rounded,
              size: 20,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.2);
  }

  Widget _buildExistingClientSection(
      PrecargaController provider, bool isDark) {
    final list = _filteredClientes ?? [];

    return Column(
      key: const ValueKey('existing'),
      children: [
        // Buscador
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            style: GoogleFonts.inter(
                fontSize: 14,
                color: isDark ? Colors.white : const Color(0xFF1A1A1A)),
            decoration: InputDecoration(
              hintText: 'Buscar por nombre o razón social...',
              hintStyle: GoogleFonts.inter(
                  color: isDark ? Colors.white38 : Colors.black38,
                  fontSize: 14),
              prefixIcon: Icon(Icons.search_rounded,
                  color: isDark ? Colors.white54 : Colors.black38, size: 20),
              suffixIcon: _isSearching
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : !_isSearchEmpty
                  ? IconButton(
                      icon: Icon(Icons.close_rounded,
                          size: 18,
                          color: isDark ? Colors.white54 : Colors.black38),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
            ),
          ),
        ).animate(delay: 300.ms).fadeIn().slideY(begin: 0.2),
        const SizedBox(height: 12),

        if (provider.isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Column(
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 12),
                Text('Cargando clientes...'),
              ],
            ),
          )
        else if (list.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Column(
              children: [
                Icon(Icons.search_off_rounded,
                    size: 48, color: isDark ? Colors.white24 : Colors.black26),
                const SizedBox(height: 12),
                Text(
                  'Sin resultados',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),
              ],
            ),
          )
        else
          SizedBox(
            height: 420,
            child: ListView.separated(
              itemCount: list.length,
              padding: const EdgeInsets.only(bottom: 8),
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
              final cliente = list[index];
              final isSelected = provider.selectedCliente != null &&
                  (provider.selectedCliente!['cliente_id'] ==
                          cliente['cliente_id'] ||
                      provider.selectedCliente!['nombre'] == cliente['nombre']);
              final nombre = cliente['nombre'] ?? 'Cliente sin nombre';
              final razon = cliente['razonsocial'] ?? '';
              final initials =
                  nombre.isNotEmpty ? nombre[0].toUpperCase() : '?';

              return GestureDetector(
                onTap: () {
                  provider.selectCliente(cliente);
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
                          : (isDark
                              ? Colors.white12
                              : const Color(0xFFE2E8F0)),
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
                            if (razon.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                razon,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: isDark
                                      ? Colors.white38
                                      : Colors.black45,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
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
          ),
      ],
    );
  }

  Widget _buildNewClientSection(
      PrecargaController provider, bool isDark) {
    return Column(
      key: const ValueKey('new'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _inputField(
          controller: _nombreComercialController,
          label: 'Nombre Comercial',
          hint: 'Ej. Empresa ABC',
          icon: Icons.business_rounded,
          isDark: isDark,
          required: true,
          onChanged: (value) {
            provider.selectCliente({
              'id': 'NUEVO_${DateTime.now().millisecondsSinceEpoch}',
              'cliente': value,
              'nombre': value,
              'razonsocial': _razonSocialController.text,
              'isNew': true,
            });
          },
        ).animate(delay: 300.ms).fadeIn().slideX(begin: -0.1),
        const SizedBox(height: 12),
        _inputField(
          controller: _razonSocialController,
          label: 'Razón Social',
          hint: 'Ej. Empresa ABC S.A.C.',
          icon: Icons.assignment_rounded,
          isDark: isDark,
          onChanged: (value) {
            provider.selectCliente({
              'id': 'NUEVO_${DateTime.now().millisecondsSinceEpoch}',
              'cliente': _nombreComercialController.text,
              'nombre': _nombreComercialController.text,
              'razonsocial': value,
              'isNew': true,
            });
          },
        ).animate(delay: 380.ms).fadeIn().slideX(begin: 0.1),
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
              Icon(Icons.info_outline_rounded,
                  size: 18, color: Colors.amber[600]),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Al crear un cliente nuevo, se solicitará ingresar la información de su planta en el paso siguiente.',
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

  Widget _buildSelectedClientCard(
      Map<String, dynamic> cliente, bool isDark) {
    final nombre = cliente['nombre'] ?? 'Cliente sin nombre';
    final razon = cliente['razonsocial'] ?? '';
    final isNew = cliente['isNew'] == true;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFFf9e300).withOpacity(0.08)
            : const Color(0xFFFFFDE6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFf9e300).withOpacity(0.5)),
      ),
      child: Row(
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
                  isNew ? 'Cliente Nuevo Registrado' : 'Cliente Seleccionado',
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
                if (razon.isNotEmpty)
                  Text(
                    razon,
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
    );
  }

  Future<void> _scanQrAndProcess(PrecargaController provider) async {
    final codMetrica = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const QrScannerScreen()),
    );
    if (codMetrica == null || codMetrica.isEmpty || !mounted) return;

    TopAlert.show(context, 'Buscando equipo: $codMetrica');
  }
}
