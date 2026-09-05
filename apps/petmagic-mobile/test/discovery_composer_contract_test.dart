import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/features/templates/application/template_discovery_state.dart';
import 'package:petmagic_mobile/features/templates/data/template_discovery_cache_data_source.dart';
import 'package:petmagic_mobile/features/templates/data/template_discovery_dto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  test(
    'V2 preserves localized copy, revision, identities and surface flags',
    () {
      final dto = TemplateDiscoveryDto.fromJson(_document());
      final discovery = dto.toDomain();
      expect(discovery.schemaVersion, 2);
      expect(discovery.revision, 42);
      expect(discovery.page?.title, 'Магия осени');
      expect(discovery.page?.subtitle, 'Новые идеи');
      expect(discovery.page?.searchEnabled, isFalse);
      expect(discovery.page?.autoplayEnabled, isFalse);
      expect(discovery.page?.autoAdvanceInterval, const Duration(seconds: 12));
      final section = discovery.sections.single;
      expect(section.identity, 'section-1');
      expect(section.categoryId, 'category-1');
      expect(section.category, 'Funny');
      expect(section.displayTitle, 'Смешные истории');
      expect(section.subtitle, 'Для вашего питомца');
      expect(section.showInCarousel, isFalse);
      expect(section.showAsRail, isTrue);
      expect(
        TemplateDiscoveryDto.fromJson(dto.toJson()).toJson(),
        dto.toJson(),
      );
    },
  );

  for (final schema in [null, 1, 3]) {
    test('schema $schema keeps legacy layout and ignores V2 controls', () {
      final document = _document()..['schemaVersion'] = schema;
      final discovery = TemplateDiscoveryDto.fromJson(document).toDomain();
      expect(discovery.page, isNull);
      expect(discovery.revision, isNull);
      expect(discovery.sections.single.displayTitle, 'Funny');
      expect(discovery.sections.single.showInCarousel, isTrue);
      expect(discovery.sections.single.showAsRail, isTrue);
    });
  }

  for (final (input, expected) in [
    (-1, 5000),
    (5000, 5000),
    (18000, 18000),
    (30000, 30000),
    (999999, 30000),
    ('bad', 7000),
    (null, 7000),
    (double.nan, 7000),
  ]) {
    test('autoplay interval $input safely resolves to $expected ms', () {
      final document = _document();
      (document['page']! as Map)['autoplayIntervalMs'] = input;
      expect(
        TemplateDiscoveryDto.fromJson(document).page?.autoAdvanceInterval,
        Duration(milliseconds: expected),
      );
    });
  }

  test('malformed optional settings fall back without losing the feed', () {
    final document = _document()
      ..['page'] = {
        'title': 12,
        'subtitle': '',
        'searchEnabled': 'false',
        'carouselEnabled': [],
        'autoplayEnabled': null,
      };
    final discovery = TemplateDiscoveryDto.fromJson(document).toDomain();
    expect(discovery.page?.title, isNull);
    expect(discovery.page?.subtitle, '');
    expect(discovery.page?.searchEnabled, isTrue);
    expect(discovery.page?.carouselEnabled, isTrue);
    expect(discovery.page?.autoplayEnabled, isTrue);
    expect(discovery.sections, hasLength(1));
    expect(
      TemplateDiscoveryDto.fromJson({'sections': 'bad'}).sections,
      isEmpty,
    );
  });

  test('state replaces V2 configuration with legacy defaults atomically', () {
    final configured = const TemplateDiscoveryState().copyWith(
      discovery: TemplateDiscoveryDto.fromJson(_document()).toDomain(),
      hasLoaded: true,
    );
    expect(configured.carouselSections, isEmpty);
    expect(configured.railSections, hasLength(1));
    expect(configured.isEmpty, isFalse);
    expect(configured.copyWith(isRefreshing: true).page, same(configured.page));
    final legacy = configured.copyWith(
      discovery: TemplateDiscoveryDto.fromJson({
        'sections': [
          {'category': 'Funny', 'items': []},
        ],
      }).toDomain(),
    );
    expect(legacy.page, isNull);
    expect(legacy.revision, isNull);
    expect(legacy.carouselSections, hasLength(1));
  });

  test(
    'V2 cache round trip keeps settings and remains locale isolated',
    () async {
      final previous = SharedPreferencesAsyncPlatform.instance;
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      addTearDown(() => SharedPreferencesAsyncPlatform.instance = previous);
      final cache = TemplateDiscoveryCacheDataSource(SharedPreferencesAsync());
      final dto = TemplateDiscoveryDto.fromJson(_document());
      await cache.write(dto, localeTag: 'ru-RU');
      expect((await cache.read(localeTag: 'ru-RU'))?.toJson(), dto.toJson());
      expect(await cache.read(localeTag: 'en-US'), isNull);
    },
  );
}

Map<String, Object?> _document() => {
  'schemaVersion': 2,
  'revision': 42,
  'generatedAtUtc': '2026-09-05T08:00:00Z',
  'page': <String, Object?>{
    'title': 'Магия осени',
    'subtitle': 'Новые идеи',
    'searchEnabled': false,
    'carouselEnabled': true,
    'autoplayEnabled': false,
    'autoplayIntervalMs': 12000,
  },
  'sections': [
    {
      'category': 'Funny',
      'sectionId': 'section-1',
      'categoryId': 'category-1',
      'title': 'Смешные истории',
      'subtitle': 'Для вашего питомца',
      'showInCarousel': false,
      'showAsRail': true,
      'items': <Object?>[],
    },
  ],
};
