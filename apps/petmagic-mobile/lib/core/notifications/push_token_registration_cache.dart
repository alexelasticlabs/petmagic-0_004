import 'package:shared_preferences/shared_preferences.dart';

const pushTokenRegistrationFingerprintPrefix = 'sha256:';

abstract interface class PushTokenRegistrationCache {
  Future<String?> readLastCompletedRegistrationKey();

  Future<void> writeLastCompletedRegistrationKey(String key);

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
  Future<String?> readLastCompletedRegistrationKey() async {
    final value = await _preferences.getString(_storageKey);
    if (value == null || value.isEmpty) {
      return null;
    }

    if (!value.startsWith(pushTokenRegistrationFingerprintPrefix)) {
      await _preferences.remove(_storageKey);
      return null;
    }

    return value;
  }

  @override
  Future<void> writeLastCompletedRegistrationKey(String key) {
    if (!key.startsWith(pushTokenRegistrationFingerprintPrefix)) {
      throw ArgumentError.value(
        key,
        'key',
        'Persisted push registration keys must be fingerprinted.',
      );
    }

    return _preferences.setString(_storageKey, key);
  }

  @override
  Future<void> clear() {
    return _preferences.remove(_storageKey);
  }
}
