// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get navTemplates => 'Templates';

  @override
  String get navCreations => 'Gallery';

  @override
  String get navRewards => 'Rewards';

  @override
  String get navProfile => 'Profile';

  @override
  String get comingSoonMessage =>
      'This section is prepared for the next product wave.';

  @override
  String get createMagicTitle => 'Create Magic';

  @override
  String get pickTemplateSubtitle => 'Pick a template for your pet';

  @override
  String get searchTemplates => 'Search templates';

  @override
  String get allFilter => 'All';

  @override
  String get videosFilter => 'Videos';

  @override
  String get imagesFilter => 'Images';

  @override
  String get trendingFilter => '🔥 Trending';

  @override
  String get funnyFilter => '😂 Funny';

  @override
  String get danceFilter => '🕺 Dance';

  @override
  String get magicFilter => '✣ Magic';

  @override
  String get adventureFilter => '🌄 Adventure';

  @override
  String get filtersTooltip => 'Filters';

  @override
  String get giftTooltip => 'Rewards';

  @override
  String get addTokensTooltip => 'Add PawSpark';

  @override
  String get premiumLabel => 'Premium';

  @override
  String get freeLabel => 'Free';

  @override
  String get profileTitle => 'Your Profile';

  @override
  String get profileSubtitle => 'Manage sign-in and your public avatar.';

  @override
  String get profileDashboardSubtitle =>
      'Manage your account and personalize your PetMagic experience.';

  @override
  String get profileSignInTitle => 'Sign in to continue';

  @override
  String get profileSignInHint =>
      'Use your PetMagic account to load your profile and manage the avatar visible in admin.';

  @override
  String get profileEmailLabel => 'Email';

  @override
  String get profilePasswordLabel => 'Password';

  @override
  String get profileSignInAction => 'Sign in';

  @override
  String get profileSignOutAction => 'Sign out';

  @override
  String get profileLoadingAction => 'Working...';

  @override
  String get profileAvatarUpload => 'Upload avatar';

  @override
  String get profileAvatarRemove => 'Remove avatar';

  @override
  String get profileEmailConfirmed => 'Email confirmed';

  @override
  String get profileEmailPending => 'Email not confirmed';

  @override
  String get profileEmailVerifiedShort => 'Email verified';

  @override
  String get profileEmailPendingShort => 'Verify email';

  @override
  String get profileSignedOut => 'Signed out on this device.';

  @override
  String get profileAccountCenterTitle => 'Account center';

  @override
  String get profileAccountCenterSubtitle =>
      'Review your preferences, privacy and app setup.';

  @override
  String get profileTermsStat => 'Terms accepted';

  @override
  String get profileMarketingStat => 'Offers & updates';

  @override
  String get profileEmailStat => 'Email status';

  @override
  String get profileStatOn => 'On';

  @override
  String get profileStatOff => 'Off';

  @override
  String get profileStatReady => 'Ready';

  @override
  String get profileStatPending => 'Pending';

  @override
  String get profilePetsTitle => 'My pets';

  @override
  String get profilePetsSubtitle =>
      'Your favorite companions and pet profiles.';

  @override
  String get profilePremiumTitle => 'Go Premium';

  @override
  String get profilePremiumSubtitle =>
      'Unlock all templates and premium editing flows.';

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
      'Unlimited pet magic, faster generation and premium templates in one plan.';

  @override
  String get premiumHeroEyebrow => 'Premium magic';

  @override
  String get premiumHeroTitle => 'Unlock viral pet videos';

  @override
  String get premiumHeroSubtitle =>
      'More generations, premium templates, faster processing and no watermark.';

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
  String get premiumContinueAction => 'Continue';

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
  String get profileCommunicationsTitle => 'PetMagic updates';

  @override
  String get profileCommunicationsEnabled =>
      'You are subscribed to product updates and offers.';

  @override
  String get profileCommunicationsDisabled =>
      'Marketing updates are currently turned off.';

  @override
  String get profilePrivacyTitle => 'Privacy and consent';

  @override
  String get profileTermsAccepted =>
      'Your account has accepted the Terms of Use and Privacy Policy.';

  @override
  String get profileTermsPending =>
      'Complete consent review in account settings.';

  @override
  String get profileLegalShortcutTitle => 'Privacy & Legal';

  @override
  String get profileLegalShortcutAccepted =>
      'Terms accepted • Privacy settings';

  @override
  String get profileLegalShortcutPending => 'Review permissions';

  @override
  String get profileSupportTitle => 'Contact support';

  @override
  String get profileSupportSubtitle =>
      'We are here when you need help with your account.';

  @override
  String get profileSupportCompactSubtitle =>
      'Get help with billing or account access.';

  @override
  String get profileSettingsShortcutTitle => 'Settings';

  @override
  String get profileSettingsShortcutSubtitle =>
      'Manage language, theme and account sections.';

  @override
  String get profileSettingsCompactSubtitle =>
      'Language, theme and account settings.';

  @override
  String get profilePreferenceEnabled => 'Enabled';

  @override
  String get profilePreferenceOff => 'Off';

  @override
  String get profileSettingsTitle => 'Settings';

  @override
  String get profileSettingsSubtitle => 'Manage the app and your account.';

  @override
  String get profileSettingsAccountSection => 'Account';

  @override
  String get profileSettingsNotificationsSection => 'Notifications';

  @override
  String get profileSettingsPreferencesSection => 'Preferences';

  @override
  String get profileSettingsSupportSection => 'Support';

  @override
  String get profileSettingsAboutSection => 'About app';

  @override
  String get profileSettingsDangerSection => 'Danger zone';

  @override
  String get profileSettingsAccountInfoTitle => 'Account information';

  @override
  String get profileSettingsUnavailableSubtitle =>
      'This information becomes available after sign in.';

  @override
  String get profileSettingsLinkedAccountsTitle => 'Linked accounts';

  @override
  String get profileSettingsLinkedAccountsSubtitle =>
      'Add sign-in methods so you do not lose access to your account.';

  @override
  String get profileSettingsPasswordTitle => 'Change password';

  @override
  String get profileSettingsPasswordSubtitle =>
      'Update your password to keep the account secure.';

  @override
  String get profileSettingsNotificationsTitle => 'Notification settings';

  @override
  String get profileSettingsNotificationsSubtitle =>
      'Manage push and email preferences across the app.';

  @override
  String get profileSettingsLanguageTitle => 'App language';

  @override
  String get profileSettingsLanguageSubtitle =>
      'Choose the language used throughout the interface.';

  @override
  String get profileSettingsThemeTitle => 'App theme';

  @override
  String get profileSettingsThemeSubtitle =>
      'Switch between system, light and dark appearance.';

  @override
  String get profileSettingsHelpCenterTitle => 'Help center';

  @override
  String get profileSettingsHelpCenterSubtitle =>
      'Quick answers and guides for common questions.';

  @override
  String get profileSettingsSupportTitle => 'Contact support';

  @override
  String get profileSettingsSupportSubtitle =>
      'Reach out if you need help with billing or account access.';

  @override
  String get profileSettingsTermsTitle => 'Terms of Use';

  @override
  String get profileSettingsTermsSubtitle =>
      'Review the rules for using PetMagic.';

  @override
  String get profileSettingsPrivacyTitle => 'Privacy Policy';

  @override
  String get profileSettingsPrivacySubtitle =>
      'Learn how your data is handled and protected.';

  @override
  String get profileSettingsDeleteAccountTitle => 'Delete account';

  @override
  String get profileSettingsDeleteAccountSubtitle =>
      'This action cannot be undone.';

  @override
  String get profileAccountDetailsSubtitle =>
      'Review the account data currently available on this device.';

  @override
  String get profileAccountDetailsSection => 'Account details';

  @override
  String get profileAccountUserIdLabel => 'User ID';

  @override
  String get profileAccountDisplayNameLabel => 'Display name';

  @override
  String get profileAccountDisplayNameMissing => 'Not set yet';

  @override
  String get profileAccountRolesLabel => 'Roles';

  @override
  String get profileAccountRolesMissing => 'No roles assigned';

  @override
  String get profileAccountMembershipLabel => 'Membership';

  @override
  String get profileAccountConsentLabel => 'Terms acceptance';

  @override
  String get profileAccountMarketingLabel => 'Offers and updates';

  @override
  String get profileAccountAvatarLabel => 'Avatar';

  @override
  String get profileAccountAvatarMissing => 'No avatar uploaded';

  @override
  String get profileAccountAvatarUploaded => 'Avatar uploaded';

  @override
  String get profileDetailsCurrentStatusSection => 'Current status';

  @override
  String get profileDetailsNextStepSection => 'What happens next';

  @override
  String get profileDetailsLinkedAccountsBody =>
      'Connect Google or Apple to keep access to your generations, purchases, and PawSpark on any device.';

  @override
  String get profileDetailsLinkedAccountsStatus =>
      'Choose and connect convenient sign-in methods for your account.';

  @override
  String get profileDetailsLinkedAccountsNext =>
      'Linked accounts help you:\n✓ recover access\n✓ sign in on a new device\n✓ keep purchases and PawSpark\n✓ protect your account';

  @override
  String get profileLinkedAccountsLoading =>
      'Loading linked sign-in providers...';

  @override
  String get profileLinkedAccountsConnectedStatus =>
      'Connected and ready to sign in.';

  @override
  String get profileLinkedAccountsNotConnectedStatus => 'Not connected.';

  @override
  String get profileLinkedAccountsConnectAction => 'Connect';

  @override
  String get profileLinkedAccountsDisconnectAction => 'Disconnect';

  @override
  String get profileLinkedAccountsProtectedHint =>
      'This sign-in method cannot be removed until another method is connected.';

  @override
  String get profileLinkedAccountsSignInRequired =>
      'Sign in again to manage linked accounts.';

  @override
  String get profileLinkedAccountsUnavailable =>
      'Linked accounts are temporarily unavailable.';

  @override
  String get profileDetailsNotificationsBody =>
      'Choose which notifications you want to receive in PetMagic.';

  @override
  String get profileDetailsNotificationsStatusEnabled =>
      'Notifications are enabled for this profile.';

  @override
  String get profileDetailsNotificationsStatusDisabled =>
      'Notifications are disabled for this profile.';

  @override
  String get profileDetailsNotificationsNext =>
      'You can change push and email preferences at any time.';

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
      'The help center will collect quick answers, setup tips and account guidance in one place.';

  @override
  String get profileDetailsHelpStatus =>
      'The in-app knowledge base is still being assembled, so this screen shows the current rollout status.';

  @override
  String get profileDetailsHelpNext =>
      'The first help articles and troubleshooting guides will appear here as the mobile support content is published.';

  @override
  String get profileDetailsSupportBody =>
      'Support requests will be handled here without forcing you out of the profile area.';

  @override
  String get profileDetailsSupportStatus =>
      'Direct in-app contact is not wired yet. For now, keep this screen as the support entry point for the next slice.';

  @override
  String get profileDetailsSupportNext =>
      'The next step is a real support form or email handoff connected to the backend support flow.';

  @override
  String get profileDetailsTermsBody =>
      'Review how PetMagic expects the app and account to be used.';

  @override
  String get profileDetailsTermsStatusAccepted =>
      'This account has already accepted the Terms of Use during registration.';

  @override
  String get profileDetailsTermsStatusPending =>
      'This account has not recorded a completed terms acceptance yet.';

  @override
  String get profileDetailsTermsNext =>
      'A fuller legal document view can be attached here later. For now, this screen confirms the current acceptance state.';

  @override
  String get profileDetailsPrivacyBody =>
      'Review how PetMagic stores, protects and uses account data.';

  @override
  String get profileDetailsPrivacyStatus =>
      'Privacy details are currently represented as an in-app summary screen while the full legal document flow is prepared.';

  @override
  String get profileDetailsPrivacyNext =>
      'The next slice can attach a complete policy document or hosted legal page to this route.';

  @override
  String get profileLegalAcceptanceCurrent =>
      'Current legal documents are accepted for this account.';

  @override
  String get profileLegalAcceptanceRequired =>
      'This account needs to accept the current legal document versions.';

  @override
  String get profileLegalVersionLabel => 'Current version';

  @override
  String get profileLegalPublishedLabel => 'Published';

  @override
  String get profileLegalAcceptedVersionLabel => 'Accepted version';

  @override
  String get profileLegalAcceptedAtLabel => 'Accepted at';

  @override
  String get profileLegalLoading =>
      'Loading the current legal document from the backend...';

  @override
  String get profileLegalUnavailable =>
      'The current legal document could not be loaded right now.';

  @override
  String get profileLegalAcceptAction => 'Accept current legal documents';

  @override
  String get profileLegalAcceptanceGuestHint =>
      'You will accept the current Terms of Use and Privacy Policy during sign up.';

  @override
  String get profileLegalDocumentSection => 'Document';

  @override
  String get profileLegalDocumentInfoSection => 'Document info';

  @override
  String get profileLegalOpenFullAction => 'Open full policy';

  @override
  String get profileLegalCompactHint =>
      'The summary stays visible, and each section expands only when you need more detail.';

  @override
  String get profileLegalCurrentAcceptedHint =>
      'No additional confirmation is required for this account right now.';

  @override
  String get profileLegalCompactSectionLabel => 'Tap to expand';

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
      'Account deletion is intentionally protected and not executed from this screen yet.';

  @override
  String get profileDetailsDeleteStatus =>
      'Deletion is not available as a one-tap action in the mobile app right now. This avoids destructive behavior before the backend confirmation flow is ready.';

  @override
  String get profileDetailsDeleteNext =>
      'When the backend deletion workflow is implemented, this screen can become the confirmation and verification step instead of a placeholder.';

  @override
  String get supportChatTitle => 'Support chat';

  @override
  String get supportChatSubtitle =>
      'Message the PetMagic team directly from your profile.';

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
  String get supportChatInputHint => 'Describe the issue...';

  @override
  String get supportChatSendAction => 'Send';

  @override
  String get supportChatEmptyTitle => 'Start the conversation';

  @override
  String get supportChatEmptyMessage =>
      'Your support chat is ready. Send the first message and the team will respond here.';

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
  String get supportChatQuickActionSubscription => 'Subscription issue';

  @override
  String get supportChatQuickActionVideo => 'Video generation issue';

  @override
  String get supportChatQuickActionTokens => 'Tokens were not credited';

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
  String get supportChatStatusOpen => 'Open';

  @override
  String get supportChatStatusInProgress => 'In progress';

  @override
  String get supportChatStatusResolved => 'Resolved';

  @override
  String get supportChatStatusClosed => 'Closed';

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
  String get supportChatMessageDelivered => 'Delivered';

  @override
  String get supportChatMessageRead => 'Read';

  @override
  String get supportChatUnavailableError =>
      'Unable to reach support right now. Please try again in a moment.';

  @override
  String get supportChatAttachmentUnavailableError =>
      'Unable to send the attachment right now. Please try again in a moment.';

  @override
  String get supportChatAttachmentTooLargeError => 'File is too large';

  @override
  String get supportChatImageLabel => 'Support image';

  @override
  String get supportChatSaveImageAction => 'Save image';

  @override
  String get supportChatShareAction => 'Share';

  @override
  String get supportChatOpenOriginalAction => 'Open original';

  @override
  String get supportChatCloseAction => 'Close';

  @override
  String get supportChatImageSavedMessage => 'Image saved';

  @override
  String get supportChatSaveImageFailedError => 'Failed to save image';

  @override
  String get supportChatShareImageFailedError => 'Failed to share image';

  @override
  String get supportChatAttachmentStatusUploading => 'Uploading';

  @override
  String get supportChatAttachmentStatusUploaded => 'Uploaded';

  @override
  String get supportChatAttachmentStatusFailed => 'Failed';

  @override
  String get supportChatAttachmentStatusRetry => 'Retry';

  @override
  String supportChatAttachmentUploadingWithCount(Object current, Object total) {
    return 'Uploading photo $current of $total';
  }

  @override
  String get supportChatImageUploadFailedLabel => 'Image upload failed';

  @override
  String get supportChatFileFallbackLabel => 'File';

  @override
  String get supportChatSystemNoticeTitle => 'Request sent';

  @override
  String get supportChatSystemNoticeBody =>
      'Thanks, we received your message. Support will reply in this chat.';

  @override
  String get supportChatComposerAttachmentChip =>
      'Up to 5 photos: JPG/PNG/WebP, 10 MB each';

  @override
  String get supportChatComposerResponseChip => 'Typical reply in a few hours';

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
  String get supportChatCloseRequestDialogTitle => 'Close request?';

  @override
  String get supportChatCloseRequestDialogBody =>
      'If the problem is resolved, we will close this conversation. You can create a new request later.';

  @override
  String get supportChatCloseConfirmAction => 'Close';

  @override
  String get supportChatCancelAction => 'Cancel';

  @override
  String get supportChatConversationClosedLabel => 'Request closed';

  @override
  String get supportChatReopenAction => 'Write again';

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
  String get supportHomeOpenChatAction => 'Open chat';

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
  String get profileSettingsThemeLight => 'Light';

  @override
  String get profileSettingsThemeDark => 'Dark';

  @override
  String get profileSettingsLanguageRussian => 'Russian';

  @override
  String get profileSettingsLanguageEnglish => 'English';

  @override
  String get profileSettingsLanguageGerman => 'German';

  @override
  String get profileSettingsLanguageSpanish => 'Spanish';

  @override
  String get profileSettingsLanguageFrench => 'French';

  @override
  String get profileSettingsLanguageItalian => 'Italian';

  @override
  String get profileSettingsLanguagePolish => 'Polish';

  @override
  String profileSettingsVersionLabel(Object version) {
    return 'App version $version';
  }

  @override
  String get magicLoadingPreparing => 'Preparing the magic...';

  @override
  String get magicLoadingCutestAngle => 'Finding the cutest angle...';

  @override
  String get magicLoadingAiPaws => 'Warming up AI paws...';

  @override
  String get magicLoadingCreatingAdorable => 'Creating something adorable...';

  @override
  String get magicLoadingAlmostReady => 'Almost ready...';

  @override
  String get videoLabel => 'Video';

  @override
  String get imageLabel => 'Image';

  @override
  String get templatesErrorTitle => 'Templates did not load';

  @override
  String get retryAction => 'Retry';

  @override
  String get emptyTemplatesTitle => 'No templates yet';

  @override
  String get emptyTemplatesMessage =>
      'Try another filter or refresh the catalog.';

  @override
  String get templatesFeedEmptyError =>
      'Templates are temporarily unavailable.';

  @override
  String get templatesConnectionTimeoutError =>
      'No connection. Check your network and try again.';

  @override
  String get templatesServerTimeoutError =>
      'The server took too long to respond. Please try again.';

  @override
  String get templatesRequestFailedError =>
      'Could not load templates right now. Please try again.';

  @override
  String get startupOnboardingActionContinueGuest => 'Continue as guest';

  @override
  String get startupOnboardingActionNext => 'Next';

  @override
  String get startupOnboardingActionStart => 'Get started';

  @override
  String get startupOnboardingPageOneTitle =>
      'Create magic moments with your pet';

  @override
  String get startupOnboardingPageOneSubtitle =>
      'Turn everyday clips into playful viral-ready stories with bright, pet-first templates.';

  @override
  String get startupOnboardingPageOneHighlightOne => 'Trendy templates';

  @override
  String get startupOnboardingPageOneHighlightTwo => 'Fast edits';

  @override
  String get startupOnboardingPageOneHighlightThree => 'Pet-safe vibe';

  @override
  String get startupOnboardingPageTwoTitle =>
      'Browse first, unlock when you are ready';

  @override
  String get startupOnboardingPageTwoSubtitle =>
      'Explore the feed as a guest, then sign in when you want to render, save or go premium.';

  @override
  String get startupOnboardingPageTwoHighlightOne => 'Guest browsing';

  @override
  String get startupOnboardingPageTwoHighlightTwo => 'One-tap sign in';

  @override
  String get startupOnboardingPageTwoHighlightThree => 'Smooth handoff';

  @override
  String get startupOnboardingPageThreeTitle =>
      'Collect tokens and premium perks later';

  @override
  String get startupOnboardingPageThreeSubtitle =>
      'Keep the first impression fun. Tokens, rewards and premium actions wait behind a clean auth step.';

  @override
  String get startupOnboardingPageThreeHighlightOne => 'Premium unlocks';

  @override
  String get startupOnboardingPageThreeHighlightTwo => 'Token balance';

  @override
  String get startupOnboardingPageThreeHighlightThree => 'Creator perks';

  @override
  String get startupMiniFeatureFastStart => 'Fast start';

  @override
  String get startupMiniFeaturePetFirst => 'Pet-first';

  @override
  String get startupMiniFeatureUpgradeLater => 'Upgrade later';

  @override
  String get startupWelcomeViewOnboarding => 'View onboarding';

  @override
  String get startupWelcomeTitle => 'Welcome back to PetMagic';

  @override
  String get startupWelcomeSubtitle =>
      'Keep exploring as a guest or sign in before you render templates, unlock rewards and save your creations.';

  @override
  String get startupWelcomeContinueGuest => 'Continue as guest';

  @override
  String get startupWelcomeTemplatesTitle => 'Viral Templates';

  @override
  String get startupWelcomeTemplatesSubtitle => 'Preview the full feed';

  @override
  String get startupWelcomeAiTitle => 'AI Magic';

  @override
  String get startupWelcomeAiSubtitle => 'Unlock on sign in';

  @override
  String get startupWelcomeShareTitle => 'Share & Enjoy';

  @override
  String get startupWelcomeShareSubtitle => 'Save your favorites later';

  @override
  String get authEntryTitle => 'Welcome back!';

  @override
  String get authEntrySubtitle => 'Sign in to continue your pet magic.';

  @override
  String get authRegisterTitle => 'Create your account';

  @override
  String get authRegisterSubtitle =>
      'Join PetMagic and unlock templates, tokens and premium features.';

  @override
  String get authRegisterAction => 'Sign Up';

  @override
  String get authDisplayNameLabel => 'Display name (optional)';

  @override
  String get authConfirmPasswordLabel => 'Confirm password';

  @override
  String get authPasswordRulesHint => 'Use at least 6 characters.';

  @override
  String get authPasswordTooShort =>
      'Password must be at least 6 characters long.';

  @override
  String get authForgotPasswordAction => 'Forgot password?';

  @override
  String get authForgotPasswordComingSoon =>
      'Password recovery is coming soon.';

  @override
  String get authPasswordResetTitle => 'Reset your password';

  @override
  String get authPasswordResetSubtitle =>
      'Enter your email and we will send you a reset code.';

  @override
  String get authPasswordResetCodeTitle => 'Enter the code from your email';

  @override
  String get authPasswordResetCodeSubtitle =>
      'Use the code to set a new password for your account.';

  @override
  String get authPasswordResetCodeLabel => 'Reset code';

  @override
  String get authPasswordResetRequestAction => 'Send code';

  @override
  String get authPasswordResetConfirmAction => 'Save new password';

  @override
  String get authPasswordResetResendAction => 'Send code again';

  @override
  String get authPasswordResetCodeSent =>
      'We sent a password reset code to your email.';

  @override
  String get authPasswordResetSuccess =>
      'Password updated. You can now sign in with the new password.';

  @override
  String get authPasswordResetCodeInvalid =>
      'This reset code is invalid or has expired.';

  @override
  String get authOrContinueWith => 'or continue with';

  @override
  String get authAcceptTermsLabel =>
      'I agree to the Terms of Use and Privacy Policy';

  @override
  String get authReceiveUpdatesLabel =>
      'I want to receive updates and offers from PetMagic';

  @override
  String get authAcceptTermsRequired =>
      'You need to accept the Terms of Use and Privacy Policy to create an account.';

  @override
  String get authReviewTermsAction => 'Review Terms';

  @override
  String get authReviewPrivacyAction => 'Review Privacy';

  @override
  String get authLegalLoading =>
      'Loading the current Terms and Privacy documents...';

  @override
  String get authLegalReady =>
      'Current legal documents are ready to review and accept.';

  @override
  String get authLegalUnavailable =>
      'Current legal documents are temporarily unavailable. Try again in a moment.';

  @override
  String get authGoogleShortLabel => 'Google';

  @override
  String get authAppleShortLabel => 'Apple';

  @override
  String get authContinueWithGoogle => 'Continue with Google';

  @override
  String get authContinueWithApple => 'Continue with Apple';

  @override
  String get authNoAccountPrompt => 'Don\'t have an account?';

  @override
  String get authHaveAccountPrompt => 'Already have an account?';

  @override
  String get authSignUpAction => 'Sign Up';

  @override
  String get authSocialComingSoon => 'Social sign-in is coming soon.';

  @override
  String get authPasswordMismatch => 'Passwords do not match.';

  @override
  String get authExternalCancelled => 'Sign-in was cancelled.';

  @override
  String get authExternalFailed => 'External sign-in failed. Please try again.';

  @override
  String get authExternalTimedOut => 'Sign-in took too long. Please try again.';

  @override
  String get authExternalLaunchFailed => 'Could not open the sign-in page.';

  @override
  String get authExternalCallbackFailed =>
      'We could not finish sign-in in the app.';

  @override
  String get authExternalSessionExpired =>
      'This sign-in session expired. Please try again.';

  @override
  String get authSignInRequired => 'Sign in is required.';

  @override
  String get authSessionExpired => 'Session expired.';

  @override
  String get authLoginFailed => 'Login failed. Please try again.';

  @override
  String get authRegistrationFailed => 'Registration failed. Please try again.';

  @override
  String get authPasswordResetRequestFailed =>
      'Password reset request failed. Please try again.';

  @override
  String get authPasswordResetFailed =>
      'Password reset failed. Please try again.';

  @override
  String get authRequestFailed => 'Request failed. Please try again.';

  @override
  String get profileActionFailed =>
      'We could not complete this action. Please try again.';

  @override
  String get authSecurePrivateTitle => 'Secure & Private';

  @override
  String get authSecurePrivateSubtitle => 'Your data stays protected.';

  @override
  String get authFastEasyTitle => 'Fast & Easy';

  @override
  String get authFastEasySubtitle => 'Start creating in just a few taps.';

  @override
  String get authLovedByPetsTitle => 'Loved by Pets';

  @override
  String get authLovedByPetsSubtitle => 'Built for happy pet parents.';

  @override
  String get authPrivacyTitle => 'Your privacy matters';

  @override
  String get authPrivacySubtitle =>
      'We never sell or share your data with third parties.';

  @override
  String get authRequiredTitle => 'Sign in to unlock this action';

  @override
  String get authRequiredMessage =>
      'Guests can explore the app, but template actions, rewards and token features require a PetMagic account.';

  @override
  String get authRequiredContinueBrowsing => 'Continue browsing';

  @override
  String get templateTryAction => 'Try template';

  @override
  String get templateGuestPreview => 'Guest preview';

  @override
  String get templateActionComingSoon => 'Template studio is coming soon.';

  @override
  String get tokensActionComingSoon => 'Token wallet is coming soon.';

  @override
  String get rewardsActionComingSoon => 'Rewards center is coming soon.';

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
  String get templateFlowTemplateLabel => 'Template';

  @override
  String get templateFlowCostLabel => 'Cost';

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
  String get templateFlowStepProcessPhoto => 'Processing photo';

  @override
  String get templateFlowStepAnalyzePet => 'Analyzing pet';

  @override
  String get templateFlowStepCreateMagic => 'Creating magic';

  @override
  String get templateFlowStepFinalTouches => 'Final touches';

  @override
  String get templateFlowTopUpBalanceAction => 'Top up balance';

  @override
  String get templateFlowResultReadyTitle => 'Done!';

  @override
  String get templateFlowResultReadySubtitle => 'Your magic is ready';

  @override
  String get templateFlowResultUnavailable => 'Result is not available yet';

  @override
  String get templateFlowLoadingResult => 'Loading result...';

  @override
  String get templateFlowResultLoadFailed => 'Could not load result';

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
  String get generationStatusTitle => 'Generation status';

  @override
  String get generationStatusCreatedLabel => 'Created';

  @override
  String get generationStatusStartedLabel => 'Started';

  @override
  String get generationStatusTypeLabel => 'Type';

  @override
  String get generationStatusAttemptLabel => 'Attempt';

  @override
  String get generationStatusUntitledFallback => 'Untitled';

  @override
  String get generationStatusDetailsTitle => 'Details';

  @override
  String get generationStatusFeedbackTitle => 'How is the result?';

  @override
  String get generationStatusFeedbackExcellent => 'Excellent';

  @override
  String get generationStatusFeedbackOkay => 'Okay';

  @override
  String get generationStatusFeedbackBad => 'Not great';

  @override
  String get generationStatusSaveAction => 'Save';

  @override
  String get generationStatusDeleteAction => 'Delete';

  @override
  String get generationStatusReportProblemAction => 'Report a problem';

  @override
  String get generationStatusPickAnotherPhotoAction => 'Choose another photo';

  @override
  String get generationStatusRetryAction => 'Try again';

  @override
  String get generationStatusContactSupportAction => 'Contact support';

  @override
  String get generationStatusOpenGalleryAction => 'Open gallery';

  @override
  String get generationStatusOpenStatusAction => 'Open status';

  @override
  String get generationStatusCancelGenerationAction => 'Cancel generation';

  @override
  String get generationStatusResultUnavailableForSave =>
      'Result is not available for saving yet.';

  @override
  String get generationStatusResultUnavailableForShare =>
      'Result is not available for sharing yet.';

  @override
  String get generationStatusSaveFileDialogTitle => 'Save file';

  @override
  String get generationStatusFileSavedMessage => 'File saved to device.';

  @override
  String get generationStatusFileSaveFailedMessage =>
      'Could not save file. Please try again.';

  @override
  String get generationStatusSavedToGalleryMessage => 'Saved to Gallery';

  @override
  String get generationStatusLinkCopiedMessage => 'Link copied';

  @override
  String get generationStatusDeletedMessage => 'Deleted';

  @override
  String get generationStatusFullscreenControlsHint =>
      'Tap to hide/show controls';

  @override
  String get generationStatusDeleteSoonMessage =>
      'Deletion will be available soon.';

  @override
  String get generationStatusCancelSoonMessage =>
      'Generation cancellation is coming soon.';

  @override
  String get generationStatusRetrySoonMessage =>
      'Choose another photo and start generation again.';

  @override
  String get generationStatusFeedbackThanksMessage =>
      'Thanks! Your feedback helps improve PetMagic.';

  @override
  String get generationStatusResultTitle => 'PetMagic result';

  @override
  String get generationStatusNonTerminalHint =>
      'This usually takes a few minutes. You can keep using the app.';

  @override
  String get generationStatusStageQueued => 'In queue';

  @override
  String get generationStatusStageDone => 'Done';

  @override
  String get generationStatusVideoReady => 'Video is ready';

  @override
  String get generationStatusShareVideoAction => 'Share video';

  @override
  String get generationStatusFailedTitle => 'Could not create result';

  @override
  String get generationStatusTokensRefundedHint =>
      'Tokens were returned to your balance.';

  @override
  String get generationStatusTokensRefundedShort => 'Tokens refunded';

  @override
  String get generationStatusSupportHint => 'If this repeats, contact support.';

  @override
  String get generationStatusBackgroundHint =>
      'Generation continues on the server. We will show the result in Gallery when it is ready.';

  @override
  String get generationStatusDownloadAction => 'Download';

  @override
  String get generationStatusContinueInAppAction => 'Continue in app';

  @override
  String get generationStatusFeedbackImproveTitle => 'What can we improve?';

  @override
  String get generationStatusFeedbackCommentLabel => 'Comment';

  @override
  String get generationStatusFeedbackCommentHint =>
      'Briefly tell us what was wrong';

  @override
  String get generationStatusFeedbackSubmitAction => 'Submit feedback';

  @override
  String get generationStatusFeedbackReasonPetNotSimilar =>
      'Pet does not look like itself';

  @override
  String get generationStatusFeedbackReasonFaceDistorted =>
      'Face or muzzle is distorted';

  @override
  String get generationStatusFeedbackReasonStrangeMotion =>
      'Motion looks strange';

  @override
  String get generationStatusFeedbackReasonPreviewMismatch =>
      'Result differs from preview';

  @override
  String get generationStatusFeedbackReasonLowQuality => 'Quality is too low';

  @override
  String get generationStatusFeedbackReasonStyleDisliked =>
      'Did not like the style';

  @override
  String get generationStatusFeedbackReasonOther => 'Other';

  @override
  String generationStatusEtaEstimated(Object value) {
    return 'About $value left';
  }

  @override
  String get generationStatusEtaQueued => 'Waiting in queue';

  @override
  String get generationStatusEtaFinalizing => 'Almost ready';

  @override
  String get generationStatusEtaDefault => 'About 1-2 min left';

  @override
  String get generationStatusEtaStartsSoon => 'Will start in a few minutes';

  @override
  String get generationStatusEtaNotifyHint =>
      'We will notify you when the result is ready.';

  @override
  String get generationStatusFailurePhotoHint =>
      'The photo is not suitable for this template. Try a photo where the pet is clearly visible.';

  @override
  String get generationStatusFailureTechnicalHint =>
      'Could not create the result due to a technical issue. Tokens were returned to your balance.';

  @override
  String get generationStatusStatusCompleted => 'Your result is ready';

  @override
  String get generationStatusStatusFailed => 'Could not create result';

  @override
  String get generationStatusStatusCreatingMagic => 'Creating magic...';

  @override
  String get generationStatusTerminalRefundedHint =>
      'Tokens were refunded automatically.';

  @override
  String get generationStatusTerminalFailureHint =>
      'A technical issue has been recorded.';

  @override
  String get generationStatusTerminalSuccessHint =>
      'Open result, share it, or leave feedback.';

  @override
  String get generationStatusSectionActive => 'In progress';

  @override
  String get generationStatusSectionReady => 'Ready';

  @override
  String get generationStatusSectionFailed => 'Failed';

  @override
  String get generationStatusFilterActive => 'In progress';

  @override
  String get generationStatusFilterReady => 'Ready';

  @override
  String get generationStatusFilterFailed => 'Failed';

  @override
  String generationStatusShowMoreAction(int hiddenCount) {
    return 'Show more ($hiddenCount) ▾';
  }

  @override
  String get generationStatusCollapseAction => 'Collapse ▲';

  @override
  String get generationStatusActiveInfoHint =>
      'You can close the app. We will notify you when the result is ready.';

  @override
  String generationStatusUnreadCount(int count) {
    return '$count new';
  }

  @override
  String get generationStatusEmptyTitle => 'Your results will appear here';

  @override
  String get generationStatusEmptyMessage =>
      'Choose a template, upload your pet photo and create your first magic art.';

  @override
  String get generationStatusSubtitleAll => 'Your magical creations';

  @override
  String get generationStatusSubtitleActive => 'Active generations';

  @override
  String get generationStatusSubtitleReady => 'Your ready results';

  @override
  String get generationStatusSubtitleFailed => 'Generation issues';

  @override
  String get generationStatusOfflineBannerTitle => 'You are offline';

  @override
  String get generationStatusOfflineBannerMessage =>
      'Showing previously saved creations from this device.';

  @override
  String generationStatusOfflineBannerSyncedAt(Object value) {
    return 'Last sync: $value';
  }

  @override
  String get generationStatusOnlineBannerTitle => 'Connection restored';

  @override
  String get generationStatusOnlineBannerMessage =>
      'Fresh data has been loaded.';

  @override
  String generationStatusOnlineBannerSyncedAt(Object value) {
    return 'Updated: $value';
  }

  @override
  String generationStatusDateToday(Object time) {
    return 'Today, $time';
  }

  @override
  String generationStatusDateYesterday(Object time) {
    return 'Yesterday, $time';
  }

  @override
  String shellActiveGenerationLabel(Object templateTitle) {
    return '✨ Creating $templateTitle';
  }

  @override
  String get shellActiveGenerationFallback => 'result';
}
