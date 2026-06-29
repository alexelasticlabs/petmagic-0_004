import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'template flow sheet uses app localizations instead of locale branches',
    () async {
      final sheetSource = await File(
        'lib/features/templates/presentation/widgets/template_flow_sheets.dart',
      ).readAsString();
      final contentSource = await File(
        'lib/features/templates/presentation/widgets/template_flow_sheets_content.part.dart',
      ).readAsString();

      expect(sheetSource, isNot(contains('_isRussian(')));
      expect(contentSource, isNot(contains('_isRussian(')));
      expect(sheetSource, isNot(contains('Preview coming soon')));
      expect(sheetSource, contains('templateDetailHeroImageTitle'));
      expect(sheetSource, contains('templateDetailPreviewMissingTitle'));
      expect(contentSource, contains('AppLocalizations.of(context)'));
    },
  );

  test(
    'template flow premium gates use localized copy instead of ru branches',
    () async {
      final sheetSource = await File(
        'lib/features/templates/presentation/widgets/template_flow_sheets.dart',
      ).readAsString();
      final contentSource = await File(
        'lib/features/templates/presentation/widgets/template_flow_sheets_content.part.dart',
      ).readAsString();
      final cardSource = await File(
        'lib/features/templates/presentation/widgets/template_card.dart',
      ).readAsString();
      final cardPresentationSource = await File(
        'lib/features/templates/presentation/widgets/template_card_presentation.part.dart',
      ).readAsString();
      final fullCardSource = '$cardSource\n$cardPresentationSource';

      expect(
        sheetSource,
        isNot(contains("languageCode.toLowerCase() == 'ru'")),
      );
      expect(
        contentSource,
        isNot(contains("languageCode.toLowerCase() == 'ru'")),
      );
      expect(cardSource, isNot(contains("languageCode.toLowerCase() == 'ru'")));
      expect(
        sheetSource,
        contains('templateFlowInsufficientBalanceUpsellMessage'),
      );
      expect(contentSource, contains('templateFlowCompletedPremiumHeadline'));
      expect(contentSource, contains('templateFlowCompletedPremiumMessage'));
      expect(
        cardSource,
        contains("part 'template_card_presentation.part.dart';"),
      );
      expect(cardSource, isNot(contains('class _TemplateShadeOverlay')));
      expect(fullCardSource, contains('templateFlowPreviewUnavailable'));
      expect(fullCardSource, contains('supportChatTodayLabel'));
      expect(fullCardSource, isNot(contains('Preview unavailable')));
      expect(fullCardSource, isNot(contains('Превью недоступно')));
      expect(contentSource, isNot(contains('Video is ready! 🎉')));
      expect(contentSource, isNot(contains('Видео готово! 🎉')));
    },
  );

  test('templates domain secondary flows use shared localizations', () async {
    final gallerySource = await File(
      'lib/features/templates/presentation/generations_gallery_page_filters_and_chrome.dart',
    ).readAsString();
    final resultInputSource = await File(
      'lib/features/templates/presentation/generation_result_input_page.dart',
    ).readAsString();
    final petLaunchSource = await File(
      'lib/features/templates/presentation/widgets/pet_generation_launch_sheet.dart',
    ).readAsString();
    final petLaunchContentSource = await File(
      'lib/features/templates/presentation/widgets/pet_generation_launch_sheet_content.part.dart',
    ).readAsString();
    final fullPetLaunchSource = '$petLaunchSource\n$petLaunchContentSource';
    final templateOfDaySource = await File(
      'lib/features/templates/presentation/widgets/template_of_the_day_card.dart',
    ).readAsString();

    expect(
      gallerySource,
      isNot(contains("languageCode.toLowerCase() == 'ru'")),
    );
    expect(resultInputSource, isNot(contains("localeName.startsWith('ru')")));
    expect(petLaunchSource, isNot(contains("localeName.startsWith('ru')")));
    expect(templateOfDaySource, isNot(contains("languageCode == 'ru'")));

    expect(gallerySource, contains('galleryPremiumUpsellTitle'));
    expect(gallerySource, contains('galleryPremiumUpsellSubtitle'));
    expect(resultInputSource, contains('generationResultInputTitle'));
    expect(resultInputSource, contains('generationResultInputCostEstimate'));
    expect(
      petLaunchSource,
      contains("part 'pet_generation_launch_sheet_content.part.dart';"),
    );
    expect(petLaunchSource, isNot(contains('class _PetLaunchHeader')));
    expect(fullPetLaunchSource, contains('petGenerationLaunchTitleWithName'));
    expect(templateOfDaySource, contains('templateOfTheDayLoadFailed'));

    expect(fullPetLaunchSource, isNot(contains('Magic generation launch')));
    expect(fullPetLaunchSource, isNot(contains('Запуск магии')));
    expect(resultInputSource, isNot(contains('Use result')));
    expect(resultInputSource, isNot(contains('Использовать результат')));
  });

  test(
    'mobile localizations do not keep removed coming soon legacy keys',
    () async {
      const arbFiles = <String>[
        'lib/l10n/app_en.arb',
        'lib/l10n/app_ru.arb',
        'lib/l10n/app_de.arb',
        'lib/l10n/app_es.arb',
        'lib/l10n/app_fr.arb',
        'lib/l10n/app_it.arb',
        'lib/l10n/app_pl.arb',
      ];
      const removedKeys = <String>[
        'authForgotPasswordComingSoon',
        'authSocialComingSoon',
        'templateActionComingSoon',
        'tokensActionComingSoon',
        'rewardsActionComingSoon',
      ];

      for (final path in arbFiles) {
        final source = await File(path).readAsString();
        for (final key in removedKeys) {
          expect(
            source,
            isNot(contains('"$key"')),
            reason: '$path still contains $key',
          );
        }
      }
    },
  );

  test(
    'template flow gate localization keys exist in every supported locale',
    () async {
      const arbFiles = <String>[
        'lib/l10n/app_en.arb',
        'lib/l10n/app_ru.arb',
        'lib/l10n/app_de.arb',
        'lib/l10n/app_es.arb',
        'lib/l10n/app_fr.arb',
        'lib/l10n/app_it.arb',
        'lib/l10n/app_pl.arb',
      ];
      const requiredKeys = <String>[
        'templateFlowInsufficientBalanceUpsellMessage',
        'templateFlowCompletedPremiumHeadline',
        'templateFlowCompletedPremiumMessage',
      ];

      for (final path in arbFiles) {
        final source = await File(path).readAsString();
        for (final key in requiredKeys) {
          expect(source, contains('"$key"'), reason: '$path is missing $key');
        }
      }
    },
  );

  test(
    'templates domain secondary localization keys exist in every supported locale',
    () async {
      const arbFiles = <String>[
        'lib/l10n/app_en.arb',
        'lib/l10n/app_ru.arb',
        'lib/l10n/app_de.arb',
        'lib/l10n/app_es.arb',
        'lib/l10n/app_fr.arb',
        'lib/l10n/app_it.arb',
        'lib/l10n/app_pl.arb',
      ];
      const requiredKeys = <String>[
        'templateOfTheDayLoadFailed',
        'galleryPremiumUpsellTitle',
        'galleryPremiumUpsellSubtitle',
        'generationResultInputTitle',
        'generationResultInputParentTitle',
        'generationResultInputParentHint',
        'generationResultInputMediaUnavailable',
        'generationResultInputRecommendedBadge',
        'generationResultInputEmpty',
        'generationResultInputError',
        'generationResultInputNoCredits',
        'generationResultInputStartAction',
        'generationResultInputCostEstimate',
        'closeAction',
        'petGenerationLaunchTitle',
        'petGenerationLaunchTitleWithName',
        'petGenerationLaunchSubtitle',
        'petGenerationLaunchPhotoSectionTitle',
        'petGenerationLaunchSelectedPhotoLabel',
        'petGenerationLaunchUploadPhotoAction',
        'petGenerationLaunchChoosePhotoTitle',
        'petGenerationLaunchLoadingPhotos',
        'petGenerationLaunchPhotoLoadError',
        'petGenerationLaunchSelectedPhotoMissing',
        'petGenerationLaunchPhotoTypeError',
        'petGenerationLaunchUploadError',
        'petGenerationLaunchStartError',
      ];

      for (final path in arbFiles) {
        final source = await File(path).readAsString();
        for (final key in requiredKeys) {
          expect(source, contains('"$key"'), reason: '$path is missing $key');
        }
      }
    },
  );
}
