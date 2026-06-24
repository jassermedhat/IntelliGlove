// theme_toggle_switch.dart
// Premium animated pill-shaped theme toggle switch.
// Uses Flutter built-in animation widgets only — no packages.
//
// API:
//   ThemeToggleSwitch(
//     isDark: provider.isDark,
//     onTap:  provider.toggleTheme,
//   )

import 'package:flutter/material.dart';

/// A compact, iOS-style animated pill toggle that switches between
/// light (☀️) and dark (🌙) mode with smooth spring-like motion.
///
/// Dimensions: 56 × 30 px by default.
/// The circular thumb slides left ↔ right, changes color, and
/// cross-fades its icon with a subtle rotation transition.
class ThemeToggleSwitch extends StatelessWidget {
  final bool isDark;
  final VoidCallback onTap;

  /// Pill width.  Default 56.
  final double width;

  /// Pill height.  Default 30.  Thumb is (height − 8).
  final double height;

  const ThemeToggleSwitch({
    super.key,
    required this.isDark,
    required this.onTap,
    this.width = 56,
    this.height = 30,
  });

  // ── Design tokens ──────────────────────────────────────────────────────────

  /// Pill background in light mode: pale blue-grey.
  static const _lightPillBg = Color(0xFFE2E8F2);

  /// Pill background in dark mode: deep navy-blue.
  static const _darkPillBg = Color(0xFF1B2D5A);

  /// Pill border in light mode.
  static const _lightBorder = Color(0xFFCBD5E1);

  /// Pill border in dark mode: accent blue tint.
  static const _darkBorder = Color(0xFF3B5FBB);

  /// Thumb color: crisp white in both modes.
  static const _thumbColor = Colors.white;

  /// Thumb glow in light mode: warm yellow.
  static const _lightGlow = Color(0xFFFBBF24);

  /// Thumb glow in dark mode: blue-violet.
  static const _darkGlow = Color(0xFF6C8AFF);

  /// Sun icon color (light mode).
  static const _sunColor = Color(0xFFF59E0B);

  /// Moon icon color (dark mode).
  static const _moonColor = Color(0xFF93C5FD);

  static const Duration _dur = Duration(milliseconds: 260);
  static const Curve _curve = Curves.easeInOutCubic;

  @override
  Widget build(BuildContext context) {
    // final thumbSize  = height - 8.0;   // 4 px padding on each side
    final padding = 4.0;
    final thumbSize = height - (padding * 2);

    return Semantics(
      label: 'Toggle theme',
      toggled: isDark,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: _dur,
          curve: _curve,
          width: width,
          height: height,
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(height / 2),
            color: isDark ? _darkPillBg : _lightPillBg,
            border: Border.all(
              color: isDark ? _darkBorder : _lightBorder,
              width: 1,
            ),
          ),
          child: AnimatedAlign(
            duration: _dur,
            curve: _curve,
            alignment: isDark ? Alignment.centerRight : Alignment.centerLeft,
            child: AnimatedContainer(
              duration: _dur,
              curve: _curve,
              width: thumbSize,
              height: thumbSize,
              decoration: BoxDecoration(
                color: _thumbColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                  BoxShadow(
                    color: (isDark ? _darkGlow : _lightGlow).withValues(
                      alpha: isDark ? 0.45 : 0.35,
                    ),
                    blurRadius: 8,
                    spreadRadius: -1,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: ScaleTransition(scale: anim, child: child),
                ),
                child: Icon(
                  isDark ? Icons.nightlight_round : Icons.wb_sunny_rounded,
                  key: ValueKey(isDark),
                  size: thumbSize * 0.52,
                  color: isDark ? _moonColor : _sunColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
