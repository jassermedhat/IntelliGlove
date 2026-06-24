import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/theme_provider.dart';
import '../theme/app_colors.dart';
import '../components/inputs.dart';
import '../components/display.dart';
import '../components/glove_status.dart';
import '../components/glove_visualization.dart';
import '../services/auth_provider.dart';
import '../services/glove_state_provider.dart';
import '../app_routes.dart';
import '../components/toast.dart';
import '../components/app_async_state.dart';
import '../components/app_layout.dart';
import '../models/app_alert.dart';
import '../models/load_status.dart';
import '../services/alerts_controller.dart';
import '../services/service_availability_controller.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final bool _sessionActive = false;

  Future<void> _openTranslation() async {
    try {
      if (await ServiceAvailabilityController.instance.isEnabled(
        'translation',
      )) {
        if (mounted) context.push(AppRoutes.servicesTranslate);
        return;
      }
      toast.warning(
        title: 'Feature unavailable',
        description: 'This feature is currently unavailable.',
      );
    } catch (_) {
      if (mounted) context.push(AppRoutes.servicesTranslate);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ThemeProviderScope.of(context).tokens;
    final isDark = ThemeProviderScope.of(context).isDark;
    final alerts = AlertsScope.of(context);

    return Scaffold(
      backgroundColor: t.background,
      body: Stack(
        children: [
          // Background orbs
          Positioned(
            top: -120,
            right: -120,
            child: _Orb(color: t.accent.withValues(alpha: 0.05), size: 320),
          ),
          Positioned(
            top: MediaQuery.of(context).size.height * 0.33,
            left: -100,
            child: _Orb(color: t.primary.withValues(alpha: 0.05), size: 240),
          ),
          Positioned(
            bottom: 60,
            right: 30,
            child: _Orb(color: t.accent.withValues(alpha: 0.03), size: 160),
          ),

          SafeArea(
            child: Column(
              children: [
                // ── Glassy top bar ──────────────────────────
                _TopBar(t: t),

                // ── Scrollable body ─────────────────────────
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
                        // HERO split
                        _HeroSection(
                          t: t,
                          sessionActive: _sessionActive,
                          onToggleSession: _openTranslation,
                        ),
                        const SizedBox(height: 28),

                        // CONNECTION STATUS — from GloveStateProvider
                        Builder(
                          builder: (context) {
                            final glove = GloveStateScope.of(context);
                            final device = glove.pairedDevice;
                            final isConnected = glove.isConnected;
                            return GloveStatus(
                              gloveName: device?.name ?? 'IntelliGlove',
                              batteryLevel: isConnected
                                  ? device?.batteryLevel ?? 0
                                  : 0,
                              isConnected: isConnected,
                              signalStrength: isConnected
                                  ? device?.signalStrength ?? 0
                                  : 0,
                            );
                          },
                        ),
                        const SizedBox(height: 28),

                        // LIVE PREVIEW
                        _SectionLabel(t: t, label: 'Live Preview'),
                        const SizedBox(height: 12),
                        _LivePreviewCard(t: t, sessionActive: _sessionActive),
                        const SizedBox(height: 28),

                        // ALERTS
                        HomeAlertsPanel(t: t, controller: alerts),
                        const SizedBox(height: 28),

                        // NEED HELP CTA
                        _BottomCta(t: t, isDark: isDark),
                        const SizedBox(height: 28),
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
    final isConnected = GloveStateScope.of(context).isConnected;
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
          // Logo + status dot
          Stack(
            clipBehavior: Clip.none,
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
                  child: Icon(
                    Icons.bolt_rounded,
                    size: 18,
                    color: AppColors.white,
                  ),
                ),
              ),
              Positioned(
                top: -1,
                right: -1,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isConnected ? t.success : t.destructive,
                    border: Border.all(color: t.background, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'IntelliGlove',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: t.foreground,
                ),
              ),
            ],
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

// ── Hero Section ──────────────────────────────────────────────

class _HeroSection extends StatelessWidget {
  final AppColorTokens t;
  final bool sessionActive;
  final VoidCallback onToggleSession;
  const _HeroSection({
    required this.t,
    required this.sessionActive,
    required this.onToggleSession,
  });

  @override
  Widget build(BuildContext context) {
    final isConnected = GloveStateScope.of(context).isConnected;
    final subtitle = isConnected
        ? 'Your glove is connected and\nperforming optimally.'
        : 'Pair your glove to start\nusing IntelliGlove features.';

    return LayoutBuilder(
      builder: (context, constraints) {
        // On small screens (< 360px wide) collapse the logo
        final logoSize = constraints.maxWidth < 360 ? 80.0 : 120.0;
        final showLogo = constraints.maxWidth >= 300;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                        'HOME',
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
                  RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: t.foreground,
                        height: 1.1,
                        letterSpacing: -0.3,
                      ),
                      children: [
                        const TextSpan(text: 'Welcome\n'),
                        TextSpan(
                          text:
                              'back, ${AuthProviderScope.of(context).userName.split(' ').first}',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: t.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isConnected
                          ? t.mutedForeground
                          : t.accent.withValues(alpha: 0.8),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          variant: sessionActive
                              ? AppButtonVariant.destructive
                              : AppButtonVariant.hero,
                          size: AppButtonSize.sm,
                          onPressed: () {
                            if (!isConnected) {
                              toast.action(
                                message:
                                    'No glove connected. Pair your device first.',
                                actionLabel: 'Pair Device',
                                onAction: () =>
                                    context.push(AppRoutes.profileDevices),
                              );
                              return;
                            }
                            onToggleSession();
                          },
                          child: Text(
                            sessionActive ? 'Stop Session' : 'Start Session',
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: AppButton(
                          variant: AppButtonVariant.outline,
                          size: AppButtonSize.sm,
                          onPressed: () =>
                              context.push(AppRoutes.profileDevices),
                          child: const Text(
                            'Devices',
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (showLogo) ...[
              const SizedBox(width: 16),
              SizedBox(
                width: logoSize,
                height: logoSize,
                child: Image.asset('assets/logo_app.png', fit: BoxFit.contain),
              ),
            ],
          ],
        );
      },
    );
  }
}

// ── Live Preview Card ────────────────────────────────────────

class _LivePreviewCard extends StatelessWidget {
  final AppColorTokens t;
  final bool sessionActive;
  const _LivePreviewCard({required this.t, required this.sessionActive});

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: sessionActive ? 1.0 : 0.35,
      duration: const Duration(milliseconds: 400),
      child: Stack(
        children: [
          AppCard(
            onTap: sessionActive ? () {} : null,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: GloveVisualization(
                size: GloveSize.lg,
                isActive: sessionActive,
              ),
            ),
          ),
          if (!sessionActive)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: t.background.withValues(alpha: 0.45),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: t.card.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: t.border.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.sensors_off_rounded,
                              size: 24,
                              color: t.mutedForeground,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Session not started',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: t.mutedForeground,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Tap "Start Session" to activate',
                              style: TextStyle(
                                fontSize: 10,
                                color: t.mutedForeground.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// // ── Primary Action Card ──────────────────────────────────────
//
// class _PrimaryActionCard extends StatelessWidget {
//   final AppColorTokens t;
//   final bool isDark;
//   const _PrimaryActionCard({required this.t, required this.isDark});
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       decoration: BoxDecoration(
//         color: t.card,
//         borderRadius: BorderRadius.circular(16),
//         border: Border.all(color: t.accent.withValues(alpha: 0.2)),
//       ),
//       clipBehavior: Clip.antiAlias,
//       child: Stack(
//         children: [
//           Positioned.fill(
//             child: Container(
//               decoration: BoxDecoration(
//                 gradient: LinearGradient(
//                   begin: Alignment.topLeft,
//                   end: Alignment.bottomRight,
//                   colors: [t.primary.withValues(alpha: isDark ? 0.10 : 0.05), Colors.transparent],
//                 ),
//               ),
//             ),
//           ),
//           Positioned(bottom: -20, right: -20,
//             child: _Orb(color: t.accent.withValues(alpha: 0.08), size: 100)),
//           Padding(
//             padding: const EdgeInsets.all(20),
//             child: Row(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Container(
//                   width: 52,
//                   height: 52,
//                   decoration: BoxDecoration(
//                     color: t.accent.withValues(alpha: isDark ? 0.2 : 0.1),
//                     borderRadius: BorderRadius.circular(16),
//                   ),
//                   child: Center(child: Icon(Icons.auto_awesome_rounded, size: 24, color: t.accent)),
//                 ),
//                 const SizedBox(width: 14),
//                 Expanded(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       Text('Real-Time Translation',
//                         style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: t.foreground)),
//                       const SizedBox(height: 4),
//                       Text('Start translating your gestures into text and speech instantly.',
//                         style: TextStyle(fontSize: 11, color: t.mutedForeground, height: 1.5)),
//                       const SizedBox(height: 12),
//                       AppButton(
//                         variant: AppButtonVariant.accent,
//                         size: AppButtonSize.sm,
//                         icon: const Icon(Icons.chevron_right_rounded, size: 14),
//                         onPressed: () => context.go('/translate'),
//                         child: const Text('Launch Translator'),
//                       ),
//                     ],
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// ── Alerts Section ───────────────────────────────────────────

class HomeAlertsPanel extends StatelessWidget {
  final AppColorTokens t;
  final AlertsController controller;
  const HomeAlertsPanel({super.key, required this.t, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _SectionLabel(t: t, label: 'Alerts & Updates'),
            GestureDetector(
              onTap: () => context.push(AppRoutes.profileDeviceUpdates),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'View all',
                    style: TextStyle(
                      fontSize: 11,
                      color: t.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, size: 12, color: t.accent),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (controller.status == LoadStatus.loading)
          const AppLoadingState(message: 'Loading alerts...')
        else if (controller.status == LoadStatus.error)
          AppErrorState(
            title: 'Alerts unavailable',
            message: controller.error ?? 'Could not load alerts.',
            actionLabel: 'Retry',
            onAction: controller.refresh,
            card: true,
          )
        else if (controller.status == LoadStatus.empty)
          const AppEmptyState(
            title: 'No alerts',
            message: 'You are all caught up.',
            card: true,
          )
        else
          ...controller.latestAlerts.map((alert) {
            final color = switch (alert.type) {
              AppAlertType.info => t.accent,
              AppAlertType.success => t.success,
              AppAlertType.warning => Colors.orange,
              AppAlertType.error => t.destructive,
            };
            final icon = switch (alert.type) {
              AppAlertType.info => Icons.info_outline_rounded,
              AppAlertType.success => Icons.check_circle_outline_rounded,
              AppAlertType.warning => Icons.warning_amber_rounded,
              AppAlertType.error => Icons.error_outline_rounded,
            };
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: t.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: t.border.withValues(alpha: 0.4)),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => controller.markRead(alert.id),
                child: Row(
                  children: [
                    Container(width: 4, color: color),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(icon, size: 16, color: color),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                alert.message,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: t.foreground,
                                  height: 1.4,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            AppBadge(
                              label: alert.isRead ? 'Read' : 'New',
                              variant: !alert.isRead
                                  ? AppBadgeVariant.primary
                                  : AppBadgeVariant.secondary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

// // ── Bottom CTA ───────────────────────────────────────────────
//
// class _BottomCta extends StatelessWidget {
//   final AppColorTokens t;
//   final bool isDark;
//   const _BottomCta({required this.t, required this.isDark});
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.all(18),
//       decoration: BoxDecoration(
//         color: t.card,
//         borderRadius: BorderRadius.circular(14),
//         border: Border.all(color: t.border.withValues(alpha: 0.4)),
//         gradient: LinearGradient(
//           begin: Alignment.centerLeft,
//           end: Alignment.centerRight,
//           colors: [
//             t.accent.withValues(alpha: isDark ? 0.1 : 0.05),
//             t.primary.withValues(alpha: isDark ? 0.1 : 0.05),
//           ],
//         ),
//       ),
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Text('Explore all features',
//             style: TextStyle(fontSize: 11, color: t.mutedForeground, fontWeight: FontWeight.w500)),
//           const SizedBox(height: 10),
//           AppButton(
//             variant: AppButtonVariant.outline,
//             size: AppButtonSize.sm,
//             icon: const Icon(Icons.chevron_right_rounded, size: 14),
//             onPressed: () => context.go('/services'),
//             child: const Text('View All Services'),
//           ),
//         ],
//       ),
//     );
//   }
// }

// ── Bottom CTA ────────────────────────────────────────────────

class _BottomCta extends StatelessWidget {
  final AppColorTokens t;
  final bool isDark;
  const _BottomCta({required this.t, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.border.withValues(alpha: 0.4)),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            t.accent.withValues(alpha: isDark ? 0.1 : 0.05),
            t.primary.withValues(alpha: isDark ? 0.1 : 0.05),
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Need help getting started?',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: t.foreground,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Check out our quick-start guide for new users.',
            style: TextStyle(fontSize: 11, color: t.mutedForeground),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          AppButton(
            variant: AppButtonVariant.outline,
            size: AppButtonSize.sm,
            icon: const Icon(Icons.chevron_right_rounded, size: 14),
            onPressed: () => context.push(AppRoutes.servicesGuide),
            child: const Text('View Guide'),
          ),
        ],
      ),
    );
  }
}

// ── Shared helpers ───────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final AppColorTokens t;
  final String label;
  const _SectionLabel({required this.t, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
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
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: t.mutedForeground,
            letterSpacing: 1.8,
          ),
        ),
      ],
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
