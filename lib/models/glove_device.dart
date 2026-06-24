// lib/models/glove_device.dart
// Stable glove device identity + live connection status enum.
// GloveDevice represents a paired device (persisted across restarts).
// GloveConnectionStatus reflects live BLE/backend state (NOT persisted).

/// Live connection state — never persisted as truth across restarts.
enum GloveConnectionStatus {
  /// No paired device or device not reachable.
  disconnected,

  /// Attempting initial BLE connection.
  connecting,

  /// BLE session is active and data is flowing.
  connected,

  /// Lost connection; attempting automatic reconnect.
  reconnecting,

  /// Device is paired but has been explicitly marked unavailable
  /// (e.g. out of range, BLE turned off).
  unavailable,
}

/// Immutable identity of a paired glove device.
/// Stable across restarts — persisted to SharedPreferences.
class GloveDevice {
  /// Stable device identifier (BLE peripheral ID, HW address, or backend ID).
  /// Used to distinguish devices, even those with the same display name.
  final String id;

  /// Human-readable display name (e.g. "IntelliGlove Pro").
  final String name;

  /// Hardware/MAC address if available from BLE layer.
  final String? hardwareAddress;

  /// Last known firmware version string (e.g. "v2.4.1").
  final String? firmwareVersion;

  /// Last known battery level (0–100). Null if never received.
  final int? batteryLevel;

  /// Last known signal strength (0–5 bars). Null if never received.
  final int? signalStrength;

  const GloveDevice({
    required this.id,
    required this.name,
    this.hardwareAddress,
    this.firmwareVersion,
    this.batteryLevel,
    this.signalStrength,
  });

  GloveDevice copyWith({
    String? id,
    String? name,
    String? hardwareAddress,
    String? firmwareVersion,
    int? batteryLevel,
    int? signalStrength,
  }) {
    return GloveDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      hardwareAddress: hardwareAddress ?? this.hardwareAddress,
      firmwareVersion: firmwareVersion ?? this.firmwareVersion,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      signalStrength: signalStrength ?? this.signalStrength,
    );
  }
}
