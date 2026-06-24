import 'package:flutter/foundation.dart';

import '../services/backend_api_client.dart';
import '../services/development_testing_session.dart';
import 'auth_repository.dart';

bool matchesDevelopmentTestingCredentials(
  String email,
  String password, {
  bool enabled = kDebugMode,
}) {
  return enabled && email.trim() == 'testing' && password == '1234';
}

const _testingSession = AuthSession(
  userId: 'testing-user',
  displayName: 'Testing User',
  email: 'testing',
);

/// Adds a local testing login in debug builds while delegating every normal
/// authentication operation to Firebase.
class DevelopmentAuthRepository implements AuthRepository {
  DevelopmentAuthRepository(
    this._delegate, {
    BackendApiClient? api,
    this.enabled = kDebugMode,
  }) : _api = api ?? BackendApiClient.instance;

  final AuthRepository _delegate;
  final BackendApiClient _api;
  final bool enabled;

  Future<bool> _hasTestingSession() async {
    return DevelopmentTestingSession.isActive(enabled: enabled);
  }

  AuthSession _sessionFromBackend(Object? value) {
    final map = value! as Map<String, dynamic>;
    return AuthSession(
      userId: map['id']! as String,
      displayName: (map['name'] as String?) ?? _testingSession.displayName,
      email: (map['email'] as String?) ?? _testingSession.email,
    );
  }

  Future<AuthSession> _syncTestingProfile() async {
    final data = await _api.post(
      '/auth/sync',
      body: {'name': _testingSession.displayName},
    );
    return _sessionFromBackend(data);
  }

  @override
  Future<AuthResult> login(String email, String password) async {
    if (matchesDevelopmentTestingCredentials(
      email,
      password,
      enabled: enabled,
    )) {
      await DevelopmentTestingSession.setActive(true);
      try {
        return AuthResult(success: true, session: await _syncTestingProfile());
      } on BackendApiException catch (error) {
        await DevelopmentTestingSession.setActive(false);
        return AuthResult.failure(
          'Testing backend sign-in failed: ${error.message}',
        );
      } catch (_) {
        await DevelopmentTestingSession.setActive(false);
        return const AuthResult.failure(
          'Testing backend sign-in failed. Check that the backend is running.',
        );
      }
    }

    final result = await _delegate.login(email, password);
    if (result.success) await DevelopmentTestingSession.setActive(false);
    return result;
  }

  @override
  Future<AuthResult> register(
    String name,
    String email,
    String password,
  ) async {
    final result = await _delegate.register(name, email, password);
    if (result.success) await DevelopmentTestingSession.setActive(false);
    return result;
  }

  @override
  Future<AuthResult> loginWithGoogle() async {
    final result = await _delegate.loginWithGoogle();
    if (result.success) await DevelopmentTestingSession.setActive(false);
    return result;
  }

  @override
  Future<void> sendPasswordReset(String email) {
    return _delegate.sendPasswordReset(email);
  }

  @override
  Future<AuthSession> updateProfile({
    required String name,
    String? email,
  }) async {
    if (await _hasTestingSession()) {
      final data = await _api.patch('/me', body: {'name': name.trim()});
      return _sessionFromBackend(data);
    }
    return _delegate.updateProfile(name: name, email: email);
  }

  @override
  Future<void> logout() async {
    await DevelopmentTestingSession.setActive(false);
    await _delegate.logout();
  }

  @override
  Future<AuthSession?> restoreSession() async {
    if (await _hasTestingSession()) {
      try {
        return await _syncTestingProfile();
      } catch (_) {
        return _testingSession;
      }
    }
    return _delegate.restoreSession();
  }
}
