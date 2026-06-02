import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:service_met/models/service_session.dart';

class SuggestionHelper {
  static double getDivisionForValue(BalanzaInfo balanza, double value) {
    final rangos = <Map<String, double>>[];

    final capMax1 = double.tryParse(balanza.capMax1 ?? '') ?? 0;
    final d1 = balanza.d1 ?? 0;
    if (capMax1 > 0 && d1 > 0) {
      rangos.add({'capMax': capMax1, 'd': d1});
    }

    final capMax2 = double.tryParse(balanza.capMax2 ?? '') ?? 0;
    final d2 = balanza.d2 ?? 0;
    if (capMax2 > 0 && d2 > 0) {
      rangos.add({'capMax': capMax2, 'd': d2});
    }

    final capMax3 = double.tryParse(balanza.capMax3 ?? '') ?? 0;
    final d3 = balanza.d3 ?? 0;
    if (capMax3 > 0 && d3 > 0) {
      rangos.add({'capMax': capMax3, 'd': d3});
    }

    if (rangos.isEmpty) return 0;

    rangos.sort((a, b) => a['capMax']!.compareTo(b['capMax']!));

    for (final rango in rangos) {
      if (value <= rango['capMax']!) {
        return rango['d']!;
      }
    }

    return rangos.last['d']!;
  }

  static int getDecimalPlaces(double d) {
    if (d == 0) return 0;
    String s = d.toString();
    if (!s.contains('.')) return 0;
    final parts = s.split('.');
    if (parts.length < 2) return 0;
    return parts[1].length;
  }

  static Future<String?> showSuggestedValues({
    required BuildContext context,
    required BalanzaInfo balanza,
    required double baseValue,
    required String title,
    required bool isDark,
  }) {
    final d = getDivisionForValue(balanza, baseValue);
    if (d == 0) return Future.value(null);

    final decimals = getDecimalPlaces(d);
    int upCount = 5;
    int downCount = 5;

    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final values = <double>[];

            for (int i = upCount; i >= 1; i--) {
              values.add(baseValue + (d * i));
            }

            values.add(baseValue);

            for (int i = 1; i <= downCount; i++) {
              final val = baseValue - (d * i);
              if (val >= 0) values.add(val);
            }

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.5,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black26,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 8),
                    child: Row(
                      children: [
                        Icon(Icons.tune_rounded,
                            color: isDark
                                ? Colors.white54
                                : Colors.black54,
                            size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            title,
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1A1A1A),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white12
                                : const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'd = ${d.toStringAsFixed(decimals)}',
                            style: GoogleFonts.robotoMono(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.white70
                                  : Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        setSheetState(() => upCount += 5);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.keyboard_arrow_up_rounded,
                                color: isDark
                                    ? const Color(0xFF64B5F6)
                                    : const Color(0xFF1565C0),
                                size: 20),
                            const SizedBox(width: 4),
                            Text(
                              'Ver más valores',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? const Color(0xFF64B5F6)
                                    : const Color(0xFF1565C0),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: values.length,
                      itemBuilder: (ctx, vi) {
                        final val = values[vi];
                        final isBase = val == baseValue;
                        final formatted = val.toStringAsFixed(decimals);

                        return Material(
                          color: isBase
                              ? (isDark
                                  ? const Color(0xFF2E7D32)
                                      .withOpacity(0.2)
                                  : const Color(0xFFE8F5E9))
                              : Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              Navigator.pop(ctx, formatted);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 14),
                              child: Row(
                                children: [
                                  if (isBase)
                                    Icon(
                                        Icons.arrow_forward_rounded,
                                        color: isDark
                                            ? const Color(0xFF81C784)
                                            : const Color(0xFF2E7D32),
                                        size: 18)
                                  else
                                    const SizedBox(width: 18),
                                  const SizedBox(width: 12),
                                  Text(
                                    formatted,
                                    style: GoogleFonts.robotoMono(
                                      fontSize: 16,
                                      fontWeight: isBase
                                          ? FontWeight.bold
                                          : FontWeight.w500,
                                      color: isBase
                                          ? (isDark
                                              ? const Color(0xFF81C784)
                                              : const Color(0xFF2E7D32))
                                          : (isDark
                                              ? Colors.white
                                              : const Color(0xFF1A1A1A)),
                                    ),
                                  ),
                                  if (isBase) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? const Color(0xFF81C784)
                                                .withOpacity(0.2)
                                            : const Color(0xFFC8E6C9),
                                        borderRadius:
                                            BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'BASE',
                                        style: GoogleFonts.inter(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: isDark
                                              ? const Color(0xFF81C784)
                                              : const Color(0xFF2E7D32),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        setSheetState(() => downCount += 5);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.keyboard_arrow_down_rounded,
                                color: isDark
                                    ? const Color(0xFF64B5F6)
                                    : const Color(0xFF1565C0),
                                size: 20),
                            const SizedBox(width: 4),
                            Text(
                              'Ver menos valores',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? const Color(0xFF64B5F6)
                                    : const Color(0xFF1565C0),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                      height: MediaQuery.of(ctx).padding.bottom + 8),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
