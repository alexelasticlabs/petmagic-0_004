import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('template presentation avoids uncached Image.network widgets', () async {
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
      expect(
        source,
        isNot(contains('Image.network(')),
        reason:
            '${file.path} should use CachedNetworkImage or a bounded '
            'provider path for remote media.',
      );
    }
  });

  test(
    'template card fallback image path remains cached and bounded',
    () async {
      final source = await File(
        'lib/features/templates/presentation/widgets/template_card.dart',
      ).readAsString();

      expect(source, contains('CachedNetworkImage('));
      expect(source, contains('memCacheWidth: cacheWidth'));
      expect(source, contains('maxWidthDiskCache: cacheWidth'));
      expect(source, contains('filterQuality: FilterQuality.medium'));
    },
  );

  test('active generation shell thumbnail is cached at thumbnail size', () async {
    final source = await File(
      'lib/shared/navigation/petmagic_shell.dart',
    ).readAsString();

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
    expect(actionsSource, contains('parseSafeGenerationMediaUri(outputUrl)'));
    expect(actionsSource, contains('ClipboardData(text: safeUri.toString())'));
    expect(cardsSource, isNot(contains('imageUrl: previewImageUrl!')));
  });

  test(
    'selected local pet photo preview decodes to bounded thumbnail size',
    () async {
      final source = await File(
        'lib/features/templates/presentation/widgets/template_flow_sheets.dart',
      ).readAsString();

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

  test('template blocked balance sheet keeps a lazy scroll surface', () async {
    final source = await File(
      'lib/features/templates/presentation/widgets/template_flow_sheets.dart',
    ).readAsString();

    expect(source, contains('child: ListView('));
    expect(source, contains('shrinkWrap: true'));
    expect(source, isNot(contains('SingleChildScrollView(')));
  });
}
