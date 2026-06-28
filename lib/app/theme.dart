import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Centralized theme for PlaySpace. A modern, vibrant, "playful-premium" look
/// built on an indigo/violet brand with soft surfaces, rounded geometry and
/// gentle depth. Supports both light and dark mode.
class AppTheme {
  AppTheme._();

  // Brand palette ------------------------------------------------------------
  static const Color seed = Color(0xFF6D5DF6); // indigo-violet
  static const Color violet = Color(0xFF7C3AED);
  static const Color blue = Color(0xFF3B82F6);
  static const Color pink = Color(0xFFEC4899);
  static const Color flame = Color(0xFFFB7185);
  static const Color amber = Color(0xFFF59E0B);
  static const Color online = Color(0xFF22C55E);

  // Neutral surfaces tuned for each brightness.
  static const Color _darkBg = Color(0xFF0E0F1A);
  static const Color _darkSurface = Color(0xFF15172A);
  static const Color _darkCard = Color(0xFF1C1F36);

  static ThemeData light({Color? seed}) =>
      _build(Brightness.light, seed ?? AppTheme.seed);
  static ThemeData dark({Color? seed}) =>
      _build(Brightness.dark, seed ?? AppTheme.seed);

  static ThemeData _build(Brightness brightness, Color seedColor) {
    final isDark = brightness == Brightness.dark;

    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    ).copyWith(
      surface: isDark ? _darkBg : const Color(0xFFF7F7FB),
      surfaceContainerLowest: isDark ? _darkBg : Colors.white,
      surfaceContainerLow: isDark ? _darkSurface : Colors.white,
      surfaceContainer: isDark ? _darkSurface : const Color(0xFFFFFFFF),
      surfaceContainerHigh: isDark ? _darkCard : const Color(0xFFF0F0F6),
      surfaceContainerHighest: isDark ? _darkCard : const Color(0xFFEAEAF2),
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      splashFactory: InkSparkle.splashFactory,
    );

    final textTheme = GoogleFonts.interTextTheme(base.textTheme).copyWith(
      displaySmall: GoogleFonts.spaceGrotesk(
          textStyle: base.textTheme.displaySmall, fontWeight: FontWeight.w700),
      headlineMedium: GoogleFonts.spaceGrotesk(
          textStyle: base.textTheme.headlineMedium, fontWeight: FontWeight.w700),
      headlineSmall: GoogleFonts.spaceGrotesk(
          textStyle: base.textTheme.headlineSmall, fontWeight: FontWeight.w700),
      titleLarge: GoogleFonts.spaceGrotesk(
          textStyle: base.textTheme.titleLarge, fontWeight: FontWeight.w700),
    );

    final outline = colorScheme.outlineVariant.withValues(alpha: isDark ? 0.5 : 0.7);

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: colorScheme.onSurface,
        ),
        systemOverlayStyle:
            isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withValues(alpha: 0.06),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: outline, width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
      ),
      dividerTheme: DividerThemeData(
        color: outline,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.white,
        prefixIconColor: colorScheme.onSurfaceVariant,
        suffixIconColor: colorScheme.onSurfaceVariant,
        hintStyle: TextStyle(
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7)),
        labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
        floatingLabelStyle: TextStyle(color: colorScheme.primary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: outline, width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: outline, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.error, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.error, width: 1.8),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: GoogleFonts.inter(
              fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.2),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          side: BorderSide(color: outline, width: 1.4),
          foregroundColor: colorScheme.onSurface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: GoogleFonts.inter(
              fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
      ),
      chipTheme: ChipThemeData(
        side: BorderSide(color: outline),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: colorScheme.surfaceContainerHigh,
        labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 70,
        elevation: 0,
        backgroundColor: isDark
            ? _darkSurface.withValues(alpha: 0.96)
            : Colors.white,
        surfaceTintColor: Colors.transparent,
        indicatorColor: colorScheme.primary.withValues(alpha: 0.16),
        indicatorShape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return GoogleFonts.inter(
            fontSize: 11.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
          );
        }),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? _darkCard : const Color(0xFF1F2233),
        contentTextStyle: GoogleFonts.inter(
            color: Colors.white, fontWeight: FontWeight.w500),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.all(16),
      ),
      listTileTheme: const ListTileThemeData(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16))),
      ),
    );
  }
}

/// Brand gradient used for logos, story rings, primary buttons and accents.
const kBrandGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF3B82F6), Color(0xFF7C3AED), Color(0xFFEC4899)],
);

/// Softer two-stop gradient for large background washes.
const kBrandGradientSoft = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF6D5DF6), Color(0xFF9333EA)],
);

/// Convenience helpers on [BuildContext] for terse access to theme tokens.
extension ThemeX on BuildContext {
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get texts => Theme.of(this).textTheme;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}
