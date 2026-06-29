// ignore_for_file: deprecated_member_use
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:service_met/models/service_session.dart';
import 'package:service_met/providers/service_session_provider.dart';
import 'package:service_met/repositories/calibration_repository.dart';
import 'package:service_met/screens/calibracion/widgets/qr_scanner_screen.dart';
import 'package:service_met/utils/top_alert.dart';

class ClienteStep extends StatefulWidget {
  const ClienteStep({super.key});

  @override
  State<ClienteStep> createState() => _ClienteStepState();
}

class _ClienteStepState extends State<ClienteStep> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _nombreComercialController =
      TextEditingController();
  final TextEditingController _razonSocialController = TextEditingController();
  final CalibrationRepository _repository = CalibrationRepository();

  bool _isNewClient = false;
  bool _showQrBanner = true;
  List<Map<String, dynamic>>? _allClientes;
  List<Map<String, dynamic>>? _filteredClientes;
  Timer? _debounce;
  bool _isSearchEmpty = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadClientes();
    _searchController.addListener(() {
      final isEmpty = _searchController.text.isEmpty;
      if (isEmpty != _isSearchEmpty) {
        setState(() {
          _isSearchEmpty = isEmpty;
        });
      }
    });
  }

  Future<void> _loadClientes() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final clientes = await _repository.getClientes();

      final processedClientes = clientes.map((c) {
        final newMap = Map<String, dynamic>.from(c);
        final nombre = c['cliente']?.toString().toLowerCase() ?? '';
        final razon = c['razonsocial']?.toString().toLowerCase() ?? '';
        newMap['_searchKey'] = '$nombre $razon';
        return newMap;
      }).toList();

      if (mounted) {
        setState(() {
          _allClientes = processedClientes;
          _filteredClientes = processedClientes;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _allClientes = [];
          _filteredClientes = [];
          _errorMessage = 'Error al cargar clientes: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _filterClientes(query);
    });
  }

  void _filterClientes(String query) {
    if (_allClientes == null) return;

    final search = query.toLowerCase().trim();
    if (search.isEmpty) {
      setState(() {
        _filteredClientes = _allClientes;
      });
      return;
    }

    setState(() {
      _filteredClientes = _allClientes!.where((c) {
        final searchKey = c['_searchKey'] as String? ?? '';
        return searchKey.contains(search);
      }).toList();
    });
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
    return Consumer<ServiceSessionProvider>(
      builder: (context, provider, child) {
        final selectedCliente = provider.session?.cliente;
        final hasSelection = selectedCliente?.nombreComercial != null &&
            selectedCliente!.nombreComercial!.isNotEmpty;

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
                _buildQrBanner(provider, isDark),
                const SizedBox(height: 20),
              ],

              // Mode selector (segmented)
              _buildModeSelector(provider, isDark),
              const SizedBox(height: 20),

              // Content
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: !_isNewClient
                    ? _buildExistingClientSection(provider, isDark)
                    : _buildNewClientSection(provider, isDark),
              ),

              // Selected client card
              if (hasSelection) ...[
                const SizedBox(height: 24),
                _buildSelectedClientCard(provider, isDark),
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
          'Selecciona o registra el cliente del servicio',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: isDark ? Colors.white54 : Colors.black45,
            fontWeight: FontWeight.w400,
          ),
        ).animate(delay: 100.ms).fadeIn(duration: 400.ms),
      ],
    );
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
            icon: Icons.person_search_rounded,
            isActive: !_isNewClient,
            isDark: isDark,
            onTap: () {
              setState(() {
                _isNewClient = false;
                _searchController.clear();
                _filterClientes('');
                provider.updateCliente(ClienteInfo());
              });
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
                provider.updateCliente(ClienteInfo(isNew: true));
              });
            },
          ),
          // Separador visual
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

  Widget _qrTab(ServiceSessionProvider provider, bool isDark) {
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
              Icon(Icons.qr_code_scanner,
                  size: 18, color: const Color(0xFFFFFFFF)),
              const SizedBox(width: 6),
              Text(
                'QR',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFFFFFFF),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQrBanner(ServiceSessionProvider provider, bool isDark) {
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
                size: 28, color: Color(0xFFFFFFFF)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '¿Tienes el código QR del instrumento?',
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
                'Escaneá',
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
      ServiceSessionProvider provider, bool isDark) {
    return Column(
      key: const ValueKey('existing'),
      children: [
        // Search field
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
            style: GoogleFonts.inter(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Buscar por nombre o razón social...',
              hintStyle: GoogleFonts.inter(
                  color: isDark ? Colors.white38 : Colors.black38,
                  fontSize: 14),
              prefixIcon: Icon(Icons.search_rounded,
                  color: isDark ? Colors.white54 : Colors.black38, size: 20),
              suffixIcon: !_isSearchEmpty
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
        ).animate(delay: 300.ms).fadeIn().slideY(begin: 0.2),
        const SizedBox(height: 12),

        // Client list
        if (_isLoading)
          _buildLoadingState(isDark)
        else if (_errorMessage != null)
          _buildErrorState(isDark)
        else if (_filteredClientes!.isEmpty)
          _buildEmptyState(isDark)
        else
          _buildClientList(provider, isDark),
      ],
    );
  }

  Widget _buildLoadingState(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Cargando clientes...',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
          ),
        ],
      ),
    ).animate().fadeIn();
  }

  Widget _buildErrorState(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(Icons.error_outline_rounded,
              size: 48, color: isDark ? Colors.red[300] : Colors.red[400]),
          const SizedBox(height: 12),
          Text(
            'Error al cargar clientes',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              _errorMessage ?? '',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () {
              _loadClientes();
            },
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: Text(
              'Reintentar',
              style: GoogleFonts.inter(fontSize: 13),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF04376E),
              side: const BorderSide(color: Color(0xFF04376E)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
          ),
        ],
      ),
    ).animate().fadeIn();
  }

  Widget _buildEmptyState(bool isDark) {
    return Padding(
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
          Text(
            'Intenta con otro término de búsqueda',
            style: GoogleFonts.inter(
                fontSize: 12, color: isDark ? Colors.white38 : Colors.black38),
          ),
        ],
      ),
    ).animate().fadeIn();
  }

  Widget _buildClientList(ServiceSessionProvider provider, bool isDark) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _filteredClientes!.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final cliente = _filteredClientes![index];
        final isSelected =
            provider.session?.cliente?.id == cliente['cliente_id']?.toString();
        final nombre = cliente['cliente'] ?? 'Cliente desconocido';
        final razon = cliente['razonsocial'] ?? '';
        final initials = nombre.isNotEmpty ? nombre[0].toUpperCase() : '?';

        return GestureDetector(
          onTap: () {
            provider.updateCliente(ClienteInfo(
              id: cliente['cliente_id']?.toString(),
              codigoCliente: cliente['codigo_cliente']?.toString(),
              nombreComercial: cliente['cliente'],
              razonSocial: cliente['razonsocial'],
              isNew: false,
            ));
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                        : (isDark ? Colors.white12 : const Color(0xFFF0F2F5)),
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
    );
  }

  Widget _buildNewClientSection(ServiceSessionProvider provider, bool isDark) {
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
            provider.updateCliente(ClienteInfo(
              nombreComercial: value,
              razonSocial: _razonSocialController.text,
              isNew: true,
            ));
          },
        ).animate(delay: 300.ms).fadeIn().slideX(begin: -0.1),
        const SizedBox(height: 12),
        _inputField(
          controller: _razonSocialController,
          label: 'Razón Social',
          hint: 'Ej. Empresa ABC S.A.S.',
          icon: Icons.assignment_rounded,
          isDark: isDark,
          onChanged: (value) {
            provider.updateCliente(ClienteInfo(
              nombreComercial: _nombreComercialController.text,
              razonSocial: value,
              isNew: true,
            ));
          },
        ).animate(delay: 380.ms).fadeIn().slideX(begin: 0.1),
        const SizedBox(height: 16),
        // Info banner
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
                  'Al crear un cliente nuevo, no podrá ver la lista de balanzas registradas para ese cliente.',
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
            .animate(delay: 460.ms)
            .fadeIn()
            .scale(begin: const Offset(0.97, 0.97)),
      ],
    );
  }

  Future<void> _scanQrAndProcess(ServiceSessionProvider provider) async {
    final codMetrica = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const QrScannerScreen()),
    );
    if (codMetrica == null || !mounted) return;

    final navigator = Navigator.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Color(0xFF667EEA)),
            const SizedBox(height: 16),
            Text(
              'Identificando instrumento...\n$codMetrica',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 14),
            ),
          ],
        ),
      ),
    );

    String? error;
    try {
      error = await provider.processQrCode(codMetrica);
    } catch (e) {
      if (!mounted) return;
      provider.clearQrMode();
      error = 'Error al procesar QR: $e';
    }

    if (navigator.context.mounted) {
      navigator.pop();
    }

    if (!mounted) return;

    if (error != null) {
      TopAlert.show(context, error, isError: true);
    } else {
      _showQrBanner = false;
      TopAlert.show(
        context,
        'Cliente y planta identificados\nConfirme el SECA para continuar',
        isError: false,
      );
    }
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

  Widget _buildSelectedClientCard(
      ServiceSessionProvider provider, bool isDark) {
    final cliente = provider.session!.cliente!;
    final isNew = cliente.isNew == true;
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
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isNew ? Icons.person_add_rounded : Icons.check_rounded,
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
                  isNew ? 'Cliente Nuevo' : 'Cliente Seleccionado',
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
                  cliente.nombreComercial!,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                  ),
                ),
                if (cliente.razonSocial != null &&
                    cliente.razonSocial!.isNotEmpty)
                  Text(
                    cliente.razonSocial!,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.2);
  }
}
