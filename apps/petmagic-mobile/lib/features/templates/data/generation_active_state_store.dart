import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef GenerationCacheScopeReader = Future<String?> Function();
typedef GenerationCacheStringReader =
    Future<String?> Function({
      required String dataKey,
      required String legacyDataKey,
    });

/// Owns secure active-generation persistence and legacy preference migration.
final class GenerationActiveStateStore {
  const GenerationActiveStateStore({
    required SharedPreferencesAsync preferences,
    required FlutterSecureStorage secureStorage,
    required GenerationCacheScopeReader readScope,
    required GenerationCacheStringReader readCacheString,
    required String Function(String scope) scopeFingerprint,
    required String Function() createCorrelationId,
  }) : _preferences = preferences,
       _secureStorage = secureStorage,
       _readScope = readScope,
       _readCacheString = readCacheString,
       _scopeFingerprint = scopeFingerprint,
       _createCorrelationId = createCorrelationId;

  static const _generationsCachePrefix = 'templates_generations_v1:';
  static const _generationsCacheUpdatedAtPrefix =
      'templates_generations_updated_at_v1:';
  static const _unreadCountCacheKey = 'templates_generations_unread_v1';
  static const _unreadCountCacheUpdatedAtKey =
      'templates_generations_unread_updated_at_v1';
  static const _activeGenerationIdKey = 'templates_active_generation_id_v1';
  static const _activeGenerationCorrelationIdKey =
      'templates_active_generation_correlation_id_v1';
  static const _secureScopeKey =
      'petmagic_mobile_templates_active_generation_scope_v2';
  static const _secureGenerationIdKey =
      'petmagic_mobile_templates_active_generation_id_v2';
  static const _secureCorrelationIdKey =
      'petmagic_mobile_templates_active_generation_correlation_id_v2';

  final SharedPreferencesAsync _preferences;
  final FlutterSecureStorage _secureStorage;
  final GenerationCacheScopeReader _readScope;
  final GenerationCacheStringReader _readCacheString;
  final String Function(String scope) _scopeFingerprint;
  final String Function() _createCorrelationId;

  Future<({String generationId, String correlationId})?> read() async {
    try {
      final scope = await _readScope();
      if (scope == null) return null;

      final keys = _keys(scope);
      final secureScope = await _secureStorage.read(key: _secureScopeKey);
      final fingerprint = _scopeFingerprint(scope);
      var generationId = secureScope == fingerprint
          ? await _secureStorage.read(key: _secureGenerationIdKey)
          : null;
      var migratedGenerationId = false;
      if (_isEmpty(generationId)) {
        generationId = await _readCacheString(
          dataKey: keys.generationId,
          legacyDataKey: keys.legacyGenerationId,
        );
        if (!_isEmpty(generationId)) {
          migratedGenerationId = true;
          await _secureStorage.write(
            key: _secureGenerationIdKey,
            value: generationId!.trim(),
          );
          await _secureStorage.write(key: _secureScopeKey, value: fingerprint);
        }
      }
      if (_isEmpty(generationId)) return null;

      var correlationId = secureScope == fingerprint
          ? await _secureStorage.read(key: _secureCorrelationIdKey)
          : null;
      if (_isEmpty(correlationId)) {
        correlationId = await _readCacheString(
          dataKey: keys.correlationId,
          legacyDataKey: keys.legacyCorrelationId,
        );
        if (!_isEmpty(correlationId)) {
          await _secureStorage.write(
            key: _secureCorrelationIdKey,
            value: correlationId!.trim(),
          );
          await _clearPreferenceKeys(keys);
        }
      }

      final normalizedGenerationId = generationId!.trim();
      final normalizedCorrelationId = _isEmpty(correlationId)
          ? _createCorrelationId()
          : correlationId!.trim();
      if (_isEmpty(correlationId)) {
        await remember(
          generationId: normalizedGenerationId,
          correlationId: normalizedCorrelationId,
        );
      } else if (migratedGenerationId) {
        await _clearPreferenceKeys(keys);
      }
      return (
        generationId: normalizedGenerationId,
        correlationId: normalizedCorrelationId,
      );
    } on Object {
      return null;
    }
  }

  Future<void> remember({
    required String generationId,
    String? correlationId,
  }) async {
    try {
      final scope = await _readScope();
      final normalizedGenerationId = generationId.trim();
      if (scope == null || normalizedGenerationId.isEmpty) return;

      await _secureStorage.write(
        key: _secureScopeKey,
        value: _scopeFingerprint(scope),
      );
      await _secureStorage.write(
        key: _secureGenerationIdKey,
        value: normalizedGenerationId,
      );
      final normalizedCorrelationId = _isEmpty(correlationId)
          ? _createCorrelationId()
          : correlationId!.trim();
      await _secureStorage.write(
        key: _secureCorrelationIdKey,
        value: normalizedCorrelationId,
      );
      await _clearPreferenceKeys(_keys(scope));
    } on Object {
      // Active state persistence must not break generation submission.
    }
  }

  Future<void> clear(String generationId) async {
    try {
      final scope = await _readScope();
      if (scope == null) return;

      final keys = _keys(scope);
      final fingerprint = _scopeFingerprint(scope);
      final secureScope = await _secureStorage.read(key: _secureScopeKey);
      final secureScopeMatches = secureScope == fingerprint;
      final current = secureScopeMatches
          ? await _secureStorage.read(key: _secureGenerationIdKey)
          : await _readCacheString(
              dataKey: keys.generationId,
              legacyDataKey: keys.legacyGenerationId,
            );
      if (current != null && current != generationId) return;

      if (secureScopeMatches) await _clearSecureState();
      await _clearPreferenceKeys(keys);
    } on Object {
      // Cleanup remains best-effort.
    }
  }

  Future<void> clearAll() async {
    try {
      final keys = await _preferences.getKeys();
      const prefixes = <String>[
        _generationsCachePrefix,
        _generationsCacheUpdatedAtPrefix,
        _unreadCountCacheKey,
        _unreadCountCacheUpdatedAtKey,
        _activeGenerationIdKey,
        _activeGenerationCorrelationIdKey,
      ];
      for (final key in keys.where(
        (key) => prefixes.any(
          (prefix) => key == prefix || key.startsWith('$prefix:'),
        ),
      )) {
        await _preferences.remove(key);
      }
      await _clearSecureState();
    } on Object {
      // Logout cache cleanup remains best-effort.
    }
  }

  Future<void> _clearSecureState() => Future.wait<void>([
    _secureStorage.delete(key: _secureScopeKey),
    _secureStorage.delete(key: _secureGenerationIdKey),
    _secureStorage.delete(key: _secureCorrelationIdKey),
  ]);

  Future<void> _clearPreferenceKeys(_ActiveGenerationKeys keys) =>
      Future.wait<void>([
        _preferences.remove(keys.generationId),
        _preferences.remove(keys.correlationId),
        _preferences.remove(keys.legacyGenerationId),
        _preferences.remove(keys.legacyCorrelationId),
      ]);

  _ActiveGenerationKeys _keys(String scope) {
    final fingerprint = _scopeFingerprint(scope);
    return _ActiveGenerationKeys(
      generationId: '$_activeGenerationIdKey:$fingerprint',
      correlationId: '$_activeGenerationCorrelationIdKey:$fingerprint',
      legacyGenerationId: '$_activeGenerationIdKey:$scope',
      legacyCorrelationId: '$_activeGenerationCorrelationIdKey:$scope',
    );
  }

  bool _isEmpty(String? value) => value == null || value.trim().isEmpty;
}

final class _ActiveGenerationKeys {
  const _ActiveGenerationKeys({
    required this.generationId,
    required this.correlationId,
    required this.legacyGenerationId,
    required this.legacyCorrelationId,
  });

  final String generationId;
  final String correlationId;
  final String legacyGenerationId;
  final String legacyCorrelationId;
}
