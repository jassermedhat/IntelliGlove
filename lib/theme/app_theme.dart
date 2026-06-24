import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  // ── Quick access ──
  static ThemeData get light => _build(AppColors.light);
  static ThemeData get dark => _build(AppColors.dark);

  /// Resolve tokens at runtime (e.g. from provider)
  static ThemeData fromMode(ThemeMode mode) =>
      mode == ThemeMode.dark ? dark : light;

  // ─────────────────────────────────────────────
  //  Builder
  // ─────────────────────────────────────────────
  static ThemeData _build(AppColorTokens t) {
    final isDark = t == AppColors.dark;

    final colorScheme = ColorScheme(
      brightness: isDark ? Brightness.dark : Brightness.light,

      // Primary
      primary: t.primary,
      onPrimary: t.primaryForeground,
      primaryContainer: t.primaryGlow,
      onPrimaryContainer: t.primaryForeground,

      // Secondary
      secondary: t.secondary,
      onSecondary: t.secondaryForeground,
      secondaryContainer: t.secondary.withValues(alpha: 0.15),
      onSecondaryContainer: t.foreground,

      // Tertiary → maps to accent
      tertiary: t.accent,
      onTertiary: t.accentForeground,
      tertiaryContainer: t.accent.withValues(alpha: 0.15),
      onTertiaryContainer: t.foreground,

      // Error / destructive
      error: t.destructive,
      onError: AppColors.white,
      errorContainer: t.destructive.withValues(alpha: 0.15),
      onErrorContainer: t.destructive,

      // Surfaces
      surface: t.card,
      onSurface: t.foreground,
      surfaceContainerHighest: t.muted,
      onSurfaceVariant: t.mutedForeground,

      // Outline / border
      outline: t.border,
      outlineVariant: t.border.withValues(alpha: 0.5),

      // Misc
      shadow: Colors.black.withValues(alpha: isDark ? 0.4 : 0.06),
      inverseSurface: isDark ? AppColors.light.card : AppColors.dark.card,
      onInverseSurface: isDark
          ? AppColors.light.foreground
          : AppColors.dark.foreground,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: colorScheme.brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: t.background,

      // ── AppBar ──
      appBarTheme: AppBarTheme(
        backgroundColor: t.card,
        foregroundColor: t.foreground,
        elevation: 0,
        scrolledUnderElevation: isDark ? 0 : 1,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: t.foreground,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),

      // ── Card ──
      cardTheme: CardThemeData(
        color: t.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: t.border, width: 1),
        ),
      ),

      // ── Elevated Button (primary) ──
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: t.primary,
          foregroundColor: t.primaryForeground,
          elevation: 0,
          shadowColor: t.primaryGlow.withValues(alpha: 0.4),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),

      // ── Outlined Button ──
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: t.accent,
          side: BorderSide(color: t.accent.withValues(alpha: 0.5)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),

      // ── Text Button ──
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: t.accent,
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),

      // ── FAB ──
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: t.accent,
        foregroundColor: t.accentForeground,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      // ── Input ──
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: t.muted,
        hintStyle: TextStyle(color: t.mutedForeground),
        labelStyle: TextStyle(color: t.mutedForeground),
        prefixIconColor: t.mutedForeground,
        suffixIconColor: t.mutedForeground,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: t.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: t.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: t.ring, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: t.destructive),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: t.destructive, width: 2),
        ),
      ),

      // ── Chip ──
      chipTheme: ChipThemeData(
        backgroundColor: t.muted,
        labelStyle: TextStyle(color: t.foreground, fontSize: 13),
        side: BorderSide(color: t.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        selectedColor: t.accent.withValues(alpha: 0.15),
        secondaryLabelStyle: TextStyle(color: t.accent),
      ),

      // ── Bottom Nav ──
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: t.card,
        selectedItemColor: t.accent,
        unselectedItemColor: t.mutedForeground,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),

      // ── Navigation Bar (M3) ──
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: t.card,
        indicatorColor: t.accent.withValues(alpha: 0.15),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: t.accent);
          }
          return IconThemeData(color: t.mutedForeground);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              color: t.accent,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            );
          }
          return TextStyle(color: t.mutedForeground, fontSize: 12);
        }),
        surfaceTintColor: Colors.transparent,
      ),

      // ── Divider ──
      dividerTheme: DividerThemeData(color: t.border, thickness: 1, space: 1),

      // ── Dialog ──
      dialogTheme: DialogThemeData(
        backgroundColor: t.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: t.border),
        ),
        titleTextStyle: TextStyle(
          color: t.foreground,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),

      // ── Bottom Sheet ──
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: t.card,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),

      // ── Snackbar ──
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? AppColors.light.card : AppColors.dark.card,
        contentTextStyle: TextStyle(
          color: isDark
              ? AppColors.light.foreground
              : AppColors.dark.foreground,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),

      // ── Switch ──
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return t.accent;
          return t.mutedForeground;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return t.accent.withValues(alpha: 0.3);
          }
          return t.muted;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.transparent;
          return t.border;
        }),
      ),

      // ── Checkbox ──
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return t.accent;
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(t.accentForeground),
        side: BorderSide(color: t.border, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),

      // ── Radio ──
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return t.accent;
          return t.mutedForeground;
        }),
      ),

      // ── Progress Indicator ──
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: t.accent,
        linearTrackColor: t.muted,
        circularTrackColor: t.muted,
      ),

      // ── Tooltip ──
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF26365C) : const Color(0xFF101B40),
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(color: Color(0xFFEDF0F5), fontSize: 12),
      ),

      // ── Icon ──
      iconTheme: IconThemeData(color: t.foreground, size: 22),

      // ── Text ──
      textTheme: _textTheme(t),
    );
  }

  // ─────────────────────────────────────────────
  //  Typography
  // ─────────────────────────────────────────────
  static TextTheme _textTheme(AppColorTokens t) => TextTheme(
    displayLarge: TextStyle(color: t.foreground, fontWeight: FontWeight.w700),
    displayMedium: TextStyle(color: t.foreground, fontWeight: FontWeight.w700),
    displaySmall: TextStyle(color: t.foreground, fontWeight: FontWeight.w700),
    headlineLarge: TextStyle(color: t.foreground, fontWeight: FontWeight.w700),
    headlineMedium: TextStyle(color: t.foreground, fontWeight: FontWeight.w600),
    headlineSmall: TextStyle(color: t.foreground, fontWeight: FontWeight.w600),
    titleLarge: TextStyle(color: t.foreground, fontWeight: FontWeight.w600),
    titleMedium: TextStyle(color: t.foreground, fontWeight: FontWeight.w500),
    titleSmall: TextStyle(color: t.foreground, fontWeight: FontWeight.w500),
    bodyLarge: TextStyle(color: t.foreground),
    bodyMedium: TextStyle(color: t.foreground),
    bodySmall: TextStyle(color: t.mutedForeground),
    labelLarge: TextStyle(color: t.foreground, fontWeight: FontWeight.w600),
    labelMedium: TextStyle(
      color: t.mutedForeground,
      fontWeight: FontWeight.w500,
    ),
    labelSmall: TextStyle(color: t.mutedForeground),
  );
}
