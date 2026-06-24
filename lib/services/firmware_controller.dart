import 'dart:async';

import 'package:flutter/widgets.dart';

import '../repositories/firmware_repository.dart';
import '../repositories/backend_repositories.dart';

enum FirmwareStatus {
  initial,
  checking,
  noUpdate,
  updateAvailable,
  downloading,
  installing,
  success,
  failure,
}

class FirmwareController extends ChangeNotifier {
  FirmwareController({FirmwareRepository? repository})
    : _repository = repository ?? BackendFirmwareRepository();

  final FirmwareRepository _repository;
  FirmwareStatus _status = FirmwareStatus.initial;
  String _currentVersion = 'Unknown';
  String? _availableVersion;
  double _progress = 0;
  String? _error;
  int _operation = 0;

  FirmwareStatus get status => _status;
  String get currentVersion => _currentVersion;
  String? get availableVersion => _availableVersion;
  double get progress => _progress;
  String? get error => _error;
  bool get isBusy =>
      _status == FirmwareStatus.checking ||
      _status == FirmwareStatus.downloading ||
      _status == FirmwareStatus.installing;

  Future<void> check() async {
    final operation = ++_operation;
    _status = FirmwareStatus.checking;
    _error = null;
    notifyListeners();
    try {
      final info = await _repository.checkForUpdate();
      if (operation != _operation) return;
      _currentVersion = info.currentVersion;
      _availableVersion = info.availableVersion;
      _status = info.hasUpdate
          ? FirmwareStatus.updateAvailable
          : FirmwareStatus.noUpdate;
    } catch (_) {
      if (operation != _operation) return;
      _status = FirmwareStatus.failure;
      _error = 'Could not check for firmware updates.';
    }
    notifyListeners();
  }

  Future<void> install() async {
    if (_availableVersion == null || isBusy) return;
    final operation = ++_operation;
    _status = FirmwareStatus.downloading;
    _progress = 0;
    _error = null;
    notifyListeners();
    try {
      await for (final progress in _repository.installUpdate()) {
        if (operation != _operation) return;
        _progress = progress.clamp(0, 1);
        _status = _progress < 0.6
            ? FirmwareStatus.downloading
            : FirmwareStatus.installing;
        notifyListeners();
      }
      if (operation != _operation) return;
      _currentVersion = _availableVersion!;
      _availableVersion = null;
      _progress = 1;
      _status = FirmwareStatus.success;
    } catch (_) {
      if (operation != _operation) return;
      _status = FirmwareStatus.failure;
      _error = 'The firmware simulation failed. Please try again.';
    }
    notifyListeners();
  }

  Future<void> retry() => _availableVersion == null ? check() : install();

  @override
  void dispose() {
    _operation++;
    super.dispose();
  }
}

class FirmwareScope extends InheritedNotifier<FirmwareController> {
  const FirmwareScope({
    super.key,
    required FirmwareController super.notifier,
    required super.child,
  });

  static FirmwareController of(BuildContext context) {
    final controller = context
        .dependOnInheritedWidgetOfExactType<FirmwareScope>()
        ?.notifier;
    if (controller == null) {
      throw FlutterError('FirmwareScope.of() called without a FirmwareScope.');
    }
    return controller;
  }
}
