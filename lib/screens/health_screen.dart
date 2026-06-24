// health_screen.dart

import 'package:flutter/material.dart';
import '../components/app_layout.dart';
import 'package:go_router/go_router.dart';
import '../theme/theme_provider.dart';
import '../theme/app_colors.dart';
import '../services/glove_state_provider.dart';
import '../app_routes.dart';
import '../models/load_status.dart';
import '../services/health_controller.dart';
import '../components/app_async_state.dart';

class HealthScreen extends StatefulWidget {
  const HealthScreen({super.key});

  @override
  State<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends State<HealthScreen> {
  late final HealthController _controller;
  bool? _lastConnected;

  @override
  void initState() {
    super.initState();
    _controller = HealthController()..addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = ThemeProviderScope.of(context).tokens;
    final isDark = ThemeProviderScope.of(context).isDark;
    final isConnected = GloveStateScope.of(context).isConnected;
    if (_lastConnected != isConnected) {
      _lastConnected = isConnected;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _controller.load(isConnected: isConnected),
      );
    }
    final vitals = _controller.vitals;

    return Scaffold(
      backgroundColor: t.background,
      body: Stack(
        children: [
          Positioned(
            top: -120,
            right: -120,
            child: _Orb(
              color: t.destructive.withValues(alpha: 0.05),
              size: 320,
            ),
          ),
          Positioned(
            bottom: MediaQuery.of(context).size.height * 0.33,
            left: -100,
            child: _Orb(color: t.accent.withValues(alpha: 0.05), size: 240),
          ),
          SafeArea(
            child: Column(
              children: [
                // Top bar
                Container(
                  constraints: BoxConstraints(
                    minHeight: AppLayout.topBarHeight(context),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: t.background.withValues(alpha: 0.75),
                    border: Border(
                      bottom: BorderSide(
                        color: t.border.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: t.destructive.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.favorite_border_rounded,
                            size: 18,
                            color: t.destructive,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Health',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: t.foreground,
                            ),
                          ),
                          Text(
                            'Live Monitoring',
                            style: TextStyle(
                              fontSize: 10,
                              color: t.mutedForeground,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                    ],
                  ),
                ),

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
                        // Disconnected warning banner
                        if (!isConnected) ...[
                          GestureDetector(
                            onTap: () =>
                                context.push(AppRoutes.profileDevicePairing),
                            child: Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: t.destructive.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: t.destructive.withValues(alpha: 0.25),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.bluetooth_disabled_rounded,
                                    size: 16,
                                    color: t.destructive,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'No glove connected. Health data unavailable. Tap to pair.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: t.destructive,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    size: 16,
                                    color: t.destructive,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        if (isConnected &&
                            _controller.status == LoadStatus.loading) ...[
                          const AppLoadingState(
                            message: 'Loading health data...',
                          ),
                          const SizedBox(height: 20),
                        ],
                        if (_controller.status == LoadStatus.error) ...[
                          AppErrorState(
                            message:
                                _controller.error ??
                                'Health data is unavailable.',
                            onAction: () =>
                                _controller.load(isConnected: isConnected),
                          ),
                          const SizedBox(height: 20),
                        ],
                        // Hero
                        Row(
                          children: [
                            Container(
                              width: 28,
                              height: 4,
                              decoration: BoxDecoration(
                                color: t.destructive,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'VITALS',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: t.destructive,
                                letterSpacing: 2.5,
                              ),
                            ),
                            if (vitals.isDemo) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: t.accent.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'DEMO',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: t.accent,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 10),
                        RichText(
                          text: TextSpan(
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: t.foreground,
                              letterSpacing: -0.3,
                              height: 1.1,
                            ),
                            children: [
                              const TextSpan(text: 'Health\n'),
                              TextSpan(
                                text: 'Monitoring',
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
                          'Real-time health metrics from your IntelliGlove sensors.',
                          style: TextStyle(
                            fontSize: 12,
                            color: t.mutedForeground,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Primary Metric (Heart Rate)
                        _HeartRateCard(
                          t: t,
                          isDark: isDark,
                          isConnected: isConnected,
                          value: vitals.heartRate,
                        ),
                        const SizedBox(height: 20),

                        // All metrics label
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
                              'ALL METRICS',
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

                        // 2-col metrics grid
                        // Blood Pressure + Blood Oxygen
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _MetricCard(
                                t: t,
                                icon: Icons.show_chart_rounded,
                                iconColor: t.accent,
                                bgColor: t.accent.withValues(alpha: 0.1),
                                label: 'Blood Pressure',
                                value: vitals.bloodPressure ?? '--',
                                unit: 'mmHg',
                                status: 'normal',
                                isConnected: isConnected,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _MetricCard(
                                t: t,
                                icon: Icons.water_drop_outlined,
                                iconColor: t.secondary,
                                bgColor: t.secondary.withValues(alpha: 0.1),
                                label: 'Blood Oxygen',
                                value: vitals.bloodOxygen?.toString() ?? '--',
                                unit: '%',
                                status: 'normal',
                                isConnected: isConnected,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Emotion full-width
                        _EmotionCard(
                          t: t,
                          isConnected: isConnected,
                          emotion: vitals.emotion,
                          activeEmotion: vitals.activeEmotion,
                        ),
                        const SizedBox(height: 10),

                        // Respiratory full-width
                        _MetricCard(
                          t: t,
                          icon: Icons.air_rounded,
                          iconColor: t.accent,
                          bgColor: t.accent.withValues(alpha: 0.1),
                          label: 'Respiratory Rate',
                          value: vitals.respiratoryRate?.toString() ?? '--',
                          unit: 'breaths/min',
                          status: 'normal',
                          fullWidth: true,
                          isConnected: isConnected,
                        ),
                        const SizedBox(height: 24),

                        // Summary
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: t.card,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: t.border.withValues(alpha: 0.4),
                            ),
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                t.accent.withValues(alpha: isDark ? 0.1 : 0.05),
                                t.primary.withValues(
                                  alpha: isDark ? 0.1 : 0.05,
                                ),
                              ],
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Overall Health Status',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: t.foreground,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                isConnected
                                    ? 'Connected values are demonstration data until real health sensors are integrated.'
                                    : 'Connect a glove to view available health information.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: t.mutedForeground,
                                  height: 1.5,
                                ),
                              ),
                            ],
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

class _HeartRateCard extends StatelessWidget {
  final AppColorTokens t;
  final bool isDark;
  final bool isConnected;
  final int? value;
  const _HeartRateCard({
    required this.t,
    required this.isDark,
    required this.isConnected,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.destructive.withValues(alpha: 0.2)),
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
                    t.destructive.withValues(alpha: isDark ? 0.08 : 0.04),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -24,
            right: -24,
            child: _Orb(
              color: t.destructive.withValues(alpha: 0.05),
              size: 100,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.favorite_border_rounded,
                          size: 16,
                          color: t.destructive,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'HEART RATE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: t.destructive,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          value?.toString() ?? '--',
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            color: t.foreground,
                            letterSpacing: -1.5,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'bpm',
                          style: TextStyle(
                            fontSize: 13,
                            color: t.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isConnected ? t.success : t.mutedForeground,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          isConnected ? 'Normal range' : 'No data',
                          style: TextStyle(
                            fontSize: 10,
                            color: isConnected ? t.success : t.mutedForeground,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: t.destructive.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Center(child: _AnimatedHeart(color: t.destructive)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final AppColorTokens t;
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final String label;
  final String value;
  final String unit;
  final String status;
  final bool fullWidth;
  final bool isConnected;
  const _MetricCard({
    required this.t,
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.label,
    required this.value,
    required this.unit,
    required this.status,
    this.fullWidth = false,
    this.isConnected = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.border.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(child: Icon(icon, size: 18, color: iconColor)),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 9,
                    color: t.mutedForeground,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: t.foreground,
                ),
              ),
              if (unit.isNotEmpty && isConnected) ...[
                const SizedBox(width: 4),
                Text(
                  unit,
                  style: TextStyle(fontSize: 10, color: t.mutedForeground),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isConnected ? t.success : t.mutedForeground,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                isConnected ? status : 'No data',
                style: TextStyle(
                  fontSize: 10,
                  color: isConnected ? t.success : t.mutedForeground,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmotionCard extends StatelessWidget {
  final AppColorTokens t;
  final bool isConnected;
  final String? emotion;
  final int? activeEmotion;
  const _EmotionCard({
    required this.t,
    this.isConnected = true,
    this.emotion,
    this.activeEmotion,
  });

  @override
  Widget build(BuildContext context) {
    const emojis = ['😨', '😠', '😊', '😰'];
    const labels = ['Afraid', 'Angry', 'Happy', 'Stressed'];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.border.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: t.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Icon(
                    Icons.psychology_outlined,
                    size: 18,
                    color: t.success,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'EMOTION',
                style: TextStyle(
                  fontSize: 9,
                  color: t.mutedForeground,
                  letterSpacing: 0.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                emotion ?? '--',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: t.foreground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [0, 1, 2, 3].map((i) {
              final isActive = isConnected && i == activeEmotion;
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: i < 3 ? 6 : 0),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isActive
                        ? t.success.withValues(alpha: 0.12)
                        : t.muted.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(12),
                    border: isActive
                        ? Border.all(color: t.success.withValues(alpha: 0.3))
                        : null,
                  ),
                  child: Text(
                    emojis[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      color: isConnected ? null : Colors.grey,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Text(
            labels.join(' · '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9,
              color: t.mutedForeground,
              letterSpacing: 1.0,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _AnimatedHeart extends StatefulWidget {
  final Color color;
  const _AnimatedHeart({required this.color});
  @override
  State<_AnimatedHeart> createState() => _AnimatedHeartState();
}

class _AnimatedHeartState extends State<_AnimatedHeart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, __) => Transform.scale(
      scale: 0.9 + _c.value * 0.15,
      child: Icon(Icons.favorite_rounded, size: 28, color: widget.color),
    ),
  );
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
