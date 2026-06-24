import 'package:flutter/material.dart';

import '../app_routes.dart';
import '../components/app_async_state.dart';
import '../components/app_layout.dart';
import '../components/app_top_bar.dart';
import '../components/display.dart';
import '../components/inputs.dart';
import '../components/toast.dart';
import '../models/app_alert.dart' as model;
import '../models/load_status.dart';
import '../services/alerts_controller.dart';
import '../services/firmware_controller.dart';
import '../theme/app_colors.dart';
import '../theme/theme_provider.dart';

class DeviceUpdatesScreen extends StatefulWidget {
  const DeviceUpdatesScreen({super.key});

  @override
  State<DeviceUpdatesScreen> createState() => _DeviceUpdatesScreenState();
}

class _DeviceUpdatesScreenState extends State<DeviceUpdatesScreen> {
  @override
  void initState() {
    super.initState();
    // Refetch on open. Firmware + alerts come from app-lifetime singletons loaded
    // once at login, so without this the screen shows stale state (e.g. a new
    // firmware release or alert) until the app restarts.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      AlertsScope.of(context).refresh();
      final firmware = FirmwareScope.of(context);
      if (!firmware.isBusy) firmware.check();
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = ThemeProviderScope.of(context).tokens;
    final firmware = FirmwareScope.of(context);
    final alerts = AlertsScope.of(context);

    return Scaffold(
      backgroundColor: t.background,
      body: SafeArea(
        child: Column(
          children: [
            AppTopBar(
              title: 'Firmware Updates',
              showBackButton: true,
              fallbackRoute: AppRoutes.profileDevices,
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
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'Firmware',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: t.foreground,
                          ),
                        ),
                        const FirmwareSimulationBadge(),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'This build demonstrates the update flow. It does not install real device firmware.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: t.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _FirmwareCard(t: t, controller: firmware),
                    const SizedBox(height: 28),
                    Text(
                      'ALERTS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: t.mutedForeground,
                        letterSpacing: 1.8,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _AlertsList(t: t, controller: alerts),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FirmwareSimulationBadge extends StatelessWidget {
  const FirmwareSimulationBadge({super.key});

  @override
  Widget build(BuildContext context) =>
      const AppBadge(label: 'Simulation', variant: AppBadgeVariant.primary);
}

class _FirmwareCard extends StatelessWidget {
  const _FirmwareCard({required this.t, required this.controller});

  final AppColorTokens t;
  final FirmwareController controller;

  @override
  Widget build(BuildContext context) {
    final status = controller.status;
    final busy = controller.isBusy;
    final progress = controller.progress;
    final version = controller.availableVersion ?? controller.currentVersion;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.accent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: t.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  status == FirmwareStatus.success
                      ? Icons.check_circle_rounded
                      : Icons.system_update_rounded,
                  color: status == FirmwareStatus.success
                      ? t.success
                      : t.accent,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _title(status, version),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: t.foreground,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _message(status, controller),
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.45,
                        color: status == FirmwareStatus.failure
                            ? t.destructive
                            : t.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (busy) ...[
            const SizedBox(height: 18),
            AppProgress(value: progress),
            const SizedBox(height: 6),
            Text(
              '${(progress * 100).round()}%',
              style: TextStyle(color: t.accent, fontWeight: FontWeight.w700),
            ),
          ],
          const SizedBox(height: 18),
          AppButton(
            width: double.infinity,
            variant: AppButtonVariant.hero,
            size: AppButtonSize.lg,
            onPressed: busy
                ? null
                : () async {
                    if (status == FirmwareStatus.updateAvailable ||
                        (status == FirmwareStatus.failure &&
                            controller.availableVersion != null)) {
                      await controller.install();
                      if (context.mounted &&
                          controller.status == FirmwareStatus.success) {
                        toast.success(
                          title: 'Simulation complete',
                          description:
                              'No real firmware was installed on the glove.',
                        );
                      }
                    } else {
                      await controller.check();
                    }
                  },
            child: Text(_buttonLabel(status)),
          ),
        ],
      ),
    );
  }

  static String _title(FirmwareStatus status, String version) =>
      switch (status) {
        FirmwareStatus.initial => 'Ready to check',
        FirmwareStatus.checking => 'Checking for updates',
        FirmwareStatus.noUpdate => 'Firmware is up to date',
        FirmwareStatus.updateAvailable => 'Firmware $version available',
        FirmwareStatus.downloading => 'Downloading simulation',
        FirmwareStatus.installing => 'Installing simulation',
        FirmwareStatus.success => 'Simulation complete',
        FirmwareStatus.failure => 'Update simulation failed',
      };

  static String _message(
    FirmwareStatus status,
    FirmwareController controller,
  ) => switch (status) {
    FirmwareStatus.noUpdate => 'Current version: ${controller.currentVersion}.',
    FirmwareStatus.updateAvailable =>
      'Current ${controller.currentVersion}; available ${controller.availableVersion}.',
    FirmwareStatus.failure =>
      controller.error ?? 'Please retry the simulated operation.',
    FirmwareStatus.success =>
      'Version ${controller.currentVersion} is now shown as installed for this demo.',
    _ => 'Keep the app open while the simulated operation runs.',
  };

  static String _buttonLabel(FirmwareStatus status) => switch (status) {
    FirmwareStatus.updateAvailable => 'Run Update Simulation',
    FirmwareStatus.failure => 'Retry',
    FirmwareStatus.noUpdate || FirmwareStatus.success => 'Check Again',
    _ => 'Check for Updates',
  };
}

class _AlertsList extends StatelessWidget {
  const _AlertsList({required this.t, required this.controller});

  final AppColorTokens t;
  final AlertsController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.status == LoadStatus.loading) {
      return const AppLoadingState(message: 'Loading alerts...');
    }
    if (controller.status == LoadStatus.error) {
      return AppErrorState(
        title: 'Alerts unavailable',
        message: controller.error ?? 'Could not load alerts.',
        actionLabel: 'Retry',
        onAction: controller.refresh,
        card: true,
      );
    }
    if (controller.alerts.isEmpty) {
      return const AppEmptyState(
        title: 'No alerts',
        message: 'You are all caught up.',
        card: true,
      );
    }
    return Column(
      children: controller.alerts
          .map(
            (alert) => _AlertTile(t: t, alert: alert, controller: controller),
          )
          .toList(),
    );
  }
}

class _AlertTile extends StatelessWidget {
  const _AlertTile({
    required this.t,
    required this.alert,
    required this.controller,
  });

  final AppColorTokens t;
  final model.AppAlert alert;
  final AlertsController controller;

  @override
  Widget build(BuildContext context) {
    final color = switch (alert.type) {
      model.AppAlertType.info => t.accent,
      model.AppAlertType.success => t.success,
      model.AppAlertType.warning => Colors.orange,
      model.AppAlertType.error => t.destructive,
    };
    return Card(
      color: t.card,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: () => controller.markRead(alert.id),
        leading: Icon(Icons.notifications_outlined, color: color),
        title: Text(alert.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(alert.message),
        trailing: alert.isRead
            ? null
            : Icon(Icons.circle, size: 8, color: t.accent),
      ),
    );
  }
}
