import 'package:flutter_test/flutter_test.dart';
import 'package:intelliglove/repositories/firmware_repository.dart';
import 'package:intelliglove/services/firmware_controller.dart';

void main() {
  test('reports no update', () async {
    final controller = FirmwareController(
      repository: MockFirmwareRepository(
        currentVersion: '2.5.0',
        availableVersion: null,
        stepDelay: Duration.zero,
      ),
    );
    await controller.check();
    expect(controller.status, FirmwareStatus.noUpdate);
  });

  test('reports availability, progress, and success', () async {
    final controller = FirmwareController(
      repository: MockFirmwareRepository(stepDelay: Duration.zero),
    );
    final seen = <double>[];
    controller.addListener(() => seen.add(controller.progress));

    await controller.check();
    expect(controller.status, FirmwareStatus.updateAvailable);
    await controller.install();

    expect(seen.any((value) => value > 0 && value < 1), isTrue);
    expect(controller.progress, 1);
    expect(controller.status, FirmwareStatus.success);
  });

  test('failure can be retried', () async {
    final repository = _RetryFirmwareRepository();
    final controller = FirmwareController(repository: repository);
    await controller.check();
    await controller.install();
    expect(controller.status, FirmwareStatus.failure);

    repository.fail = false;
    await controller.retry();
    expect(controller.status, FirmwareStatus.success);
  });
}

class _RetryFirmwareRepository implements FirmwareRepository {
  bool fail = true;

  @override
  Future<FirmwareInfo> checkForUpdate() async =>
      const FirmwareInfo(currentVersion: '1.0', availableVersion: '2.0');

  @override
  Stream<double> installUpdate() async* {
    yield 0.4;
    if (fail) throw const FirmwareRepositoryException();
    yield 1;
  }
}
