// app_top_bar.dart
// Reusable top bar components.
//
// Usage — inner page (back button):
//   AppTopBar(title: 'Device Pairing', showBackButton: true, fallbackRoute: AppRoutes.profile)
//
// Usage — page with icon:
//   AppTopBar(
//     title: 'SOS', subtitle: 'Emergency',
//     leading: Container(child: Icon(Icons.shield_outlined, ...)),
//     actions: [...],
//   )

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/theme_provider.dart';
import '../theme/app_colors.dart';
import 'app_layout.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  AppBackButton
// ─────────────────────────────────────────────────────────────────────────────

/// A back button that pops if possible, or goes to [fallbackRoute].
/// Use on inner pages only (not Home, Services, Profile tabs).
class AppBackButton extends StatelessWidget {
  final String? fallbackRoute;
  const AppBackButton({super.key, this.fallbackRoute});

  @override
  Widget build(BuildContext context) {
    final t = ThemeProviderScope.of(context).tokens;
    return IconButton(
      icon: IconTheme(
        data: IconThemeData(size: 22, color: t.foreground),
        child: const BackButtonIcon(),
      ),
      onPressed: () {
        if (context.canPop()) {
          context.pop();
        } else if (fallbackRoute != null) {
          context.go(fallbackRoute!);
        }
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  AppTopBar
// ─────────────────────────────────────────────────────────────────────────────

/// Standard 64 px top bar used across all screens.
///
/// Parameters:
/// * [title] — primary text.
/// * [subtitle] — optional secondary text shown below title.
/// * [leading] — custom leading widget (overrides [showBackButton] / [showLogo]).
/// * [showBackButton] — shows an [AppBackButton] as leading.
/// * [fallbackRoute] — passed to [AppBackButton].
/// * [showLogo] — shows the IntelliGlove bolt icon as leading.
/// * [actions] — trailing widgets (right side of the bar).
class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final String? subtitle;
  final Widget? leading;
  final bool showBackButton;
  final String? fallbackRoute;
  final bool showLogo;
  final List<Widget> actions;

  const AppTopBar({
    super.key,
    this.title,
    this.subtitle,
    this.leading,
    this.showBackButton = false,
    this.fallbackRoute,
    this.showLogo = false,
    this.actions = const [],
  });

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final t = ThemeProviderScope.of(context).tokens;

    Widget? leadingWidget = leading;

    if (leadingWidget == null) {
      if (showBackButton) {
        leadingWidget = AppBackButton(fallbackRoute: fallbackRoute);
      } else if (showLogo) {
        leadingWidget = Container(
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
        );
      }
    }

    return Container(
      constraints: BoxConstraints(minHeight: AppLayout.topBarHeight(context)),
      padding: EdgeInsets.symmetric(
        horizontal: showBackButton ? 8 : 20,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: t.background.withValues(alpha: 0.75),
        border: Border(
          bottom: BorderSide(color: t.border.withValues(alpha: 0.3)),
        ),
      ),
      child: Row(
        children: [
          if (leadingWidget != null) leadingWidget,
          if (leadingWidget != null && title != null) const SizedBox(width: 12),
          if (title != null)
            Flexible(
              child: subtitle != null
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title!,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: t.foreground,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize: 10,
                            color: t.mutedForeground,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    )
                  : Text(
                      title!,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: t.foreground,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
            ),
          const Spacer(),
          ...actions,
        ],
      ),
    );
  }
}
