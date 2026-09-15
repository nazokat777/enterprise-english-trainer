import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// DIZAYN TIZIMI — "Enterprise" brendi.
///
/// 2026-09-15 "WOW" yangilanishi. Tamoyillar:
///  * Bitta kuchli brend gradienti (binafsha -> indigo -> moviy) va
///    unga qarshi iliq accent (sariq/olov) — ranglar "gapiradi".
///  * Havodor bo'shliq, katta radiuslar (16/20/28), yumshoq ko'p qatlamli
///    soyalar — "plastik" emas, "shisha va qog'oz".
///  * Tipografika: Manrope (geometrik, zamonaviy) sarlavhalar, Inter
///    matn — ikkalasi Google Fonts, OFL.
///  * Tungi rejim chin qora emas, chuqur ko'k-qora (#0F1117) + ko'tarilgan
///    yuzalar — kontrast WCAG AA.
class AppColors {
  // --- Brend / funksional (ikkala rejimda bir xil) ---
  static const brandPurple = Color(0xFF7C3AED); // brend / vocabulary
  static const brandIndigo = Color(0xFF4F46E5);
  static const brandCyan = Color(0xFF06B6D4);
  static const actionBlue = Color(0xFF2563EB); // harakat tugmalari
  static const success = Color(0xFF16A34A); // to'g'ri javob (yashil)
  static const homework = Color(0xFFEA580C); // homework / olov (to'q sariq)
  static const coin = Color(0xFFF59E0B); // tanga (sariq)
  static const danger = Color(0xFFDC2626); // xato
  static const pink = Color(0xFFEC4899);

  /// Brend gradienti — hero, faol menyu, daraja halqasi.
  static const brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF7C3AED), Color(0xFF4F46E5), Color(0xFF0EA5E9)],
  );

  /// Iliq "yutuq" gradienti — sandiq, rekord, imtihon.
  static const goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF59E0B), Color(0xFFF97316), Color(0xFFEC4899)],
  );

  /// Yashil "muvaffaqiyat" gradienti.
  static const successGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF22C55E), Color(0xFF16A34A), Color(0xFF0D9488)],
  );

  // --- Light rejim ---
  static const lightBg = Color(0xFFF3F4FA);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightHeading = Color(0xFF1E1B4B); // chuqur indigo sarlavha
  static const lightInk = Color(0xFF1F2430); // asosiy matn
  static const lightMuted = Color(0xFF64748B); // ikkilamchi matn
  static const neutralShadow = Color(0xFFC9CDE3); // 3D tugma soyasi / border
  static const lightBorder = Color(0xFFE6E8F2);

  // --- Dark rejim ---
  static const darkBg = Color(0xFF0F1117);
  static const darkSurface = Color(0xFF1A1D27);
  static const darkSurface2 = Color(0xFF232736); // ko'tarilgan yuza
  static const darkHeading = Color(0xFFC4B5FD); // dark fonda och binafsha
  static const darkInk = Color(0xFFE8E9ED);
  static const darkMuted = Color(0xFF9AA0AC);
  static const darkShadow = Color(0xFF0A0B10);
  static const darkBorder = Color(0xFF2C3040);

  /// IKKILAMChI MATN — rejimga qarab tanlanadi.
  ///
  /// Tungi rejimda `lightMuted` kontrasti 2.69:1 chiqardi (WCAG AA —
  /// 4.5:1); `darkMuted` bilan 4.95:1.
  static Color muted(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkMuted : lightMuted;

  static Color border(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkBorder : lightBorder;

  static Color surface(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkSurface : lightSurface;

  static Color surface2(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkSurface2
          : const Color(0xFFF8F9FE);
}

/// Burchak radiuslari (dizayn tokenlari).
class AppRadius {
  static const sm = 10.0;
  static const md = 14.0;
  static const lg = 20.0;
  static const xl = 28.0;
  static const pill = 9999.0;
}

/// Soyalar — ko'p qatlamli, yumshoq ("ambient + key").
class AppShadow {
  static List<BoxShadow> card(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: dark ? 0.35 : 0.05),
        blurRadius: 18,
        offset: const Offset(0, 8),
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: dark ? 0.2 : 0.03),
        blurRadius: 2,
        offset: const Offset(0, 1),
      ),
    ];
  }

  /// Rangli "nur" — brend elementlar uchun.
  static List<BoxShadow> glow(Color c, {double alpha = 0.35}) => [
        BoxShadow(
          color: c.withValues(alpha: alpha),
          blurRadius: 24,
          spreadRadius: -4,
          offset: const Offset(0, 10),
        ),
      ];
}

class AppTheme {
  /// Sarlavha shrifti — Manrope; matn — Inter. Google Fonts topilmasa
  /// tizim shriftiga tushadi, ilova baribir ishlaydi.
  static TextTheme _fonts(TextTheme base) {
    TextTheme t;
    try {
      t = GoogleFonts.interTextTheme(base);
    } catch (_) {
      t = base;
    }
    TextStyle? head(TextStyle? s, double size, FontWeight w, {double? ls}) {
      if (s == null) return null;
      try {
        return GoogleFonts.manrope(
            textStyle: s, fontSize: size, fontWeight: w, letterSpacing: ls);
      } catch (_) {
        return s.copyWith(fontSize: size, fontWeight: w, letterSpacing: ls);
      }
    }

    return t.copyWith(
      displayLarge: head(t.displayLarge, 44, FontWeight.w800, ls: -1.2),
      displayMedium: head(t.displayMedium, 36, FontWeight.w800, ls: -1),
      displaySmall: head(t.displaySmall, 30, FontWeight.w800, ls: -0.6),
      headlineLarge: head(t.headlineLarge, 28, FontWeight.w800, ls: -0.5),
      headlineMedium: head(t.headlineMedium, 24, FontWeight.w800, ls: -0.4),
      headlineSmall: head(t.headlineSmall, 20, FontWeight.w800, ls: -0.2),
      titleLarge: head(t.titleLarge, 18, FontWeight.w800),
      titleMedium: head(t.titleMedium, 16, FontWeight.w700),
      titleSmall: head(t.titleSmall, 14, FontWeight.w700),
    );
  }

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness b) {
    final isLight = b == Brightness.light;
    final bg = isLight ? AppColors.lightBg : AppColors.darkBg;
    final surface = isLight ? AppColors.lightSurface : AppColors.darkSurface;
    final ink = isLight ? AppColors.lightInk : AppColors.darkInk;
    final heading = isLight ? AppColors.lightHeading : AppColors.darkHeading;
    final border = isLight ? AppColors.lightBorder : AppColors.darkBorder;

    final base = ThemeData(
      brightness: b,
      useMaterial3: true,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.brandPurple,
        brightness: b,
        primary: AppColors.brandPurple,
        secondary: AppColors.brandIndigo,
        tertiary: AppColors.brandCyan,
        surface: surface,
        error: AppColors.danger,
      ),
    );

    final text = _fonts(base.textTheme).apply(
      bodyColor: ink,
      displayColor: heading,
    );

    return base.copyWith(
      textTheme: text,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: heading,
        centerTitle: false,
        titleTextStyle: text.titleLarge?.copyWith(color: heading),
      ),
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: border),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.pill)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.pill)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.pill)),
          side: BorderSide(color: border, width: 1.5),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            side: BorderSide(color: border)),
        side: BorderSide(color: border),
        backgroundColor: surface,
        labelStyle: TextStyle(fontWeight: FontWeight.w700, color: ink),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: BorderSide(color: border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: BorderSide(color: border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: const BorderSide(color: AppColors.brandPurple, width: 2)),
      ),
      sliderTheme: const SliderThemeData(
        trackHeight: 6,
        activeTrackColor: AppColors.brandPurple,
        thumbColor: AppColors.brandPurple,
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1),
      // Sahifa o'tishlari — silliq zoom-fade (Material 3).
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

  /// Sarlavha uslubi (24px / 800, Manrope).
  static TextStyle heading(BuildContext c) =>
      (Theme.of(c).textTheme.headlineMedium ??
              const TextStyle(fontSize: 24, fontWeight: FontWeight.w800))
          .copyWith(
        color: Theme.of(c).brightness == Brightness.light
            ? AppColors.lightHeading
            : AppColors.darkHeading,
      );

  /// Katta ko'rgazma uslubi (30px / 800).
  static TextStyle display(BuildContext c) =>
      (Theme.of(c).textTheme.displaySmall ??
              const TextStyle(fontSize: 30, fontWeight: FontWeight.w800))
          .copyWith(
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
