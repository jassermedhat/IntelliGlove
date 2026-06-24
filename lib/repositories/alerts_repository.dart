import '../models/app_alert.dart';

abstract class AlertsRepository {
  Future<List<AppAlert>> loadAlerts();
  Future<void> markRead(String id);
}

class MockAlertsRepository implements AlertsRepository {
  MockAlertsRepository({
    List<AppAlert>? alerts,
    this.shouldFail = false,
    this.delay = Duration.zero,
  }) : _alerts = List.of(alerts ?? _defaults());

  final bool shouldFail;
  final Duration delay;
  final List<AppAlert> _alerts;

  @override
  Future<List<AppAlert>> loadAlerts() async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (shouldFail) throw const AlertsRepositoryException();
    return List.unmodifiable(_alerts);
  }

  @override
  Future<void> markRead(String id) async {
    if (shouldFail) throw const AlertsRepositoryException();
    final index = _alerts.indexWhere((alert) => alert.id == id);
    if (index >= 0) _alerts[index] = _alerts[index].copyWith(isRead: true);
  }

  static List<AppAlert> _defaults() {
    final now = DateTime.now();
    return [
      AppAlert(
        id: 'firmware-update',
        title: 'Firmware update available',
        message: 'Firmware update available (v2.5.0)',
        type: AppAlertType.info,
        createdAt: now,
      ),
      AppAlert(
        id: 'sensors-calibrated',
        title: 'Calibration complete',
        message: 'All sensors calibrated successfully',
        type: AppAlertType.success,
        createdAt: now.subtract(const Duration(hours: 1)),
        isRead: true,
      ),
    ];
  }
}

class AlertsRepositoryException implements Exception {
  const AlertsRepositoryException();
}
