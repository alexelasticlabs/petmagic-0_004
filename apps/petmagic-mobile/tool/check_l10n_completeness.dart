import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  final root = Directory.current;
  final l10nDir = Directory('${root.path}/lib/l10n');
  final enFile = File('${l10nDir.path}/app_en.arb');

  if (!enFile.existsSync()) {
    stderr.writeln('Missing template locale file: ${enFile.path}');
    exitCode = 1;
    return;
  }

  final enMap = _readArb(enFile);
  final baseKeys = enMap.keys.where((key) => !key.startsWith('@')).toList()
    ..sort();

  const localeFiles = <String>[
    'app_ru.arb',
    'app_de.arb',
    'app_es.arb',
    'app_fr.arb',
    'app_it.arb',
    'app_pl.arb',
  ];

  const sameValueAllowlist = <String>{
    'achievementTrendsetter',
    'authAppleShortLabel',
    'authGoogleShortLabel',
    'emailVerificationCodeLabel',
    'gamificationEvolutionBaby',
    'gamificationLevel',
    'generationStatusCopyLinkAction',
    'imageLabel',
    'imagesFilter',
    'premiumCheckoutSummaryPlanLabel',
    'premiumCheckoutTotalLabel',
    'premiumLabel',
    'premiumPaymentApple',
    'premiumPaymentGooglePlay',
    'premiumPageTitle',
    'premiumPremiumColumn',
    'profileAccountAvatarLabel',
    'profileAccountRolesLabel',
    'profileEmailLabel',
    'profileNotificationsDeviceNotifications',
    'profileNotificationsDevicePhotos',
    'profilePasswordLabel',
    'profilePremiumOpenAction',
    'profileSettingsAccountSection',
    'profileLegalDocumentSection',
    'profileSettingsNotificationsSection',
    'profileSettingsThemeSystem',
    'profileStatBalanceLabel',
    'profileStatLegalLabel',
    'profileStatPlanLabel',
    'profileSubscriptionStatusLabel',
    'profileNotificationsEmailSection',
    'rewardsSourceBonus',
    'profileWalletPreviewEyebrow',
    'randomTemplateAccessPremium',
    'rewardsReferralInputHint',
    'subscriptionPaymentProviderGooglePlay',
    'supportChatArchiveAction',
    'supportChatAssistantBadge',
    'supportChatFileFallbackLabel',
    'supportChatFaqTitle',
    'supportChatTeamTitle',
    'startupMiniFeaturePetFirst',
    'templateDetailCategoryPortrait',
    'templateDetailCategoryVideo',
    'templateDetailFormatLabel',
    'templateDetailImageEta',
    'templateDetailVideoEta',
    'videoLabel',
    'videosFilter',
    'walletBalanceUnit',
    'walletApproxPhotos',
    'walletApproxPhotosOnly',
    'walletBalanceAfter',
    'walletPackBaseSpark',
    'walletPackBonus',
    'walletPackBonusPill',
    'walletPackBreakdown',
    'walletPackTotalSpark',
    'walletPurchaseSummary',
    'walletPopularBadge',
    'walletStripeCardBrandsLabel',
    'walletStripeWalletsLabel',
    'walletCheckoutTotalLabel',
  };

  var hasFailures = false;

  for (final localeFileName in localeFiles) {
    final file = File('${l10nDir.path}/$localeFileName');
    if (!file.existsSync()) {
      stderr.writeln('Missing locale file: ${file.path}');
      hasFailures = true;
      continue;
    }

    final localeMap = _readArb(file);
    final missingKeys = baseKeys
        .where((key) => !localeMap.containsKey(key))
        .toList(growable: false);
    final emptyKeys = baseKeys
        .where((key) => localeMap.containsKey(key))
        .where((key) {
          final value = localeMap[key];
          return value is String && value.trim().isEmpty;
        })
        .toList(growable: false);
    final sameValueKeys = baseKeys
        .where((key) => localeMap.containsKey(key) && enMap.containsKey(key))
        .where((key) {
          if (sameValueAllowlist.contains(key)) {
            return false;
          }

          final localValue = localeMap[key];
          final enValue = enMap[key];
          return localValue is String &&
              enValue is String &&
              localValue.trim() == enValue.trim();
        })
        .toList(growable: false);

    if (missingKeys.isNotEmpty ||
        emptyKeys.isNotEmpty ||
        sameValueKeys.isNotEmpty) {
      hasFailures = true;
      stdout.writeln('[$localeFileName]');

      if (missingKeys.isNotEmpty) {
        stdout.writeln('  missing: ${missingKeys.join(', ')}');
      }
      if (emptyKeys.isNotEmpty) {
        stdout.writeln('  empty: ${emptyKeys.join(', ')}');
      }
      if (sameValueKeys.isNotEmpty) {
        stdout.writeln('  english fallback: ${sameValueKeys.join(', ')}');
      }
    }
  }

  if (hasFailures) {
    stderr.writeln('Localization completeness check failed.');
    exitCode = 1;
    return;
  }

  stdout.writeln(
    'Localization completeness check passed (${baseKeys.length} keys).',
  );
}

Map<String, dynamic> _readArb(File file) {
  final raw = file.readAsStringSync();
  final decoded = jsonDecode(raw);

  if (decoded is! Map<String, dynamic>) {
    throw FormatException('Invalid ARB JSON object in ${file.path}');
  }

  return decoded;
}
