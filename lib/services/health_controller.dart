import 'package:flutter/foundation.dart';

import '../models/load_status.dart';
import '../repositories/health_repository.dart';
import '../repositories/backend_repositories.dart';

class HealthController extends ChangeNotifier {
  HealthController({HealthRepository? repository})
    : _repository = repository ?? BackendHealthRepository();

  final HealthRepository _repository;
  LoadStatus _status = LoadStatus.initial;
  HealthVitals _vitals = const HealthVitals.disconnected();
  String? _error;

  LoadStatus get status => _status;
  HealthVitals get vitals => _vitals;
  String? get error => _error;

  Future<void> load({required bool isConnected}) async {
    _status = LoadStatus.loading;
    _error = null;
    notifyListeners();
    try {
      _vitals = await _repository.getVitals(isConnected: isConnected);
      final hasData =
          _vitals.heartRate != null ||
          _vitals.bloodPressure != null ||
          _vitals.bloodOxygen != null ||
          _vitals.respiratoryRate != null;
      _status = hasData ? LoadStatus.success : LoadStatus.empty;
    } catch (_) {
      _vitals = const HealthVitals.disconnected();
      _status = LoadStatus.error;
      _error = 'Health data could not be loaded.';
    }
    notifyListeners();
  }
}
