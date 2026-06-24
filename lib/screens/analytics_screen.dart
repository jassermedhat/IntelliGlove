// analytics_screen.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../components/app_layout.dart';
import '../theme/app_colors.dart';
import '../theme/theme_provider.dart';
import '../models/load_status.dart';
import '../repositories/analytics_repository.dart';
import '../services/analytics_controller.dart';
import '../components/app_async_state.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  late final PageController _pageController;
  late final AnalyticsController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnalyticsController()..addListener(_refresh);
    _pageController = PageController(
      initialPage: _controller.selectedRange.index,
    );
    _controller.loadAll();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _pageController.dispose();
    _controller
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  static const _ranges = ['Day', 'Week', 'Month'];

  // ── Static data per range ────────────────────────────────────────────────

  // Day (24h, shown as 8 selected hours)

  // Weekly gesture counts (Mon–Sun)

  // Accuracy over 7 days

  // Session minutes per day this week

  // Month (4 weeks)

  // Top gestures

  // Helpers
  @override
  Widget build(BuildContext context) {
    final t = ThemeProviderScope.of(context).tokens;
    final isDark = ThemeProviderScope.of(context).isDark;

    return Scaffold(
      backgroundColor: t.background,
      body: Stack(
        children: [
          // Background orbs — same positions/sizes as home
          Positioned(
            top: -60,
            right: 0,
            child: _Orb(color: t.accent.withValues(alpha: 0.05), size: 280),
          ),
          Positioned(
            bottom: 160,
            left: -60,
            child: _Orb(color: t.primary.withValues(alpha: 0.05), size: 220),
          ),

          SafeArea(
            child: Column(
              children: [
                // ── Top bar ──────────────────────────────────
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
                          color: const Color(0x1A3B82F6),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.analytics_rounded,
                            size: 18,
                            color: Color(0xFF3B82F6),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Analytics',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: t.foreground,
                            ),
                          ),
                          Text(
                            'Insights',
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

                // ── Static header + range selector ────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
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
                            'ANALYTICS',
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
                        'Performance',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: t.foreground,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Your session insights & gesture analytics',
                        style: TextStyle(
                          fontSize: 13,
                          color: t.mutedForeground,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _RangeSelector(
                        t: t,
                        isDark: isDark,
                        selected: _controller.selectedRange.index,
                        labels: _ranges,
                        onSelect: (i) {
                          _controller.selectRange(AnalyticsRange.values[i]);
                          _pageController.animateToPage(
                            i,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                      ),
                      const SizedBox(height: 4),
                    ],
                  ),
                ),

                // ── Swipeable data area ─────────────────────────────────────
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    physics: const ClampingScrollPhysics(),
                    onPageChanged: (i) =>
                        _controller.selectRange(AnalyticsRange.values[i]),
                    itemCount: 3,
                    itemBuilder: (_, index) {
                      final range = AnalyticsRange.values[index];
                      final status = _controller.statusFor(range);
                      final data = _controller.dataFor(range);
                      if (status == LoadStatus.loading ||
                          status == LoadStatus.initial) {
                        return const AppLoadingState(
                          message: 'Loading analytics...',
                        );
                      }
                      if (status == LoadStatus.error) {
                        return AppErrorState(
                          message:
                              _controller.errorFor(range) ??
                              'Analytics could not be loaded.',
                          onAction: () => _controller.retry(range),
                        );
                      }
                      if (status == LoadStatus.empty || data == null) {
                        return AppEmptyState(
                          icon: Icons.analytics_outlined,
                          message: 'No analytics are available for this range.',
                          actionLabel: 'Refresh',
                          onAction: () => _controller.retry(range),
                        );
                      }
                      final gestures = data.gestures;
                      final labels = data.labels;
                      final accuracy = data.accuracy;
                      final minutes = data.sessionMinutes;
                      return SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          20,
                          16,
                          20,
                          AppLayout.bottomNavClearance(context),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── Summary stats ─────────────────────────────────
                            _SectionLabel(t: t, label: 'SUMMARY'),
                            const SizedBox(height: 12),
                            _SummaryRow(t: t, rangeIndex: index, data: data),
                            const SizedBox(height: 24),

                            // ── Gesture count bar chart ────────────────────────
                            _SectionLabel(t: t, label: 'GESTURE INDEX'),
                            const SizedBox(height: 12),
                            _GestureBarChart(
                              t: t,
                              isDark: isDark,
                              values: gestures,
                              labels: labels,
                              rangeIndex: index,
                            ),
                            const SizedBox(height: 24),

                            // ── Accuracy line chart ────────────────────────────
                            _SectionLabel(t: t, label: 'ACCURACY TREND'),
                            const SizedBox(height: 12),
                            _AccuracyLineChart(
                              t: t,
                              isDark: isDark,
                              values: accuracy,
                              labels: labels,
                            ),
                            const SizedBox(height: 24),

                            // ── Session time chart ─────────────────────────────
                            _SectionLabel(t: t, label: 'SESSION TIME'),
                            const SizedBox(height: 12),
                            _SessionTimeChart(
                              t: t,
                              isDark: isDark,
                              minutes: minutes,
                              labels: labels,
                            ),
                            const SizedBox(height: 24),

                            // ── Top gestures ──────────────────────────────────
                            _SectionLabel(t: t, label: 'TOP GESTURES'),
                            const SizedBox(height: 12),
                            _TopGesturesCard(t: t, gestures: data.topGestures),
                            const SizedBox(height: 24),

                            // ── Recognition quality ────────────────────────────
                            _SectionLabel(t: t, label: 'RECOGNITION QUALITY'),
                            const SizedBox(height: 12),
                            _RecognitionQualityCard(t: t, isDark: isDark),
                            const SizedBox(height: 8),
                          ],
                        ),
                      );
                    },
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

// ── Range Selector ─────────────────────────────────────────

class _RangeSelector extends StatelessWidget {
  final AppColorTokens t;
  final bool isDark;
  final int selected;
  final List<String> labels;
  final ValueChanged<int> onSelect;
  const _RangeSelector({
    required this.t,
    required this.isDark,
    required this.selected,
    required this.labels,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: t.muted.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.border.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: labels.asMap().entries.map((e) {
          final isSelected = e.key == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelect(e.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? t.card : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: t.border.withValues(alpha: 0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  e.value,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? t.accent : t.mutedForeground,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Summary Row (Gesture Index, Session Time, Accuracy) ─────

class _SummaryRow extends StatelessWidget {
  final AppColorTokens t;
  final int rangeIndex; // 0=Day, 1=Week, 2=Month
  final AnalyticsData data;
  const _SummaryRow({
    required this.t,
    required this.rangeIndex,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final totalGestures = data.gestures.fold<int>(
      0,
      (sum, value) => sum + value,
    );
    final totalMinutes = data.sessionMinutes.fold<int>(
      0,
      (sum, value) => sum + value,
    );
    final averageAccuracy = data.accuracy.isEmpty
        ? 0.0
        : data.accuracy.reduce((a, b) => a + b) / data.accuracy.length;
    final period = rangeIndex == 0
        ? 'Today'
        : rangeIndex == 1
        ? 'Week'
        : 'Month';
    final stats = [
      (
        label: 'Gestures\n$period',
        value: '$totalGestures',
        change: 'Recorded',
        icon: Icons.trending_up_rounded,
      ),
      (
        label: 'Session\nTime',
        value: '${totalMinutes ~/ 60}h ${totalMinutes % 60}m',
        change: 'Total',
        icon: Icons.access_time_rounded,
      ),
      (
        label: 'Accuracy',
        value: '${averageAccuracy.toStringAsFixed(1)}%',
        change: 'Average',
        icon: Icons.bar_chart_rounded,
      ),
    ];
    return Row(
      children: stats.asMap().entries.map((e) {
        final s = e.value;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: e.key < stats.length - 1 ? 10 : 0),
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
                Icon(s.icon, size: 16, color: t.accent),
                const SizedBox(height: 6),
                Text(
                  s.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: t.foreground,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  s.label,
                  style: TextStyle(
                    fontSize: 8,
                    color: t.mutedForeground,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.0,
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 2),
                Text(
                  s.change,
                  style: TextStyle(
                    fontSize: 9,
                    color: t.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Gesture Bar Chart ────────────────────────────────────────

class _GestureBarChart extends StatelessWidget {
  final AppColorTokens t;
  final bool isDark;
  final List<int> values;
  final List<String> labels;
  final int rangeIndex;
  const _GestureBarChart({
    required this.t,
    required this.isDark,
    required this.values,
    required this.labels,
    required this.rangeIndex,
  });

  @override
  Widget build(BuildContext context) {
    final maxVal = values.reduce(math.max).toDouble();
    // highlight the last item (most recent) in any range
    final highlightIdx = values.length - 1;
    final rangeLabel = rangeIndex == 0
        ? 'Today'
        : rangeIndex == 1
        ? 'This Week'
        : 'This Month';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.border.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${values.reduce((a, b) => a + b)} total',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: t.foreground,
                  letterSpacing: -0.3,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: t.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  rangeLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: t.accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Gestures detected',
            style: TextStyle(fontSize: 11, color: t.mutedForeground),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: values.asMap().entries.map((e) {
                final ratio = e.value / maxVal;
                final isHighlight = e.key == highlightIdx;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: e.key < values.length - 1 ? 6 : 0,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '${e.value}',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: isHighlight ? t.accent : t.mutedForeground,
                          ),
                        ),
                        const SizedBox(height: 4),
                        AnimatedContainer(
                          duration: Duration(milliseconds: 400 + e.key * 60),
                          curve: Curves.easeOut,
                          height: 90 * ratio,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            gradient: isHighlight
                                ? LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [
                                      t.accent,
                                      t.accent.withValues(alpha: 0.6),
                                    ],
                                  )
                                : LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [
                                      t.primary.withValues(
                                        alpha: isDark ? 0.5 : 0.35,
                                      ),
                                      t.primary.withValues(
                                        alpha: isDark ? 0.25 : 0.15,
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: labels.asMap().entries.map((e) {
              final isHighlight = e.key == highlightIdx;
              return Expanded(
                child: Text(
                  e.value,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: isHighlight ? FontWeight.w800 : FontWeight.w500,
                    color: isHighlight ? t.accent : t.mutedForeground,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ── Accuracy Line Chart ──────────────────────────────────────

class _AccuracyLineChart extends StatelessWidget {
  final AppColorTokens t;
  final bool isDark;
  final List<double> values;
  final List<String> labels;
  const _AccuracyLineChart({
    required this.t,
    required this.isDark,
    required this.values,
    required this.labels,
  });

  @override
  Widget build(BuildContext context) {
    final minVal = values.reduce(math.min);
    final maxVal = values.reduce(math.max);
    final range = maxVal - minVal;
    final avg = values.reduce((a, b) => a + b) / values.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.border.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${values.last.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: t.foreground,
                      letterSpacing: -0.3,
                    ),
                  ),
                  Text(
                    'Latest accuracy',
                    style: TextStyle(fontSize: 11, color: t.mutedForeground),
                  ),
                ],
              ),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: t.success.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.trending_up_rounded,
                            size: 10,
                            color: t.success,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${(values.last - values.first).toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: t.success,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'avg ${avg.toStringAsFixed(1)}%',
                      style: TextStyle(fontSize: 10, color: t.mutedForeground),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 80,
            child: CustomPaint(
              size: const Size(double.infinity, 80),
              painter: _LineChartPainter(
                values: values
                    .map((v) => (v - minVal) / (range == 0 ? 1 : range))
                    .toList(),
                lineColor: t.accent,
                fillColor: t.accent.withValues(alpha: isDark ? 0.12 : 0.08),
                dotColor: t.accent,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: labels
                .asMap()
                .entries
                .map(
                  (e) => Expanded(
                    child: Text(
                      e.value,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                        color: t.mutedForeground,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<double> values;
  final Color lineColor;
  final Color fillColor;
  final Color dotColor;
  const _LineChartPainter({
    required this.values,
    required this.lineColor,
    required this.fillColor,
    required this.dotColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final count = values.length;
    final pts = <Offset>[];

    for (int i = 0; i < count; i++) {
      final x = i / (count - 1) * size.width;
      final y =
          size.height - values[i] * size.height * 0.85 - size.height * 0.075;
      pts.add(Offset(x, y));
    }

    // Fill path
    final fillPath = Path()..moveTo(pts.first.dx, size.height);
    for (final p in pts) {
      fillPath.lineTo(p.dx, p.dy);
    }
    fillPath.lineTo(pts.last.dx, size.height);
    fillPath.close();
    canvas.drawPath(
      fillPath,
      Paint()
        ..color = fillColor
        ..style = PaintingStyle.fill,
    );

    // Line
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final linePath = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (int i = 1; i < pts.length; i++) {
      final cp1 = Offset((pts[i - 1].dx + pts[i].dx) / 2, pts[i - 1].dy);
      final cp2 = Offset((pts[i - 1].dx + pts[i].dx) / 2, pts[i].dy);
      linePath.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, pts[i].dx, pts[i].dy);
    }
    canvas.drawPath(linePath, linePaint);

    // Dots
    for (int i = 0; i < pts.length; i++) {
      canvas.drawCircle(
        pts[i],
        3.5,
        Paint()
          ..color = dotColor
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        pts[i],
        3.5,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(_LineChartPainter old) =>
      old.values != values || old.lineColor != lineColor;
}

// ── Session Time Chart ───────────────────────────────────────

class _SessionTimeChart extends StatelessWidget {
  final AppColorTokens t;
  final bool isDark;
  final List<int> minutes;
  final List<String> labels;
  const _SessionTimeChart({
    required this.t,
    required this.isDark,
    required this.minutes,
    required this.labels,
  });

  String _fmtMin(int m) => m >= 60 ? '${m ~/ 60}h ${m % 60}m' : '${m}m';

  @override
  Widget build(BuildContext context) {
    final total = minutes.reduce((a, b) => a + b);
    final maxM = minutes.reduce(math.max);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.border.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _fmtMin(total),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: t.foreground,
                      letterSpacing: -0.3,
                    ),
                  ),
                  Text(
                    'Total this week',
                    style: TextStyle(fontSize: 11, color: t.mutedForeground),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: t.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Avg ${_fmtMin(total ~/ minutes.length)}/day',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: t.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...minutes.asMap().entries.map((e) {
            final ratio = e.value / maxM;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    child: Text(
                      labels[e.key],
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: t.mutedForeground,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Stack(
                      children: [
                        Container(
                          height: 20,
                          decoration: BoxDecoration(
                            color: t.muted.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: ratio,
                          child: Container(
                            height: 20,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              gradient: LinearGradient(
                                colors: [
                                  t.primary.withValues(
                                    alpha: isDark ? 0.8 : 0.7,
                                  ),
                                  t.primaryGlow.withValues(
                                    alpha: isDark ? 0.6 : 0.5,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 48,
                    child: Text(
                      _fmtMin(e.value),
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: t.foreground,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── Top Gestures Card ────────────────────────────────────────

class _TopGesturesCard extends StatelessWidget {
  final AppColorTokens t;
  final List<GestureUsage> gestures;
  const _TopGesturesCard({required this.t, required this.gestures});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.border.withValues(alpha: 0.4)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: gestures.asMap().entries.map((e) {
          final i = e.key;
          final g = e.value;
          return Container(
            decoration: i < gestures.length - 1
                ? BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: t.border.withValues(alpha: 0.3),
                      ),
                    ),
                  )
                : null,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Rank badge
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: i == 0
                        ? t.accent.withValues(alpha: 0.15)
                        : t.muted.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Center(
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: i == 0 ? t.accent : t.mutedForeground,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Label + bar
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        g.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: t.foreground,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Stack(
                        children: [
                          Container(
                            height: 4,
                            decoration: BoxDecoration(
                              color: t.muted.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: g.percentage,
                            child: Container(
                              height: 4,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(3),
                                color: i == 0
                                    ? t.accent
                                    : t.primary.withValues(alpha: 0.6),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${g.count}x',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: t.foreground,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
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
  Widget build(BuildContext context) => Row(
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

// ── Recognition Quality Card ─────────────────────────────────

class _RecognitionQualityCard extends StatelessWidget {
  final AppColorTokens t;
  final bool isDark;
  const _RecognitionQualityCard({required this.t, required this.isDark});

  static const _qualities = [
    (label: 'Excellent (≥ 95%)', fraction: 0.62, colorIdx: 0),
    (label: 'Good (85–94%)', fraction: 0.24, colorIdx: 1),
    (label: 'Fair (< 85%)', fraction: 0.14, colorIdx: 2),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.border.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recognition Breakdown',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: t.foreground,
            ),
          ),
          const SizedBox(height: 16),
          ..._qualities.asMap().entries.map((entry) {
            final i = entry.key;
            final q = entry.value;
            final barColor = i == 0
                ? t.success
                : i == 1
                ? t.accent
                : t.destructive;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        q.label,
                        style: TextStyle(
                          fontSize: 11,
                          color: t.mutedForeground,
                        ),
                      ),
                      Text(
                        '${(q.fraction * 100).round()}%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: barColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: q.fraction,
                      minHeight: 6,
                      backgroundColor: t.muted.withValues(alpha: 0.3),
                      valueColor: AlwaysStoppedAnimation<Color>(barColor),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
