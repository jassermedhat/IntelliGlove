// splash_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../app_routes.dart';
import '../theme/theme_provider.dart';
import '../theme/app_colors.dart';
import '../components/inputs.dart';
import '../components/arc_rings.dart';
import '../services/app_startup_controller.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _enterCtrl;
  late final AnimationController _pulseCtrl;

  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();

    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _fadeAnim = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut);

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.07),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOutCubic));

    _scaleAnim = Tween<double>(
      begin: 0.92,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOutCubic));

    _pulseAnim = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _enterCtrl.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) => _routeFromSplash());
  }

  Future<void> _routeFromSplash() async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    final destination = await AppStartupScope.of(context).initialize();
    if (!mounted) return;
    context.go(destination);
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = ThemeProviderScope.of(context).tokens;
    final size = MediaQuery.of(context).size;
    final screenW = size.width;
    final screenH = size.height;
    final isShort = screenH < 600;

    // ── Responsive measurements ──────────────────────────
    final logoSize = (size.shortestSide * 0.28).clamp(
      isShort ? 72.0 : 90.0,
      isShort ? 100.0 : 160.0,
    );
    final logoOffset = logoSize / 2;
    final arcCenterY = screenH * (isShort ? 0.22 : 0.3);

    // Horizontal padding scales with width, clamped for phones/tablets
    final hPadding = (screenW * 0.08).clamp(24.0, 64.0);

    // Gap between brand block and buttons scales with height
    final brandToBtn = (screenH * 0.2).clamp(
      isShort ? 16.0 : 32.0,
      isShort ? 32.0 : 150.0,
    );

    // Bottom padding for button section — safe on notched + tall devices
    final btnBottom = (screenH * 0.04).clamp(24.0, 48.0);
    // ─────────────────────────────────────────────────────

    return Scaffold(
      backgroundColor: t.background,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: ScaleTransition(
            scale: _scaleAnim,
            child: Stack(
              children: [
                // ── Background arcs ──────────────────────────────
                Positioned.fill(
                  child: ArcRingsWidget(
                    accentColor: t.accent,
                    centerYFraction: 0.3,
                    baseRadiusFraction: 0.28,
                  ),
                ),

                // ── Logo ─────────────────────────────────────────
                Positioned(
                  top: arcCenterY - logoOffset,
                  left: 0,
                  right: 0,
                  child: AnimatedBuilder(
                    animation: _pulseAnim,
                    builder: (_, child) => Center(
                      child: _LogoRing(
                        t: t,
                        pulseValue: _pulseAnim.value,
                        size: logoSize,
                        child: child!,
                      ),
                    ),
                    child: _LogoImage(t: t, size: logoSize),
                  ),
                ),

                // ── Bottom content ────────────────────────────────
                Positioned.fill(
                  child: SafeArea(
                    top: false,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          reverse: true,
                          padding: EdgeInsets.only(
                            top: logoSize + 24,
                            bottom: btnBottom,
                          ),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: constraints.maxHeight - btnBottom,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: hPadding,
                                  ),
                                  child: _BrandBlock(t: t),
                                ),
                                SizedBox(height: brandToBtn),
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: hPadding,
                                  ),
                                  child: _CtaButtons(t: t),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
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

// ─────────────────────────────────────────────
// LOGO RING (RESPONSIVE)
// ─────────────────────────────────────────────

class _LogoRing extends StatelessWidget {
  final AppColorTokens t;
  final double pulseValue;
  final Widget child;
  final double size;

  const _LogoRing({
    required this.t,
    required this.pulseValue,
    required this.child,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _ring(size, 0.06 + 0.06 * pulseValue),
          _ring(size * 0.85, 0.10 + 0.08 * pulseValue),
          Container(
            width: size * 0.72,
            height: size * 0.72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: t.accent.withValues(alpha: 0.05 + 0.04 * pulseValue),
            ),
          ),
          child,
        ],
      ),
    );
  }

  Widget _ring(double s, double opacity) {
    return Container(
      width: s,
      height: s,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: t.accent.withValues(alpha: opacity),
          width: 1,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// LOGO IMAGE (RESPONSIVE)
// ─────────────────────────────────────────────

class _LogoImage extends StatelessWidget {
  final AppColorTokens t;
  final double size;

  const _LogoImage({required this.t, required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size * 0.67,
      height: size * 0.67,
      child: Image.asset('assets/logo_app.png', fit: BoxFit.contain),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// BRAND BLOCK  (fully responsive)
// ─────────────────────────────────────────────────────────────

class _BrandBlock extends StatelessWidget {
  final AppColorTokens t;
  const _BrandBlock({required this.t});

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final screenH = MediaQuery.of(context).size.height;

    // Font sizes — scale with width, clamped for phones → tablets
    final labelSize = (screenW * 0.025).clamp(9.0, 13.0);
    final titleSize = (screenW * 0.092).clamp(28.0, 48.0);
    final subtitleSize = (screenW * 0.035).clamp(12.0, 17.0);

    // Spacing scales with height
    final labelGap = (screenH * 0.012).clamp(8.0, 16.0);
    final dividerGap = (screenH * 0.016).clamp(10.0, 22.0);

    return Column(
      children: [
        Text(
          'SMART GLOVE',
          style: TextStyle(
            fontSize: labelSize,
            fontWeight: FontWeight.w800,
            color: t.accent,
            letterSpacing: (screenW * 0.01).clamp(2.0, 5.0),
          ),
        ),
        SizedBox(height: labelGap),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: TextStyle(
              fontSize: titleSize,
              fontWeight: FontWeight.w900,
              color: t.foreground,
              letterSpacing: -1,
              height: 1.0,
            ),
            children: [
              const TextSpan(text: 'Intelli'),
              TextSpan(
                text: 'Glove',
                style: TextStyle(color: t.accent),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(vertical: dividerGap),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 0.5,
                  color: t.accent.withValues(alpha: 0.15),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: t.accent.withValues(alpha: 0.4),
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  height: 0.5,
                  color: t.accent.withValues(alpha: 0.15),
                ),
              ),
            ],
          ),
        ),
        Text(
          'Bridging gesture and digital language.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: subtitleSize,
            color: t.mutedForeground,
            height: 1.6,
            letterSpacing: 0.1,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// CTA BUTTONS
// ─────────────────────────────────────────────────────────────

class _CtaButtons extends StatelessWidget {
  final AppColorTokens t;
  const _CtaButtons({required this.t});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: AppButton(
            variant: AppButtonVariant.hero,
            size: AppButtonSize.md,
            onPressed: () => context.push(AppRoutes.onboarding),
            child: const Text('Get Started'),
          ),
        ),
      ],
    );
  }
}
