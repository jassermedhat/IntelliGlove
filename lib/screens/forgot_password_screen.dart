// forgot_password_screen.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../app_routes.dart';
import '../theme/theme_provider.dart';
import '../theme/app_colors.dart';
import '../components/inputs.dart';
import '../services/auth_provider.dart';
import '../components/toast.dart';

// ── State machine ─────────────────────────────────────────
enum _ForgotStep { input, success }

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with TickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  _ForgotStep _step = _ForgotStep.input;

  late final AnimationController _fadeCtrl;
  late final AnimationController _arcCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();

    _arcCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _fadeCtrl.dispose();
    _arcCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSend() async {
    final email = _emailCtrl.text.trim();
    if (!email.contains('@')) {
      toast.warning(
        title: 'Invalid email',
        description: 'Enter a valid email address.',
      );
      return;
    }
    await AuthProviderScope.of(context).sendPasswordReset(email);
    if (!mounted) return;
    _fadeCtrl.reset();
    setState(() => _step = _ForgotStep.success);
    _fadeCtrl.forward();
  }

  Future<void> _handleResend() async {
    await AuthProviderScope.of(context).sendPasswordReset(_emailCtrl.text.trim());
    toast.info(
      title: 'Reset email sent',
      description:
          'If an account exists for this email, a reset link is on its way.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = ThemeProviderScope.of(context).tokens;
    final isDark = ThemeProviderScope.of(context).isDark;
    final size = MediaQuery.of(context).size;

    final screenW = size.width;
    final screenH = size.height;

    // ── Responsive measurements ──────────────────────────
    final domeHeight = (screenH * 0.16).clamp(105.0, 155.0);
    final backRowHeight = domeHeight * 0.50;

    final hPadding = (screenW * 0.065).clamp(20.0, 40.0);
    final topScrollPadding = (screenH * 0.12).clamp(55.0, 130.0);
    final bottomScrollPadding = (screenH * 0.05).clamp(28.0, 60.0);
    final maxContentWidth = screenW >= 700 ? 448.0 : double.infinity;
    // ─────────────────────────────────────────────────────

    return Scaffold(
      backgroundColor: t.background,
      body: Stack(
        children: [
          // ── Dome + oval arc ───────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SizedBox(
              width: screenW,
              height: domeHeight,
              child: AnimatedBuilder(
                animation: _arcCtrl,
                builder: (_, __) => CustomPaint(
                  painter: _DomePainter(
                    primaryColor: t.primary,
                    primaryGlow: t.primaryGlow,
                    accentColor: t.accent,
                    isDark: isDark,
                    arcProgress: _arcCtrl.value,
                  ),
                ),
              ),
            ),
          ),

          // ── Content ───────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                // ── Back button row — sits just below dome ──────
                SizedBox(
                  height: backRowHeight,
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: (screenW * 0.035).clamp(12.0, 22.0),
                        bottom: (screenH * 0.006).clamp(4.0, 8.0),
                      ),
                      child: GestureDetector(
                        onTap: () => context.go(AppRoutes.login),
                        child: Container(
                          width: (screenW * 0.095).clamp(34.0, 42.0),
                          height: (screenW * 0.095).clamp(34.0, 42.0),
                          decoration: BoxDecoration(
                            color: t.accent.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: t.accent.withValues(alpha: 0.22),
                            ),
                          ),
                          child: Icon(
                            Icons.arrow_back_rounded,
                            size: (screenW * 0.045).clamp(17.0, 21.0),
                            color: t.accent,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // ── Scrollable form ──────────────────────────────
                Expanded(
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: SlideTransition(
                      position: _slideAnim,
                      child: SingleChildScrollView(
                        padding: EdgeInsets.symmetric(
                          horizontal: hPadding,
                          vertical: topScrollPadding,
                        ).copyWith(bottom: bottomScrollPadding),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: maxContentWidth,
                            ),
                            child: _step == _ForgotStep.input
                                ? _InputView(
                                    t: t,
                                    emailCtrl: _emailCtrl,
                                    onSend: _handleSend,
                                  )
                                : _SuccessView(
                                    t: t,
                                    email: _emailCtrl.text,
                                    onResend: _handleResend,
                                  ),
                          ),
                        ),
                      ),
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

// ─────────────────────────────────────────────────────────────
// STEP 1 — Email input
// ─────────────────────────────────────────────────────────────

class _InputView extends StatelessWidget {
  final AppColorTokens t;
  final TextEditingController emailCtrl;
  final VoidCallback onSend;

  const _InputView({
    required this.t,
    required this.emailCtrl,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final screenW = size.width;
    final screenH = size.height;

    // ── Responsive measurements ──────────────────────────
    final iconBoxSize = (screenW * 0.20).clamp(64.0, 82.0);
    final iconSize = (screenW * 0.09).clamp(30.0, 38.0);
    final iconRadius = (screenW * 0.055).clamp(18.0, 24.0);

    final titleSize = (screenW * 0.068).clamp(22.0, 28.0);
    final subtitleSize = (screenW * 0.034).clamp(12.0, 14.0);

    final iconToTitleGap = (screenH * 0.023).clamp(14.0, 22.0);
    final titleToSubtitleGap = (screenH * 0.006).clamp(4.0, 7.0);
    final headerToCardGap = (screenH * 0.035).clamp(22.0, 32.0);
    final cardPadding = (screenW * 0.055).clamp(18.0, 24.0);
    final cardRadius = (screenW * 0.050).clamp(18.0, 22.0);

    final fieldToButtonGap = (screenH * 0.025).clamp(16.0, 22.0);
    final buttonHeight = (screenH * 0.064).clamp(48.0, 54.0);
    final buttonRadius = (screenW * 0.035).clamp(12.0, 16.0);
    final buttonTextSize = (screenW * 0.038).clamp(14.0, 16.0);

    final footerTextSize = (screenW * 0.033).clamp(12.0, 14.0);
    final bottomGap = (screenH * 0.04).clamp(24.0, 34.0);
    // ─────────────────────────────────────────────────────

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Column(
          children: [
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
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  Icons.lock_reset_rounded,
                  size: iconSize,
                  color: Colors.white,
                ),
              ),
            ),
            SizedBox(height: iconToTitleGap),
            Text(
              'Forgot Password?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: titleSize,
                fontWeight: FontWeight.w900,
                color: t.foreground,
                letterSpacing: -0.3,
              ),
            ),
            SizedBox(height: titleToSubtitleGap),
            Text(
              'Enter your email and we\'ll send\nyou a reset link',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: t.mutedForeground,
                fontSize: subtitleSize,
                height: 1.5,
              ),
            ),
          ],
        ),

        SizedBox(height: headerToCardGap),

        Container(
          padding: EdgeInsets.all(cardPadding),
          decoration: BoxDecoration(
            color: t.card,
            borderRadius: BorderRadius.circular(cardRadius),
            border: Border.all(color: t.accent.withValues(alpha: 0.15)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppLabel('Email'),
              const SizedBox(height: 6),
              AppInput(
                controller: emailCtrl,
                hintText: 'your.email@example.com',
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => onSend(),
                prefixIcon: Icon(
                  Icons.mail_outline_rounded,
                  size: 18,
                  color: t.mutedForeground,
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: fieldToButtonGap),

        GestureDetector(
          onTap: onSend,
          child: Container(
            width: double.infinity,
            height: buttonHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(buttonRadius),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [t.primary, t.accent],
              ),
              boxShadow: [
                BoxShadow(
                  color: t.accent.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              'Send Reset Link',
              style: TextStyle(
                fontSize: buttonTextSize,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),

        SizedBox(height: fieldToButtonGap),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                'Remember your password? ',
                style: TextStyle(
                  fontSize: footerTextSize,
                  color: t.mutedForeground,
                ),
              ),
            ),
            GestureDetector(
              onTap: () => context.go(AppRoutes.login),
              child: Text(
                'Sign In',
                style: TextStyle(
                  fontSize: footerTextSize,
                  color: t.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),

        SizedBox(height: bottomGap),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// STEP 2 — Success confirmation
// ─────────────────────────────────────────────────────────────

class _SuccessView extends StatelessWidget {
  final AppColorTokens t;
  final String email;
  final VoidCallback onResend;

  const _SuccessView({
    required this.t,
    required this.email,
    required this.onResend,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final screenW = size.width;
    final screenH = size.height;

    // ── Responsive measurements ──────────────────────────
    final iconBoxSize = (screenW * 0.20).clamp(64.0, 82.0);
    final iconSize = (screenW * 0.09).clamp(30.0, 38.0);
    final iconRadius = (screenW * 0.055).clamp(18.0, 24.0);

    final titleSize = (screenW * 0.068).clamp(22.0, 28.0);
    final subtitleSize = (screenW * 0.034).clamp(12.0, 14.0);

    final iconToTitleGap = (screenH * 0.023).clamp(14.0, 22.0);
    final titleToSubtitleGap = (screenH * 0.006).clamp(4.0, 7.0);
    final headerToCardGap = (screenH * 0.035).clamp(22.0, 32.0);

    final cardPadding = (screenW * 0.055).clamp(18.0, 24.0);
    final cardRadius = (screenW * 0.050).clamp(18.0, 22.0);
    final infoIconSize = (screenW * 0.095).clamp(34.0, 40.0);

    final sectionGap = (screenH * 0.025).clamp(16.0, 22.0);
    final buttonHeight = (screenH * 0.064).clamp(48.0, 54.0);
    final secondaryButtonHeight = (screenH * 0.058).clamp(44.0, 50.0);
    final buttonRadius = (screenW * 0.035).clamp(12.0, 16.0);

    final buttonTextSize = (screenW * 0.038).clamp(14.0, 16.0);
    final smallTextSize = (screenW * 0.033).clamp(12.0, 14.0);
    final bottomGap = (screenH * 0.04).clamp(24.0, 34.0);
    // ─────────────────────────────────────────────────────

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Column(
          children: [
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
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  Icons.mark_email_read_outlined,
                  size: iconSize,
                  color: Colors.white,
                ),
              ),
            ),
            SizedBox(height: iconToTitleGap),
            Text(
              'Check Your Email',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: titleSize,
                fontWeight: FontWeight.w900,
                color: t.foreground,
                letterSpacing: -0.3,
              ),
            ),
            SizedBox(height: titleToSubtitleGap),
            Text(
              'We sent a reset link to',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: t.mutedForeground,
                fontSize: subtitleSize,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              email,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: TextStyle(
                color: t.accent,
                fontSize: smallTextSize,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),

        SizedBox(height: headerToCardGap),

        Container(
          padding: EdgeInsets.all(cardPadding),
          decoration: BoxDecoration(
            color: t.card,
            borderRadius: BorderRadius.circular(cardRadius),
            border: Border.all(color: t.accent.withValues(alpha: 0.15)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: infoIconSize,
                height: infoIconSize,
                decoration: BoxDecoration(
                  color: t.accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: t.accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Make sure to check your spam or junk folder if you don\'t see it.',
                  style: TextStyle(
                    fontSize: smallTextSize,
                    color: t.mutedForeground,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: sectionGap),

        GestureDetector(
          onTap: () => context.go(AppRoutes.login),
          child: Container(
            width: double.infinity,
            height: buttonHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(buttonRadius),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [t.primary, t.accent],
              ),
              boxShadow: [
                BoxShadow(
                  color: t.accent.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              'Back to Sign In',
              style: TextStyle(
                fontSize: buttonTextSize,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),

        SizedBox(height: (screenH * 0.018).clamp(12.0, 18.0)),

        GestureDetector(
          onTap: onResend,
          child: Container(
            width: double.infinity,
            height: secondaryButtonHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(buttonRadius),
              border: Border.all(
                color: t.accent.withValues(alpha: 0.40),
                width: 1.5,
              ),
              color: t.accent.withValues(alpha: 0.06),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.refresh_rounded, size: 18, color: t.accent),
                const SizedBox(width: 7),
                Text(
                  'Resend Email',
                  style: TextStyle(
                    fontSize: smallTextSize,
                    fontWeight: FontWeight.w700,
                    color: t.accent,
                  ),
                ),
              ],
            ),
          ),
        ),

        SizedBox(height: bottomGap),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// DOME PAINTER — identical to login (single rotating oval arc)
// ─────────────────────────────────────────────────────────────

class _DomePainter extends CustomPainter {
  final Color primaryColor;
  final Color primaryGlow;
  final Color accentColor;
  final bool isDark;
  final double arcProgress;

  const _DomePainter({
    required this.primaryColor,
    required this.primaryGlow,
    required this.accentColor,
    required this.isDark,
    required this.arcProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final domeRect = Rect.fromCenter(
      center: Offset(w / 2, 0),
      width: w * 1.18,
      height: h * 2.2,
    );

    // Outer soft halo
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w / 2, 0),
        width: w * 1.40,
        height: h * 2.6,
      ),
      Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 0.60,
          colors: [
            primaryGlow.withValues(alpha: isDark ? 0.20 : 0.13),
            primaryColor.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, w, h * 2)),
    );

    // Main dome fill
    canvas.drawOval(
      domeRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            primaryColor.withValues(alpha: isDark ? 0.60 : 0.42),
            primaryColor.withValues(alpha: isDark ? 0.24 : 0.15),
            primaryColor.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // Inner accent cap
    canvas.drawOval(
      domeRect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.85),
          radius: 0.50,
          colors: [
            accentColor.withValues(alpha: isDark ? 0.30 : 0.18),
            accentColor.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // Static glowing rim
    canvas.drawOval(
      domeRect,
      Paint()
        ..color = primaryColor.withValues(alpha: isDark ? 0.50 : 0.28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    // ── Rotating arc on the oval rim ─────────────────────
    final rx = domeRect.width / 2;
    final ry = domeRect.height / 2;
    final cx = domeRect.center.dx;
    final cy = domeRect.center.dy;

    const arcFraction = 0.35;
    const segments = 80;

    final startT = arcProgress * math.pi * 2;
    final endT = startT + arcFraction * math.pi * 2;

    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < segments; i++) {
      final t0 = startT + (endT - startT) * (i / segments);
      final t1 = startT + (endT - startT) * ((i + 1) / segments);

      final x0 = cx + rx * math.cos(t0);
      final y0 = cy + ry * math.sin(t0);
      final x1 = cx + rx * math.cos(t1);
      final y1 = cy + ry * math.sin(t1);

      final frac = i / segments;
      final opacity = frac < 0.2
          ? (frac / 0.2)
          : frac > 0.8
          ? ((1.0 - frac) / 0.2)
          : 1.0;

      arcPaint.color = accentColor.withValues(
        alpha: (isDark ? 0.90 : 0.70) * opacity,
      );

      canvas.drawLine(Offset(x0, y0), Offset(x1, y1), arcPaint);
    }

    // Glowing tip dot
    final tipX = cx + rx * math.cos(endT);
    final tipY = cy + ry * math.sin(endT);
    final tipRect = Rect.fromCircle(center: Offset(tipX, tipY), radius: 6);

    canvas.drawCircle(
      Offset(tipX, tipY),
      4,
      Paint()
        ..shader = RadialGradient(
          colors: [
            accentColor.withValues(alpha: isDark ? 0.95 : 0.80),
            accentColor.withValues(alpha: 0.0),
          ],
        ).createShader(tipRect),
    );
  }

  @override
  bool shouldRepaint(_DomePainter old) =>
      old.arcProgress != arcProgress ||
      old.primaryColor != primaryColor ||
      old.isDark != isDark;
}
