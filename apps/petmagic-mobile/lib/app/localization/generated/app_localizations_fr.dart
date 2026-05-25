// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get navTemplates => 'Modeles';

  @override
  String get navCreations => 'Galerie';

  @override
  String get navRewards => 'Rewards';

  @override
  String get navProfile => 'Profil';

  @override
  String get comingSoonMessage =>
      'Cette section est prete pour la prochaine etape produit.';

  @override
  String get createMagicTitle => 'Creer la magie';

  @override
  String get pickTemplateSubtitle => 'Choisissez un modele pour votre animal';

  @override
  String get searchTemplates => 'Rechercher des modeles';

  @override
  String get allFilter => 'Tous';

  @override
  String get videosFilter => 'Vidéos';

  @override
  String get imagesFilter => 'Images';

  @override
  String get trendingFilter => '🔥 Tendances';

  @override
  String get funnyFilter => '😂 Drole';

  @override
  String get danceFilter => '🕺 Danse';

  @override
  String get magicFilter => '✣ Magie';

  @override
  String get adventureFilter => '🌄 Aventure';

  @override
  String get filtersTooltip => 'Filtres';

  @override
  String get giftTooltip => 'Recompenses';

  @override
  String get addTokensTooltip => 'Ajouter PawSpark';

  @override
  String get premiumLabel => 'Prime';

  @override
  String get freeLabel => 'Gratuit';

  @override
  String get profileTitle => 'Votre profil';

  @override
  String get profileSubtitle => 'Gérez la connexion et votre avatar public.';

  @override
  String get profileDashboardSubtitle =>
      'Gérez votre compte et personnalisez votre expérience PetMagic.';

  @override
  String get profileSignInTitle => 'Connectez-vous pour continuer';

  @override
  String get profileSignInHint =>
      'Utilisez votre compte PetMagic pour charger votre profil et gérer l\'avatar visible dans l\'administrateur.';

  @override
  String get profileEmailLabel => 'E-mail';

  @override
  String get profilePasswordLabel => 'Mot de passe';

  @override
  String get profileSignInAction => 'Se connecter';

  @override
  String get profileSignOutAction => 'se déconnecter';

  @override
  String get profileLoadingAction => 'Fonctionnement...';

  @override
  String get profileAvatarUpload => 'Télécharger un avatar';

  @override
  String get profileAvatarRemove => 'Supprimer l\'avatar';

  @override
  String get profileEmailConfirmed => 'E-mail confirmé';

  @override
  String get profileEmailPending => 'E-mail non confirmé';

  @override
  String get profileEmailVerifiedShort => 'Email verified';

  @override
  String get profileEmailPendingShort => 'Verify email';

  @override
  String get profileSignedOut => 'Déconnecté sur cet appareil.';

  @override
  String get profileAccountCenterTitle => 'Centre de comptes';

  @override
  String get profileAccountCenterSubtitle =>
      'Vérifiez vos préférences, votre confidentialité et la configuration de l\'application.';

  @override
  String get profileTermsStat => 'Conditions acceptées';

  @override
  String get profileMarketingStat => 'Offres et mises à jour';

  @override
  String get profileEmailStat => 'Statut de l\'e-mail';

  @override
  String get profileStatOn => 'Sur';

  @override
  String get profileStatOff => 'Désactivé';

  @override
  String get profileStatReady => 'Prêt';

  @override
  String get profileStatPending => 'En attente';

  @override
  String get profilePetsTitle => 'Mes animaux de compagnie';

  @override
  String get profilePetsSubtitle =>
      'Vos compagnons et profils d\'animaux préférés.';

  @override
  String get profilePremiumTitle => 'Passez à la version premium';

  @override
  String get profilePremiumSubtitle =>
      'Débloquez tous les modèles et flux d’édition premium.';

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
  String get walletBalanceEyebrow => 'Current balance';

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
  String get walletWatchAdAction => 'Get +15 PawSpark';

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
  String get walletWhatYouCanCreateTitle => 'Your balance is enough for:';

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
  String get rewardsPageTitle => 'Rewards and promo codes';

  @override
  String get rewardsPageSubtitle =>
      'Activate promo codes, invite friends, and earn rewards.';

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
  String get rewardsPromoTitle => 'Promo codes';

  @override
  String get rewardsPromoSubtitle =>
      'Enter a promo code to top up your PawSpark balance.';

  @override
  String get rewardsPromoEmptyError => 'Enter promo code.';

  @override
  String get rewardsPromoCheckingStatus => 'Checking code...';

  @override
  String get rewardsReferralTitle => 'Referral bonuses';

  @override
  String get rewardsReferralSubtitle =>
      'Share your code with a friend. Referral bonus is not paid for signup and is credited only after their first successful paid purchase.';

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
      'Enter it before your first purchase.';

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
  String get rewardsReferralEarnedLabel => 'PawSpark earned';

  @override
  String get rewardsReferralFriendsLabel => 'Friends invited';

  @override
  String get rewardsReferralBonusLabel => 'Completed purchases';

  @override
  String rewardsReferralBonusPerFriend(int count) {
    return '+$count PawSpark per invited friend';
  }

  @override
  String get rewardsReferralRulesNote =>
      'No signup bonus. Referral reward is credited only after a successful first paid purchase.';

  @override
  String rewardsReferralShareMessage(Object code, int bonus) {
    return 'Join me in PetMagic! Use my referral code $code. Bonus is credited after your first successful paid purchase. After your first purchase I\'ll receive +$bonus PawSpark.';
  }

  @override
  String get rewardsHistoryTitle => 'Bonus history';

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
  String get profileCommunicationsTitle => 'Mises à jour de PetMagic';

  @override
  String get profileCommunicationsEnabled =>
      'Vous êtes abonné aux mises à jour et offres de produits.';

  @override
  String get profileCommunicationsDisabled =>
      'Les mises à jour marketing sont actuellement désactivées.';

  @override
  String get profilePrivacyTitle => 'Confidentialité et consentement';

  @override
  String get profileTermsAccepted =>
      'Votre compte a accepté les conditions d\'utilisation et la politique de confidentialité.';

  @override
  String get profileTermsPending =>
      'Terminez l’examen du consentement dans les paramètres du compte.';

  @override
  String get profileLegalShortcutTitle => 'Privacy & Legal';

  @override
  String get profileLegalShortcutAccepted =>
      'Terms accepted • Privacy settings';

  @override
  String get profileLegalShortcutPending => 'Review permissions';

  @override
  String get profileSupportTitle => 'Contacter l\'assistance';

  @override
  String get profileSupportSubtitle =>
      'Nous sommes là lorsque vous avez besoin d\'aide avec votre compte.';

  @override
  String get profileSupportCompactSubtitle =>
      'Get help with billing or account access.';

  @override
  String get profileSettingsShortcutTitle => 'Paramètres';

  @override
  String get profileSettingsShortcutSubtitle =>
      'Gérez les sections de langue, de thème et de compte.';

  @override
  String get profileSettingsCompactSubtitle =>
      'Language, theme and account settings.';

  @override
  String get profilePreferenceEnabled => 'Activé';

  @override
  String get profilePreferenceOff => 'Désactivé';

  @override
  String get profileSettingsTitle => 'Paramètres';

  @override
  String get profileSettingsSubtitle => 'Gérez l\'application et votre compte.';

  @override
  String get profileSettingsAccountSection => 'Compte';

  @override
  String get profileSettingsNotificationsSection => 'Notifications';

  @override
  String get profileSettingsPreferencesSection => 'Préférences';

  @override
  String get profileSettingsSupportSection => 'Soutien';

  @override
  String get profileSettingsAboutSection => 'À propos de l\'application';

  @override
  String get profileSettingsDangerSection => 'Zone dangereuse';

  @override
  String get profileSettingsAccountInfoTitle => 'Informations sur le compte';

  @override
  String get profileSettingsUnavailableSubtitle =>
      'Ces informations deviennent disponibles après la connexion.';

  @override
  String get profileSettingsLinkedAccountsTitle => 'Comptes liés';

  @override
  String get profileSettingsLinkedAccountsSubtitle =>
      'Google, Apple et d\'autres fournisseurs apparaîtront ici.';

  @override
  String get profileSettingsPasswordTitle => 'Changer le mot de passe';

  @override
  String get profileSettingsPasswordSubtitle =>
      'Mettez à jour votre mot de passe pour sécuriser le compte.';

  @override
  String get profileSettingsNotificationsTitle => 'Paramètres de notification';

  @override
  String get profileSettingsNotificationsSubtitle =>
      'Gérez les préférences push et email dans l\'application.';

  @override
  String get profileSettingsLanguageTitle => 'Langue de l\'application';

  @override
  String get profileSettingsLanguageSubtitle =>
      'Choisissez la langue utilisée dans toute l\'interface.';

  @override
  String get profileSettingsThemeTitle => 'Thème de l\'application';

  @override
  String get profileSettingsThemeSubtitle =>
      'Basculez entre le système, l’apparence claire et sombre.';

  @override
  String get profileSettingsHelpCenterTitle => 'Centre d\'aide';

  @override
  String get profileSettingsHelpCenterSubtitle =>
      'Réponses rapides et guides pour les questions courantes.';

  @override
  String get profileSettingsSupportTitle => 'Contacter l\'assistance';

  @override
  String get profileSettingsSupportSubtitle =>
      'Contactez-nous si vous avez besoin d\'aide pour la facturation ou l\'accès au compte.';

  @override
  String get profileSettingsTermsTitle => 'Conditions d\'utilisation';

  @override
  String get profileSettingsTermsSubtitle =>
      'Consultez les règles d\'utilisation de PetMagic.';

  @override
  String get profileSettingsPrivacyTitle => 'politique de confidentialité';

  @override
  String get profileSettingsPrivacySubtitle =>
      'Découvrez comment vos données sont traitées et protégées.';

  @override
  String get profileSettingsDeleteAccountTitle => 'Supprimer le compte';

  @override
  String get profileSettingsDeleteAccountSubtitle =>
      'Cette action ne peut pas être annulée.';

  @override
  String get profileAccountDetailsSubtitle =>
      'Vérifiez les données de compte actuellement disponibles sur cet appareil.';

  @override
  String get profileAccountDetailsSection => 'Détails du compte';

  @override
  String get profileAccountUserIdLabel => 'ID de l\'utilisateur';

  @override
  String get profileAccountDisplayNameLabel => 'Nom d\'affichage';

  @override
  String get profileAccountDisplayNameMissing => 'Pas encore défini';

  @override
  String get profileAccountRolesLabel => 'Rôles';

  @override
  String get profileAccountRolesMissing => 'Aucun rôle attribué';

  @override
  String get profileAccountMembershipLabel => 'Adhésion';

  @override
  String get profileAccountConsentLabel => 'Acceptation des conditions';

  @override
  String get profileAccountMarketingLabel => 'Offres et mises à jour';

  @override
  String get profileAccountAvatarLabel => 'Avatar';

  @override
  String get profileAccountAvatarMissing => 'Aucun avatar téléchargé';

  @override
  String get profileAccountAvatarUploaded => 'Avatar téléchargé';

  @override
  String get profileDetailsCurrentStatusSection => 'Statut actuel';

  @override
  String get profileDetailsNextStepSection => 'Que se passe-t-il ensuite';

  @override
  String get profileDetailsLinkedAccountsBody =>
      'Les fournisseurs connectés apparaîtront ici dès que la liaison sera activée pour votre compte.';

  @override
  String get profileDetailsLinkedAccountsStatus =>
      'Aucun fournisseur externe n\'est encore lié. L\'e-mail et le mot de passe restent la méthode de connexion active pour ce profil.';

  @override
  String get profileDetailsLinkedAccountsNext =>
      'Google, Apple et d\'autres fournisseurs seront affichés ici après l\'ouverture du flux de liaison backend dans l\'application.';

  @override
  String get profileLinkedAccountsLoading =>
      'Chargement des fournisseurs de connexion liés...';

  @override
  String get profileLinkedAccountsConnectedStatus =>
      'Connecté et prêt pour la connexion.';

  @override
  String get profileLinkedAccountsNotConnectedStatus => 'Pas encore connecté.';

  @override
  String get profileLinkedAccountsConnectAction => 'Connecter';

  @override
  String get profileLinkedAccountsDisconnectAction => 'Déconnecter';

  @override
  String get profileLinkedAccountsProtectedHint =>
      'Ce fournisseur ne peut pas être supprimé tant qu\'une autre méthode de connexion n\'est pas disponible.';

  @override
  String get profileLinkedAccountsSignInRequired =>
      'Reconnectez-vous pour gérer les comptes liés.';

  @override
  String get profileLinkedAccountsUnavailable =>
      'Les comptes liés sont temporairement indisponibles.';

  @override
  String get profileDetailsNotificationsBody =>
      'Cette section reflète vos préférences de communication actuelles dans l\'application.';

  @override
  String get profileDetailsNotificationsStatusEnabled =>
      'Les mises à jour de produits et les offres sont activées pour ce profil. Des commandes push supplémentaires apparaîtront ici plus tard.';

  @override
  String get profileDetailsNotificationsStatusDisabled =>
      'Les e-mails marketing sont actuellement désactivés pour ce profil. Des commandes push supplémentaires apparaîtront ici plus tard.';

  @override
  String get profileDetailsNotificationsNext =>
      'Vous pouvez déjà consulter les préférences de courrier électronique actuelles ici. Des boutons poussoirs dédiés seront ajoutés dans une tranche de produit ultérieure.';

  @override
  String get profileDetailsHelpBody =>
      'Le centre d\'aide rassemblera des réponses rapides, des conseils de configuration et des conseils sur le compte en un seul endroit.';

  @override
  String get profileDetailsHelpStatus =>
      'La base de connaissances intégrée à l\'application est toujours en cours d\'assemblage. Cet écran affiche donc l\'état actuel du déploiement.';

  @override
  String get profileDetailsHelpNext =>
      'Les premiers articles d\'aide et guides de dépannage apparaîtront ici au fur et à mesure de la publication du contenu de l\'assistance mobile.';

  @override
  String get profileDetailsSupportBody =>
      'Les demandes d\'assistance seront traitées ici sans vous forcer à quitter la zone de profil.';

  @override
  String get profileDetailsSupportStatus =>
      'Le contact direct dans l\'application n\'est pas encore câblé. Pour l’instant, conservez cet écran comme point d’entrée du support pour la tranche suivante.';

  @override
  String get profileDetailsSupportNext =>
      'L\'étape suivante est un véritable formulaire d\'assistance ou un transfert d\'e-mail connecté au flux d\'assistance backend.';

  @override
  String get profileDetailsTermsBody =>
      'Vérifiez comment PetMagic s\'attend à ce que l\'application et le compte soient utilisés.';

  @override
  String get profileDetailsTermsStatusAccepted =>
      'Ce compte a déjà accepté les conditions d\'utilisation lors de l\'inscription.';

  @override
  String get profileDetailsTermsStatusPending =>
      'Ce compte n\'a pas encore enregistré d\'acceptation des conditions complétées.';

  @override
  String get profileDetailsTermsNext =>
      'Une vue plus complète du document juridique peut être jointe ici ultérieurement. Pour l\'instant, cet écran confirme l\'état d\'acceptation actuel.';

  @override
  String get profileDetailsPrivacyBody =>
      'Découvrez comment PetMagic stocke, protège et utilise les données de compte.';

  @override
  String get profileDetailsPrivacyStatus =>
      'Les détails de confidentialité sont actuellement représentés sous la forme d\'un écran de résumé dans l\'application pendant que le flux complet des documents juridiques est préparé.';

  @override
  String get profileDetailsPrivacyNext =>
      'La tranche suivante peut joindre un document de politique complet ou une page juridique hébergée à cette route.';

  @override
  String get profileLegalAcceptanceCurrent =>
      'Les documents juridiques actuels sont acceptés pour ce compte.';

  @override
  String get profileLegalAcceptanceRequired =>
      'Ce compte doit accepter les versions actuelles des documents juridiques.';

  @override
  String get profileLegalVersionLabel => 'Version actuelle';

  @override
  String get profileLegalPublishedLabel => 'Publié';

  @override
  String get profileLegalAcceptedVersionLabel => 'Version acceptée';

  @override
  String get profileLegalAcceptedAtLabel => 'Accepté le';

  @override
  String get profileLegalLoading =>
      'Chargement du document juridique actuel depuis le backend...';

  @override
  String get profileLegalUnavailable =>
      'Le document juridique actuel ne peut pas être chargé pour le moment.';

  @override
  String get profileLegalAcceptAction =>
      'Accepter les documents juridiques actuels';

  @override
  String get profileLegalAcceptanceGuestHint =>
      'Lors de l\'inscription, vous accepterez la version actuelle des Conditions d\'utilisation et de la Politique de confidentialité.';

  @override
  String get profileLegalDocumentSection => 'Document';

  @override
  String get profileLegalCompactHint =>
      'Le résumé reste visible et les détails ne s\'ouvrent qu\'en cas de besoin.';

  @override
  String get profileLegalCurrentAcceptedHint =>
      'Aucune confirmation supplémentaire n\'est nécessaire pour ce compte.';

  @override
  String get profileLegalCompactSectionLabel => 'Appuyer pour développer';

  @override
  String get profileDetailsDeleteBody =>
      'La suppression du compte est intentionnellement protégée et n\'est pas encore exécutée à partir de cet écran.';

  @override
  String get profileDetailsDeleteStatus =>
      'La suppression n\'est pas disponible en un seul clic dans l\'application mobile pour le moment. Cela évite un comportement destructeur avant que le flux de confirmation du backend ne soit prêt.';

  @override
  String get profileDetailsDeleteNext =>
      'Lorsque le workflow de suppression backend est mis en œuvre, cet écran peut devenir l\'étape de confirmation et de vérification au lieu d\'un espace réservé.';

  @override
  String get supportChatTitle => 'Chat d\'assistance';

  @override
  String get supportChatSubtitle =>
      'Envoyez un message à l\'équipe PetMagic directement depuis votre profil.';

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
  String get supportChatInputHint =>
      'Décrivez le problème, la question ou la demande...';

  @override
  String get supportChatSendAction => 'Envoyer';

  @override
  String get supportChatEmptyTitle => 'Démarrer la conversation';

  @override
  String get supportChatEmptyMessage =>
      'Votre chat d\'assistance est prêt. Envoyez le premier message et l’équipe répondra ici.';

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
  String get supportChatStatusOpen => 'Ouvrir';

  @override
  String get supportChatStatusInProgress => 'En cours';

  @override
  String get supportChatStatusResolved => 'Résolu';

  @override
  String get supportChatStatusClosed => 'Fermé';

  @override
  String get supportChatMessageDelivered => 'Livre';

  @override
  String get supportChatMessageRead => 'Lu';

  @override
  String get supportChatUnavailableError =>
      'Impossible de joindre le support pour le moment. Réessayez dans un instant.';

  @override
  String get supportChatAttachmentUnavailableError =>
      'Impossible d\'envoyer la pièce jointe pour le moment. Réessayez dans un instant.';

  @override
  String get profileSettingsThemeSystem => 'Système';

  @override
  String get profileSettingsThemeLight => 'Lumière';

  @override
  String get profileSettingsThemeDark => 'Sombre';

  @override
  String get profileSettingsLanguageRussian => 'russe';

  @override
  String get profileSettingsLanguageEnglish => 'Anglais';

  @override
  String get profileSettingsLanguageGerman => 'Allemand';

  @override
  String get profileSettingsLanguageSpanish => 'Espagnol';

  @override
  String get profileSettingsLanguageFrench => 'Français';

  @override
  String get profileSettingsLanguageItalian => 'Italien';

  @override
  String get profileSettingsLanguagePolish => 'Polonais';

  @override
  String profileSettingsVersionLabel(Object version) {
    return 'Version de l\'application $version';
  }

  @override
  String get magicLoadingPreparing => 'Preparation de la magie...';

  @override
  String get magicLoadingCutestAngle =>
      'Recherche de l\'angle le plus mignon...';

  @override
  String get magicLoadingAiPaws => 'Activation des pattes AI...';

  @override
  String get magicLoadingCreatingAdorable =>
      'Creation de quelque chose d\'adorable...';

  @override
  String get magicLoadingAlmostReady => 'Presque pret...';

  @override
  String get videoLabel => 'Vidéo';

  @override
  String get imageLabel => 'Image';

  @override
  String get templatesErrorTitle => 'Les modeles n\'ont pas charge';

  @override
  String get retryAction => 'Reessayer';

  @override
  String get emptyTemplatesTitle => 'Aucun modele pour le moment';

  @override
  String get emptyTemplatesMessage =>
      'Essayez un autre filtre ou actualisez le catalogue.';

  @override
  String get templatesFeedEmptyError =>
      'Les modèles sont temporairement indisponibles.';

  @override
  String get templatesConnectionTimeoutError =>
      'Aucune connexion. Vérifiez votre réseau et réessayez.';

  @override
  String get templatesServerTimeoutError =>
      'Le serveur a mis trop de temps à répondre. Veuillez réessayer.';

  @override
  String get templatesRequestFailedError =>
      'Impossible de charger les modèles pour le moment. Veuillez réessayer.';

  @override
  String get startupOnboardingActionContinueGuest =>
      'Continuer en tant qu\'invité';

  @override
  String get startupOnboardingActionNext => 'Suivant';

  @override
  String get startupOnboardingActionStart => 'Commencer';

  @override
  String get startupOnboardingPageOneTitle =>
      'Créez des moments magiques avec votre animal de compagnie';

  @override
  String get startupOnboardingPageOneSubtitle =>
      'Transformez des clips de tous les jours en histoires ludiques prêtes pour le virus avec des modèles lumineux axés sur les animaux de compagnie.';

  @override
  String get startupOnboardingPageOneHighlightOne => 'Modèles tendance';

  @override
  String get startupOnboardingPageOneHighlightTwo => 'Modifications rapides';

  @override
  String get startupOnboardingPageOneHighlightThree =>
      'Ambiance sans danger pour les animaux';

  @override
  String get startupOnboardingPageTwoTitle =>
      'Parcourez d\'abord, déverrouillez lorsque vous êtes prêt';

  @override
  String get startupOnboardingPageTwoSubtitle =>
      'Explorez le flux en tant qu\'invité, puis connectez-vous lorsque vous souhaitez effectuer un rendu, un enregistrement ou une version premium.';

  @override
  String get startupOnboardingPageTwoHighlightOne => 'Navigation invité';

  @override
  String get startupOnboardingPageTwoHighlightTwo =>
      'Connectez-vous en un seul clic';

  @override
  String get startupOnboardingPageTwoHighlightThree => 'Transfert en douceur';

  @override
  String get startupOnboardingPageThreeTitle =>
      'Collectez des jetons et des avantages premium plus tard';

  @override
  String get startupOnboardingPageThreeSubtitle =>
      'Gardez la première impression amusante. Les jetons, les récompenses et les actions premium attendent derrière une étape d\'authentification propre.';

  @override
  String get startupOnboardingPageThreeHighlightOne => 'Déblocages Premium';

  @override
  String get startupOnboardingPageThreeHighlightTwo => 'Solde des jetons';

  @override
  String get startupOnboardingPageThreeHighlightThree =>
      'Avantages du créateur';

  @override
  String get startupMiniFeatureFastStart => 'Démarrage rapide';

  @override
  String get startupMiniFeaturePetFirst => 'Les animaux de compagnie d\'abord';

  @override
  String get startupMiniFeatureUpgradeLater => 'Mettre à niveau plus tard';

  @override
  String get startupWelcomeViewOnboarding => 'Voir l\'intégration';

  @override
  String get startupWelcomeTitle => 'Bienvenue à PetMagic';

  @override
  String get startupWelcomeSubtitle =>
      'Continuez à explorer en tant qu\'invité ou connectez-vous avant de créer des modèles, de débloquer des récompenses et d\'enregistrer vos créations.';

  @override
  String get startupWelcomeContinueGuest => 'Continuer en tant qu\'invité';

  @override
  String get startupWelcomeTemplatesTitle => 'Modèles viraux';

  @override
  String get startupWelcomeTemplatesSubtitle => 'Aperçu du flux complet';

  @override
  String get startupWelcomeAiTitle => 'Magie de l\'IA';

  @override
  String get startupWelcomeAiSubtitle => 'Déverrouiller lors de la connexion';

  @override
  String get startupWelcomeShareTitle => 'Partagez et profitez';

  @override
  String get startupWelcomeShareSubtitle => 'Enregistrez vos favoris plus tard';

  @override
  String get authEntryTitle => 'Content de te revoir!';

  @override
  String get authEntrySubtitle =>
      'Connectez-vous pour continuer la magie de votre animal de compagnie.';

  @override
  String get authRegisterTitle => 'Créez votre compte';

  @override
  String get authRegisterSubtitle =>
      'Rejoignez PetMagic et débloquez des modèles, des jetons et des fonctionnalités premium.';

  @override
  String get authRegisterAction => 'S\'inscrire';

  @override
  String get authDisplayNameLabel => 'Nom d\'affichage (facultatif)';

  @override
  String get authConfirmPasswordLabel => 'Confirmez le mot de passe';

  @override
  String get authPasswordRulesHint => 'Utilisez au moins 6 caractères.';

  @override
  String get authPasswordTooShort =>
      'Le mot de passe doit comporter au moins 6 caractères.';

  @override
  String get authForgotPasswordAction => 'Mot de passe oublié ?';

  @override
  String get authForgotPasswordComingSoon =>
      'La récupération du mot de passe sera bientôt disponible.';

  @override
  String get authPasswordResetTitle => 'Réinitialisez votre mot de passe';

  @override
  String get authPasswordResetSubtitle =>
      'Entrez votre email et nous vous enverrons un code de réinitialisation.';

  @override
  String get authPasswordResetCodeTitle => 'Entrez le code de votre email';

  @override
  String get authPasswordResetCodeSubtitle =>
      'Utilisez le code pour définir un nouveau mot de passe pour votre compte.';

  @override
  String get authPasswordResetCodeLabel => 'Réinitialiser le code';

  @override
  String get authPasswordResetRequestAction => 'Envoyer le code';

  @override
  String get authPasswordResetConfirmAction =>
      'Enregistrer le nouveau mot de passe';

  @override
  String get authPasswordResetResendAction => 'Envoyer à nouveau le code';

  @override
  String get authPasswordResetCodeSent =>
      'Nous avons envoyé un code de réinitialisation de mot de passe à votre adresse e-mail.';

  @override
  String get authPasswordResetSuccess =>
      'Mot de passe mis à jour. Vous pouvez maintenant vous connecter avec le nouveau mot de passe.';

  @override
  String get authPasswordResetCodeInvalid =>
      'Ce code de réinitialisation n\'est pas valide ou a expiré.';

  @override
  String get authOrContinueWith => 'ou continuez avec';

  @override
  String get authAcceptTermsLabel =>
      'J\'accepte les conditions d\'utilisation et la politique de confidentialité';

  @override
  String get authReceiveUpdatesLabel =>
      'Je souhaite recevoir des mises à jour et des offres de PetMagic';

  @override
  String get authAcceptTermsRequired =>
      'Vous devez accepter les conditions d\'utilisation et la politique de confidentialité pour créer un compte.';

  @override
  String get authReviewTermsAction => 'Voir les conditions';

  @override
  String get authReviewPrivacyAction => 'Voir la confidentialité';

  @override
  String get authLegalLoading =>
      'Chargement des documents actuels de conditions et de confidentialité...';

  @override
  String get authLegalReady =>
      'Les documents juridiques actuels sont prêts à être consultés et acceptés.';

  @override
  String get authLegalUnavailable =>
      'Les documents juridiques actuels sont temporairement indisponibles. Réessayez dans un instant.';

  @override
  String get authGoogleShortLabel => 'Google';

  @override
  String get authAppleShortLabel => 'Pomme';

  @override
  String get authContinueWithGoogle => 'Continuer avec Google';

  @override
  String get authContinueWithApple => 'Continuer avec Apple';

  @override
  String get authNoAccountPrompt => 'Vous n\'avez pas de compte ?';

  @override
  String get authHaveAccountPrompt => 'Vous avez déjà un compte ?';

  @override
  String get authSignUpAction => 'S\'inscrire';

  @override
  String get authSocialComingSoon =>
      'La connexion sociale sera bientôt disponible.';

  @override
  String get authPasswordMismatch => 'Les mots de passe ne correspondent pas.';

  @override
  String get authExternalCancelled => 'La connexion a été annulée.';

  @override
  String get authExternalFailed =>
      'La connexion externe a échoué. Veuillez réessayer.';

  @override
  String get authExternalTimedOut =>
      'La connexion a pris trop de temps. Veuillez réessayer.';

  @override
  String get authExternalLaunchFailed =>
      'Impossible d\'ouvrir la page de connexion.';

  @override
  String get authExternalCallbackFailed =>
      'Nous n\'avons pas pu terminer la connexion dans l\'application.';

  @override
  String get authExternalSessionExpired =>
      'Cette session de connexion a expiré. Veuillez réessayer.';

  @override
  String get authSignInRequired => 'La connexion est requise.';

  @override
  String get authSessionExpired => 'Session expirée.';

  @override
  String get authLoginFailed => 'Échec de la connexion. Veuillez réessayer.';

  @override
  String get authRegistrationFailed =>
      'Échec de l\'inscription. Veuillez réessayer.';

  @override
  String get authPasswordResetRequestFailed =>
      'Échec de la demande de réinitialisation du mot de passe. Veuillez réessayer.';

  @override
  String get authPasswordResetFailed =>
      'Échec de la réinitialisation du mot de passe. Veuillez réessayer.';

  @override
  String get authRequestFailed => 'La requête a échoué. Veuillez réessayer.';

  @override
  String get profileActionFailed =>
      'We could not complete this action. Please try again.';

  @override
  String get authSecurePrivateTitle => 'Sécurisé et privé';

  @override
  String get authSecurePrivateSubtitle => 'Vos données restent protégées.';

  @override
  String get authFastEasyTitle => 'Rapide et facile';

  @override
  String get authFastEasySubtitle => 'Commencez à créer en quelques clics.';

  @override
  String get authLovedByPetsTitle => 'Aimé par les animaux de compagnie';

  @override
  String get authLovedByPetsSubtitle =>
      'Conçu pour les heureux parents d\'animaux de compagnie.';

  @override
  String get authPrivacyTitle => 'Votre vie privée est importante';

  @override
  String get authPrivacySubtitle =>
      'Nous ne vendons ni ne partageons jamais vos données avec des tiers.';

  @override
  String get authRequiredTitle => 'Connectez-vous pour débloquer cette action';

  @override
  String get authRequiredMessage =>
      'Les invités peuvent explorer l\'application, mais les actions de modèles, les récompenses et les fonctionnalités de jetons nécessitent un compte PetMagic.';

  @override
  String get authRequiredContinueBrowsing => 'Continuer la navigation';

  @override
  String get templateTryAction => 'Essayez le modèle';

  @override
  String get templateGuestPreview => 'Aperçu invité';

  @override
  String get templateActionComingSoon => 'Le studio de modèles arrive bientôt.';

  @override
  String get tokensActionComingSoon =>
      'Le portefeuille de jetons arrive bientôt.';

  @override
  String get rewardsActionComingSoon =>
      'Le centre de récompenses arrive bientôt.';
}
