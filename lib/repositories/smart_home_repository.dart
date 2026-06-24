// lib/repositories/smart_home_repository.dart
// Interface + local implementation for smart home device persistence.

import 'package:shared_preferences/shared_preferences.dart';
import '../models/smart_device.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Default devices (loaded on first run if no saved data exists)
// ─────────────────────────────────────────────────────────────────────────────

const _kDefaultDevices = [
  SmartDevice(
    id: 1,
    name: 'Living Room Light',
    iconKey: 'light',
    gesture: 'Peace Sign',
    isOn: true,
  ),
  SmartDevice(
    id: 2,
    name: 'Smart TV',
    iconKey: 'tv',
    gesture: 'Thumb Up',
    isOn: false,
  ),
  SmartDevice(
    id: 3,
    name: 'Front Door Lock',
    iconKey: 'lock',
    gesture: 'Fist',
    isOn: true,
  ),
  SmartDevice(
    id: 4,
    name: 'Thermostat',
    iconKey: 'thermostat',
    gesture: 'Open Palm',
    isOn: true,
  ),
];

const _kDevicesKey = 'smart_home_devices';

// ─────────────────────────────────────────────────────────────────────────────
//  Abstract interface
// ─────────────────────────────────────────────────────────────────────────────

abstract class SmartHomeRepository {
  Future<List<SmartDevice>> loadDevices();
  Future<void> saveDevices(List<SmartDevice> devices);
}

// ─────────────────────────────────────────────────────────────────────────────
//  Local implementation — SharedPreferences persistence
// ─────────────────────────────────────────────────────────────────────────────

class LocalSmartHomeRepository implements SmartHomeRepository {
  @override
  Future<List<SmartDevice>> loadDevices() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_kDevicesKey);
    if (raw == null || raw.isEmpty) return List.from(_kDefaultDevices);
    final loaded = raw
        .map(SmartDevice.deserialize)
        .whereType<SmartDevice>()
        .toList();
    return loaded.isEmpty ? List.from(_kDefaultDevices) : loaded;
  }

  @override
  Future<void> saveDevices(List<SmartDevice> devices) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _kDevicesKey,
      devices.map((d) => d.serialize()).toList(),
    );
  }
}
