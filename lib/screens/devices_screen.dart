// devices_screen.dart
// User-facing Devices page — shows connected/saved glove details.
// Both Home → Devices and Profile → Devices open this page.
// Pair Device / Pair New Device button opens DevicePairingScreen.

import 'package:flutter/material.dart';
import '../components/app_layout.dart';
import 'package:go_router/go_router.dart';
import '../theme/theme_provider.dart';
import '../theme/app_colors.dart';
import '../components/inputs.dart';
import '../components/app_top_bar.dart';
import '../components/toast.dart';
import '../services/glove_state_provider.dart';
import '../services/pairing_controller.dart';
import '../app_routes.dart';
import '../models/glove_device.dart';

class DevicesScreen extends StatelessWidget {
  const DevicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = ThemeProviderScope.of(context).tokens;
    final isDark = ThemeProviderScope.of(context).isDark;
    final glove = GloveStateScope.of(context);
    final pairing = PairingControllerScope.of(context);

    return Scaffold(
      backgroundColor: t.background,
      body: Stack(
        children: [
          Positioned(
            top: -60,
            right: 0,
            child: _Orb(color: t.accent.withValues(alpha: 0.05), size: 260),
          ),
          Positioned(
            bottom: 160,
            left: -60,
            child: _Orb(color: t.primary.withValues(alpha: 0.05), size: 200),
          ),
          SafeArea(
            child: Column(
              children: [
                // ── Top bar ──────────────────────────────────────────────
                Container(
                  constraints: BoxConstraints(
                    minHeight: AppLayout.topBarHeight(context),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: t.background.withValues(alpha: 0.75),
                    border: Border(
                      bottom: BorderSide(
                        color: t.border.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      AppBackButton(fallbackRoute: AppRoutes.profile),
                      Text(
                        'Devices',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: t.foreground,
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
                ),

                // ── Scrollable body ───────────────────────────────────────
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      24,
                      20,
                      AppLayout.bottomNavClearance(context),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Hero
                        Row(
                          children: [
                            Container(
                              width: 28,
                              height: 4,
                              decoration: BoxDecoration(
                                color: t.accent,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'BLUETOOTH',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: t.accent,
                                letterSpacing: 2.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Devices',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: t.foreground,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Manage paired glove and connection',
                          style: TextStyle(
                            fontSize: 13,
                            color: t.mutedForeground,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // ── Connected / Saved glove card ───────────────────
                        if (glove.hasPairedDevice) ...[
                          _SectionLabel(t: t, label: 'PAIRED DEVICE'),
                          const SizedBox(height: 12),
                          _ConnectedCard(
                            t: t,
                            isDark: isDark,
                            device: glove.pairedDevice!,
                            connectionStatus: glove.connectionStatus,
                          ),
                          const SizedBox(height: 20),

                          // Actions
                          _SectionLabel(t: t, label: 'ACTIONS'),
                          const SizedBox(height: 12),
                          Container(
                            decoration: BoxDecoration(
                              color: t.card,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: t.border.withValues(alpha: 0.4),
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _ActionRow(
                                  t: t,
                                  icon: Icons.system_update_rounded,
                                  iconColor: t.accent,
                                  iconBg: t.accent.withValues(alpha: 0.1),
                                  label: 'Firmware Updates',
                                  desc: 'Check for OTA updates',
                                  divider: true,
                                  onTap: () => context.push(
                                    AppRoutes.profileDeviceUpdates,
                                  ),
                                ),
                                _ActionRow(
                                  t: t,
                                  icon: Icons.bluetooth_searching_rounded,
                                  iconColor: t.accent,
                                  iconBg: t.accent.withValues(alpha: 0.1),
                                  label: 'Pair New Device',
                                  desc: 'Connect a different glove',
                                  divider: true,
                                  onTap: () => context.push(
                                    AppRoutes.profileDevicePairing,
                                  ),
                                ),
                                _ActionRow(
                                  t: t,
                                  icon: Icons.wifi_off_rounded,
                                  iconColor: t.destructive,
                                  iconBg: t.destructive.withValues(alpha: 0.1),
                                  label: 'Disconnect',
                                  desc: 'Disconnect from current device',
                                  labelColor: t.destructive,
                                  divider: true,
                                  onTap: pairing.isDeviceActionActive
                                      ? null
                                      : () async {
                                          final disconnected = await pairing
                                              .disconnect();
                                          if (!context.mounted) return;
                                          if (disconnected) {
                                            toast.success(
                                              title: 'Glove disconnected',
                                              description:
                                                  'The paired glove remains saved.',
                                            );
                                          } else {
                                            toast.error(
                                              title: 'Disconnect failed',
                                              description: pairing.error,
                                            );
                                          }
                                        },
                                ),
                                _ActionRow(
                                  t: t,
                                  icon: Icons.delete_outline_rounded,
                                  iconColor: t.destructive,
                                  iconBg: t.destructive.withValues(alpha: 0.1),
                                  label: 'Forget Device',
                                  desc: 'Remove this saved glove',
                                  labelColor: t.destructive,
                                  divider: false,
                                  onTap: pairing.isDeviceActionActive
                                      ? null
                                      : () async {
                                          final forgotten = await pairing
                                              .forgetDevice();
                                          if (!context.mounted) return;
                                          if (forgotten) {
                                            toast.success(
                                              title: 'Device forgotten',
                                              description:
                                                  'The saved glove was removed.',
                                            );
                                          } else {
                                            toast.error(
                                              title: 'Could not forget device',
                                              description: pairing.error,
                                            );
                                          }
                                        },
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          // ── No device paired ──────────────────────────────
                          _SectionLabel(t: t, label: 'NO DEVICE PAIRED'),
                          const SizedBox(height: 12),
                          _NoPairedCard(t: t, isDark: isDark),
                          const SizedBox(height: 20),

                          AppButton(
                            variant: AppButtonVariant.hero,
                            size: AppButtonSize.lg,
                            width: double.infinity,
                            icon: const Icon(Icons.bluetooth_rounded, size: 18),
                            onPressed: () =>
                                context.push(AppRoutes.profileDevicePairing),
                            child: const Text('Pair Device'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Connected glove card ─────────────────────────────────────────────────────

class _ConnectedCard extends StatelessWidget {
  final AppColorTokens t;
  final bool isDark;
  final GloveDevice device;
  final GloveConnectionStatus connectionStatus;
  const _ConnectedCard({
    required this.t,
    required this.isDark,
    required this.device,
    required this.connectionStatus,
  });

  Color _batteryColor() {
    final batteryLevel = _isConnected ? device.batteryLevel ?? 0 : 0;
    if (batteryLevel > 60) return t.success;
    if (batteryLevel > 30) return t.accent;
    return t.destructive;
  }

  bool get _isConnected => connectionStatus == GloveConnectionStatus.connected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.accent.withValues(alpha: 0.2)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    t.primary.withValues(alpha: isDark ? 0.08 : 0.03),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: -40,
            right: -40,
            child: _Orb(color: t.accent.withValues(alpha: 0.07), size: 120),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Glove name + status
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [t.primary, t.primaryGlow],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: t.primaryGlow.withValues(alpha: 0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.bluetooth_connected_rounded,
                          size: 24,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            device.name,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: t.foreground,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _statusColor(),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _statusLabel(),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _statusColor(),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Stats row
                Row(
                  children: [
                    Expanded(
                      child: _StatChip(
                        t: t,
                        icon: Icons.battery_full_rounded,
                        iconColor: _batteryColor(),
                        label: 'BATTERY',
                        value:
                            '${_isConnected ? device.batteryLevel ?? 0 : 0}%',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatChip(
                        t: t,
                        icon: Icons.network_wifi_rounded,
                        iconColor: t.accent,
                        label: 'SIGNAL',
                        value:
                            '${_isConnected ? device.signalStrength ?? 0 : 0}/5',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatChip(
                        t: t,
                        icon: Icons.memory_rounded,
                        iconColor: t.accent,
                        label: 'FIRMWARE',
                        value: device.firmwareVersion ?? 'Unknown',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor() {
    switch (connectionStatus) {
      case GloveConnectionStatus.connected:
        return t.success;
      case GloveConnectionStatus.connecting:
      case GloveConnectionStatus.reconnecting:
        return t.accent;
      case GloveConnectionStatus.disconnected:
      case GloveConnectionStatus.unavailable:
        return t.mutedForeground;
    }
  }

  String _statusLabel() {
    switch (connectionStatus) {
      case GloveConnectionStatus.connected:
        return 'Connected';
      case GloveConnectionStatus.connecting:
        return 'Connecting';
      case GloveConnectionStatus.reconnecting:
        return 'Reconnecting';
      case GloveConnectionStatus.unavailable:
        return 'Unavailable';
      case GloveConnectionStatus.disconnected:
        return 'Paired - disconnected';
    }
  }
}

// ── No device card ───────────────────────────────────────────────────────────

class _NoPairedCard extends StatelessWidget {
  final AppColorTokens t;
  final bool isDark;
  const _NoPairedCard({required this.t, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity, // <-- This forces the container to fill the width
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 16,
      ), // Gives the inner content some breathing room
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.border.withValues(alpha: 0.4)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: t.muted.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Icon(
                Icons.bluetooth_disabled_rounded,
                size: 28,
                color: t.mutedForeground,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'No glove paired',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: t.foreground,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Pair your IntelliGlove to start using all features.',
            style: TextStyle(
              fontSize: 12,
              color: t.mutedForeground,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Shared sub-widgets ───────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final AppColorTokens t;
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  const _StatChip({
    required this.t,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t.background.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.border.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: iconColor),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 8,
                    color: t.mutedForeground,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: t.foreground,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final AppColorTokens t;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final String desc;
  final bool divider;
  final Color? labelColor;
  final VoidCallback? onTap;
  const _ActionRow({
    required this.t,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.desc,
    required this.divider,
    required this.onTap,
    this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.5 : 1,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          decoration: divider
              ? BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: t.border.withValues(alpha: 0.3)),
                  ),
                )
              : null,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(child: Icon(icon, size: 16, color: iconColor)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: labelColor ?? t.foreground,
                      ),
                    ),
                    Text(
                      desc,
                      style: TextStyle(fontSize: 11, color: t.mutedForeground),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 14,
                color: t.mutedForeground,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final AppColorTokens t;
  final String label;
  const _SectionLabel({required this.t, required this.label});
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 20,
        height: 4,
        decoration: BoxDecoration(
          color: t.accent.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 8),
      Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: t.mutedForeground,
          letterSpacing: 1.8,
        ),
      ),
    ],
  );
}

class _Orb extends StatelessWidget {
  final Color color;
  final double size;
  const _Orb({required this.color, required this.size});
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
  );
}
