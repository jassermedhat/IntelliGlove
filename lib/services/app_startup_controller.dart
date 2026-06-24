import 'package:flutter/widgets.dart';

import '../app_routes.dart';
import '../repositories/app_startup_repository.dart';
import 'auth_provider.dart';

enum AppStartupStatus { initial, loading, ready, error }

class AppStartupController extends ChangeNotifier {
  AppStartupController({
    required AuthProvider authProvider,
    AppStartupRepository? repository,
  }) : _authProvider = authProvider,
       _repository = repository ?? LocalAppStartupRepository();

  final AuthProvider _authProvider;
  final AppStartupRepository _repository;
  AppStartupStatus _status = AppStartupStatus.initial;
  bool _onboardingComplete = false;
  String? _destination;
  String? _error;

  AppStartupStatus get status => _status;
  bool get isFirstLaunch => !_onboardingComplete;
  bool get onboardingComplete => _onboardingComplete;
  String? get destination => _destination;
  String? get error => _error;

  Future<String> initialize() async {
    _status = AppStartupStatus.loading;
    _error = null;
    notifyListeners();
    try {
      _onboardingComplete = await _repository.isOnboardingComplete();
      _destination = _authProvider.isLoggedIn
          ? AppRoutes.home
          : _onboardingComplete
          ? AppRoutes.login
          : AppRoutes.onboarding;
      _status = AppStartupStatus.ready;
    } catch (_) {
      _onboardingComplete = false;
      _destination = AppRoutes.onboarding;
      _status = AppStartupStatus.error;
      _error = 'Startup preferences could not be restored.';
    }
    notifyListeners();
    return _destination!;
  }

  Future<bool> completeOnboarding() async {
    try {
      await _repository.setOnboardingComplete();
      _onboardingComplete = true;
      _destination = AppRoutes.login;
      _status = AppStartupStatus.ready;
      notifyListeners();
      return true;
    } catch (_) {
      _status = AppStartupStatus.error;
      _error = 'Could not save onboarding progress.';
      notifyListeners();
      return false;
    }
  }
}

class AppStartupScope extends InheritedNotifier<AppStartupController> {
  const AppStartupScope({
    super.key,
    required AppStartupController super.notifier,
    required super.child,
  });

  static AppStartupController of(BuildContext context) {
    final controller = context
        .dependOnInheritedWidgetOfExactType<AppStartupScope>()
        ?.notifier;
    if (controller == null) {
      throw FlutterError(
        'AppStartupScope.of() called without an AppStartupScope.',
      );
    }
    return controller;
  }
}
