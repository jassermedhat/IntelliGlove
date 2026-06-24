import 'package:flutter_test/flutter_test.dart';
import 'package:intelliglove/app_routes.dart';
import 'package:intelliglove/repositories/app_startup_repository.dart';
import 'package:intelliglove/repositories/auth_repository.dart';
import 'package:intelliglove/services/app_startup_controller.dart';
import 'package:intelliglove/services/auth_provider.dart';

void main() {
  test('first launch routes to onboarding', () async {
    final controller = AppStartupController(
      authProvider: AuthProvider(),
      repository: _StartupRepository(completed: false),
    );
    expect(await controller.initialize(), AppRoutes.onboarding);
  });

  test('completed onboarding routes unauthenticated user to login', () async {
    final controller = AppStartupController(
      authProvider: AuthProvider(),
      repository: _StartupRepository(completed: true),
    );
    expect(await controller.initialize(), AppRoutes.login);
  });

  test('restored authenticated session routes to home', () async {
    final auth = AuthProvider(
      session: AuthSession(
        userId: '1',
        displayName: 'User',
        email: 'user@example.com',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      ),
    );
    final controller = AppStartupController(
      authProvider: auth,
      repository: _StartupRepository(completed: true),
    );
    expect(await controller.initialize(), AppRoutes.home);
  });

  test(
    'corrupt data is treated as first launch and failures are safe',
    () async {
      final corrupt = AppStartupController(
        authProvider: AuthProvider(),
        repository: _StartupRepository(completed: false),
      );
      expect(await corrupt.initialize(), AppRoutes.onboarding);

      final failing = AppStartupController(
        authProvider: AuthProvider(),
        repository: _StartupRepository(completed: false, fail: true),
      );
      expect(await failing.initialize(), AppRoutes.onboarding);
      expect(failing.status, AppStartupStatus.error);
    },
  );
}

class _StartupRepository implements AppStartupRepository {
  _StartupRepository({required this.completed, this.fail = false});

  final bool completed;
  final bool fail;

  @override
  Future<bool> isOnboardingComplete() async {
    if (fail) throw const AppStartupRepositoryException();
    return completed;
  }

  @override
  Future<void> setOnboardingComplete() async {
    if (fail) throw const AppStartupRepositoryException();
  }
}
