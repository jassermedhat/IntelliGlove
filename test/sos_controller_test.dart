import 'package:flutter_test/flutter_test.dart';
import 'package:intelliglove/models/sos_models.dart';
import 'package:intelliglove/repositories/emergency_repository.dart';
import 'package:intelliglove/services/emergency_contacts_controller.dart';
import 'package:intelliglove/services/location_services.dart';
import 'package:intelliglove/services/sos_controller.dart';

void main() {
  test('early hold release returns to idle without sending', () async {
    final fixture = _Fixture();
    var completed = false;
    fixture.sos.startHold(onCompleted: () async => completed = true);
    await Future<void>.delayed(const Duration(milliseconds: 5));
    fixture.sos.releaseHold();
    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(fixture.sos.state, SosState.idle);
    expect(fixture.sos.holdProgress, 0);
    expect(completed, isFalse);
    fixture.dispose();
  });

  test('full hold completes from one timer source', () async {
    final fixture = _Fixture();
    var completions = 0;
    fixture.sos.startHold(onCompleted: () async => completions++);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(completions, 1);
    expect(fixture.sos.holdProgress, 1);
    fixture.dispose();
  });

  test(
    'send succeeds only after prepared location and repository success',
    () async {
      final fixture = _Fixture();
      await fixture.contacts.load();
      await fixture.sos.send(locationExplanationAccepted: true);

      expect(fixture.sos.state, SosState.success);
      expect(fixture.sos.latitude, 30);
      expect(fixture.repository.sendCalls, 1);
      fixture.dispose();
    },
  );

  test('permanently denied location exposes settings action state', () async {
    final fixture = _Fixture(
      permission: LocationPermissionState.permanentlyDenied,
    );
    await fixture.contacts.load();
    await fixture.sos.send(locationExplanationAccepted: true);

    expect(fixture.sos.state, SosState.failed);
    expect(fixture.sos.requiresSettings, isTrue);
    expect(fixture.repository.sendCalls, 0);
    fixture.dispose();
  });

  test('failed send can retry and cancel', () async {
    final fixture = _Fixture(sendSuccess: false);
    await fixture.contacts.load();
    await fixture.sos.send(locationExplanationAccepted: true);
    expect(fixture.sos.state, SosState.failed);

    fixture.repository.sendSuccess = true;
    await fixture.sos.retry();
    expect(fixture.sos.state, SosState.success);
    expect(fixture.repository.sendCalls, 2);

    fixture.sos.cancel();
    expect(fixture.sos.state, SosState.idle);
    expect(fixture.sos.preparedRequest, isNull);
    fixture.dispose();
  });
}

class _Fixture {
  _Fixture({
    LocationPermissionState permission = LocationPermissionState.granted,
    bool sendSuccess = true,
  }) : repository = _EmergencyRepository(sendSuccess: sendSuccess),
       permissionService = _PermissionService(permission) {
    contacts = EmergencyContactsController(repository: repository);
    sos = SosController(
      emergencyRepository: repository,
      locationPermissionService: permissionService,
      locationRepository: _LocationRepository(),
      contactsController: contacts,
      holdDuration: const Duration(milliseconds: 30),
      holdTick: const Duration(milliseconds: 10),
    );
  }

  final _EmergencyRepository repository;
  final _PermissionService permissionService;
  late final EmergencyContactsController contacts;
  late final SosController sos;

  void dispose() {
    sos.dispose();
    contacts.dispose();
  }
}

class _EmergencyRepository implements EmergencyRepository {
  _EmergencyRepository({required this.sendSuccess});

  bool sendSuccess;
  int sendCalls = 0;

  @override
  Future<List<EmergencyContact>> loadContacts() async => const [
    EmergencyContact(id: 1, name: 'Mona', phone: '+20 123'),
  ];

  @override
  Future<void> saveContacts(List<EmergencyContact> contacts) async {}

  @override
  Future<SosResult> sendSos(SosRequest request) async {
    sendCalls++;
    return SosResult(
      success: sendSuccess,
      errorMessage: sendSuccess ? null : 'No network',
    );
  }
}

class _PermissionService implements LocationPermissionService {
  _PermissionService(this.state);

  LocationPermissionState state;

  @override
  Future<LocationPermissionState> check() async => state;

  @override
  Future<bool> openSettings() async => true;

  @override
  Future<LocationPermissionState> request() async => state;
}

class _LocationRepository implements LocationRepository {
  @override
  Future<LocationResult> getCurrentCoordinates() async {
    return const LocationResult.success(
      LocationCoordinates(latitude: 30, longitude: 31),
    );
  }
}
