import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import 'app_design.dart';
import 'app_icons.dart';

class AppTheme {
  /// Volver, cerrar y menú de las barras superiores con los íconos de la app,
  /// en vez de los de Material que Flutter pone solo.
  static final _botonesDeAccion = ActionIconThemeData(
    backButtonIconBuilder: (_) => const Icon(AppIcons.atras),
    closeButtonIconBuilder: (_) => const Icon(AppIcons.cerrar),
    drawerButtonIconBuilder: (_) => const Icon(AppIcons.menu),
    endDrawerButtonIconBuilder: (_) => const Icon(AppIcons.menu),
  );

  static ThemeData buildLightTheme(BuildContext context) {
    const primaryColor = AppColors.primary;
    const scaffoldBackgroundColor = AppDesign.canvas;

    final baseTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorSchemeSeed: AppColors.primary,
    );

    return baseTheme.copyWith(
      scaffoldBackgroundColor: scaffoldBackgroundColor,
      primaryColor: primaryColor,
      canvasColor: scaffoldBackgroundColor,
      cardColor: scaffoldBackgroundColor,
      cardTheme: CardThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppDesign.largeRadius,
          side: const BorderSide(color: AppColors.borderLight),
        ),
      ),
      disabledColor: Colors.grey[400],
      colorScheme: baseTheme.colorScheme.copyWith(
        primary: primaryColor,
        secondary: primaryColor,
        surface: scaffoldBackgroundColor,
        onSurface: Colors.black,
        brightness: Brightness.light,
      ),
      textTheme: GoogleFonts.interTextTheme(baseTheme.textTheme).copyWith(
        displayLarge: const TextStyle(color: Colors.black),
        displayMedium: const TextStyle(color: Colors.black),
        displaySmall: const TextStyle(color: Colors.black),
        headlineMedium: const TextStyle(color: Colors.black),
        headlineSmall: const TextStyle(color: Colors.black),
        titleLarge: const TextStyle(color: Colors.black),
        titleMedium: const TextStyle(color: Colors.black),
        titleSmall: const TextStyle(color: Colors.black),
        bodyLarge: const TextStyle(color: Colors.black),
        bodyMedium: const TextStyle(color: Colors.black),
        bodySmall: TextStyle(color: Colors.grey[800]),
        labelLarge: const TextStyle(color: Colors.white),
        labelSmall: TextStyle(color: Colors.grey[800]),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppDesign.canvas,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.dark,
          systemStatusBarContrastEnforced: false,
          systemNavigationBarContrastEnforced: false,
        ),
        titleTextStyle: GoogleFonts.poppins(
          color: Color(0xFF292929),
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
        iconTheme: const IconThemeData(color: Color(0xFF292929)),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: AppDesign.mediumRadius,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppDesign.mediumRadius,
          borderSide: const BorderSide(
            color: AppColors.actionPositive,
            width: 1.4,
          ),
        ),
        floatingLabelStyle: TextStyle(color: Colors.grey[600]),
        contentPadding: const EdgeInsets.all(16),
        labelStyle: TextStyle(color: Colors.grey[800]),
        hintStyle: TextStyle(color: Colors.grey[600]),
        prefixIconColor: Colors.grey[800],
        suffixIconColor: Colors.grey[800],
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: AppDesign.positiveButtonStyle(),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: AppDesign.positiveButtonStyle(),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, AppDesign.controlHeight),
          foregroundColor: AppColors.primary,
          backgroundColor: AppColors.accentYellow.withOpacity(0.055),
          side: BorderSide(
            color: AppColors.accentYellow.withOpacity(0.32),
          ),
          shape: RoundedRectangleBorder(borderRadius: AppDesign.mediumRadius),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
      ),
      iconTheme: const IconThemeData(color: Colors.black),
      actionIconTheme: _botonesDeAccion,
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: primaryColor,
        ),
      ),
      dividerTheme: const DividerThemeData(
        thickness: 1,
        space: 1,
      ).copyWith(color: Colors.grey[300]),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: Colors.grey[800],
        contentTextStyle: const TextStyle(color: Colors.white),
      ),
      popupMenuTheme: PopupMenuThemeData(
        textStyle: const TextStyle(color: Colors.black),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppDesign.radiusLarge),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.grey[200]!,
        labelStyle: const TextStyle(color: Colors.black),
        secondaryLabelStyle: const TextStyle(color: Colors.white),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: AppDesign.largeRadius),
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: AppDesign.ink,
        ),
        contentTextStyle: GoogleFonts.inter(
          fontSize: 14,
          height: 1.45,
          color: AppDesign.muted,
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: AppColors.shimmerGold,
        shape: RoundedRectangleBorder(borderRadius: AppDesign.mediumRadius),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.actionPositive,
        linearTrackColor: Color(0x1F8BC251),
      ),
      sliderTheme: baseTheme.sliderTheme.copyWith(
        activeTrackColor: AppColors.actionPositive,
        thumbColor: AppColors.actionPositive,
        overlayColor: AppColors.accentYellow.withOpacity(0.14),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.actionPositive
              : null,
        ),
        checkColor: const WidgetStatePropertyAll(AppColors.actionPositiveInk),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      radioTheme: const RadioThemeData(
        fillColor: WidgetStatePropertyAll(AppColors.actionPositive),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.actionPositive,
        foregroundColor: AppColors.actionPositiveInk,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color?>(
          (states) {
            if (states.contains(WidgetState.selected)) {
              return Colors.white;
            }
            return Colors.grey;
          },
        ),
        trackColor: WidgetStateProperty.resolveWith<Color?>(
          (states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.actionPositive;
            }
            return Colors.black12;
          },
        ),
      ),
    );
  }

  static ThemeData buildDarkTheme(BuildContext context) {
    const primaryColor = Colors.white;
    const scaffoldBackgroundColor = AppDesign.canvasDark;

    final baseTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorSchemeSeed: AppColors.accentYellow,
    );

    return baseTheme.copyWith(
      scaffoldBackgroundColor: scaffoldBackgroundColor,
      primaryColor: primaryColor,
      canvasColor: AppColors.surfaceDark,
      cardColor: AppColors.surfaceDark,
      cardTheme: CardThemeData(
        color: AppColors.surfaceDark,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppDesign.largeRadius,
          side: const BorderSide(color: AppColors.borderDarkSoft),
        ),
      ),
      disabledColor: Colors.grey[600],
      colorScheme: baseTheme.colorScheme.copyWith(
        primary: primaryColor,
        secondary: primaryColor,
        surface: AppColors.surfaceDark,
        onSurface: Colors.white,
        brightness: Brightness.dark,
      ),
      textTheme: GoogleFonts.interTextTheme(baseTheme.textTheme).copyWith(
        displayLarge: const TextStyle(color: Colors.white),
        displayMedium: const TextStyle(color: Colors.white),
        displaySmall: const TextStyle(color: Colors.white),
        headlineMedium: const TextStyle(color: Colors.white),
        headlineSmall: const TextStyle(color: Colors.white),
        titleLarge: const TextStyle(color: Colors.white),
        titleMedium: const TextStyle(color: Colors.white),
        titleSmall: const TextStyle(color: Colors.white),
        bodyLarge: const TextStyle(color: Colors.white),
        bodyMedium: const TextStyle(color: Colors.white),
        bodySmall: const TextStyle(color: Colors.white70),
        labelLarge: const TextStyle(color: Colors.black),
        labelSmall: const TextStyle(color: Colors.white70),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppDesign.canvasDark,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.light,
          systemStatusBarContrastEnforced: false,
          systemNavigationBarContrastEnforced: false,
        ),
        titleTextStyle: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.grey[800],
        border: OutlineInputBorder(
          borderRadius: AppDesign.mediumRadius,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppDesign.mediumRadius,
          borderSide: const BorderSide(
            color: AppColors.actionPositive,
            width: 1.4,
          ),
        ),
        floatingLabelStyle: TextStyle(color: Colors.grey[400]),
        contentPadding: EdgeInsets.all(16),
        labelStyle: TextStyle(color: Colors.white70),
        hintStyle: TextStyle(color: Colors.white54),
        prefixIconColor: Colors.white70,
        suffixIconColor: Colors.white70,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: AppDesign.positiveButtonStyle(),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: AppDesign.positiveButtonStyle(),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, AppDesign.controlHeight),
          foregroundColor: Colors.white,
          backgroundColor: AppColors.accentYellow.withOpacity(0.065),
          side: BorderSide(
            color: AppColors.accentYellow.withOpacity(0.28),
          ),
          shape: RoundedRectangleBorder(borderRadius: AppDesign.mediumRadius),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
      ),
      iconTheme: const IconThemeData(color: Colors.white),
      actionIconTheme: _botonesDeAccion,
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: primaryColor,
        ),
      ),
      dividerTheme: const DividerThemeData(
        thickness: 1,
        space: 1,
      ).copyWith(color: Colors.grey[700]),
      snackBarTheme: const SnackBarThemeData(
        contentTextStyle: TextStyle(color: Colors.white),
      ).copyWith(backgroundColor: AppColors.surfaceDark),
      popupMenuTheme: const PopupMenuThemeData(
        textStyle: TextStyle(color: Colors.white),
      ).copyWith(color: AppColors.surfaceDark),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surfaceDark,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppDesign.radiusLarge),
          ),
        ),
      ),
      chipTheme: const ChipThemeData(
        labelStyle: TextStyle(color: Colors.white),
        secondaryLabelStyle: TextStyle(color: Colors.black),
      ).copyWith(backgroundColor: Colors.grey[700]!),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceDark,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: AppDesign.largeRadius),
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
        contentTextStyle: GoogleFonts.inter(
          fontSize: 14,
          height: 1.45,
          color: Colors.white70,
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: AppColors.actionPositive,
        shape: RoundedRectangleBorder(borderRadius: AppDesign.mediumRadius),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.actionPositive,
        linearTrackColor: Color(0x338BC251),
      ),
      sliderTheme: baseTheme.sliderTheme.copyWith(
        activeTrackColor: AppColors.actionPositive,
        thumbColor: AppColors.actionPositive,
        overlayColor: AppColors.accentYellow.withOpacity(0.12),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.actionPositive
              : null,
        ),
        checkColor: const WidgetStatePropertyAll(AppColors.actionPositiveInk),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      radioTheme: const RadioThemeData(
        fillColor: WidgetStatePropertyAll(AppColors.actionPositive),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.actionPositive,
        foregroundColor: AppColors.actionPositiveInk,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color?>(
          (states) {
            if (states.contains(WidgetState.selected)) {
              return Colors.white;
            }
            return Colors.grey;
          },
        ),
        trackColor: WidgetStateProperty.resolveWith<Color?>(
          (states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.actionPositive;
            }
            return Colors.black12;
          },
        ),
      ),
    );
  }
}
