import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';

void main() {
  test(
    'same-version detail restores feed previews and retains detail metadata',
    () {
      final detail = _detail(animatedPreviewUrl: '  ');

      final hydrated = detail.withFeedMediaFrom(_feed());

      expect(hydrated.thumbnailUrl, 'https://cdn.example.com/feed-thumb.webp');
      expect(hydrated.animatedPreviewUrl, 'https://cdn.example.com/feed.webp');
      expect(hydrated.feedLoopLowUrl, 'https://cdn.example.com/low.mp4');
      expect(hydrated.feedLoopMediumUrl, 'https://cdn.example.com/medium.mp4');
      expect(_detailMetadata(hydrated), _detailMetadata(detail));
    },
  );

  test(
    'explicit detail URLs win and only missing derivatives are restored',
    () {
      final detail = _detail(
        thumbnailUrl: 'https://cdn.example.com/detail-thumb.webp',
        feedLoopLowUrl: 'https://cdn.example.com/detail-low.mp4',
      );

      final hydrated = detail.withFeedMediaFrom(_feed());

      expect(hydrated.thumbnailUrl, detail.thumbnailUrl);
      expect(hydrated.feedLoopLowUrl, detail.feedLoopLowUrl);
      expect(hydrated.animatedPreviewUrl, 'https://cdn.example.com/feed.webp');
      expect(hydrated.feedLoopMediumUrl, 'https://cdn.example.com/medium.mp4');
      expect(_detailMetadata(hydrated), _detailMetadata(detail));
    },
  );

  test(
    'positive catalog version can match the effective feed media version',
    () {
      final detail = _detail(mediaVersion: null, version: 7);

      final hydrated = detail.withFeedMediaFrom(_feed());

      expect(hydrated.feedLoopLowUrl, 'https://cdn.example.com/low.mp4');
      // Retain the feed's cache key when an older detail contract omits it.
      expect(hydrated.mediaVersion, 7);
      expect(hydrated.version, 7);
    },
  );

  test('different template or media version cannot restore old feed URLs', () {
    final details = [
      _detail(id: 'other-template'),
      _detail(mediaVersion: 8),
      _detail(mediaVersion: 6),
      _detail(mediaVersion: 0),
      _detail(mediaVersion: null, version: 0),
    ];

    for (final detail in details) {
      expect(identical(detail.withFeedMediaFrom(_feed()), detail), isTrue);
      expect(detail.feedLoopLowUrl, isNull);
    }
  });

  test(
    'unknown versions and missing feed URLs preserve the detail instance',
    () {
      final unversioned = _detail(mediaVersion: null, version: 0);
      expect(
        identical(unversioned.withFeedMediaFrom(unversioned), unversioned),
        isTrue,
      );
      final detail = _detail();
      expect(identical(detail.withFeedMediaFrom(_detail()), detail), isTrue);
    },
  );
}

TemplateItem _feed() => const TemplateItem(
  templateId: 'template-1',
  templateType: TemplateType.video,
  title: 'Feed title',
  shortDescription: '',
  petPhotoRequirements: [],
  category: '',
  tags: [],
  isPremium: false,
  tokenCost: 1,
  thumbnailUrl: 'https://cdn.example.com/feed-thumb.webp',
  animatedPreviewUrl: 'https://cdn.example.com/feed.webp',
  feedLoopLowUrl: 'https://cdn.example.com/low.mp4',
  feedLoopMediumUrl: 'https://cdn.example.com/medium.mp4',
  detailPreviewUrl: 'https://cdn.example.com/feed-detail.mp4',
  mediaVersion: 7,
  version: 7,
);

TemplateItem _detail({
  String id = 'template-1',
  int? mediaVersion = 7,
  int version = 11,
  String? thumbnailUrl,
  String? animatedPreviewUrl,
  String? feedLoopLowUrl,
}) => TemplateItem(
  templateId: id,
  templateType: TemplateType.video,
  title: 'Detailed title',
  shortDescription: 'Detailed description',
  petPhotoRequirements: const ['Full body', 'Visible face'],
  category: 'Motion',
  tags: const ['Playful', 'Portrait'],
  isPremium: true,
  tokenCost: 50,
  effectivePromoBadge: 'New',
  thumbnailUrl: thumbnailUrl,
  animatedPreviewUrl: animatedPreviewUrl,
  feedLoopLowUrl: feedLoopLowUrl,
  detailPreviewUrl: 'https://cdn.example.com/detail.mp4',
  mediaKind: 'video',
  durationMs: 5300,
  sizeBytes: 5000000,
  mediaVersion: mediaVersion,
  previewAsset: const TemplateAsset(
    url: 'https://cdn.example.com/detail.mp4',
    fileName: 'detail.mp4',
    contentType: 'video/mp4',
    fileSizeBytes: 5000000,
    durationSeconds: 5.3,
  ),
  musicDescription: 'Soft music',
  referenceVideoDurationSeconds: 5.3,
  supportsGenerationResultInput: true,
  requiredInputMediaType: TemplateType.image,
  recommendedAfterImageGeneration: true,
  supportsGenerateSimilar: false,
  defaultVariationStrength: 'high',
  version: version,
  updatedAtUtc: DateTime.utc(2026, 9, 5),
);

List<Object?> _detailMetadata(TemplateItem item) => [
  item.templateId,
  item.templateType,
  item.title,
  item.shortDescription,
  item.petPhotoRequirements,
  item.category,
  item.tags,
  item.isPremium,
  item.tokenCost,
  item.effectivePromoBadge,
  item.detailPreviewUrl,
  item.mediaKind,
  item.durationMs,
  item.sizeBytes,
  item.mediaVersion,
  item.previewAsset,
  item.musicDescription,
  item.referenceVideoDurationSeconds,
  item.supportsGenerationResultInput,
  item.requiredInputMediaType,
  item.recommendedAfterImageGeneration,
  item.supportsGenerateSimilar,
  item.defaultVariationStrength,
  item.version,
  item.updatedAtUtc,
];
