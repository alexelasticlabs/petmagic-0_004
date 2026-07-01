import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/features/templates/domain/generation_media_kind.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_models.dart';

void main() {
  group('generation media kind', () {
    test(
      'classifies video generations from type, duration, extension, and query hints',
      () {
        expect(
          isVideoGenerationResult(
            _generation(
              status: TemplateGenerationStatus.queued,
              mediaType: 'video',
              templateType: null,
            ),
          ),
          isTrue,
        );
        expect(
          isVideoGenerationResult(_generation(templateType: 'pet_video')),
          isTrue,
        );
        expect(
          isVideoGenerationResult(
            _generation(
              templateType: 'image',
              outputVideoDurationSeconds: 2.5,
              outputUrl: 'https://cdn.petmagic.app/result.jpg',
            ),
          ),
          isTrue,
        );
        expect(
          isVideoGenerationResult(
            _generation(
              templateType: 'image',
              outputUrl: ' https://cdn.petmagic.app/result.mp4 ',
            ),
          ),
          isTrue,
        );
        expect(
          isVideoGenerationResult(
            _generation(
              templateType: 'image',
              outputUrl:
                  'https://cdn.petmagic.app/result.jpg?contentType=video',
            ),
          ),
          isTrue,
        );
        expect(
          isVideoGenerationResult(
            _generation(
              templateType: 'image',
              outputUrl: 'https://cdn.petmagic.app/result.jpg?format=mp4',
            ),
          ),
          isTrue,
        );
        expect(
          isVideoGenerationResult(
            _generation(
              templateType: 'image',
              outputUrl: 'https://cdn.petmagic.app/result.jpg',
            ),
          ),
          isFalse,
        );
      },
    );

    test(
      'classifies likely video URLs without requiring a generation model',
      () {
        expect(
          isLikelyGenerationVideoUrl('https://cdn.petmagic.app/result.webm'),
          isTrue,
        );
        expect(
          isLikelyGenerationVideoUrl(
            'https://cdn.petmagic.app/result.mov?sig=1',
          ),
          isTrue,
        );
        expect(
          isLikelyGenerationVideoUrl('https://cdn.petmagic.app/result.jpg'),
          isFalse,
        );
        expect(isLikelyGenerationVideoUrl('   '), isFalse);
        expect(isLikelyGenerationVideoUrl(null), isFalse);
      },
    );

    test(
      'classifies likely image URLs without treating opaque URLs as images',
      () {
        expect(
          isLikelyGenerationImageUrl('https://cdn.petmagic.app/result.jpg'),
          isTrue,
        );
        expect(
          isLikelyGenerationImageUrl(
            'https://cdn.petmagic.app/result.HEIC?sig=1',
          ),
          isTrue,
        );
        expect(
          isLikelyGenerationImageUrl('https://cdn.petmagic.app/result.mp4'),
          isFalse,
        );
        expect(
          isLikelyGenerationImageUrl('https://cdn.petmagic.app/result'),
          isFalse,
        );
        expect(isLikelyGenerationImageUrl('   '), isFalse);
        expect(isLikelyGenerationImageUrl(null), isFalse);
      },
    );
  });
}

TemplateGenerationResult _generation({
  TemplateGenerationStatus status = TemplateGenerationStatus.completed,
  String? mediaType,
  String? templateType = 'image',
  String? outputUrl,
  double? outputVideoDurationSeconds,
}) {
  final now = DateTime.utc(2026, 6, 16, 12);
  return TemplateGenerationResult(
    generationId: 'generation-1',
    userId: 'user-1',
    templateId: 'template-1',
    status: status,
    tokenCost: 1,
    attemptCount: 1,
    createdAtUtc: now,
    updatedAtUtc: now,
    userMediaExpired: false,
    mediaType: mediaType,
    templateType: templateType,
    outputUrl: outputUrl,
    outputVideoDurationSeconds: outputVideoDurationSeconds,
  );
}
