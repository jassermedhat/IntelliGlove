// chart.dart
// ============================================================
// Chart system — wraps fl_chart with a config API
// similar to TSX Recharts ChartContainer / ChartConfig
// ============================================================

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme/theme_provider.dart'; // adjust path
import '../theme/app_colors.dart'; // adjust path

// ─────────────────────────────────────────────────────────────
// CHART CONFIG (mirrors TSX ChartConfig)
// ─────────────────────────────────────────────────────────────

class AppChartConfig {
  final Map<String, AppChartSeriesConfig> series;

  const AppChartConfig({required this.series});

  Color colorFor(String key, AppColorTokens t) {
    final s = series[key];
    if (s == null) return t.accent;
    if (s.lightColor != null || s.darkColor != null) {
      final isDark = t == AppColors.dark;
      return isDark
          ? (s.darkColor ?? s.color ?? t.accent)
          : (s.lightColor ?? s.color ?? t.accent);
    }
    return s.color ?? t.accent;
  }

  String labelFor(String key) {
    return series[key]?.label ?? key;
  }

  IconData? iconFor(String key) {
    return series[key]?.icon;
  }
}

class AppChartSeriesConfig {
  final String? label;
  final Color? color;
  final Color? lightColor;
  final Color? darkColor;
  final IconData? icon;

  const AppChartSeriesConfig({
    this.label,
    this.color,
    this.lightColor,
    this.darkColor,
    this.icon,
  });
}

// ─────────────────────────────────────────────────────────────
// CHART CONTAINER
// ─────────────────────────────────────────────────────────────

/// Themed chart container — wraps any fl_chart widget.
/// Provides `config` down via InheritedWidget.
///
/// ```dart
/// AppChartContainer(
///   config: myConfig,
///   aspectRatio: 16 / 9,
///   child: AppLineChart(...),
/// )
/// ```
class AppChartContainer extends StatelessWidget {
  final AppChartConfig config;
  final Widget child;
  final double aspectRatio;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  const AppChartContainer({
    super.key,
    required this.config,
    required this.child,
    this.aspectRatio = 16 / 9,
    this.padding,
    this.margin,
  });

  /// Look up config from widget tree.
  static AppChartConfig of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_ChartConfigScope>();
    assert(scope != null, 'No AppChartContainer found in widget tree');
    return scope!.config;
  }

  @override
  Widget build(BuildContext context) {
    return _ChartConfigScope(
      config: config,
      child: Padding(
        padding: margin ?? EdgeInsets.zero,
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
        ),
      ),
    );
  }
}

class _ChartConfigScope extends InheritedWidget {
  final AppChartConfig config;

  const _ChartConfigScope({required this.config, required super.child});

  @override
  bool updateShouldNotify(_ChartConfigScope old) => config != old.config;
}

// ─────────────────────────────────────────────────────────────
// LINE CHART
// ─────────────────────────────────────────────────────────────

class AppLineChartData {
  final String key;
  final List<FlSpot> spots;
  final bool showDots;
  final bool curved;
  final double strokeWidth;

  const AppLineChartData({
    required this.key,
    required this.spots,
    this.showDots = true,
    this.curved = true,
    this.strokeWidth = 2.5,
  });
}

class AppLineChart extends StatelessWidget {
  final List<AppLineChartData> lines;
  final bool showGrid;
  final bool showTooltip;
  final List<String>? bottomLabels;
  final List<String>? leftLabels;
  final double? minY;
  final double? maxY;

  const AppLineChart({
    super.key,
    required this.lines,
    this.showGrid = true,
    this.showTooltip = true,
    this.bottomLabels,
    this.leftLabels,
    this.minY,
    this.maxY,
  });

  @override
  Widget build(BuildContext context) {
    final t = ThemeProviderScope.of(context).tokens;
    final config = AppChartContainer.of(context);

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: showGrid,
          drawVerticalLine: false,
          horizontalInterval: 1,
          getDrawingHorizontalLine: (value) =>
              FlLine(color: t.border.withValues(alpha: 0.5), strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: bottomLabels != null,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (bottomLabels == null ||
                    i < 0 ||
                    i >= bottomLabels!.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    bottomLabels![i],
                    style: TextStyle(fontSize: 11, color: t.mutedForeground),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: leftLabels != null,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (leftLabels == null || i < 0 || i >= leftLabels!.length) {
                  return const SizedBox.shrink();
                }
                return Text(
                  leftLabels![i],
                  style: TextStyle(fontSize: 11, color: t.mutedForeground),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minY: minY,
        maxY: maxY,
        lineTouchData: LineTouchData(
          enabled: showTooltip,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => t.card,
            tooltipBorder: BorderSide(color: t.border.withValues(alpha: 0.5)),
            tooltipRoundedRadius: 8,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final key = lines[spot.barIndex].key;
                final color = config.colorFor(key, t);
                final label = config.labelFor(key);
                return LineTooltipItem(
                  '$label\n${spot.y.toStringAsFixed(1)}',
                  TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                );
              }).toList();
            },
          ),
        ),
        lineBarsData: lines.map((line) {
          final color = config.colorFor(line.key, t);
          return LineChartBarData(
            spots: line.spots,
            isCurved: line.curved,
            color: color,
            barWidth: line.strokeWidth,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: line.showDots,
              getDotPainter: (spot, percent, barData, index) =>
                  FlDotCirclePainter(
                    radius: 4,
                    color: t.card,
                    strokeWidth: 2,
                    strokeColor: color,
                  ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: color.withValues(alpha: 0.08),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// BAR CHART
// ─────────────────────────────────────────────────────────────

class AppBarChartGroup {
  final int x;
  final Map<String, double> values; // key → value
  final String? label;

  const AppBarChartGroup({required this.x, required this.values, this.label});
}

class AppBarChart extends StatelessWidget {
  final List<AppBarChartGroup> groups;
  final bool showGrid;
  final bool showTooltip;
  final double barWidth;
  final double groupSpacing;

  const AppBarChart({
    super.key,
    required this.groups,
    this.showGrid = true,
    this.showTooltip = true,
    this.barWidth = 16,
    this.groupSpacing = 12,
  });

  @override
  Widget build(BuildContext context) {
    final t = ThemeProviderScope.of(context).tokens;
    final config = AppChartContainer.of(context);

    // Collect all series keys
    final allKeys = <String>{};
    for (final g in groups) {
      allKeys.addAll(g.values.keys);
    }
    final keyList = allKeys.toList();

    return BarChart(
      BarChartData(
        gridData: FlGridData(
          show: showGrid,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) =>
              FlLine(color: t.border.withValues(alpha: 0.5), strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= groups.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    groups[i].label ?? '$i',
                    style: TextStyle(fontSize: 11, color: t.mutedForeground),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) => Text(
                value.toInt().toString(),
                style: TextStyle(fontSize: 11, color: t.mutedForeground),
              ),
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          enabled: showTooltip,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => t.card,
            tooltipBorder: BorderSide(color: t.border.withValues(alpha: 0.5)),
            tooltipRoundedRadius: 8,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final key = keyList[rodIndex];
              final label = config.labelFor(key);
              return BarTooltipItem(
                '$label: ${rod.toY.toStringAsFixed(1)}',
                TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: config.colorFor(key, t),
                ),
              );
            },
          ),
        ),
        groupsSpace: groupSpacing,
        barGroups: groups.asMap().entries.map((entry) {
          final g = entry.value;
          return BarChartGroupData(
            x: g.x,
            barRods: keyList.map((key) {
              return BarChartRodData(
                toY: g.values[key] ?? 0,
                width: barWidth,
                color: config.colorFor(key, t),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
              );
            }).toList(),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// PIE CHART
// ─────────────────────────────────────────────────────────────

class AppPieChartSection {
  final String key;
  final double value;

  const AppPieChartSection({required this.key, required this.value});
}

class AppPieChart extends StatelessWidget {
  final List<AppPieChartSection> sections;
  final double centerRadius;
  final bool showLabels;
  final double startDegreeOffset;

  const AppPieChart({
    super.key,
    required this.sections,
    this.centerRadius = 40,
    this.showLabels = false,
    this.startDegreeOffset = -90,
  });

  @override
  Widget build(BuildContext context) {
    final t = ThemeProviderScope.of(context).tokens;
    final config = AppChartContainer.of(context);

    return PieChart(
      PieChartData(
        startDegreeOffset: startDegreeOffset,
        sectionsSpace: 2,
        centerSpaceRadius: centerRadius,
        sections: sections.map((s) {
          final color = config.colorFor(s.key, t);
          return PieChartSectionData(
            value: s.value,
            color: color,
            radius: 50,
            showTitle: showLabels,
            title: showLabels ? config.labelFor(s.key) : '',
            titleStyle: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.white,
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// CHART LEGEND
// ─────────────────────────────────────────────────────────────

/// Horizontal legend row — mirrors TSX `<ChartLegendContent />`
class AppChartLegend extends StatelessWidget {
  final List<String> keys;
  final bool showIcons;
  final EdgeInsetsGeometry? padding;

  const AppChartLegend({
    super.key,
    required this.keys,
    this.showIcons = false,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final t = ThemeProviderScope.of(context).tokens;
    final config = AppChartContainer.of(context);

    return Padding(
      padding: padding ?? const EdgeInsets.only(top: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: keys.map((key) {
            final color = config.colorFor(key, t);
            final label = config.labelFor(key);
            final icon = config.iconFor(key);

            return Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showIcons && icon != null) ...[
                    Icon(icon, size: 12, color: t.mutedForeground),
                    const SizedBox(width: 6),
                  ] else ...[
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: t.mutedForeground),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
