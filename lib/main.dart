import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'theme/app_theme.dart';
import 'theme/theme_provider.dart';
import 'components/toast.dart';
import 'components/biometric_lock_gate.dart';
import 'app_routes.dart';
import 'services/auth_provider.dart';
import 'services/backend_config.dart';
import 'services/glove_state_provider.dart';
import 'services/preferences_provider.dart';
import 'services/translation_controller.dart';
import 'services/smart_home_provider.dart';
import 'services/pairing_controller.dart';
import 'services/alerts_controller.dart';
import 'services/firmware_controller.dart';
import 'services/app_startup_controller.dart';
import 'repositories/backend_repositories.dart';
import 'repositories/firebase_auth_repository.dart';
import 'repositories/development_auth_repository.dart';
import 'firebase_options.dart';

// ─── Screens ───────────────────────────────────────────────────────────────
import 'screens/appearance_screen.dart';
import 'screens/device_pairing_screen.dart';
import 'screens/device_updates_screen.dart';
import 'screens/devices_screen.dart';
import 'screens/edit_profile_screen.dart';
import 'screens/faq_screen.dart';
import 'screens/guide_screen.dart';
import 'screens/health_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/main_shell_screen.dart';
import 'screens/morse_screen.dart';
import 'screens/not_found_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/practice_mode_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/services_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/smart_home_screen.dart';
import 'screens/sos_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/translate_screen.dart';
import 'screens/translation_history_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/analytics_screen.dart';
import 'screens/privacy_security_screen.dart';
import 'screens/help_feedback_screen.dart';

// ------------------------------------
final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

final GlobalKey<NavigatorState> _homeNavigatorKey = GlobalKey<NavigatorState>();

final GlobalKey<NavigatorState> _servicesNavigatorKey =
    GlobalKey<NavigatorState>();

final GlobalKey<NavigatorState> _profileNavigatorKey =
    GlobalKey<NavigatorState>();

GoRouter buildRouter(AuthProvider authProvider) => GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: AppRoutes.splash,
  errorBuilder: (context, state) => const NotFoundScreen(),
  // ── Auth redirect ─────────────────────────────────────────────────────────
  redirect: (context, state) {
    final loggedIn = authProvider.isLoggedIn;
    final authRoutes = {
      AppRoutes.login,
      AppRoutes.signup,
      AppRoutes.splash,
      AppRoutes.onboarding,
      AppRoutes.forgotPassword,
    };
    final isAuthRoute = authRoutes.contains(state.matchedLocation);

    // Not logged in and trying to access a protected route → send to login
    if (!loggedIn && !isAuthRoute) return AppRoutes.login;

    // Logged in and still on an auth route → send to home
    if (loggedIn && isAuthRoute && state.matchedLocation != AppRoutes.splash) {
      return AppRoutes.home;
    }

    return null; // no redirect
  },
  routes: [
    // ═══════════════════════════════════════════════════════════════
    // 1. FULL SCREEN ROUTES (No Bottom Nav)
    // ═══════════════════════════════════════════════════════════════
    GoRoute(
      path: AppRoutes.splash,
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: AppRoutes.onboarding,
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: AppRoutes.login,
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: AppRoutes.signup,
      builder: (context, state) => const SignupScreen(),
    ),
    GoRoute(
      path: AppRoutes.forgotPassword,
      builder: (context, state) => const ForgotPasswordScreen(),
    ),
    GoRoute(
      path: AppRoutes.homeTranslateLegacy,
      redirect: (context, state) => AppRoutes.servicesTranslate,
    ),

    // ═══════════════════════════════════════════════════════════════
    // 2. MAIN APP SHELL (3 Tabs - Bottom Nav is Visible)
    // ═══════════════════════════════════════════════════════════════
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return MainShellScreen(navigationShell: navigationShell);
      },
      branches: [
        // ─── TAB 1: HOME BRANCH ───
        StatefulShellBranch(
          navigatorKey: _homeNavigatorKey,
          routes: [
            GoRoute(
              path: AppRoutes.home,
              builder: (context, state) => const HomeScreen(),
            ),
          ],
        ),

        // ─── TAB 2: SERVICES BRANCH ───
        StatefulShellBranch(
          navigatorKey: _servicesNavigatorKey,
          routes: [
            GoRoute(
              path: AppRoutes.services,
              builder: (context, state) => const ServicesScreen(),
              routes: [
                GoRoute(
                  path: 'translate',
                  builder: (context, state) => const TranslateScreen(),
                  routes: [
                    GoRoute(
                      path: 'history',
                      builder: (context, state) =>
                          const TranslationHistoryScreen(),
                    ),
                  ],
                ),
                GoRoute(
                  path: 'analytics',
                  builder: (context, state) => const AnalyticsScreen(),
                ),
                GoRoute(
                  path: 'sos',
                  builder: (context, state) => const SOSScreen(),
                ),
                GoRoute(
                  path: 'smart-home',
                  builder: (context, state) => const SmartHomeScreen(),
                ),
                GoRoute(
                  path: 'morse',
                  builder: (context, state) => const MorseScreen(),
                ), // hidden but accessible
                GoRoute(
                  path: 'guide',
                  builder: (context, state) => const GuideScreen(),
                ),
                GoRoute(
                  path: 'health',
                  builder: (context, state) => const HealthScreen(),
                ),
                GoRoute(
                  path: 'practice',
                  builder: (context, state) => const PracticeModeScreen(),
                ),
              ],
            ),
          ],
        ),

        // ─── TAB 3: PROFILE BRANCH ───
        StatefulShellBranch(
          navigatorKey: _profileNavigatorKey,
          routes: [
            GoRoute(
              path: AppRoutes.profile,
              builder: (context, state) => const ProfileScreen(),
              routes: [
                GoRoute(
                  path: 'edit',
                  builder: (context, state) => const EditProfileScreen(),
                ),
                GoRoute(
                  path: 'appearance',
                  builder: (context, state) => const AppearanceScreen(),
                ),
                GoRoute(
                  path: 'faq',
                  builder: (context, state) => const FaqScreen(),
                ),
                GoRoute(
                  path: 'privacy-security',
                  builder: (context, state) => const PrivacySecurityScreen(),
                ),
                GoRoute(
                  path: 'help-feedback',
                  builder: (context, state) => const HelpFeedbackScreen(),
                ),
                GoRoute(
                  path: 'devices',
                  builder: (context, state) => const DevicesScreen(),
                  routes: [
                    GoRoute(
                      path: 'pairing',
                      builder: (context, state) => const DevicePairingScreen(),
                      routes: [
                        GoRoute(
                          path: 'updates',
                          redirect: (context, state) =>
                              AppRoutes.profileDeviceUpdates,
                        ),
                      ],
                    ),
                    // Legacy alias so old pushes to /profile/devices/updates still work
                    GoRoute(
                      path: 'updates',
                      builder: (context, state) => const DeviceUpdatesScreen(),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ],
);

// ─── Entry Point ───────────────────────────────────────────────────────────
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (error, stackTrace) {
    // Never let a Firebase init failure block the whole app from launching.
    // The API client guards on `Firebase.apps.isEmpty` and the dev-bypass
    // session still works, so the shell must still come up.
    debugPrint('Firebase initialization failed: $error\n$stackTrace');
  }
  // Resolve the backend's actual LAN IP before any API client is created.
  // Falls back silently to the compile-time default if the backend is unreachable.
  await BackendConfig.instance.discover();

  final gloveRepository = BackendGloveRepository();
  final themeProvider = await _loadOrDefault(
    'theme',
    ThemeProvider.load,
    ThemeProvider.new,
  );
  final authProvider = await _loadOrDefault(
    'auth',
    () => AuthProvider.load(
      repository: DevelopmentAuthRepository(FirebaseAuthRepository()),
    ),
    AuthProvider.new,
  );
  final gloveProvider = await _loadOrDefault(
    'glove',
    () => GloveStateProvider.load(repository: gloveRepository),
    GloveStateProvider.new,
  );
  final prefProvider = await _loadOrDefault(
    'preferences',
    PreferencesProvider.load,
    PreferencesProvider.new,
  );
  final translationController = TranslationController(
    repository: BackendTranslationRepository(),
  );
  final smartHomeProvider = SmartHomeProvider(
    repository: BackendSmartHomeRepository(),
  );
  final pairingController = PairingController(
    repository: gloveRepository,
    gloveState: gloveProvider,
  );
  final alertsController = AlertsController(
    repository: BackendAlertsRepository(),
  );
  final firmwareController = FirmwareController(
    repository: BackendFirmwareRepository(),
  );
  if (authProvider.isLoggedIn) {
    pairingController.startMonitoring();
    // Fire-and-forget: these populate provider state in the background and each
    // controller has its own loading/error handling. Awaiting them here would
    // block first paint on the network and could stall startup when the backend
    // is unreachable — the app shell must always come up.
    unawaited(smartHomeProvider.load());
    unawaited(alertsController.load());
    unawaited(firmwareController.check());
  }
  final startupController = AppStartupController(authProvider: authProvider);

  runApp(
    MyApp(
      themeProvider: themeProvider,
      authProvider: authProvider,
      gloveProvider: gloveProvider,
      prefProvider: prefProvider,
      translationController: translationController,
      smartHomeProvider: smartHomeProvider,
      pairingController: pairingController,
      alertsController: alertsController,
      firmwareController: firmwareController,
      startupController: startupController,
    ),
  );
}

Future<T> _loadOrDefault<T>(
  String name,
  Future<T> Function() load,
  T Function() fallback,
) async {
  try {
    return await load();
  } catch (error, stackTrace) {
    debugPrint('Failed to load $name state: $error\n$stackTrace');
    return fallback();
  }
}

// ─── Root App ──────────────────────────────────────────────────────────────
class MyApp extends StatefulWidget {
  final ThemeProvider themeProvider;
  final AuthProvider authProvider;
  final GloveStateProvider gloveProvider;
  final PreferencesProvider prefProvider;
  final TranslationController translationController;
  final SmartHomeProvider smartHomeProvider;
  final PairingController pairingController;
  final AlertsController alertsController;
  final FirmwareController firmwareController;
  final AppStartupController startupController;

  const MyApp({
    super.key,
    required this.themeProvider,
    required this.authProvider,
    required this.gloveProvider,
    required this.prefProvider,
    required this.translationController,
    required this.smartHomeProvider,
    required this.pairingController,
    required this.alertsController,
    required this.firmwareController,
    required this.startupController,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final GoRouter _router;
  bool _lastLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _router = buildRouter(widget.authProvider);
    _lastLoggedIn = widget.authProvider.isLoggedIn;

    // Rebuild router when auth state changes (handles redirects after login/logout).
    widget.authProvider.addListener(_router.refresh);
    widget.authProvider.addListener(_handleAuthState);
  }

  void _handleAuthState() {
    final loggedIn = widget.authProvider.isLoggedIn;
    if (loggedIn && !_lastLoggedIn) {
      widget.pairingController.startMonitoring();
      widget.smartHomeProvider.load();
      widget.alertsController.refresh();
      widget.firmwareController.check();
      widget.pairingController.loadPairedDevice();
    } else if (!loggedIn && _lastLoggedIn) {
      widget.pairingController.stopMonitoring();
    }
    _lastLoggedIn = loggedIn;
  }

  @override
  void dispose() {
    widget.authProvider.removeListener(_router.refresh);
    widget.authProvider.removeListener(_handleAuthState);
    _router.dispose();
    // MyApp owns the objects created in main(); scopes only expose them.
    widget.pairingController.dispose();
    widget.alertsController.dispose();
    widget.firmwareController.dispose();
    widget.startupController.dispose();
    widget.translationController.dispose();
    widget.smartHomeProvider.dispose();
    widget.prefProvider.dispose();
    widget.gloveProvider.dispose();
    widget.authProvider.dispose();
    widget.themeProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ThemeProviderScope(
      notifier: widget.themeProvider,
      child: AuthProviderScope(
        notifier: widget.authProvider,
        child: GloveStateScope(
          notifier: widget.gloveProvider,
          child: PreferencesScope(
            notifier: widget.prefProvider,
            child: TranslationControllerScope(
              notifier: widget.translationController,
              child: AppStartupScope(
                notifier: widget.startupController,
                child: PairingControllerScope(
                  notifier: widget.pairingController,
                  child: SmartHomeScope(
                    notifier: widget.smartHomeProvider,
                    child: AlertsScope(
                      notifier: widget.alertsController,
                      child: FirmwareScope(
                        notifier: widget.firmwareController,
                        child: AnimatedBuilder(
                          animation: widget.themeProvider,
                          builder: (context, _) {
                            return MaterialApp.router(
                              title: 'IntelliGlove',
                              debugShowCheckedModeBanner: false,
                              theme: AppTheme.light,
                              darkTheme: AppTheme.dark,
                              themeMode: widget.themeProvider.themeMode,
                              routerConfig: _router,
                              // ── Toast overlay at root ──────────────────────────────────
                              builder: (context, child) {
                                final path = _router
                                    .routerDelegate
                                    .currentConfiguration
                                    .uri
                                    .path;
                                final hasBottomNavigation =
                                    path.startsWith(AppRoutes.home) ||
                                    path.startsWith(AppRoutes.services) ||
                                    path.startsWith(AppRoutes.profile);
                                return BiometricLockGate(
                                  child: Stack(
                                    children: [
                                      child!,
                                      AppToaster(
                                        hasBottomNavigation:
                                            hasBottomNavigation,
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
