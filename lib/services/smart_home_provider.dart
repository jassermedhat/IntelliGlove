import 'package:flutter/material.dart';

import '../models/load_status.dart';
import '../models/smart_device.dart';
import '../repositories/smart_home_repository.dart';
import '../repositories/backend_repositories.dart';

class SmartHomeProvider extends ChangeNotifier {
  SmartHomeProvider({SmartHomeRepository? repository})
    : _repository = repository ?? BackendSmartHomeRepository();

  final SmartHomeRepository _repository;
  LoadStatus _status = LoadStatus.initial;
  List<SmartDevice> _devices = const [];
  String? _errorMessage;
  bool _isSaving = false;

  LoadStatus get status => _status;
  List<SmartDevice> get devices => List.unmodifiable(_devices);
  String? get errorMessage => _errorMessage;
  bool get isSaving => _isSaving;

  Future<void> load() async {
    _status = LoadStatus.loading;
    notifyListeners();
    try {
      _devices = await _repository.loadDevices();
      _errorMessage = null;
      _status = _devices.isEmpty ? LoadStatus.empty : LoadStatus.success;
    } catch (_) {
      _devices = const [];
      _errorMessage = 'Could not load smart-home devices.';
      _status = LoadStatus.error;
    }
    notifyListeners();
  }

  Future<bool> addDevice(SmartDevice device) async {
    return _persist([..._devices, device]);
  }

  Future<bool> toggleDevice(int id) async {
    return _persist([
      for (final device in _devices)
        device.id == id ? device.copyWith(isOn: !device.isOn) : device,
    ]);
  }

  Future<bool> editDevice(SmartDevice updated) async {
    return _persist([
      for (final device in _devices) device.id == updated.id ? updated : device,
    ]);
  }

  Future<bool> removeDevice(int id) async {
    return _persist(_devices.where((device) => device.id != id).toList());
  }

  Future<bool> updateGesture(int id, String gesture) async {
    return _persist([
      for (final device in _devices)
        device.id == id ? device.copyWith(gesture: gesture) : device,
    ]);
  }

  Future<bool> _persist(List<SmartDevice> next) async {
    if (_isSaving) return false;
    final previous = _devices;
    _isSaving = true;
    _devices = List.unmodifiable(next);
    _status = _devices.isEmpty ? LoadStatus.empty : LoadStatus.success;
    _errorMessage = null;
    notifyListeners();
    try {
      await _repository.saveDevices(_devices);
      _isSaving = false;
      notifyListeners();
      return true;
    } catch (_) {
      _devices = previous;
      _status = _devices.isEmpty ? LoadStatus.empty : LoadStatus.success;
      _errorMessage = 'Changes could not be saved. Please try again.';
      _isSaving = false;
      notifyListeners();
      return false;
    }
  }
}

class SmartHomeScope extends InheritedNotifier<SmartHomeProvider> {
  const SmartHomeScope({
    super.key,
    required SmartHomeProvider super.notifier,
    required super.child,
  });

  static SmartHomeProvider of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SmartHomeScope>();
    final notifier = scope?.notifier;
    if (notifier == null) {
      throw FlutterError(
        'SmartHomeScope.of() called without a SmartHomeScope above the context.',
      );
    }
    return notifier;
  }
}
