import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/glove_device.dart';
import '../repositories/glove_repository.dart';
import '../repositories/backend_repositories.dart';

class _Keys {
  static const deviceId = 'glove_device_id';
  static const gloveName = 'glove_name';
  static const hardwareAddress = 'glove_hardware_address';
  static const batteryLevel = 'glove_battery';
  static const signalStrength = 'glove_signal';
  static const firmwareVersion = 'glove_firmware';
}

class GloveStateProvider extends ChangeNotifier {
  GloveDevice? _pairedDevice;
  GloveConnectionStatus _connectionStatus;

  GloveStateProvider({
    GloveDevice? pairedDevice,
    GloveConnectionStatus connectionStatus = GloveConnectionStatus.disconnected,
  }) : _pairedDevice = pairedDevice,
       _connectionStatus = connectionStatus;

  static Future<GloveStateProvider> load({GloveRepository? repository}) async {
    final gloveRepository = repository ?? BackendGloveRepository();
    final device = await gloveRepository.loadPairedDevice();
    return GloveStateProvider(
      pairedDevice: device,
      connectionStatus: GloveConnectionStatus.disconnected,
    );
  }

  GloveDevice? get pairedDevice => _pairedDevice;
  GloveConnectionStatus get connectionStatus => _connectionStatus;
  bool get hasPairedDevice => _pairedDevice != null;
  bool get isConnected => _connectionStatus == GloveConnectionStatus.connected;

  Future<void> restorePairedDevice(
    GloveDevice device, {
    GloveConnectionStatus connectionStatus = GloveConnectionStatus.disconnected,
  }) async {
    final changed =
        _pairedDevice?.id != device.id ||
        _pairedDevice?.name != device.name ||
        _pairedDevice?.batteryLevel != device.batteryLevel ||
        _pairedDevice?.signalStrength != device.signalStrength ||
        _pairedDevice?.firmwareVersion != device.firmwareVersion ||
        _connectionStatus != connectionStatus;
    _pairedDevice = device;
    _connectionStatus = connectionStatus;
    if (changed) notifyListeners();
  }

  Future<void> onDeviceConnected({required GloveDevice device}) async {
    _pairedDevice = device;
    _connectionStatus = GloveConnectionStatus.connected;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_Keys.deviceId, _pairedDevice!.id);
    await prefs.setString(_Keys.gloveName, device.name);
    if (device.hardwareAddress != null) {
      await prefs.setString(_Keys.hardwareAddress, device.hardwareAddress!);
    }
    if (device.batteryLevel != null) {
      await prefs.setInt(_Keys.batteryLevel, device.batteryLevel!);
    }
    if (device.signalStrength != null) {
      await prefs.setInt(_Keys.signalStrength, device.signalStrength!);
    }
    if (device.firmwareVersion != null) {
      await prefs.setString(_Keys.firmwareVersion, device.firmwareVersion!);
    }
  }

  void setConnectionStatus(GloveConnectionStatus status) {
    if (_connectionStatus == status) return;
    _connectionStatus = status;
    notifyListeners();
  }

  void markDisconnected() {
    _connectionStatus = GloveConnectionStatus.disconnected;
    notifyListeners();
  }

  Future<void> forgetDevice() async {
    _pairedDevice = null;
    _connectionStatus = GloveConnectionStatus.disconnected;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_Keys.deviceId);
    await prefs.remove(_Keys.gloveName);
    await prefs.remove(_Keys.hardwareAddress);
    await prefs.remove(_Keys.batteryLevel);
    await prefs.remove(_Keys.signalStrength);
    await prefs.remove(_Keys.firmwareVersion);
  }
}

class GloveStateScope extends InheritedNotifier<GloveStateProvider> {
  const GloveStateScope({
    super.key,
    required GloveStateProvider super.notifier,
    required super.child,
  });

  static GloveStateProvider of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<GloveStateScope>();
    final notifier = scope?.notifier;
    if (notifier == null) {
      throw FlutterError(
        'GloveStateScope.of() called without a GloveStateScope above the context.',
      );
    }
    return notifier;
  }
}
