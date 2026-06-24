// arc_rings.dart
//
// Self-contained rotating arc-rings component.
// Drop this single file anywhere and import it.
//
// ── Usage ────────────────────────────────────────────────────────────
//
//   // Fill parent (as a background layer)
//   Positioned.fill(
//     child: ArcRingsWidget(
//       accentColor: t.accent,
//       centerYFraction: 0.42,
//     ),
//   )
//
//   // Fixed size, centred rings
//   ArcRingsWidget(
//     accentColor: Colors.cyanAccent,
//     width: 320,
//     height: 320,
//   )

import 'dart:math' as math;
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────
// PAINTER
// ─────────────────────────────────────────────

class _ArcRingsPainter extends CustomPainter {
  final double progress;
  final Color accentColor;
  final double baseRadius;
  final double centerYFraction;

  const _ArcRingsPainter({
    required this.progress,
    required this.accentColor,
    required this.baseRadius,
    required this.centerYFraction,
  });

  static const List<double> _ringRadiusFactors = [0.56, 0.82, 1.10, 1.40, 1.75];
  static const List<double> _ringOpacities = [0.07, 0.05, 0.04, 0.03, 0.02];

  // (radiusFactor, phaseOffset, sweepFraction, speed, opacity)
  static const List<(double, double, double, double, double)> _arcConfigs = [
    (0.56, 0.0, 0.4, 2.0, 0.55),
    (0.82, 0.6, 0.3, -1.0, 0.35),
    (1.10, 0.2, 0.25, 1.0, 0.25),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * centerYFraction;

    // Static background rings
    for (var i = 0; i < _ringRadiusFactors.length; i++) {
      canvas.drawCircle(
        Offset(cx, cy),
        baseRadius * _ringRadiusFactors[i],
        Paint()
          ..color = accentColor.withValues(alpha: _ringOpacities[i])
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );
    }

    // Rotating arcs + glowing tip dots
    for (var i = 0; i < _arcConfigs.length; i++) {
      final (rFactor, phase, sweepFrac, speed, op) = _arcConfigs[i];
      final r = baseRadius * rFactor;

      final angle = (progress * speed * math.pi * 2) % (math.pi * 2);
      final startAngle = phase * math.pi * 2 + angle;
      final sweepAngle = sweepFrac * math.pi * 2;
      final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);

      canvas.drawArc(
        rect,
        startAngle,
        sweepAngle,
        false,
        Paint()
          ..shader = SweepGradient(
            startAngle: 0,
            endAngle: math.pi * 2,
            transform: GradientRotation(angle),
            colors: [
              accentColor.withValues(alpha: 0.0),
              accentColor.withValues(alpha: op * 0.4),
              accentColor.withValues(alpha: op),
              accentColor.withValues(alpha: op * 0.4),
              accentColor.withValues(alpha: 0.0),
            ],
            stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
          ).createShader(rect)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round,
      );

      // Tip dot — index 1 uses start tip, others use end tip
      final tipAngle = (i == 1) ? startAngle : (startAngle + sweepAngle);
      final tipX = cx + r * math.cos(tipAngle);
      final tipY = cy + r * math.sin(tipAngle);
      final tipRect = Rect.fromCircle(center: Offset(tipX, tipY), radius: 3);

      canvas.drawCircle(
        Offset(tipX, tipY),
        3,
        Paint()
          ..shader = RadialGradient(
            colors: [
              accentColor.withValues(alpha: op),
              accentColor.withValues(alpha: 0.0),
            ],
          ).createShader(tipRect),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ArcRingsPainter old) =>
      old.progress != progress ||
      old.accentColor != accentColor ||
      old.baseRadius != baseRadius ||
      old.centerYFraction != centerYFraction;
}

// ─────────────────────────────────────────────
// WIDGET
// ─────────────────────────────────────────────

class ArcRingsWidget extends StatefulWidget {
  /// Accent colour used for every ring, arc, and dot.
  final Color accentColor;

  /// Optional fixed width. When null, expands to fill parent.
  final double? width;

  /// Optional fixed height. When null, expands to fill parent.
  final double? height;

  /// Vertical centre of the ring group as a fraction of widget height.
  /// Defaults to 0.5 (true centre). Use 0.42 to match the splash screen.
  final double centerYFraction;

  /// Ring scale unit as a fraction of widget width.
  /// Defaults to 0.28 (matches the original splash-screen formula).
  final double baseRadiusFraction;

  /// Duration of one full rotation cycle. Defaults to 16 seconds.
  final Duration cycleDuration;

  const ArcRingsWidget({
    super.key,
    required this.accentColor,
    this.width,
    this.height,
    this.centerYFraction = 0.5,
    this.baseRadiusFraction = 0.28,
    this.cycleDuration = const Duration(seconds: 16),
  });

  @override
  State<ArcRingsWidget> createState() => _ArcRingsWidgetState();
}

class _ArcRingsWidgetState extends State<ArcRingsWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.cycleDuration)
      ..repeat();
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.linear);
  }

  @override
  void didUpdateWidget(covariant ArcRingsWidget old) {
    super.didUpdateWidget(old);
    if (old.cycleDuration != widget.cycleDuration) {
      _ctrl.duration = widget.cycleDuration;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final renderWidth = constraints.maxWidth.isInfinite
              ? (widget.width ?? MediaQuery.of(context).size.width)
              : constraints.maxWidth;

          return RepaintBoundary(
            child: AnimatedBuilder(
              animation: _anim,
              builder: (_, __) => CustomPaint(
                painter: _ArcRingsPainter(
                  progress: _anim.value,
                  accentColor: widget.accentColor,
                  baseRadius: renderWidth * widget.baseRadiusFraction,
                  centerYFraction: widget.centerYFraction,
                ),
                size: Size.infinite,
              ),
            ),
          );
        },
      ),
    );
  }
}
