import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intelliglove/models/glove_device.dart';
import 'package:intelliglove/components/app_async_state.dart';
import 'package:intelliglove/repositories/glove_repository.dart';
import 'package:intelliglove/screens/device_pairing_screen.dart';
import 'package:intelliglove/screens/sos_screen.dart';
import 'package:intelliglove/screens/translate_screen.dart';
import 'package:intelliglove/services/glove_state_provider.dart';
import 'package:intelliglove/services/pairing_controller.dart';
import 'package:intelliglove/services/preferences_provider.dart';
import 'package:intelliglove/services/translation_controller.dart';
import 'package:intelliglove/theme/theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('pairing screen fits 320px width at 2x text scale', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 700);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _Repository();
    final gloveState = GloveStateProvider();
    final pairing = PairingController(
      repository: repository,
      gloveState: gloveState,
    );
    final router = GoRouter(
      initialLocation: '/pair',
      routes: [
        GoRoute(path: '/pair', builder: (_, __) => const DevicePairingScreen()),
      ],
    );

    await tester.pumpWidget(
      ThemeProviderScope(
        notifier: ThemeProvider(),
        child: GloveStateScope(
          notifier: gloveState,
          child: PairingControllerScope(
            notifier: pairing,
            child: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 700),
                textScaler: TextScaler.linear(2),
              ),
              child: MaterialApp.router(routerConfig: router),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    router.dispose();
    pairing.dispose();
    gloveState.dispose();
  });

  testWidgets('pairing screen fits a landscape tablet', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1024, 600);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _Repository();
    final gloveState = GloveStateProvider();
    final pairing = PairingController(
      repository: repository,
      gloveState: gloveState,
    );
    final router = GoRouter(
      initialLocation: '/pair',
      routes: [
        GoRoute(path: '/pair', builder: (_, __) => const DevicePairingScreen()),
      ],
    );

    await tester.pumpWidget(
      ThemeProviderScope(
        notifier: ThemeProvider(),
        child: GloveStateScope(
          notifier: gloveState,
          child: PairingControllerScope(
            notifier: pairing,
            child: MediaQuery(
              data: const MediaQueryData(
                size: Size(1024, 600),
                textScaler: TextScaler.linear(1.3),
              ),
              child: MaterialApp.router(routerConfig: router),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    router.dispose();
    pairing.dispose();
    gloveState.dispose();
  });

  testWidgets('translation supports Arabic RTL at increased text scale', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final gloveState = GloveStateProvider(
      pairedDevice: const GloveDevice(
        id: 'glove-1',
        name: 'IntelliGlove',
        batteryLevel: 80,
        signalStrength: 4,
      ),
      connectionStatus: GloveConnectionStatus.connected,
    );
    final preferences = PreferencesProvider(signLanguage: kSignLangArsl);
    final translation = TranslationController();
    final router = GoRouter(
      initialLocation: '/translate',
      routes: [
        GoRoute(
          path: '/translate',
          builder: (_, __) => const TranslateScreen(),
        ),
      ],
    );

    await tester.pumpWidget(
      ThemeProviderScope(
        notifier: ThemeProvider(),
        child: GloveStateScope(
          notifier: gloveState,
          child: PreferencesScope(
            notifier: preferences,
            child: TranslationControllerScope(
              notifier: translation,
              child: MediaQuery(
                data: const MediaQueryData(
                  size: Size(360, 800),
                  textScaler: TextScaler.linear(1.5),
                ),
                child: MaterialApp.router(routerConfig: router),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Directionality &&
            widget.textDirection == TextDirection.rtl,
      ),
      findsWidgets,
    );

    await tester.pumpWidget(const SizedBox());
    router.dispose();
    translation.dispose();
    preferences.dispose();
    gloveState.dispose();
  });

  testWidgets('SOS screen fits compact landscape', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(700, 360);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      initialLocation: '/sos',
      routes: [GoRoute(path: '/sos', builder: (_, __) => const SOSScreen())],
    );
    await tester.pumpWidget(
      ThemeProviderScope(
        notifier: ThemeProvider(),
        child: PreferencesScope(
          notifier: PreferencesProvider(),
          child: MediaQuery(
            data: const MediaQueryData(
              size: Size(700, 360),
              textScaler: TextScaler.linear(1.3),
            ),
            child: MaterialApp.router(routerConfig: router),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    router.dispose();
  });

  testWidgets('shared empty state fits compact width at 2.5x text scale', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 480);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ThemeProviderScope(
        notifier: ThemeProvider(),
        child: const MediaQuery(
          data: MediaQueryData(
            size: Size(320, 480),
            textScaler: TextScaler.linear(2.5),
          ),
          child: MaterialApp(
            home: Scaffold(
              body: AppEmptyState(
                title: 'Nothing here yet',
                message: 'Connect or refresh to load available information.',
                actionLabel: 'Refresh content',
                onAction: _noop,
                card: true,
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}

void _noop() {}

class _Repository implements GloveRepository {
  @override
  Future<bool> connect(GloveDevice device) async => true;

  @override
  Future<void> disconnect() async {}

  @override
  GloveConnectionStatus getStatus() => GloveConnectionStatus.disconnected;

  @override
  Future<GloveDevice?> loadPairedDevice() async => null;

  @override
  Future<List<GloveDevice>> scanDevices() async => const [];
}
