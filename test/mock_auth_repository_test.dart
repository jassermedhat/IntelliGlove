import 'package:flutter_test/flutter_test.dart';
import 'package:intelliglove/repositories/auth_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('supports successful and invalid login', () async {
    final success = await MockAuthRepository(
      delay: Duration.zero,
    ).login('user@example.com', 'secret');
    expect(success.success, isTrue);
    expect(success.session?.accessToken, isNotEmpty);

    final invalid = await MockAuthRepository(
      loginOutcome: MockAuthOutcome.invalidCredentials,
      delay: Duration.zero,
    ).login('user@example.com', 'wrong');
    expect(invalid.success, isFalse);
  });

  test('supports network, timeout, and registration failures', () async {
    expect(
      () => MockAuthRepository(
        loginOutcome: MockAuthOutcome.networkFailure,
        delay: Duration.zero,
      ).login('user@example.com', 'secret'),
      throwsA(isA<MockAuthException>()),
    );
    expect(
      () => MockAuthRepository(
        loginOutcome: MockAuthOutcome.timeoutFailure,
        delay: Duration.zero,
      ).login('user@example.com', 'secret'),
      throwsA(isA<Exception>()),
    );
    final registration = await MockAuthRepository(
      registrationOutcome: MockAuthOutcome.registrationFailure,
      delay: Duration.zero,
    ).register('User', 'user@example.com', 'secret');
    expect(registration.success, isFalse);
  });

  test(
    'restores valid, expired, malformed, and missing sessions safely',
    () async {
      final valid = await MockAuthRepository(
        restoredSession: MockRestoredSession.valid,
      ).restoreSession();
      expect(valid, isNotNull);
      expect(valid!.isExpired, isFalse);

      expect(
        await MockAuthRepository(
          restoredSession: MockRestoredSession.expired,
        ).restoreSession(),
        isNull,
      );
      expect(
        await MockAuthRepository(
          restoredSession: MockRestoredSession.malformed,
        ).restoreSession(),
        isNull,
      );
      expect(
        await MockAuthRepository(
          restoredSession: MockRestoredSession.missing,
        ).restoreSession(),
        isNull,
      );
    },
  );

  test('stored session excludes tokens and rejects expired data', () async {
    final repository = MockAuthRepository(delay: Duration.zero);
    await repository.login('user@example.com', 'secret');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys().any((key) => key.contains('token')), isFalse);
    expect(await repository.restoreSession(), isNotNull);

    SharedPreferences.setMockInitialValues({
      'auth-is-logged-in': true,
      'auth-user-id': 'id',
      'auth-user-name': 'User',
      'auth-user-email': 'user@example.com',
      'auth-session-expiry': DateTime(2020).toIso8601String(),
    });
    expect(await repository.restoreSession(), isNull);
  });
}
