import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Premium Clinical Color Palette
  static const Color primaryNavy = Color(0xFF0F2B5C);
  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color primaryCyan = Color(0xFF0891B2);
  static const Color primaryTeal = Color(0xFF0D9488);
  static const Color accentIndigo = Color(0xFF4F46E5);

  static const Color slateDark = Color(0xFF0F172A);
  static const Color slateMedium = Color(0xFF334155);
  static const Color slateMuted = Color(0xFF64748B);
  static const Color slateLight = Color(0xFF94A3B8);
  
  static const Color backgroundGrey = Color(0xFFF8FAFC);
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  static const Color surfaceElevated = Color(0xFFFFFFFF);
  static const Color borderGrey = Color(0xFFE2E8F0);
  static const Color borderLight = Color(0xFFF1F5F9);

  // Semantic Status Colors & Tints
  static const Color statusSuccess = Color(0xFF059669);
  static const Color statusSuccessBg = Color(0xFFECFDF5);
  static const Color statusSuccessBorder = Color(0xFFA7F3D0);

  static const Color statusWarning = Color(0xFFD97706);
  static const Color statusWarningBg = Color(0xFFFFFBEB);
  static const Color statusWarningBorder = Color(0xFFFDE68A);

  static const Color statusDanger = Color(0xFFDC2626);
  static const Color statusDangerBg = Color(0xFFFEF2F2);
  static const Color statusDangerBorder = Color(0xFFFECACA);

  static const Color statusPurple = Color(0xFF7C3AED);
  static const Color statusPurpleBg = Color(0xFFF5F3FF);
  static const Color statusPurpleBorder = Color(0xFFDDD6FE);

  static const Color statusNeutral = Color(0xFF475569);
  static const Color statusNeutralBg = Color(0xFFF1F5F9);
  static const Color statusNeutralBorder = Color(0xFFE2E8F0);

  // Modern Gradients
  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF0F172A), Color(0xFF1E3A8A), Color(0xFF2563EB)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient tealGradient = LinearGradient(
    colors: [Color(0xFF0F766E), Color(0xFF0D9488), Color(0xFF06B6D4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFFFFFFFF), Color(0xFFF8FAFC)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // Modern Shadows
  static List<BoxShadow> get softShadow => [
    BoxShadow(
      color: const Color(0xFF0F172A).withValues(alpha: 0.04),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: const Color(0xFF0F172A).withValues(alpha: 0.02),
      blurRadius: 2,
      offset: const Offset(0, 1),
    ),
  ];

  static List<BoxShadow> get hoverShadow => [
    BoxShadow(
      color: const Color(0xFF1E3A8A).withValues(alpha: 0.08),
      blurRadius: 16,
      offset: const Offset(0, 8),
    ),
    BoxShadow(
      color: const Color(0xFF0F172A).withValues(alpha: 0.04),
      blurRadius: 4,
      offset: const Offset(0, 2),
    ),
  ];

  static ThemeData get lightTheme {
    final baseTextTheme = GoogleFonts.plusJakartaSansTextTheme();

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: backgroundGrey,
      primaryColor: primaryNavy,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryNavy,
        primary: primaryNavy,
        secondary: primaryBlue,
        tertiary: primaryTeal,
        surface: surfaceWhite,
        error: statusDanger,
      ),
      textTheme: baseTextTheme.copyWith(
        displayLarge: GoogleFonts.plusJakartaSans(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          color: slateDark,
          letterSpacing: -0.8,
        ),
        displayMedium: GoogleFonts.plusJakartaSans(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: slateDark,
          letterSpacing: -0.6,
        ),
        headlineLarge: GoogleFonts.plusJakartaSans(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: slateDark,
          letterSpacing: -0.4,
        ),
        headlineMedium: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: slateDark,
          letterSpacing: -0.3,
        ),
        titleMedium: GoogleFonts.plusJakartaSans(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: slateDark,
        ),
        bodyLarge: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: slateDark,
        ),
        bodyMedium: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: slateMedium,
        ),
        labelLarge: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surfaceWhite,
        foregroundColor: slateDark,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          color: slateDark,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        iconTheme: const IconThemeData(color: slateDark),
      ),
      cardTheme: CardThemeData(
        color: surfaceWhite,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: borderGrey, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryNavy,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryNavy,
          side: const BorderSide(color: borderGrey, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceWhite,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: borderGrey, width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: borderGrey, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: primaryBlue, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: statusDanger, width: 1.2),
        ),
        labelStyle: GoogleFonts.plusJakartaSans(color: slateMuted, fontSize: 13, fontWeight: FontWeight.w500),
        hintStyle: GoogleFonts.plusJakartaSans(color: slateLight, fontSize: 13),
      ),
      dividerTheme: const DividerThemeData(
        color: borderGrey,
        thickness: 1,
        space: 1,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surfaceWhite,
        selectedItemColor: primaryNavy,
        unselectedItemColor: slateMuted,
        selectedLabelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 11),
        unselectedLabelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w500, fontSize: 11),
        elevation: 12,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
