import 'package:flutter/material.dart';

import '../repositories/auth_repository.dart';
import '../repositories/firebase_auth_repository.dart';
import '../models/load_status.dart';
import 'biometric_service.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider({
    AuthRepository? repository,
    AuthSession? session,
    bool isRestoring = false,
  }) : _repository = repository ?? FirebaseAuthRepository(),
       _session = session,
       _isRestoring = isRestoring;

  final AuthRepository _repository;
  AuthSession? _session;
  bool _isRestoring;
  String? _errorMessage;
  LoadStatus _status = LoadStatus.initial;
  bool _sessionRestored = false;
  bool _unauthorized = false;
  bool _verificationSent = false;

  bool get isLoggedIn => _session != null;
  bool get isRestoring => _isRestoring;
  bool get isSubmitting => _status == LoadStatus.loading;
  LoadStatus get status => _status;
  bool get sessionRestored => _sessionRestored;
  bool get unauthorized => _unauthorized;
  bool get verificationSent => _verificationSent;
  String get userName =>
      _session?.displayName.isNotEmpty == true ? _session!.displayName : 'User';
  String get userEmail => _session?.email ?? '';
  String? get errorMessage => _errorMessage;

  Future<void> login(String email, String password) async {
    if (isSubmitting) return;
    _status = LoadStatus.loading;
    _errorMessage = null;
    _unauthorized = false;
    _verificationSent = false;
    notifyListeners();
    try {
      final result = await _repository.login(email, password);
      if (result.success) {
        _session = result.session;
        _status = LoadStatus.success;
      } else {
        _errorMessage = result.errorMessage ?? 'Unable to sign in.';
        _unauthorized = true;
        _status = LoadStatus.error;
      }
    } catch (_) {
      _errorMessage = 'Unable to sign in right now. Please try again.';
      _status = LoadStatus.error;
    }
    notifyListeners();
  }

  Future<void> register(String name, String email, String password) async {
    if (isSubmitting) return;
    _status = LoadStatus.loading;
    _errorMessage = null;
    _unauthorized = false;
    _verificationSent = false;
    notifyListeners();
    try {
      final result = await _repository.register(name, email, password);
      if (result.success) {
        _session = result.session;
        _verificationSent = result.session == null;
        _status = LoadStatus.success;
      } else {
        _errorMessage = result.errorMessage ?? 'Unable to create the account.';
        _status = LoadStatus.error;
      }
    } catch (_) {
      _errorMessage = 'Unable to create the account right now.';
      _status = LoadStatus.error;
    }
    notifyListeners();
  }

  Future<void> loginWithGoogle() async {
    if (isSubmitting) return;
    _status = LoadStatus.loading;
    _errorMessage = null;
    notifyListeners();
    try {
      final result = await _repository.loginWithGoogle();
      _session = result.session;
      _status = result.success ? LoadStatus.success : LoadStatus.error;
      _errorMessage = result.errorMessage;
    } catch (_) {
      _status = LoadStatus.error;
      _errorMessage = 'Google sign-in could not be completed.';
    }
    notifyListeners();
  }

  Future<bool> sendPasswordReset(String email) async {
    try {
      await _repository.sendPasswordReset(email);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateProfile({required String name, String? email}) async {
    try {
      _session = await _repository.updateProfile(name: name, email: email);
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> unlockWithBiometrics() async {
    if (!await BiometricService.instance.unlockCurrentSession()) return false;
    try {
      _session = await _repository.restoreSession();
      notifyListeners();
      return _session != null;
    } catch (_) {
      return false;
    }
  }

  Future<void> logout() async {
    await _repository.logout();
    _session = null;
    _errorMessage = null;
    _status = LoadStatus.initial;
    _unauthorized = false;
    _verificationSent = false;
    notifyListeners();
  }

  static Future<AuthProvider> load({AuthRepository? repository}) async {
    final authRepository = repository ?? FirebaseAuthRepository();
    final provider = AuthProvider(
      repository: authRepository,
      isRestoring: true,
    );
    try {
      provider._session = await authRepository.restoreSession();
      provider._status = provider._session == null
          ? LoadStatus.empty
          : LoadStatus.success;
      provider._sessionRestored = true;
    } catch (_) {
      provider._session = null;
      provider._status = LoadStatus.error;
      provider._errorMessage = 'Your saved session could not be restored.';
    } finally {
      provider._isRestoring = false;
    }
    return provider;
  }
}

class AuthProviderScope extends InheritedNotifier<AuthProvider> {
  const AuthProviderScope({
    super.key,
    required AuthProvider super.notifier,
    required super.child,
  });

  static AuthProvider of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<AuthProviderScope>();
    final notifier = scope?.notifier;
    if (notifier == null) {
      throw FlutterError(
        'AuthProviderScope.of() called without an AuthProviderScope above the context.',
      );
    }
    return notifier;
  }
}
