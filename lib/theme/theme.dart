import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SacredTheme {
  // Sacred & Serene Colors
  static const Color surface = Color(0xFFFFF8F6);
  static const Color surfaceDim = Color(0xFFECD5CC);
  static const Color surfaceBright = Color(0xFFFFF8F6);
  
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFFFF1EB);
  static const Color surfaceContainer = Color(0xFFFFEAE1);
  static const Color surfaceContainerHigh = Color(0xFFFBE3DA);
  static const Color surfaceContainerHighest = Color(0xFFF5DED4);
  
  static const Color onSurface = Color(0xFF251913);
  static const Color onSurfaceVariant = Color(0xFF584238);
  static const Color outline = Color(0xFF8C7166);
  static const Color outlineVariant = Color(0xFFE0C0B2);
  
  static const Color primary = Color(0xFF9C3F00);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFFC45100);
  static const Color onPrimaryContainer = Color(0xFFFFFBFF);
  
  static const Color secondary = Color(0xFF525E7F);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color secondaryContainer = Color(0xFFCAD6FD);
  static const Color onSecondaryContainer = Color(0xFF515D7E);
  
  static const Color tertiary = Color(0xFF605C50);
  static const Color onTertiary = Color(0xFFFFFFFF);
  
  static const Color error = Color(0xFFBA1A1A);
  static const Color onError = Color(0xFFFFFFFF);
  
  // Custom Accents
  static const Color deepSaffron = Color(0xFFCC5500);
  static const Color meditativeIndigo = Color(0xFF2E3A59);
  static const Color deepMeditativeIndigo = Color(0xFF0D1A38);
  static const Color parchmentCream = Color(0xFFFDF5E6);
  static const Color templeGold = Color(0xFFD4AF37);

  // Spacing & Layout Rhythm
  static const double marginEdge = 24.0;
  static const double gutterGrid = 16.0;
  static const double stackSm = 8.0;
  static const double stackMd = 16.0;
  static const double stackLg = 32.0;
  static const double safeAreaBottom = 24.0;

  // Corner Radii
  static const double radiusSm = 4.0;
  static const double radiusDefault = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 24.0;

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: primary,
        onPrimary: onPrimary,
        primaryContainer: primaryContainer,
        onPrimaryContainer: onPrimaryContainer,
        secondary: secondary,
        onSecondary: onSecondary,
        secondaryContainer: secondaryContainer,
        onSecondaryContainer: onSecondaryContainer,
        tertiary: tertiary,
        onTertiary: onTertiary,
        error: error,
        onError: onError,
        surface: surface,
        onSurface: onSurface,
        onSurfaceVariant: onSurfaceVariant,
        outline: outline,
        outlineVariant: outlineVariant,
      ),
      scaffoldBackgroundColor: surface,
      cardTheme: CardTheme(
        color: surfaceContainerLow,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusDefault),
          side: const BorderSide(color: outlineVariant, width: 0.5),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: outlineVariant,
        thickness: 0.5,
        space: 1,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButtonButtonTheme(),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButtonButtonTheme(),
      ),
      textTheme: TextTheme(
        // Newsreader for headlines and scriptural texts
        displayLarge: GoogleFonts.newsreader(
          fontSize: 42,
          fontWeight: FontWeight.w600,
          height: 1.23,
          letterSpacing: -0.02,
          color: onSurface,
        ),
        headlineLarge: GoogleFonts.newsreader(
          fontSize: 32,
          fontWeight: FontWeight.w500,
          height: 1.25,
          color: onSurface,
        ),
        headlineMedium: GoogleFonts.newsreader(
          fontSize: 28,
          fontWeight: FontWeight.w500,
          height: 1.28,
          color: onSurface,
        ),
        
        // Newsreader for scripture content
        titleLarge: GoogleFonts.newsreader(
          fontSize: 20,
          fontWeight: FontWeight.w400,
          height: 1.6, // 1.6x line height for meditative reading
          color: onSurface,
        ),

        // Be Vietnam Pro for body and AI responses
        bodyLarge: GoogleFonts.beVietnamPro(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          height: 1.5,
          color: onSurface,
        ),
        bodyMedium: GoogleFonts.beVietnamPro(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          height: 1.43,
          color: onSurfaceVariant,
        ),

        // Inter for microcopy and actions
        labelLarge: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.05,
        ),
        labelSmall: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.05,
          color: onSurfaceVariant,
        ),
      ),
    );
  }

  static ButtonStyle ElevatedButtonButtonTheme() {
    return ElevatedButton.styleFrom(
      backgroundColor: deepSaffron,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusDefault),
      ),
      elevation: 2,
      shadowColor: meditativeIndigo.withOpacity(0.15),
      textStyle: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.05,
      ),
    );
  }

  static ButtonStyle OutlinedButtonButtonTheme() {
    return OutlinedButton.styleFrom(
      foregroundColor: meditativeIndigo,
      side: const BorderSide(color: outline, width: 1.0),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusDefault),
      ),
      textStyle: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.05,
      ),
    );
  }
}
