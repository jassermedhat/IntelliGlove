// lib/repositories/health_repository.dart
// Interface + mock implementation for health vitals.
// IMPORTANT: All values are DEMO data until a real BLE health sensor is integrated.

class HealthVitals {
  /// Whether these are real readings (false = demo/mock).
  final bool isDemo;
  final int? heartRate; // bpm
  final String? bloodPressure; // e.g. "120/80"
  final int? bloodOxygen; // SpO2 %
  final int? respiratoryRate; // breaths/min
  final double? temperatureCelsius;
  final String? emotion; // e.g. "Happy"
  final int? activeEmotion; // index 0-3

  const HealthVitals({
    required this.isDemo,
    this.heartRate,
    this.bloodPressure,
    this.bloodOxygen,
    this.respiratoryRate,
    this.temperatureCelsius,
    this.emotion,
    this.activeEmotion,
  });

  /// Empty vitals when glove is disconnected.
  const HealthVitals.disconnected()
    : isDemo = false,
      heartRate = null,
      bloodPressure = null,
      bloodOxygen = null,
      respiratoryRate = null,
      temperatureCelsius = null,
      emotion = null,
      activeEmotion = null;

  /// Demo/mock vitals when glove is connected but backend data is unavailable.
  const HealthVitals.demo()
    : isDemo = true,
      heartRate = 72,
      bloodPressure = '120/80',
      bloodOxygen = 98,
      respiratoryRate = 16,
      temperatureCelsius = 36.7,
      emotion = 'Happy',
      activeEmotion = 2;
}

// ─────────────────────────────────────────────────────────────────────────────
//  Abstract interface
// ─────────────────────────────────────────────────────────────────────────────

abstract class HealthRepository {
  /// Returns current vitals. Caller should check [isConnected] before calling.
  Future<HealthVitals> getVitals({required bool isConnected});
}

// ─────────────────────────────────────────────────────────────────────────────
//  Mock implementation
// ─────────────────────────────────────────────────────────────────────────────

class MockHealthRepository implements HealthRepository {
  @override
  Future<HealthVitals> getVitals({required bool isConnected}) async {
    if (!isConnected) return const HealthVitals.disconnected();
    return const HealthVitals.demo();
  }
}
