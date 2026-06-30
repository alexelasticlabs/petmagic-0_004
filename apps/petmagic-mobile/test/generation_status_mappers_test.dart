import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_models.dart';
import 'package:petmagic_mobile/features/templates/presentation/mappers/generation_status_mappers.dart';

void main() {
  group('generation status mappers', () {
    test(
      'video detection respects media type, duration, extension, and query hints',
      () {
        expect(isVideoGeneration(_generation(templateType: 'pet_video')), true);
        expect(
          isVideoGeneration(
            _generation(
              templateType: 'Image',
              outputVideoDurationSeconds: 2.5,
              outputUrl: 'https://cdn.petmagic.app/result.jpg',
            ),
          ),
          true,
        );
        expect(
          isVideoGeneration(
            _generation(
              templateType: 'Image',
              outputUrl:
                  'https://cdn.petmagic.app/result.jpg?contentType=video',
            ),
          ),
          true,
        );
        expect(
          isVideoGeneration(
            _generation(
              templateType: 'Image',
              outputUrl: 'https://cdn.petmagic.app/result.jpg?format=mp4',
            ),
          ),
          true,
        );
        expect(
          isVideoGeneration(
            _generation(
              templateType: 'Image',
              outputUrl: ' https://cdn.petmagic.app/result.mp4 ',
            ),
          ),
          true,
        );
        expect(
          isVideoGeneration(
            _generation(
              templateType: 'Image',
              outputUrl: 'https://cdn.petmagic.app/result.jpg',
            ),
          ),
          false,
        );
      },
    );

    test('generation date formatting respects the active locale', () async {
      await initializeDateFormatting();
      final value = DateTime.utc(2026, 1, 5, 9, 7);

      final english = formatGenerationDateTime(value, const Locale('en'));
      final russian = formatGenerationDateTime(value, const Locale('ru'));

      expect(english, isNot('05.01.2026, 09:07'));
      expect(russian, isNot('05.01.2026, 09:07'));
      expect(english, isNot(russian));
      expect(english, contains('2026'));
      expect(russian, contains('2026'));
    });
  });
}

TemplateGenerationResult _generation({
  String? templateType = 'Image',
  String? outputUrl,
  double? outputVideoDurationSeconds,
}) {
  final now = DateTime.utc(2026, 6, 15, 12);
  return TemplateGenerationResult(
    generationId: 'generation-1',
    userId: 'user-1',
    templateId: 'template-1',
    status: TemplateGenerationStatus.completed,
    tokenCost: 1,
    attemptCount: 1,
    createdAtUtc: now,
    updatedAtUtc: now,
    userMediaExpired: false,
    templateType: templateType,
    outputUrl: outputUrl,
    outputVideoDurationSeconds: outputVideoDurationSeconds,
  );
}
