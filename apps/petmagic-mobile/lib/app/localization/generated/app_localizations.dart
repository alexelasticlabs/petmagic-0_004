import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_it.dart';
import 'app_localizations_pl.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('it'),
    Locale('pl'),
    Locale('ru'),
  ];

  /// No description provided for @navTemplates.
  ///
  /// In en, this message translates to:
  /// **'Templates'**
  String get navTemplates;

  /// No description provided for @navCreations.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get navCreations;

  /// No description provided for @navRewards.
  ///
  /// In en, this message translates to:
  /// **'Rewards'**
  String get navRewards;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @comingSoonMessage.
  ///
  /// In en, this message translates to:
  /// **'This section is prepared for the next product wave.'**
  String get comingSoonMessage;

  /// No description provided for @createMagicTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Magic'**
  String get createMagicTitle;

  /// No description provided for @pickTemplateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pick a template for your pet'**
  String get pickTemplateSubtitle;

  /// No description provided for @searchTemplates.
  ///
  /// In en, this message translates to:
  /// **'Search templates'**
  String get searchTemplates;

  /// No description provided for @allFilter.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get allFilter;

  /// No description provided for @videosFilter.
  ///
  /// In en, this message translates to:
  /// **'Videos'**
  String get videosFilter;

  /// No description provided for @imagesFilter.
  ///
  /// In en, this message translates to:
  /// **'Images'**
  String get imagesFilter;

  /// No description provided for @trendingFilter.
  ///
  /// In en, this message translates to:
  /// **'🔥 Trending'**
  String get trendingFilter;

  /// No description provided for @funnyFilter.
  ///
  /// In en, this message translates to:
  /// **'😂 Funny'**
  String get funnyFilter;

  /// No description provided for @danceFilter.
  ///
  /// In en, this message translates to:
  /// **'🕺 Dance'**
  String get danceFilter;

  /// No description provided for @magicFilter.
  ///
  /// In en, this message translates to:
  /// **'✣ Magic'**
  String get magicFilter;

  /// No description provided for @adventureFilter.
  ///
  /// In en, this message translates to:
  /// **'🌄 Adventure'**
  String get adventureFilter;

  /// No description provided for @filtersTooltip.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get filtersTooltip;

  /// No description provided for @giftTooltip.
  ///
  /// In en, this message translates to:
  /// **'Rewards'**
  String get giftTooltip;

  /// No description provided for @addTokensTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add PawSpark'**
  String get addTokensTooltip;

  /// No description provided for @premiumLabel.
  ///
  /// In en, this message translates to:
  /// **'Premium'**
  String get premiumLabel;

  /// No description provided for @freeLabel.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get freeLabel;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Your Profile'**
  String get profileTitle;

  /// No description provided for @profileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage sign-in and your public avatar.'**
  String get profileSubtitle;

  /// No description provided for @profileDashboardSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage your account and personalize your PetMagic experience.'**
  String get profileDashboardSubtitle;

  /// No description provided for @profileSignInTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue'**
  String get profileSignInTitle;

  /// No description provided for @profileSignInHint.
  ///
  /// In en, this message translates to:
  /// **'Use your PetMagic account to load your profile and manage the avatar visible in admin.'**
  String get profileSignInHint;

  /// No description provided for @profileEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get profileEmailLabel;

  /// No description provided for @profilePasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get profilePasswordLabel;

  /// No description provided for @profileSignInAction.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get profileSignInAction;

  /// No description provided for @profileSignOutAction.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get profileSignOutAction;

  /// No description provided for @profileLoadingAction.
  ///
  /// In en, this message translates to:
  /// **'Working...'**
  String get profileLoadingAction;

  /// No description provided for @profileAvatarUpload.
  ///
  /// In en, this message translates to:
  /// **'Upload avatar'**
  String get profileAvatarUpload;

  /// No description provided for @profileAvatarRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove avatar'**
  String get profileAvatarRemove;

  /// No description provided for @profileEmailConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Email confirmed'**
  String get profileEmailConfirmed;

  /// No description provided for @profileEmailPending.
  ///
  /// In en, this message translates to:
  /// **'Email not confirmed'**
  String get profileEmailPending;

  /// No description provided for @profileEmailVerifiedShort.
  ///
  /// In en, this message translates to:
  /// **'Email verified'**
  String get profileEmailVerifiedShort;

  /// No description provided for @profileEmailPendingShort.
  ///
  /// In en, this message translates to:
  /// **'Verify email'**
  String get profileEmailPendingShort;

  /// No description provided for @profileSignedOut.
  ///
  /// In en, this message translates to:
  /// **'Signed out on this device.'**
  String get profileSignedOut;

  /// No description provided for @profileAccountCenterTitle.
  ///
  /// In en, this message translates to:
  /// **'Account center'**
  String get profileAccountCenterTitle;

  /// No description provided for @profileAccountCenterSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Review your preferences, privacy and app setup.'**
  String get profileAccountCenterSubtitle;

  /// No description provided for @profileTermsStat.
  ///
  /// In en, this message translates to:
  /// **'Terms accepted'**
  String get profileTermsStat;

  /// No description provided for @profileMarketingStat.
  ///
  /// In en, this message translates to:
  /// **'Offers & updates'**
  String get profileMarketingStat;

  /// No description provided for @profileEmailStat.
  ///
  /// In en, this message translates to:
  /// **'Email status'**
  String get profileEmailStat;

  /// No description provided for @profileStatOn.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get profileStatOn;

  /// No description provided for @profileStatOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get profileStatOff;

  /// No description provided for @profileStatReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get profileStatReady;

  /// No description provided for @profileStatPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get profileStatPending;

  /// No description provided for @profilePetsTitle.
  ///
  /// In en, this message translates to:
  /// **'My pets'**
  String get profilePetsTitle;

  /// No description provided for @profilePetsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your favorite companions and pet profiles.'**
  String get profilePetsSubtitle;

  /// No description provided for @profilePremiumTitle.
  ///
  /// In en, this message translates to:
  /// **'Go Premium'**
  String get profilePremiumTitle;

  /// No description provided for @profilePremiumSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Unlock all templates and premium editing flows.'**
  String get profilePremiumSubtitle;

  /// No description provided for @profilePremiumPlanLabel.
  ///
  /// In en, this message translates to:
  /// **'Premium Plan'**
  String get profilePremiumPlanLabel;

  /// No description provided for @profileFreePlanLabel.
  ///
  /// In en, this message translates to:
  /// **'Free Plan'**
  String get profileFreePlanLabel;

  /// No description provided for @profilePremiumBannerTitle.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to Premium'**
  String get profilePremiumBannerTitle;

  /// No description provided for @profilePremiumBannerActiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Premium active'**
  String get profilePremiumBannerActiveTitle;

  /// No description provided for @profilePremiumBenefitUnlimitedTemplates.
  ///
  /// In en, this message translates to:
  /// **'Unlimited templates'**
  String get profilePremiumBenefitUnlimitedTemplates;

  /// No description provided for @profilePremiumBenefitPriorityGeneration.
  ///
  /// In en, this message translates to:
  /// **'Priority generation'**
  String get profilePremiumBenefitPriorityGeneration;

  /// No description provided for @profilePremiumBenefitNoWatermark.
  ///
  /// In en, this message translates to:
  /// **'No watermark'**
  String get profilePremiumBenefitNoWatermark;

  /// No description provided for @profilePremiumOpenAction.
  ///
  /// In en, this message translates to:
  /// **'Upgrade'**
  String get profilePremiumOpenAction;

  /// No description provided for @profileSubscriptionTitle.
  ///
  /// In en, this message translates to:
  /// **'My subscription'**
  String get profileSubscriptionTitle;

  /// No description provided for @profileSubscriptionStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get profileSubscriptionStatusLabel;

  /// No description provided for @profileSubscriptionProviderLabel.
  ///
  /// In en, this message translates to:
  /// **'Provider'**
  String get profileSubscriptionProviderLabel;

  /// No description provided for @profileSubscriptionNextBillingLabel.
  ///
  /// In en, this message translates to:
  /// **'Next billing date'**
  String get profileSubscriptionNextBillingLabel;

  /// No description provided for @profileSubscriptionTokensLabel.
  ///
  /// In en, this message translates to:
  /// **'Tokens available'**
  String get profileSubscriptionTokensLabel;

  /// No description provided for @profileWalletTitle.
  ///
  /// In en, this message translates to:
  /// **'Wallet'**
  String get profileWalletTitle;

  /// No description provided for @profileWalletHistoryHint.
  ///
  /// In en, this message translates to:
  /// **'Open balance, purchases and history.'**
  String get profileWalletHistoryHint;

  /// No description provided for @walletPageTitle.
  ///
  /// In en, this message translates to:
  /// **'PawSpark wallet'**
  String get walletPageTitle;

  /// No description provided for @walletPageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Balance, promo codes, ad bonus, and PawSpark top-ups.'**
  String get walletPageSubtitle;

  /// No description provided for @profileWalletPreviewEyebrow.
  ///
  /// In en, this message translates to:
  /// **'PawSpark'**
  String get profileWalletPreviewEyebrow;

  /// No description provided for @profileWalletPreviewSubtitle.
  ///
  /// In en, this message translates to:
  /// **'In-app currency for generations and bonus rewards.'**
  String get profileWalletPreviewSubtitle;

  /// No description provided for @profileWalletPreviewAction.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get profileWalletPreviewAction;

  /// No description provided for @profileWalletPreviewLoadingStatus.
  ///
  /// In en, this message translates to:
  /// **'Refreshing status'**
  String get profileWalletPreviewLoadingStatus;

  /// No description provided for @profileWalletPreviewWeeklyReady.
  ///
  /// In en, this message translates to:
  /// **'Weekly reward ready'**
  String get profileWalletPreviewWeeklyReady;

  /// No description provided for @profileWalletPreviewAdCount.
  ///
  /// In en, this message translates to:
  /// **'Ads today: {count}'**
  String profileWalletPreviewAdCount(Object count);

  /// No description provided for @profileWalletLoadingHint.
  ///
  /// In en, this message translates to:
  /// **'Loading balance...'**
  String get profileWalletLoadingHint;

  /// No description provided for @profileWalletEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Open balance and history'**
  String get profileWalletEmptyHint;

  /// No description provided for @walletDataUnavailableFallback.
  ///
  /// In en, this message translates to:
  /// **'Wallet data is not available right now.'**
  String get walletDataUnavailableFallback;

  /// No description provided for @walletRefreshTooltip.
  ///
  /// In en, this message translates to:
  /// **'Refresh wallet'**
  String get walletRefreshTooltip;

  /// No description provided for @walletBalanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Available for photos, videos and premium templates.'**
  String get walletBalanceTitle;

  /// No description provided for @walletBalanceEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Your balance'**
  String get walletBalanceEyebrow;

  /// No description provided for @walletBalanceUnit.
  ///
  /// In en, this message translates to:
  /// **'PawSpark'**
  String get walletBalanceUnit;

  /// No description provided for @walletBalanceExplanation.
  ///
  /// In en, this message translates to:
  /// **'PawSpark — internal currency of PetMagic. Use it for creating photos, videos and accessing premium templates.'**
  String get walletBalanceExplanation;

  /// No description provided for @walletPremiumStatus.
  ///
  /// In en, this message translates to:
  /// **'Premium wallet'**
  String get walletPremiumStatus;

  /// No description provided for @walletFreeStatus.
  ///
  /// In en, this message translates to:
  /// **'Free wallet'**
  String get walletFreeStatus;

  /// No description provided for @walletAdRewardsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} ad rewards'**
  String walletAdRewardsCount(Object count);

  /// No description provided for @walletQuickActionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Promo codes'**
  String get walletQuickActionsTitle;

  /// No description provided for @walletRedeemAction.
  ///
  /// In en, this message translates to:
  /// **'Activate'**
  String get walletRedeemAction;

  /// No description provided for @walletRewardsTitle.
  ///
  /// In en, this message translates to:
  /// **'Ad bonus'**
  String get walletRewardsTitle;

  /// No description provided for @walletAdRewardAction.
  ///
  /// In en, this message translates to:
  /// **'Ad reward'**
  String get walletAdRewardAction;

  /// No description provided for @walletAdRewardCompactTitle.
  ///
  /// In en, this message translates to:
  /// **'Get PawSpark for free'**
  String get walletAdRewardCompactTitle;

  /// No description provided for @walletAdRewardCompactDescription.
  ///
  /// In en, this message translates to:
  /// **'Watch a short ad and get +15 PawSpark.'**
  String get walletAdRewardCompactDescription;

  /// No description provided for @walletAdRewardRemaining.
  ///
  /// In en, this message translates to:
  /// **'Left today: {count}'**
  String walletAdRewardRemaining(Object count);

  /// No description provided for @walletWatchAdAction.
  ///
  /// In en, this message translates to:
  /// **'Watch ad +15'**
  String get walletWatchAdAction;

  /// No description provided for @walletAdDailyLimitReached.
  ///
  /// In en, this message translates to:
  /// **'Ads are temporarily unavailable. Please try again later.'**
  String get walletAdDailyLimitReached;

  /// No description provided for @walletPromoTitle.
  ///
  /// In en, this message translates to:
  /// **'Have a promo code?'**
  String get walletPromoTitle;

  /// No description provided for @walletPromoSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter a code from PetMagic and add PawSpark to your balance.'**
  String get walletPromoSubtitle;

  /// No description provided for @walletPromoInputPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Enter promo code'**
  String get walletPromoInputPlaceholder;

  /// No description provided for @walletPromoSuccessMessage.
  ///
  /// In en, this message translates to:
  /// **'Promo code activated successfully!'**
  String get walletPromoSuccessMessage;

  /// No description provided for @walletBestValueBadge.
  ///
  /// In en, this message translates to:
  /// **'Best value'**
  String get walletBestValueBadge;

  /// No description provided for @walletPremiumUpsellTitle.
  ///
  /// In en, this message translates to:
  /// **'Create often?'**
  String get walletPremiumUpsellTitle;

  /// No description provided for @walletPremiumUpsellMessage.
  ///
  /// In en, this message translates to:
  /// **'Premium membership gives you cheaper generations, monthly PawSparks and exclusive premium templates.'**
  String get walletPremiumUpsellMessage;

  /// No description provided for @walletViewPremiumAction.
  ///
  /// In en, this message translates to:
  /// **'View Premium'**
  String get walletViewPremiumAction;

  /// No description provided for @walletWhatYouCanCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'Enough for approximately:'**
  String get walletWhatYouCanCreateTitle;

  /// No description provided for @walletApproxPhotos.
  ///
  /// In en, this message translates to:
  /// **'{count} photos'**
  String walletApproxPhotos(int count);

  /// No description provided for @walletApproxVideos.
  ///
  /// In en, this message translates to:
  /// **'{count} videos'**
  String walletApproxVideos(int count);

  /// No description provided for @walletSpendPhotoSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Photos\nfrom 10 Spark'**
  String get walletSpendPhotoSubtitle;

  /// No description provided for @walletSpendVideoSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Videos\nfrom 50 Spark'**
  String get walletSpendVideoSubtitle;

  /// No description provided for @walletSpendPremiumSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Premium\nfrom 80 Spark'**
  String get walletSpendPremiumSubtitle;

  /// No description provided for @walletContactSupportAction.
  ///
  /// In en, this message translates to:
  /// **'Contact support'**
  String get walletContactSupportAction;

  /// No description provided for @walletRetryAction.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get walletRetryAction;

  /// No description provided for @rewardsPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Rewards'**
  String get rewardsPageTitle;

  /// No description provided for @rewardsPageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Earn PawSpark with promo codes and invitations'**
  String get rewardsPageSubtitle;

  /// No description provided for @rewardsLastUpdatedLabel.
  ///
  /// In en, this message translates to:
  /// **'Updated: {value}'**
  String rewardsLastUpdatedLabel(Object value);

  /// No description provided for @rewardsLastUpdatedNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get rewardsLastUpdatedNow;

  /// No description provided for @rewardsLastUpdatedMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count} min ago'**
  String rewardsLastUpdatedMinutes(int count);

  /// No description provided for @rewardsLastUpdatedHours.
  ///
  /// In en, this message translates to:
  /// **'{count} h ago'**
  String rewardsLastUpdatedHours(int count);

  /// No description provided for @rewardsPromoTitle.
  ///
  /// In en, this message translates to:
  /// **'Promo code'**
  String get rewardsPromoTitle;

  /// No description provided for @rewardsPromoSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter a promo code and receive a bonus'**
  String get rewardsPromoSubtitle;

  /// No description provided for @rewardsPromoEmptyError.
  ///
  /// In en, this message translates to:
  /// **'Enter promo code.'**
  String get rewardsPromoEmptyError;

  /// No description provided for @rewardsPromoCheckingStatus.
  ///
  /// In en, this message translates to:
  /// **'Checking code...'**
  String get rewardsPromoCheckingStatus;

  /// No description provided for @rewardsReferralTitle.
  ///
  /// In en, this message translates to:
  /// **'Invite a friend'**
  String get rewardsReferralTitle;

  /// No description provided for @rewardsReferralSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Share your code with a friend. Referral bonus is not paid for signup and is credited only after their first successful paid purchase.'**
  String get rewardsReferralSubtitle;

  /// No description provided for @rewardsReferralInvitePrefix.
  ///
  /// In en, this message translates to:
  /// **'Your friend gets a bonus before their first purchase, and you get'**
  String get rewardsReferralInvitePrefix;

  /// No description provided for @rewardsReferralInviteSuffix.
  ///
  /// In en, this message translates to:
  /// **'after their first successful payment.'**
  String get rewardsReferralInviteSuffix;

  /// No description provided for @rewardsYourReferralCode.
  ///
  /// In en, this message translates to:
  /// **'Your code'**
  String get rewardsYourReferralCode;

  /// No description provided for @rewardsCopyReferralCodeAction.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get rewardsCopyReferralCodeAction;

  /// No description provided for @rewardsReferralCopiedMessage.
  ///
  /// In en, this message translates to:
  /// **'Code copied.'**
  String get rewardsReferralCopiedMessage;

  /// No description provided for @rewardsReferralShareCodeAction.
  ///
  /// In en, this message translates to:
  /// **'Share code'**
  String get rewardsReferralShareCodeAction;

  /// No description provided for @rewardsReferralUseFriendCodeAction.
  ///
  /// In en, this message translates to:
  /// **'Enter friend code'**
  String get rewardsReferralUseFriendCodeAction;

  /// No description provided for @rewardsReferralFriendCodePrompt.
  ///
  /// In en, this message translates to:
  /// **'Have a friend\'s code?'**
  String get rewardsReferralFriendCodePrompt;

  /// No description provided for @rewardsReferralFriendCodeHint.
  ///
  /// In en, this message translates to:
  /// **'Enter a friend\'s code before your first purchase and get a bonus.'**
  String get rewardsReferralFriendCodeHint;

  /// No description provided for @rewardsReferralInputLabel.
  ///
  /// In en, this message translates to:
  /// **'Friend code'**
  String get rewardsReferralInputLabel;

  /// No description provided for @rewardsReferralInputHint.
  ///
  /// In en, this message translates to:
  /// **'PMABC12345'**
  String get rewardsReferralInputHint;

  /// No description provided for @rewardsReferralActivateAction.
  ///
  /// In en, this message translates to:
  /// **'Activate code'**
  String get rewardsReferralActivateAction;

  /// No description provided for @rewardsReferralEmptyError.
  ///
  /// In en, this message translates to:
  /// **'Enter friend code.'**
  String get rewardsReferralEmptyError;

  /// No description provided for @rewardsReferralCheckingStatus.
  ///
  /// In en, this message translates to:
  /// **'Checking referral code...'**
  String get rewardsReferralCheckingStatus;

  /// No description provided for @rewardsReferralActivatedMessage.
  ///
  /// In en, this message translates to:
  /// **'Referral code activated. Bonus is credited after your first successful paid purchase.'**
  String get rewardsReferralActivatedMessage;

  /// No description provided for @rewardsReferralStatusLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading referral status...'**
  String get rewardsReferralStatusLoading;

  /// No description provided for @rewardsReferralStatusNone.
  ///
  /// In en, this message translates to:
  /// **'Enter a friend\'s code before your first purchase. Bonus is credited only after a successful payment.'**
  String get rewardsReferralStatusNone;

  /// No description provided for @rewardsReferralStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Referral connected. Bonus will be paid after your first successful paid purchase.'**
  String get rewardsReferralStatusPending;

  /// No description provided for @rewardsReferralStatusRewarded.
  ///
  /// In en, this message translates to:
  /// **'Referral bonus paid. Thanks for growing PetMagic.'**
  String get rewardsReferralStatusRewarded;

  /// No description provided for @rewardsReferralEarnedLabel.
  ///
  /// In en, this message translates to:
  /// **'Earned'**
  String get rewardsReferralEarnedLabel;

  /// No description provided for @rewardsReferralFriendsLabel.
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get rewardsReferralFriendsLabel;

  /// No description provided for @rewardsReferralBonusLabel.
  ///
  /// In en, this message translates to:
  /// **'Friend purchases'**
  String get rewardsReferralBonusLabel;

  /// No description provided for @rewardsReferralBonusPerFriend.
  ///
  /// In en, this message translates to:
  /// **'+{count} PawSpark per invited friend'**
  String rewardsReferralBonusPerFriend(int count);

  /// No description provided for @rewardsReferralRulesNote.
  ///
  /// In en, this message translates to:
  /// **'Bonus is credited after your friend\'s first successful purchase.'**
  String get rewardsReferralRulesNote;

  /// No description provided for @rewardsReferralHowItWorksAction.
  ///
  /// In en, this message translates to:
  /// **'How does it work?'**
  String get rewardsReferralHowItWorksAction;

  /// No description provided for @rewardsReferralShareMessage.
  ///
  /// In en, this message translates to:
  /// **'Join me in PetMagic! Use my referral code {code}. Bonus is credited after your first successful paid purchase. After your first purchase I\'ll receive +{bonus} PawSpark.'**
  String rewardsReferralShareMessage(Object code, int bonus);

  /// No description provided for @rewardsHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get rewardsHistoryTitle;

  /// No description provided for @rewardsHistorySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Recent promo, referral, ad and weekly rewards.'**
  String get rewardsHistorySubtitle;

  /// No description provided for @rewardsHistoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No bonuses yet. Promo and referral rewards will appear here.'**
  String get rewardsHistoryEmpty;

  /// No description provided for @rewardsSourcePromo.
  ///
  /// In en, this message translates to:
  /// **'Promo code'**
  String get rewardsSourcePromo;

  /// No description provided for @rewardsSourceReferral.
  ///
  /// In en, this message translates to:
  /// **'Referral bonus'**
  String get rewardsSourceReferral;

  /// No description provided for @rewardsSourceAd.
  ///
  /// In en, this message translates to:
  /// **'Ad reward'**
  String get rewardsSourceAd;

  /// No description provided for @rewardsSourceWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly reward'**
  String get rewardsSourceWeekly;

  /// No description provided for @rewardsSourcePremium.
  ///
  /// In en, this message translates to:
  /// **'Premium grant'**
  String get rewardsSourcePremium;

  /// No description provided for @rewardsSourceBonus.
  ///
  /// In en, this message translates to:
  /// **'Bonus'**
  String get rewardsSourceBonus;

  /// No description provided for @rewardsReferralCodeNotFoundError.
  ///
  /// In en, this message translates to:
  /// **'Referral code was not found.'**
  String get rewardsReferralCodeNotFoundError;

  /// No description provided for @rewardsReferralSelfError.
  ///
  /// In en, this message translates to:
  /// **'You cannot activate your own referral code.'**
  String get rewardsReferralSelfError;

  /// No description provided for @rewardsReferralAlreadyLinkedError.
  ///
  /// In en, this message translates to:
  /// **'A referral code is already activated for this account.'**
  String get rewardsReferralAlreadyLinkedError;

  /// No description provided for @rewardsReferralPaidUserError.
  ///
  /// In en, this message translates to:
  /// **'Referral code must be activated before your first successful paid purchase.'**
  String get rewardsReferralPaidUserError;

  /// No description provided for @walletBuySparkTitle.
  ///
  /// In en, this message translates to:
  /// **'Top up PawSpark'**
  String get walletBuySparkTitle;

  /// No description provided for @walletPackTotalSpark.
  ///
  /// In en, this message translates to:
  /// **'{count} PawSpark'**
  String walletPackTotalSpark(Object count);

  /// No description provided for @walletPopularBadge.
  ///
  /// In en, this message translates to:
  /// **'Popular'**
  String get walletPopularBadge;

  /// No description provided for @walletBestValueLabel.
  ///
  /// In en, this message translates to:
  /// **'Best value'**
  String get walletBestValueLabel;

  /// No description provided for @walletPackBonus.
  ///
  /// In en, this message translates to:
  /// **'+{count} bonus'**
  String walletPackBonus(Object count);

  /// No description provided for @walletPackBonusPill.
  ///
  /// In en, this message translates to:
  /// **'Bonus +{count}'**
  String walletPackBonusPill(Object count);

  /// No description provided for @walletPackBaseSpark.
  ///
  /// In en, this message translates to:
  /// **'{count} base'**
  String walletPackBaseSpark(Object count);

  /// No description provided for @walletBuyForPrice.
  ///
  /// In en, this message translates to:
  /// **'Buy for {price}'**
  String walletBuyForPrice(Object price);

  /// No description provided for @walletPackDetailsAction.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get walletPackDetailsAction;

  /// No description provided for @walletPackDetailSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Check what is included before opening checkout.'**
  String get walletPackDetailSubtitle;

  /// No description provided for @walletCheckoutHint.
  ///
  /// In en, this message translates to:
  /// **'Payment opens in secure Stripe Checkout. PetMagic does not store your card details.'**
  String get walletCheckoutHint;

  /// No description provided for @walletCheckoutSucceeded.
  ///
  /// In en, this message translates to:
  /// **'Payment confirmed. +{spark} PawSpark is already in your wallet.'**
  String walletCheckoutSucceeded(int spark);

  /// No description provided for @walletPackBreakdown.
  ///
  /// In en, this message translates to:
  /// **'{base} base + {bonus} bonus'**
  String walletPackBreakdown(Object base, Object bonus);

  /// No description provided for @walletRecentTransactionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Recent transactions'**
  String get walletRecentTransactionsTitle;

  /// No description provided for @walletViewAllTransactions.
  ///
  /// In en, this message translates to:
  /// **'All transactions'**
  String get walletViewAllTransactions;

  /// No description provided for @walletNoActivity.
  ///
  /// In en, this message translates to:
  /// **'No wallet activity yet.'**
  String get walletNoActivity;

  /// No description provided for @walletBalanceAfter.
  ///
  /// In en, this message translates to:
  /// **'Bal. {count}'**
  String walletBalanceAfter(Object count);

  /// No description provided for @walletPurchaseHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Purchase history'**
  String get walletPurchaseHistoryTitle;

  /// No description provided for @walletPurchaseSummary.
  ///
  /// In en, this message translates to:
  /// **'{count} PawSpark • {date}'**
  String walletPurchaseSummary(Object count, Object date);

  /// No description provided for @walletPurchaseJustConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Just confirmed'**
  String get walletPurchaseJustConfirmed;

  /// No description provided for @walletUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Wallet is temporarily unavailable'**
  String get walletUnavailableTitle;

  /// No description provided for @walletTryAgainAction.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get walletTryAgainAction;

  /// No description provided for @walletPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get walletPending;

  /// No description provided for @walletSourcePackPurchase.
  ///
  /// In en, this message translates to:
  /// **'Added funds'**
  String get walletSourcePackPurchase;

  /// No description provided for @walletSourceGenerationSpend.
  ///
  /// In en, this message translates to:
  /// **'Generation'**
  String get walletSourceGenerationSpend;

  /// No description provided for @walletSourceGenerationRefund.
  ///
  /// In en, this message translates to:
  /// **'Generation refund'**
  String get walletSourceGenerationRefund;

  /// No description provided for @walletSourceWeeklyGrant.
  ///
  /// In en, this message translates to:
  /// **'Weekly bonus'**
  String get walletSourceWeeklyGrant;

  /// No description provided for @walletSourceAdReward.
  ///
  /// In en, this message translates to:
  /// **'Ad bonus'**
  String get walletSourceAdReward;

  /// No description provided for @walletSourcePromoCode.
  ///
  /// In en, this message translates to:
  /// **'Promo code'**
  String get walletSourcePromoCode;

  /// No description provided for @walletSourceAdminGrant.
  ///
  /// In en, this message translates to:
  /// **'Support credit'**
  String get walletSourceAdminGrant;

  /// No description provided for @walletSourceAdminDebit.
  ///
  /// In en, this message translates to:
  /// **'Support adjustment'**
  String get walletSourceAdminDebit;

  /// No description provided for @walletPurchaseCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get walletPurchaseCompleted;

  /// No description provided for @walletPurchaseFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get walletPurchaseFailed;

  /// No description provided for @walletQueryFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get walletQueryFilterAll;

  /// No description provided for @walletQueryFilterCredits.
  ///
  /// In en, this message translates to:
  /// **'Credits'**
  String get walletQueryFilterCredits;

  /// No description provided for @walletQueryFilterDebits.
  ///
  /// In en, this message translates to:
  /// **'Debits'**
  String get walletQueryFilterDebits;

  /// No description provided for @walletPartialActivityUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Your balance is already available. History and some wallet actions will refresh a bit later.'**
  String get walletPartialActivityUnavailable;

  /// No description provided for @walletPaymentGatewayUnavailableError.
  ///
  /// In en, this message translates to:
  /// **'Payments are temporarily unavailable. Please try again later or update the app.'**
  String get walletPaymentGatewayUnavailableError;

  /// No description provided for @walletPaymentUnavailableError.
  ///
  /// In en, this message translates to:
  /// **'Top-up is temporarily unavailable. Please try again later.'**
  String get walletPaymentUnavailableError;

  /// No description provided for @walletPackUnavailableError.
  ///
  /// In en, this message translates to:
  /// **'This PawSpark pack is no longer available.'**
  String get walletPackUnavailableError;

  /// No description provided for @walletRedeemCodeNotFoundError.
  ///
  /// In en, this message translates to:
  /// **'Redeem code was not found.'**
  String get walletRedeemCodeNotFoundError;

  /// No description provided for @walletRedeemCodeAlreadyUsedError.
  ///
  /// In en, this message translates to:
  /// **'This redeem code was already used.'**
  String get walletRedeemCodeAlreadyUsedError;

  /// No description provided for @walletRedeemCodeExpiredError.
  ///
  /// In en, this message translates to:
  /// **'Redeem code has expired.'**
  String get walletRedeemCodeExpiredError;

  /// No description provided for @walletRedeemCodeInactiveError.
  ///
  /// In en, this message translates to:
  /// **'This redeem code is not available right now.'**
  String get walletRedeemCodeInactiveError;

  /// No description provided for @walletRedeemCodeExhaustedError.
  ///
  /// In en, this message translates to:
  /// **'This redeem code has reached its usage limit.'**
  String get walletRedeemCodeExhaustedError;

  /// No description provided for @walletRedeemCodeUserLimitError.
  ///
  /// In en, this message translates to:
  /// **'This user has already reached the redeem limit for this code.'**
  String get walletRedeemCodeUserLimitError;

  /// No description provided for @walletRedeemOfflineError.
  ///
  /// In en, this message translates to:
  /// **'No internet connection. Check your network and try again.'**
  String get walletRedeemOfflineError;

  /// No description provided for @walletRedeemServerError.
  ///
  /// In en, this message translates to:
  /// **'The promo code could not be applied because of a server error. Please try again later.'**
  String get walletRedeemServerError;

  /// No description provided for @walletInsufficientBalanceError.
  ///
  /// In en, this message translates to:
  /// **'Not enough PawSpark for this operation.'**
  String get walletInsufficientBalanceError;

  /// No description provided for @walletUnavailableError.
  ///
  /// In en, this message translates to:
  /// **'Wallet data is temporarily unavailable. Please try again in a moment.'**
  String get walletUnavailableError;

  /// No description provided for @walletRedeemSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Redeem code'**
  String get walletRedeemSheetTitle;

  /// No description provided for @walletRedeemSheetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A code can be used once while it is active and not expired.'**
  String get walletRedeemSheetSubtitle;

  /// No description provided for @walletRedeemInputLabel.
  ///
  /// In en, this message translates to:
  /// **'Promo code'**
  String get walletRedeemInputLabel;

  /// No description provided for @walletRedeemHint.
  ///
  /// In en, this message translates to:
  /// **'Enter promo code'**
  String get walletRedeemHint;

  /// No description provided for @walletRedeemCancelAction.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get walletRedeemCancelAction;

  /// No description provided for @walletApplyCode.
  ///
  /// In en, this message translates to:
  /// **'Apply code'**
  String get walletApplyCode;

  /// No description provided for @walletRedeemSuccessMessage.
  ///
  /// In en, this message translates to:
  /// **'Promo code applied successfully. Your balance is already updated.'**
  String get walletRedeemSuccessMessage;

  /// No description provided for @walletRedeemSuccessAction.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get walletRedeemSuccessAction;

  /// No description provided for @profileStatsSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Account stats'**
  String get profileStatsSectionTitle;

  /// No description provided for @profileStatBalanceLabel.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get profileStatBalanceLabel;

  /// No description provided for @profileStatPlanLabel.
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get profileStatPlanLabel;

  /// No description provided for @profileStatLegalLabel.
  ///
  /// In en, this message translates to:
  /// **'Legal'**
  String get profileStatLegalLabel;

  /// No description provided for @profileMagicMomentTitle.
  ///
  /// In en, this message translates to:
  /// **'Your next pet star moment'**
  String get profileMagicMomentTitle;

  /// No description provided for @profileMagicMomentSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create something playful for your pets in just a few taps.'**
  String get profileMagicMomentSubtitle;

  /// No description provided for @premiumPageTitle.
  ///
  /// In en, this message translates to:
  /// **'PetMagic Premium'**
  String get premiumPageTitle;

  /// No description provided for @premiumPageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Unlimited pet magic, faster generation and premium templates in one plan.'**
  String get premiumPageSubtitle;

  /// No description provided for @premiumHeroEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Premium magic'**
  String get premiumHeroEyebrow;

  /// No description provided for @premiumHeroTitle.
  ///
  /// In en, this message translates to:
  /// **'Get Premium and create more content.'**
  String get premiumHeroTitle;

  /// No description provided for @premiumHeroSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Unlock premium templates, faster generation and more room for photos and videos in one plan.'**
  String get premiumHeroSubtitle;

  /// No description provided for @premiumAlreadyActive.
  ///
  /// In en, this message translates to:
  /// **'Premium active'**
  String get premiumAlreadyActive;

  /// No description provided for @premiumBenefitUnlimitedTemplates.
  ///
  /// In en, this message translates to:
  /// **'Unlimited templates'**
  String get premiumBenefitUnlimitedTemplates;

  /// No description provided for @premiumBenefitFastGeneration.
  ///
  /// In en, this message translates to:
  /// **'Faster generation'**
  String get premiumBenefitFastGeneration;

  /// No description provided for @premiumBenefitHighQuality.
  ///
  /// In en, this message translates to:
  /// **'High quality output'**
  String get premiumBenefitHighQuality;

  /// No description provided for @premiumBenefitExclusive.
  ///
  /// In en, this message translates to:
  /// **'Exclusive templates'**
  String get premiumBenefitExclusive;

  /// No description provided for @premiumChoosePlanTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose plan'**
  String get premiumChoosePlanTitle;

  /// No description provided for @premiumWeeklyPlan.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get premiumWeeklyPlan;

  /// No description provided for @premiumMonthlyPlan.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get premiumMonthlyPlan;

  /// No description provided for @premiumYearlyPlan.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get premiumYearlyPlan;

  /// No description provided for @premiumWeeklyPeriod.
  ///
  /// In en, this message translates to:
  /// **'/ week'**
  String get premiumWeeklyPeriod;

  /// No description provided for @premiumMonthlyPeriod.
  ///
  /// In en, this message translates to:
  /// **'/ month'**
  String get premiumMonthlyPeriod;

  /// No description provided for @premiumYearlyPeriod.
  ///
  /// In en, this message translates to:
  /// **'/ year'**
  String get premiumYearlyPeriod;

  /// No description provided for @premiumPopularBadge.
  ///
  /// In en, this message translates to:
  /// **'Most popular'**
  String get premiumPopularBadge;

  /// No description provided for @premiumTokensPerWeek.
  ///
  /// In en, this message translates to:
  /// **'{count} tokens / week'**
  String premiumTokensPerWeek(Object count);

  /// No description provided for @premiumTokensPerMonth.
  ///
  /// In en, this message translates to:
  /// **'{count} tokens / month'**
  String premiumTokensPerMonth(Object count);

  /// No description provided for @premiumDiscountLabel.
  ///
  /// In en, this message translates to:
  /// **'Save {percent}%'**
  String premiumDiscountLabel(Object percent);

  /// No description provided for @premiumCancelAnytime.
  ///
  /// In en, this message translates to:
  /// **'Cancel anytime'**
  String get premiumCancelAnytime;

  /// No description provided for @premiumIncludesTitle.
  ///
  /// In en, this message translates to:
  /// **'What Premium includes'**
  String get premiumIncludesTitle;

  /// No description provided for @premiumTokenEstimate.
  ///
  /// In en, this message translates to:
  /// **'{videos} videos or {photos} photos per month, depending on template complexity.'**
  String premiumTokenEstimate(Object videos, Object photos);

  /// No description provided for @premiumSocialProof.
  ///
  /// In en, this message translates to:
  /// **'Most chosen plan for regular PetMagic creators.'**
  String get premiumSocialProof;

  /// No description provided for @premiumPaymentTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment method'**
  String get premiumPaymentTitle;

  /// No description provided for @premiumPaymentStripe.
  ///
  /// In en, this message translates to:
  /// **'Card via Stripe'**
  String get premiumPaymentStripe;

  /// No description provided for @premiumPaymentGooglePlay.
  ///
  /// In en, this message translates to:
  /// **'Google Play'**
  String get premiumPaymentGooglePlay;

  /// No description provided for @premiumPaymentApple.
  ///
  /// In en, this message translates to:
  /// **'Apple Pay / App Store'**
  String get premiumPaymentApple;

  /// No description provided for @premiumPaymentRecommendedBadge.
  ///
  /// In en, this message translates to:
  /// **'Recommended'**
  String get premiumPaymentRecommendedBadge;

  /// No description provided for @premiumPaymentDefaultBadge.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get premiumPaymentDefaultBadge;

  /// No description provided for @paymentBonusPercentBadge.
  ///
  /// In en, this message translates to:
  /// **'+{percent}% bonus'**
  String paymentBonusPercentBadge(Object percent);

  /// No description provided for @premiumComparisonTitle.
  ///
  /// In en, this message translates to:
  /// **'What changes with Premium'**
  String get premiumComparisonTitle;

  /// No description provided for @premiumFreeColumn.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get premiumFreeColumn;

  /// No description provided for @premiumPremiumColumn.
  ///
  /// In en, this message translates to:
  /// **'Premium'**
  String get premiumPremiumColumn;

  /// No description provided for @premiumComparisonFreeTemplates.
  ///
  /// In en, this message translates to:
  /// **'Free templates'**
  String get premiumComparisonFreeTemplates;

  /// No description provided for @premiumComparisonPremiumTemplates.
  ///
  /// In en, this message translates to:
  /// **'Premium templates'**
  String get premiumComparisonPremiumTemplates;

  /// No description provided for @premiumComparisonTokens.
  ///
  /// In en, this message translates to:
  /// **'Tokens per month'**
  String get premiumComparisonTokens;

  /// No description provided for @premiumComparisonPremiumTokens.
  ///
  /// In en, this message translates to:
  /// **'Up to {count}'**
  String premiumComparisonPremiumTokens(Object count);

  /// No description provided for @premiumComparisonPremiumTokensFallback.
  ///
  /// In en, this message translates to:
  /// **'Up to 1000'**
  String get premiumComparisonPremiumTokensFallback;

  /// No description provided for @premiumComparisonFast.
  ///
  /// In en, this message translates to:
  /// **'Fast generation'**
  String get premiumComparisonFast;

  /// No description provided for @premiumComparisonHighQuality.
  ///
  /// In en, this message translates to:
  /// **'High quality export'**
  String get premiumComparisonHighQuality;

  /// No description provided for @premiumComparisonNoWatermark.
  ///
  /// In en, this message translates to:
  /// **'No watermark'**
  String get premiumComparisonNoWatermark;

  /// No description provided for @premiumComparisonPrioritySupport.
  ///
  /// In en, this message translates to:
  /// **'Priority support'**
  String get premiumComparisonPrioritySupport;

  /// No description provided for @premiumFreeSummaryTokens.
  ///
  /// In en, this message translates to:
  /// **'20 tokens per month'**
  String get premiumFreeSummaryTokens;

  /// No description provided for @premiumFreeSummaryWatermark.
  ///
  /// In en, this message translates to:
  /// **'Watermark on content'**
  String get premiumFreeSummaryWatermark;

  /// No description provided for @premiumFreeSummaryTemplates.
  ///
  /// In en, this message translates to:
  /// **'Basic templates'**
  String get premiumFreeSummaryTemplates;

  /// No description provided for @premiumFreeSummaryQuality.
  ///
  /// In en, this message translates to:
  /// **'Standard quality'**
  String get premiumFreeSummaryQuality;

  /// No description provided for @premiumSecurePaymentTitle.
  ///
  /// In en, this message translates to:
  /// **'Secure payment'**
  String get premiumSecurePaymentTitle;

  /// No description provided for @premiumSecurePaymentSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage or cancel your subscription from billing settings at any time.'**
  String get premiumSecurePaymentSubtitle;

  /// No description provided for @premiumContinueAction.
  ///
  /// In en, this message translates to:
  /// **'Start Premium'**
  String get premiumContinueAction;

  /// No description provided for @externalCheckoutStripeTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment via Stripe'**
  String get externalCheckoutStripeTitle;

  /// No description provided for @externalCheckoutStripeMessage.
  ///
  /// In en, this message translates to:
  /// **'Stripe Checkout opens in a secure in-app browser. After you return to PetMagic, we automatically check the payment status before updating your access.'**
  String get externalCheckoutStripeMessage;

  /// No description provided for @externalCheckoutContinueAction.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get externalCheckoutContinueAction;

  /// No description provided for @externalCheckoutCheckingTitle.
  ///
  /// In en, this message translates to:
  /// **'Checking payment'**
  String get externalCheckoutCheckingTitle;

  /// No description provided for @externalCheckoutCheckingMessage.
  ///
  /// In en, this message translates to:
  /// **'We are waiting for Stripe confirmation. This usually takes a few seconds.'**
  String get externalCheckoutCheckingMessage;

  /// No description provided for @externalCheckoutPendingVerificationMessage.
  ///
  /// In en, this message translates to:
  /// **'Payment is not confirmed yet. We will update Premium or your wallet as soon as Stripe webhook arrives.'**
  String get externalCheckoutPendingVerificationMessage;

  /// No description provided for @premiumContinueWithPlan.
  ///
  /// In en, this message translates to:
  /// **'Continue with {plan} — {price} {period}'**
  String premiumContinueWithPlan(Object plan, Object price, Object period);

  /// No description provided for @premiumManageAction.
  ///
  /// In en, this message translates to:
  /// **'Manage subscription'**
  String get premiumManageAction;

  /// No description provided for @premiumRestoreAction.
  ///
  /// In en, this message translates to:
  /// **'Restore purchases'**
  String get premiumRestoreAction;

  /// No description provided for @premiumTermsNotice.
  ///
  /// In en, this message translates to:
  /// **'By continuing, you agree to the Terms of Use and Privacy Policy.'**
  String get premiumTermsNotice;

  /// No description provided for @premiumStoreUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Store subscriptions are waiting for App Store / Google Play product setup. Use Stripe checkout for now.'**
  String get premiumStoreUnavailable;

  /// No description provided for @premiumStoreProductUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This subscription product is not available in the store on this device.'**
  String get premiumStoreProductUnavailable;

  /// No description provided for @premiumStoreVerificationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Server-side store verification is not configured yet.'**
  String get premiumStoreVerificationUnavailable;

  /// No description provided for @premiumStorePurchaseInvalid.
  ///
  /// In en, this message translates to:
  /// **'The purchase could not be verified.'**
  String get premiumStorePurchaseInvalid;

  /// No description provided for @premiumStorePurchaseInactive.
  ///
  /// In en, this message translates to:
  /// **'This subscription is no longer active.'**
  String get premiumStorePurchaseInactive;

  /// No description provided for @premiumPurchaseActivated.
  ///
  /// In en, this message translates to:
  /// **'Premium is active now.'**
  String get premiumPurchaseActivated;

  /// No description provided for @premiumRecentlyActivatedBadge.
  ///
  /// In en, this message translates to:
  /// **'Just activated'**
  String get premiumRecentlyActivatedBadge;

  /// No description provided for @premiumRecentlyActivatedTitle.
  ///
  /// In en, this message translates to:
  /// **'Premium confirmed'**
  String get premiumRecentlyActivatedTitle;

  /// No description provided for @premiumRecentlyActivatedMessage.
  ///
  /// In en, this message translates to:
  /// **'Your Premium access is active on this device and ready to use.'**
  String get premiumRecentlyActivatedMessage;

  /// No description provided for @premiumPurchaseCancelled.
  ///
  /// In en, this message translates to:
  /// **'Purchase was cancelled.'**
  String get premiumPurchaseCancelled;

  /// No description provided for @premiumCheckoutFailed.
  ///
  /// In en, this message translates to:
  /// **'Premium checkout is temporarily unavailable.'**
  String get premiumCheckoutFailed;

  /// No description provided for @premiumManageFailed.
  ///
  /// In en, this message translates to:
  /// **'Billing management is not available yet for this account.'**
  String get premiumManageFailed;

  /// No description provided for @premiumRestoreStarted.
  ///
  /// In en, this message translates to:
  /// **'Premium status refreshed on this device.'**
  String get premiumRestoreStarted;

  /// No description provided for @profileCommunicationsTitle.
  ///
  /// In en, this message translates to:
  /// **'PetMagic updates'**
  String get profileCommunicationsTitle;

  /// No description provided for @profileCommunicationsEnabled.
  ///
  /// In en, this message translates to:
  /// **'You are subscribed to product updates and offers.'**
  String get profileCommunicationsEnabled;

  /// No description provided for @profileCommunicationsDisabled.
  ///
  /// In en, this message translates to:
  /// **'Marketing updates are currently turned off.'**
  String get profileCommunicationsDisabled;

  /// No description provided for @profilePrivacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy and consent'**
  String get profilePrivacyTitle;

  /// No description provided for @profileTermsAccepted.
  ///
  /// In en, this message translates to:
  /// **'Your account has accepted the Terms of Use and Privacy Policy.'**
  String get profileTermsAccepted;

  /// No description provided for @profileTermsPending.
  ///
  /// In en, this message translates to:
  /// **'Complete consent review in account settings.'**
  String get profileTermsPending;

  /// No description provided for @profileLegalShortcutTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy & Legal'**
  String get profileLegalShortcutTitle;

  /// No description provided for @profileLegalShortcutAccepted.
  ///
  /// In en, this message translates to:
  /// **'Terms accepted • Privacy settings'**
  String get profileLegalShortcutAccepted;

  /// No description provided for @profileLegalShortcutPending.
  ///
  /// In en, this message translates to:
  /// **'Review permissions'**
  String get profileLegalShortcutPending;

  /// No description provided for @profileSupportTitle.
  ///
  /// In en, this message translates to:
  /// **'Contact support'**
  String get profileSupportTitle;

  /// No description provided for @profileSupportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'We are here when you need help with your account.'**
  String get profileSupportSubtitle;

  /// No description provided for @profileSupportCompactSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Get help with billing or account access.'**
  String get profileSupportCompactSubtitle;

  /// No description provided for @profileSettingsShortcutTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get profileSettingsShortcutTitle;

  /// No description provided for @profileSettingsShortcutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage language, theme and account sections.'**
  String get profileSettingsShortcutSubtitle;

  /// No description provided for @profileSettingsCompactSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Language, theme and account settings.'**
  String get profileSettingsCompactSubtitle;

  /// No description provided for @profilePreferenceEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get profilePreferenceEnabled;

  /// No description provided for @profilePreferenceOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get profilePreferenceOff;

  /// No description provided for @profileSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get profileSettingsTitle;

  /// No description provided for @profileSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage the app and your account.'**
  String get profileSettingsSubtitle;

  /// No description provided for @profileSettingsAccountSection.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get profileSettingsAccountSection;

  /// No description provided for @profileSettingsNotificationsSection.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get profileSettingsNotificationsSection;

  /// No description provided for @profileSettingsPreferencesSection.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get profileSettingsPreferencesSection;

  /// No description provided for @profileSettingsSupportSection.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get profileSettingsSupportSection;

  /// No description provided for @profileSettingsAboutSection.
  ///
  /// In en, this message translates to:
  /// **'About app'**
  String get profileSettingsAboutSection;

  /// No description provided for @profileSettingsDangerSection.
  ///
  /// In en, this message translates to:
  /// **'Danger zone'**
  String get profileSettingsDangerSection;

  /// No description provided for @profileSettingsAccountInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Account information'**
  String get profileSettingsAccountInfoTitle;

  /// No description provided for @profileSettingsUnavailableSubtitle.
  ///
  /// In en, this message translates to:
  /// **'This information becomes available after sign in.'**
  String get profileSettingsUnavailableSubtitle;

  /// No description provided for @profileSettingsLinkedAccountsTitle.
  ///
  /// In en, this message translates to:
  /// **'Linked accounts'**
  String get profileSettingsLinkedAccountsTitle;

  /// No description provided for @profileSettingsLinkedAccountsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Google, Apple and other providers will appear here.'**
  String get profileSettingsLinkedAccountsSubtitle;

  /// No description provided for @profileSettingsPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get profileSettingsPasswordTitle;

  /// No description provided for @profileSettingsPasswordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Update your password to keep the account secure.'**
  String get profileSettingsPasswordSubtitle;

  /// No description provided for @profileSettingsNotificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notification settings'**
  String get profileSettingsNotificationsTitle;

  /// No description provided for @profileSettingsNotificationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage push and email preferences across the app.'**
  String get profileSettingsNotificationsSubtitle;

  /// No description provided for @profileSettingsLanguageTitle.
  ///
  /// In en, this message translates to:
  /// **'App language'**
  String get profileSettingsLanguageTitle;

  /// No description provided for @profileSettingsLanguageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose the language used throughout the interface.'**
  String get profileSettingsLanguageSubtitle;

  /// No description provided for @profileSettingsThemeTitle.
  ///
  /// In en, this message translates to:
  /// **'App theme'**
  String get profileSettingsThemeTitle;

  /// No description provided for @profileSettingsThemeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Switch between system, light and dark appearance.'**
  String get profileSettingsThemeSubtitle;

  /// No description provided for @profileSettingsHelpCenterTitle.
  ///
  /// In en, this message translates to:
  /// **'Help center'**
  String get profileSettingsHelpCenterTitle;

  /// No description provided for @profileSettingsHelpCenterSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Quick answers and guides for common questions.'**
  String get profileSettingsHelpCenterSubtitle;

  /// No description provided for @profileSettingsSupportTitle.
  ///
  /// In en, this message translates to:
  /// **'Contact support'**
  String get profileSettingsSupportTitle;

  /// No description provided for @profileSettingsSupportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Reach out if you need help with billing or account access.'**
  String get profileSettingsSupportSubtitle;

  /// No description provided for @profileSettingsTermsTitle.
  ///
  /// In en, this message translates to:
  /// **'Terms of Use'**
  String get profileSettingsTermsTitle;

  /// No description provided for @profileSettingsTermsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Review the rules for using PetMagic.'**
  String get profileSettingsTermsSubtitle;

  /// No description provided for @profileSettingsPrivacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get profileSettingsPrivacyTitle;

  /// No description provided for @profileSettingsPrivacySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Learn how your data is handled and protected.'**
  String get profileSettingsPrivacySubtitle;

  /// No description provided for @profileSettingsDeleteAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get profileSettingsDeleteAccountTitle;

  /// No description provided for @profileSettingsDeleteAccountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone.'**
  String get profileSettingsDeleteAccountSubtitle;

  /// No description provided for @profileAccountDetailsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Review the account data currently available on this device.'**
  String get profileAccountDetailsSubtitle;

  /// No description provided for @profileAccountDetailsSection.
  ///
  /// In en, this message translates to:
  /// **'Account details'**
  String get profileAccountDetailsSection;

  /// No description provided for @profileAccountUserIdLabel.
  ///
  /// In en, this message translates to:
  /// **'User ID'**
  String get profileAccountUserIdLabel;

  /// No description provided for @profileAccountDisplayNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get profileAccountDisplayNameLabel;

  /// No description provided for @profileAccountDisplayNameMissing.
  ///
  /// In en, this message translates to:
  /// **'Not set yet'**
  String get profileAccountDisplayNameMissing;

  /// No description provided for @profileAccountRolesLabel.
  ///
  /// In en, this message translates to:
  /// **'Roles'**
  String get profileAccountRolesLabel;

  /// No description provided for @profileAccountRolesMissing.
  ///
  /// In en, this message translates to:
  /// **'No roles assigned'**
  String get profileAccountRolesMissing;

  /// No description provided for @profileAccountMembershipLabel.
  ///
  /// In en, this message translates to:
  /// **'Membership'**
  String get profileAccountMembershipLabel;

  /// No description provided for @profileAccountConsentLabel.
  ///
  /// In en, this message translates to:
  /// **'Terms acceptance'**
  String get profileAccountConsentLabel;

  /// No description provided for @profileAccountMarketingLabel.
  ///
  /// In en, this message translates to:
  /// **'Offers and updates'**
  String get profileAccountMarketingLabel;

  /// No description provided for @profileAccountAvatarLabel.
  ///
  /// In en, this message translates to:
  /// **'Avatar'**
  String get profileAccountAvatarLabel;

  /// No description provided for @profileAccountAvatarMissing.
  ///
  /// In en, this message translates to:
  /// **'No avatar uploaded'**
  String get profileAccountAvatarMissing;

  /// No description provided for @profileAccountAvatarUploaded.
  ///
  /// In en, this message translates to:
  /// **'Avatar uploaded'**
  String get profileAccountAvatarUploaded;

  /// No description provided for @profileDetailsCurrentStatusSection.
  ///
  /// In en, this message translates to:
  /// **'Current status'**
  String get profileDetailsCurrentStatusSection;

  /// No description provided for @profileDetailsNextStepSection.
  ///
  /// In en, this message translates to:
  /// **'What happens next'**
  String get profileDetailsNextStepSection;

  /// No description provided for @profileDetailsLinkedAccountsBody.
  ///
  /// In en, this message translates to:
  /// **'Connected providers will appear here as soon as linking is enabled for your account.'**
  String get profileDetailsLinkedAccountsBody;

  /// No description provided for @profileDetailsLinkedAccountsStatus.
  ///
  /// In en, this message translates to:
  /// **'No external providers are linked yet. Email and password remain the active sign-in method for this profile.'**
  String get profileDetailsLinkedAccountsStatus;

  /// No description provided for @profileDetailsLinkedAccountsNext.
  ///
  /// In en, this message translates to:
  /// **'Google, Apple and additional providers will be shown here after the backend linking flow is opened in the app.'**
  String get profileDetailsLinkedAccountsNext;

  /// No description provided for @profileLinkedAccountsLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading linked sign-in providers...'**
  String get profileLinkedAccountsLoading;

  /// No description provided for @profileLinkedAccountsConnectedStatus.
  ///
  /// In en, this message translates to:
  /// **'Connected and ready for sign in.'**
  String get profileLinkedAccountsConnectedStatus;

  /// No description provided for @profileLinkedAccountsNotConnectedStatus.
  ///
  /// In en, this message translates to:
  /// **'Not connected yet.'**
  String get profileLinkedAccountsNotConnectedStatus;

  /// No description provided for @profileLinkedAccountsConnectAction.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get profileLinkedAccountsConnectAction;

  /// No description provided for @profileLinkedAccountsDisconnectAction.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get profileLinkedAccountsDisconnectAction;

  /// No description provided for @profileLinkedAccountsProtectedHint.
  ///
  /// In en, this message translates to:
  /// **'This provider cannot be removed until another sign-in method remains available.'**
  String get profileLinkedAccountsProtectedHint;

  /// No description provided for @profileLinkedAccountsSignInRequired.
  ///
  /// In en, this message translates to:
  /// **'Sign in again to manage linked accounts.'**
  String get profileLinkedAccountsSignInRequired;

  /// No description provided for @profileLinkedAccountsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Linked accounts are temporarily unavailable.'**
  String get profileLinkedAccountsUnavailable;

  /// No description provided for @profileDetailsNotificationsBody.
  ///
  /// In en, this message translates to:
  /// **'This section reflects your current communication preferences in the app.'**
  String get profileDetailsNotificationsBody;

  /// No description provided for @profileDetailsNotificationsStatusEnabled.
  ///
  /// In en, this message translates to:
  /// **'Product updates and offers are enabled for this profile. Additional push controls will appear here later.'**
  String get profileDetailsNotificationsStatusEnabled;

  /// No description provided for @profileDetailsNotificationsStatusDisabled.
  ///
  /// In en, this message translates to:
  /// **'Marketing emails are currently disabled for this profile. Additional push controls will appear here later.'**
  String get profileDetailsNotificationsStatusDisabled;

  /// No description provided for @profileDetailsNotificationsNext.
  ///
  /// In en, this message translates to:
  /// **'You can already review the current email preference here. Dedicated push toggles will be added in a later product slice.'**
  String get profileDetailsNotificationsNext;

  /// No description provided for @profileDetailsHelpBody.
  ///
  /// In en, this message translates to:
  /// **'The help center will collect quick answers, setup tips and account guidance in one place.'**
  String get profileDetailsHelpBody;

  /// No description provided for @profileDetailsHelpStatus.
  ///
  /// In en, this message translates to:
  /// **'The in-app knowledge base is still being assembled, so this screen shows the current rollout status.'**
  String get profileDetailsHelpStatus;

  /// No description provided for @profileDetailsHelpNext.
  ///
  /// In en, this message translates to:
  /// **'The first help articles and troubleshooting guides will appear here as the mobile support content is published.'**
  String get profileDetailsHelpNext;

  /// No description provided for @profileDetailsSupportBody.
  ///
  /// In en, this message translates to:
  /// **'Support requests will be handled here without forcing you out of the profile area.'**
  String get profileDetailsSupportBody;

  /// No description provided for @profileDetailsSupportStatus.
  ///
  /// In en, this message translates to:
  /// **'Direct in-app contact is not wired yet. For now, keep this screen as the support entry point for the next slice.'**
  String get profileDetailsSupportStatus;

  /// No description provided for @profileDetailsSupportNext.
  ///
  /// In en, this message translates to:
  /// **'The next step is a real support form or email handoff connected to the backend support flow.'**
  String get profileDetailsSupportNext;

  /// No description provided for @profileDetailsTermsBody.
  ///
  /// In en, this message translates to:
  /// **'Review how PetMagic expects the app and account to be used.'**
  String get profileDetailsTermsBody;

  /// No description provided for @profileDetailsTermsStatusAccepted.
  ///
  /// In en, this message translates to:
  /// **'This account has already accepted the Terms of Use during registration.'**
  String get profileDetailsTermsStatusAccepted;

  /// No description provided for @profileDetailsTermsStatusPending.
  ///
  /// In en, this message translates to:
  /// **'This account has not recorded a completed terms acceptance yet.'**
  String get profileDetailsTermsStatusPending;

  /// No description provided for @profileDetailsTermsNext.
  ///
  /// In en, this message translates to:
  /// **'A fuller legal document view can be attached here later. For now, this screen confirms the current acceptance state.'**
  String get profileDetailsTermsNext;

  /// No description provided for @profileDetailsPrivacyBody.
  ///
  /// In en, this message translates to:
  /// **'Review how PetMagic stores, protects and uses account data.'**
  String get profileDetailsPrivacyBody;

  /// No description provided for @profileDetailsPrivacyStatus.
  ///
  /// In en, this message translates to:
  /// **'Privacy details are currently represented as an in-app summary screen while the full legal document flow is prepared.'**
  String get profileDetailsPrivacyStatus;

  /// No description provided for @profileDetailsPrivacyNext.
  ///
  /// In en, this message translates to:
  /// **'The next slice can attach a complete policy document or hosted legal page to this route.'**
  String get profileDetailsPrivacyNext;

  /// No description provided for @profileLegalAcceptanceCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current legal documents are accepted for this account.'**
  String get profileLegalAcceptanceCurrent;

  /// No description provided for @profileLegalAcceptanceRequired.
  ///
  /// In en, this message translates to:
  /// **'This account needs to accept the current legal document versions.'**
  String get profileLegalAcceptanceRequired;

  /// No description provided for @profileLegalVersionLabel.
  ///
  /// In en, this message translates to:
  /// **'Current version'**
  String get profileLegalVersionLabel;

  /// No description provided for @profileLegalPublishedLabel.
  ///
  /// In en, this message translates to:
  /// **'Published'**
  String get profileLegalPublishedLabel;

  /// No description provided for @profileLegalAcceptedVersionLabel.
  ///
  /// In en, this message translates to:
  /// **'Accepted version'**
  String get profileLegalAcceptedVersionLabel;

  /// No description provided for @profileLegalAcceptedAtLabel.
  ///
  /// In en, this message translates to:
  /// **'Accepted at'**
  String get profileLegalAcceptedAtLabel;

  /// No description provided for @profileLegalLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading the current legal document from the backend...'**
  String get profileLegalLoading;

  /// No description provided for @profileLegalUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The current legal document could not be loaded right now.'**
  String get profileLegalUnavailable;

  /// No description provided for @profileLegalAcceptAction.
  ///
  /// In en, this message translates to:
  /// **'Accept current legal documents'**
  String get profileLegalAcceptAction;

  /// No description provided for @profileLegalAcceptanceGuestHint.
  ///
  /// In en, this message translates to:
  /// **'You will accept the current Terms of Use and Privacy Policy during sign up.'**
  String get profileLegalAcceptanceGuestHint;

  /// No description provided for @profileLegalDocumentSection.
  ///
  /// In en, this message translates to:
  /// **'Document'**
  String get profileLegalDocumentSection;

  /// No description provided for @profileLegalCompactHint.
  ///
  /// In en, this message translates to:
  /// **'The summary stays visible, and each section expands only when you need more detail.'**
  String get profileLegalCompactHint;

  /// No description provided for @profileLegalCurrentAcceptedHint.
  ///
  /// In en, this message translates to:
  /// **'No additional confirmation is required for this account right now.'**
  String get profileLegalCurrentAcceptedHint;

  /// No description provided for @profileLegalCompactSectionLabel.
  ///
  /// In en, this message translates to:
  /// **'Tap to expand'**
  String get profileLegalCompactSectionLabel;

  /// No description provided for @profileDetailsDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Account deletion is intentionally protected and not executed from this screen yet.'**
  String get profileDetailsDeleteBody;

  /// No description provided for @profileDetailsDeleteStatus.
  ///
  /// In en, this message translates to:
  /// **'Deletion is not available as a one-tap action in the mobile app right now. This avoids destructive behavior before the backend confirmation flow is ready.'**
  String get profileDetailsDeleteStatus;

  /// No description provided for @profileDetailsDeleteNext.
  ///
  /// In en, this message translates to:
  /// **'When the backend deletion workflow is implemented, this screen can become the confirmation and verification step instead of a placeholder.'**
  String get profileDetailsDeleteNext;

  /// No description provided for @supportChatTitle.
  ///
  /// In en, this message translates to:
  /// **'Support chat'**
  String get supportChatTitle;

  /// No description provided for @supportChatSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Message the PetMagic team directly from your profile.'**
  String get supportChatSubtitle;

  /// No description provided for @supportChatSecureTitle.
  ///
  /// In en, this message translates to:
  /// **'Your conversation is secure'**
  String get supportChatSecureTitle;

  /// No description provided for @supportChatSecureSubtitle.
  ///
  /// In en, this message translates to:
  /// **'We protect your data and keep your information private.'**
  String get supportChatSecureSubtitle;

  /// No description provided for @supportChatTeamTitle.
  ///
  /// In en, this message translates to:
  /// **'PetMagic Support'**
  String get supportChatTeamTitle;

  /// No description provided for @supportChatTeamStatus.
  ///
  /// In en, this message translates to:
  /// **'Online • typical reply under 5 min'**
  String get supportChatTeamStatus;

  /// No description provided for @supportChatTodayLabel.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get supportChatTodayLabel;

  /// No description provided for @supportChatInputHint.
  ///
  /// In en, this message translates to:
  /// **'Describe the issue, question or request...'**
  String get supportChatInputHint;

  /// No description provided for @supportChatSendAction.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get supportChatSendAction;

  /// No description provided for @supportChatEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Start the conversation'**
  String get supportChatEmptyTitle;

  /// No description provided for @supportChatEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Your support chat is ready. Send the first message and the team will respond here.'**
  String get supportChatEmptyMessage;

  /// No description provided for @supportChatWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to PetMagic support'**
  String get supportChatWelcomeTitle;

  /// No description provided for @supportChatWelcomeBody.
  ///
  /// In en, this message translates to:
  /// **'Choose a common topic below or write your message right away. We will route it to the right team without making the chat feel empty.'**
  String get supportChatWelcomeBody;

  /// No description provided for @supportChatQuickActionGeneration.
  ///
  /// In en, this message translates to:
  /// **'Issue with image generation'**
  String get supportChatQuickActionGeneration;

  /// No description provided for @supportChatQuickActionPayment.
  ///
  /// In en, this message translates to:
  /// **'Payment problem'**
  String get supportChatQuickActionPayment;

  /// No description provided for @supportChatQuickActionRefund.
  ///
  /// In en, this message translates to:
  /// **'Refund request'**
  String get supportChatQuickActionRefund;

  /// No description provided for @supportChatQuickActionHuman.
  ///
  /// In en, this message translates to:
  /// **'Talk to an operator'**
  String get supportChatQuickActionHuman;

  /// No description provided for @supportChatFaqTitle.
  ///
  /// In en, this message translates to:
  /// **'FAQ'**
  String get supportChatFaqTitle;

  /// No description provided for @supportChatFaqGenerationTitle.
  ///
  /// In en, this message translates to:
  /// **'Why did my generation fail?'**
  String get supportChatFaqGenerationTitle;

  /// No description provided for @supportChatFaqGenerationBody.
  ///
  /// In en, this message translates to:
  /// **'Send the template name, your pet type and a screenshot if possible. This usually gives support enough context on the first reply.'**
  String get supportChatFaqGenerationBody;

  /// No description provided for @supportChatFaqResponseTitle.
  ///
  /// In en, this message translates to:
  /// **'When will support reply?'**
  String get supportChatFaqResponseTitle;

  /// No description provided for @supportChatFaqResponseBody.
  ///
  /// In en, this message translates to:
  /// **'Active chats are normally answered within a few minutes during support hours. We keep the thread here so you do not lose context.'**
  String get supportChatFaqResponseBody;

  /// No description provided for @supportChatFaqRefundTitle.
  ///
  /// In en, this message translates to:
  /// **'How do refunds work?'**
  String get supportChatFaqRefundTitle;

  /// No description provided for @supportChatFaqRefundBody.
  ///
  /// In en, this message translates to:
  /// **'Share the order date and the reason for the request. Billing cases are reviewed in the same chat without switching channels.'**
  String get supportChatFaqRefundBody;

  /// No description provided for @supportChatStatusOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get supportChatStatusOpen;

  /// No description provided for @supportChatStatusInProgress.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get supportChatStatusInProgress;

  /// No description provided for @supportChatStatusResolved.
  ///
  /// In en, this message translates to:
  /// **'Resolved'**
  String get supportChatStatusResolved;

  /// No description provided for @supportChatStatusClosed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get supportChatStatusClosed;

  /// No description provided for @supportChatMessageDelivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get supportChatMessageDelivered;

  /// No description provided for @supportChatMessageRead.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get supportChatMessageRead;

  /// No description provided for @supportChatUnavailableError.
  ///
  /// In en, this message translates to:
  /// **'Unable to reach support right now. Please try again in a moment.'**
  String get supportChatUnavailableError;

  /// No description provided for @supportChatAttachmentUnavailableError.
  ///
  /// In en, this message translates to:
  /// **'Unable to send the attachment right now. Please try again in a moment.'**
  String get supportChatAttachmentUnavailableError;

  /// No description provided for @profileSettingsThemeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get profileSettingsThemeSystem;

  /// No description provided for @profileSettingsThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get profileSettingsThemeLight;

  /// No description provided for @profileSettingsThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get profileSettingsThemeDark;

  /// No description provided for @profileSettingsLanguageRussian.
  ///
  /// In en, this message translates to:
  /// **'Russian'**
  String get profileSettingsLanguageRussian;

  /// No description provided for @profileSettingsLanguageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get profileSettingsLanguageEnglish;

  /// No description provided for @profileSettingsLanguageGerman.
  ///
  /// In en, this message translates to:
  /// **'German'**
  String get profileSettingsLanguageGerman;

  /// No description provided for @profileSettingsLanguageSpanish.
  ///
  /// In en, this message translates to:
  /// **'Spanish'**
  String get profileSettingsLanguageSpanish;

  /// No description provided for @profileSettingsLanguageFrench.
  ///
  /// In en, this message translates to:
  /// **'French'**
  String get profileSettingsLanguageFrench;

  /// No description provided for @profileSettingsLanguageItalian.
  ///
  /// In en, this message translates to:
  /// **'Italian'**
  String get profileSettingsLanguageItalian;

  /// No description provided for @profileSettingsLanguagePolish.
  ///
  /// In en, this message translates to:
  /// **'Polish'**
  String get profileSettingsLanguagePolish;

  /// No description provided for @profileSettingsVersionLabel.
  ///
  /// In en, this message translates to:
  /// **'App version {version}'**
  String profileSettingsVersionLabel(Object version);

  /// No description provided for @magicLoadingPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing the magic...'**
  String get magicLoadingPreparing;

  /// No description provided for @magicLoadingCutestAngle.
  ///
  /// In en, this message translates to:
  /// **'Finding the cutest angle...'**
  String get magicLoadingCutestAngle;

  /// No description provided for @magicLoadingAiPaws.
  ///
  /// In en, this message translates to:
  /// **'Warming up AI paws...'**
  String get magicLoadingAiPaws;

  /// No description provided for @magicLoadingCreatingAdorable.
  ///
  /// In en, this message translates to:
  /// **'Creating something adorable...'**
  String get magicLoadingCreatingAdorable;

  /// No description provided for @magicLoadingAlmostReady.
  ///
  /// In en, this message translates to:
  /// **'Almost ready...'**
  String get magicLoadingAlmostReady;

  /// No description provided for @videoLabel.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get videoLabel;

  /// No description provided for @imageLabel.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get imageLabel;

  /// No description provided for @templatesErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Templates did not load'**
  String get templatesErrorTitle;

  /// No description provided for @retryAction.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retryAction;

  /// No description provided for @emptyTemplatesTitle.
  ///
  /// In en, this message translates to:
  /// **'No templates yet'**
  String get emptyTemplatesTitle;

  /// No description provided for @emptyTemplatesMessage.
  ///
  /// In en, this message translates to:
  /// **'Try another filter or refresh the catalog.'**
  String get emptyTemplatesMessage;

  /// No description provided for @templatesFeedEmptyError.
  ///
  /// In en, this message translates to:
  /// **'Templates are temporarily unavailable.'**
  String get templatesFeedEmptyError;

  /// No description provided for @templatesConnectionTimeoutError.
  ///
  /// In en, this message translates to:
  /// **'No connection. Check your network and try again.'**
  String get templatesConnectionTimeoutError;

  /// No description provided for @templatesServerTimeoutError.
  ///
  /// In en, this message translates to:
  /// **'The server took too long to respond. Please try again.'**
  String get templatesServerTimeoutError;

  /// No description provided for @templatesRequestFailedError.
  ///
  /// In en, this message translates to:
  /// **'Could not load templates right now. Please try again.'**
  String get templatesRequestFailedError;

  /// No description provided for @startupOnboardingActionContinueGuest.
  ///
  /// In en, this message translates to:
  /// **'Continue as guest'**
  String get startupOnboardingActionContinueGuest;

  /// No description provided for @startupOnboardingActionNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get startupOnboardingActionNext;

  /// No description provided for @startupOnboardingActionStart.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get startupOnboardingActionStart;

  /// No description provided for @startupOnboardingPageOneTitle.
  ///
  /// In en, this message translates to:
  /// **'Create magic moments with your pet'**
  String get startupOnboardingPageOneTitle;

  /// No description provided for @startupOnboardingPageOneSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Turn everyday clips into playful viral-ready stories with bright, pet-first templates.'**
  String get startupOnboardingPageOneSubtitle;

  /// No description provided for @startupOnboardingPageOneHighlightOne.
  ///
  /// In en, this message translates to:
  /// **'Trendy templates'**
  String get startupOnboardingPageOneHighlightOne;

  /// No description provided for @startupOnboardingPageOneHighlightTwo.
  ///
  /// In en, this message translates to:
  /// **'Fast edits'**
  String get startupOnboardingPageOneHighlightTwo;

  /// No description provided for @startupOnboardingPageOneHighlightThree.
  ///
  /// In en, this message translates to:
  /// **'Pet-safe vibe'**
  String get startupOnboardingPageOneHighlightThree;

  /// No description provided for @startupOnboardingPageTwoTitle.
  ///
  /// In en, this message translates to:
  /// **'Browse first, unlock when you are ready'**
  String get startupOnboardingPageTwoTitle;

  /// No description provided for @startupOnboardingPageTwoSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Explore the feed as a guest, then sign in when you want to render, save or go premium.'**
  String get startupOnboardingPageTwoSubtitle;

  /// No description provided for @startupOnboardingPageTwoHighlightOne.
  ///
  /// In en, this message translates to:
  /// **'Guest browsing'**
  String get startupOnboardingPageTwoHighlightOne;

  /// No description provided for @startupOnboardingPageTwoHighlightTwo.
  ///
  /// In en, this message translates to:
  /// **'One-tap sign in'**
  String get startupOnboardingPageTwoHighlightTwo;

  /// No description provided for @startupOnboardingPageTwoHighlightThree.
  ///
  /// In en, this message translates to:
  /// **'Smooth handoff'**
  String get startupOnboardingPageTwoHighlightThree;

  /// No description provided for @startupOnboardingPageThreeTitle.
  ///
  /// In en, this message translates to:
  /// **'Collect tokens and premium perks later'**
  String get startupOnboardingPageThreeTitle;

  /// No description provided for @startupOnboardingPageThreeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Keep the first impression fun. Tokens, rewards and premium actions wait behind a clean auth step.'**
  String get startupOnboardingPageThreeSubtitle;

  /// No description provided for @startupOnboardingPageThreeHighlightOne.
  ///
  /// In en, this message translates to:
  /// **'Premium unlocks'**
  String get startupOnboardingPageThreeHighlightOne;

  /// No description provided for @startupOnboardingPageThreeHighlightTwo.
  ///
  /// In en, this message translates to:
  /// **'Token balance'**
  String get startupOnboardingPageThreeHighlightTwo;

  /// No description provided for @startupOnboardingPageThreeHighlightThree.
  ///
  /// In en, this message translates to:
  /// **'Creator perks'**
  String get startupOnboardingPageThreeHighlightThree;

  /// No description provided for @startupMiniFeatureFastStart.
  ///
  /// In en, this message translates to:
  /// **'Fast start'**
  String get startupMiniFeatureFastStart;

  /// No description provided for @startupMiniFeaturePetFirst.
  ///
  /// In en, this message translates to:
  /// **'Pet-first'**
  String get startupMiniFeaturePetFirst;

  /// No description provided for @startupMiniFeatureUpgradeLater.
  ///
  /// In en, this message translates to:
  /// **'Upgrade later'**
  String get startupMiniFeatureUpgradeLater;

  /// No description provided for @startupWelcomeViewOnboarding.
  ///
  /// In en, this message translates to:
  /// **'View onboarding'**
  String get startupWelcomeViewOnboarding;

  /// No description provided for @startupWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome back to PetMagic'**
  String get startupWelcomeTitle;

  /// No description provided for @startupWelcomeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Keep exploring as a guest or sign in before you render templates, unlock rewards and save your creations.'**
  String get startupWelcomeSubtitle;

  /// No description provided for @startupWelcomeContinueGuest.
  ///
  /// In en, this message translates to:
  /// **'Continue as guest'**
  String get startupWelcomeContinueGuest;

  /// No description provided for @startupWelcomeTemplatesTitle.
  ///
  /// In en, this message translates to:
  /// **'Viral Templates'**
  String get startupWelcomeTemplatesTitle;

  /// No description provided for @startupWelcomeTemplatesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Preview the full feed'**
  String get startupWelcomeTemplatesSubtitle;

  /// No description provided for @startupWelcomeAiTitle.
  ///
  /// In en, this message translates to:
  /// **'AI Magic'**
  String get startupWelcomeAiTitle;

  /// No description provided for @startupWelcomeAiSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Unlock on sign in'**
  String get startupWelcomeAiSubtitle;

  /// No description provided for @startupWelcomeShareTitle.
  ///
  /// In en, this message translates to:
  /// **'Share & Enjoy'**
  String get startupWelcomeShareTitle;

  /// No description provided for @startupWelcomeShareSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Save your favorites later'**
  String get startupWelcomeShareSubtitle;

  /// No description provided for @authEntryTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome back!'**
  String get authEntryTitle;

  /// No description provided for @authEntrySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue your pet magic.'**
  String get authEntrySubtitle;

  /// No description provided for @authRegisterTitle.
  ///
  /// In en, this message translates to:
  /// **'Create your account'**
  String get authRegisterTitle;

  /// No description provided for @authRegisterSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Join PetMagic and unlock templates, tokens and premium features.'**
  String get authRegisterSubtitle;

  /// No description provided for @authRegisterAction.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get authRegisterAction;

  /// No description provided for @authDisplayNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Display name (optional)'**
  String get authDisplayNameLabel;

  /// No description provided for @authConfirmPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get authConfirmPasswordLabel;

  /// No description provided for @authPasswordRulesHint.
  ///
  /// In en, this message translates to:
  /// **'Use at least 6 characters.'**
  String get authPasswordRulesHint;

  /// No description provided for @authPasswordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters long.'**
  String get authPasswordTooShort;

  /// No description provided for @authForgotPasswordAction.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get authForgotPasswordAction;

  /// No description provided for @authForgotPasswordComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Password recovery is coming soon.'**
  String get authForgotPasswordComingSoon;

  /// No description provided for @authPasswordResetTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset your password'**
  String get authPasswordResetTitle;

  /// No description provided for @authPasswordResetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your email and we will send you a reset code.'**
  String get authPasswordResetSubtitle;

  /// No description provided for @authPasswordResetCodeTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter the code from your email'**
  String get authPasswordResetCodeTitle;

  /// No description provided for @authPasswordResetCodeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use the code to set a new password for your account.'**
  String get authPasswordResetCodeSubtitle;

  /// No description provided for @authPasswordResetCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Reset code'**
  String get authPasswordResetCodeLabel;

  /// No description provided for @authPasswordResetRequestAction.
  ///
  /// In en, this message translates to:
  /// **'Send code'**
  String get authPasswordResetRequestAction;

  /// No description provided for @authPasswordResetConfirmAction.
  ///
  /// In en, this message translates to:
  /// **'Save new password'**
  String get authPasswordResetConfirmAction;

  /// No description provided for @authPasswordResetResendAction.
  ///
  /// In en, this message translates to:
  /// **'Send code again'**
  String get authPasswordResetResendAction;

  /// No description provided for @authPasswordResetCodeSent.
  ///
  /// In en, this message translates to:
  /// **'We sent a password reset code to your email.'**
  String get authPasswordResetCodeSent;

  /// No description provided for @authPasswordResetSuccess.
  ///
  /// In en, this message translates to:
  /// **'Password updated. You can now sign in with the new password.'**
  String get authPasswordResetSuccess;

  /// No description provided for @authPasswordResetCodeInvalid.
  ///
  /// In en, this message translates to:
  /// **'This reset code is invalid or has expired.'**
  String get authPasswordResetCodeInvalid;

  /// No description provided for @authOrContinueWith.
  ///
  /// In en, this message translates to:
  /// **'or continue with'**
  String get authOrContinueWith;

  /// No description provided for @authAcceptTermsLabel.
  ///
  /// In en, this message translates to:
  /// **'I agree to the Terms of Use and Privacy Policy'**
  String get authAcceptTermsLabel;

  /// No description provided for @authReceiveUpdatesLabel.
  ///
  /// In en, this message translates to:
  /// **'I want to receive updates and offers from PetMagic'**
  String get authReceiveUpdatesLabel;

  /// No description provided for @authAcceptTermsRequired.
  ///
  /// In en, this message translates to:
  /// **'You need to accept the Terms of Use and Privacy Policy to create an account.'**
  String get authAcceptTermsRequired;

  /// No description provided for @authReviewTermsAction.
  ///
  /// In en, this message translates to:
  /// **'Review Terms'**
  String get authReviewTermsAction;

  /// No description provided for @authReviewPrivacyAction.
  ///
  /// In en, this message translates to:
  /// **'Review Privacy'**
  String get authReviewPrivacyAction;

  /// No description provided for @authLegalLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading the current Terms and Privacy documents...'**
  String get authLegalLoading;

  /// No description provided for @authLegalReady.
  ///
  /// In en, this message translates to:
  /// **'Current legal documents are ready to review and accept.'**
  String get authLegalReady;

  /// No description provided for @authLegalUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Current legal documents are temporarily unavailable. Try again in a moment.'**
  String get authLegalUnavailable;

  /// No description provided for @authGoogleShortLabel.
  ///
  /// In en, this message translates to:
  /// **'Google'**
  String get authGoogleShortLabel;

  /// No description provided for @authAppleShortLabel.
  ///
  /// In en, this message translates to:
  /// **'Apple'**
  String get authAppleShortLabel;

  /// No description provided for @authContinueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get authContinueWithGoogle;

  /// No description provided for @authContinueWithApple.
  ///
  /// In en, this message translates to:
  /// **'Continue with Apple'**
  String get authContinueWithApple;

  /// No description provided for @authNoAccountPrompt.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get authNoAccountPrompt;

  /// No description provided for @authHaveAccountPrompt.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get authHaveAccountPrompt;

  /// No description provided for @authSignUpAction.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get authSignUpAction;

  /// No description provided for @authSocialComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Social sign-in is coming soon.'**
  String get authSocialComingSoon;

  /// No description provided for @authPasswordMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match.'**
  String get authPasswordMismatch;

  /// No description provided for @authExternalCancelled.
  ///
  /// In en, this message translates to:
  /// **'Sign-in was cancelled.'**
  String get authExternalCancelled;

  /// No description provided for @authExternalFailed.
  ///
  /// In en, this message translates to:
  /// **'External sign-in failed. Please try again.'**
  String get authExternalFailed;

  /// No description provided for @authExternalTimedOut.
  ///
  /// In en, this message translates to:
  /// **'Sign-in took too long. Please try again.'**
  String get authExternalTimedOut;

  /// No description provided for @authExternalLaunchFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the sign-in page.'**
  String get authExternalLaunchFailed;

  /// No description provided for @authExternalCallbackFailed.
  ///
  /// In en, this message translates to:
  /// **'We could not finish sign-in in the app.'**
  String get authExternalCallbackFailed;

  /// No description provided for @authExternalSessionExpired.
  ///
  /// In en, this message translates to:
  /// **'This sign-in session expired. Please try again.'**
  String get authExternalSessionExpired;

  /// No description provided for @authSignInRequired.
  ///
  /// In en, this message translates to:
  /// **'Sign in is required.'**
  String get authSignInRequired;

  /// No description provided for @authSessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Session expired.'**
  String get authSessionExpired;

  /// No description provided for @authLoginFailed.
  ///
  /// In en, this message translates to:
  /// **'Login failed. Please try again.'**
  String get authLoginFailed;

  /// No description provided for @authRegistrationFailed.
  ///
  /// In en, this message translates to:
  /// **'Registration failed. Please try again.'**
  String get authRegistrationFailed;

  /// No description provided for @authPasswordResetRequestFailed.
  ///
  /// In en, this message translates to:
  /// **'Password reset request failed. Please try again.'**
  String get authPasswordResetRequestFailed;

  /// No description provided for @authPasswordResetFailed.
  ///
  /// In en, this message translates to:
  /// **'Password reset failed. Please try again.'**
  String get authPasswordResetFailed;

  /// No description provided for @authRequestFailed.
  ///
  /// In en, this message translates to:
  /// **'Request failed. Please try again.'**
  String get authRequestFailed;

  /// No description provided for @profileActionFailed.
  ///
  /// In en, this message translates to:
  /// **'We could not complete this action. Please try again.'**
  String get profileActionFailed;

  /// No description provided for @authSecurePrivateTitle.
  ///
  /// In en, this message translates to:
  /// **'Secure & Private'**
  String get authSecurePrivateTitle;

  /// No description provided for @authSecurePrivateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your data stays protected.'**
  String get authSecurePrivateSubtitle;

  /// No description provided for @authFastEasyTitle.
  ///
  /// In en, this message translates to:
  /// **'Fast & Easy'**
  String get authFastEasyTitle;

  /// No description provided for @authFastEasySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Start creating in just a few taps.'**
  String get authFastEasySubtitle;

  /// No description provided for @authLovedByPetsTitle.
  ///
  /// In en, this message translates to:
  /// **'Loved by Pets'**
  String get authLovedByPetsTitle;

  /// No description provided for @authLovedByPetsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Built for happy pet parents.'**
  String get authLovedByPetsSubtitle;

  /// No description provided for @authPrivacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Your privacy matters'**
  String get authPrivacyTitle;

  /// No description provided for @authPrivacySubtitle.
  ///
  /// In en, this message translates to:
  /// **'We never sell or share your data with third parties.'**
  String get authPrivacySubtitle;

  /// No description provided for @authRequiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to unlock this action'**
  String get authRequiredTitle;

  /// No description provided for @authRequiredMessage.
  ///
  /// In en, this message translates to:
  /// **'Guests can explore the app, but template actions, rewards and token features require a PetMagic account.'**
  String get authRequiredMessage;

  /// No description provided for @authRequiredContinueBrowsing.
  ///
  /// In en, this message translates to:
  /// **'Continue browsing'**
  String get authRequiredContinueBrowsing;

  /// No description provided for @templateTryAction.
  ///
  /// In en, this message translates to:
  /// **'Try template'**
  String get templateTryAction;

  /// No description provided for @templateGuestPreview.
  ///
  /// In en, this message translates to:
  /// **'Guest preview'**
  String get templateGuestPreview;

  /// No description provided for @templateActionComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Template studio is coming soon.'**
  String get templateActionComingSoon;

  /// No description provided for @tokensActionComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Token wallet is coming soon.'**
  String get tokensActionComingSoon;

  /// No description provided for @rewardsActionComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Rewards center is coming soon.'**
  String get rewardsActionComingSoon;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'de',
    'en',
    'es',
    'fr',
    'it',
    'pl',
    'ru',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'it':
      return AppLocalizationsIt();
    case 'pl':
      return AppLocalizationsPl();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
