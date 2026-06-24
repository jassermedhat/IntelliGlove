import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

enum LocationPermissionState { granted, denied, permanentlyDenied, restricted }

abstract class LocationPermissionService {
  Future<LocationPermissionState> check();
  Future<LocationPermissionState> request();
  Future<bool> openSettings();
}

class DeviceLocationPermissionService implements LocationPermissionService {
  @override
  Future<LocationPermissionState> check() async {
    return _map(await Permission.locationWhenInUse.status);
  }

  @override
  Future<LocationPermissionState> request() async {
    return _map(await Permission.locationWhenInUse.request());
  }

  @override
  Future<bool> openSettings() => openAppSettings();

  LocationPermissionState _map(PermissionStatus status) {
    if (status.isGranted || status.isLimited) {
      return LocationPermissionState.granted;
    }
    if (status.isPermanentlyDenied) {
      return LocationPermissionState.permanentlyDenied;
    }
    if (status.isRestricted) return LocationPermissionState.restricted;
    return LocationPermissionState.denied;
  }
}

enum LocationFailureType { servicesDisabled, timeout, unavailable }

class LocationCoordinates {
  const LocationCoordinates({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}

class LocationResult {
  const LocationResult.success(this.coordinates) : failure = null;
  const LocationResult.failure(this.failure) : coordinates = null;

  final LocationCoordinates? coordinates;
  final LocationFailureType? failure;
  bool get isSuccess => coordinates != null;
}

abstract class LocationRepository {
  Future<LocationResult> getCurrentCoordinates();
}

class DeviceLocationRepository implements LocationRepository {
  const DeviceLocationRepository({this.timeout = const Duration(seconds: 10)});

  final Duration timeout;

  @override
  Future<LocationResult> getCurrentCoordinates() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return const LocationResult.failure(LocationFailureType.servicesDisabled);
    }
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: timeout,
        ),
      );
      return LocationResult.success(
        LocationCoordinates(
          latitude: position.latitude,
          longitude: position.longitude,
        ),
      );
    } on TimeoutException {
      return const LocationResult.failure(LocationFailureType.timeout);
    } catch (_) {
      return const LocationResult.failure(LocationFailureType.unavailable);
    }
  }
}
