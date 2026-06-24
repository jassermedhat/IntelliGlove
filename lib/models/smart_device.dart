// lib/models/smart_device.dart
// Persistent smart home device model.

class SmartDevice {
  final int id;
  final String? backendId;
  final String name;

  /// Icon key maps to an IconData in the UI layer (e.g. 'light', 'tv', 'lock').
  final String iconKey;
  final String gesture;
  final bool isOn;

  const SmartDevice({
    required this.id,
    this.backendId,
    required this.name,
    required this.iconKey,
    required this.gesture,
    required this.isOn,
  });

  SmartDevice copyWith({
    int? id,
    String? backendId,
    String? name,
    String? iconKey,
    String? gesture,
    bool? isOn,
  }) {
    return SmartDevice(
      id: id ?? this.id,
      backendId: backendId ?? this.backendId,
      name: name ?? this.name,
      iconKey: iconKey ?? this.iconKey,
      gesture: gesture ?? this.gesture,
      isOn: isOn ?? this.isOn,
    );
  }

  /// Serialise to "id|name|iconKey|gesture|isOn" for SharedPreferences.
  String serialize() => '$id|$name|$iconKey|$gesture|${isOn ? '1' : '0'}';

  static SmartDevice? deserialize(String raw) {
    final parts = raw.split('|');
    if (parts.length < 5) return null;
    final id = int.tryParse(parts[0]);
    if (id == null) return null;
    return SmartDevice(
      id: id,
      name: parts[1],
      iconKey: parts[2],
      gesture: parts[3],
      isOn: parts[4] == '1',
    );
  }
}
