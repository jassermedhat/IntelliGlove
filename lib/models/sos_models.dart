// lib/models/sos_models.dart
// SOS state machine states, request payload, and shared EmergencyContact model.

/// State machine for the SOS flow.
enum SosState {
  /// Default state. Button shows "SOS".
  idle,

  /// User is holding the button. Progress ring fills.
  holding,

  /// Hold completed. Location is being acquired and SOS is being sent.
  sending,

  /// SOS sent successfully.
  success,

  /// SOS failed (location unavailable, network error, etc.).
  failed,
}

/// An emergency contact stored locally.
class EmergencyContact {
  final int id;
  final String name;
  final String phone;
  final String? relationship;

  const EmergencyContact({
    required this.id,
    required this.name,
    required this.phone,
    this.relationship,
  });

  EmergencyContact copyWith({
    int? id,
    String? name,
    String? phone,
    String? relationship,
  }) {
    return EmergencyContact(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      relationship: relationship ?? this.relationship,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'relationship': relationship,
  };

  static EmergencyContact? fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final name = json['name'];
    final phone = json['phone'];
    if (id is! int || name is! String || phone is! String) return null;
    return EmergencyContact(
      id: id,
      name: name,
      phone: phone,
      relationship: json['relationship'] as String?,
    );
  }
}

/// Payload prepared when an SOS is activated.
class SosRequest {
  final DateTime timestamp;
  final double? latitude;
  final double? longitude;
  final List<EmergencyContact> contacts;
  final String? userId;
  final String? photoPath;
  final String? requestId;

  const SosRequest({
    required this.timestamp,
    required this.contacts,
    this.latitude,
    this.longitude,
    this.userId,
    this.photoPath,
    this.requestId,
  });

  Map<String, Object?> toJson() => {
    'timestamp': timestamp.toUtc().toIso8601String(),
    'latitude': latitude,
    'longitude': longitude,
    'contacts': contacts.map((contact) => contact.toJson()).toList(),
    'userId': userId,
    'photoPath': photoPath,
    'requestId': requestId,
  };
}

/// Result of an SOS send attempt.
class SosResult {
  final bool success;
  final String? errorMessage;

  const SosResult({required this.success, this.errorMessage});
}
