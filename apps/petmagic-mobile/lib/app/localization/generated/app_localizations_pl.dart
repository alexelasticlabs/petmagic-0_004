// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Polish (`pl`).
class AppLocalizationsPl extends AppLocalizations {
  AppLocalizationsPl([String locale = 'pl']) : super(locale);

  @override
  String get navTemplates => 'Szablony';

  @override
  String get navCreations => 'Galeria';

  @override
  String get navProfile => 'Profil';

  @override
  String get comingSoonMessage =>
      'Ta sekcja jest przygotowana na kolejny etap produktu.';

  @override
  String get createMagicTitle => 'Stworz magie';

  @override
  String get pickTemplateSubtitle => 'Wybierz szablon dla swojego pupila';

  @override
  String get searchTemplates => 'Szukaj szablonow';

  @override
  String get allFilter => 'Wszystkie';

  @override
  String get videosFilter => 'Wideo';

  @override
  String get imagesFilter => 'Obrazy';

  @override
  String get trendingFilter => '🔥 Trendy';

  @override
  String get funnyFilter => '😂 Zabawne';

  @override
  String get danceFilter => '🕺 Taniec';

  @override
  String get magicFilter => '✣ Magia';

  @override
  String get adventureFilter => '🌄 Przygoda';

  @override
  String get filtersTooltip => 'Filtry';

  @override
  String get giftTooltip => 'Nagrody';

  @override
  String get addTokensTooltip => 'Dodaj PawSpark';

  @override
  String get premiumLabel => 'Premia';

  @override
  String get freeLabel => 'Bezpłatny';

  @override
  String get profileTitle => 'Twój profil';

  @override
  String get profileSubtitle =>
      'Zarządzaj logowaniem i swoim awatarem publicznym.';

  @override
  String get profileDashboardSubtitle =>
      'Zarządzaj swoim kontem i personalizuj swoje doświadczenie PetMagic.';

  @override
  String get profileSignInTitle => 'Zaloguj się, aby kontynuować';

  @override
  String get profileSignInHint =>
      'Użyj swojego konta PetMagic, aby załadować swój profil i zarządzać awatarem widocznym w panelu administracyjnym.';

  @override
  String get profileEmailLabel => 'E-mail';

  @override
  String get profilePasswordLabel => 'Hasło';

  @override
  String get profileSignInAction => 'Zalogować się';

  @override
  String get profileSignOutAction => 'Wyloguj się';

  @override
  String get profileLoadingAction => 'Pracujący...';

  @override
  String get profileAvatarUpload => 'Prześlij awatar';

  @override
  String get profileAvatarRemove => 'Usuń awatar';

  @override
  String get profileEmailConfirmed => 'E-mail potwierdzony';

  @override
  String get profileEmailPending => 'Adres e-mail nie został potwierdzony';

  @override
  String get profileEmailVerifiedShort => 'Email verified';

  @override
  String get profileEmailPendingShort => 'Verify email';

  @override
  String get profileSignedOut => 'Wylogowano się na tym urządzeniu.';

  @override
  String get profileAccountCenterTitle => 'Centrum kont';

  @override
  String get profileAccountCenterSubtitle =>
      'Sprawdź swoje preferencje, prywatność i konfigurację aplikacji.';

  @override
  String get profileTermsStat => 'Warunki zaakceptowane';

  @override
  String get profileMarketingStat => 'Oferty i aktualizacje';

  @override
  String get profileEmailStat => 'Stan e-maila';

  @override
  String get profileStatOn => 'NA';

  @override
  String get profileStatOff => 'Wyłączony';

  @override
  String get profileStatReady => 'Gotowy';

  @override
  String get profileStatPending => 'Aż do';

  @override
  String get profilePetsTitle => 'Moje zwierzaki';

  @override
  String get profilePetsSubtitle =>
      'Twoi ulubieni towarzysze i profile zwierząt.';

  @override
  String get profilePremiumTitle => 'Przejdź na Premium';

  @override
  String get profilePremiumSubtitle =>
      'Odblokuj wszystkie szablony i procesy edycji premium.';

  @override
  String get profilePremiumPlanLabel => 'Premium Plan';

  @override
  String get profileFreePlanLabel => 'Free Plan';

  @override
  String get profilePremiumBannerTitle => 'Upgrade to Premium';

  @override
  String get profilePremiumBannerActiveTitle => 'Premium active';

  @override
  String get profilePremiumBenefitUnlimitedTemplates => 'Unlimited templates';

  @override
  String get profilePremiumBenefitPriorityGeneration => 'Priority generation';

  @override
  String get profilePremiumBenefitNoWatermark => 'No watermark';

  @override
  String get profilePremiumOpenAction => 'Upgrade';

  @override
  String get profileSubscriptionTitle => 'My subscription';

  @override
  String get profileSubscriptionStatusLabel => 'Status';

  @override
  String get profileSubscriptionProviderLabel => 'Provider';

  @override
  String get profileSubscriptionNextBillingLabel => 'Next billing date';

  @override
  String get profileSubscriptionTokensLabel => 'Tokens available';

  @override
  String get profileWalletTitle => 'Wallet';

  @override
  String get profileWalletHistoryHint => 'Open balance, purchases and history.';

  @override
  String get walletPageTitle => 'PawSpark wallet';

  @override
  String get walletPageSubtitle =>
      'Balance, promo codes, ad bonus, and PawSpark top-ups.';

  @override
  String get profileWalletPreviewEyebrow => 'PawSpark';

  @override
  String get profileWalletPreviewSubtitle =>
      'In-app currency for generations and bonus rewards.';

  @override
  String get profileWalletPreviewAction => 'Open';

  @override
  String get profileWalletPreviewLoadingStatus => 'Refreshing status';

  @override
  String get profileWalletPreviewWeeklyReady => 'Weekly reward ready';

  @override
  String profileWalletPreviewAdCount(Object count) {
    return 'Ads today: $count';
  }

  @override
  String get profileWalletLoadingHint => 'Loading balance...';

  @override
  String get profileWalletEmptyHint => 'Open balance and history';

  @override
  String get walletDataUnavailableFallback =>
      'Wallet data is not available right now.';

  @override
  String get walletRefreshTooltip => 'Refresh wallet';

  @override
  String get walletBalanceTitle => 'Ready for photos and videos';

  @override
  String get walletBalanceEyebrow => 'Current balance';

  @override
  String get walletBalanceUnit => 'PawSpark';

  @override
  String get walletBalanceExplanation =>
      'PawSpark is spent only inside PetMagic: generations, bonus actions, and new formats.';

  @override
  String get walletPremiumStatus => 'Premium wallet';

  @override
  String get walletFreeStatus => 'Free wallet';

  @override
  String walletAdRewardsCount(Object count) {
    return '$count ad rewards';
  }

  @override
  String get walletQuickActionsTitle => 'Promo codes';

  @override
  String get walletRedeemAction => 'Redeem promo code';

  @override
  String get walletRewardsTitle => 'Ad bonus';

  @override
  String get walletAdRewardAction => 'Ad reward';

  @override
  String get walletAdRewardCompactTitle => 'Quick ad bonus';

  @override
  String get walletAdRewardCompactDescription =>
      'Watch a short ad and add PawSpark without paying.';

  @override
  String walletAdRewardRemaining(Object count) {
    return 'Left today: $count';
  }

  @override
  String get walletWatchAdAction => 'Watch ad';

  @override
  String get walletPromoTitle => 'Have a promo code?';

  @override
  String get walletPromoSubtitle =>
      'Enter a code from PetMagic and add PawSpark to your balance.';

  @override
  String get walletBuySparkTitle => 'Top up PawSpark';

  @override
  String walletPackTotalSpark(Object count) {
    return '$count PawSpark';
  }

  @override
  String get walletPopularBadge => 'Popular';

  @override
  String get walletBestValueLabel => 'Best value';

  @override
  String walletPackBonus(Object count) {
    return '+$count bonus';
  }

  @override
  String walletPackBonusPill(Object count) {
    return 'Bonus +$count';
  }

  @override
  String walletPackBaseSpark(Object count) {
    return '$count base';
  }

  @override
  String walletBuyForPrice(Object price) {
    return 'Buy for $price';
  }

  @override
  String get walletPackDetailsAction => 'Details';

  @override
  String get walletPackDetailSubtitle =>
      'Check what is included before opening checkout.';

  @override
  String get walletCheckoutHint =>
      'Payment opens in secure Stripe Checkout. PetMagic does not store your card details.';

  @override
  String walletCheckoutSucceeded(int spark) {
    return 'Payment confirmed. +$spark PawSpark is already in your wallet.';
  }

  @override
  String walletPackBreakdown(Object base, Object bonus) {
    return '$base base + $bonus bonus';
  }

  @override
  String get walletRecentTransactionsTitle => 'Recent transactions';

  @override
  String get walletNoActivity => 'No wallet activity yet.';

  @override
  String walletBalanceAfter(Object count) {
    return 'Bal. $count';
  }

  @override
  String get walletPurchaseHistoryTitle => 'Purchase history';

  @override
  String walletPurchaseSummary(Object count, Object date) {
    return '$count PawSpark • $date';
  }

  @override
  String get walletPurchaseJustConfirmed => 'Just confirmed';

  @override
  String get walletUnavailableTitle => 'Wallet is temporarily unavailable';

  @override
  String get walletTryAgainAction => 'Try again';

  @override
  String get walletPending => 'Pending';

  @override
  String get walletSourcePackPurchase => 'Added funds';

  @override
  String get walletSourceGenerationSpend => 'Template generation';

  @override
  String get walletSourceGenerationRefund => 'Generation refund';

  @override
  String get walletSourceWeeklyGrant => 'Weekly reward';

  @override
  String get walletSourceAdReward => 'Ad reward';

  @override
  String get walletSourceAdminGrant => 'Support credit';

  @override
  String get walletSourceAdminDebit => 'Support adjustment';

  @override
  String get walletPurchaseCompleted => 'Completed';

  @override
  String get walletPurchaseFailed => 'Failed';

  @override
  String get walletPartialActivityUnavailable =>
      'Your balance is already available. History and some wallet actions will refresh a bit later.';

  @override
  String get walletPaymentGatewayUnavailableError =>
      'Payment is temporarily unavailable. Please try Stripe Checkout again in a moment.';

  @override
  String get walletPackUnavailableError =>
      'This PawSpark pack is no longer available.';

  @override
  String get walletRedeemCodeNotFoundError => 'Redeem code was not found.';

  @override
  String get walletRedeemCodeAlreadyUsedError =>
      'This redeem code was already used.';

  @override
  String get walletRedeemCodeExpiredError => 'Redeem code has expired.';

  @override
  String get walletRedeemCodeInactiveError =>
      'This redeem code is not available right now.';

  @override
  String get walletRedeemCodeExhaustedError =>
      'This redeem code has reached its usage limit.';

  @override
  String get walletRedeemCodeUserLimitError =>
      'This user has already reached the redeem limit for this code.';

  @override
  String get walletRedeemOfflineError =>
      'No internet connection. Check your network and try again.';

  @override
  String get walletRedeemServerError =>
      'The promo code could not be applied because of a server error. Please try again later.';

  @override
  String get walletInsufficientBalanceError =>
      'Not enough PawSpark for this operation.';

  @override
  String get walletUnavailableError =>
      'Wallet data is temporarily unavailable. Please try again in a moment.';

  @override
  String get walletRedeemSheetTitle => 'Redeem code';

  @override
  String get walletRedeemSheetSubtitle =>
      'A code can be used once while it is active and not expired.';

  @override
  String get walletRedeemInputLabel => 'Promo code';

  @override
  String get walletRedeemHint => 'WELCOME-100';

  @override
  String get walletRedeemCancelAction => 'Cancel';

  @override
  String get walletApplyCode => 'Apply code';

  @override
  String get walletRedeemSuccessMessage =>
      'Promo code applied successfully. Your balance is already updated.';

  @override
  String get walletRedeemSuccessAction => 'Done';

  @override
  String get profileStatsSectionTitle => 'Account stats';

  @override
  String get profileStatBalanceLabel => 'Balance';

  @override
  String get profileStatPlanLabel => 'Plan';

  @override
  String get profileStatLegalLabel => 'Legal';

  @override
  String get profileMagicMomentTitle => 'Your next pet star moment';

  @override
  String get profileMagicMomentSubtitle =>
      'Create something playful for your pets in just a few taps.';

  @override
  String get premiumPageTitle => 'PetMagic Premium';

  @override
  String get premiumPageSubtitle =>
      'Unlimited pet magic, faster generation and premium templates in one plan.';

  @override
  String get premiumHeroEyebrow => 'Premium magic';

  @override
  String get premiumHeroTitle => 'Get Premium and create more content.';

  @override
  String get premiumHeroSubtitle =>
      'Unlock premium templates, faster generation and more room for photos and videos in one plan.';

  @override
  String get premiumAlreadyActive => 'Premium active';

  @override
  String get premiumBenefitUnlimitedTemplates => 'Unlimited templates';

  @override
  String get premiumBenefitFastGeneration => 'Faster generation';

  @override
  String get premiumBenefitHighQuality => 'High quality output';

  @override
  String get premiumBenefitExclusive => 'Exclusive templates';

  @override
  String get premiumChoosePlanTitle => 'Choose plan';

  @override
  String get premiumWeeklyPlan => 'Weekly';

  @override
  String get premiumMonthlyPlan => 'Monthly';

  @override
  String get premiumYearlyPlan => 'Yearly';

  @override
  String get premiumWeeklyPeriod => '/ week';

  @override
  String get premiumMonthlyPeriod => '/ month';

  @override
  String get premiumYearlyPeriod => '/ year';

  @override
  String get premiumPopularBadge => 'Most popular';

  @override
  String premiumTokensPerWeek(Object count) {
    return '$count tokens / week';
  }

  @override
  String premiumTokensPerMonth(Object count) {
    return '$count tokens / month';
  }

  @override
  String premiumDiscountLabel(Object percent) {
    return 'Save $percent%';
  }

  @override
  String get premiumCancelAnytime => 'Cancel anytime';

  @override
  String get premiumIncludesTitle => 'What Premium includes';

  @override
  String premiumTokenEstimate(Object videos, Object photos) {
    return '$videos videos or $photos photos per month, depending on template complexity.';
  }

  @override
  String get premiumSocialProof =>
      'Most chosen plan for regular PetMagic creators.';

  @override
  String get premiumPaymentTitle => 'Payment method';

  @override
  String get premiumPaymentStripe => 'Card via Stripe';

  @override
  String get premiumPaymentGooglePlay => 'Google Play';

  @override
  String get premiumPaymentApple => 'Apple Pay / App Store';

  @override
  String get premiumPaymentRecommendedBadge => 'Recommended';

  @override
  String get premiumPaymentDefaultBadge => 'Default';

  @override
  String paymentBonusPercentBadge(Object percent) {
    return '+$percent% bonus';
  }

  @override
  String get premiumComparisonTitle => 'What changes with Premium';

  @override
  String get premiumFreeColumn => 'Free';

  @override
  String get premiumPremiumColumn => 'Premium';

  @override
  String get premiumComparisonFreeTemplates => 'Free templates';

  @override
  String get premiumComparisonPremiumTemplates => 'Premium templates';

  @override
  String get premiumComparisonTokens => 'Tokens per month';

  @override
  String premiumComparisonPremiumTokens(Object count) {
    return 'Up to $count';
  }

  @override
  String get premiumComparisonPremiumTokensFallback => 'Up to 1000';

  @override
  String get premiumComparisonFast => 'Fast generation';

  @override
  String get premiumComparisonHighQuality => 'High quality export';

  @override
  String get premiumComparisonNoWatermark => 'No watermark';

  @override
  String get premiumComparisonPrioritySupport => 'Priority support';

  @override
  String get premiumFreeSummaryTokens => '20 tokens per month';

  @override
  String get premiumFreeSummaryWatermark => 'Watermark on content';

  @override
  String get premiumFreeSummaryTemplates => 'Basic templates';

  @override
  String get premiumFreeSummaryQuality => 'Standard quality';

  @override
  String get premiumSecurePaymentTitle => 'Secure payment';

  @override
  String get premiumSecurePaymentSubtitle =>
      'Manage or cancel your subscription from billing settings at any time.';

  @override
  String get premiumContinueAction => 'Start Premium';

  @override
  String get externalCheckoutStripeTitle => 'Payment via Stripe';

  @override
  String get externalCheckoutStripeMessage =>
      'Stripe Checkout opens in a secure in-app browser. After you return to PetMagic, we automatically check the payment status before updating your access.';

  @override
  String get externalCheckoutContinueAction => 'Continue';

  @override
  String get externalCheckoutCheckingTitle => 'Checking payment';

  @override
  String get externalCheckoutCheckingMessage =>
      'We are waiting for Stripe confirmation. This usually takes a few seconds.';

  @override
  String get externalCheckoutPendingVerificationMessage =>
      'Payment is not confirmed yet. We will update Premium or your wallet as soon as Stripe webhook arrives.';

  @override
  String premiumContinueWithPlan(Object plan, Object price, Object period) {
    return 'Continue with $plan — $price $period';
  }

  @override
  String get premiumManageAction => 'Manage subscription';

  @override
  String get premiumRestoreAction => 'Restore purchases';

  @override
  String get premiumTermsNotice =>
      'By continuing, you agree to the Terms of Use and Privacy Policy.';

  @override
  String get premiumStoreUnavailable =>
      'Store subscriptions are waiting for App Store / Google Play product setup. Use Stripe checkout for now.';

  @override
  String get premiumStoreProductUnavailable =>
      'This subscription product is not available in the store on this device.';

  @override
  String get premiumStoreVerificationUnavailable =>
      'Server-side store verification is not configured yet.';

  @override
  String get premiumStorePurchaseInvalid =>
      'The purchase could not be verified.';

  @override
  String get premiumStorePurchaseInactive =>
      'This subscription is no longer active.';

  @override
  String get premiumPurchaseActivated => 'Premium is active now.';

  @override
  String get premiumRecentlyActivatedBadge => 'Just activated';

  @override
  String get premiumRecentlyActivatedTitle => 'Premium confirmed';

  @override
  String get premiumRecentlyActivatedMessage =>
      'Your Premium access is active on this device and ready to use.';

  @override
  String get premiumPurchaseCancelled => 'Purchase was cancelled.';

  @override
  String get premiumCheckoutFailed =>
      'Premium checkout is temporarily unavailable.';

  @override
  String get premiumManageFailed =>
      'Billing management is not available yet for this account.';

  @override
  String get premiumRestoreStarted =>
      'Premium status refreshed on this device.';

  @override
  String get profileCommunicationsTitle => 'Aktualizacje PetMagic';

  @override
  String get profileCommunicationsEnabled =>
      'Subskrybujesz aktualizacje produktów i oferty.';

  @override
  String get profileCommunicationsDisabled =>
      'Aktualizacje marketingowe są obecnie wyłączone.';

  @override
  String get profilePrivacyTitle => 'Prywatność i zgoda';

  @override
  String get profileTermsAccepted =>
      'Twoje konto zaakceptowało Warunki użytkowania i Politykę prywatności.';

  @override
  String get profileTermsPending =>
      'Dokończ weryfikację zgody w ustawieniach konta.';

  @override
  String get profileLegalShortcutTitle => 'Privacy & Legal';

  @override
  String get profileLegalShortcutAccepted =>
      'Terms accepted • Privacy settings';

  @override
  String get profileLegalShortcutPending => 'Review permissions';

  @override
  String get profileSupportTitle => 'Skontaktuj się z pomocą techniczną';

  @override
  String get profileSupportSubtitle =>
      'Jesteśmy tu, gdy potrzebujesz pomocy ze swoim kontem.';

  @override
  String get profileSupportCompactSubtitle =>
      'Get help with billing or account access.';

  @override
  String get profileSettingsShortcutTitle => 'Ustawienia';

  @override
  String get profileSettingsShortcutSubtitle =>
      'Zarządzaj sekcjami języka, motywu i konta.';

  @override
  String get profileSettingsCompactSubtitle =>
      'Language, theme and account settings.';

  @override
  String get profilePreferenceEnabled => 'Włączony';

  @override
  String get profilePreferenceOff => 'Wyłączony';

  @override
  String get profileSettingsTitle => 'Ustawienia';

  @override
  String get profileSettingsSubtitle => 'Zarządzaj aplikacją i swoim kontem.';

  @override
  String get profileSettingsAccountSection => 'Konto';

  @override
  String get profileSettingsNotificationsSection => 'Powiadomienia';

  @override
  String get profileSettingsPreferencesSection => 'Preferencje';

  @override
  String get profileSettingsSupportSection => 'Wsparcie';

  @override
  String get profileSettingsAboutSection => 'O aplikacji';

  @override
  String get profileSettingsDangerSection => 'Strefa niebezpieczeństwa';

  @override
  String get profileSettingsAccountInfoTitle => 'Informacje o koncie';

  @override
  String get profileSettingsUnavailableSubtitle =>
      'Informacje te stają się dostępne po zalogowaniu.';

  @override
  String get profileSettingsLinkedAccountsTitle => 'Połączone konta';

  @override
  String get profileSettingsLinkedAccountsSubtitle =>
      'Pojawią się tutaj Google, Apple i inni dostawcy.';

  @override
  String get profileSettingsPasswordTitle => 'Zmień hasło';

  @override
  String get profileSettingsPasswordSubtitle =>
      'Zaktualizuj swoje hasło, aby zapewnić bezpieczeństwo konta.';

  @override
  String get profileSettingsNotificationsTitle => 'Ustawienia powiadomień';

  @override
  String get profileSettingsNotificationsSubtitle =>
      'Zarządzaj preferencjami push i e-mail w całej aplikacji.';

  @override
  String get profileSettingsLanguageTitle => 'Język aplikacji';

  @override
  String get profileSettingsLanguageSubtitle =>
      'Wybierz język używany w całym interfejsie.';

  @override
  String get profileSettingsThemeTitle => 'Motyw aplikacji';

  @override
  String get profileSettingsThemeSubtitle =>
      'Przełączaj pomiędzy systemem, jasnym i ciemnym wyglądem.';

  @override
  String get profileSettingsHelpCenterTitle => 'Centrum pomocy';

  @override
  String get profileSettingsHelpCenterSubtitle =>
      'Szybkie odpowiedzi i przewodniki dotyczące często zadawanych pytań.';

  @override
  String get profileSettingsSupportTitle =>
      'Skontaktuj się z pomocą techniczną';

  @override
  String get profileSettingsSupportSubtitle =>
      'Skontaktuj się, jeśli potrzebujesz pomocy w zakresie rozliczeń lub dostępu do konta.';

  @override
  String get profileSettingsTermsTitle => 'Warunki użytkowania';

  @override
  String get profileSettingsTermsSubtitle =>
      'Zapoznaj się z zasadami korzystania z PetMagic.';

  @override
  String get profileSettingsPrivacyTitle => 'Polityka prywatności';

  @override
  String get profileSettingsPrivacySubtitle =>
      'Dowiedz się, jak przetwarzane i chronione są Twoje dane.';

  @override
  String get profileSettingsDeleteAccountTitle => 'Usuń konto';

  @override
  String get profileSettingsDeleteAccountSubtitle =>
      'Tej akcji nie można cofnąć.';

  @override
  String get profileAccountDetailsSubtitle =>
      'Przejrzyj dane konta aktualnie dostępne na tym urządzeniu.';

  @override
  String get profileAccountDetailsSection => 'Szczegóły konta';

  @override
  String get profileAccountUserIdLabel => 'Identyfikator użytkownika';

  @override
  String get profileAccountDisplayNameLabel => 'Nazwa wyświetlana';

  @override
  String get profileAccountDisplayNameMissing => 'Jeszcze nie ustawione';

  @override
  String get profileAccountRolesLabel => 'Role';

  @override
  String get profileAccountRolesMissing => 'Brak przypisanych ról';

  @override
  String get profileAccountMembershipLabel => 'Członkostwo';

  @override
  String get profileAccountConsentLabel => 'Akceptacja warunków';

  @override
  String get profileAccountMarketingLabel => 'Oferty i aktualizacje';

  @override
  String get profileAccountAvatarLabel => 'Awatara';

  @override
  String get profileAccountAvatarMissing => 'Nie przesłano awatara';

  @override
  String get profileAccountAvatarUploaded => 'Awatar przesłany';

  @override
  String get profileDetailsCurrentStatusSection => 'Aktualny stan';

  @override
  String get profileDetailsNextStepSection => 'Co stanie się dalej';

  @override
  String get profileDetailsLinkedAccountsBody =>
      'Połączeni dostawcy pojawią się tutaj, gdy tylko połączenie zostanie włączone dla Twojego konta.';

  @override
  String get profileDetailsLinkedAccountsStatus =>
      'Żaden zewnętrzny dostawca nie jest jeszcze połączony. Adres e-mail i hasło pozostają aktywną metodą logowania do tego profilu.';

  @override
  String get profileDetailsLinkedAccountsNext =>
      'Google, Apple i dodatkowi dostawcy zostaną wyświetleni tutaj po otwarciu procesu łączenia zaplecza w aplikacji.';

  @override
  String get profileLinkedAccountsLoading =>
      'Ładowanie połączonych dostawców logowania...';

  @override
  String get profileLinkedAccountsConnectedStatus =>
      'Połączono i gotowe do logowania.';

  @override
  String get profileLinkedAccountsNotConnectedStatus =>
      'Jeszcze nie połączono.';

  @override
  String get profileLinkedAccountsConnectAction => 'Połącz';

  @override
  String get profileLinkedAccountsDisconnectAction => 'Odłącz';

  @override
  String get profileLinkedAccountsProtectedHint =>
      'Tego dostawcy nie można odłączyć, dopóki nie pozostanie dostępna inna metoda logowania.';

  @override
  String get profileDetailsNotificationsBody =>
      'Ta sekcja odzwierciedla Twoje obecne preferencje dotyczące komunikacji w aplikacji.';

  @override
  String get profileDetailsNotificationsStatusEnabled =>
      'Aktualizacje produktów i oferty są włączone dla tego profilu. Dodatkowe elementy sterujące push pojawią się tutaj później.';

  @override
  String get profileDetailsNotificationsStatusDisabled =>
      'Marketingowe e-maile są obecnie wyłączone w tym profilu. Dodatkowe elementy sterujące push pojawią się tutaj później.';

  @override
  String get profileDetailsNotificationsNext =>
      'Tutaj możesz już sprawdzić aktualne preferencje dotyczące poczty e-mail. Dedykowane przełączniki przyciskowe zostaną dodane w późniejszym fragmencie produktu.';

  @override
  String get profileDetailsHelpBody =>
      'Centrum pomocy zgromadzi w jednym miejscu krótkie odpowiedzi, wskazówki dotyczące konfiguracji i wskazówki dotyczące konta.';

  @override
  String get profileDetailsHelpStatus =>
      'Baza wiedzy w aplikacji jest wciąż tworzona, dlatego na tym ekranie widoczny jest bieżący stan wdrożenia.';

  @override
  String get profileDetailsHelpNext =>
      'Pierwsze artykuły pomocy i przewodniki dotyczące rozwiązywania problemów pojawią się tutaj po opublikowaniu treści pomocy dla urządzeń mobilnych.';

  @override
  String get profileDetailsSupportBody =>
      'Prośby o wsparcie będą obsługiwane tutaj, bez zmuszania Cię do opuszczenia obszaru profilu.';

  @override
  String get profileDetailsSupportStatus =>
      'Bezpośredni kontakt w aplikacji nie jest jeszcze podłączony. Na razie zachowaj ten ekran jako punkt wejścia wsparcia dla następnego fragmentu.';

  @override
  String get profileDetailsSupportNext =>
      'Następnym krokiem jest prawdziwy formularz wsparcia lub przekazanie wiadomości e-mail połączone z przepływem wsparcia zaplecza.';

  @override
  String get profileDetailsTermsBody =>
      'Sprawdź, jak PetMagic oczekuje, że aplikacja i konto będą używane.';

  @override
  String get profileDetailsTermsStatusAccepted =>
      'To konto zaakceptowało już Warunki użytkowania podczas rejestracji.';

  @override
  String get profileDetailsTermsStatusPending =>
      'Na tym koncie nie zarejestrowano jeszcze zakończonej akceptacji warunków.';

  @override
  String get profileDetailsTermsNext =>
      'Pełniejszy widok dokumentu prawnego można załączyć tutaj później. Na razie ten ekran potwierdza aktualny stan akceptacji.';

  @override
  String get profileDetailsPrivacyBody =>
      'Sprawdź, jak PetMagic przechowuje, chroni i wykorzystuje dane konta.';

  @override
  String get profileDetailsPrivacyStatus =>
      'Szczegóły dotyczące prywatności są obecnie wyświetlane jako ekran podsumowania w aplikacji, podczas gdy przygotowywany jest pełny obieg dokumentów prawnych.';

  @override
  String get profileDetailsPrivacyNext =>
      'Następny fragment może dołączyć do tej trasy kompletny dokument dotyczący polityki lub hostowaną stronę prawną.';

  @override
  String get profileLegalAcceptanceCurrent =>
      'Aktualne dokumenty prawne są zaakceptowane dla tego konta.';

  @override
  String get profileLegalAcceptanceRequired =>
      'To konto musi zaakceptować aktualne wersje dokumentów prawnych.';

  @override
  String get profileLegalVersionLabel => 'Aktualna wersja';

  @override
  String get profileLegalPublishedLabel => 'Opublikowano';

  @override
  String get profileLegalAcceptedVersionLabel => 'Zaakceptowana wersja';

  @override
  String get profileLegalAcceptedAtLabel => 'Zaakceptowano';

  @override
  String get profileLegalLoading =>
      'Ładowanie aktualnego dokumentu prawnego z backendu...';

  @override
  String get profileLegalUnavailable =>
      'Nie udało się teraz załadować aktualnego dokumentu prawnego.';

  @override
  String get profileLegalAcceptAction => 'Zaakceptuj aktualne dokumenty prawne';

  @override
  String get profileLegalAcceptanceGuestHint =>
      'Podczas rejestracji zaakceptujesz aktualną wersję Warunków korzystania i Polityki prywatności.';

  @override
  String get profileLegalDocumentSection => 'Dokument';

  @override
  String get profileLegalCompactHint =>
      'Najpierw widzisz skrót, a szczegóły rozwijasz tylko wtedy, gdy są potrzebne.';

  @override
  String get profileLegalCurrentAcceptedHint =>
      'Dla tego konta nie jest wymagane dodatkowe potwierdzenie.';

  @override
  String get profileLegalCompactSectionLabel => 'Dotknij, aby rozwinąć';

  @override
  String get profileDetailsDeleteBody =>
      'Usuwanie konta jest celowo chronione i nie jest jeszcze wykonywane z tego ekranu.';

  @override
  String get profileDetailsDeleteStatus =>
      'Usunięcie nie jest obecnie dostępne w aplikacji mobilnej jednym dotknięciem. Pozwala to uniknąć destrukcyjnego zachowania, zanim przepływ potwierdzenia zaplecza będzie gotowy.';

  @override
  String get profileDetailsDeleteNext =>
      'Po zaimplementowaniu przepływu pracy usuwania zaplecza ten ekran może stać się krokiem potwierdzenia i weryfikacji, a nie symbolem zastępczym.';

  @override
  String get supportChatTitle => 'Czat wsparcia';

  @override
  String get supportChatSubtitle =>
      'Wyślij wiadomość do zespołu PetMagic bezpośrednio ze swojego profilu.';

  @override
  String get supportChatSecureTitle => 'Your conversation is secure';

  @override
  String get supportChatSecureSubtitle =>
      'We protect your data and keep your information private.';

  @override
  String get supportChatTeamTitle => 'PetMagic Support';

  @override
  String get supportChatTeamStatus => 'Online • typical reply under 5 min';

  @override
  String get supportChatTodayLabel => 'Today';

  @override
  String get supportChatInputHint => 'Opisz problem, pytanie lub prośbę...';

  @override
  String get supportChatSendAction => 'Wysłać';

  @override
  String get supportChatEmptyTitle => 'Rozpocznij rozmowę';

  @override
  String get supportChatEmptyMessage =>
      'Twój czat pomocy technicznej jest gotowy. Wyślij pierwszą wiadomość, a zespół odpowie tutaj.';

  @override
  String get supportChatWelcomeTitle => 'Welcome to PetMagic support';

  @override
  String get supportChatWelcomeBody =>
      'Choose a common topic below or write your message right away. We will route it to the right team without making the chat feel empty.';

  @override
  String get supportChatQuickActionGeneration => 'Issue with image generation';

  @override
  String get supportChatQuickActionPayment => 'Payment problem';

  @override
  String get supportChatQuickActionRefund => 'Refund request';

  @override
  String get supportChatQuickActionHuman => 'Talk to an operator';

  @override
  String get supportChatFaqTitle => 'FAQ';

  @override
  String get supportChatFaqGenerationTitle => 'Why did my generation fail?';

  @override
  String get supportChatFaqGenerationBody =>
      'Send the template name, your pet type and a screenshot if possible. This usually gives support enough context on the first reply.';

  @override
  String get supportChatFaqResponseTitle => 'When will support reply?';

  @override
  String get supportChatFaqResponseBody =>
      'Active chats are normally answered within a few minutes during support hours. We keep the thread here so you do not lose context.';

  @override
  String get supportChatFaqRefundTitle => 'How do refunds work?';

  @override
  String get supportChatFaqRefundBody =>
      'Share the order date and the reason for the request. Billing cases are reviewed in the same chat without switching channels.';

  @override
  String get supportChatStatusOpen => 'Otwarte';

  @override
  String get supportChatStatusInProgress => 'W toku';

  @override
  String get supportChatStatusResolved => 'Rozwiązany';

  @override
  String get supportChatStatusClosed => 'Zamknięte';

  @override
  String get supportChatMessageDelivered => 'Dostarczono';

  @override
  String get supportChatMessageRead => 'Przeczytano';

  @override
  String get profileSettingsThemeSystem => 'System';

  @override
  String get profileSettingsThemeLight => 'Światło';

  @override
  String get profileSettingsThemeDark => 'Ciemny';

  @override
  String get profileSettingsLanguageRussian => 'rosyjski';

  @override
  String get profileSettingsLanguageEnglish => 'angielski';

  @override
  String get profileSettingsLanguageEnglishUs => 'angielski (amerykański)';

  @override
  String profileSettingsVersionLabel(Object version) {
    return 'Wersja aplikacji $version';
  }

  @override
  String get magicLoadingPreparing => 'Przygotowujemy magie...';

  @override
  String get magicLoadingCutestAngle => 'Szukamy najslodszego ujecia...';

  @override
  String get magicLoadingAiPaws => 'Rozgrzewamy lapki AI...';

  @override
  String get magicLoadingCreatingAdorable => 'Tworzymy cos uroczego...';

  @override
  String get magicLoadingAlmostReady => 'Prawie gotowe...';

  @override
  String get videoLabel => 'Wideo';

  @override
  String get imageLabel => 'Obraz';

  @override
  String get templatesErrorTitle => 'Nie zaladowano szablonow';

  @override
  String get retryAction => 'Sprobuj ponownie';

  @override
  String get emptyTemplatesTitle => 'Nie ma jeszcze szablonow';

  @override
  String get emptyTemplatesMessage =>
      'Sprobuj innego filtra albo odswiez katalog.';

  @override
  String get startupOnboardingActionContinueGuest => 'Kontynuuj jako gość';

  @override
  String get startupOnboardingActionNext => 'Następny';

  @override
  String get startupOnboardingActionStart => 'Zacznij';

  @override
  String get startupOnboardingPageOneTitle =>
      'Twórz magiczne chwile ze swoim zwierzakiem';

  @override
  String get startupOnboardingPageOneSubtitle =>
      'Zamień codzienne klipy w zabawne historie, gotowe do rozpowszechniania w Internecie, dzięki jasnym szablonom przeznaczonym przede wszystkim dla zwierząt.';

  @override
  String get startupOnboardingPageOneHighlightOne => 'Modne szablony';

  @override
  String get startupOnboardingPageOneHighlightTwo => 'Szybkie edycje';

  @override
  String get startupOnboardingPageOneHighlightThree =>
      'Atmosfera bezpieczna dla zwierząt';

  @override
  String get startupOnboardingPageTwoTitle =>
      'Najpierw przeglądaj, odblokuj, gdy będziesz gotowy';

  @override
  String get startupOnboardingPageTwoSubtitle =>
      'Przeglądaj kanał jako gość, a następnie zaloguj się, jeśli chcesz renderować, zapisywać lub przejść na wersję premium.';

  @override
  String get startupOnboardingPageTwoHighlightOne => 'Przeglądanie gościnne';

  @override
  String get startupOnboardingPageTwoHighlightTwo =>
      'Zaloguj się jednym dotknięciem';

  @override
  String get startupOnboardingPageTwoHighlightThree => 'Płynne przekazanie';

  @override
  String get startupOnboardingPageThreeTitle =>
      'Zbieraj tokeny i dodatkowe korzyści później';

  @override
  String get startupOnboardingPageThreeSubtitle =>
      'Spraw, aby pierwsze wrażenie było zabawne. Tokeny, nagrody i akcje premium czekają na czysty etap autoryzacji.';

  @override
  String get startupOnboardingPageThreeHighlightOne => 'Odblokowuje premium';

  @override
  String get startupOnboardingPageThreeHighlightTwo => 'Bilans tokenów';

  @override
  String get startupOnboardingPageThreeHighlightThree => 'Korzyści dla twórców';

  @override
  String get startupMiniFeatureFastStart => 'Szybki start';

  @override
  String get startupMiniFeaturePetFirst => 'Najpierw zwierzę';

  @override
  String get startupMiniFeatureUpgradeLater => 'Uaktualnij później';

  @override
  String get startupWelcomeViewOnboarding => 'Zobacz wprowadzenie';

  @override
  String get startupWelcomeTitle => 'Witamy ponownie w PetMagic';

  @override
  String get startupWelcomeSubtitle =>
      'Kontynuuj eksplorację jako gość lub zaloguj się, zanim zaczniesz renderować szablony, odblokowywać nagrody i zapisywać swoje dzieła.';

  @override
  String get startupWelcomeContinueGuest => 'Kontynuuj jako gość';

  @override
  String get startupWelcomeTemplatesTitle => 'Szablony wirusowe';

  @override
  String get startupWelcomeTemplatesSubtitle => 'Podgląd pełnego kanału';

  @override
  String get startupWelcomeAiTitle => 'Magia AI';

  @override
  String get startupWelcomeAiSubtitle => 'Odblokuj po zalogowaniu';

  @override
  String get startupWelcomeShareTitle => 'Udostępnij i ciesz się';

  @override
  String get startupWelcomeShareSubtitle => 'Zapisz swoje ulubione później';

  @override
  String get authEntryTitle => 'Witamy ponownie!';

  @override
  String get authEntrySubtitle =>
      'Zaloguj się, aby kontynuować swoją magię zwierząt.';

  @override
  String get authRegisterTitle => 'Utwórz swoje konto';

  @override
  String get authRegisterSubtitle =>
      'Dołącz do PetMagic i odblokuj szablony, tokeny i funkcje premium.';

  @override
  String get authRegisterAction => 'Zapisać się';

  @override
  String get authDisplayNameLabel => 'Nazwa wyświetlana (opcjonalnie)';

  @override
  String get authConfirmPasswordLabel => 'Potwierdź hasło';

  @override
  String get authPasswordRulesHint => 'Użyj co najmniej 6 znaków.';

  @override
  String get authPasswordTooShort => 'Hasło musi mieć co najmniej 6 znaków.';

  @override
  String get authForgotPasswordAction => 'Zapomniałeś hasła?';

  @override
  String get authForgotPasswordComingSoon => 'Odzyskiwanie hasła już wkrótce.';

  @override
  String get authPasswordResetTitle => 'Zresetuj swoje hasło';

  @override
  String get authPasswordResetSubtitle =>
      'Podaj swój adres e-mail, a my wyślemy Ci kod resetujący.';

  @override
  String get authPasswordResetCodeTitle => 'Wpisz kod z e-maila';

  @override
  String get authPasswordResetCodeSubtitle =>
      'Użyj kodu, aby ustawić nowe hasło do swojego konta.';

  @override
  String get authPasswordResetCodeLabel => 'Zresetuj kod';

  @override
  String get authPasswordResetRequestAction => 'Wyślij kod';

  @override
  String get authPasswordResetConfirmAction => 'Zapisz nowe hasło';

  @override
  String get authPasswordResetResendAction => 'Wyślij kod ponownie';

  @override
  String get authPasswordResetCodeSent =>
      'Wysłaliśmy kod resetowania hasła na Twój adres e-mail.';

  @override
  String get authPasswordResetSuccess =>
      'Hasło zaktualizowane. Możesz teraz zalogować się przy użyciu nowego hasła.';

  @override
  String get authPasswordResetCodeInvalid =>
      'Ten kod resetowania jest nieprawidłowy lub wygasł.';

  @override
  String get authOrContinueWith => 'lub kontynuuj';

  @override
  String get authAcceptTermsLabel =>
      'Zgadzam się z Warunkami użytkowania i Polityką prywatności';

  @override
  String get authReceiveUpdatesLabel =>
      'Chcę otrzymywać aktualizacje i oferty od PetMagic';

  @override
  String get authAcceptTermsRequired =>
      'Aby założyć konto, musisz zaakceptować Regulamin i Politykę prywatności.';

  @override
  String get authReviewTermsAction => 'Zobacz warunki';

  @override
  String get authReviewPrivacyAction => 'Zobacz prywatność';

  @override
  String get authLegalLoading =>
      'Ładowanie aktualnych dokumentów warunków i prywatności...';

  @override
  String get authLegalReady =>
      'Aktualne dokumenty prawne są gotowe do przeczytania i zaakceptowania.';

  @override
  String get authLegalUnavailable =>
      'Aktualne dokumenty prawne są tymczasowo niedostępne. Spróbuj ponownie za chwilę.';

  @override
  String get authGoogleShortLabel => 'Google';

  @override
  String get authAppleShortLabel => 'Jabłko';

  @override
  String get authContinueWithGoogle => 'Kontynuuj z Google';

  @override
  String get authContinueWithApple => 'Kontynuuj z Apple';

  @override
  String get authNoAccountPrompt => 'Nie masz konta?';

  @override
  String get authHaveAccountPrompt => 'Masz już konto?';

  @override
  String get authSignUpAction => 'Zapisać się';

  @override
  String get authSocialComingSoon => 'Logowanie społecznościowe już wkrótce.';

  @override
  String get authPasswordMismatch => 'Hasła nie pasują.';

  @override
  String get authExternalCancelled => 'Logowanie zostało anulowane.';

  @override
  String get authExternalFailed =>
      'Logowanie zewnętrzne nie powiodło się. Spróbuj ponownie.';

  @override
  String get authExternalTimedOut =>
      'Logowanie trwało zbyt długo. Spróbuj ponownie.';

  @override
  String get authExternalLaunchFailed => 'Nie można otworzyć strony logowania.';

  @override
  String get authExternalCallbackFailed =>
      'Nie udało się dokończyć logowania w aplikacji.';

  @override
  String get authExternalSessionExpired =>
      'Ta sesja logowania wygasła. Spróbuj ponownie.';

  @override
  String get profileActionFailed =>
      'We could not complete this action. Please try again.';

  @override
  String get authSecurePrivateTitle => 'Bezpieczne i prywatne';

  @override
  String get authSecurePrivateSubtitle => 'Twoje dane pozostają chronione.';

  @override
  String get authFastEasyTitle => 'Szybko i łatwo';

  @override
  String get authFastEasySubtitle =>
      'Zacznij tworzyć za pomocą kilku dotknięć.';

  @override
  String get authLovedByPetsTitle => 'Uwielbiany przez zwierzęta';

  @override
  String get authLovedByPetsSubtitle =>
      'Stworzony dla szczęśliwych rodziców zwierząt.';

  @override
  String get authPrivacyTitle => 'Twoja prywatność ma znaczenie';

  @override
  String get authPrivacySubtitle =>
      'Nigdy nie sprzedajemy ani nie udostępniamy Twoich danych stronom trzecim.';

  @override
  String get authRequiredTitle => 'Zaloguj się, aby odblokować tę akcję';

  @override
  String get authRequiredMessage =>
      'Goście mogą eksplorować aplikację, ale działania szablonów, nagrody i funkcje tokenów wymagają konta PetMagic.';

  @override
  String get authRequiredContinueBrowsing => 'Kontynuuj przeglądanie';

  @override
  String get templateTryAction => 'Wypróbuj szablon';

  @override
  String get templateGuestPreview => 'Podgląd gościnny';

  @override
  String get templateActionComingSoon => 'Studio szablonów już wkrótce.';

  @override
  String get tokensActionComingSoon => 'Portfel tokenowy już wkrótce.';

  @override
  String get rewardsActionComingSoon => 'Centrum nagród już wkrótce.';
}
