import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BiometricService {
  BiometricService({LocalAuthentication? localAuth})
    : _localAuth = localAuth ?? LocalAuthentication();

  static final instance = BiometricService();
  final LocalAuthentication _localAuth;

  String _key(String uid) => 'biometric-lock-enabled-$uid';

  Future<bool> isAvailable() async {
    try {
      return await _localAuth.isDeviceSupported() &&
          await _localAuth.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  Future<bool> isEnabled(String uid) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_key(uid)) ?? false;
  }

  Future<void> setEnabled(String uid, bool value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_key(uid), value);
  }

  Future<bool> authenticate() async {
    if (!await isAvailable()) return false;
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Unlock your Firebase-authenticated IntelliGlove session',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  Future<bool> unlockCurrentSession() async {
    if (Firebase.apps.isEmpty) return false;
    if (FirebaseAuth.instance.currentUser == null) return false;
    return authenticate();
  }
}
