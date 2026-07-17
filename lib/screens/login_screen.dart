// login_screen.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../app_routes.dart';
import '../theme/theme_provider.dart';
import '../components/inputs.dart';
import '../services/auth_provider.dart';
import '../components/toast.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;

  late final AnimationController _fadeCtrl;
  late final AnimationController _arcCtrl; // ← drives the oval arc
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
    _passwordCtrl.dispose();
    _fadeCtrl.dispose();
    _arcCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_loading) return;
    setState(() => _loading = true);
    toast.info(description: 'Signing in…');
    final auth = AuthProviderScope.of(context);
    await auth.login(_emailCtrl.text.trim(), _passwordCtrl.text);
    if (!mounted) return;
    setState(() => _loading = false);
    // Success toast is not guarded by `mounted`: a successful login triggers a
    // router redirect to home that unmounts this screen before we get here. The
    // toast service is a global overlay, so it still surfaces after navigation.
    if (auth.isLoggedIn) {
      toast.success(
        title: 'Welcome back',
        description: 'Logged in successfully.',
      );
    } else if (auth.errorMessage != null) {
      toast.error(title: 'Sign-in failed', description: auth.errorMessage!);
    }
  }

  Future<void> _handleGoogle() async {
    if (_loading) return;
    setState(() => _loading = true);
    toast.info(description: 'Signing in with Google…');
    final auth = AuthProviderScope.of(context);
    await auth.loginWithGoogle();
    if (!mounted) return;
    setState(() => _loading = false);
    if (auth.isLoggedIn) {
      toast.success(
        title: 'Welcome back',
        description: 'Signed in with Google.',
      );
    } else if (auth.errorMessage != null) {
      toast.error(
        title: 'Google sign-in failed',
        description: auth.errorMessage!,
      );
    }
  }

  Future<void> _handleBiometric() async {
    final auth = AuthProviderScope.of(context);
    if (!await auth.unlockWithBiometrics() && mounted) {
      toast.warning(
        title: 'Biometric unlock unavailable',
        description: 'Sign in normally first, then enable biometric lock in Privacy & Security.',
      );
    }
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
    final hPadding = (screenW * 0.065).clamp(20.0, 40.0);

    final logoSize = (screenW * 0.20).clamp(64.0, 82.0);
    final logoRadius = (screenW * 0.055).clamp(18.0, 24.0);

    final domeGap = (domeHeight * 0.30).clamp(28.0, 48.0);
    final logoToTitleGap = (screenH * 0.062).clamp(28.0, 60.0);
    final titleSize = (screenW * 0.068).clamp(22.0, 28.0);
    final subtitleSize = (screenW * 0.034).clamp(12.0, 14.0);

    final headerToCardGap = (screenH * 0.038).clamp(24.0, 34.0);
    final cardPadding = (screenW * 0.055).clamp(18.0, 24.0);
    final cardRadius = (screenW * 0.050).clamp(18.0, 22.0);

    final inputGap = (screenH * 0.020).clamp(14.0, 18.0);
    final buttonGap = (screenH * 0.025).clamp(16.0, 22.0);
    final buttonHeight = (screenH * 0.064).clamp(48.0, 54.0);
    final secondaryButtonHeight = (screenH * 0.058).clamp(44.0, 50.0);
    final buttonRadius = (screenW * 0.035).clamp(12.0, 16.0);

    final mainButtonTextSize = (screenW * 0.038).clamp(14.0, 16.0);
    final smallTextSize = (screenW * 0.033).clamp(12.0, 14.0);
    final dividerTextSize = (screenW * 0.028).clamp(10.0, 12.0);

    final sectionGap = (screenH * 0.028).clamp(18.0, 26.0);
    final bottomGap = (screenH * 0.04).clamp(24.0, 36.0);

    final maxContentWidth = screenW >= 700 ? 448.0 : double.infinity;
    // ─────────────────────────────────────────────────────

    return Scaffold(
      backgroundColor: t.background,
      body: Stack(
        children: [
          // ── Dome + oval arc (animated) ────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SizedBox(
              width: size.width,
              height: domeHeight,
              child: AnimatedBuilder(
                animation: _arcCtrl,
                builder: (_, __) => CustomPaint(
                  painter: _DomePainter(
                    primaryColor: t.primary,
                    primaryGlow: t.primaryGlow,
                    accentColor: t.accent,
                    isDark: isDark,
                    arcProgress: _arcCtrl.value, // ← 0→1 progress
                  ),
                ),
              ),
            ),
          ),

          // ── Scrollable content ────────────────────────────────
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: hPadding),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxContentWidth),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Space for dome
                          SizedBox(height: domeGap),
                          // ── Logo + headline ───────────────────
                          Column(
                            children: [
                              Container(
                                width: logoSize,
                                height: logoSize,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(
                                    logoRadius,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                    logoRadius,
                                  ),
                                  child: Image.asset(
                                    'assets/logo_app.png',
                                    width: logoSize,
                                    height: logoSize,
                                    fit: BoxFit.scaleDown,
                                  ),
                                ),
                              ),

                              SizedBox(height: logoToTitleGap),
                              Text(
                                'Welcome Back',
                                style: TextStyle(
                                  fontSize: titleSize,
                                  fontWeight: FontWeight.w900,
                                  color: t.foreground,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                'Sign in to continue',
                                style: TextStyle(
                                  color: t.mutedForeground,
                                  fontSize: subtitleSize,
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: headerToCardGap),

                          // ── Form card ─────────────────────────
                          Container(
                            padding: EdgeInsets.all(cardPadding),
                            decoration: BoxDecoration(
                              color: t.card,
                              borderRadius: BorderRadius.circular(cardRadius),
                              border: Border.all(
                                color: t.accent.withValues(alpha: 0.15),
                              ),
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
                                  controller: _emailCtrl,
                                  hintText: 'your.email@example.com',
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  prefixIcon: Icon(
                                    Icons.mail_outline_rounded,
                                    size: 18,
                                    color: t.mutedForeground,
                                  ),
                                ),
                                SizedBox(height: inputGap),
                                AppLabel('Password'),
                                const SizedBox(height: 6),
                                AppInput(
                                  controller: _passwordCtrl,
                                  hintText: '••••••••',
                                  obscureText: _obscure,
                                  textInputAction: TextInputAction.done,
                                  onSubmitted: (_) => _handleLogin(),
                                  prefixIcon: Icon(
                                    Icons.lock_outline_rounded,
                                    size: 18,
                                    color: t.mutedForeground,
                                  ),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscure
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      size: 18,
                                      color: t.mutedForeground,
                                    ),
                                    onPressed: () =>
                                        setState(() => _obscure = !_obscure),
                                  ),
                                ),
                                const SizedBox(height: 10),

                                Align(
                                  alignment: Alignment.centerRight,
                                  child: GestureDetector(
                                    onTap: () =>
                                        context.push(AppRoutes.forgotPassword),
                                    child: Text(
                                      'Forgot Password?',
                                      style: TextStyle(
                                        fontSize: smallTextSize,
                                        color: t.accent,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          SizedBox(height: buttonGap),

                          // ── Sign In button ────────────────────
                          GestureDetector(
                            onTap: _loading ? null : _handleLogin,
                            child: AnimatedOpacity(
                              opacity: _loading ? 0.75 : 1.0,
                              duration: const Duration(milliseconds: 150),
                              child: Container(
                                width: double.infinity,
                                height: buttonHeight,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(
                                    buttonRadius,
                                  ),
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
                                child: _loading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                            Colors.white,
                                          ),
                                        ),
                                      )
                                    : Text(
                                        'Sign In',
                                        style: TextStyle(
                                          fontSize: mainButtonTextSize,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                              ),
                            ),
                          ),

                          SizedBox(height: sectionGap),
                          // ── Divider ───────────────────────────
                          Row(
                            children: [
                              Expanded(child: Divider(color: t.border)),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                child: Text(
                                  'Or continue with',
                                  style: TextStyle(
                                    fontSize: dividerTextSize,
                                    color: t.mutedForeground,
                                  ),
                                ),
                              ),
                              Expanded(child: Divider(color: t.border)),
                            ],
                          ),

                          SizedBox(height: inputGap),

                          // ── Social buttons ────────────────────
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: _handleGoogle,
                                  child: Container(
                                    height: secondaryButtonHeight,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(
                                        buttonRadius,
                                      ),
                                      border: Border.all(
                                        color: t.accent.withValues(alpha: 0.40),
                                        width: 1.5,
                                      ),
                                      color: t.accent.withValues(alpha: 0.06),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.language_rounded,
                                          size: 18,
                                          color: t.accent,
                                        ),
                                        const SizedBox(width: 7),
                                        Text(
                                          'Google',
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
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: GestureDetector(
                                  onTap: _handleBiometric,
                                  child: Container(
                                    height: secondaryButtonHeight,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(
                                        buttonRadius,
                                      ),
                                      border: Border.all(
                                        color: t.accent.withValues(alpha: 0.40),
                                        width: 1.5,
                                      ),
                                      color: t.accent.withValues(alpha: 0.06),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.fingerprint_rounded,
                                          size: 18,
                                          color: t.accent,
                                        ),
                                        const SizedBox(width: 7),
                                        Text(
                                          'Biometric',
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
                              ),
                            ],
                          ),

                          SizedBox(height: sectionGap),
                          // ── Sign up link ──────────────────────
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  "Don't have an account? ",
                                  style: TextStyle(
                                    fontSize: smallTextSize,
                                    color: t.mutedForeground,
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: () => context.push(AppRoutes.signup),
                                child: Text(
                                  'Sign Up',
                                  style: TextStyle(
                                    fontSize: smallTextSize,
                                    color: t.accent,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: bottomGap),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// DOME PAINTER  — with rotating oval arc on the rim
// ─────────────────────────────────────────────────────────────

class _DomePainter extends CustomPainter {
  final Color primaryColor;
  final Color primaryGlow;
  final Color accentColor;
  final bool isDark;
  final double arcProgress; // 0.0 → 1.0, drives rotation

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

    // ── Outer soft halo ──────────────────────────────────
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

    // ── Main dome fill ───────────────────────────────────
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

    // ── Inner accent cap ─────────────────────────────────
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

    // ── Static glowing rim ───────────────────────────────
    canvas.drawOval(
      domeRect,
      Paint()
        ..color = primaryColor.withValues(alpha: isDark ? 0.50 : 0.28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    // ── Rotating arc on the oval rim ─────────────────────
    //
    // Strategy: parametric walk around the oval, sample N points,
    // draw as a series of tiny line segments so the stroke follows
    // the exact oval shape.
    //
    // The arc covers 35% of the oval perimeter and rotates with
    // arcProgress (0→1 = one full lap).

    final rx = domeRect.width / 2; // oval x-radius
    final ry = domeRect.height / 2; // oval y-radius
    final cx = domeRect.center.dx;
    final cy = domeRect.center.dy;

    const arcFraction = 0.35; // 35% of the oval
    const segments = 80; // smoothness

    final startT = arcProgress * math.pi * 2;
    final endT = startT + arcFraction * math.pi * 2;

    // Build gradient opacity along the arc: fade in, full, fade out
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

      // Fade in first 20%, full middle, fade out last 20%
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

    // Glowing tip dot at the leading end of the arc
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
