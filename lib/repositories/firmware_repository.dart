class FirmwareInfo {
  final String currentVersion;
  final String? availableVersion;

  const FirmwareInfo({required this.currentVersion, this.availableVersion});

  bool get hasUpdate =>
      availableVersion != null && availableVersion != currentVersion;
}

abstract class FirmwareRepository {
  Future<FirmwareInfo> checkForUpdate();
  Stream<double> installUpdate();
}

class MockFirmwareRepository implements FirmwareRepository {
  MockFirmwareRepository({
    this.currentVersion = '2.3.1',
    this.availableVersion = '2.5.0',
    this.shouldFailCheck = false,
    this.shouldFailInstall = false,
    this.stepDelay = const Duration(milliseconds: 80),
  });

  final String currentVersion;
  final String? availableVersion;
  final bool shouldFailCheck;
  final bool shouldFailInstall;
  final Duration stepDelay;

  @override
  Future<FirmwareInfo> checkForUpdate() async {
    await Future<void>.delayed(stepDelay);
    if (shouldFailCheck) throw const FirmwareRepositoryException();
    return FirmwareInfo(
      currentVersion: currentVersion,
      availableVersion: availableVersion,
    );
  }

  @override
  Stream<double> installUpdate() async* {
    for (var step = 1; step <= 10; step++) {
      await Future<void>.delayed(stepDelay);
      if (shouldFailInstall && step == 5) {
        throw const FirmwareRepositoryException();
      }
      yield step / 10;
    }
  }
}

class FirmwareRepositoryException implements Exception {
  const FirmwareRepositoryException();
}
