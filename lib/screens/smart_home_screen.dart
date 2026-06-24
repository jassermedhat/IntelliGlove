import 'package:flutter/material.dart';
import '../components/app_layout.dart';
import 'package:go_router/go_router.dart';
import '../components/smart_device_icon_resolver.dart';
import '../components/toast.dart';
import '../theme/theme_provider.dart';
import '../theme/app_colors.dart';
import '../components/inputs.dart';
import '../services/glove_state_provider.dart';
import '../app_routes.dart';
import '../models/smart_device.dart';
import '../services/smart_home_provider.dart';
import '../models/load_status.dart';
import '../components/app_async_state.dart';

class SmartHomeScreen extends StatefulWidget {
  const SmartHomeScreen({super.key});
  @override
  State<SmartHomeScreen> createState() => _SmartHomeScreenState();
}

class _SmartHomeScreenState extends State<SmartHomeScreen> {
  @override
  void initState() {
    super.initState();
    // Refetch on open. SmartHomeProvider is an app-lifetime singleton loaded once
    // at login, so without this, devices added/seeded since (e.g. from the admin
    // panel) would not appear until the app restarts.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) SmartHomeScope.of(context).load();
    });
  }

  void _showNoGloveDialog(BuildContext context) {
    final t = ThemeProviderScope.of(context).tokens;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        backgroundColor: t.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              Icons.bluetooth_disabled_rounded,
              size: 20,
              color: t.destructive,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'No Glove Connected',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: t.foreground,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'No glove connected. Please pair your IntelliGlove device first.',
          style: TextStyle(fontSize: 13, color: t.mutedForeground, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: TextStyle(color: t.mutedForeground)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.push(AppRoutes.profileDevicePairing);
            },
            child: Text(
              'Pair Device',
              style: TextStyle(color: t.accent, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddDeviceDialog(
    BuildContext context,
    AppColorTokens t,
    SmartHomeProvider provider,
  ) {
    final nameCtrl = TextEditingController();
    final gestureCtrl = TextEditingController(text: 'Custom Gesture');
    int selectedTypeIndex = 0;

    const typeOptions = [
      (label: 'Light', icon: Icons.lightbulb_outline_rounded),
      (label: 'TV', icon: Icons.tv_rounded),
      (label: 'Lock', icon: Icons.lock_outline_rounded),
      (label: 'Thermostat', icon: Icons.thermostat_rounded),
      (label: 'Fan', icon: Icons.air_rounded),
      (label: 'Other', icon: Icons.devices_other_rounded),
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          scrollable: true,
          backgroundColor: t.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Add Device',
            style: TextStyle(fontWeight: FontWeight.w700, color: t.foreground),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Device Name',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: t.mutedForeground,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: nameCtrl,
                  style: TextStyle(fontSize: 13, color: t.foreground),
                  decoration: InputDecoration(
                    hintText: 'e.g. Bedroom Light',
                    hintStyle: TextStyle(color: t.mutedForeground),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: t.border.withValues(alpha: 0.4),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: t.border.withValues(alpha: 0.4),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: t.accent, width: 1.5),
                    ),
                    fillColor: t.background,
                    filled: true,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Device Type',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: t.mutedForeground,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: typeOptions.asMap().entries.map((e) {
                    final selected = e.key == selectedTypeIndex;
                    return GestureDetector(
                      onTap: () =>
                          setModalState(() => selectedTypeIndex = e.key),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? t.accent.withValues(alpha: 0.15)
                              : t.muted.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: selected ? t.accent : Colors.transparent,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              e.value.icon,
                              size: 14,
                              color: selected ? t.accent : t.mutedForeground,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              e.value.label,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: selected ? t.accent : t.mutedForeground,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                Text(
                  'Gesture Mapping',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: t.mutedForeground,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: gestureCtrl,
                  style: TextStyle(fontSize: 13, color: t.foreground),
                  decoration: InputDecoration(
                    hintText: 'e.g. Peace Sign',
                    hintStyle: TextStyle(color: t.mutedForeground),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: t.border.withValues(alpha: 0.4),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: t.border.withValues(alpha: 0.4),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: t.accent, width: 1.5),
                    ),
                    fillColor: t.background,
                    filled: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Cancel', style: TextStyle(color: t.mutedForeground)),
            ),
            TextButton(
              onPressed: provider.isSaving
                  ? null
                  : () async {
                      final name = nameCtrl.text.trim();
                      if (name.isEmpty) return;
                      final type = typeOptions[selectedTypeIndex];
                      final gesture = gestureCtrl.text.trim().isNotEmpty
                          ? gestureCtrl.text.trim()
                          : 'Custom Gesture';
                      final devices = provider.devices;
                      final newId =
                          (devices.isEmpty
                              ? 0
                              : devices
                                    .map((d) => d.id)
                                    .reduce((a, b) => a > b ? a : b)) +
                          1;
                      final saved = await provider.addDevice(
                        SmartDevice(
                          id: newId,
                          name: name,
                          iconKey: type.label.toLowerCase(),
                          gesture: gesture,
                          isOn: false,
                        ),
                      );
                      if (!ctx.mounted) return;
                      if (saved) {
                        Navigator.of(ctx).pop();
                        toast.success(
                          title: 'Device added',
                          description: '$name is ready for gesture control.',
                        );
                      } else {
                        toast.error(
                          title: 'Device not added',
                          description: provider.errorMessage,
                        );
                      }
                    },
              child: Text(
                'Add',
                style: TextStyle(color: t.accent, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = ThemeProviderScope.of(context).tokens;
    final isDark = ThemeProviderScope.of(context).isDark;
    final provider = SmartHomeScope.of(context);
    final devices = provider.devices;
    final activeCount = devices.where((d) => d.isOn).length;

    return Scaffold(
      backgroundColor: t.background,
      body: Stack(
        children: [
          Positioned(
            top: -120,
            right: -120,
            child: _Orb(color: t.accent.withValues(alpha: 0.05), size: 320),
          ),
          Positioned(
            bottom: MediaQuery.of(context).size.height * 0.33,
            left: -100,
            child: _Orb(color: t.primary.withValues(alpha: 0.05), size: 240),
          ),
          SafeArea(
            child: Column(
              children: [
                // Top bar
                Container(
                  constraints: BoxConstraints(
                    minHeight: AppLayout.topBarHeight(context),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
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
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0x1A22C55E),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.home_rounded,
                            size: 18,
                            color: Color(0xFF22C55E),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Smart Home',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: t.foreground,
                            ),
                          ),
                          Text(
                            'IoT Control',
                            style: TextStyle(
                              fontSize: 10,
                              color: t.mutedForeground,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      // Add device button — tappable
                      GestureDetector(
                        onTap: () => _showAddDeviceDialog(context, t, provider),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [t.primary, t.primaryGlow],
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.add_rounded,
                              size: 16,
                              color: AppColors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

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
                              'CONTROL CENTER',
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
                        RichText(
                          text: TextSpan(
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: t.foreground,
                              letterSpacing: -0.3,
                              height: 1.1,
                            ),
                            children: [
                              const TextSpan(text: 'Your\n'),
                              TextSpan(
                                text: 'Connected Home',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w600,
                                  color: t.mutedForeground,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Control your devices using hand gestures through IntelliGlove.',
                          style: TextStyle(
                            fontSize: 12,
                            color: t.mutedForeground,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Stats 2-col
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: t.card,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: t.accent.withValues(alpha: 0.2),
                                  ),
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
                                              t.primary.withValues(
                                                alpha: isDark ? 0.08 : 0.03,
                                              ),
                                              Colors.transparent,
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'ACTIVE',
                                          style: TextStyle(
                                            fontSize: 9,
                                            color: t.mutedForeground,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 1.0,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '$activeCount',
                                          style: TextStyle(
                                            fontSize: 36,
                                            fontWeight: FontWeight.w900,
                                            color: t.accent,
                                            letterSpacing: -1.0,
                                          ),
                                        ),
                                        Text(
                                          'devices online',
                                          style: TextStyle(
                                            fontSize: 9,
                                            color: t.mutedForeground,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: t.card,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: t.border.withValues(alpha: 0.4),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'TOTAL',
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: t.mutedForeground,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${devices.length}',
                                      style: TextStyle(
                                        fontSize: 36,
                                        fontWeight: FontWeight.w900,
                                        color: t.foreground,
                                        letterSpacing: -1.0,
                                      ),
                                    ),
                                    Text(
                                      'registered',
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: t.mutedForeground,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Your Devices label
                        Row(
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
                              'YOUR DEVICES',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: t.mutedForeground,
                                letterSpacing: 1.8,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Device list
                        if (provider.status == LoadStatus.loading)
                          const AppLoadingState(
                            message: 'Loading smart devices...',
                          )
                        else if (provider.status == LoadStatus.error)
                          AppErrorState(
                            message:
                                provider.errorMessage ??
                                'Smart-home devices could not be loaded.',
                            onAction: provider.load,
                          )
                        else if (devices.isEmpty)
                          const AppEmptyState(
                            icon: Icons.devices_other_rounded,
                            message: 'No smart devices added yet.',
                          )
                        else
                          ...devices.map(
                            (device) => _DeviceCard(
                              t: t,
                              device: device,
                              onToggle: provider.isSaving
                                  ? null
                                  : () async {
                                      if (!GloveStateScope.of(
                                        context,
                                      ).isConnected) {
                                        _showNoGloveDialog(context);
                                        return;
                                      }
                                      final saved = await provider.toggleDevice(
                                        device.id,
                                      );
                                      if (!context.mounted || saved) return;
                                      toast.error(
                                        title: 'Change not saved',
                                        description: provider.errorMessage,
                                      );
                                    },
                            ),
                          ),
                        const SizedBox(height: 20),

                        // Pro tip
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: t.card,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: t.border.withValues(alpha: 0.4),
                            ),
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                t.accent.withValues(alpha: isDark ? 0.1 : 0.05),
                                t.primary.withValues(
                                  alpha: isDark ? 0.1 : 0.05,
                                ),
                              ],
                            ),
                          ),
                          child: RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              style: TextStyle(
                                fontSize: 12,
                                color: t.mutedForeground,
                                height: 1.5,
                              ),
                              children: [
                                const TextSpan(text: '💡 '),
                                TextSpan(
                                  text: 'Pro Tip: ',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: t.foreground,
                                  ),
                                ),
                                const TextSpan(
                                  text:
                                      'Long-press any device to customize its gesture mapping.',
                                ),
                              ],
                            ),
                          ),
                        ),
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

class _DeviceCard extends StatelessWidget {
  final AppColorTokens t;
  final SmartDevice device;
  final VoidCallback? onToggle;
  const _DeviceCard({
    required this.t,
    required this.device,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.border.withValues(alpha: 0.4)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          // Active indicator bar
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 4,
            color: device.isOn ? t.accent : t.border,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(13),
                      gradient: device.isOn
                          ? LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [t.primary, t.primaryGlow],
                            )
                          : null,
                      color: device.isOn ? null : t.muted,
                    ),
                    child: Center(
                      child: Icon(
                        SmartDeviceIconResolver.fromKey(device.iconKey),
                        size: 20,
                        color: device.isOn
                            ? AppColors.white
                            : t.mutedForeground,
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
                            fontWeight: FontWeight.w600,
                            color: t.foreground,
                          ),
                        ),
                        RichText(
                          text: TextSpan(
                            style: TextStyle(
                              fontSize: 10,
                              color: t.mutedForeground,
                            ),
                            children: [
                              const TextSpan(text: 'Gesture: '),
                              TextSpan(
                                text: device.gesture,
                                style: TextStyle(
                                  color: t.accent,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  AppSwitch(
                    value: device.isOn,
                    onChanged: onToggle == null ? null : (_) => onToggle!(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
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
