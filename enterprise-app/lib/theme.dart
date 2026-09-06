import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Ilova rang tizimi (prompt spec — aniq qiymatlar).
/// Brend/funksional ranglar ikkala rejimda ham bir xil; faqat fon va matn
/// (surface/ink) light↔dark o'zgaradi.
class AppColors {
  // --- Brend / funksional (ikkala rejimda bir xil) ---
  static const brandPurple = Color(0xFF7C3AED); // brend / vocabulary
  static const actionBlue = Color(0xFF2563EB); // harakat tugmalari (blue-600)
  static const success = Color(0xFF16A34A); // to'g'ri javob (yashil)
  static const homework = Color(0xFFEA580C); // homework / leaderboard (to'q sariq)
  static const coin = Color(0xFFF59E0B); // tanga (sariq)
  static const danger = Color(0xFFDC2626); // xato

  // --- Light rejim ---
  static const lightBg = Color(0xFFF5F6FA);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightHeading = Color(0xFF28004D); // to'q binafsha sarlavha
  static const lightInk = Color(0xFF1F2430); // asosiy matn
  static const lightMuted = Color(0xFF6B7280); // ikkilamchi matn
  static const neutralShadow = Color(0xFFC9CDE3); // neomorfik soya / border

  // --- Dark rejim ---
  static const darkBg = Color(0xFF25272D);
  static const darkSurface = Color(0xFF2F3138);
  static const darkHeading = Color(0xFFC4B5FD); // dark fonda och binafsha
  static const darkInk = Color(0xFFE8E9ED);
  static const darkMuted = Color(0xFF9AA0AC);
  static const darkShadow = Color(0xFF1A1B20);

  /// IKKILAMChI MATN — rejimga qarab tanlanadi.
  ///
  /// Ilgari ekranlarda to'g'ridan-to'g'ri `lightMuted` yozilgan edi va u
  /// TUNGI rejimda ham ishlatilardi: kontrast atigi 2.69:1 chiqardi
  /// (WCAG AA me'yori — 4.5:1), ya'ni izohlar, bet yorliqlari va yordam
  /// matnlari deyarli o'qilmasdi. `darkMuted` bilan 4.95:1 bo'ladi.
  static Color muted(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkMuted : lightMuted;
}

/// Burchak radiuslari (dizayn tokenlari).
class AppRadius {
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const pill = 9999.0;
}

class AppTheme {
  /// Geist shrifti (OFL, bepul). google_fonts'da bo'lmasa — Inter'ga tushadi
  /// (Geist'ga vizual eng yaqin, doim mavjud). Ilova baribir ishlaydi.
  static TextTheme _geist(TextTheme base) {
    try {
      return GoogleFonts.getTextTheme('Geist', base);
    } catch (_) {
      return GoogleFonts.interTextTheme(base);
    }
  }

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness b) {
    final isLight = b == Brightness.light;
    final bg = isLight ? AppColors.lightBg : AppColors.darkBg;
    final surface = isLight ? AppColors.lightSurface : AppColors.darkSurface;
    final ink = isLight ? AppColors.lightInk : AppColors.darkInk;
    final heading = isLight ? AppColors.lightHeading : AppColors.darkHeading;

    final base = ThemeData(
      brightness: b,
      useMaterial3: true,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.brandPurple,
        brightness: b,
        primary: AppColors.actionBlue,
        secondary: AppColors.brandPurple,
        surface: surface,
      ),
    );

    return base.copyWith(
      textTheme: _geist(base.textTheme).apply(
        bodyColor: ink,
        displayColor: heading,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: heading,
        centerTitle: false,
      ),
      // Barcha sahifa o'tishlari — silliq zoom-fade (Material 3).
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: ZoomPageTransitionsBuilder(),
          TargetPlatform.macOS: ZoomPageTransitionsBuilder(),
          TargetPlatform.windows: ZoomPageTransitionsBuilder(),
          TargetPlatform.linux: ZoomPageTransitionsBuilder(),
        },
      ),
    );
  }

  /// Sarlavha uslubi (24px / 700).
  static TextStyle heading(BuildContext c) => TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: Theme.of(c).brightness == Brightness.light
            ? AppColors.lightHeading
            : AppColors.darkHeading,
      );

  /// Body uslubi (16px / 400).
  static TextStyle body(BuildContext c) => TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: Theme.of(c).brightness == Brightness.light
            ? AppColors.lightInk
            : AppColors.darkInk,
      );
}
