import 'package:flutter/material.dart';

/// "Soft Structuralism" theme — warm paper surfaces, deep teal identity,
/// Sora display type + Plus Jakarta Sans body type, soft diffused shadows.
class AppTheme {
  AppTheme._();

  // Identity: deep teal (distinct from default indigo/purple AI look).
  static const _seed = Color(0xFF0B6E62);

  // Warm paper light / soft graphite dark — pure #FFF and #000 never appear.
  static const _bgLight = Color(0xFFF6F5F1);
  static const _bgDark = Color(0xFF121417);

  static const _display = 'Sora';
  static const _body = 'Plus Jakarta Sans';

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(seedColor: _seed, brightness: brightness);
    final isDark = brightness == Brightness.dark;

    final cardColor = isDark ? const Color(0xFF1B1E22) : Colors.white;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark ? _bgDark : _bgLight,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: isDark ? _bgDark : _bgLight,
        foregroundColor: scheme.onSurface,
        titleTextStyle: TextStyle(
          fontFamily: _display,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      ),
      textTheme: _buildTextTheme(scheme.onSurface),
      cardTheme: CardThemeData(
        elevation: 0,
        color: cardColor,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.error, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.error, width: 1.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontFamily: _display, fontSize: 16, fontWeight: FontWeight.w600),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontFamily: _display, fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
        labelStyle: TextStyle(fontFamily: _body, fontSize: 12.5, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        actionTextColor: scheme.primary,
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant.withValues(alpha: 0.5), space: 20),
    );
  }

  /// Display face on headlines/titles for the typographic voice;
  /// body face everywhere else. One scale, no ad-hoc sizes in screens.
  static TextTheme _buildTextTheme(Color onSurface) {
    const display = TextStyle(fontFamily: _display, fontWeight: FontWeight.w700, height: 1.15, letterSpacing: -0.5);
    const body = TextStyle(fontFamily: _body, fontWeight: FontWeight.w400, height: 1.4);
    return TextTheme(
      headlineMedium: display.copyWith(fontSize: 30),
      headlineSmall: display.copyWith(fontSize: 25),
      titleLarge: display.copyWith(fontSize: 20, fontWeight: FontWeight.w600),
      titleMedium: display.copyWith(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0),
      titleSmall: body.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
      bodyLarge: body.copyWith(fontSize: 16),
      bodyMedium: body.copyWith(fontSize: 14),
      bodySmall: body.copyWith(fontSize: 12.5, color: onSurface.withValues(alpha: 0.75)),
      labelLarge: display.copyWith(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0),
      labelSmall: body.copyWith(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.4),
    );
  }

  /// Ambient shadow for custom floating containers (menu tiles, hero areas).
  static List<BoxShadow> floatingShadow(bool isDark) => [
        BoxShadow(
          color: isDark ? Colors.black.withValues(alpha: 0.35) : const Color(0x141A1A1A),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ];
}
