import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pet generation launch sheet uses explicit pet photo error keys', () {
    final source = File(
      'lib/features/templates/presentation/widgets/pet_generation_launch_sheet.dart',
    ).readAsStringSync();

    expect(source, contains('_normalizePetLaunchErrorKey(error.message)'));
    expect(source, contains('normalizeTemplateErrorKey(error.message)'));
    expect(source, contains('templateFlowPremiumRequiredError'));
    expect(source, contains('templateFlowActiveGenerationLimitError'));
    expect(source, contains('templateFlowServerError'));
    expect(source, contains("'pets.photo_not_found'"));
    expect(source, contains("'pets.photo_required'"));
    expect(source, contains("'pets.photo_type_not_allowed'"));
    expect(
      source,
      isNot(
        contains(
          "message.contains('unavailable') || message.contains('photo')",
        ),
      ),
    );
  });

  test('pet generation launch sheet disables creation for an unusable photo', () {
    final source = File(
      'lib/features/templates/presentation/widgets/pet_generation_launch_sheet.dart',
    ).readAsStringSync();

    expect(
      source,
      contains('_petPhotoDisplayUrl(selectedPhotoForStart) == null'),
    );
    expect(source, contains(': () => _start(selectedPhotoForStart);'));
    expect(source, contains('selectedPhotoPreviewFailed ||'));
    expect(source, contains('onPreviewLoadFailed: _markPreviewLoadFailed'));
  });

  test('pet generation launch sheet reports selected preview failures', () {
    final mediaSource = File(
      'lib/features/templates/presentation/widgets/'
      'pet_generation_launch_sheet_media.part.dart',
    ).readAsStringSync();

    expect(mediaSource, contains('onImageLoadFailed(selectedPhoto)'));
    expect(mediaSource, contains('_reportImageLoadFailure();'));
  });

  test('pet generation launch sheet strips signed pet photo cache keys', () {
    final mediaSource = File(
      'lib/features/templates/presentation/widgets/'
      'pet_generation_launch_sheet_media.part.dart',
    ).readAsStringSync();

    expect(
      mediaSource,
      contains('cacheKey: persistentSafeGenerationMediaUrl(imageUrl)'),
    );
    expect(
      mediaSource,
      isNot(contains('cacheKey: persistentSafeProfileAvatarUrl(imageUrl)')),
    );
  });

  test('pet generation launch sheet bounds pet photo disk cache', () {
    final mediaSource = File(
      'lib/features/templates/presentation/widgets/'
      'pet_generation_launch_sheet_media.part.dart',
    ).readAsStringSync();

    expect(
      mediaSource,
      contains('const int _petLaunchSelectedPhotoPreviewCacheWidth = 760;'),
    );
    expect(
      mediaSource,
      contains('const int _petLaunchPhotoThumbnailCacheWidth = 180;'),
    );
    expect(
      mediaSource,
      contains('memCacheWidth: _petLaunchSelectedPhotoPreviewCacheWidth'),
    );
    expect(
      mediaSource,
      contains('maxWidthDiskCache: _petLaunchSelectedPhotoPreviewCacheWidth'),
    );
    expect(
      mediaSource,
      contains('memCacheWidth: _petLaunchPhotoThumbnailCacheWidth'),
    );
    expect(
      mediaSource,
      contains('maxWidthDiskCache: _petLaunchPhotoThumbnailCacheWidth'),
    );
  });

  test('pet generation launch header uses theme contrast for accent icon', () {
    final contentSource = File(
      'lib/features/templates/presentation/widgets/'
      'pet_generation_launch_sheet_content.part.dart',
    ).readAsStringSync();

    expect(contentSource, contains('color: colors.on(colors.accent)'));
    expect(
      contentSource,
      isNot(
        contains(
          'Icons.auto_awesome_rounded,\n            color: Colors.white',
        ),
      ),
    );
  });
}
