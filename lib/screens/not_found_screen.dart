// not_found_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/theme_provider.dart';
import '../theme/app_colors.dart';
import '../components/inputs.dart';
import '../app_routes.dart';

class NotFoundScreen extends StatelessWidget {
  final String? attemptedPath;
  const NotFoundScreen({super.key, this.attemptedPath});

  @override
  Widget build(BuildContext context) {
    final t = ThemeProviderScope.of(context).tokens;
    // Mirror NotFound.tsx: log attempted path
    debugPrint(
      '404 Error: User attempted to access non-existent route: ${attemptedPath ?? 'unknown'}',
    );

    return Scaffold(
      backgroundColor: t.background,
      body: Stack(
        children: [
          Positioned(
            top: -120,
            right: -120,
            child: _Orb(color: t.accent.withValues(alpha: 0.05), size: 320),
          ),
          Positioned(
            bottom: 160,
            left: -80,
            child: _Orb(color: t.primary.withValues(alpha: 0.05), size: 240),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 24,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 48,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 404 badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [t.primary, t.primaryGlow],
                          ),
                          borderRadius: BorderRadius.circular(50),
                          boxShadow: [
                            BoxShadow(
                              color: t.primaryGlow.withValues(alpha: 0.4),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Text(
                          '404',
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            color: AppColors.white,
                            letterSpacing: -1.0,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Icon
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: t.muted.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.explore_off_rounded,
                            size: 36,
                            color: t.mutedForeground,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Headline
                      Text(
                        'Oops! Page Not Found',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: t.foreground,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'The page you are looking for does not exist\nor has been moved.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: t.mutedForeground,
                          height: 1.55,
                        ),
                      ),

                      // Attempted path display
                      if (attemptedPath != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: t.muted.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: t.border.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Text(
                            attemptedPath!,
                            style: TextStyle(
                              fontSize: 11,
                              fontFamily: 'monospace',
                              color: t.mutedForeground,
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 36),

                      // CTA
                      AppButton(
                        variant: AppButtonVariant.hero,
                        size: AppButtonSize.lg,
                        icon: const Icon(Icons.home_rounded, size: 18),
                        onPressed: () => context.go(AppRoutes.home),
                        child: const Text('Return to Home'),
                      ),
                      const SizedBox(height: 12),
                      AppButton(
                        variant: AppButtonVariant.ghost,
                        size: AppButtonSize.sm,
                        onPressed: () => context.pop(),
                        child: Text(
                          'Go Back',
                          style: TextStyle(color: t.mutedForeground),
                        ),
                      ),
                    ],
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
