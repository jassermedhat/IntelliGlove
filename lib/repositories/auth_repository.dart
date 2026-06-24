// lib/repositories/auth_repository.dart
// Authentication repository and configurable local implementation.

import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

// ─────────────────────────────────────────────────────────────────────────────
//  Data types
// ─────────────────────────────────────────────────────────────────────────────

class AuthSession {
  final String userId;
  final String displayName;
  final String email;
  final String? accessToken;
  final String? refreshToken;
  final DateTime? expiresAt;

  const AuthSession({
    required this.userId,
    required this.displayName,
    required this.email,
    this.accessToken,
    this.refreshToken,
    this.expiresAt,
  });

  bool get isExpired =>
      expiresAt != null && !expiresAt!.isAfter(DateTime.now().toUtc());
}

class AuthResult {
  final bool success;
  final AuthSession? session;
  final String? errorMessage;

  const AuthResult({required this.success, this.session, this.errorMessage});
  const AuthResult.failure(String message)
    : success = false,
      session = null,
      errorMessage = message;
}

// ─────────────────────────────────────────────────────────────────────────────
//  Abstract interface
// ─────────────────────────────────────────────────────────────────────────────

abstract class AuthRepository {
  Future<AuthResult> login(String email, String password);
  Future<AuthResult> register(String name, String email, String password);
  Future<AuthResult> loginWithGoogle();
  Future<void> sendPasswordReset(String email);
  Future<AuthSession> updateProfile({required String name, String? email});
  Future<void> logout();
  Future<AuthSession?> restoreSession();
}

// ─────────────────────────────────────────────────────────────────────────────
//  Mock implementation
// ─────────────────────────────────────────────────────────────────────────────

const _kIsLoggedIn = 'auth-is-logged-in';
const _kUserId = 'auth-user-id';
const _kUserName = 'auth-user-name';
const _kUserEmail = 'auth-user-email';
const _kSessionExpiry = 'auth-session-expiry';

enum MockAuthOutcome {
  success,
  invalidCredentials,
  networkFailure,
  timeoutFailure,
  registrationFailure,
}

enum MockRestoredSession { stored, valid, expired, malformed, missing, failure }

class MockAuthRepository implements AuthRepository {
  MockAuthRepository({
    this.loginOutcome = MockAuthOutcome.success,
    this.registrationOutcome = MockAuthOutcome.success,
    this.restoredSession = MockRestoredSession.stored,
    this.delay = const Duration(milliseconds: 100),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final MockAuthOutcome loginOutcome;
  final MockAuthOutcome registrationOutcome;
  final MockRestoredSession restoredSession;
  final Duration delay;
  final DateTime Function() _now;

  @override
  Future<AuthResult> login(String email, String password) async {
    await Future<void>.delayed(delay);
    final failure = _failureFor(loginOutcome, registration: false);
    if (failure != null) return failure;
    final session = AuthSession(
      userId: 'mock-uid-${email.hashCode}',
      displayName: email.split('@').first,
      email: email,
      accessToken: 'mock-access-token',
      refreshToken: 'mock-refresh-token',
      expiresAt: _now().toUtc().add(const Duration(hours: 1)),
    );
    await _persist(session);
    return AuthResult(success: true, session: session);
  }

  @override
  Future<AuthResult> register(
    String name,
    String email,
    String password,
  ) async {
    await Future<void>.delayed(delay);
    final failure = _failureFor(registrationOutcome, registration: true);
    if (failure != null) return failure;
    final session = AuthSession(
      userId: 'mock-uid-${email.hashCode}',
      displayName: name,
      email: email,
      accessToken: 'mock-access-token',
      refreshToken: 'mock-refresh-token',
      expiresAt: _now().toUtc().add(const Duration(hours: 1)),
    );
    await _persist(session);
    return AuthResult(success: true, session: session);
  }

  @override
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kIsLoggedIn);
    await prefs.remove(_kUserId);
    await prefs.remove(_kUserName);
    await prefs.remove(_kUserEmail);
    await prefs.remove(_kSessionExpiry);
  }

  @override
  Future<AuthResult> loginWithGoogle() => login(
    'google@example.com',
    'mock-google-password',
  );

  @override
  Future<void> sendPasswordReset(String email) async {
    if (!email.contains('@')) throw const MockAuthException('Invalid email');
  }

  @override
  Future<AuthSession> updateProfile({required String name, String? email}) async {
    final restored = await restoreSession();
    if (restored == null) throw const MockAuthException('No session');
    final updated = AuthSession(
      userId: restored.userId,
      displayName: name,
      email: email ?? restored.email,
      accessToken: restored.accessToken,
      refreshToken: restored.refreshToken,
      expiresAt: restored.expiresAt,
    );
    await _persist(updated);
    return updated;
  }

  @override
  Future<AuthSession?> restoreSession() async {
    switch (restoredSession) {
      case MockRestoredSession.valid:
        return _configuredSession(expired: false);
      case MockRestoredSession.expired:
        return null;
      case MockRestoredSession.malformed:
      case MockRestoredSession.missing:
        return null;
      case MockRestoredSession.failure:
        throw const MockAuthException('Session restore failed');
      case MockRestoredSession.stored:
        break;
    }
    final prefs = await SharedPreferences.getInstance();
    final loggedIn = prefs.getBool(_kIsLoggedIn) ?? false;
    if (!loggedIn) return null;
    final userId = prefs.getString(_kUserId);
    final displayName = prefs.getString(_kUserName);
    final email = prefs.getString(_kUserEmail);
    final expiryText = prefs.getString(_kSessionExpiry);
    final expiry = expiryText == null ? null : DateTime.tryParse(expiryText);
    if (userId == null ||
        userId.isEmpty ||
        displayName == null ||
        displayName.isEmpty ||
        email == null ||
        !email.contains('@') ||
        expiry == null ||
        !expiry.isAfter(_now().toUtc())) {
      await logout();
      return null;
    }
    return AuthSession(
      userId: userId,
      displayName: displayName,
      email: email,
      accessToken: 'restored-mock-access-token',
      refreshToken: 'restored-mock-refresh-token',
      expiresAt: expiry,
    );
  }

  Future<void> _persist(AuthSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kIsLoggedIn, true);
    await prefs.setString(_kUserId, session.userId);
    await prefs.setString(_kUserName, session.displayName);
    await prefs.setString(_kUserEmail, session.email);
    await prefs.setString(
      _kSessionExpiry,
      session.expiresAt!.toUtc().toIso8601String(),
    );
  }

  AuthResult? _failureFor(
    MockAuthOutcome outcome, {
    required bool registration,
  }) {
    switch (outcome) {
      case MockAuthOutcome.success:
        return null;
      case MockAuthOutcome.invalidCredentials:
        return const AuthResult.failure('Invalid email or password.');
      case MockAuthOutcome.registrationFailure:
        return const AuthResult.failure('Could not create the account.');
      case MockAuthOutcome.networkFailure:
        throw const MockAuthException('Network unavailable');
      case MockAuthOutcome.timeoutFailure:
        throw TimeoutException('Authentication timed out');
    }
  }

  AuthSession _configuredSession({required bool expired}) {
    final now = _now().toUtc();
    return AuthSession(
      userId: 'restored-user',
      displayName: 'Restored User',
      email: 'restored@example.com',
      accessToken: 'restored-mock-access-token',
      refreshToken: 'restored-mock-refresh-token',
      expiresAt: expired
          ? now.subtract(const Duration(minutes: 1))
          : now.add(const Duration(hours: 1)),
    );
  }
}

class MockAuthException implements Exception {
  final String message;
  const MockAuthException(this.message);
}
