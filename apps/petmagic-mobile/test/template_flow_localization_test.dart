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
      final actionsSource = await File(
        'lib/features/templates/presentation/widgets/template_flow_sheets_actions.part.dart',
      ).readAsString();
      final blockedSource = await File(
        'lib/features/templates/presentation/widgets/template_flow_sheets_blocked.part.dart',
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
      expect(contentSource, contains('text.walletBalanceUnit'));
      expect(actionsSource, contains('onTopUpBalance'));
      expect(blockedSource, contains('onTopUpBalance'));
      expect(actionsSource, isNot(contains('onBuyPowSpark')));
      expect(blockedSource, isNot(contains('onBuyPowSpark')));
      expect(
        contentSource,
        isNot(contains("label: '\${template.tokenCost} PawSpark'")),
      );
      expect(
        contentSource,
        isNot(contains("value: '\${template.tokenCost} PawSpark'")),
      );
      expect(
        generationSource,
        contains("part of 'template_flow_sheets.dart';"),
      );
    },
  );

  test('template flow premium gates use localized copy instead of ru branches', () async {
    final sheetSource = readTemplateFlowSheetsLibrarySource();
    final contentSource = await File(
      'lib/features/templates/presentation/widgets/template_flow_sheets_content.part.dart',
    ).readAsString();
    final generationSource = await File(
      'lib/features/templates/presentation/widgets/template_flow_sheets_generation.part.dart',
    ).readAsString();
    final chromeSource = await File(
      'lib/features/templates/presentation/widgets/template_flow_sheets_chrome.part.dart',
    ).readAsString();
    final blockedSource = await File(
      'lib/features/templates/presentation/widgets/template_flow_sheets_blocked.part.dart',
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

    expect(sheetSource, isNot(contains("languageCode.toLowerCase() == 'ru'")));
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
    expect(generationSource, contains('templateFlowCompletedPremiumHeadline'));
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
    expect(cardBadgesSource, contains('colors.on(tone)'));
    expect(
      cardBadgesSource,
      contains('colors.on(isFeatured ? colors.gold : colors.accent)'),
    );
    expect(
      cardPresentationSource,
      contains('final foregroundColor = usePremiumStyle'),
    );
    expect(cardPresentationSource, contains('accent: colors.accent'));
    expect(cardPresentationSource, contains('accent: colors.gold'));
    expect(cardPresentationSource, contains(': colors.on(colors.accent);'));
    expect(cardPresentationSource, contains('color: foregroundColor'));
    expect(cardBadgesSource, contains('color: colors.blue'));
    expect(cardBadgesSource, contains('colors.gold.withValues(alpha: 0.5)'));
    expect(cardBadgesSource, contains('color: colors.gold'));
    expect(
      cardBadgesSource,
      isNot(contains('color: Colors.white,\n            fontSize: 9,')),
    );
    expect(cardBadgesSource, isNot(contains('color: Color(0xFF052317)')));
    expect(
      cardPresentationSource,
      isNot(contains('const premiumTextColor = Color(0xFF251102)')),
    );
    expect(cardPresentationSource, isNot(contains('const Color(0xFF22D394)')));
    expect(cardPresentationSource, isNot(contains('const Color(0xFFF5D679)')));
    expect(cardPresentationSource, isNot(contains('const Color(0xFF082313)')));
    expect(cardBadgesSource, isNot(contains('Color(0xFF46B0FF)')));
    expect(cardBadgesSource, isNot(contains('const Color(0xFFFFE89E)')));
    expect(fullCardSource, contains('templateFlowPreviewUnavailable'));
    expect(fullCardSource, contains('supportChatTodayLabel'));
    expect(
      cardBadgesSource,
      contains('Localizations.localeOf(context).toLanguageTag()'),
    );
    expect(
      cardBadgesSource,
      contains(
        'NumberFormat.decimalPattern(localeTag).format(popularityCount)',
      ),
    );
    expect(
      cardBadgesSource,
      contains(
        'NumberFormat.compact(locale: localeTag).format(popularityCount)',
      ),
    );
    expect(cardBadgesSource, isNot(contains("toStringAsFixed(1)")));
    expect(cardBadgesSource, isNot(contains("}k'")));
    expect(fullCardSource, isNot(contains('Preview unavailable')));
    expect(fullCardSource, isNot(contains('Превью недоступно')));
    expect(generationSource, isNot(contains('Video is ready! 🎉')));
    expect(generationSource, isNot(contains('Видео готово! 🎉')));
    expect(
      sheetSource,
      contains('context.petMagicColors.on(const Color(0xFFEAB13A))'),
    );
    expect(
      chromeSource,
      contains('context.petMagicColors.on(const Color(0xFFF3C65A))'),
    );
    expect(
      chromeSource,
      contains('context.petMagicColors.on(const Color(0xFFEFCB72))'),
    );
    expect(blockedSource, isNot(contains('color: Color(0xFF261903)')));
    expect(generationSource, isNot(contains('color: Color(0xFF261903)')));
    expect(chromeSource, isNot(contains('const ctaTextColor = Color')));
    expect(blockedSource, contains('final colors = context.petMagicColors;'));
    expect(
      generationSource,
      contains('final colors = context.petMagicColors;'),
    );
    expect(blockedSource, contains('color: colors.textStrong'));
    expect(generationSource, contains('color: colors.textStrong'));
    expect(blockedSource, contains('color: colors.textSoft'));
    expect(generationSource, contains('color: colors.textSoft'));
    expect(blockedSource, contains('color: colors.accent'));
    expect(blockedSource, contains('color: colors.gold'));
    for (final rawColor in const [
      'const Color(0xFF514325)',
      'const Color(0xFFE1DED4)',
      'const Color(0xFF1E1608)',
      'const Color(0xFFEDE7D8)',
      'const Color(0xFF3B3324)',
      'const Color(0xFFE3DFD2)',
      'const Color(0xFF2F2719)',
      'const Color(0xFFD7DFEF)',
      'const Color(0xFF0EA76A)',
      'const Color(0xFFBCB29B)',
      'const Color(0xFF2A3651)',
      'const Color(0xFF3C3222)',
      'const Color(0xFF3C3324)',
      'const Color(0xFFC6CEDD)',
    ]) {
      expect(blockedSource, isNot(contains(rawColor)));
      expect(generationSource, isNot(contains(rawColor)));
    }
  });

  test('template flow high-load rejection uses dedicated safe UX copy', () async {
    final sheetSource = readTemplateFlowSheetsLibrarySource();
    final generationSource = await File(
      'lib/features/templates/presentation/widgets/template_flow_sheets_generation.part.dart',
    ).readAsString();

    expect(generationSource, contains('GenerationWaitTooLongException'));
    expect(generationSource, contains('queueRejection'));
    expect(
      generationSource,
      contains('templateFlowGenerationWaitTooLongTitle'),
    );
    expect(
      generationSource,
      contains('templateFlowGenerationWaitTooLongMessage'),
    );
    expect(
      generationSource,
      contains('templateFlowGenerationWaitTooLongRetryAfter'),
    );
    expect(
      generationSource,
      contains('templateFlowGenerationWaitTooLongPremiumHint'),
    );
    expect(generationSource, contains('walletControllerProvider'));
    expect(sheetSource, isNot(contains('ProblemDetails')));
    expect(sheetSource.toLowerCase(), isNot(contains('stack trace')));
    expect(sheetSource.toLowerCase(), isNot(contains('guarantee')));
  });

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
    expect(resultInputSource, contains('text.premiumLabel'));
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
    expect(templateOfDayChromeSource, contains('colors.gold'));
    expect(templateOfDayChromeSource, contains('colors.on(background)'));
    expect(templateOfDayChromeSource, isNot(contains('Color(0xFF251102)')));
    expect(templateOfDayChromeSource, isNot(contains('Color(0xFFEFC35C)')));
    expect(statusSource, contains('walletBalanceUnit'));
    expect(activeStatusCardSource, contains('walletBalanceUnit'));
    expect(galleryCardsSource, contains('walletBalanceUnit'));

    expect(fullPetLaunchSource, isNot(contains('Magic generation launch')));
    expect(fullPetLaunchSource, isNot(contains('Запуск магии')));
    expect(resultInputSource, isNot(contains('Use result')));
    expect(resultInputSource, isNot(contains('Использовать результат')));
    expect(resultInputSource, isNot(contains("_MiniBadge(label: 'Premium')")));
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
        'templateFlowGenerationWaitTooLongTitle',
        'templateFlowGenerationWaitTooLongMessage',
        'templateFlowGenerationWaitTooLongRetryAfter',
        'templateFlowGenerationWaitTooLongPremiumHint',
        'templateFlowActiveGenerationLimitError',
        'generationStatusCancelledTitle',
        'generationStatusCancelledMessage',
        'generationStatusCancelQueuedHint',
        'generationStatusCancelQueuedAction',
        'generationStatusCancelQueuedTitle',
        'generationStatusCancelQueuedMessage',
        'generationStatusCancelQueuedKeepAction',
        'generationStatusCancelQueuedConfirmAction',
        'generationStatusCancelQueuedSuccess',
        'generationStatusCancelQueuedAlreadyStarted',
        'generationStatusCancelQueuedFailed',
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
    'non-English template flow wait-localizations do not keep English fallback copy',
    () async {
      const localizedArbFiles = <String>[
        'lib/l10n/app_de.arb',
        'lib/l10n/app_es.arb',
        'lib/l10n/app_fr.arb',
        'lib/l10n/app_it.arb',
        'lib/l10n/app_pl.arb',
      ];

      for (final path in localizedArbFiles) {
        final source = await File(path).readAsString();
        expect(
          source,
          isNot(
            contains(
              '"generationStatusQueuedVideoHint": "Video usually takes longer than photos and can take a few minutes."',
            ),
          ),
          reason: '$path still contains English queued-video hint',
        );
        expect(
          source,
          isNot(
            contains(
              '"templateFlowGenerationWaitTooLongTitle": "High load right now"',
            ),
          ),
          reason: '$path still contains English high-load title',
        );
        expect(
          source,
          isNot(
            contains(
              '"generationStatusQueuePositionWithWait": "Queue position #{position}',
            ),
          ),
          reason: '$path still contains English queue position with wait',
        );
        expect(
          source,
          isNot(
            contains(
              '"generationStatusQueuePosition": "Queue position #{position}"',
            ),
          ),
          reason: '$path still contains English queue position',
        );
        expect(
          source,
          isNot(
            contains(
              '"templateFlowGenerationWaitTooLongPremiumHint": "Premium gets priority queue access and usually waits less."',
            ),
          ),
          reason: '$path still contains English Premium queue hint',
        );
        expect(
          source,
          isNot(
            contains(
              '"templateFlowGenerationWaitTooLongMessage": "The estimated wait for this generation is too long. Try again later or choose a photo generation, which is usually faster."',
            ),
          ),
          reason: '$path still contains English high-load message',
        );
        expect(
          source,
          isNot(
            contains(
              '"templateFlowGenerationWaitTooLongRetryAfter": "Try again in about {value}."',
            ),
          ),
          reason: '$path still contains English retry-after copy',
        );
        expect(
          source,
          isNot(
            contains(
              '"generationStatusStatusCancelled": "Generation cancelled"',
            ),
          ),
          reason: '$path still contains English cancelled title',
        );
        expect(
          source,
          isNot(
            contains(
              '"generationStatusTerminalCancelledHint": "Generation was cancelled before completion."',
            ),
          ),
          reason: '$path still contains English cancelled hint',
        );
        expect(
          source,
          isNot(
            contains(
              '"generationStatusCancelledTitle": "Generation cancelled"',
            ),
          ),
          reason: '$path still contains English cancelled card title',
        );
        expect(
          source,
          isNot(
            contains(
              '"generationStatusCancelledMessage": "This generation was stopped before processing started."',
            ),
          ),
          reason: '$path still contains English cancelled card message',
        );
        expect(
          source,
          isNot(
            contains(
              '"generationStatusCancelQueuedHint": "You can cancel while this generation is still waiting in queue."',
            ),
          ),
          reason: '$path still contains English cancel hint',
        );
        expect(
          source,
          isNot(
            contains(
              '"generationStatusCancelQueuedAction": "Cancel generation"',
            ),
          ),
          reason: '$path still contains English cancel action',
        );
        expect(
          source,
          isNot(
            contains(
              '"generationStatusCancelQueuedAlreadyStarted": "Generation already started and cannot be cancelled."',
            ),
          ),
          reason: '$path still contains English already-started message',
        );
        expect(
          source,
          isNot(
            contains(
              '"generationStatusCancelQueuedFailed": "Could not cancel generation. Please try again."',
            ),
          ),
          reason: '$path still contains English cancel failure message',
        );
      }

      final spanishSource = await File('lib/l10n/app_es.arb').readAsString();
      expect(
        spanishSource,
        isNot(contains('"walletRetryAction": "Rever"')),
        reason: 'Spanish wallet retry label still contains typo',
      );
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

  test(
    'remove-watermark localizations use PawSpark wording in every supported locale',
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

      final bodyPattern = RegExp(
        r'^  "generationStatusRemoveWatermarkSheetBody": ".*PawSpark.*",$',
        multiLine: true,
      );
      final actionPattern = RegExp(
        r'^  "generationStatusRemoveWatermarkUseCredit": ".*PawSpark.*",$',
        multiLine: true,
      );
      final emptyPattern = RegExp(
        r'^  "generationStatusRemoveWatermarkNoCredits": ".*PawSpark.*",$',
        multiLine: true,
      );

      for (final path in arbFiles) {
        final source = await File(path).readAsString();
        expect(
          bodyPattern.hasMatch(source),
          isTrue,
          reason: '$path missing PawSpark remove-watermark body',
        );
        expect(
          actionPattern.hasMatch(source),
          isTrue,
          reason: '$path missing PawSpark remove-watermark CTA',
        );
        expect(
          emptyPattern.hasMatch(source),
          isTrue,
          reason: '$path missing PawSpark remove-watermark empty-state',
        );
      }
    },
  );
}
