import 'package:flutter_test/flutter_test.dart';
import 'package:intelliglove/models/load_status.dart';
import 'package:intelliglove/models/smart_device.dart';
import 'package:intelliglove/repositories/analytics_repository.dart';
import 'package:intelliglove/repositories/smart_home_repository.dart';
import 'package:intelliglove/services/analytics_controller.dart';
import 'package:intelliglove/services/smart_home_provider.dart';

void main() {
  test('analytics loads and retries each range independently', () async {
    final repository = _AnalyticsRepository();
    final controller = AnalyticsController(repository: repository);

    await controller.load(AnalyticsRange.day);
    expect(controller.statusFor(AnalyticsRange.day), LoadStatus.error);
    expect(controller.statusFor(AnalyticsRange.week), LoadStatus.initial);

    repository.failDay = false;
    await controller.retry(AnalyticsRange.day);
    expect(controller.statusFor(AnalyticsRange.day), LoadStatus.success);
    expect(controller.dataFor(AnalyticsRange.day)?.labels, ['Day']);
    controller.dispose();
  });

  test(
    'smart-home persistence failure rolls back optimistic mutation',
    () async {
      final repository = _FailingSmartHomeRepository();
      final provider = SmartHomeProvider(repository: repository);
      await provider.load();

      await provider.toggleDevice(1);
      expect(provider.devices.single.isOn, isFalse);
      expect(provider.errorMessage, contains('could not be saved'));
      provider.dispose();
    },
  );
}

const _analyticsData = AnalyticsData(
  gestures: [1],
  labels: ['Day'],
  accuracy: [95],
  sessionMinutes: [10],
  topGestures: [],
);

class _AnalyticsRepository implements AnalyticsRepository {
  bool failDay = true;

  @override
  Future<AnalyticsData> loadDay() async {
    if (failDay) throw StateError('offline');
    return _analyticsData;
  }

  @override
  Future<AnalyticsData> loadMonth() async => _analyticsData;

  @override
  Future<AnalyticsData> loadWeek() async => _analyticsData;
}

class _FailingSmartHomeRepository implements SmartHomeRepository {
  @override
  Future<List<SmartDevice>> loadDevices() async => const [
    SmartDevice(
      id: 1,
      name: 'Lamp',
      iconKey: 'light',
      gesture: 'Wave',
      isOn: false,
    ),
  ];

  @override
  Future<void> saveDevices(List<SmartDevice> devices) async {
    throw StateError('disk full');
  }
}
