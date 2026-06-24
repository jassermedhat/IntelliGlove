// feedback2.dart
// ============================================================
// Media, Layout Utilities & Form Inputs
// Includes: Carousel, Collapsible, Pagination, InputOTP
// Skipped: Resizable (not mobile), ScrollArea (use Flutter's built-in)
// AspectRatio → use Flutter's built-in AspectRatio widget
// ============================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/theme_provider.dart'; // adjust path
import '../theme/app_colors.dart'; // adjust path

// ─────────────────────────────────────────────────────────────
// CAROUSEL
// ─────────────────────────────────────────────────────────────

/// Full-featured carousel — wraps PageView with prev/next, dots,
/// auto-play, and snapping. Mirrors Embla Carousel behavior.
class AppCarousel extends StatefulWidget {
  final List<Widget> items;
  final Axis orientation;
  final bool showArrows;
  final bool showDots;
  final bool autoPlay;
  final Duration autoPlayInterval;
  final double viewportFraction;
  final ValueChanged<int>? onPageChanged;
  final EdgeInsetsGeometry? padding;
  final double? height;
  final int initialIndex;

  const AppCarousel({
    super.key,
    required this.items,
    this.orientation = Axis.horizontal,
    this.showArrows = true,
    this.showDots = true,
    this.autoPlay = false,
    this.autoPlayInterval = const Duration(seconds: 4),
    this.viewportFraction = 1.0,
    this.onPageChanged,
    this.padding,
    this.height,
    this.initialIndex = 0,
  });

  @override
  State<AppCarousel> createState() => _AppCarouselState();
}

class _AppCarouselState extends State<AppCarousel> {
  late final PageController _controller;
  late int _currentPage;
  Timer? _autoPlayTimer;

  bool get _canScrollPrev => _currentPage > 0;
  bool get _canScrollNext => _currentPage < widget.items.length - 1;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialIndex;
    _controller = PageController(
      initialPage: widget.initialIndex,
      viewportFraction: widget.viewportFraction,
    );
    if (widget.autoPlay) _startAutoPlay();
  }

  @override
  void didUpdateWidget(covariant AppCarousel old) {
    super.didUpdateWidget(old);
    if (widget.autoPlay && !old.autoPlay) {
      _startAutoPlay();
    } else if (!widget.autoPlay && old.autoPlay) {
      _stopAutoPlay();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _stopAutoPlay();
    super.dispose();
  }

  void _startAutoPlay() {
    _stopAutoPlay();
    _autoPlayTimer = Timer.periodic(widget.autoPlayInterval, (_) {
      if (!mounted) return;
      final next = _canScrollNext ? _currentPage + 1 : 0;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  void _stopAutoPlay() {
    _autoPlayTimer?.cancel();
    _autoPlayTimer = null;
  }

  void _scrollPrev() {
    if (!_canScrollPrev) return;
    _controller.animateToPage(
      _currentPage - 1,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _scrollNext() {
    if (!_canScrollNext) return;
    _controller.animateToPage(
      _currentPage + 1,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = ThemeProviderScope.of(context).tokens;

    return Padding(
      padding: widget.padding ?? EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Carousel body ──
          SizedBox(
            height: widget.height ?? 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // PageView
                PageView.builder(
                  controller: _controller,
                  scrollDirection: widget.orientation,
                  itemCount: widget.items.length,
                  onPageChanged: (i) {
                    setState(() => _currentPage = i);
                    widget.onPageChanged?.call(i);
                  },
                  itemBuilder: (context, i) {
                    return Padding(
                      padding: widget.viewportFraction < 1.0
                          ? const EdgeInsets.symmetric(horizontal: 8)
                          : EdgeInsets.zero,
                      child: widget.items[i],
                    );
                  },
                ),

                // ── Prev/Next arrows ──
                if (widget.showArrows && widget.orientation == Axis.horizontal)
                  Positioned.fill(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _CarouselArrow(
                          icon: Icons.arrow_back_rounded,
                          enabled: _canScrollPrev,
                          onTap: _scrollPrev,
                          tokens: t,
                        ),
                        _CarouselArrow(
                          icon: Icons.arrow_forward_rounded,
                          enabled: _canScrollNext,
                          onTap: _scrollNext,
                          tokens: t,
                        ),
                      ],
                    ),
                  ),

                if (widget.showArrows && widget.orientation == Axis.vertical)
                  Positioned.fill(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _CarouselArrow(
                          icon: Icons.arrow_upward_rounded,
                          enabled: _canScrollPrev,
                          onTap: _scrollPrev,
                          tokens: t,
                        ),
                        _CarouselArrow(
                          icon: Icons.arrow_downward_rounded,
                          enabled: _canScrollNext,
                          onTap: _scrollNext,
                          tokens: t,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // ── Dot indicators ──
          if (widget.showDots && widget.items.length > 1) ...[
            const SizedBox(height: 12),
            _CarouselDots(
              count: widget.items.length,
              current: _currentPage,
              tokens: t,
              onTap: (i) {
                _controller.animateToPage(
                  i,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Arrow button ────────────────────────────────────────────

class _CarouselArrow extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  final AppColorTokens tokens;

  const _CarouselArrow({
    required this.icon,
    required this.enabled,
    required this.onTap,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.3,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          width: 32,
          height: 32,
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: tokens.card.withValues(alpha: 0.9),
            border: Border.all(color: tokens.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(child: Icon(icon, size: 16, color: tokens.foreground)),
        ),
      ),
    );
  }
}

// ─── Dot indicators ──────────────────────────────────────────

class _CarouselDots extends StatelessWidget {
  final int count;
  final int current;
  final AppColorTokens tokens;
  final ValueChanged<int> onTap;

  const _CarouselDots({
    required this.count,
    required this.current,
    required this.tokens,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(count, (i) {
          final isActive = i == current;
          return GestureDetector(
            onTap: () => onTap(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              width: isActive ? 20 : 8,
              height: 8,
              margin: EdgeInsets.only(left: i == 0 ? 0 : 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: isActive
                    ? tokens.accent
                    : tokens.mutedForeground.withValues(alpha: 0.3),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// COLLAPSIBLE
// ─────────────────────────────────────────────────────────────

/// Collapsible container with trigger + animated content.
/// Mirrors Radix Collapsible.
class AppCollapsible extends StatefulWidget {
  final Widget trigger;
  final Widget content;
  final bool initiallyOpen;
  final ValueChanged<bool>? onOpenChange;
  final Duration duration;

  const AppCollapsible({
    super.key,
    required this.trigger,
    required this.content,
    this.initiallyOpen = false,
    this.onOpenChange,
    this.duration = const Duration(milliseconds: 200),
  });

  @override
  State<AppCollapsible> createState() => _AppCollapsibleState();
}

class _AppCollapsibleState extends State<AppCollapsible> {
  late bool _isOpen;

  @override
  void initState() {
    super.initState();
    _isOpen = widget.initiallyOpen;
  }

  void _toggle() {
    setState(() => _isOpen = !_isOpen);
    widget.onOpenChange?.call(_isOpen);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Trigger
        GestureDetector(
          onTap: _toggle,
          behavior: HitTestBehavior.opaque,
          child: widget.trigger,
        ),

        // Animated content
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity, height: 0),
          secondChild: widget.content,
          crossFadeState: _isOpen
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: widget.duration,
          sizeCurve: Curves.easeOut,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// PAGINATION
// ─────────────────────────────────────────────────────────────

/// Full pagination bar with prev, next, page numbers, ellipsis.
class AppPagination extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final ValueChanged<int> onPageChanged;
  final int siblingCount;
  final EdgeInsetsGeometry? margin;

  const AppPagination({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.onPageChanged,
    this.siblingCount = 1,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final t = ThemeProviderScope.of(context).tokens;
    final pages = _generatePages();

    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: Center(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Previous
              _PaginationNavButton(
                icon: Icons.chevron_left_rounded,
                label: 'Previous',
                enabled: currentPage > 1,
                onTap: () => onPageChanged(currentPage - 1),
                tokens: t,
              ),
              const SizedBox(width: 4),

              // Page items
              ...pages.map((page) {
                if (page == -1) {
                  // Ellipsis
                  return _PaginationEllipsis(tokens: t);
                }
                return _PaginationPageButton(
                  page: page,
                  isActive: page == currentPage,
                  onTap: () => onPageChanged(page),
                  tokens: t,
                );
              }),

              const SizedBox(width: 4),

              // Next
              _PaginationNavButton(
                icon: Icons.chevron_right_rounded,
                label: 'Next',
                enabled: currentPage < totalPages,
                onTap: () => onPageChanged(currentPage + 1),
                tokens: t,
                showLabelAfterIcon: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Generates page numbers with ellipsis (-1 = ellipsis).
  List<int> _generatePages() {
    if (totalPages <= 7) {
      return List.generate(totalPages, (i) => i + 1);
    }

    final pages = <int>{};
    pages.add(1);
    pages.add(totalPages);

    for (
      var i = currentPage - siblingCount;
      i <= currentPage + siblingCount;
      i++
    ) {
      if (i >= 1 && i <= totalPages) pages.add(i);
    }

    final sorted = pages.toList()..sort();
    final result = <int>[];

    for (var i = 0; i < sorted.length; i++) {
      if (i > 0 && sorted[i] - sorted[i - 1] > 1) {
        result.add(-1); // ellipsis
      }
      result.add(sorted[i]);
    }

    return result;
  }
}

// ─── Page number button ──────────────────────────────────────

class _PaginationPageButton extends StatelessWidget {
  final int page;
  final bool isActive;
  final VoidCallback onTap;
  final AppColorTokens tokens;

  const _PaginationPageButton({
    required this.page,
    required this.isActive,
    required this.onTap,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isActive ? Colors.transparent : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isActive
                ? Border.all(color: tokens.border, width: 1)
                : null,
          ),
          child: Center(
            child: Text(
              '$page',
              style: TextStyle(
                fontSize: 14,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive ? tokens.foreground : tokens.mutedForeground,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Nav button (prev/next) ──────────────────────────────────

class _PaginationNavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;
  final AppColorTokens tokens;
  final bool showLabelAfterIcon;

  const _PaginationNavButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
    required this.tokens,
    this.showLabelAfterIcon = false,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: showLabelAfterIcon
                ? [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        color: tokens.mutedForeground,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(icon, size: 16, color: tokens.mutedForeground),
                  ]
                : [
                    Icon(icon, size: 16, color: tokens.mutedForeground),
                    const SizedBox(width: 4),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        color: tokens.mutedForeground,
                      ),
                    ),
                  ],
          ),
        ),
      ),
    );
  }
}

// ─── Ellipsis ────────────────────────────────────────────────

class _PaginationEllipsis extends StatelessWidget {
  final AppColorTokens tokens;

  const _PaginationEllipsis({required this.tokens});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 36,
      child: Center(
        child: Icon(
          Icons.more_horiz_rounded,
          size: 16,
          color: tokens.mutedForeground,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// INPUT OTP
// ─────────────────────────────────────────────────────────────

/// OTP input with individual character slots.
class AppInputOTP extends StatefulWidget {
  final int length;
  final ValueChanged<String>? onCompleted;
  final ValueChanged<String>? onChanged;
  final bool obscureText;
  final bool autofocus;
  final bool enabled;
  final List<int>? separatorPositions;
  final TextInputType keyboardType;

  const AppInputOTP({
    super.key,
    this.length = 6,
    this.onCompleted,
    this.onChanged,
    this.obscureText = false,
    this.autofocus = true,
    this.enabled = true,
    this.separatorPositions,
    this.keyboardType = TextInputType.number,
  });

  @override
  State<AppInputOTP> createState() => _AppInputOTPState();
}

class _AppInputOTPState extends State<AppInputOTP> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(widget.length, (_) => TextEditingController());
    _focusNodes = List.generate(widget.length, (_) => FocusNode());

    // Auto-focus first slot
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNodes[0].requestFocus();
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _currentValue => _controllers.map((c) => c.text).join();

  void _onChanged(int index, String value) {
    if (value.length > 1) {
      // Handle paste — distribute characters
      _handlePaste(value, index);
      return;
    }

    if (value.isNotEmpty && index < widget.length - 1) {
      _focusNodes[index + 1].requestFocus();
    }

    widget.onChanged?.call(_currentValue);

    if (_currentValue.length == widget.length) {
      widget.onCompleted?.call(_currentValue);
    }
  }

  void _handlePaste(String value, int startIndex) {
    final chars = value.split('');
    for (var i = 0; i < chars.length && (startIndex + i) < widget.length; i++) {
      _controllers[startIndex + i].text = chars[i];
    }

    final nextFocus = (startIndex + chars.length).clamp(0, widget.length - 1);
    _focusNodes[nextFocus].requestFocus();

    widget.onChanged?.call(_currentValue);

    if (_currentValue.length == widget.length) {
      widget.onCompleted?.call(_currentValue);
    }
  }

  void _onKeyEvent(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace) {
      if (_controllers[index].text.isEmpty && index > 0) {
        _controllers[index - 1].clear();
        _focusNodes[index - 1].requestFocus();
        widget.onChanged?.call(_currentValue);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ThemeProviderScope.of(context).tokens;
    final separators = widget.separatorPositions ?? [];

    return Opacity(
      opacity: widget.enabled ? 1.0 : 0.5,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(widget.length, (i) {
            final slot = _OTPSlot(
              index: i,
              controller: _controllers[i],
              focusNode: _focusNodes[i],
              obscureText: widget.obscureText,
              enabled: widget.enabled,
              keyboardType: widget.keyboardType,
              isFirst: i == 0,
              isLast: i == widget.length - 1,
              tokens: t,
              onChanged: (v) => _onChanged(i, v),
              onKeyEvent: (e) => _onKeyEvent(i, e),
            );

            // Add separator after this slot?
            if (separators.contains(i + 1) && i < widget.length - 1) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  slot,
                  _OTPSeparator(tokens: t),
                ],
              );
            }

            return slot;
          }),
        ),
      ),
    );
  }
}

// ─── Single OTP slot ─────────────────────────────────────────

class _OTPSlot extends StatelessWidget {
  final int index;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool obscureText;
  final bool enabled;
  final TextInputType keyboardType;
  final bool isFirst;
  final bool isLast;
  final AppColorTokens tokens;
  final ValueChanged<String> onChanged;
  final ValueChanged<KeyEvent> onKeyEvent;

  const _OTPSlot({
    required this.index,
    required this.controller,
    required this.focusNode,
    required this.obscureText,
    required this.enabled,
    required this.keyboardType,
    required this.isFirst,
    required this.isLast,
    required this.tokens,
    required this.onChanged,
    required this.onKeyEvent,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: KeyboardListener(
        focusNode: FocusNode(),
        onKeyEvent: onKeyEvent,
        child: AnimatedBuilder(
          animation: focusNode,
          builder: (context, child) {
            final isFocused = focusNode.hasFocus;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                border: Border.all(
                  color: isFocused ? tokens.ring : tokens.border,
                  width: isFocused ? 2 : 1,
                ),
                borderRadius: BorderRadius.horizontal(
                  left: isFirst ? const Radius.circular(8) : Radius.zero,
                  right: isLast ? const Radius.circular(8) : Radius.zero,
                ),
                color: tokens.card,
              ),
              alignment: Alignment.center,
              child: child,
            );
          },
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            enabled: enabled,
            obscureText: obscureText,
            keyboardType: keyboardType,
            textAlign: TextAlign.center,
            maxLength: 1,
            onChanged: onChanged,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: tokens.foreground,
            ),
            inputFormatters: [
              LengthLimitingTextInputFormatter(1),
              if (keyboardType == TextInputType.number)
                FilteringTextInputFormatter.digitsOnly,
            ],
            decoration: const InputDecoration(
              counterText: '',
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              isDense: true,
              filled: false,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── OTP separator dot ───────────────────────────────────────

class _OTPSeparator extends StatelessWidget {
  final AppColorTokens tokens;

  const _OTPSeparator({required this.tokens});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: tokens.mutedForeground.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}
