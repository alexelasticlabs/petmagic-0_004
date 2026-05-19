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
    Locale('en', 'US'),
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
  /// **'Creations'**
  String get navCreations;

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

  /// No description provided for @profileSignedOut.
  ///
  /// In en, this message translates to:
  /// **'Signed out on this device.'**
  String get profileSignedOut;

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
  /// **'Use 10+ characters with uppercase, lowercase and a number.'**
  String get authPasswordRulesHint;

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

  /// No description provided for @authOrContinueWith.
  ///
  /// In en, this message translates to:
  /// **'or continue with'**
  String get authOrContinueWith;

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
  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'en':
      {
        switch (locale.countryCode) {
          case 'US':
            return AppLocalizationsEnUs();
        }
        break;
      }
  }

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
