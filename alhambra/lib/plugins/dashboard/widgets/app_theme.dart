import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DashboardTheme {
  static const Color primaryBlue = Color(0xFF6C63FF);
  static const Color secondaryPurple = Color(0xFF9D4EDD);
  static const Color accentPink = Color(0xFFFF6B9D);
  static const Color accentCyan = Color(0xFF00D4FF);
  static const Color accentGreen = Color(0xFF00E676);
  static const Color accentOrange = Color(0xFFFF9100);

  static const List<Color> gradientColors = [
    Color(0xFF6C63FF),
    Color(0xFF9D4EDD),
    Color(0xFFFF6B9D),
  ];

  static final TextStyle titleStyle = GoogleFonts.inter(
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
  );

  static final TextStyle subtitleStyle = GoogleFonts.inter(
    fontWeight: FontWeight.w500,
    letterSpacing: -0.2,
  );

  static final TextStyle bodyStyle = GoogleFonts.inter(
    fontWeight: FontWeight.w400,
  );

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: const ColorScheme.light(
      primary: primaryBlue,
      secondary: secondaryPurple,
      tertiary: accentPink,
      surface: Color(0xFFF8F9FE),
    ),
    scaffoldBackgroundColor: const Color(0xFFF0F2FF),
    fontFamily: 'Inter',
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      color: Colors.white.withValues(alpha: 0.7),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: primaryBlue,
      secondary: secondaryPurple,
      tertiary: accentPink,
      surface: Color(0xFF1A1A2E),
    ),
    scaffoldBackgroundColor: const Color(0xFF12121E),
    fontFamily: 'Inter',
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      color: Colors.white.withValues(alpha: 0.05),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
  );
}
