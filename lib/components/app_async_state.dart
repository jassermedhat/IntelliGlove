import 'package:flutter/material.dart';

import '../theme/theme_provider.dart';
import 'inputs.dart';

class AppLoadingState extends StatelessWidget {
  const AppLoadingState({super.key, this.message, this.padding});

  final String? message;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final t = ThemeProviderScope.of(context).tokens;
    return Semantics(
      liveRegion: true,
      label: message ?? 'Loading',
      child: Padding(
        padding: padding ?? const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: t.accent),
              if (message != null) ...[
                const SizedBox(height: 12),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: t.mutedForeground),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.message,
    this.title,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
    this.card = false,
    this.padding,
  });

  final String? title;
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool card;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) => _AppStatePanel(
    title: title,
    message: message,
    icon: icon,
    actionLabel: actionLabel,
    onAction: onAction,
    card: card,
    padding: padding,
  );
}

class AppErrorState extends StatelessWidget {
  const AppErrorState({
    super.key,
    required this.message,
    this.title = 'Something went wrong',
    this.actionLabel = 'Retry',
    this.onAction,
    this.card = false,
    this.padding,
  });

  final String? title;
  final String message;
  final String actionLabel;
  final VoidCallback? onAction;
  final bool card;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) => _AppStatePanel(
    title: title,
    message: message,
    icon: Icons.error_outline_rounded,
    actionLabel: onAction == null ? null : actionLabel,
    onAction: onAction,
    card: card,
    padding: padding,
    isError: true,
  );
}

class _AppStatePanel extends StatelessWidget {
  const _AppStatePanel({
    required this.message,
    required this.icon,
    required this.card,
    this.title,
    this.actionLabel,
    this.onAction,
    this.padding,
    this.isError = false,
  });

  final String? title;
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool card;
  final EdgeInsetsGeometry? padding;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final t = ThemeProviderScope.of(context).tokens;
    final content = Padding(
      padding: padding ?? const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 28,
            color: isError ? t.destructive : t.mutedForeground,
          ),
          if (title != null) ...[
            const SizedBox(height: 10),
            Text(
              title!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: t.foreground,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: t.mutedForeground),
          ),
          if (onAction != null && actionLabel != null) ...[
            const SizedBox(height: 14),
            AppButton(
              size: AppButtonSize.sm,
              variant: AppButtonVariant.outline,
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );

    return Semantics(
      liveRegion: true,
      container: true,
      child: SingleChildScrollView(
        child: Center(
          child: card
              ? Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: t.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: t.border.withValues(alpha: 0.4)),
                  ),
                  child: content,
                )
              : content,
        ),
      ),
    );
  }
}
