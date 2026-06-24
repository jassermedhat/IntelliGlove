import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/sos_models.dart';
import '../repositories/emergency_repository.dart';
import 'emergency_contacts_controller.dart';
import 'location_services.dart';

class SosController extends ChangeNotifier {
  SosController({
    required EmergencyRepository emergencyRepository,
    required LocationPermissionService locationPermissionService,
    required LocationRepository locationRepository,
    required EmergencyContactsController contactsController,
    this.holdDuration = const Duration(seconds: 3),
    this.holdTick = const Duration(milliseconds: 50),
  }) : _emergencyRepository = emergencyRepository,
       _locationPermissionService = locationPermissionService,
       _locationRepository = locationRepository,
       _contactsController = contactsController;

  final EmergencyRepository _emergencyRepository;
  final LocationPermissionService _locationPermissionService;
  final LocationRepository _locationRepository;
  final EmergencyContactsController _contactsController;
  final Duration holdDuration;
  final Duration holdTick;

  SosState _state = SosState.idle;
  SosRequest? _preparedRequest;
  String? _failureReason;
  double? _latitude;
  double? _longitude;
  bool _retrying = false;
  bool _requiresSettings = false;
  double _holdProgress = 0;
  Timer? _holdTimer;
  Future<void> Function()? _onHoldCompleted;

  SosState get state => _state;
  SosRequest? get preparedRequest => _preparedRequest;
  String? get failureReason => _failureReason;
  double? get latitude => _latitude;
  double? get longitude => _longitude;
  bool get isRetrying => _retrying;
  bool get requiresSettings => _requiresSettings;
  double get holdProgress => _holdProgress;

  void startHold({required Future<void> Function() onCompleted}) {
    if (_state != SosState.idle) return;
    _holdTimer?.cancel();
    _onHoldCompleted = onCompleted;
    _state = SosState.holding;
    _holdProgress = 0;
    notifyListeners();

    final totalMilliseconds = holdDuration.inMilliseconds;
    _holdTimer = Timer.periodic(holdTick, (timer) {
      final next = _holdProgress + holdTick.inMilliseconds / totalMilliseconds;
      if (next >= 1) {
        timer.cancel();
        _holdTimer = null;
        _holdProgress = 1;
        notifyListeners();
        final callback = _onHoldCompleted;
        _onHoldCompleted = null;
        if (callback != null) unawaited(callback());
        return;
      }
      _holdProgress = next;
      notifyListeners();
    });
  }

  void releaseHold() {
    if (_state != SosState.holding) return;
    _holdTimer?.cancel();
    _holdTimer = null;
    _onHoldCompleted = null;
    _state = SosState.idle;
    _holdProgress = 0;
    notifyListeners();
  }

  Future<void> send({required bool locationExplanationAccepted}) async {
    if (_state == SosState.sending || _retrying) return;
    if (!locationExplanationAccepted) {
      cancel();
      return;
    }
    final contacts = _contactsController.contacts;
    if (contacts.isEmpty) {
      _fail('Add at least one emergency contact before sending SOS.');
      return;
    }

    _state = SosState.sending;
    _holdProgress = 0;
    _failureReason = null;
    _requiresSettings = false;
    _preparedRequest = SosRequest(
      timestamp: DateTime.now(),
      contacts: contacts,
      requestId: DateTime.now().microsecondsSinceEpoch.toString(),
    );
    notifyListeners();

    final coordinates = await _prepareLocation();
    if (coordinates == null) {
      _state = SosState.failed;
      notifyListeners();
      return;
    }
    _setPreparedLocation(coordinates);
    await _sendPreparedRequest();
  }

  Future<void> retry() async {
    final request = _preparedRequest;
    if (request == null || _retrying) return;
    if (request.latitude != null && request.longitude != null) {
      await _sendPreparedRequest();
      return;
    }

    _retrying = true;
    _state = SosState.sending;
    _failureReason = null;
    _requiresSettings = false;
    notifyListeners();
    final coordinates = await _prepareLocation();
    _retrying = false;
    if (coordinates == null) {
      _state = SosState.failed;
      notifyListeners();
      return;
    }
    _setPreparedLocation(coordinates);
    await _sendPreparedRequest();
  }

  void cancel() {
    _holdTimer?.cancel();
    _holdTimer = null;
    _onHoldCompleted = null;
    _state = SosState.idle;
    _holdProgress = 0;
    _preparedRequest = null;
    _failureReason = null;
    _retrying = false;
    _requiresSettings = false;
    notifyListeners();
  }

  void clearSettingsRequest() {
    if (!_requiresSettings) return;
    _requiresSettings = false;
    notifyListeners();
  }

  Future<LocationCoordinates?> _prepareLocation() async {
    var permission = await _locationPermissionService.check();
    if (permission == LocationPermissionState.denied) {
      permission = await _locationPermissionService.request();
    }
    if (permission == LocationPermissionState.permanentlyDenied) {
      _requiresSettings = true;
      _failureReason =
          'Location permission is disabled. Open Settings to allow SOS location.';
      return null;
    }
    if (permission != LocationPermissionState.granted) {
      _failureReason =
          'Location permission is required to include your position in SOS.';
      return null;
    }

    final result = await _locationRepository.getCurrentCoordinates();
    if (result.isSuccess) return result.coordinates;
    _failureReason = switch (result.failure) {
      LocationFailureType.servicesDisabled =>
        'Location Services are disabled. Enable GPS and try again.',
      LocationFailureType.timeout =>
        'Location request timed out. Check your GPS signal and retry.',
      _ => 'Your current location could not be obtained.',
    };
    return null;
  }

  void _setPreparedLocation(LocationCoordinates coordinates) {
    final request = _preparedRequest!;
    _latitude = coordinates.latitude;
    _longitude = coordinates.longitude;
    _preparedRequest = SosRequest(
      timestamp: request.timestamp,
      latitude: coordinates.latitude,
      longitude: coordinates.longitude,
      contacts: request.contacts,
      userId: request.userId,
      photoPath: request.photoPath,
      requestId: request.requestId,
    );
  }

  Future<void> _sendPreparedRequest() async {
    final request = _preparedRequest;
    if (request == null || _retrying) return;
    _retrying = true;
    _state = SosState.sending;
    notifyListeners();
    try {
      final result = await _emergencyRepository.sendSos(request);
      _state = result.success ? SosState.success : SosState.failed;
      _failureReason = result.success
          ? null
          : result.errorMessage ?? 'SOS could not be sent. Please retry.';
    } catch (_) {
      _state = SosState.failed;
      _failureReason =
          'SOS could not be sent. Check your connection and retry.';
    } finally {
      _retrying = false;
      notifyListeners();
    }
  }

  void _fail(String message) {
    _state = SosState.failed;
    _failureReason = message;
    notifyListeners();
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    super.dispose();
  }
}
