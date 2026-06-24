// lib/repositories/glove_repository.dart
// Glove device repository and local development implementation.

import '../models/glove_device.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Abstract interface
// ─────────────────────────────────────────────────────────────────────────────

abstract class GloveRepository {
  /// Load the last paired device from persistent storage.
  /// Returns null if no device has been paired.
  Future<GloveDevice?> loadPairedDevice();

  /// Scan for nearby BLE devices. Returns a list of discovered devices.
  Future<List<GloveDevice>> scanDevices();

  /// Attempt to connect to [device]. Returns true on success.
  Future<bool> connect(GloveDevice device);

  /// Disconnect from the currently connected device.
  Future<void> disconnect();

  /// Returns the current live connection status.
  GloveConnectionStatus getStatus();
}

// ─────────────────────────────────────────────────────────────────────────────
//  Mock implementation — used until real BLE layer is wired
// ─────────────────────────────────────────────────────────────────────────────

const _kMockDevices = [
  GloveDevice(
    id: 'IG-PRO-2024',
    name: 'IntelliGlove Pro',
    firmwareVersion: 'v2.4.1',
    batteryLevel: 78,
    signalStrength: 4,
  ),
  GloveDevice(
    id: 'IG-LITE-2024',
    name: 'IntelliGlove Lite',
    firmwareVersion: 'v1.8.3',
    batteryLevel: 92,
    signalStrength: 3,
  ),
  GloveDevice(
    id: 'IG-SE-2024',
    name: 'IntelliGlove SE',
    firmwareVersion: 'v1.5.0',
    batteryLevel: 55,
    signalStrength: 2,
  ),
];

class MockGloveRepository implements GloveRepository {
  static const _deviceIdKey = 'glove_device_id';
  static const _nameKey = 'glove_name';
  static const _hardwareAddressKey = 'glove_hardware_address';
  static const _batteryKey = 'glove_battery';
  static const _signalKey = 'glove_signal';
  static const _firmwareKey = 'glove_firmware';

  GloveConnectionStatus _status = GloveConnectionStatus.disconnected;

  @override
  Future<GloveDevice?> loadPairedDevice() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_deviceIdKey);
    final name = prefs.getString(_nameKey);
    if (id == null || id.isEmpty || name == null || name.isEmpty) return null;
    return GloveDevice(
      id: id,
      name: name,
      hardwareAddress: prefs.getString(_hardwareAddressKey),
      batteryLevel: prefs.getInt(_batteryKey),
      signalStrength: prefs.getInt(_signalKey),
      firmwareVersion: prefs.getString(_firmwareKey),
    );
  }

  @override
  Future<List<GloveDevice>> scanDevices() async {
    await Future<void>.delayed(const Duration(milliseconds: 2500));
    return List.from(_kMockDevices);
  }

  @override
  Future<bool> connect(GloveDevice device) async {
    _status = GloveConnectionStatus.connecting;
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    _status = GloveConnectionStatus.connected;
    return true;
  }

  @override
  Future<void> disconnect() async {
    _status = GloveConnectionStatus.disconnected;
  }

  @override
  GloveConnectionStatus getStatus() => _status;
}
