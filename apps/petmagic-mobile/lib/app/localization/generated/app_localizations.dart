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

  /// No description provided for @profileSettingsLanguageEnglishUs.
  ///
  /// In en, this message translates to:
  /// **'English (US)'**
  String get profileSettingsLanguageEnglishUs;

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
