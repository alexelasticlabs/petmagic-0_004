import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/features/templates/data/templates_dto.dart';
import 'package:petmagic_mobile/features/templates/data/templates_query.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';
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

  static const _catalogItemsKey = 'templates_catalog_items_v1';
  static const _catalogVersionKey = 'templates_catalog_version_v1';
  static const _catalogLastSyncAtKey = 'templates_catalog_last_sync_at_v1';

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

    return decoded
        .whereType<Map>()
        .map((item) => TemplateItemDto.fromJson(Map<String, Object?>.from(item)))
        .toList(growable: false);
  }

  Future<void> writeCatalogItems(List<TemplateItemDto> items) async {
    final encoded = jsonEncode(
      items.map((item) => item.toJson()).toList(growable: false),
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

    final removedPreviewUrls = <String>[];
    for (final deletedId in changes.deletedIds) {
      final removed = byId.remove(deletedId);
      final previewUrl = removed?.previewAsset?.url.trim();
      if (previewUrl != null && previewUrl.isNotEmpty) {
        removedPreviewUrls.add(previewUrl);
      }
    }

    for (final upsert in changes.upserts) {
      byId[upsert.templateId] = upsert;
    }

    await writeCatalogItems(_sortByUpdatedAt(byId.values.toList(growable: false)));
    await writeCatalogVersion(changes.toVersion);

    return removedPreviewUrls;
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
    return readPage(query.copyWith(page: 1, resetPage: true, clearCursor: true));
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
    final categories = items
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
      final aUpdatedAt = a.updatedAtUtc ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      final bUpdatedAt = b.updatedAtUtc ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      final byDate = bUpdatedAt.compareTo(aUpdatedAt);
      if (byDate != 0) {
        return byDate;
      }

      return b.templateId.compareTo(a.templateId);
    });

    return sorted;
  }

  List<TemplateItemDto> _filterItems(List<TemplateItemDto> items, TemplatesQuery query) {
    final normalizedSearch = query.search?.trim().toLowerCase();
    final normalizedCategory = query.category?.trim().toLowerCase();

    return items.where((item) {
      if (query.type != null && templateTypeFromApi(item.templateType) != query.type) {
        return false;
      }

      if (normalizedCategory != null && normalizedCategory.isNotEmpty) {
        if (item.category.trim().toLowerCase() != normalizedCategory) {
          return false;
        }
      }

      if (normalizedSearch != null && normalizedSearch.isNotEmpty) {
        final title = item.title.toLowerCase();
        final category = item.category.toLowerCase();
        final tags = item.tags.join(' ').toLowerCase();
        if (!title.contains(normalizedSearch)
            && !category.contains(normalizedSearch)
            && !tags.contains(normalizedSearch)) {
          return false;
        }
      }

      return true;
    }).toList(growable: false);
  }
}
