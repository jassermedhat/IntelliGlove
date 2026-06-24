// services_screen.dart

import 'package:flutter/material.dart';
import '../components/app_layout.dart';
import 'package:go_router/go_router.dart';
import '../theme/theme_provider.dart';
import '../theme/app_colors.dart';
import '../components/inputs.dart';
import '../components/feature_card.dart';
import '../app_routes.dart';
import '../components/toast.dart';
import '../services/service_availability_controller.dart';

Future<void> _openBackendService(
  BuildContext context,
  String service,
  String route,
) async {
  try {
    if (await ServiceAvailabilityController.instance.isEnabled(service)) {
      if (context.mounted) context.push(route);
      return;
    }
  } catch (_) {
    // The destination will render its normal retryable backend error.
    if (context.mounted) context.push(route);
    return;
  }
  toast.warning(
    title: 'Feature unavailable',
    description: 'This feature is currently unavailable.',
  );
}

class ServicesScreen extends StatelessWidget {
  const ServicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = ThemeProviderScope.of(context).tokens;
    final isDark = ThemeProviderScope.of(context).isDark;

    return Scaffold(
      backgroundColor: t.background,
      body: Stack(
        children: [
          Positioned(
            top: 60,
            right: -60,
            child: _Orb(color: t.accent.withValues(alpha: 0.05), size: 240),
          ),
          Positioned(
            bottom: 160,
            left: -60,
            child: _Orb(color: t.primary.withValues(alpha: 0.05), size: 200),
          ),
          SafeArea(
            child: Column(
              children: [
                // Top bar
                _TopBar(t: t),

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
                        // Hero header
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
                              'SERVICES',
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
                          'Your Toolkit',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: t.foreground,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Every gesture, a word. Every word, a connection.\nIntelliGlove bridges the gap between hands and voices.',
                          style: TextStyle(
                            fontSize: 12,
                            color: t.mutedForeground,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Featured service card
                        _FeaturedCard(t: t, isDark: isDark),
                        const SizedBox(height: 24),

                        // All Services label
                        Row(
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
                              'OTHER SERVICES',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: t.mutedForeground,
                                letterSpacing: 1.8,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // SOS full-width FeatureCard
                        FeatureCard(
                          icon: Icons.phone_rounded,
                          title: 'SOS Alert',
                          description:
                              'Emergency assistance at your fingertips',
                          onTap: () => context.push(AppRoutes.servicesSos),
                        ),
                        const SizedBox(height: 10),

                        // 2-col: Practice Mode + Analytics
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: _CompactServiceCard(
                                  t: t,
                                  icon: Icons.track_changes_rounded,
                                  title: 'Practice Mode',
                                  description: 'Learn & practice sign gestures',
                                  onTap: () => _openBackendService(
                                    context,
                                    'practiceMode',
                                    AppRoutes.servicesPractice,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _CompactServiceCard(
                                  t: t,
                                  icon: Icons.bar_chart_rounded,
                                  title: 'Analytics',
                                  description:
                                      'Insights, trends & session data',
                                  onTap: () => _openBackendService(
                                    context,
                                    'analytics',
                                    AppRoutes.servicesAnalytics,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),

                        // 2-col: Smart Home + Guide
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: _CompactServiceCard(
                                  t: t,
                                  icon: Icons.home_rounded,
                                  title: 'Smart Home',
                                  description:
                                      'Control IoT devices with gestures',
                                  onTap: () => _openBackendService(
                                    context,
                                    'smartHouse',
                                    AppRoutes.servicesSmartHome,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _CompactServiceCard(
                                  t: t,
                                  icon: Icons.menu_book_rounded,
                                  title: 'User Guide',
                                  description: 'Setup & feature walkthroughs',
                                  onTap: () =>
                                      context.push(AppRoutes.servicesGuide),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Health Monitor full-width
                        FeatureCard(
                          icon: Icons.favorite_border_rounded,
                          title: 'Health Monitor',
                          description: 'Track vitals & wellness data',
                          onTap: () => _openBackendService(
                            context,
                            'healthMonitor',
                            AppRoutes.servicesHealth,
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

class _TopBar extends StatelessWidget {
  final AppColorTokens t;
  const _TopBar({required this.t});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minHeight: AppLayout.topBarHeight(context)),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: t.background.withValues(alpha: 0.75),
        border: Border(
          bottom: BorderSide(color: t.border.withValues(alpha: 0.3)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [t.primary, t.primaryGlow],
              ),
            ),
            child: Center(
              child: Icon(Icons.bolt_rounded, size: 18, color: AppColors.white),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'IntelliGlove',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: t.foreground,
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  final AppColorTokens t;
  final bool isDark;
  const _FeaturedCard({required this.t, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.accent.withValues(alpha: 0.2)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    t.primary.withValues(alpha: isDark ? 0.08 : 0.04),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -20,
            right: -20,
            child: _Orb(color: t.accent.withValues(alpha: 0.08), size: 100),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [t.primary, t.primaryGlow],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: t.primaryGlow.withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 24,
                          color: AppColors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Real-Time Translation',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: t.foreground,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Convert sign language gestures into text and speech instantly with our advanced AI engine.',
                  style: TextStyle(
                    fontSize: 12,
                    color: t.mutedForeground,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 14),
                AppButton(
                  variant: AppButtonVariant.accent,
                  size: AppButtonSize.sm,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                  onPressed: () => _openBackendService(
                    context,
                    'translation',
                    AppRoutes.servicesTranslate,
                  ),
                  child: const Text('Launch Now'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactServiceCard extends StatefulWidget {
  final AppColorTokens t;
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;
  const _CompactServiceCard({
    required this.t,
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  State<_CompactServiceCard> createState() => _CompactServiceCardState();
}

class _CompactServiceCardState extends State<_CompactServiceCard> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: t.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _pressed
                ? t.accent.withValues(alpha: 0.2)
                : t.border.withValues(alpha: 0.4),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _pressed ? 0.05 : 0.02),
              blurRadius: _pressed ? 10 : 3,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 38,
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [t.primary, t.primaryGlow],
                ),
              ),
              child: Center(
                child: Icon(widget.icon, size: 18, color: AppColors.white),
              ),
            ),
            Text(
              widget.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _pressed ? t.accent : t.foreground,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              widget.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                color: t.mutedForeground,
                height: 1.4,
              ),
            ),
          ],
        ),
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
