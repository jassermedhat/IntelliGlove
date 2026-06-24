import 'package:flutter_test/flutter_test.dart';
import 'package:intelliglove/services/preferences_provider.dart';

void main() {
  test('restores and persists all profile preferences', () async {
    final store = _Store({
      'pref_sign_language': kSignLangArsl,
      'profile_notifications': false,
      'profile_haptics': false,
      'profile_auto_connect': false,
    });
    final provider = await PreferencesProvider.load(store: store);

    expect(provider.isRestored, isTrue);
    expect(provider.signLanguage, kSignLangArsl);
    expect(provider.notificationsEnabled, isFalse);
    expect(provider.hapticEnabled, isFalse);
    expect(provider.autoConnectEnabled, isFalse);

    expect(await provider.setNotificationsEnabled(true), isTrue);
    expect(await provider.setHapticEnabled(true), isTrue);
    expect(await provider.setAutoConnectEnabled(true), isTrue);
    expect(await provider.setSignLanguage(kSignLangAsl), isTrue);
  });

  test('rolls back a failed save', () async {
    final store = _Store({}, failWrites: true);
    final provider = PreferencesProvider(store: store);

    expect(await provider.setNotificationsEnabled(false), isFalse);
    expect(provider.notificationsEnabled, isTrue);
  });

  test('SOS explanation is shown once and can be reset', () async {
    final provider = PreferencesProvider(store: _Store({}));
    expect(await provider.shouldShowLocationExplanation(), isTrue);
    expect(await provider.markLocationExplanationShown(), isTrue);
    expect(await provider.shouldShowLocationExplanation(), isFalse);
    expect(await provider.resetLocationExplanation(), isTrue);
    expect(await provider.shouldShowLocationExplanation(), isTrue);
  });

  test('SOS storage failure defaults to showing the explanation', () async {
    final provider = PreferencesProvider(
      store: _Store({}, failReads: true, failWrites: true),
    );
    expect(await provider.shouldShowLocationExplanation(), isTrue);
    expect(await provider.markLocationExplanationShown(), isFalse);
  });
}

class _Store implements PreferencesStore {
  _Store(this.values, {this.failReads = false, this.failWrites = false});

  final Map<String, Object> values;
  final bool failReads;
  final bool failWrites;

  @override
  Future<Object?> read(String key) async {
    if (failReads) throw StateError('read failed');
    return values[key];
  }

  @override
  Future<bool> write(String key, Object value) async {
    if (failWrites) return false;
    values[key] = value;
    return true;
  }
}
