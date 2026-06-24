import 'package:flutter/widgets.dart';

import '../models/app_alert.dart';
import '../models/load_status.dart';
import '../repositories/alerts_repository.dart';
import '../repositories/backend_repositories.dart';

class AlertsController extends ChangeNotifier {
  AlertsController({AlertsRepository? repository})
    : _repository = repository ?? BackendAlertsRepository();

  final AlertsRepository _repository;
  List<AppAlert> _alerts = const [];
  LoadStatus _status = LoadStatus.initial;
  String? _error;

  List<AppAlert> get alerts => List.unmodifiable(_alerts);
  List<AppAlert> get latestAlerts => List.unmodifiable(_alerts.take(2));
  LoadStatus get status => _status;
  String? get error => _error;
  bool get isLoading => _status == LoadStatus.loading;
  bool get isEmpty => _status == LoadStatus.empty;

  Future<void> load() => refresh();

  Future<void> refresh() async {
    _status = LoadStatus.loading;
    _error = null;
    notifyListeners();
    try {
      _alerts = await _repository.loadAlerts();
      _status = _alerts.isEmpty ? LoadStatus.empty : LoadStatus.success;
    } catch (_) {
      _status = LoadStatus.error;
      _error = 'Could not load alerts. Please try again.';
    }
    notifyListeners();
  }

  Future<bool> markRead(String id) async {
    final index = _alerts.indexWhere((alert) => alert.id == id);
    if (index < 0 || _alerts[index].isRead) return true;
    final previous = _alerts;
    _alerts = [
      for (final alert in _alerts)
        if (alert.id == id) alert.copyWith(isRead: true) else alert,
    ];
    notifyListeners();
    try {
      await _repository.markRead(id);
      return true;
    } catch (_) {
      _alerts = previous;
      _error = 'Could not update the alert.';
      notifyListeners();
      return false;
    }
  }
}

class AlertsScope extends InheritedNotifier<AlertsController> {
  const AlertsScope({
    super.key,
    required AlertsController super.notifier,
    required super.child,
  });

  static AlertsController of(BuildContext context) {
    final controller = context
        .dependOnInheritedWidgetOfExactType<AlertsScope>()
        ?.notifier;
    if (controller == null) {
      throw FlutterError('AlertsScope.of() called without an AlertsScope.');
    }
    return controller;
  }
}
