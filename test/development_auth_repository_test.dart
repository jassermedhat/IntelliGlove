import 'package:flutter_test/flutter_test.dart';
import 'package:intelliglove/repositories/auth_repository.dart';
import 'package:intelliglove/repositories/development_auth_repository.dart';
import 'package:intelliglove/services/backend_api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('accepts testing credentials only when enabled', () {
    expect(
      matchesDevelopmentTestingCredentials('testing', '1234', enabled: true),
      isTrue,
    );
    expect(
      matchesDevelopmentTestingCredentials(' testing ', '1234', enabled: true),
      isTrue,
    );
    expect(
      matchesDevelopmentTestingCredentials('testing', 'wrong', enabled: true),
      isFalse,
    );
    expect(
      matchesDevelopmentTestingCredentials('testing', '1234', enabled: false),
      isFalse,
    );
  });

  test('creates, restores, and clears a local testing session', () async {
    final delegate = _DelegateAuthRepository();
    final repository = DevelopmentAuthRepository(
      delegate,
      enabled: true,
      api: _testingApi(),
    );

    final result = await repository.login('testing', '1234');

    expect(result.success, isTrue);
    expect(result.session?.email, 'testing@intelliglove.local');
    expect(delegate.loginCalls, 0);
    expect((await repository.restoreSession())?.userId, 'testing-user-id');

    await repository.logout();

    expect(await repository.restoreSession(), isNull);
    expect(delegate.logoutCalls, 1);
  });

  test('delegates the testing credentials when bypass is disabled', () async {
    final delegate = _DelegateAuthRepository();
    final repository = DevelopmentAuthRepository(delegate, enabled: false);

    await repository.login('testing', '1234');

    expect(delegate.loginCalls, 1);
  });
}

BackendApiClient _testingApi() {
  return BackendApiClient(
    baseUrl: 'http://testing.local/api/v1',
    tokenProvider: ({forceRefresh = false}) async =>
        'intelliglove-development-user',
    client: MockClient((request) async {
      if (request.url.path.endsWith('/auth/sync')) {
        return http.Response(
          '{"data":{"id":"testing-user-id","name":"Testing User",'
          '"email":"testing@intelliglove.local"}}',
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('{}', 404);
    }),
  );
}

class _DelegateAuthRepository implements AuthRepository {
  int loginCalls = 0;
  int logoutCalls = 0;

  @override
  Future<AuthResult> login(String email, String password) async {
    loginCalls++;
    return const AuthResult.failure('Invalid email or password.');
  }

  @override
  Future<void> logout() async {
    logoutCalls++;
  }

  @override
  Future<AuthResult> loginWithGoogle() async {
    return const AuthResult.failure('Unavailable.');
  }

  @override
  Future<AuthResult> register(
    String name,
    String email,
    String password,
  ) async {
    return const AuthResult.failure('Unavailable.');
  }

  @override
  Future<void> sendPasswordReset(String email) async {}

  @override
  Future<AuthSession> updateProfile({
    required String name,
    String? email,
  }) async {
    return AuthSession(
      userId: 'delegate',
      displayName: name,
      email: email ?? 'user@example.com',
    );
  }

  @override
  Future<AuthSession?> restoreSession() async => null;
}
