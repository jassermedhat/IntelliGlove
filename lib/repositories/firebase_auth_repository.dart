import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../services/backend_api_client.dart';
import 'auth_repository.dart';

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({
    FirebaseAuth? auth,
    BackendApiClient? api,
    GoogleSignIn? googleSignIn,
  }) : _providedAuth = auth,
       _api = api ?? BackendApiClient.instance,
       _google = googleSignIn ?? GoogleSignIn.instance;

  final FirebaseAuth? _providedAuth;
  FirebaseAuth get _auth => _providedAuth ?? FirebaseAuth.instance;
  final BackendApiClient _api;
  final GoogleSignIn _google;
  bool _googleInitialized = false;

  @override
  Future<AuthResult> login(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) return const AuthResult.failure('Unable to sign in.');
      await user.reload();
      final refreshed = _auth.currentUser;
      if (refreshed == null || !refreshed.emailVerified) {
        await refreshed?.sendEmailVerification();
        await _auth.signOut();
        return const AuthResult.failure(
          'Verify your email address before signing in. A new verification email was sent.',
        );
      }
      return AuthResult(success: true, session: await _sync(refreshed));
    } on FirebaseAuthException catch (error) {
      return AuthResult.failure(_message(error));
    } on BackendApiException catch (error) {
      return AuthResult.failure(error.message);
    }
  }

  @override
  Future<AuthResult> register(
    String name,
    String email,
    String password,
  ) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        return const AuthResult.failure('Could not create the account.');
      }
      await user.updateDisplayName(name.trim());
      await user.sendEmailVerification();
      await _api.post('/auth/sync', body: {'name': name.trim()});
      await _auth.signOut();
      return const AuthResult(success: true);
    } on FirebaseAuthException catch (error) {
      return AuthResult.failure(_message(error));
    } on BackendApiException catch (error) {
      return AuthResult.failure(error.message);
    }
  }

  @override
  Future<AuthResult> loginWithGoogle() async {
    try {
      final UserCredential credential;
      if (kIsWeb) {
        credential = await _auth.signInWithPopup(GoogleAuthProvider());
      } else {
        if (!_googleInitialized) {
          await _google.initialize();
          _googleInitialized = true;
        }
        final account = await _google.authenticate();
        final authentication = account.authentication;
        credential = await _auth.signInWithCredential(
          GoogleAuthProvider.credential(idToken: authentication.idToken),
        );
      }
      final user = credential.user;
      if (user == null || !user.emailVerified) {
        await _auth.signOut();
        return const AuthResult.failure(
          'Google did not provide a verified email address.',
        );
      }
      return AuthResult(success: true, session: await _sync(user));
    } on FirebaseAuthException catch (error) {
      return AuthResult.failure(_message(error));
    } catch (_) {
      return const AuthResult.failure('Google sign-in could not be completed.');
    }
  }

  @override
  Future<void> sendPasswordReset(String email) {
    return _auth.sendPasswordResetEmail(email: email.trim());
  }

  @override
  Future<AuthSession> updateProfile({
    required String name,
    String? email,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Authentication is required.');
    final body = <String, Object?>{'name': name.trim()};
    if (email != null && email.trim().toLowerCase() != user.email?.toLowerCase()) {
      body['email'] = email.trim().toLowerCase();
    }
    final data = await _api.patch('/me', body: body);
    await user.updateDisplayName(name.trim());
    await user.reload();
    final map = data! as Map<String, dynamic>;
    if (map['verificationRequired'] == true) {
      await _auth.currentUser?.sendEmailVerification();
    }
    return _sessionFromMap(map);
  }

  @override
  Future<void> logout() async {
    await _auth.signOut();
    if (_googleInitialized) await _google.signOut();
  }

  @override
  Future<AuthSession?> restoreSession() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    await user.reload();
    final refreshed = _auth.currentUser;
    if (refreshed == null || !refreshed.emailVerified) return null;
    try {
      return await _sync(refreshed);
    } on BackendApiException {
      return null;
    }
  }

  Future<AuthSession> _sync(User user) async {
    final data = await _api.post('/auth/sync', body: {
      if (user.displayName != null) 'name': user.displayName,
      if (user.photoURL != null) 'photoUrl': user.photoURL,
    });
    return _sessionFromMap(data! as Map<String, dynamic>);
  }

  AuthSession _sessionFromMap(Map<String, dynamic> map) {
    return AuthSession(
      userId: map['id']! as String,
      displayName: (map['name'] as String?) ?? 'User',
      email: (map['email'] as String?) ?? '',
    );
  }

  String _message(FirebaseAuthException error) {
    return switch (error.code) {
      'weak-password' => 'Use a stronger password with at least 8 characters.',
      'email-already-in-use' => 'An account already uses this email address.',
      'invalid-email' => 'Enter a valid email address.',
      'too-many-requests' => 'Too many attempts. Please try again later.',
      _ => 'Invalid email or password.',
    };
  }
}
