// overlays.dart
// ============================================================
// Dialogs, Panels & Floating Cards
// Includes: Tooltip, Dialog, AlertDialog, Sheet, Drawer, Popover
// Skipped: HoverCard (no hover on mobile)
// ============================================================

import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../theme/theme_provider.dart'; // adjust path
import '../theme/app_colors.dart'; // adjust path

// ─────────────────────────────────────────────────────────────
// TOOLTIP
// ─────────────────────────────────────────────────────────────

/// Themed tooltip — shows on long-press (mobile equivalent of hover).
/// Wraps Flutter's built-in Tooltip with your theme.
class AppTooltip extends StatelessWidget {
  final Widget child;
  final String message;
  final EdgeInsetsGeometry? padding;
  final bool preferBelow;

  const AppTooltip({
    super.key,
    required this.child,
    required this.message,
    this.padding,
    this.preferBelow = true,
  });

  @override
  Widget build(BuildContext context) {
    final t = ThemeProviderScope.of(context).tokens;
    final isDark = ThemeProviderScope.of(context).isDark;

    return Tooltip(
      message: message,
      preferBelow: preferBelow,
      waitDuration: Duration.zero,
      padding:
          padding ?? const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF26365C) : const Color(0xFF101B40),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: t.border.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      textStyle: const TextStyle(color: Color(0xFFEDF0F5), fontSize: 12),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────
// DIALOG
// ─────────────────────────────────────────────────────────────

/// Shows a themed dialog — mirrors Radix Dialog.
///
/// Returns the value passed to `Navigator.pop(context, value)`.
Future<T?> showAppDialog<T>({
  required BuildContext context,
  required Widget Function(BuildContext context) builder,
  bool barrierDismissible = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: 'Dialog',
    barrierColor: Colors.black.withValues(alpha: 0.8),
    transitionDuration: const Duration(milliseconds: 200),
    transitionBuilder: (ctx, anim, secondaryAnim, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
        child: ScaleTransition(
          scale: Tween<double>(
            begin: 0.95,
            end: 1.0,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
          child: child,
        ),
      );
    },
    pageBuilder: (ctx, _, __) => builder(ctx),
  );
}

/// Dialog content container.
class AppDialogContent extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final bool showCloseButton;
  final VoidCallback? onClose;

  const AppDialogContent({
    super.key,
    required this.child,
    this.maxWidth = 448,
    this.showCloseButton = true,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final t = ThemeProviderScope.of(context).tokens;
    final media = MediaQuery.of(context);
    final bottomInset = media.viewInsets.bottom;

    return SafeArea(
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 16),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxWidth,
              maxHeight: math.max(120, media.size.height - bottomInset - 32),
            ),
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: t.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: t.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: SingleChildScrollView(
                  child: Stack(
                    children: [
                      Padding(padding: const EdgeInsets.all(24), child: child),
                      if (showCloseButton)
                        PositionedDirectional(
                          end: 16,
                          top: 16,
                          child: GestureDetector(
                            onTap: onClose ?? () => Navigator.of(context).pop(),
                            child: Opacity(
                              opacity: 0.7,
                              child: Icon(
                                Icons.close_rounded,
                                size: 16,
                                color: t.foreground,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dialog header — `flex flex-col space-y-1.5`
class AppDialogHeader extends StatelessWidget {
  final Widget? title;
  final Widget? description;

  const AppDialogHeader({super.key, this.title, this.description});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) title!,
        if (title != null && description != null) const SizedBox(height: 6),
        if (description != null) description!,
      ],
    );
  }
}

/// Dialog title — `text-lg font-semibold leading-none tracking-tight`
class AppDialogTitle extends StatelessWidget {
  final String text;

  const AppDialogTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final t = ThemeProviderScope.of(context).tokens;
    return Text(
      text,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: t.foreground,
        height: 1.0,
        letterSpacing: -0.2,
      ),
    );
  }
}

/// Dialog description — `text-sm text-muted-foreground`
class AppDialogDescription extends StatelessWidget {
  final String text;

  const AppDialogDescription(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final t = ThemeProviderScope.of(context).tokens;
    return Text(text, style: TextStyle(fontSize: 14, color: t.mutedForeground));
  }
}

/// Dialog footer — `flex row justify-end gap-2`
class AppDialogFooter extends StatelessWidget {
  final List<Widget> children;

  const AppDialogFooter({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Wrap(
        alignment: WrapAlignment.end,
        spacing: 8,
        runSpacing: 8,
        children: children,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// ALERT DIALOG
// ─────────────────────────────────────────────────────────────

/// Shows a confirmation dialog with action + cancel.
///
/// Returns `true` if action pressed, `false` or `null` if cancelled.
Future<bool?> showAppAlertDialog({
  required BuildContext context,
  required String title,
  String? description,
  String actionLabel = 'Continue',
  String cancelLabel = 'Cancel',
  bool isDestructive = false,
}) {
  return showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      final t = ThemeProviderScope.of(ctx).tokens;

      return AppDialogContent(
        showCloseButton: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            AppDialogHeader(
              title: AppDialogTitle(title),
              description: description != null
                  ? AppDialogDescription(description)
                  : null,
            ),
            const SizedBox(height: 24),

            // Footer
            LayoutBuilder(
              builder: (context, constraints) {
                final stackActions =
                    constraints.maxWidth < 280 ||
                    MediaQuery.textScalerOf(context).scale(14) > 24;
                final cancel = _AlertButton(
                  label: cancelLabel,
                  onTap: () => Navigator.of(ctx).pop(false),
                  bg: Colors.transparent,
                  fg: t.foreground,
                  border: Border.all(color: t.border),
                  tokens: t,
                );
                final action = _AlertButton(
                  label: actionLabel,
                  onTap: () => Navigator.of(ctx).pop(true),
                  bg: isDestructive ? t.destructive : t.primary,
                  fg: isDestructive ? AppColors.white : t.primaryForeground,
                  tokens: t,
                );
                if (stackActions) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [action, const SizedBox(height: 8), cancel],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: cancel),
                    const SizedBox(width: 8),
                    Expanded(child: action),
                  ],
                );
              },
            ),
          ],
        ),
      );
    },
  );
}

class _AlertButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color bg;
  final Color fg;
  final Border? border;
  final AppColorTokens tokens;

  const _AlertButton({
    required this.label,
    required this.onTap,
    required this.bg,
    required this.fg,
    this.border,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: border,
        ),
        child: Center(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SHEET (slide-in panel from any side)
// ─────────────────────────────────────────────────────────────

enum AppSheetSide { top, bottom, left, right }

/// Shows a slide-in sheet/panel from any side.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required Widget Function(BuildContext context) builder,
  AppSheetSide side = AppSheetSide.right,
  bool barrierDismissible = true,
  double? width,
  double? height,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: 'Sheet',
    barrierColor: Colors.black.withValues(alpha: 0.8),
    transitionDuration: const Duration(milliseconds: 300),
    transitionBuilder: (ctx, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOut);
      final offset = _sheetOffset(side);
      return SlideTransition(
        position: Tween<Offset>(
          begin: offset,
          end: Offset.zero,
        ).animate(curved),
        child: FadeTransition(opacity: curved, child: child),
      );
    },
    pageBuilder: (ctx, _, __) {
      return _SheetLayout(
        side: side,
        width: width,
        height: height,
        builder: builder,
      );
    },
  );
}

Offset _sheetOffset(AppSheetSide side) {
  switch (side) {
    case AppSheetSide.top:
      return const Offset(0, -1);
    case AppSheetSide.bottom:
      return const Offset(0, 1);
    case AppSheetSide.left:
      return const Offset(-1, 0);
    case AppSheetSide.right:
      return const Offset(1, 0);
  }
}

class _SheetLayout extends StatelessWidget {
  final AppSheetSide side;
  final double? width;
  final double? height;
  final Widget Function(BuildContext context) builder;

  const _SheetLayout({
    required this.side,
    this.width,
    this.height,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    final t = ThemeProviderScope.of(context).tokens;
    final screenSize = MediaQuery.of(context).size;
    final isHorizontal =
        side == AppSheetSide.left || side == AppSheetSide.right;

    final sheetWidth = isHorizontal
        ? (width ?? screenSize.width * 0.75).clamp(0.0, screenSize.width)
        : screenSize.width;
    final sheetHeight = !isHorizontal
        ? (height ?? screenSize.height * 0.5).clamp(0.0, screenSize.height)
        : screenSize.height;

    final Alignment alignment;
    BorderRadius borderRadius;

    switch (side) {
      case AppSheetSide.top:
        alignment = Alignment.topCenter;
        borderRadius = const BorderRadius.vertical(bottom: Radius.circular(16));
        break;
      case AppSheetSide.bottom:
        alignment = Alignment.bottomCenter;
        borderRadius = const BorderRadius.vertical(top: Radius.circular(16));
        break;
      case AppSheetSide.left:
        alignment = Alignment.centerLeft;
        borderRadius = const BorderRadius.horizontal(
          right: Radius.circular(16),
        );
        break;
      case AppSheetSide.right:
        alignment = Alignment.centerRight;
        borderRadius = const BorderRadius.horizontal(left: Radius.circular(16));
        break;
    }

    return Align(
      alignment: alignment,
      child: Material(
        color: Colors.transparent,
        child: SafeArea(
          child: Container(
            width: sheetWidth,
            height: sheetHeight,
            decoration: BoxDecoration(
              color: t.card,
              borderRadius: borderRadius,
              border: Border.all(color: t.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 24,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                // Content — scrollable
                Positioned.fill(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: builder(context),
                  ),
                ),

                // Close button
                Positioned(
                  right: 16,
                  top: 16,
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Opacity(
                      opacity: 0.7,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: t.foreground,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Sheet header — `flex flex-col space-y-2`
class AppSheetHeader extends StatelessWidget {
  final Widget? title;
  final Widget? description;

  const AppSheetHeader({super.key, this.title, this.description});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 24), // avoid close button
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) title!,
          if (title != null && description != null) const SizedBox(height: 8),
          if (description != null) description!,
        ],
      ),
    );
  }
}

/// Sheet title
class AppSheetTitle extends StatelessWidget {
  final String text;

  const AppSheetTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final t = ThemeProviderScope.of(context).tokens;
    return Text(
      text,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: t.foreground,
      ),
    );
  }
}

/// Sheet description
class AppSheetDescription extends StatelessWidget {
  final String text;

  const AppSheetDescription(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final t = ThemeProviderScope.of(context).tokens;
    return Text(text, style: TextStyle(fontSize: 14, color: t.mutedForeground));
  }
}

/// Sheet footer
class AppSheetFooter extends StatelessWidget {
  final List<Widget> children;

  const AppSheetFooter({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Wrap(
        alignment: WrapAlignment.end,
        spacing: 8,
        runSpacing: 8,
        children: children,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// DRAWER (bottom sheet with drag handle — mirrors vaul)
// ─────────────────────────────────────────────────────────────

/// Shows a draggable bottom drawer — mirrors vaul Drawer.
Future<T?> showAppDrawer<T>({
  required BuildContext context,
  required Widget Function(BuildContext context) builder,
  bool isDismissible = true,
  bool enableDrag = true,
  bool isScrollControlled = true,
  double? maxHeightFraction,
}) {
  final t = ThemeProviderScope.of(context).tokens;

  return showModalBottomSheet<T>(
    context: context,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    isScrollControlled: isScrollControlled,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.8),
    builder: (ctx) {
      return SafeArea(
        child: Container(
          constraints: BoxConstraints(
            maxHeight:
                MediaQuery.of(context).size.height *
                (maxHeightFraction ?? 0.85),
          ),
          decoration: BoxDecoration(
            color: t.card,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            border: Border.all(color: t.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Container(
                  width: 100,
                  height: 8,
                  decoration: BoxDecoration(
                    color: t.muted,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),

              // Content
              Flexible(child: SingleChildScrollView(child: builder(ctx))),
            ],
          ),
        ),
      );
    },
  );
}

/// Drawer header — `grid gap-1.5 p-4`
class AppDrawerHeader extends StatelessWidget {
  final Widget? title;
  final Widget? description;

  const AppDrawerHeader({super.key, this.title, this.description});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (title != null) title!,
          if (title != null && description != null) const SizedBox(height: 6),
          if (description != null) description!,
        ],
      ),
    );
  }
}

/// Drawer title
class AppDrawerTitle extends StatelessWidget {
  final String text;

  const AppDrawerTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final t = ThemeProviderScope.of(context).tokens;
    return Text(
      text,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: t.foreground,
        height: 1.0,
        letterSpacing: -0.2,
      ),
    );
  }
}

/// Drawer description
class AppDrawerDescription extends StatelessWidget {
  final String text;

  const AppDrawerDescription(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final t = ThemeProviderScope.of(context).tokens;
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 14, color: t.mutedForeground),
    );
  }
}

/// Drawer footer — `mt-auto flex flex-col gap-2 p-4`
class AppDrawerFooter extends StatelessWidget {
  final List<Widget> children;
  final Axis direction;

  const AppDrawerFooter({
    super.key,
    required this.children,
    this.direction = Axis.vertical,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: direction == Axis.vertical
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: _interleave(children, const SizedBox(height: 8)),
            )
          : Row(
              children: _interleave(
                children.map((c) => Expanded(child: c)).toList(),
                const SizedBox(width: 8),
              ),
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// POPOVER (bottom sheet on mobile)
// ─────────────────────────────────────────────────────────────

/// Shows a popover — on mobile, renders as a small bottom sheet.
Future<T?> showAppPopover<T>({
  required BuildContext context,
  required Widget Function(BuildContext context) builder,
  bool isDismissible = true,
}) {
  final t = ThemeProviderScope.of(context).tokens;

  return showModalBottomSheet<T>(
    context: context,
    isDismissible: isDismissible,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) {
      return SafeArea(
        child: Container(
          margin: const EdgeInsets.all(16),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.5,
          ),
          decoration: BoxDecoration(
            color: t.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: t.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: builder(ctx),
          ),
        ),
      );
    },
  );
}

// ─────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────

List<Widget> _interleave(List<Widget> widgets, Widget separator) {
  if (widgets.isEmpty) return widgets;
  final result = <Widget>[];
  for (var i = 0; i < widgets.length; i++) {
    result.add(widgets[i]);
    if (i < widgets.length - 1) result.add(separator);
  }
  return result;
}
