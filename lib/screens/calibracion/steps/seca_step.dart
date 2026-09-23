import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:service_met/providers/service_session_provider.dart';
import 'package:service_met/widgets/service_ui/nav_pill.dart';

class SecaStep extends StatefulWidget {
  const SecaStep({super.key});

  @override
  State<SecaStep> createState() => _SecaStepState();
}

class _SecaStepState extends State<SecaStep> {
  final TextEditingController _cotizacionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<ServiceSessionProvider>();
      if (provider.session == null) return;
      // Al continuar un servicio la cotización sale del SECA guardado; el
      // resto de la pantalla la toma del proveedor.
      final cotizacion = provider.cotizacion;
      _cotizacionController.text = cotizacion;
      provider.setCotizacionSuffix(cotizacion);
    });
  }

  @override
  void dispose() {
    _cotizacionController.dispose();
    super.dispose();
  }

  String _getFixedSecaPart(ServiceSessionProvider provider) {
    final plantaCod = provider.session?.planta?.codigo ?? 'NNNN-NN';
    return '$plantaCod-';
  }

  String _getYearPart() {
    return '-${DateTime.now().year.toString().substring(2)}';
  }

  String _generateProposedSeca(ServiceSessionProvider provider) {
    final cotizacion =
        _cotizacionController.text.isEmpty ? 'C01' : _cotizacionController.text;
    return '${_getFixedSecaPart(provider)}$cotizacion${_getYearPart()}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<ServiceSessionProvider>(
      builder: (context, provider, child) {
        final session = provider.session;
        if (session == null) return const SizedBox.shrink();

        final isConfirmed = session.metadata.secaConfirmed;
        final currentSeca = isConfirmed
            ? session.sessionInfo.seca
            : _generateProposedSeca(provider);
        final tieneCodigoTemporal = currentSeca?.contains('NNNN-NN') ?? false;

        return SingleChildScrollView(
          padding: ServiceNavPill.pagePadding(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(isDark),
              const SizedBox(height: 24),
              _buildInfoSummary(provider, isDark),
              const SizedBox(height: 24),
              _buildSecaCard(provider, isConfirmed, currentSeca, isDark),
              const SizedBox(height: 24),
              _buildAdditionalInfo(isConfirmed, tieneCodigoTemporal, isDark),
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
          'Código SECA',
          style: GoogleFonts.poppins(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF1A1A1A),
            height: 1.1,
          ),
        ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.2),
        const SizedBox(height: 4),
        Text(
          'Generación del código único del servicio',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: isDark ? Colors.white54 : Colors.black45,
            fontWeight: FontWeight.w400,
          ),
        ).animate(delay: 100.ms).fadeIn(duration: 400.ms),
      ],
    );
  }

  Widget _buildInfoSummary(ServiceSessionProvider provider, bool isDark) {
    final session = provider.session!;
    return Container(
      padding: const EdgeInsets.all(18),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  color: isDark ? Colors.white54 : Colors.black54, size: 20),
              const SizedBox(width: 10),
              Text(
                'Resumen de la Información',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSummaryRow(
              'Cliente', session.cliente?.nombreComercial ?? 'N/A', isDark),
          const SizedBox(height: 8),
          _buildSummaryRow(
              'Código Planta', session.planta?.codigo ?? 'N/A', isDark),
          const SizedBox(height: 8),
          _buildSummaryRow(
              'Técnico', session.sessionInfo.userName ?? 'N/A', isDark),
          const SizedBox(height: 8),
          _buildSummaryRow(
              'Fecha', session.sessionInfo.fechaServicio ?? 'N/A', isDark),
        ],
      ),
    ).animate(delay: 200.ms).fadeIn().slideY(begin: -0.2);
  }

  Widget _buildSummaryRow(String label, String value, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF1A1A1A),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSecaCard(ServiceSessionProvider provider, bool isConfirmed,
      String? currentSeca, bool isDark) {
    final accentColor = const Color(0xFFf9e300);
    final cardColor = isConfirmed
        ? (isDark ? accentColor.withOpacity(0.08) : const Color(0xFFFFFDE6))
        : (isDark ? const Color(0xFF2A2A2A) : Colors.white);

    final borderColor = isConfirmed
        ? accentColor.withOpacity(0.5)
        : (isDark ? Colors.white12 : const Color(0xFFE2E8F0));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: isConfirmed ? 1.5 : 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isConfirmed ? 0.05 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        children: [
          Text(
            isConfirmed ? 'SECA Confirmado' : 'SECA Sugerido',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: isConfirmed
                  ? (isDark ? accentColor : const Color(0xFF5A4E00))
                  : (isDark ? Colors.white54 : Colors.black54),
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 16),
          if (isConfirmed)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
              ),
              child: Text(
                currentSeca ?? '',
                style: GoogleFonts.robotoMono(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                  letterSpacing: 2,
                ),
                textAlign: TextAlign.center,
              ),
            ).animate(delay: 300.ms).fadeIn()
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.05)
                    : const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _getFixedSecaPart(provider),
                    style: GoogleFonts.robotoMono(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                      letterSpacing: 1,
                    ),
                  ),
                  Container(
                    width: 70,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    child: TextField(
                      controller: _cotizacionController,
                      selectAllOnFocus: true,
                      style: GoogleFonts.robotoMono(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? accentColor : const Color(0xFF5A4E00),
                        letterSpacing: 1,
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: isDark ? Colors.black26 : Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                              color: isDark
                                  ? Colors.white12
                                  : const Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                              color: isDark
                                  ? Colors.white12
                                  : const Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: accentColor, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        hintText: 'C01',
                      ),
                      textAlign: TextAlign.center,
                      maxLength: 3,
                      buildCounter: (context,
                              {required currentLength,
                              required isFocused,
                              maxLength}) =>
                          null,
                      onChanged: (value) {
                        setState(() {}); // refresh proposed SECA
                        provider
                            .setCotizacionSuffix(value.isEmpty ? 'C01' : value);
                      },
                    ),
                  ),
                  Text(
                    _getYearPart(),
                    style: GoogleFonts.robotoMono(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ).animate(delay: 300.ms).fadeIn(),
          const SizedBox(height: 24),
          if (isConfirmed)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: Color(0xFF1A1A1A), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Confirmado y Registrado',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1A1A1A),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            )
                .animate(delay: 400.ms)
                .fadeIn()
                .scale(begin: const Offset(0.8, 0.8)),
          if (isConfirmed &&
              provider.session?.sessionInfo.sessionId != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.key_rounded,
                      color: isDark ? Colors.white54 : Colors.black45,
                      size: 16),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'ID: ${provider.session!.sessionInfo.sessionId}',
                      style: GoogleFonts.robotoMono(
                        fontSize: 12,
                        color: isDark ? Colors.white70 : Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ).animate(delay: 500.ms).fadeIn(),
          ],
        ],
      ),
    ).animate(delay: 300.ms).fadeIn().slideY(begin: 0.2);
  }

  Widget _buildAdditionalInfo(
      bool isConfirmed, bool tieneCodigoTemporal, bool isDark) {
    return Column(
      children: [
        if (tieneCodigoTemporal)
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: isDark ? Colors.amber.withOpacity(0.1) : Colors.amber[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.amber.withOpacity(0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded,
                    color: Colors.amber[600], size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Código Temporal',
                          style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.amber[400]
                                  : Colors.amber[800])),
                      const SizedBox(height: 4),
                      Text(
                          'Este SECA contiene "NNNN-NN" porque el cliente o planta es nuevo. El código definitivo se asignará desde el sistema de gestión.',
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              color: isDark
                                  ? Colors.amber[200]
                                  : Colors.amber[900])),
                    ],
                  ),
                ),
              ],
            ),
          )
              .animate(delay: 400.ms)
              .fadeIn()
              .scale(begin: const Offset(0.95, 0.95)),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF0F2F5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.help_outline_rounded,
                  color: isDark ? Colors.white54 : Colors.black54, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Formato del Código SECA',
                        style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1A1A1A))),
                    const SizedBox(height: 6),
                    Text(
                      'El código se genera automáticamente usando:\n• Código de planta ${tieneCodigoTemporal ? "(temporal)" : "seleccionado"}\n• Numeración correlativa editable (C01)\n• Año actual (${DateTime.now().year.toString().substring(2)})',
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          color: isDark ? Colors.white70 : Colors.black87,
                          height: 1.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ).animate(delay: 500.ms).fadeIn().slideX(begin: -0.1),
      ],
    );
  }
}
