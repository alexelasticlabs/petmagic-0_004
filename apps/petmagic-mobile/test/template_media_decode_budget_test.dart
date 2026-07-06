import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/shared/files/persistent_media_url.dart';

import 'template_flow_sheets_test_source.dart';

import 'template_media_performance_test_support.dart';

void main() {
  configureTemplateMediaPerformanceHarness();

  test('generation share links strip signed URL secrets', () {
    final safeUrl = persistentSafeGenerationMediaUrl(
      'https://cdn.petmagic.test/generated.jpg?X-Amz-Signature=secret&token=raw#viewer',
    );

    expect(safeUrl, 'https://cdn.petmagic.test/generated.jpg');
    expect(safeUrl, isNot(contains('X-Amz-Signature')));
    expect(safeUrl, isNot(contains('token=raw')));
    expect(safeUrl, isNot(contains('viewer')));
  });

  test('persistent media urls strip unknown query values', () {
    final safeUrl = persistentSafeGenerationMediaUrl(
      'https://cdn.petmagic.test/generated.jpg?download=1&cache_buster=raw&auth=secret#viewer',
    );

    expect(safeUrl, 'https://cdn.petmagic.test/generated.jpg');
    expect(safeUrl, isNot(contains('download=1')));
    expect(safeUrl, isNot(contains('cache_buster=raw')));
    expect(safeUrl, isNot(contains('auth=secret')));
    expect(safeUrl, isNot(contains('viewer')));
  });

  test('template flow video preview is visibility-gated and cached', () async {
    final sheetSource = await File(
      'lib/features/templates/presentation/widgets/template_flow_sheets.dart',
    ).readAsString();
    final cardSource = await File(
      'lib/features/templates/presentation/widgets/template_card.dart',
    ).readAsString();
    final playbackManagerSource = await File(
      'lib/features/templates/presentation/template_feed_playback_manager.dart',
    ).readAsString();
    final controllerSource = await File(
      'lib/core/performance/template_preview_video_controller.dart',
    ).readAsString();
    final contentSource = await File(
      'lib/features/templates/presentation/widgets/template_flow_media_preview.part.dart',
    ).readAsString().then((source) => source.replaceAll('\r\n', '\n'));

    expect(cardSource, contains('VisibilityDetector('));
    expect(
      playbackManagerSource,
      contains('videoEligibilityVisibilityFraction'),
    );
    expect(
      cardSource,
      contains(
        "import 'package:petmagic_mobile/features/templates/presentation/template_feed_playback_manager.dart';",
      ),
    );
    expect(cardSource, contains('TemplateFeedDisplayLevel.videoPreview'));
    expect(
      cardSource,
      contains('widget.playbackManager?.updateCardVisibility('),
    );
    expect(
      playbackManagerSource,
      contains(
        "import 'package:petmagic_mobile/core/performance/media_lifecycle_policy.dart';",
      ),
    );
    expect(
      playbackManagerSource,
      contains('MediaLifecyclePolicy.tryAcquireVideoPreviewSlot('),
    );
    expect(
      playbackManagerSource,
      contains('MediaLifecyclePolicy.releaseVideoPreviewSlot()'),
    );
    expect(cardSource, contains('createTemplatePreviewVideoController('));
    expect(cardSource, contains('createCachedTemplatePreviewVideoController('));
    expect(cardSource, isNot(contains('VideoPlayerController.networkUrl(')));
    expect(
      controllerSource,
      contains('parseSafeGenerationMediaUri(previewUrl)'),
    );
    expect(
      controllerSource,
      contains("FormatException('unsafe_template_preview_url')"),
    );
    expect(controllerSource, isNot(contains('Uri.parse(previewUrl)')));

    expect(
      sheetSource,
      contains(
        "import 'package:visibility_detector/visibility_detector.dart';",
      ),
    );
    expect(
      sheetSource,
      contains(
        "import 'package:petmagic_mobile/core/performance/template_preview_video_controller.dart';",
      ),
    );
    expect(
      sheetSource,
      contains(
        "import 'package:petmagic_mobile/core/performance/media_lifecycle_policy.dart';",
      ),
    );
    expect(
      sheetSource,
      contains("part 'template_flow_media_preview.part.dart';"),
    );
    expect(contentSource, contains('useSharedPreviewCache: true'));
    expect(contentSource, contains('VisibilityDetector('));
    expect(contentSource, contains('_loadVisibilityFraction'));
    expect(contentSource, contains('_playVisibilityFraction'));
    expect(contentSource, contains('_disposeVideoController()'));
    expect(contentSource, contains('bool _hasPreviewSlot = false;'));
    expect(
      contentSource,
      contains('MediaLifecyclePolicy.tryAcquireVideoPreviewSlot()'),
    );
    expect(
      contentSource,
      contains('MediaLifecyclePolicy.releaseVideoPreviewSlot()'),
    );
    expect(contentSource, contains('void _releasePreviewSlot()'));
    expect(
      contentSource,
      contains('createCachedTemplatePreviewVideoController('),
    );
    expect(contentSource, contains('fallbackUri: safeUri'));
    expect(
      RegExp(
        r'_NetworkVideoPreview\(\s*url: safeAssetUrl,\s*useSharedPreviewCache: true,',
        multiLine: true,
      ).hasMatch(contentSource),
      isTrue,
    );
    expect(
      contentSource,
      contains(
        'if (!widget.useSharedPreviewCache) {\n'
        '      return VideoPlayerController.networkUrl(safeUri);\n'
        '    }\n'
        '\n'
        '    return createCachedTemplatePreviewVideoController(',
      ),
    );
  });

  test('active generation shell thumbnail is cached at thumbnail size', () async {
    final shellSource = await File(
      'lib/shared/navigation/petmagic_shell.dart',
    ).readAsString();
    final activeGenerationSource = await File(
      'lib/shared/navigation/petmagic_shell_active_generation.part.dart',
    ).readAsString();
    final source = '$shellSource\n$activeGenerationSource';

    expect(
      source,
      contains('const _activeGenerationThumbnailCacheWidth = 96;'),
    );
    expect(
      source,
      contains(
        'memCacheWidth:\n                                      _activeGenerationThumbnailCacheWidth',
      ),
    );
    expect(
      source,
      contains(
        'maxWidthDiskCache:\n                                      _activeGenerationThumbnailCacheWidth',
      ),
    );
    expect(source, contains('parseSafeGenerationMediaUri('));
    expect(source, contains('cacheKey: persistentSafeGenerationMediaUrl('));
    expect(source, contains('filterQuality: FilterQuality.medium'));
    expect(
      source,
      isNot(contains('final previewUrl = generation.sourceImageAsset?.url')),
    );
  });

  test('generation gallery media URLs are checked before preview or copy', () async {
    final gallerySource = await File(
      'lib/features/templates/presentation/generations_gallery_page.dart',
    ).readAsString();
    final cardsSource = await File(
      'lib/features/templates/presentation/generations_gallery_page_cards.dart',
    ).readAsString();
    final actionsSource = await File(
      'lib/features/templates/presentation/generations_gallery_page_states_and_actions.dart',
    ).readAsString();

    expect(
      gallerySource,
      contains(
        "import 'package:petmagic_mobile/shared/navigation/external_url_policy.dart';",
      ),
    );
    expect(cardsSource, contains('parseSafeGenerationMediaUri('));
    expect(cardsSource, contains('imageUrl: safePreviewImageUrl!'));
    expect(
      cardsSource,
      contains('const int _generationGalleryThumbnailCacheWidth = 320;'),
    );
    expect(
      cardsSource,
      contains(
        'cacheWidth:\n                                        _generationGalleryThumbnailCacheWidth',
      ),
    );
    expect(
      cardsSource,
      contains(
        'memCacheWidth:\n                                        _generationGalleryThumbnailCacheWidth',
      ),
    );
    expect(
      cardsSource,
      contains(
        'maxWidthDiskCache:\n                                        _generationGalleryThumbnailCacheWidth',
      ),
    );
    expect(cardsSource, contains('filterQuality: FilterQuality.medium'));
    expect(
      actionsSource,
      contains('parseSafeGenerationMediaUri(access.mediaUrl)'),
    );
    expect(actionsSource, contains('.fetchShareUrl('));
    expect(
      actionsSource,
      contains('parseSafeGenerationShareUri(access.shareUrl)'),
    );
    expect(actionsSource, contains('ClipboardData(text: safeUri.toString())'));
    expect(actionsSource, isNot(contains('ClipboardData(text: shareSafeUrl)')));
    expect(cardsSource, isNot(contains('imageUrl: previewImageUrl!')));
  });

  test(
    'template result share text does not expose signed media URLs',
    () async {
      final source = readTemplateFlowSheetsLibrarySource();

      expect(source, contains('final shareSafeUrl = outputUrl.isEmpty'));
      expect(source, contains('persistentSafeGenerationMediaUrl(outputUrl)'));
      expect(
        source,
        contains("ShareParams(text: '\${template.title}\\n\$shareSafeUrl')"),
      );
      expect(
        source,
        isNot(
          contains("ShareParams(text: '\${template.title}\\n\$outputUrl')"),
        ),
      );
    },
  );

  test(
    'selected local pet photo preview decodes to bounded thumbnail size',
    () async {
      final source = readTemplateFlowSheetsLibrarySource();

      expect(
        source,
        contains('const int _selectedPetPhotoPreviewCacheWidth = 288;'),
      );
      expect(
        source,
        contains('const int _selectedPetPhotoPreviewCacheHeight = 354;'),
      );
      expect(
        source,
        contains('cacheWidth: _selectedPetPhotoPreviewCacheWidth'),
      );
      expect(
        source,
        contains('cacheHeight: _selectedPetPhotoPreviewCacheHeight'),
      );
      expect(source, contains('filterQuality: FilterQuality.medium'));
    },
  );

  test('generation status result media decodes with bounded cache sizes', () async {
    final sectionsSource = readGenerationStatusSectionsLibrarySource();
    final fullscreenSource = await File(
      'lib/features/templates/presentation/generation_status_page_fullscreen_viewer.part.dart',
    ).readAsString();
    final compareSource = await File(
      'lib/features/templates/presentation/generation_status_page_compare_viewer.part.dart',
    ).readAsString();
    final source = '$sectionsSource\n$fullscreenSource\n$compareSource';

    expect(source, contains('const int _resultCardImageCacheWidth = 1080;'));
    expect(
      source,
      contains('const int _resultFullscreenImageCacheWidth = 1440;'),
    );
    expect(
      source,
      contains('const int _beforeAfterCompareImageCacheWidth = 1024;'),
    );
    expect(
      source,
      contains('ResizeImage(\n        FileImage(localOutputFile)'),
    );
    expect(source, contains('cacheWidth: _resultCardImageCacheWidth'));
    expect(source, contains('memCacheWidth: _resultCardImageCacheWidth'));
    expect(
      source,
      contains(
        'maxWidthDiskCache:\n                                        _resultCardImageCacheWidth',
      ),
    );
    expect(source, contains('cacheWidth: _resultFullscreenImageCacheWidth'));
    expect(source, contains('memCacheWidth: _resultFullscreenImageCacheWidth'));
    expect(
      source,
      contains('maxWidthDiskCache: _resultFullscreenImageCacheWidth'),
    );
    expect(source, contains('maxWidth: _beforeAfterCompareImageCacheWidth'));
    expect(source, contains('filterQuality: FilterQuality.medium'));
    expect(source, isNot(contains('memCacheWidth: 1080')));
    expect(source, isNot(contains('memCacheWidth: 1440')));
  });

  test(
    'generation result input media decodes with bounded cache sizes',
    () async {
      final source = await File(
        'lib/features/templates/presentation/generation_result_input_page.dart',
      ).readAsString();

      expect(source, contains('const int _parentPreviewCacheWidth = 900;'));
      expect(
        source,
        contains('const int _compatibleTemplateThumbnailCacheWidth = 240;'),
      );
      expect(source, contains('memCacheWidth: _parentPreviewCacheWidth'));
      expect(source, contains('maxWidthDiskCache: _parentPreviewCacheWidth'));
      expect(
        source,
        contains('memCacheWidth: _compatibleTemplateThumbnailCacheWidth'),
      );
      expect(
        source,
        contains(
          'maxWidthDiskCache:\n                              _compatibleTemplateThumbnailCacheWidth',
        ),
      );
      expect(source, contains('filterQuality: FilterQuality.medium'));
      expect(source, isNot(contains('memCacheWidth: 900')));
      expect(source, isNot(contains('memCacheWidth: 240')));
    },
  );

  test('template blocked balance sheet keeps a lazy scroll surface', () async {
    final source = readTemplateFlowSheetsLibrarySource();

    expect(source, contains('child: ListView('));
    expect(source, contains('shrinkWrap: true'));
    expect(source, isNot(contains('SingleChildScrollView(')));
  });
}
