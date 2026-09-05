import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';
import 'package:petmagic_mobile/features/templates/presentation/template_preview_media_selection.dart';

void main() {
  for (final type in [TemplateType.image, TemplateType.video]) {
    test(
      'image preview loop alias never creates video for $type generation',
      () {
        final selection = TemplatePreviewMediaSelection(
          _template(
            type: type,
            kind: 'image',
            url: 'https://cdn.example.com/poster.webp',
          ),
          expand: true,
        );
        expect(selection.isVideo, isFalse);
        expect(selection.imageUrl, 'https://cdn.example.com/poster.webp');
        expect(selection.videoFallbackUrls, isEmpty);
        expect(selection.usesDetailImageCache, isFalse);
      },
    );
  }
  test('video media kind supports safe extensionless feed URLs', () {
    final selection = TemplatePreviewMediaSelection(
      _template(
        type: TemplateType.image,
        kind: 'video',
        url: 'https://cdn.example.com/preview',
      ),
      expand: true,
    );
    expect(selection.isVideo, isTrue);
    expect(selection.mediaUrl, 'https://cdn.example.com/preview');
  });
}

TemplateItem _template({
  required TemplateType type,
  required String kind,
  required String url,
}) => TemplateItem(
  templateId: 'legacy-media',
  templateType: type,
  title: 'Legacy preview',
  shortDescription: '',
  petPhotoRequirements: const [],
  category: 'Test',
  tags: const [],
  isPremium: false,
  tokenCost: 1,
  mediaKind: kind,
  thumbnailUrl: url,
  feedLoopLowUrl: url,
  previewAsset: TemplateAsset(
    url: url,
    fileName: 'preview',
    contentType: '$kind/${kind == 'image' ? 'webp' : 'mp4'}',
  ),
);
