import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const developmentTestingUserToken = 'intelliglove-development-user';
const developmentTestingUserUid = 'development-testing-user';
const _testingSessionKey = 'auth-development-testing-session';

class DevelopmentTestingSession {
  const DevelopmentTestingSession._();

  static Future<bool> isActive({bool enabled = kDebugMode}) async {
    if (!enabled) return false;
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_testingSessionKey) ?? false;
  }

  static Future<void> setActive(bool active) async {
    final preferences = await SharedPreferences.getInstance();
    if (active) {
      await preferences.setBool(_testingSessionKey, true);
    } else {
      await preferences.remove(_testingSessionKey);
    }
  }
}
