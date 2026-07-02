import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_models.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';
import 'package:petmagic_mobile/features/templates/presentation/generation_history_controller.dart';
import 'package:petmagic_mobile/features/templates/presentation/mappers/generations_gallery_mappers.dart';

void main() {
  final text = lookupAppLocalizations(const Locale('en'));

  group('generations gallery mappers', () {
    test('subtitleForFilter maps every gallery filter', () {
      expect(
        subtitleForFilter(text, GenerationHistoryFilter.all),
        text.generationStatusSubtitleAll,
      );
      expect(
        subtitleForFilter(text, GenerationHistoryFilter.active),
        text.generationStatusSubtitleActive,
      );
      expect(
        subtitleForFilter(text, GenerationHistoryFilter.ready),
        text.generationStatusSubtitleReady,
      );
      expect(
        subtitleForFilter(text, GenerationHistoryFilter.failed),
        text.generationStatusSubtitleFailed,
      );
    });

    test('stage and ETA labels use progress, stage, and estimate data', () {
      final queued = _generation(
        status: TemplateGenerationStatus.queued,
        stage: 'queued',
      );
      expect(stageStatusLabel(text, queued), text.generationStatusStageQueued);
      expect(
        estimatedTimeLabel(text, queued),
        text.generationStatusEtaStartsSoon,
      );

      final processing = _generation(
        stage: 'processing',
        estimatedDurationLabel: '1 min',
      );
      expect(
        stageStatusLabel(text, processing),
        text.templateFlowStepCreateMagic,
      );
      expect(
        estimatedTimeLabel(text, processing),
        text.generationStatusEtaNotifyHint,
      );

      final finalizing = _generation(stage: 'processing', progressPercent: 95);
      expect(
        stageStatusLabel(text, finalizing),
        text.generationStatusEtaFinalizing,
      );
      expect(
        estimatedTimeLabel(text, finalizing),
        text.generationStatusEtaNotifyHint,
      );

      final providerQueued = _generation(
        status: TemplateGenerationStatus.providerQueued,
      );
      expect(
        stageStatusLabel(text, providerQueued),
        text.generationStatusStageQueued,
      );
      expect(
        estimatedTimeLabel(text, providerQueued),
        text.generationStatusEtaStartsSoon,
      );

      final providerProcessing = _generation(
        status: TemplateGenerationStatus.providerProcessing,
      );
      expect(
        stageStatusLabel(text, providerProcessing),
        text.templateFlowStepCreateMagic,
      );

      final importing = _generation(
        status: TemplateGenerationStatus.importingMedia,
      );
      expect(
        stageStatusLabel(text, importing),
        text.templateFlowStepFinalTouches,
      );
    });

    test(
      'failureReasonMessage separates photo quality failures from technical failures',
      () {
        expect(
          failureReasonMessage(
            text,
            _generation(
              status: TemplateGenerationStatus.failed,
              failureCode: 'pets.photo_quality_low',
            ),
          ),
          text.generationStatusFailurePhotoHint,
        );
        expect(
          failureReasonMessage(
            text,
            _generation(
              status: TemplateGenerationStatus.failed,
              failureMessage: 'No pet face was detected',
            ),
          ),
          text.generationStatusFailurePhotoHint,
        );
        expect(
          failureReasonMessage(
            text,
            _generation(
              status: TemplateGenerationStatus.failed,
              failureCode: 'generation.provider_timeout',
            ),
          ),
          text.generationStatusFailureTechnicalHint,
        );
      },
    );

    test(
      'type labels and status icons follow generation media and terminal status',
      () {
        expect(
          typeLabel(text, _generation(templateType: 'Image')),
          text.imageLabel,
        );
        expect(
          typeLabel(text, _generation(templateType: 'Video')),
          text.videoLabel,
        );
        expect(
          statusIcon(_generation(status: TemplateGenerationStatus.completed)),
          Icons.check_circle_rounded,
        );
        expect(
          statusIcon(_generation(status: TemplateGenerationStatus.failed)),
          Icons.error_outline_rounded,
        );
        expect(
          statusIcon(_generation(status: TemplateGenerationStatus.processing)),
          Icons.auto_awesome_rounded,
        );
      },
    );

    test(
      'previewUrl chooses image previews and avoids video outputs as thumbnails',
      () {
        final image = _generation(
          templateType: 'Image',
          outputUrl: ' https://cdn.petmagic.app/result.jpg ',
          sourceImageAsset: _asset('https://cdn.petmagic.app/source.jpg'),
          normalizedImageUrl: 'https://cdn.petmagic.app/normalized.jpg',
        );
        expect(previewUrl(image), 'https://cdn.petmagic.app/result.jpg');

        final imageWithResultPreview = _generation(
          templateType: 'Image',
          resultPreviewUrl: ' https://cdn.petmagic.app/result-thumb.jpg ',
          outputUrl: 'https://cdn.petmagic.app/result-original.jpg',
        );
        expect(
          previewUrl(imageWithResultPreview),
          'https://cdn.petmagic.app/result-thumb.jpg',
        );

        final videoWithResultPreview = _generation(
          templateType: 'Video',
          resultPreviewUrl: 'https://cdn.petmagic.app/video-thumb.jpg',
          sourceImageAsset: _asset('https://cdn.petmagic.app/source.jpg'),
          outputUrl: 'https://cdn.petmagic.app/result.mp4',
        );
        expect(
          previewUrl(videoWithResultPreview),
          'https://cdn.petmagic.app/video-thumb.jpg',
        );

        final videoWithSource = _generation(
          templateType: 'Video',
          sourceImageAsset: _asset('https://cdn.petmagic.app/source.jpg'),
          normalizedImageUrl: 'https://cdn.petmagic.app/normalized.jpg',
          outputUrl: 'https://cdn.petmagic.app/result.mp4',
        );
        expect(
          previewUrl(videoWithSource),
          'https://cdn.petmagic.app/source.jpg',
        );

        final videoWithNormalized = _generation(
          templateType: 'Video',
          normalizedImageUrl: 'https://cdn.petmagic.app/normalized.jpg',
          outputUrl: 'https://cdn.petmagic.app/result.mp4',
        );
        expect(
          previewUrl(videoWithNormalized),
          'https://cdn.petmagic.app/normalized.jpg',
        );

        final videoOnly = _generation(
          templateType: 'Video',
          outputUrl: 'https://cdn.petmagic.app/result.mp4',
        );
        expect(previewUrl(videoOnly), isNull);

        final opaqueVideoOutput = _generation(
          templateType: 'Video',
          outputUrl: 'https://cdn.petmagic.app/result',
        );
        expect(previewUrl(opaqueVideoOutput), isNull);

        final videoPosterOnly = _generation(
          templateType: 'Video',
          outputUrl: 'https://cdn.petmagic.app/poster.jpg',
        );
        expect(
          previewUrl(videoPosterOnly),
          'https://cdn.petmagic.app/poster.jpg',
        );
      },
    );

    test('previewUrl rejects unsafe media URLs before image rendering', () {
      final unsafeImage = _generation(
        templateType: 'Image',
        outputUrl: 'javascript:alert(1)',
        sourceImageAsset: _asset('data:image/png;base64,AAAA'),
        normalizedImageUrl: 'file:///tmp/pet.png',
      );
      expect(previewUrl(unsafeImage), isNull);

      final unsafeVideo = _generation(
        templateType: 'Video',
        sourceImageAsset: _asset('javascript:alert(1)'),
        normalizedImageUrl: 'data:image/png;base64,AAAA',
        outputUrl: 'https://cdn.petmagic.app/result.mp4',
      );
      expect(previewUrl(unsafeVideo), isNull);

      expect(canRenderImagePreview('javascript:alert(1).jpg'), isFalse);
      expect(canRenderImagePreview('data:image/png;base64,AAAA'), isFalse);
      expect(canRenderImagePreview('file:///tmp/pet.jpg'), isFalse);
    });

    test(
      'video detection respects media type, duration, extension, and query hints',
      () {
        expect(isVideoGeneration(_generation(templateType: 'VIDEO')), isTrue);
        expect(
          isVideoGeneration(
            _generation(
              templateType: 'Image',
              outputVideoDurationSeconds: 2.5,
              outputUrl: 'https://cdn.petmagic.app/result.jpg',
            ),
          ),
          isTrue,
        );
        expect(
          isVideoGeneration(
            _generation(
              templateType: 'Image',
              outputUrl:
                  'https://cdn.petmagic.app/result.jpg?contentType=video',
            ),
          ),
          isTrue,
        );
        expect(
          isVideoGeneration(
            _generation(
              templateType: 'Image',
              outputUrl: 'https://cdn.petmagic.app/result.jpg?format=mp4',
            ),
          ),
          isTrue,
        );
        expect(
          canRenderImagePreview('https://cdn.petmagic.app/result.mp4'),
          isFalse,
        );
        expect(
          canRenderImagePreview(
            'https://cdn.petmagic.app/result.jpg?contentType=video',
          ),
          isFalse,
        );
        expect(
          canRenderImagePreview(' https://cdn.petmagic.app/result.jpg '),
          isTrue,
        );
        expect(canRenderImagePreview('   '), isFalse);
      },
    );

    test(
      'formattedDate uses locale-aware full dates outside today/yesterday',
      () async {
        await initializeDateFormatting();
        final value = DateTime.utc(2020, 1, 5, 9, 7);

        final english = formattedDate(text, value, const Locale('en'));
        final russian = formattedDate(
          lookupAppLocalizations(const Locale('ru')),
          value,
          const Locale('ru'),
        );

        expect(english, isNot('05.01.2020, 09:07'));
        expect(russian, isNot('05.01.2020, 09:07'));
        expect(english, isNot(russian));
        expect(english, contains('2020'));
        expect(russian, contains('2020'));
      },
    );
  });
}

TemplateGenerationResult _generation({
  TemplateGenerationStatus status = TemplateGenerationStatus.processing,
  String? templateType = 'Image',
  String? stage,
  int? progressPercent,
  String? estimatedDurationLabel,
  TemplateAsset? sourceImageAsset,
  String? normalizedImageUrl,
  String? resultPreviewUrl,
  String? outputUrl,
  double? outputVideoDurationSeconds,
  String? failureCode,
  String? failureMessage,
}) {
  final now = DateTime.utc(2026, 6, 15, 12);
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
    templateType: templateType,
    stage: stage,
    progressPercent: progressPercent,
    estimatedDurationLabel: estimatedDurationLabel,
    sourceImageAsset: sourceImageAsset,
    normalizedImageUrl: normalizedImageUrl,
    resultPreviewUrl: resultPreviewUrl,
    outputUrl: outputUrl,
    outputVideoDurationSeconds: outputVideoDurationSeconds,
    failureCode: failureCode,
    failureMessage: failureMessage,
  );
}

TemplateAsset _asset(String url, {String contentType = 'image/jpeg'}) {
  final value = url.trim();
  final uri = Uri.tryParse(value);
  return TemplateAsset(
    url: value,
    fileName: uri == null || uri.pathSegments.isEmpty
        ? 'asset.jpg'
        : uri.pathSegments.last,
    contentType: contentType,
  );
}
