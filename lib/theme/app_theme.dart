import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const Color dark = Color(0xFF292826);
  static const Color dark2 = Color(0xFF33312E);
  static const Color dark3 = Color(0xFF3D3A35);
  static const Color gold = Color(0xFFF2BA1D);
  static const Color gold2 = Color(0xFFF2BA1D);
  static const Color gold3 = Color(0xFFFEF8E8);
  static const Color white = Color(0xFFFFFFFF);
  static const Color bg = Color(0xFFF7F8FA);
  static const Color text = Color(0xFF292826);
  static const Color muted = Color(0xFF667085);
  static const Color border = Color(0xFFE5E7EB);
  static const Color green = Color(0xFF22A855);
  static const Color red = Color(0xFFE84040);
  static const Color blue = Color(0xFF5563DE);
}

class AppTheme {
  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary: AppColors.gold,
        secondary: AppColors.gold2,
        surface: AppColors.white,
        error: AppColors.red,
      ),
      scaffoldBackgroundColor: AppColors.bg,
      textTheme: GoogleFonts.tajawalTextTheme().apply(
        bodyColor: AppColors.text,
        displayColor: AppColors.text,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.dark,
        foregroundColor: AppColors.white,
        titleTextStyle: GoogleFonts.tajawal(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: AppColors.white,
        ),
        elevation: 0,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.dark,
        selectedItemColor: AppColors.gold2,
        unselectedItemColor: Color(0x59FFFFFF),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.bg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.gold, width: 1.5),
        ),
        hintStyle: GoogleFonts.tajawal(color: AppColors.muted, fontSize: 13),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.gold,
          foregroundColor: AppColors.white,
          textStyle: GoogleFonts.tajawal(fontWeight: FontWeight.w800, fontSize: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(vertical: 13),
        ),
      ),
    );
  }
}
