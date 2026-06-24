// glove_visualization.dart

import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/theme_provider.dart'; // adjust path
import '../theme/app_colors.dart'; // adjust path

// ─────────────────────────────────────────────
//  Size enum
// ─────────────────────────────────────────────

enum GloveSize { sm, md, lg, square }
// ─────────────────────────────────────────────
//  GloveVisualization
// ─────────────────────────────────────────────

class GloveVisualization extends StatefulWidget {
  final GloveSize size;
  final bool isActive;

  const GloveVisualization({
    super.key,
    this.size = GloveSize.md,
    this.isActive = false,
  });

  @override
  State<GloveVisualization> createState() => _GloveVisualizationState();
}

class _GloveVisualizationState extends State<GloveVisualization>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final List<double> _barHeights;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    if (widget.isActive) _pulseController.repeat(reverse: true);

    // Pre-generate random bar heights (stable across rebuilds)
    final rng = Random(42);
    _barHeights = List.generate(5, (_) => 12.0 + rng.nextDouble() * 16.0);
  }

  @override
  void didUpdateWidget(covariant GloveVisualization old) {
    super.didUpdateWidget(old);
    if (widget.isActive && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.isActive && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.value = 0;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = ThemeProviderScope.of(context).tokens;
    final isDark = ThemeProviderScope.of(context).isDark;

    return _buildSizedContainer(
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          // Subtle glow pulse when active
          final glowOpacity = widget.isActive
              ? 0.15 + (_pulseController.value * 0.1)
              : 0.0;

          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        t.accent.withValues(alpha: 0.10),
                        t.primary.withValues(alpha: 0.05),
                        t.accent.withValues(alpha: 0.05),
                      ]
                    : [
                        t.primary.withValues(alpha: 0.05),
                        t.accent.withValues(alpha: 0.05),
                        t.primary.withValues(alpha: 0.10),
                      ],
              ),
              boxShadow: widget.isActive
                  ? [
                      BoxShadow(
                        color: t.accent.withValues(alpha: glowOpacity),
                        blurRadius: 24,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            clipBehavior: Clip.antiAlias,
            child: child,
          );
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            // ── Dot pattern ──
            Positioned.fill(
              child: CustomPaint(
                painter: _DotPatternPainter(
                  color: t.foreground.withValues(alpha: 0.03),
                ),
              ),
            ),

            // ── Glow orb ──
            Positioned(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                child: Container(
                  width: 128,
                  height: 128,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: t.accent.withValues(alpha: 0.20),
                  ),
                ),
              ),
            ),

            // ── Icon + bars ──
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Hand icon
                _buildIcon(t),

                // Active bars
                if (widget.isActive) ...[
                  const SizedBox(height: 16),
                  _buildBars(t),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Sized container by GloveSize ──────────────────

  Widget _buildSizedContainer({required Widget child}) {
    switch (widget.size) {
      case GloveSize.sm:
        return SizedBox(width: 64, height: 64, child: child);
      case GloveSize.md:
        return SizedBox(width: 128, height: 128, child: child);
      case GloveSize.lg:
        return AspectRatio(aspectRatio: 16 / 9, child: child);
      case GloveSize.square:
        return AspectRatio(aspectRatio: 1, child: child);
    }
  }

  // ─── Hand icon ─────────────────────────────────────

  Widget _buildIcon(AppColorTokens t) {
    final double iconSize;
    switch (widget.size) {
      case GloveSize.sm:
        iconSize = 32;
        break;
      case GloveSize.md:
        iconSize = 64;
        break;
      case GloveSize.lg:
        iconSize = 96;
        break;
      case GloveSize.square:
        iconSize = 56;
    }

    Widget icon = Icon(
      Icons.back_hand_outlined, // closest to Lucide "Hand"
      size: iconSize,
      color: t.accent,
    );

    // Active glow shadow
    if (widget.isActive) {
      icon = AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: t.accent.withValues(
                    alpha: 0.25 + _pulseController.value * 0.15,
                  ),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: child,
          );
        },
        child: icon,
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      child: icon,
    );
  }

  // ─── Animated bars ─────────────────────────────────

  Widget _buildBars(AppColorTokens t) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        return Padding(
          padding: EdgeInsets.only(left: i == 0 ? 0 : 6),
          child: _PulsingBar(
            controller: _pulseController,
            height: _barHeights[i],
            delay: i * 0.15,
            color: t.accent.withValues(alpha: 0.6),
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────
//  Animated single bar
// ─────────────────────────────────────────────

class _PulsingBar extends StatelessWidget {
  final AnimationController controller;
  final double height;
  final double delay;
  final Color color;

  const _PulsingBar({
    required this.controller,
    required this.height,
    required this.delay,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        // Offset the animation by `delay` (normalized 0–1)
        final raw = (controller.value + delay) % 1.0;
        // Sine wave for smooth oscillation
        final scale = 0.5 + 0.5 * sin(raw * pi * 2);

        return Container(
          width: 6,
          height: height * (0.4 + 0.6 * scale),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
//  Dot pattern painter
// ─────────────────────────────────────────────

class _DotPatternPainter extends CustomPainter {
  final Color color;
  _DotPatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const spacing = 24.0;
    const radius = 1.0;

    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotPatternPainter old) => old.color != color;
}

// ─────────────────────────────────────────────
//  AnimatedBuilder alias (just uses AnimatedBuilder)
// ─────────────────────────────────────────────
// Note: Flutter's built-in AnimatedBuilder is used above.
// I used it directly — no extra class needed.
