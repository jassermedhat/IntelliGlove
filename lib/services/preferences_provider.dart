import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String kSignLangAsl = 'asl';
const String kSignLangArsl = 'arsl';

const Map<String, String> kSignLangFullNames = {
  kSignLangAsl: 'American Sign Language',
  kSignLangArsl: 'Arabic Sign Language',
};

const Map<String, String> kSignLangLabels = {
  kSignLangAsl: 'ASL',
  kSignLangArsl: 'ArSL',
};

abstract class PreferencesStore {
  Future<Object?> read(String key);
  Future<bool> write(String key, Object value);
}

class SharedPreferencesStore implements PreferencesStore {
  @override
  Future<Object?> read(String key) async =>
      (await SharedPreferences.getInstance()).get(key);

  @override
  Future<bool> write(String key, Object value) async {
    final prefs = await SharedPreferences.getInstance();
    return switch (value) {
      bool flag => prefs.setBool(key, flag),
      String text => prefs.setString(key, text),
      _ => false,
    };
  }
}

class PreferencesProvider extends ChangeNotifier {
  static const _signLanguageKey = 'pref_sign_language';
  static const _notificationsKey = 'profile_notifications';
  static const _hapticsKey = 'profile_haptics';
  static const _autoConnectKey = 'profile_auto_connect';
  static const _sosExplanationKey = 'sos_location_explained';

  PreferencesProvider({
    String signLanguage = kSignLangAsl,
    bool notificationsEnabled = true,
    bool hapticEnabled = true,
    bool autoConnectEnabled = true,
    PreferencesStore? store,
    bool restored = false,
  }) : _signLanguage = signLanguage,
       _notificationsEnabled = notificationsEnabled,
       _hapticEnabled = hapticEnabled,
       _autoConnectEnabled = autoConnectEnabled,
       _store = store ?? SharedPreferencesStore(),
       _restored = restored;

  final PreferencesStore _store;
  String _signLanguage;
  bool _notificationsEnabled;
  bool _hapticEnabled;
  bool _autoConnectEnabled;
  bool _loading = false;
  bool _restored;

  static Future<PreferencesProvider> load({PreferencesStore? store}) async {
    final provider = PreferencesProvider(store: store, restored: false);
    await provider.restore();
    return provider;
  }

  String get signLanguage => _signLanguage;
  bool get notificationsEnabled => _notificationsEnabled;
  bool get hapticEnabled => _hapticEnabled;
  bool get autoConnectEnabled => _autoConnectEnabled;
  bool get isLoading => _loading;
  bool get isRestored => _restored;
  String get ttsLocale => _signLanguage == kSignLangArsl ? 'ar-SA' : 'en-US';
  bool get isRtl => _signLanguage == kSignLangArsl;
  String get signLanguageFullName =>
      kSignLangFullNames[_signLanguage] ?? kSignLangFullNames[kSignLangAsl]!;
  String get signLanguageLabel =>
      kSignLangLabels[_signLanguage] ?? kSignLangLabels[kSignLangAsl]!;

  Future<void> restore() async {
    _loading = true;
    notifyListeners();
    try {
      final values = await Future.wait([
        _store.read(_signLanguageKey),
        _store.read(_notificationsKey),
        _store.read(_hapticsKey),
        _store.read(_autoConnectKey),
      ]);
      final language = values[0];
      _signLanguage = language == kSignLangArsl || language == kSignLangAsl
          ? language! as String
          : kSignLangAsl;
      _notificationsEnabled = values[1] is bool ? values[1]! as bool : true;
      _hapticEnabled = values[2] is bool ? values[2]! as bool : true;
      _autoConnectEnabled = values[3] is bool ? values[3]! as bool : true;
      _restored = true;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> setSignLanguage(String code) async {
    if (code != kSignLangAsl && code != kSignLangArsl) return false;
    return _setValue<String>(
      key: _signLanguageKey,
      previous: _signLanguage,
      next: code,
      apply: (value) => _signLanguage = value,
    );
  }

  Future<bool> setNotificationsEnabled(bool value) => _setValue<bool>(
    key: _notificationsKey,
    previous: _notificationsEnabled,
    next: value,
    apply: (next) => _notificationsEnabled = next,
  );

  Future<bool> setHapticEnabled(bool value) => _setValue<bool>(
    key: _hapticsKey,
    previous: _hapticEnabled,
    next: value,
    apply: (next) => _hapticEnabled = next,
  );

  Future<bool> setAutoConnectEnabled(bool value) => _setValue<bool>(
    key: _autoConnectKey,
    previous: _autoConnectEnabled,
    next: value,
    apply: (next) => _autoConnectEnabled = next,
  );

  Future<bool> _setValue<T extends Object>({
    required String key,
    required T previous,
    required T next,
    required ValueChanged<T> apply,
  }) async {
    if (previous == next) return true;
    apply(next);
    notifyListeners();
    try {
      final saved = await _store.write(key, next);
      if (!saved) throw StateError('Preference was not saved');
      return true;
    } catch (_) {
      apply(previous);
      notifyListeners();
      return false;
    }
  }

  Future<bool> shouldShowLocationExplanation() async {
    try {
      return await _store.read(_sosExplanationKey) != true;
    } catch (_) {
      return true;
    }
  }

  Future<bool> markLocationExplanationShown() async {
    try {
      return await _store.write(_sosExplanationKey, true);
    } catch (_) {
      return false;
    }
  }

  Future<bool> resetLocationExplanation() async {
    try {
      return await _store.write(_sosExplanationKey, false);
    } catch (_) {
      return false;
    }
  }
}

class PreferencesScope extends InheritedNotifier<PreferencesProvider> {
  const PreferencesScope({
    super.key,
    required PreferencesProvider super.notifier,
    required super.child,
  });

  static PreferencesProvider of(BuildContext context) {
    final notifier = context
        .dependOnInheritedWidgetOfExactType<PreferencesScope>()
        ?.notifier;
    if (notifier == null) {
      throw FlutterError(
        'PreferencesScope.of() called without a PreferencesScope above the context.',
      );
    }
    return notifier;
  }
}
