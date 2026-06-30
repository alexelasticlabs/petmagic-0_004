import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'template_flow_sheets_test_source.dart';

void main() {
  test(
    'template flow sheet uses app localizations instead of locale branches',
    () async {
      final sheetSource = readTemplateFlowSheetsLibrarySource();
      final contentSource = await File(
        'lib/features/templates/presentation/widgets/template_flow_sheets_content.part.dart',
      ).readAsString();
      final generationSource = await File(
        'lib/features/templates/presentation/widgets/template_flow_sheets_generation.part.dart',
      ).readAsString();

      expect(sheetSource, isNot(contains('_isRussian(')));
      expect(contentSource, isNot(contains('_isRussian(')));
      expect(generationSource, isNot(contains('_isRussian(')));
      expect(sheetSource, isNot(contains('Preview coming soon')));
      expect(sheetSource, contains('templateDetailHeroImageTitle'));
      expect(sheetSource, contains('templateDetailPreviewMissingTitle'));
      expect(contentSource, contains('AppLocalizations.of(context)'));
      expect(
        generationSource,
        contains("part of 'template_flow_sheets.dart';"),
      );
    },
  );

  test(
    'template flow premium gates use localized copy instead of ru branches',
    () async {
      final sheetSource = readTemplateFlowSheetsLibrarySource();
      final contentSource = await File(
        'lib/features/templates/presentation/widgets/template_flow_sheets_content.part.dart',
      ).readAsString();
      final generationSource = await File(
        'lib/features/templates/presentation/widgets/template_flow_sheets_generation.part.dart',
      ).readAsString();
      final cardSource = await File(
        'lib/features/templates/presentation/widgets/template_card.dart',
      ).readAsString();
      final cardPresentationSource = await File(
        'lib/features/templates/presentation/widgets/template_card_presentation.part.dart',
      ).readAsString();
      final cardBadgesSource = await File(
        'lib/features/templates/presentation/widgets/template_card_badges.part.dart',
      ).readAsString();
      final fullCardSource =
          '$cardSource\n$cardPresentationSource\n$cardBadgesSource';

      expect(
        sheetSource,
        isNot(contains("languageCode.toLowerCase() == 'ru'")),
      );
      expect(
        contentSource,
        isNot(contains("languageCode.toLowerCase() == 'ru'")),
      );
      expect(
        generationSource,
        isNot(contains("languageCode.toLowerCase() == 'ru'")),
      );
      expect(cardSource, isNot(contains("languageCode.toLowerCase() == 'ru'")));
      expect(
        sheetSource,
        contains('templateFlowInsufficientBalanceUpsellMessage'),
      );
      expect(
        sheetSource,
        contains("part 'template_flow_sheets_generation.part.dart';"),
      );
      expect(
        contentSource,
        isNot(contains('class _TemplateGenerationProgressContent')),
      );
      expect(
        generationSource,
        contains('class _TemplateGenerationProgressContent'),
      );
      expect(
        generationSource,
        contains('templateFlowCompletedPremiumHeadline'),
      );
      expect(generationSource, contains('templateFlowCompletedPremiumMessage'));
      expect(cardSource, contains("part 'template_card_badges.part.dart';"));
      expect(
        cardSource,
        contains("part 'template_card_presentation.part.dart';"),
      );
      expect(cardSource, isNot(contains('class _TemplateShadeOverlay')));
      expect(cardPresentationSource, isNot(contains('class _PromoBadge')));
      expect(cardBadgesSource, contains("part of 'template_card.dart';"));
      expect(cardBadgesSource, contains('class _PromoBadge'));
      expect(cardBadgesSource, contains('class _AccessTag'));
      expect(fullCardSource, contains('templateFlowPreviewUnavailable'));
      expect(fullCardSource, contains('supportChatTodayLabel'));
      expect(fullCardSource, isNot(contains('Preview unavailable')));
      expect(fullCardSource, isNot(contains('Превью недоступно')));
      expect(generationSource, isNot(contains('Video is ready! 🎉')));
      expect(generationSource, isNot(contains('Видео готово! 🎉')));
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
    final petLaunchMediaSource = await File(
      'lib/features/templates/presentation/widgets/pet_generation_launch_sheet_media.part.dart',
    ).readAsString();
    final fullPetLaunchSource =
        '$petLaunchSource\n$petLaunchContentSource\n$petLaunchMediaSource';
    final templateOfDayMainSource = await File(
      'lib/features/templates/presentation/widgets/template_of_the_day_card.dart',
    ).readAsString();
    final templateOfDayChromeSource = await File(
      'lib/features/templates/presentation/widgets/template_of_the_day_card_chrome.part.dart',
    ).readAsString();
    final templateOfDayMediaSource = await File(
      'lib/features/templates/presentation/widgets/template_of_the_day_card_media.part.dart',
    ).readAsString();
    final templateOfDaySource =
        '$templateOfDayMainSource\n$templateOfDayChromeSource\n$templateOfDayMediaSource';
    final statusSource = await File(
      'lib/features/templates/presentation/generation_status_page.dart',
    ).readAsString();
    final activeStatusCardSource = await File(
      'lib/features/templates/presentation/generation_status_page_active_card.part.dart',
    ).readAsString();
    final galleryCardsSource = await File(
      'lib/features/templates/presentation/generations_gallery_page_cards.dart',
    ).readAsString();
    final randomTemplateSheetSource = await File(
      'lib/features/templates/presentation/widgets/random_template_sheet.dart',
    ).readAsString();
    final randomTemplateContentSource = await File(
      'lib/features/templates/presentation/widgets/random_template_sheet_content.part.dart',
    ).readAsString();
    final randomTemplateComponentsSource = await File(
      'lib/features/templates/presentation/widgets/random_template_sheet_components.part.dart',
    ).readAsString();
    final fullRandomTemplateSource =
        '$randomTemplateSheetSource\n$randomTemplateContentSource\n$randomTemplateComponentsSource';

    expect(
      gallerySource,
      isNot(contains("languageCode.toLowerCase() == 'ru'")),
    );
    expect(resultInputSource, isNot(contains("localeName.startsWith('ru')")));
    expect(petLaunchSource, isNot(contains("localeName.startsWith('ru')")));
    expect(
      randomTemplateSheetSource,
      contains("part 'random_template_sheet_components.part.dart';"),
    );
    expect(
      randomTemplateSheetSource,
      contains("part 'random_template_sheet_content.part.dart';"),
    );
    expect(
      petLaunchSource,
      contains("part 'pet_generation_launch_sheet_media.part.dart';"),
    );
    expect(
      templateOfDayMainSource,
      contains("part 'template_of_the_day_card_chrome.part.dart';"),
    );
    expect(
      templateOfDayMainSource,
      contains("part 'template_of_the_day_card_media.part.dart';"),
    );
    expect(templateOfDaySource, isNot(contains("languageCode == 'ru'")));
    expect(
      templateOfDayMainSource,
      isNot(contains('class _TemplateOfTheDayDarkOverlay')),
    );
    expect(
      templateOfDayMainSource,
      isNot(contains('class TemplateOfTheDayVideoPreview')),
    );
    expect(
      templateOfDayChromeSource,
      contains("part of 'template_of_the_day_card.dart';"),
    );
    expect(
      templateOfDayMediaSource,
      contains("part of 'template_of_the_day_card.dart';"),
    );

    expect(gallerySource, contains('galleryPremiumUpsellTitle'));
    expect(gallerySource, contains('galleryPremiumUpsellSubtitle'));
    expect(resultInputSource, contains('generationResultInputTitle'));
    expect(resultInputSource, contains('generationResultInputCostEstimate'));
    expect(resultInputSource, contains('walletBalanceUnit'));
    expect(resultInputSource, contains('text.retryAction'));
    expect(
      petLaunchSource,
      contains("part 'pet_generation_launch_sheet_content.part.dart';"),
    );
    expect(
      petLaunchContentSource,
      isNot(contains('class _PetLaunchSelectedPhotoPreview')),
    );
    expect(
      petLaunchMediaSource,
      contains("part of 'pet_generation_launch_sheet.dart';"),
    );
    expect(
      petLaunchMediaSource,
      contains('class _PetLaunchSelectedPhotoPreview'),
    );
    expect(
      randomTemplateSheetSource,
      isNot(contains('class _RandomTemplateSection')),
    );
    expect(
      randomTemplateSheetSource,
      isNot(contains('class _RandomTemplateStatusMessage')),
    );
    expect(
      randomTemplateContentSource,
      contains("part of 'random_template_sheet.dart';"),
    );
    expect(
      randomTemplateComponentsSource,
      contains("part of 'random_template_sheet.dart';"),
    );
    expect(
      randomTemplateContentSource,
      contains('class _RandomTemplateSheetContent'),
    );
    expect(
      randomTemplateComponentsSource,
      contains('class _RandomTemplateSection'),
    );
    expect(petLaunchSource, isNot(contains('class _PetLaunchHeader')));
    expect(fullPetLaunchSource, contains('petGenerationLaunchTitleWithName'));
    expect(fullPetLaunchSource, contains('text.walletBalanceUnit'));
    expect(fullPetLaunchSource, contains('text.videoLabel'));
    expect(fullPetLaunchSource, contains('text.imageLabel'));
    expect(
      fullRandomTemplateSource,
      contains('randomTemplateSheetDescription'),
    );
    expect(fullRandomTemplateSource, contains('randomTemplateAccessPremium'));
    expect(
      fullRandomTemplateSource,
      isNot(contains("languageCode.toLowerCase() == 'ru'")),
    );
    expect(templateOfDaySource, contains('templateOfTheDayLoadFailed'));
    expect(templateOfDaySource, contains('walletBalanceUnit'));
    expect(statusSource, contains('walletBalanceUnit'));
    expect(activeStatusCardSource, contains('walletBalanceUnit'));
    expect(galleryCardsSource, contains('walletBalanceUnit'));

    expect(fullPetLaunchSource, isNot(contains('Magic generation launch')));
    expect(fullPetLaunchSource, isNot(contains('Запуск магии')));
    expect(resultInputSource, isNot(contains('Use result')));
    expect(resultInputSource, isNot(contains('Использовать результат')));
    expect(resultInputSource, isNot(contains("const Text('Retry')")));
    expect(fullPetLaunchSource, isNot(contains("'Video'")));
    expect(fullPetLaunchSource, isNot(contains("'Image'")));
    expect(fullRandomTemplateSource, isNot(contains("'Retry'")));
  });

  test(
    'mobile localizations do not keep removed legacy placeholder keys',
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
        'comingSoonMessage',
        'profileDetailsSupportBody',
        'profileDetailsSupportStatus',
        'profileDetailsSupportNext',
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
