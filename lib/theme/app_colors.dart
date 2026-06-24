import 'package:flutter/material.dart';

/// All design tokens mirroring the CSS custom-property system.
/// Each token has a light and dark variant.
abstract class AppColors {
  AppColors._();

  // ───────────────────────── LIGHT ─────────────────────────

  static const light = _LightColors();

  // ───────────────────────── DARK ──────────────────────────

  static const dark = _DarkColors();

  // ───────────────────────── BLUE ──────────────────────────

  static const blue = _BlueColors();

  // ───────────────────────── SHARED ────────────────────────

  static const Color destructive = Color(0xFFE02424); // 0 72% 51%
  static const Color success = Color(0xFF29A36B); // 160 60% 40%
  static const Color white = Color(0xFFFFFFFF);
}

// ─────────────────────────────────────────────────────────────
//  Token interfaces
// ─────────────────────────────────────────────────────────────

abstract class AppColorTokens {
  Color get background;
  Color get foreground;
  Color get card;
  Color get cardForeground;
  Color get primary;
  Color get primaryForeground;
  Color get primaryGlow;
  Color get secondary;
  Color get secondaryForeground;
  Color get accent;
  Color get accentForeground;
  Color get muted;
  Color get mutedForeground;
  Color get destructive;
  Color get success;
  Color get border;
  Color get ring;
}

// ─────────────────────────────────────────────────────────────
//  Light palette
// ─────────────────────────────────────────────────────────────

class _LightColors implements AppColorTokens {
  const _LightColors();

  @override
  Color get background => const Color(0xFFEDF0F5); // 220 20% 95%
  @override
  Color get foreground => const Color(0xFF101B40); // 222 60% 16%
  @override
  Color get card => const Color(0xFFFFFFFF); // 0 0% 100%
  @override
  Color get cardForeground => const Color(0xFF263366);
  @override
  Color get primary => const Color(0xFF101B40); // 222 60% 16%
  @override
  Color get primaryForeground => const Color(0xFFEDF0F5); // 220 20% 95%
  @override
  Color get primaryGlow => const Color(0xFF00838F); // 222 50% 30%
  @override
  Color get secondary => const Color(0xFF8FA4C1); // 214 30% 66%
  @override
  Color get secondaryForeground => const Color(0xFFFFFFFF);
  @override
  Color get accent => const Color(0xFF00838F); // 184 100% 28%
  @override
  Color get accentForeground => const Color(0xFFFFFFFF);
  @override
  Color get muted => const Color(0xFFE6E9EF); // 216 20% 92%
  @override
  Color get mutedForeground => const Color(0xFF626E82); // 215 15% 45%
  @override
  Color get destructive => AppColors.destructive;
  @override
  Color get success => AppColors.success;
  @override
  Color get border => const Color(0xFFD8DCE5); // 216 20% 88%
  @override
  Color get ring => const Color(0xFF00838F); // 184 100% 28%
}

// ─────────────────────────────────────────────────────────────
//  Blue palette
// ─────────────────────────────────────────────────────────────

class _BlueColors implements AppColorTokens {
  const _BlueColors();

  @override
  Color get background => const Color(0xFF0A122B); // 222 60% 16%
  @override
  Color get foreground => const Color(0xFFEDF0F5); // flipped
  @override
  Color get card => const Color(0xFF1A2850); // 222 50% 20%
  @override
  Color get cardForeground => const Color(0xFFEDF0F5);
  @override
  Color get primary => const Color(0xFF00A3A3); // 184 100% 32%
  @override
  Color get primaryForeground => const Color(0xFF101B40);
  @override
  Color get primaryGlow => const Color(0xFF17B8B8); // 184 80% 45%
  @override
  Color get secondary => const Color(0xFF6E89AD); // 214 30% 55%
  @override
  Color get secondaryForeground => const Color(0xFFFFFFFF);
  @override
  Color get accent => const Color(0xFF00C2C2); // 184 100% 38%
  @override
  Color get accentForeground => const Color(0xFF101B40);
  @override
  Color get muted => const Color(0xFF1F2D52); // 222 45% 22%
  @override
  Color get mutedForeground => const Color(0xFF8A9BB8); // ≈215 22% 63%
  @override
  Color get destructive => AppColors.destructive;
  @override
  Color get success => AppColors.success;
  @override
  Color get border => const Color(0xFF26365C); // 222 40% 25%
  @override
  Color get ring => const Color(0xFF00C2C2); // matches accent
}

// ─────────────────────────────────────────────────────────────
//  Dark palette
// ─────────────────────────────────────────────────────────────

class _DarkColors implements AppColorTokens {
  const _DarkColors();

  // 🌑 Base
  @override
  Color get background => const Color(0xFF0F172A); // deep neutral blue-gray
  @override
  Color get foreground => const Color(0xFFE6EAF2);

  // 🪟 Surfaces
  @override
  Color get card => const Color(0xFF161F3D);
  @override
  Color get cardForeground => const Color(0xFFE6EAF2);

  // 🔵 Brand (kept but tuned for dark)
  @override
  Color get primary => const Color(0xFF00B3B3); // softer than blue mode
  @override
  Color get primaryForeground => const Color(0xFF0F172A);
  @override
  Color get primaryGlow => const Color(0xFF19CACA);

  // ⚙️ Secondary system
  @override
  Color get secondary => const Color(0xFF7C92B3);
  @override
  Color get secondaryForeground => const Color(0xFFFFFFFF);

  // ✨ Accent (slightly brighter for dark contrast)
  @override
  Color get accent => const Color(0xFF00C2C2);
  @override
  Color get accentForeground => const Color(0xFF0F172A);

  // 🌫️ Muted layers
  @override
  Color get muted => const Color(0xFF1B2545);
  @override
  Color get mutedForeground => const Color(0xFF9AA7BD);

  // ⚠️ Status
  @override
  Color get destructive => AppColors.destructive;
  @override
  Color get success => AppColors.success;

  // 📏 Structure
  @override
  Color get border => const Color(0xFF26314F);
  @override
  Color get ring => const Color(0xFF00C2C2);
}
