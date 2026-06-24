// menus.dart
// ============================================================
// Menus & Command Palette
// Includes: AppMenu (dropdown), AppCommand (spotlight)
// Skipped: Menubar, NavigationMenu, ContextMenu, HoverCard
// ============================================================

import 'package:flutter/material.dart';
import '../theme/theme_provider.dart'; // adjust path
import '../theme/app_colors.dart'; // adjust path

// ─────────────────────────────────────────────────────────────
// APP MENU (dropdown — renders as bottom sheet on mobile)
// ─────────────────────────────────────────────────────────────

/// Shows a menu of actions as a bottom sheet.
///
/// Supports: items, checkbox items, radio items,
/// labels, separators, sub-groups.
Future<T?> showAppMenu<T>({
  required BuildContext context,
  required List<AppMenuItem<T>> items,
  String? label,
}) {
  final t = ThemeProviderScope.of(context).tokens;

  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) {
      return SafeArea(
        child: Container(
          margin: const EdgeInsets.all(12),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Label
              if (label != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: t.foreground,
                      ),
                    ),
                  ),
                ),

              // Items
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: items.length,
                  itemBuilder: (_, i) =>
                      _buildMenuItem(context: ctx, item: items[i], tokens: t),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Widget _buildMenuItem<T>({
  required BuildContext context,
  required AppMenuItem<T> item,
  required AppColorTokens tokens,
}) {
  // Separator
  if (item.isSeparator) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Container(height: 1, color: tokens.muted),
    );
  }

  // Group label
  if (item.isLabel) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        item.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: tokens.mutedForeground,
        ),
      ),
    );
  }

  // Regular / checkbox / radio item
  return Opacity(
    opacity: item.enabled ? 1.0 : 0.5,
    child: GestureDetector(
      onTap: item.enabled
          ? () {
              item.onTap?.call();
              if (item.value != null) {
                Navigator.of(context).pop(item.value);
              } else {
                Navigator.of(context).pop();
              }
            }
          : null,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(6)),
        child: Row(
          children: [
            // Leading: checkbox or radio indicator
            if (item.isCheckbox) ...[
              SizedBox(
                width: 24,
                child: item.isChecked
                    ? Icon(Icons.check_rounded, size: 16, color: tokens.accent)
                    : null,
              ),
            ] else if (item.isRadio) ...[
              SizedBox(
                width: 24,
                child: item.isChecked
                    ? Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: tokens.accent,
                        ),
                      )
                    : null,
              ),
            ],

            // Icon
            if (item.icon != null) ...[
              IconTheme(
                data: IconThemeData(
                  color: item.isDestructive
                      ? tokens.destructive
                      : tokens.foreground,
                  size: 16,
                ),
                child: item.icon!,
              ),
              const SizedBox(width: 12),
            ],

            // Title
            Expanded(
              child: Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  color: item.isDestructive
                      ? tokens.destructive
                      : tokens.foreground,
                ),
              ),
            ),

            // Shortcut / trailing
            if (item.shortcut != null) ...[
              const SizedBox(width: 8),
              Text(
                item.shortcut!,
                style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 1,
                  color: tokens.mutedForeground.withValues(alpha: 0.6),
                ),
              ),
            ],

            // Sub-menu indicator
            if (item.hasSubmenu) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: tokens.mutedForeground,
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

/// Data class for a menu item.
class AppMenuItem<T> {
  final String title;
  final Widget? icon;
  final T? value;
  final VoidCallback? onTap;
  final String? shortcut;
  final bool enabled;
  final bool isDestructive;
  final bool isSeparator;
  final bool isLabel;
  final bool isCheckbox;
  final bool isRadio;
  final bool isChecked;
  final bool hasSubmenu;

  const AppMenuItem({
    this.title = '',
    this.icon,
    this.value,
    this.onTap,
    this.shortcut,
    this.enabled = true,
    this.isDestructive = false,
    this.isSeparator = false,
    this.isLabel = false,
    this.isCheckbox = false,
    this.isRadio = false,
    this.isChecked = false,
    this.hasSubmenu = false,
  });

  /// Separator shorthand
  const AppMenuItem.separator()
    : title = '',
      icon = null,
      value = null,
      onTap = null,
      shortcut = null,
      enabled = true,
      isDestructive = false,
      isSeparator = true,
      isLabel = false,
      isCheckbox = false,
      isRadio = false,
      isChecked = false,
      hasSubmenu = false;

  /// Group label shorthand
  const AppMenuItem.label(this.title)
    : icon = null,
      value = null,
      onTap = null,
      shortcut = null,
      enabled = true,
      isDestructive = false,
      isSeparator = false,
      isLabel = true,
      isCheckbox = false,
      isRadio = false,
      isChecked = false,
      hasSubmenu = false;
}

// ─────────────────────────────────────────────────────────────
// COMMAND PALETTE (spotlight / search)
// ─────────────────────────────────────────────────────────────

/// Shows a searchable command palette — mirrors cmdk/Spotlight.
Future<T?> showAppCommand<T>({
  required BuildContext context,
  required List<AppCommandGroup<T>> groups,
  String placeholder = 'Type a command or search...',
  String emptyMessage = 'No results found.',
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Command',
    barrierColor: Colors.black.withValues(alpha: 0.8),
    transitionDuration: const Duration(milliseconds: 200),
    transitionBuilder: (ctx, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOut);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.95, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
    pageBuilder: (ctx, _, __) {
      return _AppCommandContent<T>(
        groups: groups,
        placeholder: placeholder,
        emptyMessage: emptyMessage,
      );
    },
  );
}

class _AppCommandContent<T> extends StatefulWidget {
  final List<AppCommandGroup<T>> groups;
  final String placeholder;
  final String emptyMessage;

  const _AppCommandContent({
    required this.groups,
    required this.placeholder,
    required this.emptyMessage,
  });

  @override
  State<_AppCommandContent<T>> createState() => _AppCommandContentState<T>();
}

class _AppCommandContentState<T> extends State<_AppCommandContent<T>> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<AppCommandGroup<T>> get _filteredGroups {
    if (_query.isEmpty) return widget.groups;

    return widget.groups
        .map((group) {
          final filtered = group.items.where((item) {
            final q = _query.toLowerCase();
            return item.label.toLowerCase().contains(q) ||
                (item.keywords?.any((k) => k.toLowerCase().contains(q)) ??
                    false);
          }).toList();

          if (filtered.isEmpty) return null;
          return AppCommandGroup<T>(heading: group.heading, items: filtered);
        })
        .whereType<AppCommandGroup<T>>()
        .toList();
  }

  bool get _hasResults => _filteredGroups.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final t = ThemeProviderScope.of(context).tokens;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Material(
            color: Colors.transparent,
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.7,
              ),
              decoration: BoxDecoration(
                color: t.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: t.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Search input ──
                  Container(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: t.border, width: 1),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Icon(
                          Icons.search_rounded,
                          size: 18,
                          color: t.mutedForeground.withValues(alpha: 0.5),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            autofocus: true,
                            onChanged: (v) => setState(() => _query = v),
                            style: TextStyle(fontSize: 14, color: t.foreground),
                            decoration: InputDecoration(
                              hintText: widget.placeholder,
                              hintStyle: TextStyle(color: t.mutedForeground),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 14,
                              ),
                              isDense: true,
                              filled: false,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Results ──
                  Flexible(
                    child: _hasResults
                        ? ListView(
                            shrinkWrap: true,
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            children: _filteredGroups.expand((group) {
                              return [
                                // Group heading
                                if (group.heading != null)
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      8,
                                      16,
                                      4,
                                    ),
                                    child: Text(
                                      group.heading!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: t.mutedForeground,
                                      ),
                                    ),
                                  ),

                                // Items
                                ...group.items.map((item) {
                                  return _CommandItem<T>(
                                    item: item,
                                    tokens: t,
                                    onSelect: () {
                                      item.onSelect?.call();
                                      Navigator.of(context).pop(item.value);
                                    },
                                  );
                                }),
                              ];
                            }).toList(),
                          )
                        : Padding(
                            padding: const EdgeInsets.all(24),
                            child: Center(
                              child: Text(
                                widget.emptyMessage,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: t.mutedForeground,
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
      ),
    );
  }
}

// ─── Single command item ─────────────────────────────────────

class _CommandItem<T> extends StatefulWidget {
  final AppCommandItem<T> item;
  final AppColorTokens tokens;
  final VoidCallback onSelect;

  const _CommandItem({
    required this.item,
    required this.tokens,
    required this.onSelect,
  });

  @override
  State<_CommandItem<T>> createState() => _CommandItemState<T>();
}

class _CommandItemState<T> extends State<_CommandItem<T>> {
  bool _highlighted = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _highlighted = true),
      onTapUp: (_) {
        setState(() => _highlighted = false);
        widget.onSelect();
      },
      onTapCancel: () => setState(() => _highlighted = false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: _highlighted
              ? widget.tokens.accent.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            // Icon
            if (widget.item.icon != null) ...[
              IconTheme(
                data: IconThemeData(color: widget.tokens.foreground, size: 18),
                child: widget.item.icon!,
              ),
              const SizedBox(width: 12),
            ],

            // Label
            Expanded(
              child: Text(
                widget.item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, color: widget.tokens.foreground),
              ),
            ),

            // Shortcut
            if (widget.item.shortcut != null) ...[
              const SizedBox(width: 8),
              Text(
                widget.item.shortcut!,
                style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 1,
                  color: widget.tokens.mutedForeground,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Data classes ────────────────────────────────────────────

class AppCommandGroup<T> {
  final String? heading;
  final List<AppCommandItem<T>> items;

  const AppCommandGroup({this.heading, required this.items});
}

class AppCommandItem<T> {
  final String label;
  final Widget? icon;
  final T? value;
  final VoidCallback? onSelect;
  final String? shortcut;
  final List<String>? keywords;

  const AppCommandItem({
    required this.label,
    this.icon,
    this.value,
    this.onSelect,
    this.shortcut,
    this.keywords,
  });
}
