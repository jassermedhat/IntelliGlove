// toast.dart
// ============================================================
// Custom overlay toast system — mirrors Radix Toast + Sonner
// Supports: variants, title, description, action, close,
// auto-dismiss, swipe-to-dismiss, stacking
// ============================================================

import 'dart:async';
import 'dart:collection';
import 'package:flutter/material.dart';
import 'app_layout.dart';
import '../theme/theme_provider.dart'; // adjust path
import '../theme/app_colors.dart'; // adjust path

// ─────────────────────────────────────────────────────────────
// TOAST DATA
// ─────────────────────────────────────────────────────────────

enum AppToastVariant { defaultVariant, destructive, success, warning }

class AppToastData {
  static int _nextId = 0;

  final String id;
  final String? title;
  final String? description;
  final AppToastVariant variant;
  final Duration duration;
  final Widget? action;
  final VoidCallback? onAction;
  final String? actionLabel;
  final bool showClose;
  final Widget? leading;

  AppToastData({
    String? id,
    this.title,
    this.description,
    this.variant = AppToastVariant.defaultVariant,
    this.duration = const Duration(seconds: 4),
    this.action,
    this.onAction,
    this.actionLabel,
    this.showClose = true,
    this.leading,
  }) : id = id ?? 'toast-${_nextId++}';
}

// ─────────────────────────────────────────────────────────────
// TOAST SERVICE (singleton — call from anywhere)
// ─────────────────────────────────────────────────────────────

class ToastService {
  ToastService._();
  static final ToastService instance = ToastService._();

  final _controller = StreamController<ToastAction>.broadcast();
  Stream<ToastAction> get stream => _controller.stream;

  /// Show a toast
  void show({
    String? title,
    String? description,
    AppToastVariant variant = AppToastVariant.defaultVariant,
    Duration duration = const Duration(seconds: 4),
    Widget? action,
    VoidCallback? onAction,
    String? actionLabel,
    bool showClose = true,
    Widget? leading,
  }) {
    final data = AppToastData(
      title: title,
      description: description,
      variant: variant,
      duration: duration,
      action: action,
      onAction: onAction,
      actionLabel: actionLabel,
      showClose: showClose,
      leading: leading,
    );
    _controller.add(ToastAction.show(data));
  }

  /// Convenience: success toast
  void success({String? title, String? description}) {
    show(
      title: title,
      description: description,
      variant: AppToastVariant.success,
      leading: const Icon(Icons.check_circle_rounded, size: 20),
    );
  }

  /// Convenience: error toast
  void error({String? title, String? description}) {
    show(
      title: title,
      description: description,
      variant: AppToastVariant.destructive,
      leading: const Icon(Icons.error_outline_rounded, size: 20),
    );
  }

  void warning({String? title, String? description}) {
    show(
      title: title,
      description: description,
      variant: AppToastVariant.warning,
      leading: const Icon(Icons.warning_amber_rounded, size: 20),
    );
  }

  void info({String? title, String? description}) {
    show(
      title: title,
      description: description,
      leading: const Icon(Icons.info_outline_rounded, size: 20),
    );
  }

  void comingSoon(String featureName) {
    info(title: featureName, description: 'Coming soon');
  }

  void action({
    required String message,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    show(description: message, actionLabel: actionLabel, onAction: onAction);
  }

  /// Dismiss a specific toast
  void dismiss(String id) {
    _controller.add(ToastAction.dismiss(id));
  }

  /// Dismiss all
  void dismissAll() {
    _controller.add(ToastAction.dismissAll());
  }

  void dispose() {
    _controller.close();
  }
}

// Global shorthand
final toast = ToastService.instance;

enum ToastActionType { show, dismiss, dismissAll }

class ToastAction {
  final ToastActionType type;
  final AppToastData? data;
  final String? id;

  ToastAction.show(this.data) : type = ToastActionType.show, id = null;
  ToastAction.dismiss(this.id) : type = ToastActionType.dismiss, data = null;
  ToastAction.dismissAll()
    : type = ToastActionType.dismissAll,
      data = null,
      id = null;
}

// ─────────────────────────────────────────────────────────────
// TOASTER WIDGET (place once at root of app)
// ─────────────────────────────────────────────────────────────

/// Place this inside your root `Stack` or as an overlay.
///
/// ```dart
/// MaterialApp(
///   builder: (context, child) {
///     return Stack(
///       children: [
///         child!,
///         const AppToaster(),
///       ],
///     );
///   },
/// )
/// ```
class AppToaster extends StatefulWidget {
  final int maxVisible;
  final Alignment alignment;
  final bool hasBottomNavigation;

  const AppToaster({
    super.key,
    this.maxVisible = 1,
    this.alignment = Alignment.bottomCenter,
    this.hasBottomNavigation = true,
  });

  @override
  State<AppToaster> createState() => _AppToasterState();
}

class _AppToasterState extends State<AppToaster> {
  final LinkedHashMap<String, AppToastData> _toasts = LinkedHashMap();
  final Map<String, Timer> _timers = {};
  late final StreamSubscription _sub;

  @override
  void initState() {
    super.initState();
    _sub = ToastService.instance.stream.listen(_handleAction);
  }

  @override
  void dispose() {
    _sub.cancel();
    for (final t in _timers.values) {
      t.cancel();
    }
    super.dispose();
  }

  void _handleAction(ToastAction action) {
    switch (action.type) {
      case ToastActionType.show:
        _addToast(action.data!);
        break;
      case ToastActionType.dismiss:
        _removeToast(action.id!);
        break;
      case ToastActionType.dismissAll:
        _removeAll();
        break;
    }
  }

  void _addToast(AppToastData data) {
    final removedIds = <String>[];
    setState(() {
      _toasts[data.id] = data;
      while (_toasts.length > widget.maxVisible) {
        final oldest = _toasts.keys.first;
        _toasts.remove(oldest);
        removedIds.add(oldest);
      }
    });
    for (final id in removedIds) {
      _timers.remove(id)?.cancel();
    }
    _timers.remove(data.id)?.cancel();
    late final Timer timer;
    timer = Timer(data.duration, () {
      if (_timers[data.id] != timer) return;
      _removeToast(data.id);
    });
    _timers[data.id] = timer;
  }

  void _removeToast(String id) {
    _timers.remove(id)?.cancel();
    if (!mounted || !_toasts.containsKey(id)) return;
    setState(() {
      _toasts.remove(id);
    });
  }

  void _removeAll() {
    for (final t in _timers.values) {
      t.cancel();
    }
    _timers.clear();
    if (!mounted || _toasts.isEmpty) return;
    setState(() {
      _toasts.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isBottom =
        widget.alignment == Alignment.bottomCenter ||
        widget.alignment == Alignment.bottomRight ||
        widget.alignment == Alignment.bottomLeft;

    return Positioned(
      left: 16,
      right: 16,
      bottom: isBottom
          ? AppLayout.toastBottomOffset(
              context,
              hasBottomNavigation: widget.hasBottomNavigation,
            )
          : null,
      top: isBottom ? null : 16,
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: _toasts.values.map((data) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ToastWidget(
                key: ValueKey(data.id),
                data: data,
                onDismiss: () => _removeToast(data.id),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// INDIVIDUAL TOAST WIDGET
// ─────────────────────────────────────────────────────────────

class _ToastWidget extends StatefulWidget {
  final AppToastData data;
  final VoidCallback onDismiss;

  const _ToastWidget({super.key, required this.data, required this.onDismiss});

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  double _swipeOffset = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _fadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();
  }

  Future<void> _dismiss() async {
    await _controller.reverse();
    widget.onDismiss();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = ThemeProviderScope.of(context).tokens;
    final resolved = _resolveVariant(t);

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: GestureDetector(
          onHorizontalDragUpdate: (details) {
            setState(() {
              _swipeOffset += details.delta.dx;
            });
          },
          onHorizontalDragEnd: (details) {
            if (_swipeOffset.abs() > 100) {
              _dismiss();
            } else {
              setState(() => _swipeOffset = 0);
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            transform: Matrix4.translationValues(_swipeOffset, 0, 0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: resolved.bg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: resolved.borderColor, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Leading icon
                      if (widget.data.leading != null) ...[
                        IconTheme(
                          data: IconThemeData(
                            color: resolved.iconColor,
                            size: 20,
                          ),
                          child: widget.data.leading!,
                        ),
                        const SizedBox(width: 12),
                      ],

                      // Content
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (widget.data.title != null)
                              Text(
                                widget.data.title!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: resolved.fg,
                                ),
                              ),
                            if (widget.data.title != null &&
                                widget.data.description != null)
                              const SizedBox(height: 4),
                            if (widget.data.description != null)
                              Text(
                                widget.data.description!,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: resolved.fg.withValues(alpha: 0.9),
                                ),
                              ),
                          ],
                        ),
                      ),

                      // Action button
                      if (widget.data.action != null) ...[
                        const SizedBox(width: 8),
                        widget.data.action!,
                      ] else if (widget.data.actionLabel != null) ...[
                        const SizedBox(width: 8),
                        _ToastActionButton(
                          label: widget.data.actionLabel!,
                          onTap: widget.data.onAction,
                          variant: widget.data.variant,
                          tokens: t,
                        ),
                      ],

                      // Close button
                      if (widget.data.showClose) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _dismiss,
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              Icons.close_rounded,
                              size: 16,
                              color: resolved.fg.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                      ],
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

  _ToastStyle _resolveVariant(AppColorTokens t) {
    switch (widget.data.variant) {
      case AppToastVariant.defaultVariant:
        return _ToastStyle(
          bg: t.card,
          fg: t.foreground,
          borderColor: t.border,
          iconColor: t.foreground,
        );
      case AppToastVariant.destructive:
        return _ToastStyle(
          bg: t.destructive,
          fg: AppColors.white,
          borderColor: t.destructive,
          iconColor: AppColors.white,
        );
      case AppToastVariant.success:
        return _ToastStyle(
          bg: t.card,
          fg: t.foreground,
          borderColor: t.success.withValues(alpha: 0.3),
          iconColor: t.success,
        );
      case AppToastVariant.warning:
        return _ToastStyle(
          bg: t.card,
          fg: t.foreground,
          borderColor: Colors.orange.withValues(alpha: 0.4),
          iconColor: Colors.orange,
        );
    }
  }
}

class _ToastStyle {
  final Color bg;
  final Color fg;
  final Color borderColor;
  final Color iconColor;

  const _ToastStyle({
    required this.bg,
    required this.fg,
    required this.borderColor,
    required this.iconColor,
  });
}

// ─────────────────────────────────────────────────────────────
// TOAST ACTION BUTTON
// ─────────────────────────────────────────────────────────────

class _ToastActionButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final AppToastVariant variant;
  final AppColorTokens tokens;

  const _ToastActionButton({
    required this.label,
    this.onTap,
    required this.variant,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    final isDestructive = variant == AppToastVariant.destructive;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isDestructive
              ? AppColors.white.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDestructive
                ? AppColors.white.withValues(alpha: 0.3)
                : tokens.border,
          ),
        ),
        child: Center(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDestructive ? AppColors.white : tokens.foreground,
            ),
          ),
        ),
      ),
    );
  }
}
