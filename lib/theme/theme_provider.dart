import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme.dart';
import 'app_colors.dart';

// ─────────────────────────────────────────────
//  Storage key
// ─────────────────────────────────────────────
const _kMode = 'app-theme-mode';

// ─────────────────────────────────────────────
//  Provider
// ─────────────────────────────────────────────
class ThemeProvider extends ChangeNotifier {
  ThemeMode _mode;

  ThemeProvider({ThemeMode mode = ThemeMode.light}) : _mode = mode;

  // ── Getters ──

  ThemeMode get themeMode => _mode;
  bool get isDark => _mode == ThemeMode.dark;

  ThemeData get lightTheme => AppTheme.light;
  ThemeData get darkTheme => AppTheme.dark;

  /// Convenience: returns the active token set.
  AppColorTokens get tokens => isDark ? AppColors.dark : AppColors.light;

  // ── Setters ──

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    prefs.setString(_kMode, mode == ThemeMode.dark ? 'dark' : 'light');
  }

  void toggleTheme() => setThemeMode(isDark ? ThemeMode.light : ThemeMode.dark);

  // ── Load from disk ──

  static Future<ThemeProvider> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_kMode);
    final mode = stored == 'dark' ? ThemeMode.dark : ThemeMode.light;
    return ThemeProvider(mode: mode);
  }
}

// ─────────────────────────────────────────────
//  Theme Toggle Widget
// ─────────────────────────────────────────────

/// Animated pill toggle that mirrors the React `<ThemeToggle />`.
class ThemeToggle extends StatelessWidget {
  final double width;
  final double height;

  const ThemeToggle({super.key, this.width = 56, this.height = 32});

  @override
  Widget build(BuildContext context) {
    // Grab provider via inherited widget lookup
    final provider = _of(context);
    final isDark = provider.isDark;
    final t = provider.tokens;

    final knobSize = height - 8; // 4px padding each side

    return Semantics(
      label: 'Toggle theme',
      toggled: isDark,
      child: GestureDetector(
        onTap: provider.toggleTheme,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOut,
          width: width,
          height: height,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(height / 2),
            color: isDark ? t.accent.withValues(alpha: 0.20) : t.muted,
            border: Border.all(
              color: isDark ? t.accent.withValues(alpha: 0.30) : t.border,
              width: 1,
            ),
          ),
          child: Stack(
            children: [
              AnimatedAlign(
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOut,
                alignment: isDark
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOut,
                  width: knobSize,
                  height: knobSize,
                  decoration: BoxDecoration(
                    color: isDark ? t.accent : t.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (isDark ? t.accent : t.primaryGlow).withValues(
                          alpha: 0.45,
                        ),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, anim) => RotationTransition(
                      turns: Tween(begin: 0.75, end: 1.0).animate(anim),
                      child: FadeTransition(opacity: anim, child: child),
                    ),
                    child: Icon(
                      isDark ? Icons.nightlight_round : Icons.wb_sunny_rounded,
                      key: ValueKey(isDark),
                      size: knobSize * 0.5,
                      color: isDark ? t.accentForeground : t.primaryForeground,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Looks up the nearest [ThemeProvider] using [Provider] or a manual
  /// [InheritedWidget]. Below uses the `provider` package.
  static ThemeProvider _of(BuildContext context) {
    final notifier = context
        .dependOnInheritedWidgetOfExactType<_ThemeProviderScope>()
        ?.notifier;
    if (notifier == null) {
      throw FlutterError(
        'ThemeToggle requires a ThemeProvider above it in the widget tree.\n'
        'Wrap your app with ThemeProviderScope.',
      );
    }
    return notifier;
  }
}

// ─────────────────────────────────────────────
//  Lightweight InheritedNotifier (no 3rd-party dep)
// ─────────────────────────────────────────────

/// Wraps the entire app so descendants can look up [ThemeProvider].
///
/// ```dart
/// ThemeProviderScope(
///   notifier: themeProvider,
///   child: MaterialApp(...),
/// )
/// ```
class ThemeProviderScope extends InheritedNotifier<ThemeProvider> {
  const ThemeProviderScope({
    super.key,
    required ThemeProvider super.notifier,
    required super.child,
  });

  /// Convenience accessor from any widget.
  static ThemeProvider of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<ThemeProviderScope>();
    final notifier = scope?.notifier;
    if (notifier == null) {
      throw FlutterError(
        'ThemeProviderScope.of() called without a ThemeProviderScope above the context.',
      );
    }
    return notifier;
  }
}

// Private typedef so ThemeToggle._of works
typedef _ThemeProviderScope = ThemeProviderScope;
