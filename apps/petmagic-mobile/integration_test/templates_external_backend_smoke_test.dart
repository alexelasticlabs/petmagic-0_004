import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:petmagic_mobile/features/templates/data/templates_dto.dart';
import 'package:petmagic_mobile/features/templates/data/templates_query.dart';
import 'package:petmagic_mobile/features/templates/data/templates_remote_data_source.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';

const _externalBaseUrl = String.fromEnvironment(
  'PETMAGIC_EXTERNAL_TEMPLATES_API_BASE_URL',
);
const _categoryOverride = String.fromEnvironment(
  'PETMAGIC_EXTERNAL_TEMPLATES_CATEGORY',
);
const _searchOverride = String.fromEnvironment(
  'PETMAGIC_EXTERNAL_TEMPLATES_SEARCH',
);

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'external templates API stays paged filtered searchable and card-sized',
    (_) async {
      final normalizedBaseUrl = _externalBaseUrl.trim();
      if (normalizedBaseUrl.isEmpty) {
        _recordExternalSmokeData(binding, {
          'stage': 'skipped',
          'reason': 'missing PETMAGIC_EXTERNAL_TEMPLATES_API_BASE_URL',
        });
        return;
      }

      final baseUri = Uri.tryParse(normalizedBaseUrl);
      expect(
        baseUri?.scheme,
        'https',
        reason:
            'External backend smoke is intended for deployed HTTPS APIs only.',
      );
      expect(baseUri?.host.trim().isNotEmpty, isTrue);

      final requestUrls = <String>[];
      final dio =
          Dio(
              BaseOptions(
                baseUrl: normalizedBaseUrl,
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 15),
                sendTimeout: const Duration(seconds: 10),
              ),
            )
            ..interceptors.add(
              InterceptorsWrapper(
                onRequest: (options, handler) {
                  requestUrls.add(options.uri.toString());
                  handler.next(options);
                },
              ),
            );
      addTearDown(() => dio.close(force: true));

      final remote = TemplatesRemoteDataSource(dio);
      final probes = <_ProbeReport>[];

      final first = await _fetchFeedProbe(
        dio,
        name: 'first_page',
        query: const TemplatesQuery(pageSize: 20),
      );
      probes.add(first.report);
      _assertFeedEnvelope(first);
      _assertFeedItemsAreCardSized(first.items, context: first.name);
      _assertNoDuplicateIds(first.dto.items, context: first.name);
      expect(first.dto.items.length, lessThanOrEqualTo(20));

      final bounded = await _fetchFeedProbe(
        dio,
        name: 'take_1000_is_bounded',
        query: const TemplatesQuery(pageSize: 1000),
      );
      probes.add(bounded.report);
      _assertFeedEnvelope(bounded);
      _assertFeedItemsAreCardSized(bounded.items, context: bounded.name);
      expect(
        bounded.dto.items.length,
        lessThanOrEqualTo(50),
        reason: 'Public feed must cap oversized take values server-side.',
      );

      _FeedProbe? second;
      if (first.dto.hasMore &&
          first.dto.nextCursor?.trim().isNotEmpty == true) {
        second = await _fetchFeedProbe(
          dio,
          name: 'second_cursor_page',
          query: TemplatesQuery(pageSize: 20, cursor: first.dto.nextCursor),
        );
        probes.add(second.report);
        _assertFeedEnvelope(second);
        _assertFeedItemsAreCardSized(second.items, context: second.name);
        _assertNoDuplicateIds(second.dto.items, context: second.name);
        _assertNoOverlap(first.dto.items, second.dto.items);
      }

      final imageFeed = await _fetchFeedProbe(
        dio,
        name: 'image_filter',
        query: const TemplatesQuery(type: TemplateType.image, pageSize: 20),
      );
      probes.add(imageFeed.report);
      _assertFeedEnvelope(imageFeed);
      _assertTypeFilter(imageFeed.dto.items, TemplateType.image);
      _assertFeedItemsAreCardSized(imageFeed.items, context: imageFeed.name);

      final videoFeed = await _fetchFeedProbe(
        dio,
        name: 'video_filter',
        query: const TemplatesQuery(type: TemplateType.video, pageSize: 20),
      );
      probes.add(videoFeed.report);
      _assertFeedEnvelope(videoFeed);
      _assertTypeFilter(videoFeed.dto.items, TemplateType.video);
      _assertFeedItemsAreCardSized(videoFeed.items, context: videoFeed.name);

      if (first.dto.items.isNotEmpty) {
        expect(
          imageFeed.dto.items.length + videoFeed.dto.items.length,
          greaterThan(0),
          reason:
              'A non-empty all feed should have at least one image/video typed page.',
        );
      }

      final category = await _chooseCategory(remote, first.dto);
      _FeedProbe? categoryFeed;
      if (category != null) {
        categoryFeed = await _fetchFeedProbe(
          dio,
          name: 'category_filter',
          query: TemplatesQuery(category: category, pageSize: 20),
        );
        probes.add(categoryFeed.report);
        _assertFeedEnvelope(categoryFeed);
        _assertCategoryFilter(categoryFeed.dto.items, category);
        _assertFeedItemsAreCardSized(
          categoryFeed.items,
          context: categoryFeed.name,
        );
      }

      final search = _chooseSearchTerm(first.dto);
      _FeedProbe? searchFeed;
      if (search != null) {
        searchFeed = await _fetchFeedProbe(
          dio,
          name: 'search_results',
          query: TemplatesQuery(search: search, pageSize: 20),
        );
        probes.add(searchFeed.report);
        _assertFeedEnvelope(searchFeed);
        _assertNoDuplicateIds(searchFeed.dto.items, context: searchFeed.name);
        _assertFeedItemsAreCardSized(
          searchFeed.items,
          context: searchFeed.name,
        );
      }

      final randomReports = <Map<String, Object?>>[];
      final anyRandom = await _fetchRandomProbe(
        remote,
        mode: TemplateRandomMode.any,
        category: null,
        includePremium: false,
      );
      randomReports.add(anyRandom);
      _assertRandomPremiumAvailability(anyRandom);

      if (imageFeed.dto.items.isNotEmpty) {
        final imageRandom = await _fetchRandomProbe(
          remote,
          mode: TemplateRandomMode.image,
          category: null,
          includePremium: true,
        );
        randomReports.add(imageRandom);
        _assertRandomType(imageRandom, TemplateType.image);
      }

      if (videoFeed.dto.items.isNotEmpty) {
        final videoRandom = await _fetchRandomProbe(
          remote,
          mode: TemplateRandomMode.video,
          category: null,
          includePremium: true,
        );
        randomReports.add(videoRandom);
        _assertRandomType(videoRandom, TemplateType.video);
      }

      if (categoryFeed != null && categoryFeed.dto.items.isNotEmpty) {
        final categoryRandom = await _fetchRandomProbe(
          remote,
          mode: TemplateRandomMode.any,
          category: category,
          includePremium: true,
        );
        randomReports.add(categoryRandom);
        _assertRandomCategory(categoryRandom, category!);
      }

      _recordExternalSmokeData(binding, {
        'stage': 'completed',
        'base_url': normalizedBaseUrl,
        'request_count': requestUrls.length,
        'request_urls': requestUrls,
        'probes': probes.map((probe) => probe.toJson()).toList(),
        'random_probes': randomReports,
        'selected_category': category,
        'selected_search': search,
        'first_page_has_more': first.dto.hasMore,
        'first_page_next_cursor_present':
            first.dto.nextCursor?.trim().isNotEmpty == true,
        'second_page_requested': second != null,
      });
    },
  );
}

Future<_FeedProbe> _fetchFeedProbe(
  Dio dio, {
  required String name,
  required TemplatesQuery query,
}) async {
  final rawWatch = Stopwatch()..start();
  final rawResponse = await dio.get<Map<String, dynamic>>(
    '/api/templates/feed',
    queryParameters: query.toQueryParameters(),
  );
  rawWatch.stop();

  final rawData = rawResponse.data;
  if (rawData == null) {
    fail('$name returned an empty feed response body.');
  }

  final raw = Map<String, Object?>.from(rawData);
  final items = _readItemMaps(raw);

  final parseWatch = Stopwatch()..start();
  final dto = TemplatesFeedDto.fromJson(raw);
  parseWatch.stop();

  return _FeedProbe(
    name: name,
    query: query.toQueryParameters(),
    raw: raw,
    items: items,
    dto: dto,
    rawElapsedMs: rawWatch.elapsedMilliseconds,
    parsedElapsedMs: parseWatch.elapsedMilliseconds,
    statusCode: rawResponse.statusCode ?? 0,
  );
}

Future<Map<String, Object?>> _fetchRandomProbe(
  TemplatesRemoteDataSource remote, {
  required TemplateRandomMode mode,
  required String? category,
  required bool includePremium,
}) async {
  final watch = Stopwatch()..start();
  final response = await remote.fetchRandomTemplate(
    mode: mode,
    category: category,
    includePremium: includePremium,
  );
  watch.stop();

  final template = response.template;
  return {
    'mode': mode.name,
    'category': category,
    'include_premium': includePremium,
    'elapsed_ms': watch.elapsedMilliseconds,
    'template_present': template != null,
    if (template != null) ...{
      'template_id': template.templateId,
      'template_type': template.templateType,
      'template_category': template.category,
      'is_premium': template.isPremium,
      'preview_content_type': template.previewAsset?.contentType,
      'thumbnail_present': template.thumbnailUrl?.trim().isNotEmpty == true,
    },
  };
}

Future<String?> _chooseCategory(
  TemplatesRemoteDataSource remote,
  TemplatesFeedDto first,
) async {
  final override = _categoryOverride.trim();
  if (override.isNotEmpty) {
    return override;
  }

  final categories = await remote.fetchCategories();
  if (categories.isNotEmpty) {
    return categories.first;
  }

  for (final item in first.items) {
    final category = item.category.trim();
    if (category.isNotEmpty) {
      return category;
    }
  }

  return null;
}

String? _chooseSearchTerm(TemplatesFeedDto first) {
  final override = _searchOverride.trim();
  if (override.isNotEmpty) {
    return override;
  }

  for (final item in first.items) {
    for (final tag in item.tags) {
      final normalized = tag.trim();
      if (normalized.length >= 3) {
        return normalized;
      }
    }

    final titleWord = item.title
        .split(RegExp(r'[^A-Za-z0-9]+'))
        .map((part) => part.trim())
        .where((part) => part.length >= 3)
        .firstOrNull;
    if (titleWord != null) {
      return titleWord;
    }

    final category = item.category.trim();
    if (category.length >= 3) {
      return category;
    }
  }

  return null;
}

void _assertFeedEnvelope(_FeedProbe probe) {
  expect(
    probe.statusCode,
    200,
    reason: '${probe.name} should return HTTP 200.',
  );
  expect(
    probe.raw['items'],
    isA<List<dynamic>>(),
    reason: '${probe.name} should expose an items array.',
  );
  expect(
    probe.raw['hasMore'],
    isA<bool>(),
    reason: '${probe.name} should expose hasMore.',
  );
  expect(
    probe.raw,
    isNot(containsPair('totalCount', anything)),
    reason: 'Public feed must avoid count-heavy list responses.',
  );
  expect(
    probe.raw,
    isNot(containsPair('pageSize', anything)),
    reason: 'Public feed must use cursor pagination, not page-size metadata.',
  );
  expect(
    probe.raw,
    isNot(containsPair('page', anything)),
    reason: 'Public feed must use cursor pagination, not page metadata.',
  );
  expect(probe.items.length, probe.dto.items.length);
  _assertFeedSortOrder(probe.dto.items, context: probe.name);
}

void _assertFeedItemsAreCardSized(
  List<Map<String, Object?>> items, {
  required String context,
}) {
  final violations = <String>[];
  for (final item in items) {
    final id = (item['templateId'] ?? item['id'] ?? '<missing>').toString();
    for (final key in item.keys) {
      if (_disallowedFeedItemKeys.contains(key)) {
        violations.add('$context/$id:$key');
      }
    }

    expect(
      (item['templateId'] ?? '').toString().trim().isNotEmpty,
      isTrue,
      reason: '$context item should include templateId.',
    );
    final type = (item['templateType'] ?? '').toString();
    expect(
      type,
      anyOf(TemplateType.image.apiValue, TemplateType.video.apiValue),
      reason: '$context/$id should include a valid templateType.',
    );
    expect(
      (item['title'] ?? '').toString().trim().isNotEmpty,
      isTrue,
      reason: '$context/$id should include title for card rendering.',
    );
    expect(
      (item['category'] ?? '').toString().trim().isNotEmpty,
      isTrue,
      reason: '$context/$id should include category for filtering UI.',
    );
    expect(
      item['tags'],
      isA<List<dynamic>>(),
      reason: '$context/$id should include tag metadata for search context.',
    );

    final previewAsset = item['previewAsset'];
    expect(
      previewAsset,
      isA<Map>(),
      reason: '$context/$id should include a previewAsset for card media.',
    );
    if (previewAsset is Map) {
      final preview = Map<String, Object?>.from(previewAsset);
      final previewUrl = (preview['url'] ?? '').toString().trim();
      final contentType = (preview['contentType'] ?? '').toString();
      _assertHttpsMediaUrl(previewUrl, '$context/$id previewAsset.url');

      if (type == TemplateType.video.apiValue) {
        expect(
          contentType.toLowerCase(),
          startsWith('video/'),
          reason: '$context/$id video templates need video preview assets.',
        );
      } else {
        expect(
          contentType.toLowerCase(),
          startsWith('image/'),
          reason: '$context/$id image templates need image thumbnails.',
        );
        final thumbnailUrl = (item['thumbnailUrl'] ?? '').toString().trim();
        _assertHttpsMediaUrl(thumbnailUrl, '$context/$id thumbnailUrl');
      }
    }
  }

  expect(
    violations,
    isEmpty,
    reason: 'Public feed item payload contains heavy/internal fields.',
  );
}

void _assertHttpsMediaUrl(String rawUrl, String field) {
  expect(rawUrl.isNotEmpty, isTrue, reason: '$field should not be empty.');
  final uri = Uri.tryParse(rawUrl);
  expect(uri?.scheme, 'https', reason: '$field should use HTTPS CDN media.');
  expect(
    uri?.host.trim().isNotEmpty,
    isTrue,
    reason: '$field should include a media host.',
  );
}

void _assertNoDuplicateIds(
  List<TemplateItemDto> items, {
  required String context,
}) {
  final ids = items.map((item) => item.templateId).toList(growable: false);
  expect(
    ids.length,
    ids.toSet().length,
    reason: '$context should not contain duplicate template ids.',
  );
}

void _assertNoOverlap(
  List<TemplateItemDto> first,
  List<TemplateItemDto> second,
) {
  final firstIds = first.map((item) => item.templateId).toSet();
  final overlap = second
      .map((item) => item.templateId)
      .where(firstIds.contains)
      .toList(growable: false);
  expect(overlap, isEmpty, reason: 'Cursor pages should not overlap.');
}

void _assertFeedSortOrder(
  List<TemplateItemDto> items, {
  required String context,
}) {
  for (final item in items) {
    expect(
      item.updatedAtUtc,
      isNotNull,
      reason: '$context/${item.templateId} should include updatedAtUtc.',
    );
    expect(
      item.version,
      greaterThan(0),
      reason: '$context/${item.templateId} should include a positive version.',
    );
  }

  for (var index = 1; index < items.length; index++) {
    final previous = items[index - 1];
    final current = items[index];
    final previousUpdatedAt = previous.updatedAtUtc;
    final currentUpdatedAt = current.updatedAtUtc;
    if (previousUpdatedAt == null || currentUpdatedAt == null) {
      continue;
    }

    final timestampCompare = previousUpdatedAt.compareTo(currentUpdatedAt);
    expect(
      timestampCompare,
      greaterThanOrEqualTo(0),
      reason:
          '$context should preserve backend order by updatedAtUtc descending.',
    );
    if (timestampCompare == 0) {
      expect(
        previous.version,
        greaterThanOrEqualTo(current.version),
        reason:
            '$context should preserve backend order by version descending when updatedAtUtc ties.',
      );
    }
  }
}

void _assertTypeFilter(List<TemplateItemDto> items, TemplateType type) {
  expect(
    items.where((item) => item.templateType != type.apiValue),
    isEmpty,
    reason: '${type.apiValue} feed should not mix template types.',
  );
}

void _assertCategoryFilter(List<TemplateItemDto> items, String category) {
  final normalized = category.trim().toLowerCase();
  expect(
    items.where((item) => item.category.trim().toLowerCase() != normalized),
    isEmpty,
    reason: 'Category feed should not mix old or unrelated results.',
  );
}

void _assertRandomType(Map<String, Object?> report, TemplateType type) {
  if (report['template_present'] != true) {
    fail(
      'Random ${type.apiValue} returned no template despite non-empty feed.',
    );
  }
  expect(
    report['template_type'],
    type.apiValue,
    reason: 'Random template should respect type filter.',
  );
}

void _assertRandomCategory(Map<String, Object?> report, String category) {
  if (report['template_present'] != true) {
    fail(
      'Random category returned no template despite non-empty category feed.',
    );
  }
  expect(
    (report['template_category'] ?? '').toString().trim().toLowerCase(),
    category.trim().toLowerCase(),
    reason: 'Random template should respect category filter.',
  );
}

void _assertRandomPremiumAvailability(Map<String, Object?> report) {
  if (report['include_premium'] != false ||
      report['template_present'] != true) {
    return;
  }

  expect(
    report['is_premium'],
    isNot(true),
    reason:
        'Random template should not return premium templates when includePremium=false.',
  );
}

List<Map<String, Object?>> _readItemMaps(Map<String, Object?> raw) {
  final rawItems = raw['items'];
  if (rawItems is! List) {
    return const [];
  }

  return rawItems
      .whereType<Map>()
      .map((item) => Map<String, Object?>.from(item))
      .toList(growable: false);
}

void _recordExternalSmokeData(
  IntegrationTestWidgetsFlutterBinding binding,
  Map<String, Object?> data,
) {
  binding.reportData ??= <String, dynamic>{};
  binding.reportData!['templates_external_backend_smoke'] = data;
}

const _disallowedFeedItemKeys = {
  'assets',
  'adminNotes',
  'createdAtUtc',
  'deletedAtUtc',
  'generationPrompt',
  'imageModel',
  'imagePrompt',
  'internalNotes',
  'klingPrompt',
  'metadata',
  'model',
  'modelName',
  'negativePrompt',
  'originalMediaUrl',
  'prompt',
  'promptAfterVariation',
  'promptBeforeVariation',
  'provider',
  'providerJobId',
  'providerPayload',
  'promoBadgeMode',
  'referenceImageUrl',
  'referenceMotionUrl',
  'referenceVideoUrl',
  'sourceImageUrl',
  'status',
  'systemPrompt',
  'videoModel',
};

class _FeedProbe {
  const _FeedProbe({
    required this.name,
    required this.query,
    required this.raw,
    required this.items,
    required this.dto,
    required this.rawElapsedMs,
    required this.parsedElapsedMs,
    required this.statusCode,
  });

  final String name;
  final Map<String, Object?> query;
  final Map<String, Object?> raw;
  final List<Map<String, Object?>> items;
  final TemplatesFeedDto dto;
  final int rawElapsedMs;
  final int parsedElapsedMs;
  final int statusCode;

  _ProbeReport get report {
    return _ProbeReport({
      'name': name,
      'query': query,
      'status_code': statusCode,
      'raw_elapsed_ms': rawElapsedMs,
      'parsed_elapsed_ms': parsedElapsedMs,
      'item_count': dto.items.length,
      'has_more': dto.hasMore,
      'next_cursor_present': dto.nextCursor?.trim().isNotEmpty == true,
      'duplicate_count':
          dto.items.length -
          dto.items.map((item) => item.templateId).toSet().length,
      'item_types': dto.items
          .map((item) => item.templateType)
          .toSet()
          .toList(growable: false),
      'preview_content_types': dto.items
          .map((item) => item.previewAsset?.contentType)
          .whereType<String>()
          .toSet()
          .toList(growable: false),
      'root_keys': raw.keys.toList(growable: false),
      'first_item_keys': items.isEmpty
          ? const <String>[]
          : items.first.keys.toList(growable: false),
    });
  }
}

class _ProbeReport {
  const _ProbeReport(this._json);

  final Map<String, Object?> _json;

  Map<String, Object?> toJson() => _json;
}
