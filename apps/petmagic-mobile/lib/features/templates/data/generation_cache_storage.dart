import 'package:petmagic_mobile/core/config/app_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Owns TTL metadata, legacy-key migration and low-level cache cleanup.
final class GenerationCacheStorage {
  const GenerationCacheStorage({required SharedPreferencesAsync preferences})
    : _preferences = preferences;

  static const _generationsCachePrefix = 'templates_generations_v1:';
  static const _generationsCacheUpdatedAtPrefix =
      'templates_generations_updated_at_v1:';
  static const _unreadCountCacheKey = 'templates_generations_unread_v1';
  static const _unreadCountCacheUpdatedAtKey =
      'templates_generations_unread_updated_at_v1';

  final SharedPreferencesAsync _preferences;

  Future<String?> readString({
    required String dataKey,
    required String legacyDataKey,
  }) async {
    final current = await _preferences.getString(dataKey);
    if (current != null) return current;

    if (await isExpired(legacyDataKey)) {
      await clear(legacyDataKey);
      return null;
    }
    final legacy = await _preferences.getString(legacyDataKey);
    if (legacy == null) return null;

    await _preferences.setString(dataKey, legacy);
    await _migrateTimestamp(fromDataKey: legacyDataKey, toDataKey: dataKey);
    await clear(legacyDataKey);
    return legacy;
  }

  Future<int?> readInt({
    required String dataKey,
    required String legacyDataKey,
  }) async {
    final current = await _preferences.getInt(dataKey);
    if (current != null) return current;

    if (await isExpired(legacyDataKey)) {
      await clear(legacyDataKey);
      return null;
    }
    final legacy = await _preferences.getInt(legacyDataKey);
    if (legacy == null) return null;

    await _preferences.setInt(dataKey, legacy);
    await _migrateTimestamp(fromDataKey: legacyDataKey, toDataKey: dataKey);
    await clear(legacyDataKey);
    return legacy;
  }

  Future<void> touch(String dataKey) => _preferences.setString(
    _updatedAtKey(dataKey),
    DateTime.now().toUtc().toIso8601String(),
  );

  Future<bool> isExpired(String dataKey) async {
    try {
      final raw = await _preferences.getString(_updatedAtKey(dataKey));
      if (raw == null || raw.isEmpty) return false;
      final updatedAtUtc = DateTime.tryParse(raw)?.toUtc();
      if (updatedAtUtc == null) return true;
      return DateTime.now().toUtc().difference(updatedAtUtc) >
          AppConfig.generationCacheTtl;
    } on Object {
      return false;
    }
  }

  Future<void> clear(String dataKey) async {
    try {
      await _preferences.remove(dataKey);
      await _preferences.remove(_updatedAtKey(dataKey));
    } on Object {
      // Cache cleanup remains best-effort.
    }
  }

  Future<void> _migrateTimestamp({
    required String fromDataKey,
    required String toDataKey,
  }) async {
    final updatedAt = await _preferences.getString(_updatedAtKey(fromDataKey));
    if (updatedAt == null || updatedAt.isEmpty) return;
    await _preferences.setString(_updatedAtKey(toDataKey), updatedAt);
  }

  String _updatedAtKey(String dataKey) {
    if (dataKey == _unreadCountCacheKey ||
        dataKey.startsWith('$_unreadCountCacheKey:')) {
      final suffix = dataKey.substring(_unreadCountCacheKey.length);
      return '$_unreadCountCacheUpdatedAtKey$suffix';
    }
    if (dataKey.startsWith(_generationsCachePrefix)) {
      final suffix = dataKey.substring(_generationsCachePrefix.length);
      return '$_generationsCacheUpdatedAtPrefix$suffix';
    }
    return '${dataKey}_updated_at_v1';
  }
}
