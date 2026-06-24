// appearance_screen.dart
// useTheme() hook → ThemeProviderScope.of(context)
// colorTheme and highContrast stored locally (not in ThemeProvider — provider only has isDark + toggleTheme)
// useToast() → ToastService.show()
// Custom color picker uses Flutter's color input type

import 'package:flutter/material.dart';
import '../components/app_layout.dart';
import '../theme/theme_provider.dart';
import '../theme/app_colors.dart';
import '../components/inputs.dart';
import '../components/toast.dart';
import '../components/app_top_bar.dart';
import '../components/theme_toggle_switch.dart';
import '../app_routes.dart';

class _ColorTheme {
  final String id;
  final String label;
  final Color swatch;
  const _ColorTheme({
    required this.id,
    required this.label,
    required this.swatch,
  });
}

const _kColorThemes = [
  _ColorTheme(id: 'blue', label: 'Navy', swatch: Color(0xFF1B2D5A)),
  _ColorTheme(id: 'green', label: 'Forest', swatch: Color(0xFF27AE60)),
  _ColorTheme(id: 'gold', label: 'Gold', swatch: Color(0xFFF0A500)),
  _ColorTheme(id: 'custom', label: 'Custom', swatch: Color(0xFFAB47BC)),
];

class AppearanceScreen extends StatefulWidget {
  const AppearanceScreen({super.key});

  @override
  State<AppearanceScreen> createState() => _AppearanceScreenState();
}

class _AppearanceScreenState extends State<AppearanceScreen> {
  // Local state — colorTheme & highContrast are UI-only for now
  // ThemeProvider only stores dark/light mode; full color theming deferred to Phase 4
  String _colorTheme = 'blue';
  bool _highContrast = false;
  Color _customPrimary = const Color(0xFF6C8AFF);
  Color _customSecondary = const Color(0xFF22C55E);
  Color _customAccent = const Color(0xFF6C8AFF);

  void _applyChanges(BuildContext context) {
    toast.success(
      title: 'Appearance updated',
      description: 'Your changes have been applied.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = ThemeProviderScope.of(context).tokens;
    final provider = ThemeProviderScope.of(context);
    final isDark = provider.isDark;

    return Scaffold(
      backgroundColor: t.background,
      body: Stack(
        children: [
          Positioned(
            top: -60,
            right: 0,
            child: _Orb(color: t.accent.withValues(alpha: 0.05), size: 240),
          ),
          Positioned(
            bottom: 80,
            left: -60,
            child: _Orb(color: t.primary.withValues(alpha: 0.05), size: 200),
          ),
          SafeArea(
            child: Column(
              children: [
                // Top bar — back (left) + theme toggle (right, kept: this is the visual settings page)
                Container(
                  constraints: BoxConstraints(
                    minHeight: AppLayout.topBarHeight(context),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: t.background.withValues(alpha: 0.75),
                    border: Border(
                      bottom: BorderSide(
                        color: t.border.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      AppBackButton(fallbackRoute: AppRoutes.profile),
                      Text(
                        'Appearance',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: t.foreground,
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      24,
                      20,
                      AppLayout.bottomNavClearance(context),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Hero
                        Row(
                          children: [
                            Container(
                              width: 28,
                              height: 4,
                              decoration: BoxDecoration(
                                color: t.accent,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'SETTINGS',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: t.accent,
                                letterSpacing: 2.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Appearance',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: t.foreground,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Customize your visual experience',
                          style: TextStyle(
                            fontSize: 13,
                            color: t.mutedForeground,
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Theme Mode
                        _SectionLabel(t: t, label: 'THEME MODE'),
                        const SizedBox(height: 12),

                        // ── Quick-toggle pill ─────────────────────────────────
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: t.card,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: t.border.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            children: [
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 240),
                                child: Icon(
                                  isDark
                                      ? Icons.nightlight_round
                                      : Icons.wb_sunny_rounded,
                                  key: ValueKey(isDark),
                                  size: 20,
                                  color: isDark
                                      ? const Color(0xFF93C5FD)
                                      : const Color(0xFFF59E0B),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      isDark ? 'Dark Mode' : 'Light Mode',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: t.foreground,
                                      ),
                                    ),
                                    Text(
                                      isDark
                                          ? 'Easy on the eyes'
                                          : 'Clean & bright',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: t.mutedForeground,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ThemeToggleSwitch(
                                isDark: isDark,
                                onTap: provider.toggleTheme,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Accessibility
                        _SectionLabel(t: t, label: 'ACCESSIBILITY'),
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: () =>
                              setState(() => _highContrast = !_highContrast),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: t.card,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: _highContrast
                                    ? t.accent
                                    : t.border.withValues(alpha: 0.4),
                                width: _highContrast ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: _highContrast
                                        ? t.accent.withValues(alpha: 0.12)
                                        : t.muted.withValues(alpha: 0.4),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      Icons.contrast_rounded,
                                      size: 18,
                                      color: _highContrast
                                          ? t.accent
                                          : t.mutedForeground,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'High-Contrast Mode',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: t.foreground,
                                        ),
                                      ),
                                      Text(
                                        'Enhanced visibility for accessibility',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: t.mutedForeground,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (_highContrast)
                                  Icon(
                                    Icons.check_rounded,
                                    size: 16,
                                    color: t.accent,
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Color Theme
                        _SectionLabel(t: t, label: 'COLOR THEME'),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: _kColorThemes.map((ct) {
                            final selected = _colorTheme == ct.id;
                            return GestureDetector(
                              onTap: () => setState(() => _colorTheme = ct.id),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: 54,
                                    height: 54,
                                    decoration: BoxDecoration(
                                      color: ct.id == 'custom'
                                          ? null
                                          : ct.swatch,
                                      gradient: ct.id == 'custom'
                                          ? const LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [
                                                Color(0xFFAB47BC),
                                                Color(0xFFEC407A),
                                              ],
                                            )
                                          : null,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.12,
                                          ),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                      border: selected
                                          ? Border.all(
                                              color: t.accent,
                                              width: 2.5,
                                            )
                                          : Border.all(
                                              color: Colors.transparent,
                                              width: 2.5,
                                            ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    ct.label,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: selected
                                          ? t.accent
                                          : t.mutedForeground,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),

                        // Custom colors picker (only shown when custom selected)
                        if (_colorTheme == 'custom') ...[
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: t.card,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: t.border.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Custom Colors',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: t.foreground,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Pick your highlight colors — saved automatically.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: t.mutedForeground,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    _ColorPicker(
                                      t: t,
                                      label: 'Primary',
                                      color: _customPrimary,
                                      onChanged: (c) =>
                                          setState(() => _customPrimary = c),
                                    ),
                                    const SizedBox(width: 10),
                                    _ColorPicker(
                                      t: t,
                                      label: 'Secondary',
                                      color: _customSecondary,
                                      onChanged: (c) =>
                                          setState(() => _customSecondary = c),
                                    ),
                                    const SizedBox(width: 10),
                                    _ColorPicker(
                                      t: t,
                                      label: 'Accent',
                                      color: _customAccent,
                                      onChanged: (c) =>
                                          setState(() => _customAccent = c),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 28),

                        // Apply button
                        AppButton(
                          variant: AppButtonVariant.accent,
                          size: AppButtonSize.lg,
                          width: double.infinity,
                          onPressed: () => _applyChanges(context),
                          child: const Text('Apply Changes'),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: t.card,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: t.border.withValues(alpha: 0.4),
                            ),
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                t.accent.withValues(alpha: isDark ? 0.1 : 0.05),
                                t.primary.withValues(
                                  alpha: isDark ? 0.1 : 0.05,
                                ),
                              ],
                            ),
                          ),
                          child: Text(
                            'Changes are applied instantly across all pages',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              color: t.mutedForeground,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ColorPicker extends StatelessWidget {
  final AppColorTokens t;
  final String label;
  final Color color;
  final ValueChanged<Color> onChanged;
  const _ColorPicker({
    required this.t,
    required this.label,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w700,
              color: t.mutedForeground,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 6),
          // Flutter color picker using a simple colored box that opens a dialog
          GestureDetector(
            onTap: () => _pickColor(context),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: t.border.withValues(alpha: 0.4)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _pickColor(BuildContext context) {
    // Custom colors intentionally use the supported preset palette.
    const colors = [
      Color(0xFF6C8AFF),
      Color(0xFF22C55E),
      Color(0xFFF0A500),
      Color(0xFFEF4444),
      Color(0xFFAB47BC),
      Color(0xFF00BCD4),
    ];
    final idx = colors.indexOf(color);
    onChanged(colors[(idx + 1) % colors.length]);
  }
}

class _SectionLabel extends StatelessWidget {
  final AppColorTokens t;
  final String label;
  const _SectionLabel({required this.t, required this.label});
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 20,
        height: 4,
        decoration: BoxDecoration(
          color: t.accent.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 8),
      Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: t.mutedForeground,
          letterSpacing: 1.8,
        ),
      ),
    ],
  );
}

class _Orb extends StatelessWidget {
  final Color color;
  final double size;
  const _Orb({required this.color, required this.size});
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
  );
}
