// display.dart
// ============================================================
// Static/visual display UI components
// Consolidated: Card, Badge, Alert, Avatar, Table, Tabs,
// Progress, Skeleton, Separator, Accordion, Breadcrumb
// ============================================================

import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/theme_provider.dart'; // adjust path
import '../theme/app_colors.dart'; // adjust path

// ─────────────────────────────────────────────────────────────
// CARD
// ─────────────────────────────────────────────────────────────

/// Base card — `rounded-2xl border bg-card text-card-foreground shadow-sm`
class AppCard extends StatelessWidget {
  final Widget? child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadiusGeometry? borderRadius;
  final Color? color;
  final Border? border;
  final List<BoxShadow>? boxShadow;
  final VoidCallback? onTap;

  const AppCard({
    super.key,
    this.child,
    this.padding,
    this.margin,
    this.borderRadius,
    this.color,
    this.border,
    this.boxShadow,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = ThemeProviderScope.of(context).tokens;

    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? t.card,
        borderRadius: borderRadius ?? BorderRadius.circular(16),
        border: border ?? Border.all(color: t.border, width: 1),
        boxShadow:
            boxShadow ??
            [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
      ),
      child: child,
    );

    if (onTap != null) {
      return Padding(
        padding: margin ?? EdgeInsets.zero,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: content,
        ),
      );
    }

    return Padding(padding: margin ?? EdgeInsets.zero, child: content);
  }
}

/// Card header — `flex flex-col space-y-1.5 p-6`
class AppCardHeader extends StatelessWidget {
  final Widget? title;
  final Widget? description;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;

  const AppCardHeader({
    super.key,
    this.title,
    this.description,
    this.trailing,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.all(24),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (title != null) title!,
                if (title != null && description != null)
                  const SizedBox(height: 6),
                if (description != null) description!,
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ],
      ),
    );
  }
}

/// Card title — `text-xl font-bold leading-none tracking-tight`
class AppCardTitle extends StatelessWidget {
  final String text;
  final int? maxLines;

  const AppCardTitle(this.text, {super.key, this.maxLines});

  @override
  Widget build(BuildContext context) {
    final t = ThemeProviderScope.of(context).tokens;
    return Text(
      text,
      maxLines: maxLines ?? 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: t.cardForeground,
        height: 1.0,
        letterSpacing: -0.3,
      ),
    );
  }
}

/// Card description — `text-sm text-muted-foreground`
class AppCardDescription extends StatelessWidget {
  final String text;
  final int? maxLines;

  const AppCardDescription(this.text, {super.key, this.maxLines});

  @override
  Widget build(BuildContext context) {
    final t = ThemeProviderScope.of(context).tokens;
    return Text(
      text,
      maxLines: maxLines ?? 3,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: 14, color: t.mutedForeground),
    );
  }
}

/// Card content — `p-6 pt-0`
class AppCardContent extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const AppCardContent({super.key, required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: child,
    );
  }
}

/// Card footer — `flex items-center p-6 pt-0`
class AppCardFooter extends StatelessWidget {
  final List<Widget> children;
  final MainAxisAlignment mainAxisAlignment;
  final EdgeInsetsGeometry? padding;

  const AppCardFooter({
    super.key,
    required this.children,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Row(mainAxisAlignment: mainAxisAlignment, children: children),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// BADGE
// ─────────────────────────────────────────────────────────────

enum AppBadgeVariant { primary, secondary, destructive, outline }

/// Pill badge — `inline-flex items-center rounded-full border px-2.5 py-0.5 text-xs font-semibold`
class AppBadge extends StatelessWidget {
  final String label;
  final AppBadgeVariant variant;
  final Widget? icon;
  final Color? customColor;
  final Color? customBackground;

  const AppBadge({
    super.key,
    required this.label,
    this.variant = AppBadgeVariant.primary,
    this.icon,
    this.customColor,
    this.customBackground,
  });

  @override
  Widget build(BuildContext context) {
    final t = ThemeProviderScope.of(context).tokens;

    final (Color bg, Color fg, Color borderColor) = _resolve(t);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: customBackground ?? bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            IconTheme(
              data: IconThemeData(color: customColor ?? fg, size: 12),
              child: icon!,
            ),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: customColor ?? fg,
              ),
            ),
          ),
        ],
      ),
    );
  }

  (Color bg, Color fg, Color border) _resolve(AppColorTokens t) {
    switch (variant) {
      case AppBadgeVariant.primary:
        return (t.primary, t.primaryForeground, Colors.transparent);
      case AppBadgeVariant.secondary:
        return (t.secondary, t.secondaryForeground, Colors.transparent);
      case AppBadgeVariant.destructive:
        return (t.destructive, AppColors.white, Colors.transparent);
      case AppBadgeVariant.outline:
        return (Colors.transparent, t.foreground, t.border);
    }
  }
}

// ─────────────────────────────────────────────────────────────
// ALERT
// ─────────────────────────────────────────────────────────────

enum AppAlertVariant { defaultVariant, destructive }

/// Alert box with optional icon, title, and description.
class AppAlert extends StatelessWidget {
  final AppAlertVariant variant;
  final Widget? icon;
  final Widget? title;
  final Widget? description;
  final EdgeInsetsGeometry? margin;

  const AppAlert({
    super.key,
    this.variant = AppAlertVariant.defaultVariant,
    this.icon,
    this.title,
    this.description,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final t = ThemeProviderScope.of(context).tokens;
    final isDestructive = variant == AppAlertVariant.destructive;

    final borderColor = isDestructive
        ? t.destructive.withValues(alpha: 0.5)
        : t.border;
    final bgColor = isDestructive ? Colors.transparent : t.background;
    final iconColor = isDestructive ? t.destructive : t.foreground;

    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) ...[
              IconTheme(
                data: IconThemeData(color: iconColor, size: 18),
                child: icon!,
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (title != null) title!,
                  if (title != null && description != null)
                    const SizedBox(height: 4),
                  if (description != null) description!,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Alert title — `font-medium leading-none tracking-tight`
class AppAlertTitle extends StatelessWidget {
  final String text;

  const AppAlertTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final t = ThemeProviderScope.of(context).tokens;
    return Text(
      text,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: t.foreground,
        height: 1.0,
        letterSpacing: -0.2,
      ),
    );
  }
}

/// Alert description — `text-sm`
class AppAlertDescription extends StatelessWidget {
  final String text;

  const AppAlertDescription(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final t = ThemeProviderScope.of(context).tokens;
    return Text(
      text,
      style: TextStyle(fontSize: 14, color: t.foreground, height: 1.5),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// AVATAR
// ─────────────────────────────────────────────────────────────

/// Circular avatar with image + fallback.
/// `relative flex h-10 w-10 shrink-0 overflow-hidden rounded-full`
class AppAvatar extends StatelessWidget {
  final String? imageUrl;
  final String? fallbackText;
  final double size;
  final Color? backgroundColor;

  const AppAvatar({
    super.key,
    this.imageUrl,
    this.fallbackText,
    this.size = 40,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final t = ThemeProviderScope.of(context).tokens;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor ?? t.muted,
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl != null && imageUrl!.isNotEmpty
          ? Image.network(
              imageUrl!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildFallback(t),
              loadingBuilder: (_, child, progress) {
                if (progress == null) return child;
                return _buildFallback(t);
              },
            )
          : _buildFallback(t),
    );
  }

  Widget _buildFallback(AppColorTokens t) {
    return Center(
      child: Text(
        (fallbackText ?? '?')
            .substring(0, min(2, (fallbackText ?? '?').length))
            .toUpperCase(),
        style: TextStyle(
          fontSize: size * 0.35,
          fontWeight: FontWeight.w600,
          color: t.mutedForeground,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// TABS
// ─────────────────────────────────────────────────────────────

/// Tab bar + content — mirrors Radix Tabs.
class AppTabs extends StatefulWidget {
  final List<AppTabItem> tabs;
  final int initialIndex;
  final ValueChanged<int>? onChanged;
  final EdgeInsetsGeometry? margin;

  const AppTabs({
    super.key,
    required this.tabs,
    this.initialIndex = 0,
    this.onChanged,
    this.margin,
  });

  @override
  State<AppTabs> createState() => _AppTabsState();
}

class _AppTabsState extends State<AppTabs> with SingleTickerProviderStateMixin {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    final t = ThemeProviderScope.of(context).tokens;

    return Padding(
      padding: widget.margin ?? EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tab list — scrollable if many tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Container(
              height: 40,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: t.muted,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(widget.tabs.length, (i) {
                  final isSelected = i == _currentIndex;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _currentIndex = i);
                      widget.onChanged?.call(i);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected ? t.card : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ]
                            : null,
                      ),
                      child: Text(
                        widget.tabs[i].label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isSelected ? t.foreground : t.mutedForeground,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),

          // Tab content
          const SizedBox(height: 8),
          if (_currentIndex < widget.tabs.length)
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: KeyedSubtree(
                key: ValueKey(_currentIndex),
                child: widget.tabs[_currentIndex].content,
              ),
            ),
        ],
      ),
    );
  }
}

class AppTabItem {
  final String label;
  final Widget content;

  const AppTabItem({required this.label, required this.content});
}

// ─────────────────────────────────────────────────────────────
// PROGRESS
// ─────────────────────────────────────────────────────────────

/// Animated progress bar.
/// `relative h-4 w-full overflow-hidden rounded-full bg-secondary`
class AppProgress extends StatelessWidget {
  final double value; // 0.0 – 1.0
  final double height;
  final Color? trackColor;
  final Color? indicatorColor;
  final BorderRadiusGeometry? borderRadius;

  const AppProgress({
    super.key,
    required this.value,
    this.height = 16,
    this.trackColor,
    this.indicatorColor,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final t = ThemeProviderScope.of(context).tokens;
    final clampedValue = value.clamp(0.0, 1.0);
    final radius = borderRadius ?? BorderRadius.circular(999);

    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: trackColor ?? t.secondary,
        borderRadius: radius,
      ),
      clipBehavior: Clip.antiAlias,
      child: Align(
        alignment: Alignment.centerLeft,
        child: AnimatedFractionallySizedBox(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          widthFactor: clampedValue,
          child: Container(
            decoration: BoxDecoration(
              color: indicatorColor ?? t.primary,
              borderRadius: radius,
            ),
          ),
        ),
      ),
    );
  }
}

/// Animated version of FractionallySizedBox
class AnimatedFractionallySizedBox extends ImplicitlyAnimatedWidget {
  final double widthFactor;
  final Widget? child;
  final AlignmentGeometry alignment;

  const AnimatedFractionallySizedBox({
    super.key,
    required this.widthFactor,
    this.child,
    this.alignment = Alignment.centerLeft,
    required super.duration,
    super.curve,
  });

  @override
  AnimatedWidgetBaseState<AnimatedFractionallySizedBox> createState() =>
      _AnimatedFractionallySizedBoxState();
}

class _AnimatedFractionallySizedBoxState
    extends AnimatedWidgetBaseState<AnimatedFractionallySizedBox> {
  Tween<double>? _widthFactor;

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    _widthFactor =
        visitor(
              _widthFactor,
              widget.widthFactor,
              (v) => Tween<double>(begin: v as double),
            )
            as Tween<double>?;
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      alignment: widget.alignment,
      widthFactor: _widthFactor?.evaluate(animation) ?? widget.widthFactor,
      child: widget.child,
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SKELETON
// ─────────────────────────────────────────────────────────────

/// Pulsing placeholder shimmer.
/// `animate-pulse rounded-md bg-muted`
class AppSkeleton extends StatefulWidget {
  final double? width;
  final double? height;
  final BorderRadiusGeometry? borderRadius;
  final EdgeInsetsGeometry? margin;

  const AppSkeleton({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
    this.margin,
  });

  /// Circle skeleton shorthand
  factory AppSkeleton.circle({Key? key, required double size}) => AppSkeleton(
    key: key,
    width: size,
    height: size,
    borderRadius: BorderRadius.circular(999),
  );

  @override
  State<AppSkeleton> createState() => _AppSkeletonState();
}

class _AppSkeletonState extends State<AppSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = ThemeProviderScope.of(context).tokens;

    return Padding(
      padding: widget.margin ?? EdgeInsets.zero,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: t.muted.withValues(alpha: 0.5 + _controller.value * 0.5),
              borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SEPARATOR
// ─────────────────────────────────────────────────────────────

/// Horizontal or vertical divider.
/// `shrink-0 bg-border h-[1px] w-full | h-full w-[1px]`
class AppSeparator extends StatelessWidget {
  final bool isVertical;
  final double thickness;
  final Color? color;
  final EdgeInsetsGeometry? margin;

  const AppSeparator({
    super.key,
    this.isVertical = false,
    this.thickness = 1,
    this.color,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final t = ThemeProviderScope.of(context).tokens;

    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: isVertical
          ? SizedBox(
              width: thickness,
              child: Container(color: color ?? t.border),
            )
          : SizedBox(
              height: thickness,
              width: double.infinity,
              child: Container(color: color ?? t.border),
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// ACCORDION
// ─────────────────────────────────────────────────────────────

/// Single-select or multi-select accordion.
class AppAccordion extends StatefulWidget {
  final List<AppAccordionItem> items;
  final bool allowMultiple;
  final EdgeInsetsGeometry? margin;

  const AppAccordion({
    super.key,
    required this.items,
    this.allowMultiple = false,
    this.margin,
  });

  @override
  State<AppAccordion> createState() => _AppAccordionState();
}

class _AppAccordionState extends State<AppAccordion> {
  final Set<int> _expanded = {};

  void _toggle(int index) {
    setState(() {
      if (_expanded.contains(index)) {
        _expanded.remove(index);
      } else {
        if (!widget.allowMultiple) _expanded.clear();
        _expanded.add(index);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = ThemeProviderScope.of(context).tokens;

    return Padding(
      padding: widget.margin ?? EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(widget.items.length, (i) {
          final item = widget.items[i];
          final isOpen = _expanded.contains(i);
          final isLast = i == widget.items.length - 1;

          return _AccordionTile(
            title: item.title,
            content: item.content,
            isOpen: isOpen,
            showBorder: !isLast,
            tokens: t,
            onTap: () => _toggle(i),
          );
        }),
      ),
    );
  }
}

class AppAccordionItem {
  final Widget title;
  final Widget content;

  const AppAccordionItem({required this.title, required this.content});
}

class _AccordionTile extends StatelessWidget {
  final Widget title;
  final Widget content;
  final bool isOpen;
  final bool showBorder;
  final AppColorTokens tokens;
  final VoidCallback onTap;

  const _AccordionTile({
    required this.title,
    required this.content,
    required this.isOpen,
    required this.showBorder,
    required this.tokens,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Trigger
        GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            decoration: showBorder && !isOpen
                ? BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: tokens.border, width: 1),
                    ),
                  )
                : null,
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: DefaultTextStyle(
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: tokens.foreground,
                    ),
                    child: title,
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedRotation(
                  turns: isOpen ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color: tokens.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Content
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity, height: 0),
          secondChild: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: DefaultTextStyle(
              style: TextStyle(fontSize: 14, color: tokens.foreground),
              child: content,
            ),
          ),
          crossFadeState: isOpen
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
          sizeCurve: Curves.easeOut,
        ),

        // Bottom border for open items
        if (showBorder && isOpen) Container(height: 1, color: tokens.border),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// BREADCRUMB
// ─────────────────────────────────────────────────────────────

/// Breadcrumb navigation.
class AppBreadcrumb extends StatelessWidget {
  final List<AppBreadcrumbItem> items;
  final Widget? separator;
  final EdgeInsetsGeometry? margin;

  const AppBreadcrumb({
    super.key,
    required this.items,
    this.separator,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final t = ThemeProviderScope.of(context).tokens;
    final sep =
        separator ??
        Icon(Icons.chevron_right_rounded, size: 14, color: t.mutedForeground);

    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(items.length * 2 - 1, (i) {
            // Even indices = items, odd = separators
            if (i.isOdd) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: sep,
              );
            }

            final itemIndex = i ~/ 2;
            final item = items[itemIndex];
            final isLast = itemIndex == items.length - 1;

            if (item.isEllipsis) {
              return SizedBox(
                width: 36,
                height: 36,
                child: Center(
                  child: Icon(
                    Icons.more_horiz_rounded,
                    size: 16,
                    color: t.mutedForeground,
                  ),
                ),
              );
            }

            if (isLast) {
              // Current page — not tappable
              return Flexible(
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: t.foreground,
                  ),
                ),
              );
            }

            // Link
            return GestureDetector(
              onTap: item.onTap,
              child: Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, color: t.mutedForeground),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class AppBreadcrumbItem {
  final String label;
  final VoidCallback? onTap;
  final bool isEllipsis;

  const AppBreadcrumbItem({
    required this.label,
    this.onTap,
    this.isEllipsis = false,
  });

  /// Shorthand for an ellipsis item
  const AppBreadcrumbItem.ellipsis()
    : label = '...',
      onTap = null,
      isEllipsis = true;
}
