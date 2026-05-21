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
  String get navCreations => 'Creations';

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
  String get profileWalletTitle => 'Wallet';

  @override
  String get profileWalletHistoryHint => 'Open balance, purchases and history.';

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
  String get walletBalanceTitle => 'Available for generation';

  @override
  String get walletBalanceEyebrow => 'Balance';

  @override
  String get walletBalanceUnit => 'PawSpark';

  @override
  String get walletBalanceExplanation =>
      'PawSpark is the in-app currency used for photo and video generations.';

  @override
  String get walletPremiumStatus => 'Premium wallet';

  @override
  String get walletFreeStatus => 'Free wallet';

  @override
  String walletSavedCardsCount(Object count) {
    return '$count saved cards';
  }

  @override
  String get walletWeeklyReady => 'Weekly ready';

  @override
  String get walletWeeklyPending => 'Weekly pending';

  @override
  String walletAdRewardsCount(Object count) {
    return '$count ad rewards';
  }

  @override
  String get walletQuickActionsTitle => 'Wallet tools';

  @override
  String get walletPaymentMethodsAction => 'Payment methods';

  @override
  String get walletRedeemAction => 'Redeem code';

  @override
  String get walletRewardsTitle => 'Rewards and bonuses';

  @override
  String get walletWeeklyRewardAction => 'Weekly reward';

  @override
  String get walletRewardReadyDescription =>
      'You can claim it now and top up your balance right away.';

  @override
  String get walletRewardPendingDescription =>
      'It will unlock later. We keep the status visible without showing a scary error.';

  @override
  String get walletAdRewardAction => 'Ad reward';

  @override
  String walletAdRewardDescription(Object count) {
    return 'Available today: $count. Use it when you need a quick PawSpark top-up.';
  }

  @override
  String get walletBuySparkTitle => 'Buy PawSpark';

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
  String walletBuyForPrice(Object price) {
    return 'Buy for $price';
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
  String get walletUnavailableTitle => 'Wallet is temporarily unavailable';

  @override
  String get walletTryAgainAction => 'Try again';

  @override
  String get walletPaymentMethodsTitle => 'Payment methods';

  @override
  String get walletNoSavedCards => 'No saved cards yet.';

  @override
  String get walletOpeningStripe => 'Opening Stripe';

  @override
  String get walletAddCard => 'Add card';

  @override
  String get walletRemoveCardTooltip => 'Remove card';

  @override
  String get walletStripeCheckout => 'Stripe Checkout';

  @override
  String walletPayWithCard(Object last4) {
    return 'Pay with •••• $last4';
  }

  @override
  String get walletDefaultCard => 'Default card';

  @override
  String get walletSavedCard => 'Saved card';

  @override
  String get walletDefaultSuffix => ' • default';

  @override
  String walletExpires(Object month, Object year, Object suffix) {
    return 'Expires $month/$year$suffix';
  }

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
  String get walletPaymentMethodUnavailableError =>
      'The selected saved card is no longer available. Choose another card or use Stripe Checkout.';

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
  String get walletInsufficientBalanceError =>
      'Not enough PawSpark for this operation.';

  @override
  String get walletUnavailableError =>
      'Wallet data is temporarily unavailable. Please try again in a moment.';

  @override
  String get walletWeeklyNotReadyError => 'Weekly reward is not ready yet.';

  @override
  String get walletRedeemSheetTitle => 'Redeem code';

  @override
  String get walletRedeemHint => 'WELCOME-100';

  @override
  String get walletApplyCode => 'Apply code';

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
  String get premiumSecurePaymentTitle => 'Secure payment';

  @override
  String get premiumSecurePaymentSubtitle =>
      'Manage or cancel your subscription from billing settings at any time.';

  @override
  String get premiumContinueAction => 'Start Premium';

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
      'Google, Apple and other providers will appear here.';

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
      'Connected providers will appear here as soon as linking is enabled for your account.';

  @override
  String get profileDetailsLinkedAccountsStatus =>
      'No external providers are linked yet. Email and password remain the active sign-in method for this profile.';

  @override
  String get profileDetailsLinkedAccountsNext =>
      'Google, Apple and additional providers will be shown here after the backend linking flow is opened in the app.';

  @override
  String get profileLinkedAccountsLoading =>
      'Loading linked sign-in providers...';

  @override
  String get profileLinkedAccountsConnectedStatus =>
      'Connected and ready for sign in.';

  @override
  String get profileLinkedAccountsNotConnectedStatus => 'Not connected yet.';

  @override
  String get profileLinkedAccountsConnectAction => 'Connect';

  @override
  String get profileLinkedAccountsDisconnectAction => 'Disconnect';

  @override
  String get profileLinkedAccountsProtectedHint =>
      'This provider cannot be removed until another sign-in method remains available.';

  @override
  String get profileDetailsNotificationsBody =>
      'This section reflects your current communication preferences in the app.';

  @override
  String get profileDetailsNotificationsStatusEnabled =>
      'Product updates and offers are enabled for this profile. Additional push controls will appear here later.';

  @override
  String get profileDetailsNotificationsStatusDisabled =>
      'Marketing emails are currently disabled for this profile. Additional push controls will appear here later.';

  @override
  String get profileDetailsNotificationsNext =>
      'You can already review the current email preference here. Dedicated push toggles will be added in a later product slice.';

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
  String get profileLegalCompactHint =>
      'The summary stays visible, and each section expands only when you need more detail.';

  @override
  String get profileLegalCurrentAcceptedHint =>
      'No additional confirmation is required for this account right now.';

  @override
  String get profileLegalCompactSectionLabel => 'Tap to expand';

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
      'Describe the issue, question or request...';

  @override
  String get supportChatSendAction => 'Send';

  @override
  String get supportChatEmptyTitle => 'Start the conversation';

  @override
  String get supportChatEmptyMessage =>
      'Your support chat is ready. Send the first message and the team will respond here.';

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
  String get supportChatStatusOpen => 'Open';

  @override
  String get supportChatStatusInProgress => 'In progress';

  @override
  String get supportChatStatusResolved => 'Resolved';

  @override
  String get supportChatStatusClosed => 'Closed';

  @override
  String get supportChatMessageDelivered => 'Delivered';

  @override
  String get supportChatMessageRead => 'Read';

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
  String get profileSettingsLanguageEnglishUs => 'English (US)';

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
}

/// The translations for English, as used in the United States (`en_US`).
class AppLocalizationsEnUs extends AppLocalizationsEn {
  AppLocalizationsEnUs() : super('en_US');

  @override
  String get navTemplates => 'Templates';

  @override
  String get navCreations => 'Creations';

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
  String get premiumSecurePaymentTitle => 'Secure payment';

  @override
  String get premiumSecurePaymentSubtitle =>
      'Manage or cancel your subscription from billing settings at any time.';

  @override
  String get premiumContinueAction => 'Start Premium';

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
  String get profileSupportTitle => 'Contact support';

  @override
  String get profileSupportSubtitle =>
      'We are here when you need help with your account.';

  @override
  String get profileSettingsShortcutTitle => 'Settings';

  @override
  String get profileSettingsShortcutSubtitle =>
      'Manage language, theme and account sections.';

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
      'Google, Apple and other providers will appear here.';

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
      'Connected providers will appear here as soon as linking is enabled for your account.';

  @override
  String get profileDetailsLinkedAccountsStatus =>
      'No external providers are linked yet. Email and password remain the active sign-in method for this profile.';

  @override
  String get profileDetailsLinkedAccountsNext =>
      'Google, Apple and additional providers will be shown here after the backend linking flow is opened in the app.';

  @override
  String get profileLinkedAccountsLoading =>
      'Loading linked sign-in providers...';

  @override
  String get profileLinkedAccountsConnectedStatus =>
      'Connected and ready for sign in.';

  @override
  String get profileLinkedAccountsNotConnectedStatus => 'Not connected yet.';

  @override
  String get profileLinkedAccountsConnectAction => 'Connect';

  @override
  String get profileLinkedAccountsDisconnectAction => 'Disconnect';

  @override
  String get profileLinkedAccountsProtectedHint =>
      'This provider cannot be removed until another sign-in method remains available.';

  @override
  String get profileDetailsNotificationsBody =>
      'This section reflects your current communication preferences in the app.';

  @override
  String get profileDetailsNotificationsStatusEnabled =>
      'Product updates and offers are enabled for this profile. Additional push controls will appear here later.';

  @override
  String get profileDetailsNotificationsStatusDisabled =>
      'Marketing emails are currently disabled for this profile. Additional push controls will appear here later.';

  @override
  String get profileDetailsNotificationsNext =>
      'You can already review the current email preference here. Dedicated push toggles will be added in a later product slice.';

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
  String get profileLegalCompactHint =>
      'The summary stays visible, and each section expands only when you need more detail.';

  @override
  String get profileLegalCurrentAcceptedHint =>
      'No additional confirmation is required for this account right now.';

  @override
  String get profileLegalCompactSectionLabel => 'Tap to expand';

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
  String get supportChatSecureTitle => 'Your conversation is secure';

  @override
  String get supportChatSecureSubtitle =>
      'We protect your data and keep your information private.';

  @override
  String get supportChatTodayLabel => 'Today';

  @override
  String get supportChatInputHint =>
      'Describe the issue, question or request...';

  @override
  String get supportChatSendAction => 'Send';

  @override
  String get supportChatEmptyTitle => 'Start the conversation';

  @override
  String get supportChatEmptyMessage =>
      'Your support chat is ready. Send the first message and the team will respond here.';

  @override
  String get supportChatStatusOpen => 'Open';

  @override
  String get supportChatStatusInProgress => 'In progress';

  @override
  String get supportChatStatusResolved => 'Resolved';

  @override
  String get supportChatStatusClosed => 'Closed';

  @override
  String get supportChatMessageDelivered => 'Delivered';

  @override
  String get supportChatMessageRead => 'Read';

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
  String get profileSettingsLanguageEnglishUs => 'English (US)';

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
}
