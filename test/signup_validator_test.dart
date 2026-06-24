import 'package:flutter_test/flutter_test.dart';
import 'package:intelliglove/services/signup_validator.dart';

void main() {
  test('signup validation rejects missing and malformed fields', () {
    expect(
      validateSignup(
        name: '',
        email: 'user@example.com',
        password: 'strongpass',
        confirmPassword: 'strongpass',
      )?.title,
      'Missing information',
    );
    expect(
      validateSignup(
        name: 'User',
        email: 'not-an-email',
        password: 'strongpass',
        confirmPassword: 'strongpass',
      )?.title,
      'Invalid email',
    );
    expect(
      validateSignup(
        name: 'User',
        email: 'user@example.com',
        password: 'short',
        confirmPassword: 'short',
      )?.title,
      'Weak password',
    );
  });

  test(
    'signup validation rejects mismatched confirmation and accepts valid input',
    () {
      expect(
        validateSignup(
          name: 'User',
          email: 'user@example.com',
          password: 'strongpass',
          confirmPassword: 'different',
        )?.title,
        'Passwords do not match',
      );
      expect(
        validateSignup(
          name: 'User',
          email: 'user@example.com',
          password: 'strongpass',
          confirmPassword: 'strongpass',
        ),
        isNull,
      );
    },
  );
}
