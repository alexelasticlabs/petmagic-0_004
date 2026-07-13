import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:petmagic_mobile/core/auth/auth_session_storage.dart';
import 'package:petmagic_mobile/features/templates/data/generation_cache_codec.dart';
import 'package:petmagic_mobile/features/templates/data/generation_cache_storage.dart';
import 'package:petmagic_mobile/features/templates/data/template_generation_dtos.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Reads account-scoped generation snapshots and owns cache-key derivation.
final class GenerationCacheReader {
  GenerationCacheReader({
    required AuthSessionStore sessionStorage,
    required SharedPreferencesAsync preferences,
    required GenerationCacheStorage storage,
  }) : _sessionStorage = sessionStorage,
       _preferences = preferences,
       _storage = storage;

  static const _generationsCachePrefix = 'templates_generations_v1:';
  static const _unreadCountCacheKey = 'templates_generations_unread_v1';
  static const allStatusKey = 'all';
  static const cacheStatuses = <String>[
    allStatusKey,
    'active',
    'completed',
    'failed',
  ];

  final AuthSessionStore _sessionStorage;
  final SharedPreferencesAsync _preferences;
  final GenerationCacheStorage _storage;
  Future<String?>? _scopeFuture;

  Future<String?> readScope() => _scopeFuture ??= _resolveScope();

  Future<List<TemplateGenerationResult>?> readGenerations({
    String? status,
  }) async {
    try {
      final scope = await readScope();
      if (scope == null) return null;

      final key = cacheKeyForScope(scope, status);
      final legacyKey = legacyCacheKeyForScope(scope, status);
      if (await _storage.isExpired(key)) {
        await _storage.clear(key);
        return null;
      }
      final raw = await _storage.readString(
        dataKey: key,
        legacyDataKey: legacyKey,
      );
      if (raw == null || raw.isEmpty) return null;

      final decoded = jsonDecode(raw);
      if (decoded is! List) return null;
      final sanitized = GenerationCacheCodec.sanitizeList(decoded);
      final sanitizedRaw = jsonEncode(sanitized);
      if (sanitizedRaw != raw) {
        await _preferences.setString(key, sanitizedRaw);
      }
      return sanitized
          .whereType<Map>()
          .map(
            (item) => TemplateGenerationDto.fromJson(
              GenerationCacheCodec.withScope(
                Map<String, dynamic>.from(item),
                scope,
              ),
            ).toDomain(),
          )
          .toList(growable: false);
    } on Object {
      return null;
    }
  }

  Future<TemplateGenerationResult?> readGeneration(String generationId) async {
    for (final status in cacheStatuses) {
      final items = await readGenerations(status: statusFilter(status));
      if (items == null || items.isEmpty) continue;
      for (final item in items) {
        if (item.generationId == generationId) return item;
      }
    }
    return null;
  }

  Future<int?> readUnreadCount() async {
    try {
      final scope = await readScope();
      if (scope == null) return null;
      final key = scopedDataKey(_unreadCountCacheKey, scope);
      final legacyKey = legacyScopedDataKey(_unreadCountCacheKey, scope);
      if (await _storage.isExpired(key)) {
        await _storage.clear(key);
        return null;
      }
      return _storage.readInt(dataKey: key, legacyDataKey: legacyKey);
    } on Object {
      return null;
    }
  }

  Future<String?> _resolveScope() async {
    final session = await _sessionStorage.read();
    final normalized = session?.user.userId.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  static String scopedDataKey(String baseKey, String scope) =>
      '$baseKey:${scopeFingerprint(scope)}';

  static String legacyScopedDataKey(String baseKey, String scope) =>
      '$baseKey:$scope';

  static String cacheKeyForScope(String scope, String? status) {
    final normalized = status == null || status.trim().isEmpty
        ? allStatusKey
        : status.trim().toLowerCase();
    return '$_generationsCachePrefix${scopeFingerprint(scope)}:$normalized';
  }

  static String legacyCacheKeyForScope(String scope, String? status) {
    final normalized = status == null || status.trim().isEmpty
        ? allStatusKey
        : status.trim().toLowerCase();
    return '$_generationsCachePrefix$scope:$normalized';
  }

  static String scopeFingerprint(String scope) =>
      sha256.convert(utf8.encode(scope.trim().toLowerCase())).toString();

  static String? statusFilter(String status) =>
      status == allStatusKey ? null : status;
}
