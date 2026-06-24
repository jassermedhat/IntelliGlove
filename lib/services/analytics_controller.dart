import 'package:flutter/foundation.dart';

import '../models/load_status.dart';
import '../repositories/analytics_repository.dart';
import '../repositories/backend_repositories.dart';

enum AnalyticsRange { day, week, month }

class AnalyticsController extends ChangeNotifier {
  AnalyticsController({AnalyticsRepository? repository})
    : _repository = repository ?? BackendAnalyticsRepository();

  final AnalyticsRepository _repository;
  AnalyticsRange _selectedRange = AnalyticsRange.week;
  final Map<AnalyticsRange, AnalyticsData> _data = {};
  final Map<AnalyticsRange, LoadStatus> _statuses = {
    for (final range in AnalyticsRange.values) range: LoadStatus.initial,
  };
  final Map<AnalyticsRange, String?> _errors = {};

  AnalyticsRange get selectedRange => _selectedRange;
  AnalyticsData? dataFor(AnalyticsRange range) => _data[range];
  LoadStatus statusFor(AnalyticsRange range) => _statuses[range]!;
  String? errorFor(AnalyticsRange range) => _errors[range];

  void selectRange(AnalyticsRange range) {
    if (_selectedRange == range) return;
    _selectedRange = range;
    notifyListeners();
    if (statusFor(range) == LoadStatus.initial) load(range);
  }

  Future<void> loadAll() async {
    await Future.wait(AnalyticsRange.values.map(load));
  }

  Future<void> load(AnalyticsRange range) async {
    if (statusFor(range) == LoadStatus.loading) return;
    _statuses[range] = LoadStatus.loading;
    _errors[range] = null;
    notifyListeners();
    try {
      final data = switch (range) {
        AnalyticsRange.day => await _repository.loadDay(),
        AnalyticsRange.week => await _repository.loadWeek(),
        AnalyticsRange.month => await _repository.loadMonth(),
      };
      _data[range] = data;
      _statuses[range] = data.gestures.isEmpty
          ? LoadStatus.empty
          : LoadStatus.success;
    } catch (_) {
      _data.remove(range);
      _errors[range] = 'Analytics could not be loaded.';
      _statuses[range] = LoadStatus.error;
    }
    notifyListeners();
  }

  Future<void> retry(AnalyticsRange range) => load(range);
}
