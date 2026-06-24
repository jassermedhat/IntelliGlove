// inputs.dart
// ============================================================
// Interactive input/form-related UI components
// Consolidated: Button, Input, Label, Textarea, Checkbox,
// Switch, RadioGroup, Slider, Toggle, ToggleGroup, Select, Form
// ============================================================

import 'package:flutter/material.dart';
import '../theme/theme_provider.dart'; // adjust path
import '../theme/app_colors.dart'; // adjust path

// ─────────────────────────────────────────────────────────────
// BUTTON
// ─────────────────────────────────────────────────────────────

enum AppButtonVariant {
  primary,
  destructive,
  outline,
  secondary,
  ghost,
  link,
  hero,
  success,
  accent,
}

enum AppButtonSize { sm, md, lg, xl, icon }

/// Themed button with variants + sizes.
class AppButton extends StatefulWidget {
  final Widget child;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final VoidCallback? onPressed;
  final bool disabled;
  final bool loading;
  final Widget? icon;
  final double? width;

  const AppButton({
    super.key,
    required this.child,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.md,
    this.onPressed,
    this.disabled = false,
    this.loading = false,
    this.icon,
    this.width,
  });

  /// Icon-only button shorthand
  factory AppButton.icon({
    Key? key,
    required Widget icon,
    AppButtonVariant variant = AppButtonVariant.primary,
    VoidCallback? onPressed,
    bool disabled = false,
  }) => AppButton(
    key: key,
    variant: variant,
    size: AppButtonSize.icon,
    onPressed: onPressed,
    disabled: disabled,
    child: icon,
  );

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;

  bool get _enabled => !widget.disabled && !widget.loading;

  void _onTapDown(TapDownDetails _) {
    if (_enabled) setState(() => _pressed = true);
  }

  void _onTapUp([_]) {
    setState(() => _pressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = ThemeProviderScope.of(context).tokens;
    final resolved = _resolveStyle(t);
    final sizeData = _resolveSize();
    final opacity = _enabled ? 1.0 : 0.5;

    final isLink = widget.variant == AppButtonVariant.link;
    final hasElevation = [
      AppButtonVariant.primary,
      AppButtonVariant.destructive,
      AppButtonVariant.hero,
      AppButtonVariant.success,
      AppButtonVariant.accent,
    ].contains(widget.variant);

    return Opacity(
      opacity: opacity,
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: (_) {
          _onTapUp();
          if (_enabled) widget.onPressed?.call();
        },
        onTapCancel: _onTapUp,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          width: widget.size == AppButtonSize.icon
              ? sizeData.height
              : widget.width,
          height: sizeData.height,
          transform: Matrix4.translationValues(0, _pressed ? 0 : 0, 0)
            ..scale(_pressed ? 0.97 : 1.0),
          transformAlignment: Alignment.center,
          padding: widget.size == AppButtonSize.icon
              ? EdgeInsets.zero
              : sizeData.padding,
          decoration: isLink
              ? null
              : BoxDecoration(
                  color: resolved.bg,
                  gradient: resolved.gradient,
                  borderRadius: sizeData.borderRadius,
                  border: resolved.border,
                  boxShadow: hasElevation && !_pressed
                      ? [
                          BoxShadow(
                            color: (resolved.shadowColor ?? Colors.black)
                                .withValues(alpha: 0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
          child: Center(
            child: widget.loading
                ? SizedBox(
                    width: sizeData.fontSize + 4,
                    height: sizeData.fontSize + 4,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(resolved.fg),
                    ),
                  )
                : _buildContent(resolved, sizeData, isLink),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    _ButtonStyle style,
    _ButtonSizeData sizeData,
    bool isLink,
  ) {
    final textStyle = TextStyle(
      fontSize: sizeData.fontSize,
      fontWeight: FontWeight.w600,
      color: style.fg,
      letterSpacing: widget.variant == AppButtonVariant.hero ? 0.5 : 0,
      decoration: isLink ? TextDecoration.underline : null,
      decorationColor: style.fg,
    );

    if (widget.size == AppButtonSize.icon) {
      return IconTheme(
        data: IconThemeData(color: style.fg, size: 16),
        child: widget.child,
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.icon != null) ...[
          IconTheme(
            data: IconThemeData(color: style.fg, size: 16),
            child: widget.icon!,
          ),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: DefaultTextStyle(
            style: textStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            child: widget.child,
          ),
        ),
      ],
    );
  }

  _ButtonStyle _resolveStyle(AppColorTokens t) {
    switch (widget.variant) {
      case AppButtonVariant.primary:
        return _ButtonStyle(
          bg: t.primary,
          fg: t.primaryForeground,
          shadowColor: t.primaryGlow,
        );
      case AppButtonVariant.destructive:
        return _ButtonStyle(
          bg: t.destructive,
          fg: AppColors.white,
          shadowColor: t.destructive,
        );
      case AppButtonVariant.outline:
        return _ButtonStyle(
          bg: Colors.transparent,
          fg: t.foreground,
          border: Border.all(color: t.primary.withValues(alpha: 0.2), width: 2),
        );
      case AppButtonVariant.secondary:
        return _ButtonStyle(
          bg: t.secondary.withValues(alpha: 0.15),
          fg: t.secondaryForeground,
          border: Border.all(
            color: t.secondary.withValues(alpha: 0.2),
            width: 1,
          ),
        );
      case AppButtonVariant.ghost:
        return _ButtonStyle(
          bg: _pressed ? t.muted.withValues(alpha: 0.6) : Colors.transparent,
          fg: t.foreground,
        );
      case AppButtonVariant.link:
        return _ButtonStyle(bg: Colors.transparent, fg: t.accent);
      case AppButtonVariant.hero:
        return _ButtonStyle(
          bg: null,
          fg: AppColors.white,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [t.primary, t.primaryGlow],
          ),
          shadowColor: t.primaryGlow,
        );
      case AppButtonVariant.success:
        return _ButtonStyle(
          bg: t.success,
          fg: AppColors.white,
          shadowColor: t.success,
        );
      case AppButtonVariant.accent:
        return _ButtonStyle(
          bg: t.accent,
          fg: t.accentForeground,
          shadowColor: t.accent,
        );
    }
  }

  _ButtonSizeData _resolveSize() {
    switch (widget.size) {
      case AppButtonSize.sm:
        return _ButtonSizeData(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          borderRadius: BorderRadius.circular(8),
          fontSize: 12,
        );
      case AppButtonSize.md:
        return _ButtonSizeData(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          borderRadius: BorderRadius.circular(12),
          fontSize: 14,
        );
      case AppButtonSize.lg:
        return _ButtonSizeData(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 32),
          borderRadius: BorderRadius.circular(12),
          fontSize: 16,
        );
      case AppButtonSize.xl:
        return _ButtonSizeData(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 40),
          borderRadius: BorderRadius.circular(16),
          fontSize: 16,
        );
      case AppButtonSize.icon:
        return _ButtonSizeData(
          height: 44,
          padding: EdgeInsets.zero,
          borderRadius: BorderRadius.circular(12),
          fontSize: 14,
        );
    }
  }
}

class _ButtonStyle {
  final Color? bg;
  final Color fg;
  final LinearGradient? gradient;
  final Border? border;
  final Color? shadowColor;

  const _ButtonStyle({
    this.bg,
    required this.fg,
    this.gradient,
    this.border,
    this.shadowColor,
  });
}

class _ButtonSizeData {
  final double height;
  final EdgeInsetsGeometry padding;
  final BorderRadiusGeometry borderRadius;
  final double fontSize;

  const _ButtonSizeData({
    required this.height,
    required this.padding,
    required this.borderRadius,
    required this.fontSize,
  });
}

// ─────────────────────────────────────────────────────────────
// INPUT
// ─────────────────────────────────────────────────────────────

/// Text input — uses theme's `InputDecorationTheme` by default.
class AppInput extends StatelessWidget {
  final TextEditingController? controller;
  final String? hintText;
  final String? labelText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final bool enabled;
  final bool readOnly;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final String? errorText;
  final int maxLines;
  final FocusNode? focusNode;
  final bool autofocus;
  final InputDecoration? decoration;

  const AppInput({
    super.key,
    this.controller,
    this.hintText,
    this.labelText,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.enabled = true,
    this.readOnly = false,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.errorText,
    this.maxLines = 1,
    this.focusNode,
    this.autofocus = false,
    this.decoration,
  });

  @override
  Widget build(BuildContext context) {
    // Inherits from InputDecorationTheme set in AppTheme
    return TextField(
      controller: controller,
      obscureText: obscureText,
      enabled: enabled,
      readOnly: readOnly,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      onTap: onTap,
      maxLines: maxLines,
      focusNode: focusNode,
      autofocus: autofocus,
      style: TextStyle(
        fontSize: 14,
        color: Theme.of(context).colorScheme.onSurface,
      ),
      decoration:
          decoration ??
          InputDecoration(
            hintText: hintText,
            labelText: labelText,
            prefixIcon: prefixIcon,
            suffixIcon: suffixIcon,
            errorText: errorText,
          ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// LABEL
// ─────────────────────────────────────────────────────────────

/// Form label — `text-sm font-medium leading-none`
class AppLabel extends StatelessWidget {
  final String text;
  final bool isError;
  final bool isDisabled;
  final EdgeInsetsGeometry? padding;

  const AppLabel(
    this.text, {
    super.key,
    this.isError = false,
    this.isDisabled = false,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final t = ThemeProviderScope.of(context).tokens;

    return Padding(
      padding: padding ?? const EdgeInsets.only(bottom: 6),
      child: Opacity(
        opacity: isDisabled ? 0.7 : 1.0,
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isError ? t.destructive : t.foreground,
            height: 1.0,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// TEXTAREA
// ─────────────────────────────────────────────────────────────

/// Multi-line text input.
class AppTextarea extends StatelessWidget {
  final TextEditingController? controller;
  final String? hintText;
  final String? labelText;
  final bool enabled;
  final int minLines;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final String? errorText;
  final FocusNode? focusNode;

  const AppTextarea({
    super.key,
    this.controller,
    this.hintText,
    this.labelText,
    this.enabled = true,
    this.minLines = 3,
    this.maxLines = 6,
    this.onChanged,
    this.errorText,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      minLines: minLines,
      maxLines: maxLines,
      onChanged: onChanged,
      focusNode: focusNode,
      style: TextStyle(
        fontSize: 14,
        color: Theme.of(context).colorScheme.onSurface,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        labelText: labelText,
        errorText: errorText,
        // Override content padding for textarea feel
        contentPadding: const EdgeInsets.all(12),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// CHECKBOX
// ─────────────────────────────────────────────────────────────

/// Themed checkbox with optional label.
class AppCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool?>? onChanged;
  final String? label;
  final bool enabled;

  const AppCheckbox({
    super.key,
    required this.value,
    this.onChanged,
    this.label,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final t = ThemeProviderScope.of(context).tokens;

    // Uses CheckboxThemeData from AppTheme
    if (label == null) {
      return Checkbox(value: value, onChanged: enabled ? onChanged : null);
    }

    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: GestureDetector(
        onTap: enabled ? () => onChanged?.call(!value) : null,
        behavior: HitTestBehavior.opaque,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Checkbox(value: value, onChanged: enabled ? onChanged : null),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, color: t.foreground),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SWITCH
// ─────────────────────────────────────────────────────────────

/// Themed switch with optional label.
class AppSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? label;
  final bool enabled;

  const AppSwitch({
    super.key,
    required this.value,
    this.onChanged,
    this.label,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final t = ThemeProviderScope.of(context).tokens;

    // Uses SwitchThemeData from AppTheme
    final switchWidget = Switch(
      value: value,
      onChanged: enabled ? onChanged : null,
    );

    if (label == null) return switchWidget;

    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: GestureDetector(
        onTap: enabled ? () => onChanged?.call(!value) : null,
        behavior: HitTestBehavior.opaque,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, color: t.foreground),
              ),
            ),
            const SizedBox(width: 12),
            switchWidget,
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// RADIO GROUP
// ─────────────────────────────────────────────────────────────

/// Radio group with label support.
class AppRadioGroup<T> extends StatelessWidget {
  final T? value;
  final List<AppRadioItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final bool enabled;
  final Axis direction;
  final double spacing;

  const AppRadioGroup({
    super.key,
    required this.value,
    required this.items,
    this.onChanged,
    this.enabled = true,
    this.direction = Axis.vertical,
    this.spacing = 8,
  });

  @override
  Widget build(BuildContext context) {
    final t = ThemeProviderScope.of(context).tokens;

    final children = items.map((item) {
      return Opacity(
        opacity: enabled ? 1.0 : 0.5,
        child: GestureDetector(
          onTap: enabled ? () => onChanged?.call(item.value) : null,
          behavior: HitTestBehavior.opaque,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Radio<T>(
                value: item.value,
                groupValue: value,
                onChanged: enabled ? onChanged : null,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  item.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, color: t.foreground),
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();

    if (direction == Axis.horizontal) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: _interleave(children, SizedBox(width: spacing)),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _interleave(children, SizedBox(height: spacing)),
    );
  }
}

class AppRadioItem<T> {
  final T value;
  final String label;

  const AppRadioItem({required this.value, required this.label});
}

// ─────────────────────────────────────────────────────────────
// SLIDER
// ─────────────────────────────────────────────────────────────

/// Themed slider.
class AppSlider extends StatelessWidget {
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeEnd;
  final bool enabled;
  final String? label;
  final Color? activeColor;

  const AppSlider({
    super.key,
    required this.value,
    this.min = 0,
    this.max = 1,
    this.divisions,
    this.onChanged,
    this.onChangeEnd,
    this.enabled = true,
    this.label,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final t = ThemeProviderScope.of(context).tokens;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: t.foreground,
            ),
          ),
          const SizedBox(height: 8),
        ],
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: activeColor ?? t.primary,
            inactiveTrackColor: t.secondary.withValues(alpha: 0.3),
            thumbColor: activeColor ?? t.primary,
            overlayColor: (activeColor ?? t.primary).withValues(alpha: 0.15),
            trackHeight: 8,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: enabled ? onChanged : null,
            onChangeEnd: onChangeEnd,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// TOGGLE
// ─────────────────────────────────────────────────────────────

enum AppToggleVariant { filled, outline }

enum AppToggleSize { sm, md, lg }

/// Single toggle button.
class AppToggle extends StatelessWidget {
  final bool isSelected;
  final VoidCallback? onPressed;
  final Widget child;
  final AppToggleVariant variant;
  final AppToggleSize size;
  final bool enabled;

  const AppToggle({
    super.key,
    required this.isSelected,
    this.onPressed,
    required this.child,
    this.variant = AppToggleVariant.filled,
    this.size = AppToggleSize.md,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final t = ThemeProviderScope.of(context).tokens;
    final sizeData = _resolveSize();

    final Color bg;
    final Color fg;
    final Border? border;

    if (isSelected) {
      bg = t.accent.withValues(alpha: 0.15);
      fg = t.accent;
      border = variant == AppToggleVariant.outline
          ? Border.all(color: t.accent.withValues(alpha: 0.5))
          : null;
    } else {
      bg = variant == AppToggleVariant.outline
          ? Colors.transparent
          : Colors.transparent;
      fg = t.mutedForeground;
      border = variant == AppToggleVariant.outline
          ? Border.all(color: t.border)
          : null;
    }

    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: GestureDetector(
        onTap: enabled ? onPressed : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: sizeData.height,
          padding: sizeData.padding,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
            border: border,
          ),
          child: Center(
            child: IconTheme(
              data: IconThemeData(color: fg, size: 16),
              child: DefaultTextStyle(
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: fg,
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }

  _ToggleSizeData _resolveSize() {
    switch (size) {
      case AppToggleSize.sm:
        return const _ToggleSizeData(
          height: 36,
          padding: EdgeInsets.symmetric(horizontal: 10),
        );
      case AppToggleSize.md:
        return const _ToggleSizeData(
          height: 40,
          padding: EdgeInsets.symmetric(horizontal: 12),
        );
      case AppToggleSize.lg:
        return const _ToggleSizeData(
          height: 44,
          padding: EdgeInsets.symmetric(horizontal: 20),
        );
    }
  }
}

class _ToggleSizeData {
  final double height;
  final EdgeInsetsGeometry padding;
  const _ToggleSizeData({required this.height, required this.padding});
}

// ─────────────────────────────────────────────────────────────
// TOGGLE GROUP
// ─────────────────────────────────────────────────────────────

/// Group of toggles — single or multi-select.
class AppToggleGroup<T> extends StatelessWidget {
  final List<AppToggleGroupItem<T>> items;
  final Set<T> selected;
  final ValueChanged<T> onToggle;
  final bool allowMultiple;
  final AppToggleVariant variant;
  final AppToggleSize size;
  final double spacing;

  const AppToggleGroup({
    super.key,
    required this.items,
    required this.selected,
    required this.onToggle,
    this.allowMultiple = false,
    this.variant = AppToggleVariant.filled,
    this.size = AppToggleSize.md,
    this.spacing = 4,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: _interleave(
          items.map((item) {
            return AppToggle(
              isSelected: selected.contains(item.value),
              onPressed: () => onToggle(item.value),
              variant: variant,
              size: size,
              child: item.child,
            );
          }).toList(),
          SizedBox(width: spacing),
        ),
      ),
    );
  }
}

class AppToggleGroupItem<T> {
  final T value;
  final Widget child;

  const AppToggleGroupItem({required this.value, required this.child});
}

// ─────────────────────────────────────────────────────────────
// SELECT (Dropdown)
// ─────────────────────────────────────────────────────────────

/// Select / dropdown that opens a bottom sheet on mobile.
class AppSelect<T> extends StatelessWidget {
  final T? value;
  final List<AppSelectItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final String? hintText;
  final String? labelText;
  final String? errorText;
  final bool enabled;
  final Widget? prefixIcon;

  const AppSelect({
    super.key,
    this.value,
    required this.items,
    this.onChanged,
    this.hintText,
    this.labelText,
    this.errorText,
    this.enabled = true,
    this.prefixIcon,
  });

  @override
  Widget build(BuildContext context) {
    final t = ThemeProviderScope.of(context).tokens;

    // Find selected item's label
    final selectedLabel = items
        .where((i) => i.value == value)
        .map((i) => i.label)
        .firstOrNull;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (labelText != null) AppLabel(labelText!),

        GestureDetector(
          onTap: enabled ? () => _showSelectSheet(context, t) : null,
          child: Opacity(
            opacity: enabled ? 1.0 : 0.5,
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: t.muted,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: errorText != null ? t.destructive : t.border,
                  width: errorText != null ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  if (prefixIcon != null) ...[
                    IconTheme(
                      data: IconThemeData(color: t.mutedForeground, size: 18),
                      child: prefixIcon!,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      selectedLabel ?? hintText ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        color: selectedLabel != null
                            ? t.foreground
                            : t.mutedForeground,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: t.mutedForeground.withValues(alpha: 0.5),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Error text
        if (errorText != null) ...[
          const SizedBox(height: 6),
          Text(
            errorText!,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: t.destructive,
            ),
          ),
        ],
      ],
    );
  }

  void _showSelectSheet(BuildContext context, AppColorTokens t) {
    showModalBottomSheet(
      context: context,
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
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: t.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 8),
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: t.muted,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Items
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: items.length,
                    itemBuilder: (_, i) {
                      final item = items[i];
                      final isSelected = item.value == value;

                      // Group label
                      if (item.isGroupLabel) {
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                          child: Text(
                            item.label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: t.mutedForeground,
                            ),
                          ),
                        );
                      }

                      // Separator
                      if (item.isSeparator) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 4,
                            horizontal: 4,
                          ),
                          child: Container(height: 1, color: t.muted),
                        );
                      }

                      return GestureDetector(
                        onTap: () {
                          onChanged?.call(item.value);
                          Navigator.pop(ctx);
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          margin: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? t.accent.withValues(alpha: 0.1)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              // Check mark
                              SizedBox(
                                width: 24,
                                child: isSelected
                                    ? Icon(
                                        Icons.check_rounded,
                                        size: 16,
                                        color: t.accent,
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  item.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isSelected ? t.accent : t.foreground,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class AppSelectItem<T> {
  final T? value;
  final String label;
  final bool isGroupLabel;
  final bool isSeparator;

  const AppSelectItem({
    this.value,
    required this.label,
    this.isGroupLabel = false,
    this.isSeparator = false,
  });

  /// Group label shorthand
  const AppSelectItem.group(this.label)
    : value = null,
      isGroupLabel = true,
      isSeparator = false;

  /// Separator shorthand
  const AppSelectItem.separator()
    : value = null,
      label = '',
      isGroupLabel = false,
      isSeparator = true;
}

// ─────────────────────────────────────────────────────────────
// FORM FIELD WRAPPER
// ─────────────────────────────────────────────────────────────

/// Wraps any input with label, description, error — mirrors React FormItem.
class AppFormField extends StatelessWidget {
  final String? label;
  final String? description;
  final String? errorMessage;
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const AppFormField({
    super.key,
    this.label,
    this.description,
    this.errorMessage,
    required this.child,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final t = ThemeProviderScope.of(context).tokens;

    return Padding(
      padding: padding ?? const EdgeInsets.only(bottom: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label
          if (label != null) AppLabel(label!, isError: errorMessage != null),

          // Input
          child,

          // Description
          if (description != null && errorMessage == null) ...[
            const SizedBox(height: 6),
            Text(
              description!,
              style: TextStyle(fontSize: 12, color: t.mutedForeground),
            ),
          ],

          // Error
          if (errorMessage != null) ...[
            const SizedBox(height: 6),
            Text(
              errorMessage!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: t.destructive,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────

/// Interleaves a list with a separator widget.
List<Widget> _interleave(List<Widget> widgets, Widget separator) {
  if (widgets.isEmpty) return widgets;
  final result = <Widget>[];
  for (var i = 0; i < widgets.length; i++) {
    result.add(widgets[i]);
    if (i < widgets.length - 1) result.add(separator);
  }
  return result;
}
