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
  String get navRewards => 'Rewards';

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
  String get walletBalanceTitle =>
      'Available for photos, videos and premium templates.';

  @override
  String get walletBalanceEyebrow => 'Your balance';

  @override
  String get walletBalanceUnit => 'PawSpark';

  @override
  String get walletBalanceExplanation =>
      'PawSpark — internal currency of PetMagic. Use it for creating photos, videos and accessing premium templates.';

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
  String get walletRedeemAction => 'Activate';

  @override
  String get walletRewardsTitle => 'Ad bonus';

  @override
  String get walletAdRewardAction => 'Ad reward';

  @override
  String get walletAdRewardCompactTitle => 'Get PawSpark for free';

  @override
  String get walletAdRewardCompactDescription =>
      'Watch a short ad and get +15 PawSpark.';

  @override
  String walletAdRewardRemaining(Object count) {
    return 'Left today: $count';
  }

  @override
  String get walletWatchAdAction => 'Watch ad +15';

  @override
  String get walletAdDailyLimitReached =>
      'Ads are temporarily unavailable. Please try again later.';

  @override
  String get walletPromoTitle => 'Have a promo code?';

  @override
  String get walletPromoSubtitle =>
      'Enter a code from PetMagic and add PawSpark to your balance.';

  @override
  String get walletPromoInputPlaceholder => 'Enter promo code';

  @override
  String get walletPromoSuccessMessage => 'Promo code activated successfully!';

  @override
  String get walletBestValueBadge => 'Best value';

  @override
  String get walletPremiumUpsellTitle => 'Create often?';

  @override
  String get walletPremiumUpsellMessage =>
      'Premium membership gives you cheaper generations, monthly PawSparks and exclusive premium templates.';

  @override
  String get walletViewPremiumAction => 'View Premium';

  @override
  String get walletWhatYouCanCreateTitle => 'Enough for approximately:';

  @override
  String walletApproxPhotos(int count) {
    return '$count photos';
  }

  @override
  String walletApproxVideos(int count) {
    return '$count videos';
  }

  @override
  String get walletSpendPhotoSubtitle => 'Photos\nfrom 10 Spark';

  @override
  String get walletSpendVideoSubtitle => 'Videos\nfrom 50 Spark';

  @override
  String get walletSpendPremiumSubtitle => 'Premium\nfrom 80 Spark';

  @override
  String get walletContactSupportAction => 'Contact support';

  @override
  String get walletRetryAction => 'Retry';

  @override
  String get rewardsPageTitle => 'Rewards';

  @override
  String get rewardsPageSubtitle =>
      'Earn PawSpark with promo codes and invitations';

  @override
  String rewardsLastUpdatedLabel(Object value) {
    return 'Updated: $value';
  }

  @override
  String get rewardsLastUpdatedNow => 'just now';

  @override
  String rewardsLastUpdatedMinutes(int count) {
    return '$count min ago';
  }

  @override
  String rewardsLastUpdatedHours(int count) {
    return '$count h ago';
  }

  @override
  String get rewardsPromoTitle => 'Promo code';

  @override
  String get rewardsPromoSubtitle => 'Enter a promo code and receive a bonus';

  @override
  String get rewardsPromoEmptyError => 'Enter promo code.';

  @override
  String get rewardsPromoCheckingStatus => 'Checking code...';

  @override
  String get rewardsReferralTitle => 'Invite a friend';

  @override
  String get rewardsReferralSubtitle =>
      'Share your code with a friend. Referral bonus is not paid for signup and is credited only after their first successful paid purchase.';

  @override
  String get rewardsReferralInvitePrefix =>
      'Your friend gets a bonus before their first purchase, and you get';

  @override
  String get rewardsReferralInviteSuffix =>
      'after their first successful payment.';

  @override
  String get rewardsYourReferralCode => 'Your code';

  @override
  String get rewardsCopyReferralCodeAction => 'Copy';

  @override
  String get rewardsReferralCopiedMessage => 'Code copied.';

  @override
  String get rewardsReferralShareCodeAction => 'Share code';

  @override
  String get rewardsReferralUseFriendCodeAction => 'Enter friend code';

  @override
  String get rewardsReferralFriendCodePrompt => 'Have a friend\'s code?';

  @override
  String get rewardsReferralFriendCodeHint =>
      'Enter a friend\'s code before your first purchase and get a bonus.';

  @override
  String get rewardsReferralInputLabel => 'Friend code';

  @override
  String get rewardsReferralInputHint => 'PMABC12345';

  @override
  String get rewardsReferralActivateAction => 'Activate code';

  @override
  String get rewardsReferralEmptyError => 'Enter friend code.';

  @override
  String get rewardsReferralCheckingStatus => 'Checking referral code...';

  @override
  String get rewardsReferralActivatedMessage =>
      'Referral code activated. Bonus is credited after your first successful paid purchase.';

  @override
  String get rewardsReferralStatusLoading => 'Loading referral status...';

  @override
  String get rewardsReferralStatusNone =>
      'Enter a friend\'s code before your first purchase. Bonus is credited only after a successful payment.';

  @override
  String get rewardsReferralStatusPending =>
      'Referral connected. Bonus will be paid after your first successful paid purchase.';

  @override
  String get rewardsReferralStatusRewarded =>
      'Referral bonus paid. Thanks for growing PetMagic.';

  @override
  String get rewardsReferralEarnedLabel => 'Earned';

  @override
  String get rewardsReferralFriendsLabel => 'Friends';

  @override
  String get rewardsReferralBonusLabel => 'Friend purchases';

  @override
  String rewardsReferralBonusPerFriend(int count) {
    return '+$count PawSpark per invited friend';
  }

  @override
  String get rewardsReferralRulesNote =>
      'Bonus is credited after your friend\'s first successful purchase.';

  @override
  String get rewardsReferralHowItWorksAction => 'How does it work?';

  @override
  String rewardsReferralShareMessage(Object code, int bonus) {
    return 'Join me in PetMagic! Use my referral code $code. Bonus is credited after your first successful paid purchase. After your first purchase I\'ll receive +$bonus PawSpark.';
  }

  @override
  String get rewardsHistoryTitle => 'History';

  @override
  String get rewardsHistorySubtitle =>
      'Recent promo, referral, ad and weekly rewards.';

  @override
  String get rewardsHistoryEmpty =>
      'No bonuses yet. Promo and referral rewards will appear here.';

  @override
  String get rewardsSourcePromo => 'Promo code';

  @override
  String get rewardsSourceReferral => 'Referral bonus';

  @override
  String get rewardsSourceAd => 'Ad reward';

  @override
  String get rewardsSourceWeekly => 'Weekly reward';

  @override
  String get rewardsSourcePremium => 'Premium grant';

  @override
  String get rewardsSourceBonus => 'Bonus';

  @override
  String get rewardsReferralCodeNotFoundError => 'Referral code was not found.';

  @override
  String get rewardsReferralSelfError =>
      'You cannot activate your own referral code.';

  @override
  String get rewardsReferralAlreadyLinkedError =>
      'A referral code is already activated for this account.';

  @override
  String get rewardsReferralPaidUserError =>
      'Referral code must be activated before your first successful paid purchase.';

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
  String get walletViewAllTransactions => 'All transactions';

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
  String get walletSourceGenerationSpend => 'Generation';

  @override
  String get walletSourceGenerationRefund => 'Generation refund';

  @override
  String get walletSourceWeeklyGrant => 'Weekly bonus';

  @override
  String get walletSourceAdReward => 'Ad bonus';

  @override
  String get walletSourcePromoCode => 'Promo code';

  @override
  String get walletSourceAdminGrant => 'Support credit';

  @override
  String get walletSourceAdminDebit => 'Support adjustment';

  @override
  String get walletPurchaseCompleted => 'Completed';

  @override
  String get walletPurchaseFailed => 'Failed';

  @override
  String get walletQueryFilterAll => 'All';

  @override
  String get walletQueryFilterCredits => 'Credits';

  @override
  String get walletQueryFilterDebits => 'Debits';

  @override
  String get walletPartialActivityUnavailable =>
      'Your balance is already available. History and some wallet actions will refresh a bit later.';

  @override
  String get walletPaymentGatewayUnavailableError =>
      'Payments are temporarily unavailable. Please try again later or update the app.';

  @override
  String get walletPaymentUnavailableError =>
      'Top-up is temporarily unavailable. Please try again later.';

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
  String get walletRedeemHint => 'Enter promo code';

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
      'Nielimitowana magia dla pupili, szybsze generowanie i szablony premium w jednym planie.';

  @override
  String get premiumHeroEyebrow => 'Magia Premium';

  @override
  String get premiumHeroTitle => 'Przejdź na Premium i twórz więcej treści.';

  @override
  String get premiumHeroSubtitle =>
      'Odblokuj szablony premium, szybsze generowanie i więcej miejsca na zdjęcia oraz filmy w jednym planie.';

  @override
  String get premiumAlreadyActive => 'Premium aktywne';

  @override
  String get premiumBenefitUnlimitedTemplates => 'Nielimitowane szablony';

  @override
  String get premiumBenefitFastGeneration => 'Szybsze generowanie';

  @override
  String get premiumBenefitHighQuality => 'Wynik w wysokiej jakości';

  @override
  String get premiumBenefitExclusive => 'Ekskluzywne szablony';

  @override
  String get premiumChoosePlanTitle => 'Wybierz plan';

  @override
  String get premiumWeeklyPlan => 'Tygodniowy';

  @override
  String get premiumMonthlyPlan => 'Miesięczny';

  @override
  String get premiumYearlyPlan => 'Roczny';

  @override
  String get premiumWeeklyPeriod => '/ tydzień';

  @override
  String get premiumMonthlyPeriod => '/ miesiąc';

  @override
  String get premiumYearlyPeriod => '/ rok';

  @override
  String get premiumPopularBadge => 'Najpopularniejszy';

  @override
  String premiumTokensPerWeek(Object count) {
    return '$count tokenów / tydzień';
  }

  @override
  String premiumTokensPerMonth(Object count) {
    return '$count tokenów / miesiąc';
  }

  @override
  String premiumDiscountLabel(Object percent) {
    return 'Oszczędzasz $percent%';
  }

  @override
  String get premiumCancelAnytime => 'Anuluj w dowolnym momencie';

  @override
  String get premiumIncludesTitle => 'Co zawiera Premium';

  @override
  String premiumTokenEstimate(Object videos, Object photos) {
    return '$videos filmów lub $photos zdjęć miesięcznie, zależnie od złożoności szablonu.';
  }

  @override
  String get premiumSocialProof =>
      'Najczęściej wybierany plan przez regularnych twórców PetMagic.';

  @override
  String get premiumPaymentTitle => 'Metoda płatności';

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
  String get premiumComparisonTitle => 'Co zmienia się z Premium';

  @override
  String get premiumFreeColumn => 'Darmowy';

  @override
  String get premiumPremiumColumn => 'Premium';

  @override
  String get premiumComparisonFreeTemplates => 'Darmowe szablony';

  @override
  String get premiumComparisonPremiumTemplates => 'Szablony premium';

  @override
  String get premiumComparisonTokens => 'Tokeny miesięcznie';

  @override
  String premiumComparisonPremiumTokens(Object count) {
    return 'Do $count';
  }

  @override
  String get premiumComparisonPremiumTokensFallback => 'Do 1000';

  @override
  String get premiumComparisonFast => 'Szybkie generowanie';

  @override
  String get premiumComparisonHighQuality => 'Eksport w wysokiej jakości';

  @override
  String get premiumComparisonNoWatermark => 'Bez znaku wodnego';

  @override
  String get premiumComparisonPrioritySupport => 'Priorytetowe wsparcie';

  @override
  String get premiumFreeSummaryTokens => '20 tokens per month';

  @override
  String get premiumFreeSummaryWatermark => 'Watermark on content';

  @override
  String get premiumFreeSummaryTemplates => 'Basic templates';

  @override
  String get premiumFreeSummaryQuality => 'Standard quality';

  @override
  String get premiumSecurePaymentTitle => 'Bezpieczna płatność';

  @override
  String get premiumSecurePaymentSubtitle =>
      'Zarządzaj subskrypcją lub anuluj ją w ustawieniach płatności w dowolnym momencie.';

  @override
  String get premiumContinueAction => 'Kontynuuj';

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
    return 'Kontynuuj z $plan — $price $period';
  }

  @override
  String get premiumManageAction => 'Zarządzaj subskrypcją';

  @override
  String get premiumRestoreAction => 'Przywróć zakupy';

  @override
  String get premiumTermsNotice =>
      'Kontynuując, akceptujesz Warunki użytkowania i Politykę prywatności.';

  @override
  String get premiumStoreUnavailable =>
      'Subskrypcje sklepowe czekają na konfigurację produktów w App Store / Google Play. Na razie użyj Stripe Checkout.';

  @override
  String get premiumStoreProductUnavailable =>
      'Ten produkt subskrypcyjny nie jest dostępny w sklepie na tym urządzeniu.';

  @override
  String get premiumStoreVerificationUnavailable =>
      'Weryfikacja sklepu po stronie serwera nie jest jeszcze skonfigurowana.';

  @override
  String get premiumStorePurchaseInvalid =>
      'Nie udało się zweryfikować zakupu.';

  @override
  String get premiumStorePurchaseInactive =>
      'Ta subskrypcja nie jest już aktywna.';

  @override
  String get premiumPurchaseActivated => 'Premium jest już aktywne.';

  @override
  String get premiumRecentlyActivatedBadge => 'Just activated';

  @override
  String get premiumRecentlyActivatedTitle => 'Premium confirmed';

  @override
  String get premiumRecentlyActivatedMessage =>
      'Your Premium access is active on this device and ready to use.';

  @override
  String get premiumPurchaseCancelled => 'Zakup został anulowany.';

  @override
  String get premiumCheckoutFailed =>
      'Premium checkout jest tymczasowo niedostępny.';

  @override
  String get premiumManageFailed =>
      'Zarządzanie płatnościami nie jest jeszcze dostępne dla tego konta.';

  @override
  String get premiumRestoreStarted =>
      'Status Premium został odświeżony na tym urządzeniu.';

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
  String get profileLinkedAccountsSignInRequired =>
      'Zaloguj się ponownie, aby zarządzać połączonymi kontami.';

  @override
  String get profileLinkedAccountsUnavailable =>
      'Połączone konta są tymczasowo niedostępne.';

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
  String get profileNotificationsLoading => 'Loading notification settings...';

  @override
  String get profileNotificationsPushSection => 'Push notifications';

  @override
  String get profileNotificationsPushPhotoReady => 'Photo is ready';

  @override
  String get profileNotificationsPushVideoReady => 'Video is ready';

  @override
  String get profileNotificationsPushGenerationErrors => 'Generation errors';

  @override
  String get profileNotificationsPushReminders => 'Reminders';

  @override
  String get profileNotificationsPushNewTemplates => 'New templates';

  @override
  String get profileNotificationsPushPurchasesAndSubscriptions =>
      'Purchases and subscriptions';

  @override
  String get profileNotificationsEmailSection => 'Email';

  @override
  String get profileNotificationsEmailOffers => 'Offers and discounts';

  @override
  String get profileNotificationsEmailNews => 'PetMagic news';

  @override
  String get profileNotificationsEmailAccountAlerts =>
      'Important account alerts';

  @override
  String get profileNotificationsDeviceSection => 'Device status';

  @override
  String get profileNotificationsPushPermissionLabel => 'Push permissions';

  @override
  String get profileNotificationsPushPermissionAllowed => 'Allowed';

  @override
  String get profileNotificationsPushPermissionDenied =>
      'Disabled in device settings';

  @override
  String get profileNotificationsPushPermissionNotDetermined =>
      'Not requested yet';

  @override
  String get profileNotificationsPushPermissionProvisional => 'Allowed quietly';

  @override
  String get profileNotificationsPushPermissionUnknown => 'Unknown';

  @override
  String get profileNotificationsRefreshStatus => 'Refresh status';

  @override
  String get profileNotificationsRequestPermission =>
      'Allow push notifications';

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
  String get profileLegalDocumentInfoSection => 'Document info';

  @override
  String get profileLegalOpenFullAction => 'Open full policy';

  @override
  String get profileLegalCompactHint =>
      'Najpierw widzisz skrót, a szczegóły rozwijasz tylko wtedy, gdy są potrzebne.';

  @override
  String get profileLegalCurrentAcceptedHint =>
      'Dla tego konta nie jest wymagane dodatkowe potwierdzenie.';

  @override
  String get profileLegalCompactSectionLabel => 'Dotknij, aby rozwinąć';

  @override
  String get profilePrivacyQuickDataTitle => 'What we collect';

  @override
  String get profilePrivacyQuickDataBody =>
      '• Email\n• Profile name\n• Generation history\n• Uploaded pet photos\n• Purchase history\n• Support requests';

  @override
  String get profilePrivacyQuickUsageTitle => 'Why we use it';

  @override
  String get profilePrivacyQuickUsageBody =>
      '• Run app features\n• Generate content\n• Respond in support\n• Protect account and payments';

  @override
  String get profilePrivacyQuickSharingTitle => 'Do we share data?';

  @override
  String get profilePrivacyQuickSharingBody =>
      'We do not sell personal data. Data may be shared only with processors needed to operate the service (for example payments, cloud hosting, and analytics).';

  @override
  String get profilePrivacyQuickRightsTitle => 'Your rights';

  @override
  String get profilePrivacyQuickRightsBody =>
      '• Request a copy of your data\n• Request account and data deletion\n• Withdraw consent where applicable';

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
  String get supportChatSecureTitle =>
      'Your conversation is protected. We use it only for support.';

  @override
  String get supportChatSecureSubtitle =>
      'We protect your data and keep your information private.';

  @override
  String get supportChatTeamTitle => 'PetMagic Support';

  @override
  String get supportChatTeamStatus => 'We usually reply within 24 hours';

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
  String get supportChatWelcomeTitle =>
      'Hello! Describe your issue and we will help.';

  @override
  String get supportChatWelcomeBody =>
      'You can also choose one of the common topics below.';

  @override
  String get supportChatQuickActionGeneration => 'Issue with image generation';

  @override
  String get supportChatQuickActionPayment => 'Payment problem';

  @override
  String get supportChatQuickActionRefund => 'Refund request';

  @override
  String get supportChatQuickActionHuman => 'Talk to an operator';

  @override
  String get supportChatQuickActionSubscription => 'Problem z subskrypcją';

  @override
  String get supportChatQuickActionVideo => 'Wideo się nie tworzy';

  @override
  String get supportChatQuickActionTokens => 'Tokeny nie zostały naliczone';

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
      'The support team will reply in this chat. We usually respond within 24 hours.';

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
  String get supportChatWaitingForSupportStatus => 'Waiting for support';

  @override
  String get supportChatWaitingForSupportStatusHint =>
      'The request is open. Support will see the new message.';

  @override
  String get supportChatInProgressStatusHint =>
      'Support is reviewing your issue.';

  @override
  String get supportChatAwaitingYourReplyStatus => 'Awaiting your reply';

  @override
  String get supportChatSupportRepliedStatusHint =>
      'Support replied. Did this help?';

  @override
  String get supportChatResolvedStatusHint =>
      'This request was marked as resolved. You can reopen it for 7 days.';

  @override
  String get supportChatClosedStatusHint =>
      'Conversation is closed. Send a new message to reopen it.';

  @override
  String get supportChatMessageDelivered => 'Dostarczono';

  @override
  String get supportChatMessageRead => 'Przeczytano';

  @override
  String get supportChatUnavailableError =>
      'Nie można teraz połączyć się ze wsparciem. Spróbuj ponownie za chwilę.';

  @override
  String get supportChatAttachmentUnavailableError =>
      'Nie można teraz wysłać załącznika. Spróbuj ponownie za chwilę.';

  @override
  String get supportChatAttachmentTooLargeError =>
      'Załącznik jest za duży. Maksymalny rozmiar to 10 MB.';

  @override
  String get supportChatImageLabel => 'Obraz pomocy';

  @override
  String get supportChatSaveImageAction => 'Zapisz obraz';

  @override
  String get supportChatShareAction => 'Udostępnij';

  @override
  String get supportChatOpenOriginalAction => 'Otwórz oryginał';

  @override
  String get supportChatCloseAction => 'Zamknij';

  @override
  String get supportChatImageSavedMessage => 'Obraz zapisany';

  @override
  String get supportChatSaveImageFailedError => 'Nie udało się zapisać obrazu';

  @override
  String get supportChatShareImageFailedError =>
      'Nie udało się udostępnić obrazu';

  @override
  String get supportChatAttachmentStatusUploading => 'Przesyłanie';

  @override
  String get supportChatAttachmentStatusUploaded => 'Przesłano';

  @override
  String get supportChatAttachmentStatusFailed => 'Błąd';

  @override
  String get supportChatAttachmentStatusRetry => 'Ponów';

  @override
  String supportChatAttachmentUploadingWithCount(Object current, Object total) {
    return 'Uploading photo $current of $total';
  }

  @override
  String get supportChatImageUploadFailedLabel =>
      'Przesyłanie obrazu nie powiodło się';

  @override
  String get supportChatFileFallbackLabel => 'Plik';

  @override
  String get supportChatSystemNoticeTitle => 'Zgłoszenie wysłane';

  @override
  String get supportChatSystemNoticeBody =>
      'Otrzymaliśmy Twoją wiadomość i odpowiemy wkrótce. Średni czas odpowiedzi to do 24 godzin.';

  @override
  String get supportChatComposerAttachmentChip =>
      '1 zdjęcie: JPG/PNG/WebP, do 10 MB';

  @override
  String get supportChatComposerResponseChip =>
      'Zwykle odpowiadamy w ciągu kilku godzin';

  @override
  String get supportChatAddPhotoTitle => 'Add photo';

  @override
  String get supportChatAddAttachmentTitle => 'Add attachment';

  @override
  String get supportChatTakePhotoAction => 'Take photo';

  @override
  String get supportChatChooseGalleryAction => 'Choose from gallery';

  @override
  String get supportChatChoosePhotosAction => 'Choose photos';

  @override
  String get supportChatRecordVideoAction => 'Record video';

  @override
  String get supportChatChooseVideoAction => 'Choose video';

  @override
  String get supportChatAttachFileAction => 'Files';

  @override
  String get supportChatRecentMediaTitle => 'Recent media';

  @override
  String get supportChatAttachmentNoRecentMedia => 'No recent photos or videos';

  @override
  String get supportChatAttachmentLimitedAccessHint =>
      'Not all photos are available. Allow full gallery access in device settings.';

  @override
  String get supportChatOpenSettingsAction => 'Open settings';

  @override
  String get supportChatAttachmentNoGalleryAccessError =>
      'Gallery access is denied. Allow access in device settings.';

  @override
  String get supportChatAttachmentExpiredPlaceholder =>
      'Attachment was deleted after 30 days';

  @override
  String get supportChatReplyLabel => 'Reply';

  @override
  String get supportChatReplyToPrefix => 'Reply to message';

  @override
  String get supportChatReplyOriginalUnavailable =>
      'Original message is unavailable';

  @override
  String get supportChatPhotoAttachedLabel => 'Photo attached';

  @override
  String get supportChatVideoAttachedLabel => 'Video attached';

  @override
  String get supportChatVideoLabel => 'Support video';

  @override
  String get supportChatAssistantBadge => 'Assistant';

  @override
  String get supportChatTooManyAttachmentsError => 'You can add up to 5 files';

  @override
  String get supportChatAttachmentUnsupportedFormatError =>
      'This format is not supported';

  @override
  String get supportChatAttachmentVideoTooLongError =>
      'Video must be 60 seconds or shorter.';

  @override
  String get supportChatMarkResolvedAction => 'Yes, close request';

  @override
  String get supportChatKeepOpenAction => 'No, write more';

  @override
  String get supportChatCloseRequestDialogTitle => 'Zamknąć zgłoszenie?';

  @override
  String get supportChatCloseRequestDialogBody =>
      'Jeśli problem został rozwiązany, zamkniemy tę rozmowę. Możesz później utworzyć nowe zgłoszenie.';

  @override
  String get supportChatCloseConfirmAction => 'Zamknij';

  @override
  String get supportChatCancelAction => 'Anuluj';

  @override
  String get supportChatArchiveAction => 'Archive';

  @override
  String get supportChatRateTitle => 'Rate the support reply';

  @override
  String supportChatRatedLabel(Object rating) {
    return 'Your rating: $rating/5';
  }

  @override
  String get supportChatReadOnlyHint => 'This conversation is read-only';

  @override
  String get supportHomeTitle => 'Help & Support';

  @override
  String get supportHomeSubtitle => 'What can we help you with?';

  @override
  String get supportHomeTopicGenerationIssue => 'Issue with image generation';

  @override
  String get supportHomeTopicGenerationTooLong => 'Generation takes too long';

  @override
  String get supportHomeTopicTokensNotArrived => 'Tokens did not arrive';

  @override
  String get supportHomeTopicPremiumIssue => 'Premium issue';

  @override
  String get supportHomeTopicPaymentRefund => 'Payment / Refund';

  @override
  String get supportHomeTopicOther => 'Other';

  @override
  String get supportAssistantTitle => 'Support Assistant';

  @override
  String get supportAssistantThisHelpedAction => 'This helped';

  @override
  String get supportAssistantCreateTicketAction => 'Create support ticket';

  @override
  String get supportAssistantCheckLaterAction => 'Check later';

  @override
  String get supportAssistantRecommendationGeneration =>
      'For better results, please use a photo where the pet is clearly visible, not cropped, not blurry, and well lit.';

  @override
  String get supportAssistantRecommendationGenerationTooLong =>
      'Video generation may take several minutes. It usually takes around 2–10 minutes. If it has taken too long, we can send this issue to support.';

  @override
  String get supportAssistantRecommendationTokensNotArrived =>
      'Sometimes token delivery after payment may take a few minutes. If the tokens still do not appear, create a support ticket and we will check the purchase.';

  @override
  String get supportAssistantRecommendationPremiumIssue =>
      'If Premium has already been paid for but is not visible in the app, please try restarting the app. If the problem remains, we will check your subscription status.';

  @override
  String get supportAssistantRecommendationPaymentRefund =>
      'We can check your payment or forward your refund request to support. Create a support ticket and we will attach the relevant purchase information if available.';

  @override
  String get supportAssistantRecommendationOther =>
      'Please describe what happened. You can also attach a screenshot to help support understand the situation faster.';

  @override
  String get supportTicketFormTitle => 'Create support ticket';

  @override
  String get supportTicketFormTopicLabel => 'Topic';

  @override
  String get supportTicketFormDescriptionLabel => 'Problem description';

  @override
  String get supportTicketFormDescriptionHint => 'Describe what happened...';

  @override
  String get supportTicketFormRelatedGenerationLabel => 'Related generation';

  @override
  String get supportTicketFormRelatedPaymentLabel => 'Related payment';

  @override
  String get supportTicketFormRelatedSubscriptionLabel =>
      'Related subscription';

  @override
  String get supportTicketFormAttachmentsLabel => 'Attachments';

  @override
  String get supportTicketFormAddScreenshotAction => 'Add screenshot';

  @override
  String get supportTicketFormSubmitAction => 'Send to support';

  @override
  String get supportTicketFormSubmittingLabel => 'Creating ticket...';

  @override
  String get supportTicketFormSuccessMessage =>
      'Your ticket has been created. We will reply in this chat.';

  @override
  String get supportTicketFormErrorMessage =>
      'Failed to create ticket. Please try again.';

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
  String get profileSettingsLanguageGerman => 'niemiecki';

  @override
  String get profileSettingsLanguageSpanish => 'hiszpański';

  @override
  String get profileSettingsLanguageFrench => 'francuski';

  @override
  String get profileSettingsLanguageItalian => 'włoski';

  @override
  String get profileSettingsLanguagePolish => 'polski';

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
  String get templatesFeedEmptyError => 'Szablony są tymczasowo niedostępne.';

  @override
  String get templatesConnectionTimeoutError =>
      'Brak połączenia. Sprawdź sieć i spróbuj ponownie.';

  @override
  String get templatesServerTimeoutError =>
      'Serwer odpowiadał zbyt długo. Spróbuj ponownie.';

  @override
  String get templatesRequestFailedError =>
      'Nie udało się teraz załadować szablonów. Spróbuj ponownie.';

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
  String get authSignInRequired => 'Wymagane jest zalogowanie.';

  @override
  String get authSessionExpired => 'Sesja wygasła.';

  @override
  String get authLoginFailed => 'Logowanie nie powiodło się. Spróbuj ponownie.';

  @override
  String get authRegistrationFailed =>
      'Rejestracja nie powiodła się. Spróbuj ponownie.';

  @override
  String get authPasswordResetRequestFailed =>
      'Nie udało się wysłać żądania resetu hasła. Spróbuj ponownie.';

  @override
  String get authPasswordResetFailed =>
      'Nie udało się zresetować hasła. Spróbuj ponownie.';

  @override
  String get authRequestFailed => 'Żądanie nie powiodło się. Spróbuj ponownie.';

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

  @override
  String get templateFlowPhotoSourceGallery => 'Gallery';

  @override
  String get templateFlowPhotoSourceCamera => 'Camera';

  @override
  String get templateFlowReadyTitle => 'Ready to create!';

  @override
  String get templateFlowCheckDetailsSubtitle =>
      'Check the details before creating';

  @override
  String get templateFlowTemplateLabel => 'Szablon';

  @override
  String get templateFlowCostLabel => 'Koszt';

  @override
  String get templateFlowBalanceLabel => 'Your balance';

  @override
  String get templateFlowDurationHint =>
      'Creation can take from 10 seconds to 1 minute.';

  @override
  String get templateFlowCreateMagicAction => 'Create magic';

  @override
  String get templateFlowChangePhotoAction => 'Change photo';

  @override
  String get templateFlowPremiumTemplateTitle => 'Premium template';

  @override
  String get templateFlowPremiumTemplateMessage =>
      'This template is available with Premium.';

  @override
  String get templateFlowInsufficientBalanceTitle => 'Not enough PawSpark';

  @override
  String templateFlowInsufficientBalanceMessage(
    Object tokenCost,
    Object balance,
  ) {
    return 'This template costs $tokenCost PawSpark. Your balance: $balance PawSpark.';
  }

  @override
  String get templateFlowChooseAnotherTemplateAction =>
      'Choose another template';

  @override
  String get templateFlowCreateFailedTitle => 'Could not create magic';

  @override
  String get templateFlowCreateFailedBalanceHint =>
      'Top up your balance and try creating again.';

  @override
  String get templateFlowCreateFailedRetryHint =>
      'Try another photo or retry later.';

  @override
  String get templateFlowCreateHint => 'This may take a little time';

  @override
  String get templateFlowStepProcessPhoto => 'Przetwarzanie zdjecia';

  @override
  String get templateFlowStepAnalyzePet => 'Analyzing pet';

  @override
  String get templateFlowStepCreateMagic => 'Tworzenie magii';

  @override
  String get templateFlowStepFinalTouches => 'Ostatnie poprawki';

  @override
  String get templateFlowTopUpBalanceAction => 'Top up balance';

  @override
  String get templateFlowResultReadyTitle => 'Done!';

  @override
  String get templateFlowResultReadySubtitle => 'Your magic is ready';

  @override
  String get templateFlowResultUnavailable => 'Wynik nie jest jeszcze dostepny';

  @override
  String get templateFlowLoadingResult => 'Loading result...';

  @override
  String get templateFlowResultLoadFailed => 'Nie udalo sie zaladowac wyniku';

  @override
  String get templateFlowCreateMoreAction => 'Create more';

  @override
  String get templateFlowPreviewFallback => 'Preview';

  @override
  String get templateFlowLoadingPreview => 'Loading preview...';

  @override
  String get templateFlowPreviewUnavailable => 'Preview unavailable';

  @override
  String get templateFlowLoadingVideo => 'Loading video...';

  @override
  String get templateFlowBestPhotoTitle => 'Best photo for this template:';

  @override
  String get templateFlowUploadPetPhotoAction => 'Upload a pet photo';

  @override
  String get templateFlowPremiumRequiredError =>
      'This template is available only with Premium.';

  @override
  String get templateFlowInsufficientBalanceError =>
      'Not enough PawSpark to start generation.';

  @override
  String get templateFlowNetworkError =>
      'No connection. Check your network and try again.';

  @override
  String get templateFlowServerError =>
      'Service is temporarily unavailable. Please try again later.';

  @override
  String get templateFlowStartFailedError =>
      'Could not start generation. Please try again.';

  @override
  String get generationStatusTitle => 'Status generowania';

  @override
  String get generationStatusCreatedLabel => 'Utworzono';

  @override
  String get generationStatusStartedLabel => 'Rozpoczeto';

  @override
  String get generationStatusTypeLabel => 'Typ';

  @override
  String get generationStatusAttemptLabel => 'Proba';

  @override
  String get generationStatusUntitledFallback => 'Bez tytulu';

  @override
  String get generationStatusDetailsTitle => 'Szczegoly';

  @override
  String get generationStatusFeedbackTitle => 'Jak oceniasz wynik?';

  @override
  String get generationStatusFeedbackExcellent => 'Swietnie';

  @override
  String get generationStatusFeedbackOkay => 'W porzadku';

  @override
  String get generationStatusFeedbackBad => 'Niezbyt dobrze';

  @override
  String get generationStatusSaveAction => 'Zapisz';

  @override
  String get generationStatusDeleteAction => 'Usun';

  @override
  String get generationStatusReportProblemAction => 'Zglos problem';

  @override
  String get generationStatusPickAnotherPhotoAction => 'Wybierz inne zdjecie';

  @override
  String get generationStatusRetryAction => 'Sprobuj ponownie';

  @override
  String get generationStatusContactSupportAction =>
      'Skontaktuj sie ze wsparciem';

  @override
  String get generationStatusOpenGalleryAction => 'Otworz galerie';

  @override
  String get generationStatusOpenStatusAction => 'Otworz status';

  @override
  String get generationStatusCancelGenerationAction => 'Anuluj generowanie';

  @override
  String get generationStatusResultUnavailableForSave =>
      'Wynik nie jest jeszcze dostepny do zapisu.';

  @override
  String get generationStatusResultUnavailableForShare =>
      'Wynik nie jest jeszcze dostepny do udostepniania.';

  @override
  String get generationStatusSaveFileDialogTitle => 'Zapisz plik';

  @override
  String get generationStatusFileSavedMessage => 'Plik zapisano na urzadzeniu.';

  @override
  String get generationStatusFileSaveFailedMessage =>
      'Nie udalo sie zapisac pliku. Sprobuj ponownie.';

  @override
  String get generationStatusSavedToGalleryMessage => 'Zapisano w galerii';

  @override
  String get generationStatusLinkCopiedMessage => 'Link skopiowany';

  @override
  String get generationStatusDeletedMessage => 'Usunieto';

  @override
  String get generationStatusFullscreenControlsHint =>
      'Dotknij, aby ukryc/pokazac kontrolki';

  @override
  String get generationStatusDeleteSoonMessage =>
      'Usuwanie bedzie wkrotce dostepne.';

  @override
  String get generationStatusCancelSoonMessage =>
      'Anulowanie generowania bedzie wkrotce dostepne.';

  @override
  String get generationStatusRetrySoonMessage =>
      'Wybierz inne zdjecie i uruchom generowanie ponownie.';

  @override
  String get generationStatusFeedbackThanksMessage =>
      'Dziekujemy! Twoja opinia pomaga ulepszac PetMagic.';

  @override
  String get generationStatusResultTitle => 'Wynik PetMagic';

  @override
  String get generationStatusNonTerminalHint =>
      'Zwykle trwa to kilka minut. Mozesz dalej korzystac z aplikacji.';

  @override
  String get generationStatusStageQueued => 'W kolejce';

  @override
  String get generationStatusStageDone => 'Gotowe';

  @override
  String get generationStatusVideoReady => 'Wideo jest gotowe';

  @override
  String get generationStatusShareVideoAction => 'Udostepnij wideo';

  @override
  String get generationStatusFailedTitle => 'Nie udalo sie utworzyc wyniku';

  @override
  String get generationStatusTokensRefundedHint =>
      'Tokeny zostaly zwrocone na Twoje saldo.';

  @override
  String get generationStatusTokensRefundedShort => 'Tokeny zwrocone';

  @override
  String get generationStatusSupportHint =>
      'Jesli problem sie powtorzy, skontaktuj sie ze wsparciem.';

  @override
  String get generationStatusBackgroundHint =>
      'Generowanie trwa na serwerze. Pokazemy wynik w Galerii, gdy bedzie gotowy.';

  @override
  String get generationStatusDownloadAction => 'Pobierz';

  @override
  String get generationStatusContinueInAppAction => 'Kontynuuj w aplikacji';

  @override
  String get generationStatusFeedbackImproveTitle => 'Co mozemy poprawic?';

  @override
  String get generationStatusFeedbackCommentLabel => 'Komentarz';

  @override
  String get generationStatusFeedbackCommentHint =>
      'Krotko opisz, co bylo nie tak';

  @override
  String get generationStatusFeedbackSubmitAction => 'Wyslij opinie';

  @override
  String get generationStatusFeedbackReasonPetNotSimilar =>
      'Zwierzak nie przypomina siebie';

  @override
  String get generationStatusFeedbackReasonFaceDistorted =>
      'Pysk lub twarz sa znieksztalcone';

  @override
  String get generationStatusFeedbackReasonStrangeMotion =>
      'Ruch wyglada dziwnie';

  @override
  String get generationStatusFeedbackReasonPreviewMismatch =>
      'Wynik rozni sie od podgladu';

  @override
  String get generationStatusFeedbackReasonLowQuality =>
      'Jakosc jest zbyt niska';

  @override
  String get generationStatusFeedbackReasonStyleDisliked =>
      'Nie podobal mi sie styl';

  @override
  String get generationStatusFeedbackReasonOther => 'Inne';

  @override
  String generationStatusEtaEstimated(Object value) {
    return 'Pozostalo okolo $value';
  }

  @override
  String get generationStatusEtaQueued => 'Oczekiwanie w kolejce';

  @override
  String get generationStatusEtaFinalizing => 'Prawie gotowe';

  @override
  String get generationStatusEtaDefault => 'Pozostalo okolo 1-2 min';

  @override
  String get generationStatusEtaStartsSoon => 'Rozpocznie sie za kilka minut';

  @override
  String get generationStatusEtaNotifyHint =>
      'Powiadomimy Cie, gdy wynik bedzie gotowy.';

  @override
  String get generationStatusFailurePhotoHint =>
      'Zdjecie nie pasuje do tego szablonu. Sprobuj zdjecia, na ktorym zwierzak jest dobrze widoczny.';

  @override
  String get generationStatusFailureTechnicalHint =>
      'Nie udalo sie utworzyc wyniku z powodu problemu technicznego. Tokeny zostaly zwrocone na Twoje saldo.';

  @override
  String get generationStatusStatusCompleted => 'Twoj wynik jest gotowy';

  @override
  String get generationStatusStatusFailed => 'Nie udalo sie utworzyc wyniku';

  @override
  String get generationStatusStatusCreatingMagic => 'Tworzenie magii...';

  @override
  String get generationStatusTerminalRefundedHint =>
      'Tokeny zostaly zwrocone automatycznie.';

  @override
  String get generationStatusTerminalFailureHint =>
      'Zarejestrowano problem techniczny.';

  @override
  String get generationStatusTerminalSuccessHint =>
      'Otworz wynik, udostepnij go lub zostaw opinie.';

  @override
  String get generationStatusSectionActive => 'W trakcie';

  @override
  String get generationStatusSectionReady => 'Gotowe';

  @override
  String get generationStatusSectionFailed => 'Nieudane';

  @override
  String get generationStatusFilterActive => 'W trakcie';

  @override
  String get generationStatusFilterReady => 'Gotowe';

  @override
  String get generationStatusFilterFailed => 'Nieudane';

  @override
  String generationStatusShowMoreAction(int hiddenCount) {
    return 'Pokaz wiecej ($hiddenCount) ▾';
  }

  @override
  String get generationStatusCollapseAction => 'Zwin ▲';

  @override
  String get generationStatusActiveInfoHint =>
      'Mozesz zamknac aplikacje. Powiadomimy Cie, gdy wynik bedzie gotowy.';

  @override
  String generationStatusUnreadCount(int count) {
    return '$count nowych';
  }

  @override
  String get generationStatusEmptyTitle => 'Twoje wyniki pojawia sie tutaj';

  @override
  String get generationStatusEmptyMessage =>
      'Wybierz szablon, przeslij zdjecie zwierzaka i stworz swoja pierwsza magiczna prace.';

  @override
  String get generationStatusSubtitleAll => 'Twoje magiczne kreacje';

  @override
  String get generationStatusSubtitleActive => 'Aktywne generacje';

  @override
  String get generationStatusSubtitleReady => 'Twoje gotowe wyniki';

  @override
  String get generationStatusSubtitleFailed => 'Problemy z generowaniem';

  @override
  String generationStatusDateToday(Object time) {
    return 'Dzisiaj, $time';
  }

  @override
  String generationStatusDateYesterday(Object time) {
    return 'Wczoraj, $time';
  }

  @override
  String shellActiveGenerationLabel(Object templateTitle) {
    return '✨ Tworzenie $templateTitle';
  }

  @override
  String get shellActiveGenerationFallback => 'wynik';
}
