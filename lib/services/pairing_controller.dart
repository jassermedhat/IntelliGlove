import 'dart:async';

import 'package:flutter/material.dart';

import '../models/glove_device.dart';
import '../models/load_status.dart';
import '../repositories/glove_repository.dart';
import 'glove_state_provider.dart';

class PairingController extends ChangeNotifier {
  PairingController({
    required GloveRepository repository,
    required GloveStateProvider gloveState,
  }) : _repository = repository,
       _gloveState = gloveState;

  final GloveRepository _repository;
  final GloveStateProvider _gloveState;

  List<GloveDevice> _discoveredDevices = const [];
  LoadStatus _scanStatus = LoadStatus.initial;
  String? _error;
  String? _connectingDeviceId;
  String? _deviceAction;
  int _operationToken = 0;
  bool _disposed = false;
  bool _loadingPairedDevice = false;
  Timer? _monitorTimer;

  List<GloveDevice> get discoveredDevices => List.unmodifiable(
    _discoveredDevices.where(
      (device) => device.id != _gloveState.pairedDevice?.id,
    ),
  );
  GloveDevice? get pairedDevice => _gloveState.pairedDevice;
  GloveConnectionStatus get connectionStatus => _gloveState.connectionStatus;
  LoadStatus get scanStatus => _scanStatus;
  String? get error => _error;
  String? get connectingDeviceId => _connectingDeviceId;
  bool get isScanning => _scanStatus == LoadStatus.loading;
  bool get isConnecting => _connectingDeviceId != null;
  bool get isDeviceActionActive => _deviceAction != null;
  String? get deviceAction => _deviceAction;

  Future<void> loadPairedDevice() async {
    if (_disposed || _loadingPairedDevice) return;
    _loadingPairedDevice = true;
    try {
      final device = await _repository.loadPairedDevice();
      if (_disposed) return;
      if (device == null) {
        _gloveState.markDisconnected();
      } else {
        await _gloveState.restorePairedDevice(
          device,
          connectionStatus: _repository.getStatus(),
        );
      }
    } catch (_) {
      if (_disposed) return;
      _error = 'Could not restore the saved glove.';
      notifyListeners();
    } finally {
      _loadingPairedDevice = false;
    }
  }

  void startMonitoring() {
    if (_disposed || _monitorTimer != null) return;
    unawaited(loadPairedDevice());
    _monitorTimer = Timer.periodic(
      const Duration(seconds: 4),
      (_) => unawaited(loadPairedDevice()),
    );
  }

  void stopMonitoring() {
    _monitorTimer?.cancel();
    _monitorTimer = null;
  }

  Future<void> scan() async {
    if (_disposed || isScanning || isConnecting || isDeviceActionActive) return;
    final token = ++_operationToken;
    _scanStatus = LoadStatus.loading;
    _error = null;
    _discoveredDevices = const [];
    notifyListeners();

    try {
      final devices = await _repository.scanDevices();
      if (!_isCurrent(token)) return;
      _discoveredDevices = devices;
      _scanStatus = discoveredDevices.isEmpty
          ? LoadStatus.empty
          : LoadStatus.success;
    } catch (_) {
      if (!_isCurrent(token)) return;
      _discoveredDevices = const [];
      _scanStatus = LoadStatus.error;
      _error = 'Could not scan for nearby gloves. Please try again.';
    }
    if (_isCurrent(token)) notifyListeners();
  }

  Future<bool> connect(GloveDevice device) async {
    if (_disposed || isScanning || isConnecting || isDeviceActionActive) {
      return false;
    }
    final token = ++_operationToken;
    _connectingDeviceId = device.id;
    _error = null;
    _gloveState.setConnectionStatus(GloveConnectionStatus.connecting);
    notifyListeners();

    try {
      final connected = await _repository.connect(device);
      if (!_isCurrent(token)) return false;
      if (!connected) {
        _gloveState.setConnectionStatus(GloveConnectionStatus.disconnected);
        _error = 'Could not connect to ${device.name}.';
        return false;
      }
      await _gloveState.onDeviceConnected(device: device);
      if (!_isCurrent(token)) return false;
      _discoveredDevices = _discoveredDevices
          .where((candidate) => candidate.id != device.id)
          .toList();
      return true;
    } catch (_) {
      if (!_isCurrent(token)) return false;
      _gloveState.setConnectionStatus(GloveConnectionStatus.disconnected);
      _error = 'Could not connect to ${device.name}.';
      return false;
    } finally {
      if (_isCurrent(token)) {
        _connectingDeviceId = null;
        notifyListeners();
      }
    }
  }

  Future<bool> disconnect() async {
    if (_disposed || isConnecting || isScanning || isDeviceActionActive) {
      return false;
    }
    cancelPending();
    _deviceAction = 'disconnect';
    _error = null;
    notifyListeners();
    try {
      await _repository.disconnect();
      if (_disposed) return false;
      _gloveState.markDisconnected();
      return true;
    } catch (_) {
      _error = 'Could not disconnect the glove. Please try again.';
      return false;
    } finally {
      if (!_disposed) {
        _deviceAction = null;
        notifyListeners();
      }
    }
  }

  Future<bool> forgetDevice() async {
    if (_disposed || isConnecting || isScanning || isDeviceActionActive) {
      return false;
    }
    _deviceAction = 'forget';
    _error = null;
    notifyListeners();
    try {
      if (_gloveState.isConnected) {
        await _repository.disconnect();
        if (_disposed) return false;
        _gloveState.markDisconnected();
      }
      await _gloveState.forgetDevice();
      _discoveredDevices = const [];
      _scanStatus = LoadStatus.initial;
      notifyListeners();
      return true;
    } catch (_) {
      _error = 'Could not forget the saved glove. Please try again.';
      return false;
    } finally {
      if (!_disposed) {
        _deviceAction = null;
        notifyListeners();
      }
    }
  }

  void cancelPending() {
    _operationToken++;
    _connectingDeviceId = null;
    if (_scanStatus == LoadStatus.loading) {
      _scanStatus = LoadStatus.initial;
    }
    if (!_disposed) notifyListeners();
  }

  bool _isCurrent(int token) => !_disposed && token == _operationToken;

  @override
  void dispose() {
    stopMonitoring();
    _disposed = true;
    _operationToken++;
    super.dispose();
  }
}

class PairingControllerScope extends InheritedNotifier<PairingController> {
  const PairingControllerScope({
    super.key,
    required PairingController super.notifier,
    required super.child,
  });

  static PairingController of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<PairingControllerScope>();
    final notifier = scope?.notifier;
    if (notifier == null) {
      throw FlutterError(
        'PairingControllerScope.of() called without a PairingControllerScope '
        'above the context.',
      );
    }
    return notifier;
  }
}
