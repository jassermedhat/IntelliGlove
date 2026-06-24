// feature_card.dart

import 'package:flutter/material.dart';
import '../theme/theme_provider.dart'; // adjust path

/// A tappable card with icon, title, description, and chevron.
/// Mirrors the React `FeatureCard` component.
class FeatureCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;
  final BoxDecoration? iconDecoration;
  final EdgeInsetsGeometry? margin;

  const FeatureCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
    this.iconDecoration,
    this.margin,
  });

  @override
  State<FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<FeatureCard> {
  bool _pressed = false;

  void _handleDown(TapDownDetails _) => setState(() => _pressed = true);
  void _handleUp([_]) => setState(() => _pressed = false);

  @override
  Widget build(BuildContext context) {
    final t = ThemeProviderScope.of(context).tokens;

    // Default gradient mimics `gradient-primary`
    final iconDeco =
        widget.iconDecoration ??
        BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [t.primary, t.primaryGlow],
          ),
          boxShadow: [
            BoxShadow(
              color: t.primaryGlow.withValues(alpha: _pressed ? 0.5 : 0.3),
              blurRadius: _pressed ? 12 : 8,
              offset: const Offset(0, 3),
            ),
          ],
        );

    return Padding(
      padding: widget.margin ?? EdgeInsets.zero,
      child: GestureDetector(
        onTapDown: _handleDown,
        onTapUp: (_) {
          _handleUp();
          widget.onTap();
        },
        onTapCancel: _handleUp,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(0, _pressed ? -2 : 0, 0),
          decoration: BoxDecoration(
            color: t.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _pressed
                  ? t.accent.withValues(alpha: 0.2)
                  : t.border.withValues(alpha: 0.5),
            ),
            boxShadow: [
              BoxShadow(
                color: _pressed
                    ? Colors.black.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.03),
                blurRadius: _pressed ? 16 : 4,
                offset: Offset(0, _pressed ? 6 : 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // ── Icon box ──
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 48,
                  height: 48,
                  decoration: iconDeco,
                  child: Center(
                    child: Icon(widget.icon, size: 22, color: Colors.white),
                  ),
                ),

                const SizedBox(width: 16),

                // ── Text ──
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 300),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _pressed ? t.accent : t.foreground,
                        ),
                        child: Text(
                          widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: t.mutedForeground,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // ── Chevron ──
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                  transform: Matrix4.translationValues(_pressed ? 2 : 0, 0, 0),
                  child: AnimatedTheme(
                    duration: const Duration(milliseconds: 300),
                    data: Theme.of(context).copyWith(
                      iconTheme: IconThemeData(
                        color: _pressed ? t.accent : t.mutedForeground,
                      ),
                    ),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: _pressed ? t.accent : t.mutedForeground,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
