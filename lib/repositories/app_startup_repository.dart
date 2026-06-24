import 'package:shared_preferences/shared_preferences.dart';

abstract class AppStartupRepository {
  Future<bool> isOnboardingComplete();
  Future<void> setOnboardingComplete();
}

class LocalAppStartupRepository implements AppStartupRepository {
  static const onboardingKey = 'onboarding-complete';

  @override
  Future<bool> isOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.get(onboardingKey);
    return value is bool ? value : false;
  }

  @override
  Future<void> setOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = await prefs.setBool(onboardingKey, true);
    if (!saved) throw const AppStartupRepositoryException();
  }
}

class AppStartupRepositoryException implements Exception {
  const AppStartupRepositoryException();
}
