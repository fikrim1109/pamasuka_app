import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Define a consistent primary color
  static const Color _primaryColor = Color(0xFFC0392B); // Solid Red for Light Theme AppBar
  static const Color _primaryColorDark = Color(0xFFD32F2F); // A slightly adjusted red for dark mode

  // Light Theme Color Scheme
  static const ColorScheme _lightColorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: _primaryColor,
    onPrimary: Colors.white, // White text/icons on primary color
    primaryContainer: Color(0xFFFFCDD2),
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
    background: Color(0xFFF5F5F5),
    onBackground: Color(0xFF1C1B1F),
    surface: Colors.white,
    onSurface: Color(0xFF1C1B1F),
    surfaceVariant: Color(0xFFEDE0E0),
    onSurfaceVariant: Color(0xFF4C4444),
    outline: Color(0xFF7D7474),
    shadow: Colors.black,
    inverseSurface: Color(0xFF313033),
    onInverseSurface: Color(0xFFF3EFF4),
    inversePrimary: Color(0xFFFFB3B1),
    surfaceTint: _primaryColor,
  );

  // Dark Theme Color Scheme
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
    surfaceVariant: Color(0xFF4C4444),
    onSurfaceVariant: Color(0xFFD0C3C3),
    outline: Color(0xFF978E8D),
    shadow: Colors.black,
    inverseSurface: Color(0xFFE6E1E5),
    onInverseSurface: Color(0xFF313033),
    inversePrimary: Color(0xFF6E0004),
    surfaceTint: _primaryColorDark,
  );

  // Common Text Theme
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
      labelLarge: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: colorScheme.onPrimary), // Used by ElevatedButton by default
      labelMedium: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: colorScheme.onSurfaceVariant),
      labelSmall: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w500, color: colorScheme.onSurfaceVariant),
    ).apply(
      bodyColor: colorScheme.onBackground,
      displayColor: colorScheme.onBackground,
    );
  }

  // Light Theme Definition
  static final ThemeData lightTheme = ThemeData(
    colorScheme: _lightColorScheme,
    textTheme: _buildTextTheme(GoogleFonts.poppinsTextTheme(), _lightColorScheme),
    primaryColor: _primaryColor,
    scaffoldBackgroundColor: _lightColorScheme.background,
    appBarTheme: AppBarTheme(
      backgroundColor: _lightColorScheme.primary, // Solid Red background
      foregroundColor: _lightColorScheme.onPrimary, // White for icons (default if not overridden by iconTheme)
      elevation: 2,
      shadowColor: Colors.black26,
      titleTextStyle: GoogleFonts.poppins(color: _lightColorScheme.onPrimary, fontSize: 20, fontWeight: FontWeight.w600), // White title text
      iconTheme: IconThemeData(color: _lightColorScheme.onPrimary), // White icons
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _lightColorScheme.primary,
        foregroundColor: _lightColorScheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        textStyle: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: _lightColorScheme.primary,
        textStyle: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    cardTheme: CardTheme(
      color: _lightColorScheme.surface,
      elevation: 3,
      shadowColor: Colors.grey.shade300,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.grey.shade100,
      labelStyle: GoogleFonts.poppins(color: Colors.grey.shade600),
      hintStyle: GoogleFonts.poppins(color: Colors.grey.shade400),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _lightColorScheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _lightColorScheme.error, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _lightColorScheme.error, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      prefixIconColor: _lightColorScheme.primary,
    ),
    dialogTheme: DialogTheme(
      backgroundColor: _lightColorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      titleTextStyle: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600, color: _lightColorScheme.onSurface),
      contentTextStyle: GoogleFonts.poppins(fontSize: 16, color: _lightColorScheme.onSurface),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: _lightColorScheme.onBackground,
      contentTextStyle: GoogleFonts.poppins(color: _lightColorScheme.background),
      actionTextColor: _lightColorScheme.inversePrimary,
      insetPadding: const EdgeInsets.all(16),
    ),
    iconTheme: IconThemeData(color: _lightColorScheme.primary), // Default icon color for other parts of the app
    progressIndicatorTheme: ProgressIndicatorThemeData(color: _lightColorScheme.primary),
    dividerTheme: DividerThemeData(color: Colors.grey.shade300, thickness: 1),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: _lightColorScheme.surface,
      selectedItemColor: _lightColorScheme.primary,
      unselectedItemColor: Colors.grey.shade600,
      selectedLabelStyle: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500),
      unselectedLabelStyle: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500),
      elevation: 8,
      type: BottomNavigationBarType.fixed, 
    ),
    visualDensity: VisualDensity.adaptivePlatformDensity,
  );

  // Dark Theme Definition
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        textStyle: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
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
      shadowColor: Colors.black.withOpacity(0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF2A2A2A),
      labelStyle: GoogleFonts.poppins(color: Colors.grey.shade400),
      hintStyle: GoogleFonts.poppins(color: Colors.grey.shade500),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _darkColorScheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _darkColorScheme.error, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _darkColorScheme.error, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      prefixIconColor: _darkColorScheme.primary,
    ),
    dialogTheme: DialogTheme(
      backgroundColor: _darkColorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      titleTextStyle: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600, color: _darkColorScheme.onSurface),
      contentTextStyle: GoogleFonts.poppins(fontSize: 16, color: _darkColorScheme.onSurface),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: _darkColorScheme.onBackground, 
      contentTextStyle: GoogleFonts.poppins(color: _darkColorScheme.background),
      actionTextColor: _darkColorScheme.inversePrimary,
      insetPadding: const EdgeInsets.all(16),
    ),
    iconTheme: IconThemeData(color: _darkColorScheme.primary),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: _darkColorScheme.primary),
    dividerTheme: DividerThemeData(color: Colors.grey.shade700, thickness: 1),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: _darkColorScheme.surface,
      selectedItemColor: _darkColorScheme.primary,
      unselectedItemColor: Colors.grey.shade400,
      selectedLabelStyle: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500),
      unselectedLabelStyle: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500),
      elevation: 8,
      type: BottomNavigationBarType.fixed,
    ),
    visualDensity: VisualDensity.adaptivePlatformDensity,
  );
}

// Custom semantic colors (example, can be expanded)
class AppSemanticColors {
  static Color success(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.light ? Colors.green.shade600 : Colors.green.shade300;
  }

  static Color warning(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.light ? Colors.orange.shade700 : Colors.orange.shade300;
  }

  static Color danger(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.light ? Colors.red.shade700 : Colors.red.shade400;
  }

  // Performance status colors from menu_page.dart
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

