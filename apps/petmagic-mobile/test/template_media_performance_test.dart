import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'template_media_performance_test_support.dart';

void main() {
  configureTemplateMediaPerformanceHarness();

  test(
    'template presentation keeps network images bounded or cached',
    () async {
      final dartFiles = await Directory('lib/features/templates/presentation')
          .list(recursive: true)
          .where((entity) {
            return entity is File && entity.path.endsWith('.dart');
          })
          .cast<File>()
          .toList();

      expect(dartFiles, isNotEmpty);

      for (final file in dartFiles) {
        final source = await file.readAsString();
        if (!source.contains('Image.network(')) {
          continue;
        }

        expect(source, contains('cacheWidth:'));
        expect(source, contains('errorBuilder:'));
        expect(
          source,
          anyOf(
            contains('TemplateMediaCache.fetchThumbnailFile('),
            contains('CachedNetworkImage('),
          ),
          reason:
              '${file.path} may use Image.network only as a bounded fallback '
              'after trying a cached media path.',
        );
      }
    },
  );

  test(
    'template card fallback image path remains cached and bounded',
    () async {
      final source = await File(
        'lib/features/templates/presentation/widgets/template_card.dart',
      ).readAsString();

      expect(source, contains('parseSafeGenerationMediaUri(candidate)'));
      expect(source, isNot(contains('widget.template.previewAsset!.url;')));
      expect(
        source,
        isNot(
          contains(
            '_normalizeTemplateMediaUrl(widget.template.previewAsset!.url) ??',
          ),
        ),
      );
      expect(source, contains('TemplateMediaCache.fetchThumbnailFile'));
      expect(source, isNot(contains('thumbnailCache.getSingleFile(')));
      expect(source, contains('Image.file('));
      expect(source, isNot(contains('Image.network(')));
      expect(source, contains('TemplateMediaCache.removeThumbnailFile'));
      expect(source, contains('cacheWidth: widget.cacheWidth'));
      expect(source, contains('filterQuality: FilterQuality.medium'));
    },
  );

  test(
    'template card image decode width stays bounded for invalid constraints',
    () async {
      final source = await File(
        'lib/features/templates/presentation/widgets/template_card.dart',
      ).readAsString();

      expect(source, contains('final int imageCacheWidth;'));
      expect(
        source,
        contains('int templateCardImageCacheWidthForLogicalWidth('),
      );
      expect(
        source,
        contains('const int _defaultTemplateCardImageCacheWidth = 720;'),
      );
      expect(source, contains('return _defaultTemplateCardImageCacheWidth;'));
      expect(
        source,
        contains(
          '.clamp(_minTemplateCardImageCacheWidth, _maxTemplateCardImageCacheWidth)',
        ),
      );
      expect(source, contains('cacheWidth: imageCacheWidth'));
    },
  );

  test('templates feed keeps a lazy paged sliver grid surface', () async {
    final source = readTemplatesPageLibrarySource();

    expect(source, contains('SliverGrid.builder('));
    expect(source, contains('itemCount: visibleEntries.length'));
    expect(source, contains('itemBuilder: (context, index)'));
    expect(source, contains('_buildFeaturedTemplateGridEntry('));
    expect(source, contains('_templatesController.loadMore()'));
    expect(source, isNot(contains('GridView.count(')));
    expect(source, isNot(contains('children: state.items.map')));
  });

  test('template cards cache thumbnails at bounded size', () async {
    final source = await File(
      'lib/features/templates/presentation/widgets/template_card.dart',
    ).readAsString();

    expect(source, contains('TemplateMediaCache.fetchThumbnailFile'));
    expect(source, contains('templateCardImageCacheWidthForLogicalWidth('));
    expect(source, contains('cacheWidth: widget.cacheWidth'));
    expect(source, contains('Image.file('));
    expect(source, contains('filterQuality: FilterQuality.medium'));
  });

  test('template page pet shortcut avatar is cached at bounded size', () async {
    final source = await File(
      'lib/features/templates/presentation/widgets/create_with_pet_block.dart',
    ).readAsString();

    expect(source, contains('const int _petShortcutAvatarCacheWidth = 64;'));
    expect(source, contains('memCacheWidth: _petShortcutAvatarCacheWidth'));
    expect(source, contains('maxWidthDiskCache: _petShortcutAvatarCacheWidth'));
    expect(source, contains('filterQuality: FilterQuality.medium'));
  });

  test('template of the day preview is split and visibility gated', () async {
    final mainSource = await File(
      'lib/features/templates/presentation/widgets/template_of_the_day_card.dart',
    ).readAsString();
    final chromeSource = await File(
      'lib/features/templates/presentation/widgets/template_of_the_day_card_chrome.part.dart',
    ).readAsString();
    final mediaSource = await File(
      'lib/features/templates/presentation/widgets/template_of_the_day_card_media.part.dart',
    ).readAsString();
    final fullSource = '$mainSource\n$chromeSource\n$mediaSource';

    expect(
      mainSource,
      contains("part 'template_of_the_day_card_chrome.part.dart';"),
    );
    expect(
      mainSource,
      contains("part 'template_of_the_day_card_media.part.dart';"),
    );
    expect(mainSource, contains('TemplatePreviewImage('));
    expect(mainSource, contains('_templateMediaCacheDimension('));
    expect(mainSource, isNot(contains('class _TemplateOfTheDayDarkOverlay')));
    expect(mainSource, isNot(contains('class TemplateOfTheDayVideoPreview')));
    expect(chromeSource, contains('class _TemplateOfTheDayDarkOverlay'));
    expect(chromeSource, contains('class _TemplateOfTheDayBadge'));
    expect(mediaSource, contains('class TemplateOfTheDayVideoPreview'));
    expect(mediaSource, contains('VisibilityDetector('));
    expect(
      mediaSource,
      contains('MediaLifecyclePolicy.tryAcquireVideoPreviewSlot()'),
    );
    expect(
      mediaSource,
      contains('createCachedTemplatePreviewVideoController('),
    );
    expect(fullSource, contains('parseSafeGenerationMediaUri('));
    expect(fullSource, isNot(contains('VideoPlayerController.networkUrl(')));
  });

  test('template card video preview is visibility gated and cached', () async {
    final source = await File(
      'lib/features/templates/presentation/widgets/template_card.dart',
    ).readAsString();
    final playbackManagerSource = await File(
      'lib/features/templates/presentation/template_feed_playback_manager.dart',
    ).readAsString();

    expect(
      source,
      contains(
        "import 'package:petmagic_mobile/core/performance/template_preview_video_controller.dart';",
      ),
    );
    expect(
      source,
      contains(
        "import 'package:petmagic_mobile/features/templates/presentation/template_feed_playback_manager.dart';",
      ),
    );
    expect(
      source,
      contains("import 'package:video_player/video_player.dart';"),
    );
    expect(
      source,
      contains(
        "import 'package:visibility_detector/visibility_detector.dart';",
      ),
    );
    expect(source, contains('_ensureVideoController()'));
    expect(source, contains('widget.template.previewAsset'));
    expect(source, contains('VisibilityDetector('));
    expect(
      playbackManagerSource,
      contains('videoEligibilityVisibilityFraction'),
    );
    expect(source, contains('widget.playbackManager?.updateCardVisibility('));
    expect(source, contains('TemplateFeedDisplayLevel.videoPreview'));
    expect(source, contains('snapshot?.mediaVersion'));
    expect(
      source,
      contains(
        'AppLifecycleSignal.instance.addListener(_appLifecycleListener);',
      ),
    );
    expect(
      source,
      contains(
        'AppLifecycleSignal.instance.removeListener(_appLifecycleListener);',
      ),
    );
    expect(source, contains('AppLifecycleState.resumed'));
    expect(source, contains('_disposeVideoController()'));
    expect(source, isNot(contains('bool _hasPreviewSlot = false;')));
    expect(
      playbackManagerSource,
      contains('MediaLifecyclePolicy.tryAcquireVideoPreviewSlot('),
    );
    expect(
      playbackManagerSource,
      contains('MediaLifecyclePolicy.releaseVideoPreviewSlot()'),
    );
    expect(source, contains('createCachedTemplatePreviewVideoController('));
    expect(source, contains('await controller.setVolume(0);'));
    expect(source, contains('await controller.setLooping(true);'));
    expect(source, contains('TemplateMediaCache.fetchThumbnailFile'));
  });

  test('template media caches use bounded object counts and app TTL', () async {
    final source = await File(
      'lib/core/performance/template_media_cache.dart',
    ).readAsString();
    final presentationSource =
        await Directory('lib/features/templates/presentation')
            .list(recursive: true)
            .where((entity) => entity is File && entity.path.endsWith('.dart'))
            .cast<File>()
            .asyncMap((file) => file.readAsString())
            .join('\n');

    expect(source, contains('stalePeriod: AppConfig.mediaCacheStalePeriod'));
    expect(source, contains('maxNrOfCacheObjects: 300'));
    expect(source, contains('maxNrOfCacheObjects: 80'));
    expect(
      source,
      contains(
        'typedef _RememberedFilesByUrl = LinkedHashMap<String, _RememberedCacheFile>;',
      ),
    );
    expect(
      source,
      contains(
        'typedef _InvalidationCountsByUrl = LinkedHashMap<String, int>;',
      ),
    );
    expect(
      source,
      contains('typedef _FetchGenerationsByUrl = LinkedHashMap<String, int>;'),
    );
    expect(
      source,
      contains('typedef _BlockedCacheUrls = LinkedHashSet<String>;'),
    );
    expect(source, contains('static final _RememberedFilesByUrl'));
    expect(source, contains('static final _InvalidationCountsByUrl'));
    expect(source, contains('static final _FetchGenerationsByUrl'));
    expect(source, contains('static final _BlockedCacheUrls'));
    expect(source, contains('final DateTime validTill;'));
    expect(
      source,
      contains('!rememberedFile.validTill.isAfter(DateTime.now())'),
    );
    expect(source, contains('!cachedFile.validTill.isAfter(DateTime.now())'));
    expect(source, contains('_maxThumbnailFileReferences = 300'));
    expect(
      source,
      contains('_maxBlockedThumbnailCacheUrls = _maxThumbnailFileReferences'),
    );
    expect(
      source,
      contains('_maxBlockedPreviewCacheUrls = _maxPreviewFileReferences'),
    );
    expect(source, contains('_thumbnailInvalidationByUrl.clear();'));
    expect(source, contains('_previewInvalidationByUrl.clear();'));
    expect(source, contains('_latestThumbnailFetchGenerationByUrl.clear();'));
    expect(source, contains('_latestPreviewFetchGenerationByUrl.clear();'));
    expect(source, contains('_rememberLatestFetchGeneration('));
    expect(source, contains('_canInvalidateCompletedFetch('));
    expect(source, contains('_trimInvalidationMap('));
    expect(source, contains('_trimBlockedCacheUrls('));
    expect(source, contains('_blockedThumbnailCacheUrls.remove(url);'));
    expect(source, contains('_blockedPreviewCacheUrls.remove(url);'));
    expect(source, contains('AppConfig.mediaCacheMaxBytesSafe'));
    expect(source, contains('_scheduleThumbnailBudgetCleanup(file.parent)'));
    expect(source, contains('thumbnail_budget_cleanup'));
    expect(
      presentationSource,
      isNot(contains('thumbnailCache.getSingleFile(')),
    );
  });

  test('app startup installs a bounded decoded image cache budget', () async {
    final mainSource = await File('lib/main.dart').readAsString();
    final appSource = await File('lib/app/app.dart').readAsString();
    final budgetSource = await File(
      'lib/core/performance/decoded_image_cache_budget.dart',
    ).readAsString();

    expect(mainSource, contains('configureDecodedImageCacheBudget();'));
    expect(budgetSource, contains('cache.maximumSize ='));
    expect(budgetSource, contains('cache.maximumSizeBytes ='));
    expect(budgetSource, contains('AppConfig.decodedImageCacheMaxObjectsSafe'));
    expect(budgetSource, contains('AppConfig.decodedImageCacheMaxBytesSafe'));
    expect(budgetSource, contains('trimDecodedImageCache();'));
    expect(appSource, contains('DecodedImageCacheLifecycleObserver('));
  });
}
