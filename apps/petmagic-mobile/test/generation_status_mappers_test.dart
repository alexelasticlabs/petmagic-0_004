import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
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

    testWidgets('queued status does not require backend stage duplication', (
      tester,
    ) async {
      late AppLocalizations text;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              text = AppLocalizations.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(
        statusTitle(
          text,
          _generation(status: TemplateGenerationStatus.queued, stage: null),
        ),
        text.generationStatusStageQueued,
      );
    });

    testWidgets('async provider statuses use public waiting labels', (
      tester,
    ) async {
      late AppLocalizations text;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              text = AppLocalizations.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(
        statusTitle(
          text,
          _generation(status: TemplateGenerationStatus.providerQueued),
        ),
        text.generationStatusStageQueued,
      );
      expect(
        etaLabel(
          text,
          _generation(
            status: TemplateGenerationStatus.providerQueued,
            queuePosition: 3,
            estimatedWaitSeconds: 180,
          ),
        ),
        text.generationStatusEtaEstimated(
          text.generationStatusQueuePositionWithWait(
            3,
            text.generationStatusWaitMinutes(3),
          ),
        ),
      );
      expect(
        statusTitle(
          text,
          _generation(status: TemplateGenerationStatus.providerProcessing),
        ),
        text.templateFlowStepCreateMagic,
      );
      expect(
        statusTitle(
          text,
          _generation(status: TemplateGenerationStatus.importingMedia),
        ),
        text.templateFlowStepFinalTouches,
      );

      final preprocessingProviderQueued = _generation(
        status: TemplateGenerationStatus.providerQueued,
        stage: 'preprocess_provider_queued',
        queuePosition: 2,
      );
      expect(
        statusTitle(text, preprocessingProviderQueued),
        text.templateFlowStepProcessPhoto,
      );
      expect(
        etaLabel(text, preprocessingProviderQueued),
        text.generationStatusEtaDefault,
      );

      final preprocessingProviderProcessing = _generation(
        status: TemplateGenerationStatus.providerProcessing,
        stage: 'preprocess_provider_processing',
      );
      expect(
        statusTitle(text, preprocessingProviderProcessing),
        text.templateFlowStepProcessPhoto,
      );

      final videoProviderQueued = _generation(
        status: TemplateGenerationStatus.providerQueued,
        stage: 'video_provider_queued',
        queuePosition: 2,
      );
      expect(
        statusTitle(text, videoProviderQueued),
        text.templateFlowStepCreateMagic,
      );
      expect(
        etaLabel(text, videoProviderQueued),
        text.generationStatusEtaDefault,
      );

      final videoProviderProcessing = _generation(
        status: TemplateGenerationStatus.providerProcessing,
        stage: 'video_provider_processing',
      );
      expect(
        statusTitle(text, videoProviderProcessing),
        text.templateFlowStepCreateMagic,
      );
    });

    testWidgets('ETA ignores backend English duration fallback', (
      tester,
    ) async {
      late AppLocalizations text;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('ru'),
          home: Builder(
            builder: (context) {
              text = AppLocalizations.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(
        etaLabel(
          text,
          _generation(
            status: TemplateGenerationStatus.providerQueued,
            estimatedDurationLabel: 'Usually under 1 minute',
          ),
        ),
        text.generationStatusEtaStartsSoon,
      );
      expect(
        etaLabel(
          text,
          _generation(
            status: TemplateGenerationStatus.queued,
            queuePosition: 1,
            estimatedWaitSeconds: 0,
          ),
        ),
        text.generationStatusEtaStartsSoon,
      );
    });

    test('photo failures are identified without changing generic retry', () {
      expect(
        isPhotoFailure(
          _generationWithFailure(failureCode: 'source_photo_invalid'),
        ),
        true,
      );
      expect(
        isPhotoFailure(_generationWithFailure(failureCode: 'provider_timeout')),
        false,
      );
    });
  });
}

TemplateGenerationResult _generationWithFailure({required String failureCode}) {
  final now = DateTime.utc(2026, 6, 15, 12);
  return TemplateGenerationResult(
    generationId: 'generation-1',
    userId: 'user-1',
    templateId: 'template-1',
    status: TemplateGenerationStatus.failed,
    tokenCost: 3,
    attemptCount: 1,
    createdAtUtc: now,
    updatedAtUtc: now,
    userMediaExpired: false,
    failureCode: failureCode,
  );
}

TemplateGenerationResult _generation({
  String? templateType = 'Image',
  String? outputUrl,
  double? outputVideoDurationSeconds,
  TemplateGenerationStatus status = TemplateGenerationStatus.completed,
  String? stage,
  int? queuePosition,
  int? estimatedWaitSeconds,
  String? estimatedDurationLabel,
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
    queuePosition: queuePosition,
    estimatedWaitSeconds: estimatedWaitSeconds,
    estimatedDurationLabel: estimatedDurationLabel,
    outputUrl: outputUrl,
    outputVideoDurationSeconds: outputVideoDurationSeconds,
  );
}
