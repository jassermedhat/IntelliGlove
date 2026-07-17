// signup_screen.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../app_routes.dart';
import '../theme/theme_provider.dart';
import '../components/inputs.dart';
import '../services/auth_provider.dart';
import '../services/signup_validator.dart';
import '../components/toast.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen>
    with TickerProviderStateMixin {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _obscurePass = true;
  bool _obscureConfirm = true;

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
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _fadeCtrl.dispose();
    _arcCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final issue = validateSignup(
      name: name,
      email: email,
      password: _passwordCtrl.text,
      confirmPassword: _confirmCtrl.text,
    );
    if (issue != null) {
      toast.warning(title: issue.title, description: issue.description);
      return;
    }
    final auth = AuthProviderScope.of(context);
    await auth.register(name, email, _passwordCtrl.text);
    if (!mounted) return;
    if (auth.verificationSent) {
      toast.success(
        title: 'Account created',
        description:
            'We sent a verification link. Verify your email before signing in.',
      );
      context.go(AppRoutes.login);
    } else if (auth.errorMessage != null) {
      toast.error(title: 'Account not created', description: auth.errorMessage!);
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
    final backRowHeight = domeHeight * 0.5;

    final hPadding = (screenW * 0.065).clamp(20.0, 40.0);
    final backButtonSize = (screenW * 0.095).clamp(34.0, 42.0);
    final backIconSize = (screenW * 0.045).clamp(17.0, 21.0);

    final logoSize = (screenW * 0.20).clamp(64.0, 82.0);
    final logoRadius = (screenW * 0.055).clamp(18.0, 24.0);

    final logoToTitleGap = (screenH * 0.036).clamp(22.0, 32.0);
    final titleSize = (screenW * 0.068).clamp(22.0, 28.0);
    final subtitleSize = (screenW * 0.034).clamp(12.0, 14.0);

    final headerToCardGap = (screenH * 0.035).clamp(22.0, 32.0);
    final cardPadding = (screenW * 0.055).clamp(18.0, 24.0);
    final cardRadius = (screenW * 0.050).clamp(18.0, 22.0);

    final inputGap = (screenH * 0.020).clamp(14.0, 18.0);
    final buttonGap = (screenH * 0.025).clamp(16.0, 22.0);
    final buttonHeight = (screenH * 0.064).clamp(48.0, 54.0);
    final buttonRadius = (screenW * 0.035).clamp(12.0, 16.0);

    final buttonTextSize = (screenW * 0.038).clamp(14.0, 16.0);
    final smallTextSize = (screenW * 0.033).clamp(12.0, 14.0);

    final bottomGap = (screenH * 0.04).clamp(24.0, 36.0);
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
                // ── Back button row — sits just below dome ───────
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
                        onTap: () => context.pop(),
                        child: Container(
                          width: backButtonSize,
                          height: backButtonSize,
                          decoration: BoxDecoration(
                            color: t.accent.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: t.accent.withValues(alpha: 0.22),
                            ),
                          ),
                          child: Icon(
                            Icons.arrow_back_rounded,
                            size: backIconSize,
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
                          vertical: 0,
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: maxContentWidth,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // ── Logo + headline ─────────────
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
                                      'Create Account',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: titleSize,
                                        fontWeight: FontWeight.w900,
                                        color: t.foreground,
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      'Join the IntelliGlove community',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: t.mutedForeground,
                                        fontSize: subtitleSize,
                                      ),
                                    ),
                                  ],
                                ),

                                SizedBox(height: headerToCardGap),

                                // ── Form card ───────────────────
                                Container(
                                  padding: EdgeInsets.all(cardPadding),
                                  decoration: BoxDecoration(
                                    color: t.card,
                                    borderRadius: BorderRadius.circular(
                                      cardRadius,
                                    ),
                                    border: Border.all(
                                      color: t.accent.withValues(alpha: 0.15),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.04,
                                        ),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      AppLabel('Full Name'),
                                      const SizedBox(height: 6),
                                      AppInput(
                                        controller: _nameCtrl,
                                        hintText: 'John Doe',
                                        textInputAction: TextInputAction.next,
                                        prefixIcon: Icon(
                                          Icons.person_outline_rounded,
                                          size: 18,
                                          color: t.mutedForeground,
                                        ),
                                      ),

                                      SizedBox(height: inputGap),

                                      AppLabel('Email'),
                                      const SizedBox(height: 6),
                                      AppInput(
                                        controller: _emailCtrl,
                                        hintText: 'your.email@example.com',
                                        keyboardType:
                                            TextInputType.emailAddress,
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
                                        obscureText: _obscurePass,
                                        textInputAction: TextInputAction.next,
                                        prefixIcon: Icon(
                                          Icons.lock_outline_rounded,
                                          size: 18,
                                          color: t.mutedForeground,
                                        ),
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _obscurePass
                                                ? Icons.visibility_off_outlined
                                                : Icons.visibility_outlined,
                                            size: 18,
                                            color: t.mutedForeground,
                                          ),
                                          onPressed: () => setState(
                                            () => _obscurePass = !_obscurePass,
                                          ),
                                        ),
                                      ),

                                      SizedBox(height: inputGap),

                                      AppLabel('Confirm Password'),
                                      const SizedBox(height: 6),
                                      AppInput(
                                        controller: _confirmCtrl,
                                        hintText: '••••••••',
                                        obscureText: _obscureConfirm,
                                        textInputAction: TextInputAction.done,
                                        onSubmitted: (_) => _handleSignup(),
                                        prefixIcon: Icon(
                                          Icons.lock_outline_rounded,
                                          size: 18,
                                          color: t.mutedForeground,
                                        ),
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _obscureConfirm
                                                ? Icons.visibility_off_outlined
                                                : Icons.visibility_outlined,
                                            size: 18,
                                            color: t.mutedForeground,
                                          ),
                                          onPressed: () => setState(
                                            () => _obscureConfirm =
                                                !_obscureConfirm,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                SizedBox(height: buttonGap),

                                // ── Create Account button ────────
                                GestureDetector(
                                  onTap: _handleSignup,
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
                                          color: t.accent.withValues(
                                            alpha: 0.35,
                                          ),
                                          blurRadius: 16,
                                          offset: const Offset(0, 5),
                                        ),
                                      ],
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      'Create Account',
                                      style: TextStyle(
                                        fontSize: buttonTextSize,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ),
                                ),

                                SizedBox(height: buttonGap),

                                // ── Sign in link ─────────────────
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        'Already have an account? ',
                                        style: TextStyle(
                                          fontSize: smallTextSize,
                                          color: t.mutedForeground,
                                        ),
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () => context.go(AppRoutes.login),
                                      child: Text(
                                        'Sign In',
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
          ),
        ],
      ),
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
