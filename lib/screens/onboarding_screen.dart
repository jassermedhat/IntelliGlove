// onboarding_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../app_routes.dart';
import '../theme/theme_provider.dart';
import '../theme/app_colors.dart';
import '../components/inputs.dart';
import '../components/arc_rings.dart';
import '../components/toast.dart';
import '../services/app_startup_controller.dart';

class _Slide {
  final IconData icon;
  final String title;
  final String description;
  const _Slide({
    required this.icon,
    required this.title,
    required this.description,
  });
}

const _kSlides = [
  _Slide(
    icon: Icons.chat_bubble_outline_rounded,
    title: 'Real-Time Translation',
    description:
        'Transform gestures into words instantly with our advanced AI-powered translation system.',
  ),
  _Slide(
    icon: Icons.accessibility_new_rounded,
    title: 'Breaking Barriers',
    description:
        'Empowering deaf and mute users to communicate effortlessly with everyone around them.',
  ),
  _Slide(
    icon: Icons.smartphone_rounded,
    title: 'Smart Control',
    description:
        'Control your smart home devices with simple hand gestures. Your home, at your fingertips.',
  ),
];

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  int _currentSlide = 0;

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();

    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    final saved = await AppStartupScope.of(context).completeOnboarding();
    if (!mounted) return;
    if (saved) {
      context.go(AppRoutes.login);
    } else {
      toast.error(
        title: 'Could not save progress',
        description: 'Please try again.',
      );
    }
  }

  Future<void> _handleNext() async {
    if (_currentSlide < _kSlides.length - 1) {
      _fadeCtrl.reset();
      setState(() => _currentSlide++);
      _fadeCtrl.forward();
    } else {
      await _completeOnboarding();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ThemeProviderScope.of(context).tokens;

    // ── Responsive measurements ──────────────────────────
    final size = MediaQuery.of(context).size;
    final screenW = size.width;
    final screenH = size.height;
    final isShort = screenH < 600;

    // Icon box scales between 120 (small phones) and 200 (tablets)
    final iconBoxSize = (size.shortestSide * (isShort ? 0.28 : 0.38)).clamp(
      isShort ? 84.0 : 120.0,
      isShort ? 120.0 : 200.0,
    );
    final iconSize = iconBoxSize * 0.45;
    final iconRadius = iconBoxSize * 0.25;

    // Vertical spacing scales with screen height
    final spacingLg = (screenH * 0.055).clamp(
      isShort ? 14.0 : 24.0,
      isShort ? 24.0 : 56.0,
    );
    final spacingMd = (screenH * 0.02).clamp(
      isShort ? 8.0 : 12.0,
      isShort ? 14.0 : 24.0,
    );

    // Horizontal padding: tighter on phones, wider on tablets
    final hPadding = (screenW * 0.08).clamp(24.0, 64.0);

    // Font sizes
    final titleSize = (screenW * 0.068).clamp(22.0, 34.0);
    final bodySize = (screenW * 0.038).clamp(13.0, 17.0);

    // Arc rings decorations scale with screen
    final arcBottomOffset = screenH * 0.17;
    final arcLeftOffset = -(screenW * 0.43);
    final arcWidth = screenW * 0.8;
    final arcHeight = screenH * 0.13;

    // ─────────────────────────────────────────────────────

    final slide = _kSlides[_currentSlide];
    final isLast = _currentSlide == _kSlides.length - 1;

    return Scaffold(
      backgroundColor: t.background,
      body: Stack(
        children: [
          // ─────────────────────────────────────────────
          // Main center arc rings
          // ─────────────────────────────────────────────
          Positioned.fill(
            child: ArcRingsWidget(
              accentColor: t.accent,
              centerYFraction: 0.35,
              baseRadiusFraction: 0.5,
            ),
          ),

          // ─────────────────────────────────────────────
          // Skip button
          // ─────────────────────────────────────────────
          Positioned(
            top: 18,
            right: 16,
            child: SafeArea(
              child: AppButton(
                variant: AppButtonVariant.secondary,
                size: AppButtonSize.sm,
                onPressed: _completeOnboarding,
                child: Text('Skip', style: TextStyle(color: t.accent)),
              ),
            ),
          ),

          // ─────────────────────────────────────────────
          // Bottom button arc rings (responsive)
          // ─────────────────────────────────────────────
          Positioned(
            bottom: arcBottomOffset,
            left: arcLeftOffset,
            child: SizedBox(
              width: arcWidth,
              height: arcHeight,
              child: ArcRingsWidget(
                accentColor: t.primaryGlow,
                centerYFraction: 0.5,
                baseRadiusFraction: 0.34,
              ),
            ),
          ),

          // ─────────────────────────────────────────────
          // Foreground content
          // ─────────────────────────────────────────────
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Slide content
                Expanded(
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(horizontal: hPadding),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          // Fixed top anchor — icon always sits at the same Y
                          SizedBox(height: screenH * (isShort ? 0.08 : 0.236)),

                          // Icon box
                          Container(
                            width: iconBoxSize,
                            height: iconBoxSize,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(iconRadius),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [t.primary, t.primaryGlow],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: t.primaryGlow.withValues(alpha: 0.4),
                                  blurRadius: 32,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Icon(
                                slide.icon,
                                size: iconSize,
                                color: AppColors.white,
                              ),
                            ),
                          ),

                          SizedBox(height: spacingLg),

                          // Title
                          Text(
                            slide.title,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: titleSize,
                              fontWeight: FontWeight.w800,
                              color: t.foreground,
                              letterSpacing: -0.3,
                            ),
                          ),

                          SizedBox(height: spacingMd),

                          // Description — fixed height container so it never
                          // pushes the icon regardless of how many lines wrap
                          Text(
                            slide.description,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: bodySize,
                              color: t.mutedForeground,
                              height: 1.6,
                            ),
                          ),

                          SizedBox(height: spacingLg),

                          // Pagination dots
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(_kSlides.length, (i) {
                              final isActive = i == _currentSlide;

                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                margin: const EdgeInsets.only(right: 6),
                                width: isActive ? 28 : 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: isActive ? t.primary : t.muted,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              );
                            }),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ),

                // Next / Get Started button
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    hPadding,
                    0,
                    hPadding,
                    // Bottom padding: respect safe area on notched devices
                    (screenH * 0.03).clamp(16.0, 32.0),
                  ),
                  child: AppButton(
                    variant: AppButtonVariant.hero,
                    size: AppButtonSize.lg,
                    width: double.infinity,
                    icon: const Icon(Icons.chevron_right_rounded, size: 20),
                    onPressed: _handleNext,
                    child: Text(isLast ? 'Get Started' : 'Next'),
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
