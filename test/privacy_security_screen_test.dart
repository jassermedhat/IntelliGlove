import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intelliglove/screens/privacy_security_screen.dart';
import 'package:intelliglove/services/location_services.dart';
import 'package:intelliglove/theme/theme_provider.dart';

void main() {
  testWidgets('requests denied location permission through the service', (
    tester,
  ) async {
    final service = _PermissionService(
      checkedState: LocationPermissionState.denied,
      requestedState: LocationPermissionState.granted,
    );

    await _pumpScreen(tester, service);
    expect(find.text('Not Granted'), findsOneWidget);

    await tester.tap(find.text('Grant Access'));
    await tester.pump();

    expect(service.requestCount, 1);
    expect(find.text('Allowed'), findsOneWidget);
  });

  testWidgets('opens settings for permanently denied location permission', (
    tester,
  ) async {
    final service = _PermissionService(
      checkedState: LocationPermissionState.permanentlyDenied,
    );

    await _pumpScreen(tester, service);
    await tester.tap(find.text('Open Settings'));
    await tester.pump();

    expect(service.settingsCount, 1);
    expect(service.requestCount, 0);
  });
}

Future<void> _pumpScreen(
  WidgetTester tester,
  LocationPermissionService service,
) async {
  await tester.pumpWidget(
    ThemeProviderScope(
      notifier: ThemeProvider(),
      child: MaterialApp(
        home: PrivacySecurityScreen(locationPermissionService: service),
      ),
    ),
  );
  await tester.pump();
}

class _PermissionService implements LocationPermissionService {
  _PermissionService({
    required this.checkedState,
    this.requestedState = LocationPermissionState.denied,
  });

  final LocationPermissionState checkedState;
  final LocationPermissionState requestedState;
  int requestCount = 0;
  int settingsCount = 0;

  @override
  Future<LocationPermissionState> check() async => checkedState;

  @override
  Future<bool> openSettings() async {
    settingsCount++;
    return true;
  }

  @override
  Future<LocationPermissionState> request() async {
    requestCount++;
    return requestedState;
  }
}
