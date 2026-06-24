// glove_status.dart

import 'package:flutter/material.dart';
import '../theme/theme_provider.dart'; // adjust path
import '../theme/app_colors.dart'; // adjust path

class GloveStatus extends StatelessWidget {
  final String gloveName;
  final int batteryLevel;
  final bool isConnected;
  final int signalStrength;
  final VoidCallback? onTap;

  const GloveStatus({
    super.key,
    this.gloveName = 'IntelliGlove Pro',
    this.batteryLevel = 85,
    this.isConnected = true,
    this.signalStrength = 4,
    this.onTap,
  });

  Color _batteryColor(AppColorTokens t) {
    if (batteryLevel > 60) return t.success;
    if (batteryLevel > 30) return t.accent;
    return t.destructive;
  }

  @override
  Widget build(BuildContext context) {
    final t = ThemeProviderScope.of(context).tokens;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: t.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: t.border.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            // ── Left: Icon + name + status ──
            Expanded(
              child: Row(
                children: [
                  // Bluetooth icon box
                  _BluetoothIcon(isConnected: isConnected, tokens: t),
                  const SizedBox(width: 16),

                  // Name + connection status
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          gloveName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: t.foreground,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _StatusDot(isConnected: isConnected, tokens: t),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                isConnected ? 'Connected' : 'Disconnected',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: isConnected
                                      ? t.success
                                      : t.mutedForeground,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // ── Right: Battery + Signal ──
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Battery
                _BatteryIndicator(
                  level: batteryLevel,
                  color: _batteryColor(t),
                  tokens: t,
                ),
                const SizedBox(width: 16),

                // Signal
                _SignalIndicator(strength: signalStrength, tokens: t),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Bluetooth icon box
// ─────────────────────────────────────────────

class _BluetoothIcon extends StatelessWidget {
  final bool isConnected;
  final AppColorTokens tokens;

  const _BluetoothIcon({required this.isConnected, required this.tokens});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: isConnected
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [tokens.primary, tokens.primaryGlow],
              )
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [tokens.card, tokens.card],
              ),
        border: isConnected
            ? null
            : Border.all(color: tokens.border.withValues(alpha: 0.5)),
        boxShadow: isConnected
            ? [
                BoxShadow(
                  color: tokens.primaryGlow.withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Center(
        child: Icon(
          isConnected
              ? Icons.bluetooth_rounded
              : Icons.bluetooth_disabled_rounded,
          size: 22,
          color: isConnected ? Colors.white : tokens.mutedForeground,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Pulsing status dot
// ─────────────────────────────────────────────

class _StatusDot extends StatefulWidget {
  final bool isConnected;
  final AppColorTokens tokens;

  const _StatusDot({required this.isConnected, required this.tokens});

  @override
  State<_StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<_StatusDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    if (widget.isConnected) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _StatusDot old) {
    super.didUpdateWidget(old);
    if (widget.isConnected && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isConnected && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final opacity = widget.isConnected
            ? 0.6 + (_controller.value * 0.4)
            : 1.0;
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color:
                (widget.isConnected
                        ? widget.tokens.success
                        : widget.tokens.mutedForeground)
                    .withValues(alpha: opacity),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
//  Battery indicator
// ─────────────────────────────────────────────

class _BatteryIndicator extends StatelessWidget {
  final int level;
  final Color color;
  final AppColorTokens tokens;

  const _BatteryIndicator({
    required this.level,
    required this.color,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(_batteryIcon(), size: 18, color: color),
        const SizedBox(height: 2),
        Text(
          '$level%',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: tokens.mutedForeground,
          ),
        ),
      ],
    );
  }

  IconData _batteryIcon() {
    if (level > 90) return Icons.battery_full_rounded;
    if (level > 75) return Icons.battery_6_bar_rounded;
    if (level > 60) return Icons.battery_5_bar_rounded;
    if (level > 45) return Icons.battery_4_bar_rounded;
    if (level > 30) return Icons.battery_3_bar_rounded;
    if (level > 15) return Icons.battery_2_bar_rounded;
    if (level > 5) return Icons.battery_1_bar_rounded;
    return Icons.battery_0_bar_rounded;
  }
}

// ─────────────────────────────────────────────
//  Signal strength indicator
// ─────────────────────────────────────────────

class _SignalIndicator extends StatelessWidget {
  final int strength;
  final AppColorTokens tokens;

  const _SignalIndicator({required this.strength, required this.tokens});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Bars only — no icon
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end, // align bars to bottom
          children: List.generate(5, (i) {
            return Padding(
              padding: EdgeInsets.only(left: i == 0 ? 0 : 2),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 4,
                height: (i + 1) * 3.0,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: i < strength ? tokens.accent : tokens.muted,
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 2),
        Text(
          '$strength/5',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: tokens.mutedForeground,
          ),
        ),
      ],
    );
  }
}
