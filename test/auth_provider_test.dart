import 'package:flutter_test/flutter_test.dart';
import 'package:intelliglove/models/load_status.dart';
import 'package:intelliglove/repositories/auth_repository.dart';
import 'package:intelliglove/services/auth_provider.dart';

void main() {
  test('restores an authenticated session', () async {
    final provider = await AuthProvider.load(
      repository: _AuthRepository(
        restored: const AuthSession(
          userId: 'user-1',
          displayName: 'Amina',
          email: 'amina@example.com',
        ),
      ),
    );

    expect(provider.sessionRestored, isTrue);
    expect(provider.isLoggedIn, isTrue);
    expect(provider.status, LoadStatus.success);
    provider.dispose();
  });

  test('maps repository exceptions to a safe login error', () async {
    final provider = AuthProvider(repository: _AuthRepository(throws: true));
    await provider.login('a@example.com', 'secret');

    expect(provider.status, LoadStatus.error);
    expect(provider.errorMessage, contains('Unable to sign in'));
    expect(provider.errorMessage, isNot(contains('database')));
    provider.dispose();
  });

  test(
    'registration delegates validated identity data and exposes verification state',
    () async {
      final repository = _AuthRepository();
      final provider = AuthProvider(repository: repository);

      await provider.register('Amina', 'amina@example.com', 'strongpass');

      expect(repository.registered, (
        'Amina',
        'amina@example.com',
        'strongpass',
      ));
      expect(provider.verificationSent, isTrue);
      expect(provider.isLoggedIn, isFalse);
      provider.dispose();
    },
  );

  test(
    'Google sign-in and password reset delegate to the repository',
    () async {
      final repository = _AuthRepository();
      final provider = AuthProvider(repository: repository);

      await provider.loginWithGoogle();
      expect(repository.googleLoginCalled, isTrue);
      expect(provider.isLoggedIn, isTrue);

      expect(await provider.sendPasswordReset('user@example.com'), isTrue);
      expect(repository.resetEmail, 'user@example.com');
      provider.dispose();
    },
  );
}

class _AuthRepository implements AuthRepository {
  _AuthRepository({this.restored, this.throws = false});

  final AuthSession? restored;
  final bool throws;
  (String, String, String)? registered;
  bool googleLoginCalled = false;
  String? resetEmail;

  @override
  Future<AuthResult> login(String email, String password) async {
    if (throws) throw StateError('database exploded');
    return AuthResult(
      success: true,
      session: AuthSession(userId: 'id', displayName: 'User', email: email),
    );
  }

  @override
  Future<void> logout() async {}

  @override
  Future<AuthResult> loginWithGoogle() async {
    googleLoginCalled = true;
    return login('google@example.com', 'secret');
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    resetEmail = email;
  }

  @override
  Future<AuthSession> updateProfile({
    required String name,
    String? email,
  }) async {
    return AuthSession(
      userId: restored?.userId ?? 'id',
      displayName: name,
      email: email ?? restored?.email ?? 'user@example.com',
    );
  }

  @override
  Future<AuthResult> register(
    String name,
    String email,
    String password,
  ) async {
    registered = (name, email, password);
    return const AuthResult(success: true);
  }

  @override
  Future<AuthSession?> restoreSession() async => restored;
}
