import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const pushTokenRegistrationFingerprintPrefix = 'sha256:';

abstract interface class PushTokenRegistrationCache {
  Future<String?> readLastCompletedRegistrationKey();

  Future<String?> readLastCompletedRegistrationToken();

  Future<void> writeLastCompletedRegistrationKey(String key);

  Future<void> writeLastCompletedRegistrationToken(String token);

  Future<void> clear();
}

final class SharedPreferencesPushTokenRegistrationCache
    implements PushTokenRegistrationCache {
  SharedPreferencesPushTokenRegistrationCache({
    SharedPreferencesAsync? preferences,
    FlutterSecureStorage? secureStorage,
  }) : _preferences = preferences ?? SharedPreferencesAsync(),
       _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static const _storageKey =
      'petmagic_mobile_push_token_last_registration_key_v1';
  static const _tokenStorageKey =
      'petmagic_mobile_push_token_last_registration_token_v1';

  final SharedPreferencesAsync _preferences;
  final FlutterSecureStorage _secureStorage;

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
  Future<String?> readLastCompletedRegistrationToken() async {
    await _clearLegacyRawTokenPreference();
    final value = await _secureStorage.read(key: _tokenStorageKey);
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
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
  Future<void> writeLastCompletedRegistrationToken(String token) {
    final normalized = token.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(
        token,
        'token',
        'Persisted push registration tokens must be non-empty.',
      );
    }

    return Future.wait<void>([
      _clearLegacyRawTokenPreference(),
      _secureStorage.write(key: _tokenStorageKey, value: normalized),
    ]).then((_) {});
  }

  @override
  Future<void> clear() async {
    await Future.wait<void>([
      _preferences.remove(_storageKey),
      _clearLegacyRawTokenPreference(),
      _secureStorage.delete(key: _tokenStorageKey),
    ]);
  }

  Future<void> _clearLegacyRawTokenPreference() {
    return _preferences.remove(_tokenStorageKey);
  }
}
