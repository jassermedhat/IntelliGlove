import 'package:flutter/material.dart';

class SmartDeviceIconResolver {
  const SmartDeviceIconResolver._();

  static IconData fromKey(String key) {
    switch (key) {
      case 'light':
        return Icons.lightbulb_outline_rounded;
      case 'tv':
        return Icons.tv_rounded;
      case 'lock':
        return Icons.lock_outline_rounded;
      case 'thermostat':
        return Icons.thermostat_rounded;
      case 'fan':
        return Icons.air_rounded;
      default:
        return Icons.devices_other_rounded;
    }
  }
}
