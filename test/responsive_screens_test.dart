import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intelliglove/screens/appearance_screen.dart';
import 'package:intelliglove/screens/faq_screen.dart';
import 'package:intelliglove/screens/guide_screen.dart';
import 'package:intelliglove/screens/help_feedback_screen.dart';
import 'package:intelliglove/screens/login_screen.dart';
import 'package:intelliglove/screens/privacy_security_screen.dart';
import 'package:intelliglove/screens/profile_screen.dart';
import 'package:intelliglove/services/auth_provider.dart';
import 'package:intelliglove/services/glove_state_provider.dart';
import 'package:intelliglove/services/location_services.dart';
import 'package:intelliglove/services/preferences_provider.dart';
import 'package:intelliglove/theme/theme_provider.dart';

void main() {
  testWidgets('profile and help screens fit 320px at 2x text scale', (
    tester,
  ) async {
    final screens = <Widget>[
      const ProfileScreen(),
      const AppearanceScreen(),
      const FaqScreen(),
      const GuideScreen(),
      const HelpFeedbackScreen(),
      PrivacySecurityScreen(locationPermissionService: _PermissionService()),
    ];

    for (final screen in screens) {
      await tester.pumpWidget(
        _baseApp(
          screen,
          size: const Size(320, 700),
          textScale: 2,
          bottomInset: 34,
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull, reason: '${screen.runtimeType}');
    }
  });

  testWidgets('login remains usable with compact keyboard viewport', (
    tester,
  ) async {
    await tester.pumpWidget(
      _baseApp(
        const LoginScreen(),
        size: const Size(320, 480),
        textScale: 1.5,
        viewInsets: 220,
      ),
    );
    await tester.pump();
    await tester.tap(find.byType(TextField).first);
    await tester.showKeyboard(find.byType(TextField).first);
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Sign In'), findsWidgets);
  });
}

Widget _baseApp(
  Widget screen, {
  required Size size,
  required double textScale,
  double bottomInset = 0,
  double viewInsets = 0,
}) {
  return ThemeProviderScope(
    notifier: ThemeProvider(),
    child: AuthProviderScope(
      notifier: AuthProvider(),
      child: GloveStateScope(
        notifier: GloveStateProvider(),
        child: PreferencesScope(
          notifier: PreferencesProvider(),
          child: MediaQuery(
            data: MediaQueryData(
              size: size,
              padding: EdgeInsets.only(bottom: bottomInset),
              viewInsets: EdgeInsets.only(bottom: viewInsets),
              textScaler: TextScaler.linear(textScale),
            ),
            child: MaterialApp(home: screen),
          ),
        ),
      ),
    ),
  );
}

class _PermissionService implements LocationPermissionService {
  @override
  Future<LocationPermissionState> check() async =>
      LocationPermissionState.denied;

  @override
  Future<bool> openSettings() async => true;

  @override
  Future<LocationPermissionState> request() async =>
      LocationPermissionState.denied;
}
