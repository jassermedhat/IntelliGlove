// lib/repositories/analytics_repository.dart
// Interface + mock implementation for gesture analytics data.

class GestureUsage {
  final String label;
  final int count;
  final double percentage;

  const GestureUsage({
    required this.label,
    required this.count,
    required this.percentage,
  });
}

class AnalyticsData {
  final List<int> gestures;
  final List<String> labels;
  final List<double> accuracy;
  final List<int> sessionMinutes;
  final List<GestureUsage> topGestures;

  const AnalyticsData({
    required this.gestures,
    required this.labels,
    required this.accuracy,
    required this.sessionMinutes,
    required this.topGestures,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
//  Abstract interface
// ─────────────────────────────────────────────────────────────────────────────

abstract class AnalyticsRepository {
  Future<AnalyticsData> loadDay();
  Future<AnalyticsData> loadWeek();
  Future<AnalyticsData> loadMonth();
}

// ─────────────────────────────────────────────────────────────────────────────
//  Mock implementation
// ─────────────────────────────────────────────────────────────────────────────

class MockAnalyticsRepository implements AnalyticsRepository {
  static const _day = AnalyticsData(
    gestures: [12, 8, 22, 31, 18, 27, 19, 5],
    labels: ['8am', '9am', '10am', '11am', '12pm', '1pm', '2pm', '3pm'],
    accuracy: [94.0, 95.5, 92.0, 96.8, 95.5, 97.1, 96.4, 95.0],
    sessionMinutes: [8, 5, 14, 22, 12, 18, 15, 4],
    topGestures: _topGestures,
  );
  static const _week = AnalyticsData(
    gestures: [98, 124, 87, 142, 116, 155, 130],
    labels: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
    accuracy: [94.2, 95.1, 93.8, 96.8, 95.5, 97.1, 96.4],
    sessionMinutes: [24, 41, 18, 55, 37, 62, 48],
    topGestures: _topGestures,
  );
  static const _month = AnalyticsData(
    gestures: [612, 734, 890, 966],
    labels: ['Wk 1', 'Wk 2', 'Wk 3', 'Wk 4'],
    accuracy: [93.0, 94.5, 95.8, 97.2],
    sessionMinutes: [280, 340, 410, 490],
    topGestures: _topGestures,
  );

  static const _topGestures = [
    GestureUsage(label: 'Hello', count: 38, percentage: 0.88),
    GestureUsage(label: 'Thank you', count: 31, percentage: 0.72),
    GestureUsage(label: 'Yes', count: 27, percentage: 0.63),
    GestureUsage(label: 'No', count: 22, percentage: 0.51),
    GestureUsage(label: 'Help', count: 18, percentage: 0.42),
  ];

  @override
  Future<AnalyticsData> loadDay() async => _day;
  @override
  Future<AnalyticsData> loadWeek() async => _week;
  @override
  Future<AnalyticsData> loadMonth() async => _month;
}
