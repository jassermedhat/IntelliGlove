import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:intelliglove/models/glove_device.dart';
import 'package:intelliglove/models/load_status.dart';
import 'package:intelliglove/repositories/glove_repository.dart';
import 'package:intelliglove/services/glove_state_provider.dart';
import 'package:intelliglove/services/pairing_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('duplicate names remain distinct and paired ID is excluded', () async {
    final repository = _GloveRepository();
    final gloveState = GloveStateProvider();
    final controller = PairingController(
      repository: repository,
      gloveState: gloveState,
    );

    await controller.scan();
    expect(controller.discoveredDevices.map((device) => device.id), [
      'one',
      'two',
    ]);

    expect(await controller.connect(repository.devices.first), isTrue);
    expect(gloveState.pairedDevice?.id, 'one');
    expect(gloveState.connectionStatus, GloveConnectionStatus.connected);
    expect(controller.discoveredDevices.map((device) => device.id), ['two']);

    expect(await controller.disconnect(), isTrue);
    expect(repository.disconnectCalls, 1);
    expect(gloveState.pairedDevice?.id, 'one');
    expect(gloveState.connectionStatus, GloveConnectionStatus.disconnected);

    expect(await controller.forgetDevice(), isTrue);
    expect(gloveState.pairedDevice, isNull);
    controller.dispose();
    gloveState.dispose();
  });

  test('cancelling a stale scan ignores its result', () async {
    final repository = _GloveRepository(delayedScan: true);
    final gloveState = GloveStateProvider();
    final controller = PairingController(
      repository: repository,
      gloveState: gloveState,
    );

    final scan = controller.scan();
    expect(controller.scanStatus, LoadStatus.loading);
    controller.cancelPending();
    repository.completeScan();
    await scan;

    expect(controller.scanStatus, LoadStatus.initial);
    expect(controller.discoveredDevices, isEmpty);
    controller.dispose();
    gloveState.dispose();
  });

  test('disconnect failure keeps paired identity and live state', () async {
    final repository = _GloveRepository(failDisconnect: true);
    final gloveState = GloveStateProvider(
      pairedDevice: repository.devices.first,
      connectionStatus: GloveConnectionStatus.connected,
    );
    final controller = PairingController(
      repository: repository,
      gloveState: gloveState,
    );

    expect(await controller.disconnect(), isFalse);
    expect(gloveState.pairedDevice?.id, 'one');
    expect(gloveState.connectionStatus, GloveConnectionStatus.connected);
    expect(controller.error, isNotEmpty);
    controller.dispose();
    gloveState.dispose();
  });

  test('device actions prevent overlap', () async {
    final repository = _GloveRepository(delayedDisconnect: true);
    final gloveState = GloveStateProvider(
      pairedDevice: repository.devices.first,
      connectionStatus: GloveConnectionStatus.connected,
    );
    final controller = PairingController(
      repository: repository,
      gloveState: gloveState,
    );

    final pending = controller.disconnect();
    expect(controller.isDeviceActionActive, isTrue);
    expect(await controller.forgetDevice(), isFalse);
    repository.completeDisconnect();
    expect(await pending, isTrue);
    expect(gloveState.pairedDevice?.id, 'one');
    controller.dispose();
    gloveState.dispose();
  });

  test('forget failure leaves paired identity intact', () async {
    final repository = _GloveRepository(failDisconnect: true);
    final gloveState = GloveStateProvider(
      pairedDevice: repository.devices.first,
      connectionStatus: GloveConnectionStatus.connected,
    );
    final controller = PairingController(
      repository: repository,
      gloveState: gloveState,
    );

    expect(await controller.forgetDevice(), isFalse);
    expect(gloveState.pairedDevice?.id, 'one');
    expect(gloveState.connectionStatus, GloveConnectionStatus.connected);
    controller.dispose();
    gloveState.dispose();
  });

  test('restores a backend-connected demo glove as connected', () async {
    const demo = GloveDevice(
      id: 'demo',
      name: 'INTELLIGLOVE DEMO',
      batteryLevel: 96,
      signalStrength: 5,
      firmwareVersion: 'demo-1.0.0',
    );
    final repository = _GloveRepository(
      loadedDevice: demo,
      status: GloveConnectionStatus.connected,
    );
    final gloveState = GloveStateProvider();
    final controller = PairingController(
      repository: repository,
      gloveState: gloveState,
    );

    await controller.loadPairedDevice();

    expect(gloveState.pairedDevice?.name, 'INTELLIGLOVE DEMO');
    expect(gloveState.isConnected, isTrue);
    controller.dispose();
    gloveState.dispose();
  });
}

class _GloveRepository implements GloveRepository {
  _GloveRepository({
    this.delayedScan = false,
    this.delayedDisconnect = false,
    this.failDisconnect = false,
    this.loadedDevice,
    this.status = GloveConnectionStatus.disconnected,
  });

  final bool delayedScan;
  final bool delayedDisconnect;
  final bool failDisconnect;
  final GloveDevice? loadedDevice;
  final Completer<List<GloveDevice>> _scanCompleter = Completer();
  final Completer<void> _disconnectCompleter = Completer();
  int disconnectCalls = 0;
  GloveConnectionStatus status;
  final devices = const [
    GloveDevice(id: 'one', name: 'Same Name', batteryLevel: 80),
    GloveDevice(id: 'two', name: 'Same Name', batteryLevel: 70),
  ];

  void completeScan() {
    if (!_scanCompleter.isCompleted) _scanCompleter.complete(devices);
  }

  void completeDisconnect() {
    if (!_disconnectCompleter.isCompleted) _disconnectCompleter.complete();
  }

  @override
  Future<bool> connect(GloveDevice device) async {
    status = GloveConnectionStatus.connected;
    return true;
  }

  @override
  Future<void> disconnect() async {
    disconnectCalls++;
    if (failDisconnect) throw StateError('disconnect failed');
    if (delayedDisconnect) await _disconnectCompleter.future;
    status = GloveConnectionStatus.disconnected;
  }

  @override
  GloveConnectionStatus getStatus() => status;

  @override
  Future<GloveDevice?> loadPairedDevice() async => loadedDevice;

  @override
  Future<List<GloveDevice>> scanDevices() async {
    if (!delayedScan) return devices;
    return _scanCompleter.future;
  }
}
