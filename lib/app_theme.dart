import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color _primaryColor = Color(0xFFC0392B); // Main brand red
  static const Color _primaryColorDark = Color(0xFFD32F2F);

  // Light Theme Color Scheme - Updated for cleaner look
  static const ColorScheme _lightColorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: _primaryColor,
    onPrimary: Colors.white,
    primaryContainer: Color(0xFFFFD5D2), // Lighter primary container
    onPrimaryContainer: Color(0xFF4E0000),
    secondary: Color(0xFF795548),
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFFD7CCC8),
    onSecondaryContainer: Color(0xFF2D160A),
    tertiary: Color(0xFF00695C),
    onTertiary: Colors.white,
    tertiaryContainer: Color(0xFFB2DFDB),
    onTertiaryContainer: Color(0xFF00251E),
    error: Color(0xFFB00020),
    onError: Colors.white,
    errorContainer: Color(0xFFFCD8DF),
    onErrorContainer: Color(0xFF3E000C),
    background: Color(0xFFFAFAFA), // Cleaner background - very light grey
    onBackground: Color(0xFF1B1B1F), // Darker text for contrast
    surface: Colors.white,          // Cards, Dialogs background
    onSurface: Color(0xFF1B1B1F),
    surfaceVariant: Color(0xFFF1F1F1), // Lighter variant for subtle backgrounds like input fields
    onSurfaceVariant: Color(0xFF48464A),
    outline: Color(0xFFBDBDBD), // Softer outline
    shadow: Colors.black,
    inverseSurface: Color(0xFF303033),
    onInverseSurface: Color(0xFFF2EFF4),
    inversePrimary: Color(0xFFFFB3B0),
    surfaceTint: _primaryColor,
  );

  // Dark Theme Color Scheme (remains largely the same, but can be tweaked if needed)
  static const ColorScheme _darkColorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: _primaryColorDark,
    onPrimary: Colors.white,
    primaryContainer: Color(0xFF93000A),
    onPrimaryContainer: Color(0xFFFFDAD6),
    secondary: Color(0xFFBCAAA4),
    onSecondary: Color(0xFF44291E),
    secondaryContainer: Color(0xFF5D4037),
    onSecondaryContainer: Color(0xFFD7CCC8),
    tertiary: Color(0xFF4DB6AC),
    onTertiary: Color(0xFF003731),
    tertiaryContainer: Color(0xFF004D40),
    onTertiaryContainer: Color(0xFFB2DFDB),
    error: Color(0xFFCF6679),
    onError: Colors.black,
    errorContainer: Color(0xFFB00020),
    onErrorContainer: Color(0xFFFCD8DF),
    background: Color(0xFF121212),
    onBackground: Color(0xFFE6E1E5),
    surface: Color(0xFF1E1E1E),
    onSurface: Color(0xFFE6E1E5),
    surfaceVariant: Color(0xFF4A484C), // Adjusted for dark
    onSurfaceVariant: Color(0xFFCAC4CF),
    outline: Color(0xFF938F94),
    shadow: Colors.black,
    inverseSurface: Color(0xFFE6E1E5),
    onInverseSurface: Color(0xFF313033),
    inversePrimary: Color(0xFF6E0004),
    surfaceTint: _primaryColorDark,
  );

  static TextTheme _buildTextTheme(TextTheme base, ColorScheme colorScheme) {
    return base.copyWith(
      displayLarge: GoogleFonts.poppins(fontSize: 57, fontWeight: FontWeight.w400, color: colorScheme.onBackground),
      displayMedium: GoogleFonts.poppins(fontSize: 45, fontWeight: FontWeight.w400, color: colorScheme.onBackground),
      displaySmall: GoogleFonts.poppins(fontSize: 36, fontWeight: FontWeight.w400, color: colorScheme.onBackground),
      headlineLarge: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.w600, color: colorScheme.onBackground),
      headlineMedium: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.w600, color: colorScheme.onBackground),
      headlineSmall: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w600, color: colorScheme.onBackground),
      titleLarge: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w600, color: colorScheme.onBackground),
      titleMedium: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
      titleSmall: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, color: colorScheme.onSurface),
      bodyLarge: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w400, color: colorScheme.onBackground),
      bodyMedium: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w400, color: colorScheme.onBackground),
      bodySmall: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w400, color: colorScheme.onSurfaceVariant),
      labelLarge: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: colorScheme.onPrimary), 
      labelMedium: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: colorScheme.onSurfaceVariant),
      labelSmall: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w500, color: colorScheme.onSurfaceVariant),
    ).apply(
      bodyColor: colorScheme.onBackground,
      displayColor: colorScheme.onBackground,
    );
  }

  static final ThemeData lightTheme = ThemeData(
    colorScheme: _lightColorScheme,
    textTheme: _buildTextTheme(GoogleFonts.poppinsTextTheme(), _lightColorScheme),
    primaryColor: _primaryColor,
    scaffoldBackgroundColor: _lightColorScheme.background,
    appBarTheme: AppBarTheme(
      backgroundColor: _lightColorScheme.primary, 
      foregroundColor: _lightColorScheme.onPrimary, 
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.15), // Softer shadow
      titleTextStyle: GoogleFonts.poppins(color: _lightColorScheme.onPrimary, fontSize: 20, fontWeight: FontWeight.w600),
      iconTheme: IconThemeData(color: _lightColorScheme.onPrimary),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _lightColorScheme.primary,
        foregroundColor: _lightColorScheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), // Slightly less rounded
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        textStyle: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600),
        elevation: 2, // Softer elevation
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: _lightColorScheme.primary,
        textStyle: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    cardTheme: CardTheme(
      color: _lightColorScheme.surface, // White cards
      elevation: 1.5, // Reduced elevation for cleaner look
      shadowColor: Colors.grey.shade200, // Lighter shadow
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), // Consistent rounding
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _lightColorScheme.surfaceVariant.withOpacity(0.6), // More subtle fill
      labelStyle: GoogleFonts.poppins(color: _lightColorScheme.onSurfaceVariant, fontSize: 14),
      hintStyle: GoogleFonts.poppins(color: _lightColorScheme.onSurfaceVariant.withOpacity(0.7), fontSize: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: _lightColorScheme.outline.withOpacity(0.5)), // Subtle border
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: _lightColorScheme.outline.withOpacity(0.5)), // Subtle border
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: _lightColorScheme.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: _lightColorScheme.error, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: _lightColorScheme.error, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      prefixIconColor: _lightColorScheme.primary,
    ),
    dialogTheme: DialogTheme(
      backgroundColor: _lightColorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      titleTextStyle: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: _lightColorScheme.onSurface),
      contentTextStyle: GoogleFonts.poppins(fontSize: 15, color: _lightColorScheme.onSurface),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      backgroundColor: _lightColorScheme.onBackground,
      contentTextStyle: GoogleFonts.poppins(color: _lightColorScheme.background),
      actionTextColor: _lightColorScheme.inversePrimary,
      elevation: 4,
      insetPadding: const EdgeInsets.all(12),
    ),
    iconTheme: IconThemeData(color: _lightColorScheme.primary),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: _lightColorScheme.primary),
    dividerTheme: DividerThemeData(color: Colors.grey.shade300, thickness: 0.8),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: _lightColorScheme.surface,
      selectedItemColor: _lightColorScheme.primary,
      unselectedItemColor: Colors.grey.shade500, // Slightly lighter unselected
      selectedLabelStyle: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500),
      unselectedLabelStyle: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500),
      elevation: 4, // Softer elevation
      type: BottomNavigationBarType.fixed, 
    ),
    visualDensity: VisualDensity.adaptivePlatformDensity,
  );

  static final ThemeData darkTheme = ThemeData(
    colorScheme: _darkColorScheme,
    textTheme: _buildTextTheme(GoogleFonts.poppinsTextTheme(), _darkColorScheme),
    primaryColor: _primaryColorDark,
    scaffoldBackgroundColor: _darkColorScheme.background,
    appBarTheme: AppBarTheme(
      backgroundColor: _darkColorScheme.surface, 
      foregroundColor: _primaryColorDark, 
      elevation: 0,
      shadowColor: Colors.transparent, 
      titleTextStyle: GoogleFonts.poppins(color: _primaryColorDark, fontSize: 20, fontWeight: FontWeight.w600),
      iconTheme: IconThemeData(color: _primaryColorDark),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _darkColorScheme.primary,
        foregroundColor: _darkColorScheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        textStyle: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: _darkColorScheme.primary,
        textStyle: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    cardTheme: CardTheme(
      color: _darkColorScheme.surface,
      elevation: 1,
      shadowColor: Colors.black.withOpacity(0.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _darkColorScheme.surfaceVariant.withOpacity(0.4),
      labelStyle: GoogleFonts.poppins(color: _darkColorScheme.onSurfaceVariant.withOpacity(0.8), fontSize: 14),
      hintStyle: GoogleFonts.poppins(color: _darkColorScheme.onSurfaceVariant.withOpacity(0.6), fontSize: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: _darkColorScheme.outline.withOpacity(0.5)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: _darkColorScheme.outline.withOpacity(0.5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: _darkColorScheme.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: _darkColorScheme.error, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: _darkColorScheme.error, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      prefixIconColor: _darkColorScheme.primary,
    ),
    dialogTheme: DialogTheme(
      backgroundColor: _darkColorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      titleTextStyle: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: _darkColorScheme.onSurface),
      contentTextStyle: GoogleFonts.poppins(fontSize: 15, color: _darkColorScheme.onSurface),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      backgroundColor: _darkColorScheme.onBackground, 
      contentTextStyle: GoogleFonts.poppins(color: _darkColorScheme.background),
      actionTextColor: _darkColorScheme.inversePrimary,
      elevation: 4,
      insetPadding: const EdgeInsets.all(12),
    ),
    iconTheme: IconThemeData(color: _darkColorScheme.primary),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: _darkColorScheme.primary),
    dividerTheme: DividerThemeData(color: Colors.grey.shade700, thickness: 0.8),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: _darkColorScheme.surface,
      selectedItemColor: _darkColorScheme.primary,
      unselectedItemColor: Colors.grey.shade400,
      selectedLabelStyle: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500),
      unselectedLabelStyle: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500),
      elevation: 4,
      type: BottomNavigationBarType.fixed,
    ),
    visualDensity: VisualDensity.adaptivePlatformDensity,
  );
}

class AppSemanticColors {
  static Color success(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.light ? Colors.green.shade600 : Colors.green.shade400;
  }

  static Color warning(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.light ? Colors.orange.shade700 : Colors.orange.shade400;
  }

  static Color danger(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.light ? Colors.red.shade700 : Colors.red.shade500;
  }

  static Color performanceAman(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.light ? Colors.green.shade600 : Colors.green.shade400;
  }

  static Color performanceBahaya(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.light ? Colors.yellow.shade700 : Colors.yellow.shade600;
  }

  static Color performanceDarurat(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.light ? Colors.red.shade700 : Colors.red.shade500;
  }

  static Color performanceError(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.light ? Colors.orange.shade700 : Colors.orange.shade500;
  }

  static Color performanceNotAvailable(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.light ? Colors.blueGrey.shade400 : Colors.blueGrey.shade600;
  }
}

