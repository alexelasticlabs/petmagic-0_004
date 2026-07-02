import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/features/templates/data/templates_dto.dart';
import 'package:petmagic_mobile/features/templates/data/templates_query.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';
import 'package:petmagic_mobile/shared/files/persistent_media_url.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sharedPreferencesProvider = Provider<SharedPreferencesAsync>(
  (ref) => SharedPreferencesAsync(),
);

final templatesCacheDataSourceProvider = Provider<TemplatesCacheDataSource>((
  ref,
) {
  return TemplatesCacheDataSource(ref.watch(sharedPreferencesProvider));
});

class TemplatesCacheDataSource {
  const TemplatesCacheDataSource(this._preferences);

  static const _catalogItemsKey = 'templates_catalog_items_v2';
  static const _catalogVersionKey = 'templates_catalog_version_v2';
  static const _catalogLastSyncAtKey = 'templates_catalog_last_sync_at_v2';

  final SharedPreferencesAsync _preferences;

  Future<int> readCatalogVersion() async {
    return await _preferences.getInt(_catalogVersionKey) ?? 0;
  }

  Future<DateTime?> readCatalogLastSyncAt() async {
    final raw = await _preferences.getString(_catalogLastSyncAtKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    return DateTime.tryParse(raw)?.toUtc();
  }

  Future<void> writeCatalogVersion(int version, {DateTime? syncedAtUtc}) async {
    await _preferences.setInt(_catalogVersionKey, version);
    await _preferences.setString(
      _catalogLastSyncAtKey,
      (syncedAtUtc ?? DateTime.now().toUtc()).toIso8601String(),
    );
  }

  Future<List<TemplateItemDto>> readCatalogItems() async {
    final raw = await _preferences.getString(_catalogItemsKey);
    if (raw == null || raw.isEmpty) {
      return const [];
    }

    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return const [];
    }

    final sanitized = decoded
        .whereType<Map>()
        .map(_sanitizePersistentCatalogItemMap)
        .toList(growable: false);
    final sanitizedRaw = jsonEncode(sanitized);
    if (sanitizedRaw != raw) {
      await _preferences.setString(_catalogItemsKey, sanitizedRaw);
    }

    return sanitized.map(TemplateItemDto.fromJson).toList(growable: false);
  }

  Future<void> writeCatalogItems(List<TemplateItemDto> items) async {
    final sanitizedItems = items
        .map(_sanitizePersistentCatalogItem)
        .toList(growable: false);
    final encoded = jsonEncode(
      sanitizedItems.map((item) => item.toJson()).toList(growable: false),
    );
    await _preferences.setString(_catalogItemsKey, encoded);
  }

  Future<void> replaceCatalog(
    List<TemplateItemDto> items, {
    required int version,
    DateTime? syncedAtUtc,
  }) async {
    await writeCatalogItems(_sortByUpdatedAt(items));
    await writeCatalogVersion(version, syncedAtUtc: syncedAtUtc);
  }

  Future<List<String>> applyCatalogChanges(
    TemplatesCatalogChangesDto changes,
  ) async {
    final existing = await readCatalogItems();
    final byId = <String, TemplateItemDto>{
      for (final item in existing) item.templateId: item,
    };

    final staleMediaCandidates = <String>{};
    for (final deletedId in changes.deletedIds) {
      final removed = byId.remove(deletedId);
      staleMediaCandidates.addAll(_templateMediaUrls(removed));
    }

    for (final upsert in changes.upserts) {
      staleMediaCandidates.addAll(_templateMediaUrls(byId[upsert.templateId]));
      byId[upsert.templateId] = upsert;
    }

    final retainedMediaUrls = byId.values.expand(_templateMediaUrls).toSet();
    final staleMediaUrls = staleMediaCandidates
        .where((url) => !retainedMediaUrls.contains(url))
        .toList(growable: false);

    await writeCatalogItems(
      _sortByUpdatedAt(byId.values.toList(growable: false)),
    );
    await writeCatalogVersion(changes.toVersion);

    return staleMediaUrls;
  }

  Future<TemplatesFeedDto?> readPage(TemplatesQuery query) async {
    final items = await readCatalogItems();
    if (items.isEmpty) {
      return null;
    }

    final filtered = _filterItems(items, query);
    final page = query.page <= 0 ? 1 : query.page;
    final pageSize = query.pageSize <= 0 ? 20 : query.pageSize;
    final start = (page - 1) * pageSize;
    if (start >= filtered.length) {
      return TemplatesFeedDto(items: const [], hasMore: false, page: page);
    }

    final endExclusive = (start + pageSize).clamp(0, filtered.length);
    final pageItems = filtered.sublist(start, endExclusive);

    return TemplatesFeedDto(
      items: pageItems,
      hasMore: endExclusive < filtered.length,
      page: page,
    );
  }

  Future<TemplatesFeedDto?> readFirstPage(TemplatesQuery query) async {
    return readPage(
      query.copyWith(page: 1, resetPage: true, clearCursor: true),
    );
  }

  Future<void> writeFirstPage(
    TemplatesQuery query,
    TemplatesFeedDto page,
  ) async {
    if (query.page != 1) {
      return;
    }

    final existing = await readCatalogItems();
    if (existing.isNotEmpty) {
      return;
    }

    await writeCatalogItems(_sortByUpdatedAt(page.items));
  }

  Future<List<String>> readCategories() async {
    final items = await readCatalogItems();
    final categories =
        items
            .map((item) => item.category.trim())
            .where((category) => category.isNotEmpty)
            .toSet()
            .toList(growable: false)
          ..sort();
    return categories;
  }

  List<TemplateItemDto> _sortByUpdatedAt(List<TemplateItemDto> items) {
    final sorted = [...items];
    sorted.sort((a, b) {
      final aUpdatedAt =
          a.updatedAtUtc ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      final bUpdatedAt =
          b.updatedAtUtc ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      final byDate = bUpdatedAt.compareTo(aUpdatedAt);
      if (byDate != 0) {
        return byDate;
      }

      final byVersion = b.version.compareTo(a.version);
      if (byVersion != 0) {
        return byVersion;
      }

      return b.templateId.compareTo(a.templateId);
    });

    return sorted;
  }

  Iterable<String> _templateMediaUrls(TemplateItemDto? item) sync* {
    final thumbnailUrl = persistentSafeGenerationMediaUrl(item?.thumbnailUrl);
    if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) {
      yield thumbnailUrl;
    }

    final previewUrl = persistentSafeGenerationMediaUrl(
      item?.previewAsset?.url,
    );
    if (previewUrl != null && previewUrl.isNotEmpty) {
      yield previewUrl;
    }
  }

  List<TemplateItemDto> _filterItems(
    List<TemplateItemDto> items,
    TemplatesQuery query,
  ) {
    final normalizedSearch = query.search?.trim().toLowerCase();
    final normalizedCategory = query.category?.trim().toLowerCase();

    return items
        .where((item) {
          if (query.type != null &&
              templateTypeFromApi(item.templateType) != query.type) {
            return false;
          }

          if (normalizedCategory != null && normalizedCategory.isNotEmpty) {
            if (item.category.trim().toLowerCase() != normalizedCategory) {
              return false;
            }
          }

          if (normalizedSearch != null && normalizedSearch.isNotEmpty) {
            if (!_matchesSearch(item, normalizedSearch)) {
              return false;
            }
          }

          return true;
        })
        .toList(growable: false);
  }

  bool _matchesSearch(TemplateItemDto item, String normalizedSearch) {
    final haystacks = <String>[
      item.title,
      item.shortDescription,
      item.category,
      ...item.tags,
      ...item.petPhotoRequirements,
    ];

    return haystacks.any(
      (value) => value.toLowerCase().contains(normalizedSearch),
    );
  }
}

TemplateItemDto _sanitizePersistentCatalogItem(TemplateItemDto item) {
  return TemplateItemDto.fromJson(
    _sanitizePersistentCatalogItemMap(item.toJson()),
  );
}

Map<String, Object?> _sanitizePersistentCatalogItemMap(Map item) {
  return Map<String, Object?>.fromEntries(
    item.entries.map((entry) {
      final key = entry.key.toString();
      return MapEntry(
        key,
        _sanitizePersistentCatalogValue(entry.value, key: key),
      );
    }),
  );
}

Object? _sanitizePersistentCatalogValue(Object? value, {String? key}) {
  if (value == null) {
    return null;
  }

  if (value is String && _isPersistentCatalogMediaUrlKey(key)) {
    return persistentSafeGenerationMediaUrl(value);
  }

  if (value is String && _isPersistentCatalogMediaFileNameKey(key)) {
    return persistentSafeMediaFileName(value);
  }

  if (value is Map) {
    return _sanitizePersistentCatalogItemMap(value);
  }

  if (value is List) {
    return value.map(_sanitizePersistentCatalogValue).toList(growable: false);
  }

  return value;
}

bool _isPersistentCatalogMediaUrlKey(String? key) {
  final normalized = key?.trim().toLowerCase();
  if (normalized == null || normalized.isEmpty) {
    return false;
  }

  return normalized == 'url' || normalized.endsWith('url');
}

bool _isPersistentCatalogMediaFileNameKey(String? key) {
  return key?.trim().toLowerCase() == 'filename';
}
