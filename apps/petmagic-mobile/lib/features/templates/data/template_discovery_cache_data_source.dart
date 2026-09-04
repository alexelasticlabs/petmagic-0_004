import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/features/templates/data/template_discovery_dto.dart';
import 'package:petmagic_mobile/features/templates/data/templates_cache_data_source.dart';
import 'package:petmagic_mobile/shared/files/persistent_media_url.dart';
import 'package:shared_preferences/shared_preferences.dart';

final templateDiscoveryCacheDataSourceProvider =
    Provider<TemplateDiscoveryCacheDataSource>((ref) {
      return TemplateDiscoveryCacheDataSource(
        ref.watch(sharedPreferencesProvider),
      );
    });

final class TemplateDiscoveryCacheDataSource {
  const TemplateDiscoveryCacheDataSource(this._preferences);

  static const _snapshotKeyPrefix = 'templates_discovery_snapshot_v1';

  final SharedPreferencesAsync _preferences;

  Future<TemplateDiscoveryDto?> read({required String localeTag}) async {
    final snapshotKey = _buildSnapshotKey(localeTag);
    final raw = await _preferences.getString(snapshotKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      return null;
    }
    final sanitized = _sanitizeMap(decoded);
    final sanitizedRaw = jsonEncode(sanitized);
    if (sanitizedRaw != raw) {
      await _preferences.setString(snapshotKey, sanitizedRaw);
    }
    return TemplateDiscoveryDto.fromJson(sanitized);
  }

  Future<void> write(
    TemplateDiscoveryDto discovery, {
    required String localeTag,
  }) async {
    final snapshotKey = _buildSnapshotKey(localeTag);
    final sanitized = _sanitizeMap(discovery.toJson());
    await _preferences.setString(snapshotKey, jsonEncode(sanitized));
  }
}

String _buildSnapshotKey(String localeTag) {
  var normalized = localeTag
      .trim()
      .toLowerCase()
      .replaceAll('_', '-')
      .replaceAll(RegExp('[^a-z0-9-]'), '');
  if (normalized.isEmpty) {
    normalized = 'default';
  } else if (normalized.length > 35) {
    normalized = normalized.substring(0, 35);
  }
  return '${TemplateDiscoveryCacheDataSource._snapshotKeyPrefix}_$normalized';
}

Map<String, Object?> _sanitizeMap(Map<dynamic, dynamic> value) {
  return Map<String, Object?>.fromEntries(
    value.entries.map((entry) {
      final key = entry.key.toString();
      return MapEntry(key, _sanitizeValue(entry.value, key: key));
    }),
  );
}

Object? _sanitizeValue(Object? value, {String? key}) {
  if (value is String && _isMediaUrlKey(key)) {
    return persistentSafeGenerationMediaUrl(value);
  }
  if (value is String && _isMediaFileNameKey(key)) {
    return persistentSafeMediaFileName(value);
  }
  if (value is Map) {
    return _sanitizeMap(value);
  }
  if (value is List) {
    return value
        .map((item) => _sanitizeValue(item, key: key))
        .toList(growable: false);
  }
  return value;
}

bool _isMediaUrlKey(String? key) {
  final normalized = key?.trim().toLowerCase();
  if (normalized == null || normalized.isEmpty) {
    return false;
  }
  return normalized == 'url' ||
      normalized.endsWith('url') ||
      normalized.endsWith('urls');
}

bool _isMediaFileNameKey(String? key) {
  return key?.trim().toLowerCase() == 'filename';
}
