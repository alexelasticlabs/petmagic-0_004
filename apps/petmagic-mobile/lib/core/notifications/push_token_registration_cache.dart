import 'package:shared_preferences/shared_preferences.dart';

abstract interface class PushTokenRegistrationCache {
  Future<String?> readLastCompletedRegistrationKey();

  Future<void> writeLastCompletedRegistrationKey(String key);

  Future<void> clearLastCompletedRegistrationKeyForToken(String token);

  Future<void> clear();
}

final class SharedPreferencesPushTokenRegistrationCache
    implements PushTokenRegistrationCache {
  SharedPreferencesPushTokenRegistrationCache({
    SharedPreferencesAsync? preferences,
  }) : _preferences = preferences ?? SharedPreferencesAsync();

  static const _storageKey =
      'petmagic_mobile_push_token_last_registration_key_v1';

  final SharedPreferencesAsync _preferences;

  @override
  Future<String?> readLastCompletedRegistrationKey() {
    return _preferences.getString(_storageKey);
  }

  @override
  Future<void> writeLastCompletedRegistrationKey(String key) {
    return _preferences.setString(_storageKey, key);
  }

  @override
  Future<void> clearLastCompletedRegistrationKeyForToken(String token) async {
    final normalizedToken = token.trim();
    if (normalizedToken.isEmpty) {
      return;
    }

    final current = await _preferences.getString(_storageKey);
    if (current == null || !current.startsWith('$normalizedToken|')) {
      return;
    }

    await _preferences.remove(_storageKey);
  }

  @override
  Future<void> clear() {
    return _preferences.remove(_storageKey);
  }
}
