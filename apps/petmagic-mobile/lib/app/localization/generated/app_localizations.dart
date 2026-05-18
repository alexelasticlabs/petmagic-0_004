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
