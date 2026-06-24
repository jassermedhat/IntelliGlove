import 'package:flutter_test/flutter_test.dart';
import 'package:intelliglove/models/app_alert.dart';
import 'package:intelliglove/models/load_status.dart';
import 'package:intelliglove/repositories/alerts_repository.dart';
import 'package:intelliglove/services/alerts_controller.dart';

void main() {
  test('loads, marks read, and exposes latest alerts', () async {
    final controller = AlertsController(
      repository: MockAlertsRepository(
        alerts: [
          AppAlert(
            id: '1',
            title: 'First',
            message: 'First alert',
            type: AppAlertType.info,
            createdAt: DateTime(2026),
          ),
          AppAlert(
            id: '2',
            title: 'Second',
            message: 'Second alert',
            type: AppAlertType.success,
            createdAt: DateTime(2026),
          ),
          AppAlert(
            id: '3',
            title: 'Third',
            message: 'Third alert',
            type: AppAlertType.warning,
            createdAt: DateTime(2026),
          ),
        ],
      ),
    );

    await controller.load();
    expect(controller.status, LoadStatus.success);
    expect(controller.latestAlerts, hasLength(2));
    expect(await controller.markRead('1'), isTrue);
    expect(controller.alerts.first.isRead, isTrue);
  });

  test('supports empty, failure, and retry', () async {
    final empty = AlertsController(
      repository: MockAlertsRepository(alerts: const []),
    );
    await empty.load();
    expect(empty.status, LoadStatus.empty);

    final failing = AlertsController(
      repository: MockAlertsRepository(shouldFail: true),
    );
    await failing.load();
    expect(failing.status, LoadStatus.error);
    await failing.refresh();
    expect(failing.status, LoadStatus.error);
  });
}
