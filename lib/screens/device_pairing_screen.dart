// device_pairing_screen.dart
// useToast() → ToastService.show()
// Progress → AppProgressBar from display.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/theme_provider.dart';
import '../theme/app_colors.dart';
import '../components/inputs.dart';
import '../components/display.dart';
import '../app_routes.dart';
import '../components/toast.dart';
import '../components/app_top_bar.dart';
import '../components/app_layout.dart';
import '../components/app_async_state.dart';
import '../services/glove_state_provider.dart';
import '../models/glove_device.dart';
import '../models/load_status.dart';
import '../services/pairing_controller.dart';

class DevicePairingScreen extends StatefulWidget {
  const DevicePairingScreen({super.key});

  @override
  State<DevicePairingScreen> createState() => _DevicePairingScreenState();
}

class _DevicePairingScreenState extends State<DevicePairingScreen> {
  PairingController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller ??= PairingControllerScope.of(context);
  }

  @override
  void dispose() {
    _controller?.cancelPending();
    super.dispose();
  }

  Future<void> _handleConnect(GloveDevice device) async {
    final connected = await PairingControllerScope.of(context).connect(device);
    if (!mounted) return;
    if (connected) {
      toast.success(
        title: 'Connected',
        description: 'Successfully paired with ${device.name}',
      );
    } else {
      toast.error(
        title: 'Connection failed',
        description: PairingControllerScope.of(context).error,
      );
    }
  }

  Future<void> _handleDisconnect() async {
    final disconnected = await PairingControllerScope.of(context).disconnect();
    if (!mounted) return;
    if (disconnected) {
      toast.success(
        title: 'Disconnected',
        description: 'The glove remains paired for a future connection.',
      );
    } else {
      toast.error(description: PairingControllerScope.of(context).error);
    }
  }

  Future<void> _handleForget() async {
    final forgotten = await PairingControllerScope.of(context).forgetDevice();
    if (!mounted) return;
    if (forgotten) {
      toast.success(
        title: 'Device forgotten',
        description: 'Device removed from saved devices.',
      );
    } else {
      toast.error(description: PairingControllerScope.of(context).error);
    }
  }

  IconData _statusIcon(PairingController controller) {
    if (controller.isScanning || controller.isConnecting) {
      return Icons.search_rounded;
    }
    return controller.connectionStatus == GloveConnectionStatus.connected
        ? Icons.bluetooth_connected_rounded
        : Icons.bluetooth_disabled_rounded;
  }

  Color _statusColor(AppColorTokens t, PairingController controller) {
    if (controller.isScanning || controller.isConnecting) return t.accent;
    return controller.connectionStatus == GloveConnectionStatus.connected
        ? t.success
        : t.mutedForeground;
  }

  String _statusLabel(PairingController controller) {
    if (controller.isScanning) return 'Scanning...';
    if (controller.isConnecting) return 'Connecting...';
    return controller.connectionStatus == GloveConnectionStatus.connected
        ? 'Connected'
        : 'Ready to scan';
  }

  @override
  Widget build(BuildContext context) {
    final t = ThemeProviderScope.of(context).tokens;
    final isDark = ThemeProviderScope.of(context).isDark;
    final globalGlove = GloveStateScope.of(context);
    final controller = PairingControllerScope.of(context);
    final availableDevices = controller.discoveredDevices;

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
                // Top bar
                Container(
                  constraints: const BoxConstraints(minHeight: 64),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
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
                      AppBackButton(fallbackRoute: AppRoutes.profileDevices),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Device Pairing',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: t.foreground,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      AppLayout.horizontalPadding(context),
                      24,
                      AppLayout.horizontalPadding(context),
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
                          'Device',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: t.foreground,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Pair and manage your IntelliGlove',
                          style: TextStyle(
                            fontSize: 13,
                            color: t.mutedForeground,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // ── Currently connected glove ───────────────────────
                        if (globalGlove.hasPairedDevice) ...[
                          _SectionLabel(t: t, label: 'PAIRED DEVICE'),
                          const SizedBox(height: 12),
                          _GlobalConnectedCard(
                            t: t,
                            isDark: isDark,
                            device: globalGlove.pairedDevice!,
                            isConnected: globalGlove.isConnected,
                          ),
                          const SizedBox(height: 20),
                        ],

                        // Status card (for scanning new devices)
                        _SectionLabel(
                          t: t,
                          label: globalGlove.isConnected
                              ? 'PAIR ANOTHER DEVICE'
                              : 'BLUETOOTH SCAN',
                        ),
                        const SizedBox(height: 12),
                        _StatusCard(
                          t: t,
                          isDark: isDark,
                          connectingDevice: availableDevices
                              .where(
                                (device) =>
                                    device.id == controller.connectingDeviceId,
                              )
                              .firstOrNull,
                          scanning: controller.isScanning,
                          connected: globalGlove.isConnected,
                          statusIcon: _statusIcon(controller),
                          statusColor: _statusColor(t, controller),
                          statusLabel: _statusLabel(controller),
                          onScan: controller.scan,
                        ),
                        const SizedBox(height: 20),

                        if (controller.scanStatus == LoadStatus.empty) ...[
                          AppEmptyState(
                            card: true,
                            icon: Icons.bluetooth_searching_rounded,
                            message: 'No nearby IntelliGloves were found.',
                            actionLabel: 'Scan again',
                            onAction: controller.scan,
                          ),
                          const SizedBox(height: 20),
                        ],
                        if (controller.scanStatus == LoadStatus.error) ...[
                          AppErrorState(
                            card: true,
                            message:
                                controller.error ??
                                'The scan could not be completed.',
                            actionLabel: 'Retry',
                            onAction: controller.scan,
                          ),
                          const SizedBox(height: 20),
                        ],

                        // Found devices list
                        if (availableDevices.isNotEmpty) ...[
                          _SectionLabel(t: t, label: 'AVAILABLE DEVICES'),
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
                              children: availableDevices.asMap().entries.map((
                                e,
                              ) {
                                final i = e.key;
                                final device = e.value;
                                return GestureDetector(
                                  onTap: () => _handleConnect(device),
                                  child: Container(
                                    decoration: i < availableDevices.length - 1
                                        ? BoxDecoration(
                                            border: Border(
                                              bottom: BorderSide(
                                                color: t.border.withValues(
                                                  alpha: 0.3,
                                                ),
                                              ),
                                            ),
                                          )
                                        : null,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            gradient: LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [
                                                t.primary,
                                                t.primaryGlow,
                                              ],
                                            ),
                                          ),
                                          child: Center(
                                            child: Icon(
                                              Icons.bluetooth_rounded,
                                              size: 18,
                                              color: AppColors.white,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                device.name,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: t.foreground,
                                                ),
                                              ),
                                              Text(
                                                device.id,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: t.mutedForeground,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        AppButton(
                                          variant: AppButtonVariant.accent,
                                          size: AppButtonSize.sm,
                                          onPressed: () =>
                                              _handleConnect(device),
                                          child:
                                              controller.connectingDeviceId ==
                                                  device.id
                                              ? const SizedBox(
                                                  width: 14,
                                                  height: 14,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                )
                                              : const Text('Pair'),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],

                        // Connected device details
                        if (globalGlove.pairedDevice != null) ...[
                          _SectionLabel(t: t, label: 'DEVICE INFO'),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _InfoCard(
                                  t: t,
                                  icon: Icons.battery_full_rounded,
                                  label: 'BATTERY',
                                  value: globalGlove.isConnected
                                      ? '${globalGlove.pairedDevice!.batteryLevel ?? 0}%'
                                      : '--',
                                  progress:
                                      globalGlove.isConnected &&
                                          globalGlove
                                                  .pairedDevice!
                                                  .batteryLevel !=
                                              null
                                      ? globalGlove
                                                .pairedDevice!
                                                .batteryLevel! /
                                            100
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _InfoCard(
                                  t: t,
                                  icon: Icons.memory_rounded,
                                  label: 'FIRMWARE',
                                  value:
                                      globalGlove
                                          .pairedDevice!
                                          .firmwareVersion ??
                                      'Unknown',
                                  statusText: 'Up to date',
                                  statusColor: t.success,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

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
                                  icon: Icons.wifi_off_rounded,
                                  iconColor: t.mutedForeground,
                                  iconBg: t.muted.withValues(alpha: 0.4),
                                  label: 'Disconnect',
                                  desc: 'Disconnect from device',
                                  divider: true,
                                  onTap: _handleDisconnect,
                                ),
                                _ActionRow(
                                  t: t,
                                  icon: Icons.delete_outline_rounded,
                                  iconColor: t.destructive,
                                  iconBg: t.destructive.withValues(alpha: 0.1),
                                  label: 'Forget Device',
                                  desc: 'Remove from saved devices',
                                  labelColor: t.destructive,
                                  divider: false,
                                  onTap: _handleForget,
                                ),
                              ],
                            ),
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

class _StatusCard extends StatelessWidget {
  final AppColorTokens t;
  final bool isDark;
  final GloveDevice? connectingDevice;
  final bool scanning;
  final bool connected;
  final IconData statusIcon;
  final Color statusColor;
  final String statusLabel;
  final VoidCallback onScan;
  const _StatusCard({
    required this.t,
    required this.isDark,
    required this.connectingDevice,
    required this.scanning,
    required this.connected,
    required this.statusIcon,
    required this.statusColor,
    required this.statusLabel,
    required this.onScan,
  });

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
                    t.primary.withValues(alpha: isDark ? 0.07 : 0.03),
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
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Icon(statusIcon, size: 24, color: statusColor),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            connectingDevice?.name ??
                                (connected
                                    ? 'Glove connected'
                                    : 'Find a glove'),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: t.foreground,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: statusColor,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  statusLabel,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: statusColor,
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
                const SizedBox(height: 16),
                if (!scanning)
                  AppButton(
                    variant: AppButtonVariant.hero,
                    width: double.infinity,
                    icon: const Icon(Icons.bluetooth_rounded, size: 18),
                    onPressed: onScan,
                    child: const Text('Scan for Devices'),
                  ),
                if (scanning)
                  Row(
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: t.accent,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Scanning nearby devices...',
                        style: TextStyle(
                          fontSize: 12,
                          color: t.mutedForeground,
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
}

class _InfoCard extends StatelessWidget {
  final AppColorTokens t;
  final IconData icon;
  final String label;
  final String value;
  final double? progress;
  final String? statusText;
  final Color? statusColor;
  const _InfoCard({
    required this.t,
    required this.icon,
    required this.label,
    required this.value,
    this.progress,
    this.statusText,
    this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.border.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: t.accent),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  color: t.mutedForeground,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: t.foreground,
            ),
          ),
          if (progress != null) ...[
            const SizedBox(height: 6),
            AppProgress(value: progress!),
          ],
          if (statusText != null) ...[
            const SizedBox(height: 4),
            Text(
              statusText!,
              style: TextStyle(
                fontSize: 10,
                color: statusColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
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
  final VoidCallback onTap;
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
    return GestureDetector(
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
    );
  }
}

class _GlobalConnectedCard extends StatelessWidget {
  final AppColorTokens t;
  final bool isDark;
  final GloveDevice device;
  final bool isConnected;
  const _GlobalConnectedCard({
    required this.t,
    required this.isDark,
    required this.device,
    required this.isConnected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.success.withValues(alpha: 0.35)),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            t.success.withValues(alpha: isDark ? 0.07 : 0.04),
            Colors.transparent,
          ],
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: t.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Icon(
                Icons.bluetooth_connected_rounded,
                size: 18,
                color: t.success,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  device.name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: t.foreground,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _Chip(
                      t: t,
                      icon: Icons.battery_full_rounded,
                      iconColor: t.success,
                      label: '${isConnected ? device.batteryLevel ?? 0 : 0}%',
                    ),
                    _Chip(
                      t: t,
                      icon: Icons.memory_rounded,
                      iconColor: t.accent,
                      label: device.firmwareVersion ?? 'Unknown',
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: t.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: t.success,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  isConnected ? 'Active' : 'Paired',
                  style: TextStyle(
                    fontSize: 10,
                    color: isConnected ? t.success : t.mutedForeground,
                    fontWeight: FontWeight.w700,
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

class _Chip extends StatelessWidget {
  final AppColorTokens t;
  final IconData icon;
  final Color iconColor;
  final String label;
  const _Chip({
    required this.t,
    required this.icon,
    required this.iconColor,
    required this.label,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    decoration: BoxDecoration(
      color: t.muted.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 10, color: iconColor),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: t.mutedForeground,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
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
      Expanded(
        child: Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: t.mutedForeground,
            letterSpacing: 1.8,
          ),
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
