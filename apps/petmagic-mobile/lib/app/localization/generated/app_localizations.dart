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

  /// No description provided for @navDiscover.
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get navDiscover;

  /// No description provided for @navCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get navCreate;

  /// No description provided for @createHubTitle.
  ///
  /// In en, this message translates to:
  /// **'Create pet magic'**
  String get createHubTitle;

  /// No description provided for @createHubSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Start with a template or your pet. We will guide you through the rest.'**
  String get createHubSubtitle;

  /// No description provided for @createHubBrowseAction.
  ///
  /// In en, this message translates to:
  /// **'Browse templates'**
  String get createHubBrowseAction;

  /// No description provided for @createHubPetsAction.
  ///
  /// In en, this message translates to:
  /// **'Choose my pet'**
  String get createHubPetsAction;

  /// No description provided for @createHubGuestHint.
  ///
  /// In en, this message translates to:
  /// **'You can explore first. Your creation intent is preserved when sign-in is required.'**
  String get createHubGuestHint;

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

  /// No description provided for @notificationOpenAction.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get notificationOpenAction;

  /// No description provided for @notificationDefaultTitle.
  ///
  /// In en, this message translates to:
  /// **'PetMagic update'**
  String get notificationDefaultTitle;

  /// No description provided for @notificationSupportTitle.
  ///
  /// In en, this message translates to:
  /// **'PetMagic Support replied'**
  String get notificationSupportTitle;

  /// No description provided for @notificationGenerationTitle.
  ///
  /// In en, this message translates to:
  /// **'PetMagic generation update'**
  String get notificationGenerationTitle;

  /// No description provided for @notificationWalletTitle.
  ///
  /// In en, this message translates to:
  /// **'PetMagic wallet update'**
  String get notificationWalletTitle;

  /// No description provided for @notificationPremiumTitle.
  ///
  /// In en, this message translates to:
  /// **'PetMagic premium update'**
  String get notificationPremiumTitle;

  /// No description provided for @notificationSupportBody.
  ///
  /// In en, this message translates to:
  /// **'Open support chat to see the latest response.'**
  String get notificationSupportBody;

  /// No description provided for @notificationGenerationBody.
  ///
  /// In en, this message translates to:
  /// **'Your generation status has changed.'**
  String get notificationGenerationBody;

  /// No description provided for @notificationWalletBody.
  ///
  /// In en, this message translates to:
  /// **'Open your wallet to review the latest balance update.'**
  String get notificationWalletBody;

  /// No description provided for @notificationPremiumBody.
  ///
  /// In en, this message translates to:
  /// **'Open your profile to review the latest Premium update.'**
  String get notificationPremiumBody;

  /// No description provided for @appUnexpectedErrorFallback.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get appUnexpectedErrorFallback;

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

  /// No description provided for @randomTemplateAction.
  ///
  /// In en, this message translates to:
  /// **'Random template'**
  String get randomTemplateAction;

  /// No description provided for @randomTemplateAny.
  ///
  /// In en, this message translates to:
  /// **'Any template'**
  String get randomTemplateAny;

  /// No description provided for @randomTemplateImage.
  ///
  /// In en, this message translates to:
  /// **'Image template'**
  String get randomTemplateImage;

  /// No description provided for @randomTemplateVideo.
  ///
  /// In en, this message translates to:
  /// **'Video template'**
  String get randomTemplateVideo;

  /// No description provided for @randomTemplateNoTemplates.
  ///
  /// In en, this message translates to:
  /// **'No templates available.'**
  String get randomTemplateNoTemplates;

  /// No description provided for @randomTemplateNoAvailableForType.
  ///
  /// In en, this message translates to:
  /// **'No available templates for this type.'**
  String get randomTemplateNoAvailableForType;

  /// No description provided for @randomTemplateNoImageTemplates.
  ///
  /// In en, this message translates to:
  /// **'No image templates available.'**
  String get randomTemplateNoImageTemplates;

  /// No description provided for @randomTemplateNoVideoTemplates.
  ///
  /// In en, this message translates to:
  /// **'No video templates available.'**
  String get randomTemplateNoVideoTemplates;

  /// No description provided for @randomTemplateLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load templates. Please try again.'**
  String get randomTemplateLoadFailed;

  /// No description provided for @randomTemplateSheetDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose which templates to search for a random pick.'**
  String get randomTemplateSheetDescription;

  /// No description provided for @randomTemplateTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Template type'**
  String get randomTemplateTypeLabel;

  /// No description provided for @randomTemplateCategoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get randomTemplateCategoryLabel;

  /// No description provided for @randomTemplateAccessLabel.
  ///
  /// In en, this message translates to:
  /// **'Availability'**
  String get randomTemplateAccessLabel;

  /// No description provided for @randomTemplateAccessAvailable.
  ///
  /// In en, this message translates to:
  /// **'All available'**
  String get randomTemplateAccessAvailable;

  /// No description provided for @randomTemplateAccessFree.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get randomTemplateAccessFree;

  /// No description provided for @randomTemplateAccessPremium.
  ///
  /// In en, this message translates to:
  /// **'Premium'**
  String get randomTemplateAccessPremium;

  /// No description provided for @randomTemplateFindAction.
  ///
  /// In en, this message translates to:
  /// **'Find random template'**
  String get randomTemplateFindAction;

  /// No description provided for @randomTemplateFinding.
  ///
  /// In en, this message translates to:
  /// **'Finding a random template...'**
  String get randomTemplateFinding;

  /// No description provided for @randomTemplateNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No templates match these settings.'**
  String get randomTemplateNoMatches;

  /// No description provided for @randomTemplateNoMatchesHint.
  ///
  /// In en, this message translates to:
  /// **'Try choosing All or another category.'**
  String get randomTemplateNoMatchesHint;

  /// No description provided for @randomTemplateResetFilters.
  ///
  /// In en, this message translates to:
  /// **'Reset settings'**
  String get randomTemplateResetFilters;

  /// No description provided for @templateOfTheDayTitle.
  ///
  /// In en, this message translates to:
  /// **'Template of the Day'**
  String get templateOfTheDayTitle;

  /// No description provided for @templateOfTheDaySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Today\'s magic idea'**
  String get templateOfTheDaySubtitle;

  /// No description provided for @templateOfTheDayTryAction.
  ///
  /// In en, this message translates to:
  /// **'Try this template'**
  String get templateOfTheDayTryAction;

  /// No description provided for @templateOfTheDayFeedBadge.
  ///
  /// In en, this message translates to:
  /// **'Today\'s pick'**
  String get templateOfTheDayFeedBadge;

  /// No description provided for @templateOfTheDayLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load Template of the Day.'**
  String get templateOfTheDayLoadFailed;

  /// No description provided for @allFilter.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get allFilter;

  /// No description provided for @templateFormatFilterLabel.
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get templateFormatFilterLabel;

  /// No description provided for @templateCategoryFilterLabel.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get templateCategoryFilterLabel;

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

  /// No description provided for @authShowPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get authShowPassword;

  /// No description provided for @authHidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get authHidePassword;

  /// No description provided for @authShowPasswordConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Show password confirmation'**
  String get authShowPasswordConfirmation;

  /// No description provided for @authHidePasswordConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Hide password confirmation'**
  String get authHidePasswordConfirmation;

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

  /// No description provided for @profileAvatarSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile photo'**
  String get profileAvatarSheetTitle;

  /// No description provided for @profileAvatarPickFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Pick from gallery'**
  String get profileAvatarPickFromGallery;

  /// No description provided for @profileAvatarTapToChange.
  ///
  /// In en, this message translates to:
  /// **'Tap to change photo'**
  String get profileAvatarTapToChange;

  /// No description provided for @profileAvatarCropTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit profile photo'**
  String get profileAvatarCropTitle;

  /// No description provided for @profileAvatarCropHint.
  ///
  /// In en, this message translates to:
  /// **'Move and zoom photo'**
  String get profileAvatarCropHint;

  /// No description provided for @profileAvatarCropCancelAction.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get profileAvatarCropCancelAction;

  /// No description provided for @profileAvatarCropSaveAction.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get profileAvatarCropSaveAction;

  /// No description provided for @profileAvatarCropResetAction.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get profileAvatarCropResetAction;

  /// No description provided for @profileAvatarCropFitAction.
  ///
  /// In en, this message translates to:
  /// **'Fit'**
  String get profileAvatarCropFitAction;

  /// No description provided for @profileAvatarCropLoading.
  ///
  /// In en, this message translates to:
  /// **'Preparing photo...'**
  String get profileAvatarCropLoading;

  /// No description provided for @profileAvatarCropError.
  ///
  /// In en, this message translates to:
  /// **'Could not process photo. Try another image.'**
  String get profileAvatarCropError;

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

  /// No description provided for @profileAccountDeleted.
  ///
  /// In en, this message translates to:
  /// **'Your account was deleted.'**
  String get profileAccountDeleted;

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

  /// No description provided for @petsAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add pet'**
  String get petsAddTitle;

  /// No description provided for @petsEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit pet'**
  String get petsEditTitle;

  /// No description provided for @petsDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Pet details'**
  String get petsDetailsTitle;

  /// No description provided for @petsCreateWithPetTitle.
  ///
  /// In en, this message translates to:
  /// **'Create with a pet'**
  String get petsCreateWithPetTitle;

  /// No description provided for @petsManageAction.
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get petsManageAction;

  /// No description provided for @petsAddAction.
  ///
  /// In en, this message translates to:
  /// **'Add pet'**
  String get petsAddAction;

  /// No description provided for @petsSaveAction.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get petsSaveAction;

  /// No description provided for @petsNextAction.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get petsNextAction;

  /// No description provided for @petsBackAction.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get petsBackAction;

  /// No description provided for @petsDoneAction.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get petsDoneAction;

  /// No description provided for @petsCancelAction.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get petsCancelAction;

  /// No description provided for @petsChangeAction.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get petsChangeAction;

  /// No description provided for @petsStartAction.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get petsStartAction;

  /// No description provided for @petsRetryAction.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get petsRetryAction;

  /// No description provided for @petsNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get petsNameLabel;

  /// No description provided for @petsNameStepTitle.
  ///
  /// In en, this message translates to:
  /// **'Pet name'**
  String get petsNameStepTitle;

  /// No description provided for @petsNameStepSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Give your pet a short name.'**
  String get petsNameStepSubtitle;

  /// No description provided for @petsNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter name'**
  String get petsNameHint;

  /// No description provided for @petsNameExample.
  ///
  /// In en, this message translates to:
  /// **'Example: Richi, Murka, Buddy'**
  String get petsNameExample;

  /// No description provided for @petsNameRequiredError.
  ///
  /// In en, this message translates to:
  /// **'Enter your pet\'s name'**
  String get petsNameRequiredError;

  /// No description provided for @petsTypeBreedTitle.
  ///
  /// In en, this message translates to:
  /// **'Type and breed'**
  String get petsTypeBreedTitle;

  /// No description provided for @petsTypeBreedStepSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose pet type and add the breed if you know it.'**
  String get petsTypeBreedStepSubtitle;

  /// No description provided for @petsBreedLabel.
  ///
  /// In en, this message translates to:
  /// **'Breed'**
  String get petsBreedLabel;

  /// No description provided for @petsBreedHint.
  ///
  /// In en, this message translates to:
  /// **'Example: Shih Tzu'**
  String get petsBreedHint;

  /// No description provided for @petsPhotoLabel.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get petsPhotoLabel;

  /// No description provided for @petsPhotoStepTitle.
  ///
  /// In en, this message translates to:
  /// **'Pet photo'**
  String get petsPhotoStepTitle;

  /// No description provided for @petsPhotoStepSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Upload a clear photo where the face is visible.'**
  String get petsPhotoStepSubtitle;

  /// No description provided for @petsDogType.
  ///
  /// In en, this message translates to:
  /// **'Dog'**
  String get petsDogType;

  /// No description provided for @petsCatType.
  ///
  /// In en, this message translates to:
  /// **'Cat'**
  String get petsCatType;

  /// No description provided for @petsOtherType.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get petsOtherType;

  /// No description provided for @petsChooseFirstPhotoAction.
  ///
  /// In en, this message translates to:
  /// **'Choose first photo'**
  String get petsChooseFirstPhotoAction;

  /// No description provided for @petsAddPhotoAction.
  ///
  /// In en, this message translates to:
  /// **'Add photo'**
  String get petsAddPhotoAction;

  /// No description provided for @petsAddPhotoLaterHint.
  ///
  /// In en, this message translates to:
  /// **'You can add a photo later from the pet profile.'**
  String get petsAddPhotoLaterHint;

  /// No description provided for @petsPhotoFormatHint.
  ///
  /// In en, this message translates to:
  /// **'JPG, PNG up to 10 MB'**
  String get petsPhotoFormatHint;

  /// No description provided for @petsPhotoSelectedLabel.
  ///
  /// In en, this message translates to:
  /// **'Photo selected'**
  String get petsPhotoSelectedLabel;

  /// No description provided for @petsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Add your first pet'**
  String get petsEmptyTitle;

  /// No description provided for @petsEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Save a profile and photos so generation starts in one tap.'**
  String get petsEmptySubtitle;

  /// No description provided for @petsLoadErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not load pets'**
  String get petsLoadErrorTitle;

  /// No description provided for @petsLoadPetErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not load pet'**
  String get petsLoadPetErrorTitle;

  /// No description provided for @petsLoadPhotosErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not load photos'**
  String get petsLoadPhotosErrorTitle;

  /// No description provided for @petsLoadHistoryErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not load history'**
  String get petsLoadHistoryErrorTitle;

  /// No description provided for @petsNotFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'Pet not found'**
  String get petsNotFoundTitle;

  /// No description provided for @petsPhotosTitle.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get petsPhotosTitle;

  /// No description provided for @petsHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Generation history'**
  String get petsHistoryTitle;

  /// No description provided for @petsNoPhotosTitle.
  ///
  /// In en, this message translates to:
  /// **'No photos yet.'**
  String get petsNoPhotosTitle;

  /// No description provided for @petsNoGenerationsTitle.
  ///
  /// In en, this message translates to:
  /// **'No generations yet.'**
  String get petsNoGenerationsTitle;

  /// No description provided for @petsStatsPhotos.
  ///
  /// In en, this message translates to:
  /// **'{count} photos'**
  String petsStatsPhotos(Object count);

  /// No description provided for @petsStatsGenerations.
  ///
  /// In en, this message translates to:
  /// **'{count} generations'**
  String petsStatsGenerations(Object count);

  /// No description provided for @petsGenerateWithPet.
  ///
  /// In en, this message translates to:
  /// **'Generate with pet'**
  String get petsGenerateWithPet;

  /// No description provided for @petsGenerateWithName.
  ///
  /// In en, this message translates to:
  /// **'Generate with {name}'**
  String petsGenerateWithName(Object name);

  /// No description provided for @petsCreateWithName.
  ///
  /// In en, this message translates to:
  /// **'Create with {name}'**
  String petsCreateWithName(Object name);

  /// No description provided for @petsAddPhotoPrompt.
  ///
  /// In en, this message translates to:
  /// **'Add a photo of {name} to start'**
  String petsAddPhotoPrompt(Object name);

  /// No description provided for @petsDeleteTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete pet'**
  String get petsDeleteTooltip;

  /// No description provided for @petsDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete pet?'**
  String get petsDeleteConfirmTitle;

  /// No description provided for @petsDeleteConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'This removes the pet profile and its saved photos.'**
  String get petsDeleteConfirmMessage;

  /// No description provided for @petsDeleteConfirmAction.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get petsDeleteConfirmAction;

  /// No description provided for @petsAddPhotosTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add photos'**
  String get petsAddPhotosTooltip;

  /// No description provided for @petsSetAvatarTooltip.
  ///
  /// In en, this message translates to:
  /// **'Set as avatar'**
  String get petsSetAvatarTooltip;

  /// No description provided for @petsMarkFavoriteTooltip.
  ///
  /// In en, this message translates to:
  /// **'Mark favorite'**
  String get petsMarkFavoriteTooltip;

  /// No description provided for @petsUseForGenerationTooltip.
  ///
  /// In en, this message translates to:
  /// **'Use for generation'**
  String get petsUseForGenerationTooltip;

  /// No description provided for @petsDeletePhotoTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete photo'**
  String get petsDeletePhotoTooltip;

  /// No description provided for @petsAvatarBadge.
  ///
  /// In en, this message translates to:
  /// **'Avatar'**
  String get petsAvatarBadge;

  /// No description provided for @petsFavoriteBadge.
  ///
  /// In en, this message translates to:
  /// **'Favorite'**
  String get petsFavoriteBadge;

  /// No description provided for @petsPhotoUpdateError.
  ///
  /// In en, this message translates to:
  /// **'Could not update photo'**
  String get petsPhotoUpdateError;

  /// No description provided for @petsUnsupportedPhotoTypeError.
  ///
  /// In en, this message translates to:
  /// **'This photo type is not supported'**
  String get petsUnsupportedPhotoTypeError;

  /// No description provided for @petsPhotoUploadError.
  ///
  /// In en, this message translates to:
  /// **'Could not upload photo'**
  String get petsPhotoUploadError;

  /// No description provided for @petsOpenGenerationTooltip.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get petsOpenGenerationTooltip;

  /// No description provided for @petsShareGenerationTooltip.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get petsShareGenerationTooltip;

  /// No description provided for @petsUseGenerationAsInputTooltip.
  ///
  /// In en, this message translates to:
  /// **'Use as input'**
  String get petsUseGenerationAsInputTooltip;

  /// No description provided for @petsTemplateFallback.
  ///
  /// In en, this message translates to:
  /// **'Template'**
  String get petsTemplateFallback;

  /// No description provided for @petsUploadAction.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get petsUploadAction;

  /// No description provided for @petsChooseFromMyPetsAction.
  ///
  /// In en, this message translates to:
  /// **'Choose from My Pets'**
  String get petsChooseFromMyPetsAction;

  /// No description provided for @petsActionSheetUploadSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add a photo or video'**
  String get petsActionSheetUploadSubtitle;

  /// No description provided for @petsActionSheetMyPetsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use a pet from your profile'**
  String get petsActionSheetMyPetsSubtitle;

  /// No description provided for @petsActionSheetSourceTitle.
  ///
  /// In en, this message translates to:
  /// **'Content source'**
  String get petsActionSheetSourceTitle;

  /// No description provided for @petsActionSheetUploadSemantic.
  ///
  /// In en, this message translates to:
  /// **'Upload a photo or video'**
  String get petsActionSheetUploadSemantic;

  /// No description provided for @petsActionSheetMyPetsSemantic.
  ///
  /// In en, this message translates to:
  /// **'Choose a pet from your profile'**
  String get petsActionSheetMyPetsSemantic;

  /// No description provided for @petsGenerationCostMessage.
  ///
  /// In en, this message translates to:
  /// **'This generation costs {count} PawSpark.'**
  String petsGenerationCostMessage(Object count);

  /// No description provided for @petsNoPhotoStartMessage.
  ///
  /// In en, this message translates to:
  /// **'Add a pet photo to start'**
  String get petsNoPhotoStartMessage;

  /// No description provided for @petsFirstPetToast.
  ///
  /// In en, this message translates to:
  /// **'Add your first pet'**
  String get petsFirstPetToast;

  /// No description provided for @petsCouldNotLoadToast.
  ///
  /// In en, this message translates to:
  /// **'Could not load pets'**
  String get petsCouldNotLoadToast;

  /// No description provided for @petsAuthRequiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Save and use your pets'**
  String get petsAuthRequiredTitle;

  /// No description provided for @petsAuthRequiredMessage.
  ///
  /// In en, this message translates to:
  /// **'Sign in or create an account to save pet profiles and use them for generations.'**
  String get petsAuthRequiredMessage;

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
  /// **'PawSpark available'**
  String get profileSubscriptionTokensLabel;

  /// No description provided for @subscriptionStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Premium active'**
  String get subscriptionStatusActive;

  /// No description provided for @subscriptionStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled (active until period end)'**
  String get subscriptionStatusCancelled;

  /// No description provided for @subscriptionStatusExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get subscriptionStatusExpired;

  /// No description provided for @subscriptionStatusPaymentFailed.
  ///
  /// In en, this message translates to:
  /// **'Payment failed'**
  String get subscriptionStatusPaymentFailed;

  /// No description provided for @subscriptionStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Payment pending'**
  String get subscriptionStatusPending;

  /// No description provided for @subscriptionStatusInactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get subscriptionStatusInactive;

  /// No description provided for @subscriptionStartDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Subscription started'**
  String get subscriptionStartDateLabel;

  /// No description provided for @subscriptionPeriodEndLabel.
  ///
  /// In en, this message translates to:
  /// **'Paid until'**
  String get subscriptionPeriodEndLabel;

  /// No description provided for @subscriptionAutoRenewLabel.
  ///
  /// In en, this message translates to:
  /// **'Auto-renewal'**
  String get subscriptionAutoRenewLabel;

  /// No description provided for @subscriptionAutoRenewOn.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get subscriptionAutoRenewOn;

  /// No description provided for @subscriptionAutoRenewOff.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get subscriptionAutoRenewOff;

  /// No description provided for @subscriptionTokensSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Premium PawSpark'**
  String get subscriptionTokensSectionTitle;

  /// No description provided for @subscriptionTokensAvailableLabel.
  ///
  /// In en, this message translates to:
  /// **'Available now'**
  String get subscriptionTokensAvailableLabel;

  /// No description provided for @subscriptionTokensPerPeriodLabel.
  ///
  /// In en, this message translates to:
  /// **'Every 7 days'**
  String get subscriptionTokensPerPeriodLabel;

  /// No description provided for @subscriptionTokensNextGrantLabel.
  ///
  /// In en, this message translates to:
  /// **'Next grant'**
  String get subscriptionTokensNextGrantLabel;

  /// No description provided for @subscriptionTokensCountdown.
  ///
  /// In en, this message translates to:
  /// **'In {days}d {hours}h {minutes}m'**
  String subscriptionTokensCountdown(Object days, Object hours, Object minutes);

  /// No description provided for @subscriptionTokensExplanation.
  ///
  /// In en, this message translates to:
  /// **'PawSpark are granted every 7 days from subscription start. The first bonus is granted immediately after purchase.'**
  String get subscriptionTokensExplanation;

  /// No description provided for @subscriptionBenefitsSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Premium benefits'**
  String get subscriptionBenefitsSectionTitle;

  /// No description provided for @subscriptionBenefitTokens.
  ///
  /// In en, this message translates to:
  /// **'40 PawSpark every 7 days'**
  String get subscriptionBenefitTokens;

  /// No description provided for @subscriptionBenefitFirstBonus.
  ///
  /// In en, this message translates to:
  /// **'First bonus granted right after purchase'**
  String get subscriptionBenefitFirstBonus;

  /// No description provided for @subscriptionBenefitTemplates.
  ///
  /// In en, this message translates to:
  /// **'Access to Premium templates'**
  String get subscriptionBenefitTemplates;

  /// No description provided for @subscriptionBenefitPriorityGeneration.
  ///
  /// In en, this message translates to:
  /// **'Priority generation'**
  String get subscriptionBenefitPriorityGeneration;

  /// No description provided for @subscriptionBenefitNoWatermark.
  ///
  /// In en, this message translates to:
  /// **'No watermark'**
  String get subscriptionBenefitNoWatermark;

  /// No description provided for @subscriptionPaymentSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get subscriptionPaymentSectionTitle;

  /// No description provided for @subscriptionPaymentMethodLabel.
  ///
  /// In en, this message translates to:
  /// **'Payment method'**
  String get subscriptionPaymentMethodLabel;

  /// No description provided for @subscriptionPaymentCardLabel.
  ///
  /// In en, this message translates to:
  /// **'Card'**
  String get subscriptionPaymentCardLabel;

  /// No description provided for @subscriptionPaymentProviderStripe.
  ///
  /// In en, this message translates to:
  /// **'Card via Stripe'**
  String get subscriptionPaymentProviderStripe;

  /// No description provided for @subscriptionPaymentProviderGooglePlay.
  ///
  /// In en, this message translates to:
  /// **'Google Play'**
  String get subscriptionPaymentProviderGooglePlay;

  /// No description provided for @subscriptionPaymentProviderAppStore.
  ///
  /// In en, this message translates to:
  /// **'Apple / App Store'**
  String get subscriptionPaymentProviderAppStore;

  /// No description provided for @subscriptionChangePaymentAction.
  ///
  /// In en, this message translates to:
  /// **'Change payment method'**
  String get subscriptionChangePaymentAction;

  /// No description provided for @subscriptionCancelAction.
  ///
  /// In en, this message translates to:
  /// **'Cancel subscription'**
  String get subscriptionCancelAction;

  /// No description provided for @subscriptionCancelledHint.
  ///
  /// In en, this message translates to:
  /// **'Subscription is active until {date}. It will not renew after that.'**
  String subscriptionCancelledHint(Object date);

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

  /// No description provided for @premiumUpsellHeadline.
  ///
  /// In en, this message translates to:
  /// **'Premium is better'**
  String get premiumUpsellHeadline;

  /// No description provided for @premiumUpsellSubtitle.
  ///
  /// In en, this message translates to:
  /// **'40 PawSpark every week\nNo watermark, high-quality export'**
  String get premiumUpsellSubtitle;

  /// No description provided for @premiumUpsellWeeklyCredits.
  ///
  /// In en, this message translates to:
  /// **'40 PawSpark every week'**
  String get premiumUpsellWeeklyCredits;

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
  String rewardsLastUpdatedMinutes(Object count);

  /// No description provided for @rewardsLastUpdatedHours.
  ///
  /// In en, this message translates to:
  /// **'{count} h ago'**
  String rewardsLastUpdatedHours(Object count);

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
  String rewardsReferralBonusPerFriend(Object count);

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
  String rewardsReferralShareMessage(Object bonus, Object code);

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

  /// No description provided for @walletPackStarterDescription.
  ///
  /// In en, this message translates to:
  /// **'A gentle start for your first creations'**
  String get walletPackStarterDescription;

  /// No description provided for @walletPackCreatorDescription.
  ///
  /// In en, this message translates to:
  /// **'More room for your favourite ideas'**
  String get walletPackCreatorDescription;

  /// No description provided for @walletPackViralDescription.
  ///
  /// In en, this message translates to:
  /// **'The biggest boost for ambitious ideas'**
  String get walletPackViralDescription;

  /// No description provided for @walletPackStarterMotivation.
  ///
  /// In en, this message translates to:
  /// **'Start creating today.'**
  String get walletPackStarterMotivation;

  /// No description provided for @walletPackCreatorMotivation.
  ///
  /// In en, this message translates to:
  /// **'More ways to delight your pet.'**
  String get walletPackCreatorMotivation;

  /// No description provided for @walletPackViralMotivation.
  ///
  /// In en, this message translates to:
  /// **'Bring your boldest ideas to life.'**
  String get walletPackViralMotivation;

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
  /// **'Payment opens in secure Stripe Checkout. After payment, PawSpark are credited to your balance right away.'**
  String get walletCheckoutHint;

  /// No description provided for @walletCheckoutProductSubtitle.
  ///
  /// In en, this message translates to:
  /// **'One-time top-up of your PawSpark balance for creating photos and videos in PetMagic'**
  String get walletCheckoutProductSubtitle;

  /// No description provided for @walletCheckoutTokensImmediately.
  ///
  /// In en, this message translates to:
  /// **'{count} PawSpark right after payment'**
  String walletCheckoutTokensImmediately(Object count);

  /// No description provided for @walletCheckoutBonusTokens.
  ///
  /// In en, this message translates to:
  /// **'+{count} bonus PawSpark included'**
  String walletCheckoutBonusTokens(Object count);

  /// No description provided for @walletCheckoutIncludesTitle.
  ///
  /// In en, this message translates to:
  /// **'What you get'**
  String get walletCheckoutIncludesTitle;

  /// No description provided for @walletCheckoutFeaturePremiumTemplates.
  ///
  /// In en, this message translates to:
  /// **'Premium templates'**
  String get walletCheckoutFeaturePremiumTemplates;

  /// No description provided for @walletCheckoutFeaturePriority.
  ///
  /// In en, this message translates to:
  /// **'Priority generation'**
  String get walletCheckoutFeaturePriority;

  /// No description provided for @walletCheckoutFeatureMoreVideos.
  ///
  /// In en, this message translates to:
  /// **'More video creation options'**
  String get walletCheckoutFeatureMoreVideos;

  /// No description provided for @walletCheckoutStripeMethodSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Card, Apple Pay or Google Pay'**
  String get walletCheckoutStripeMethodSubtitle;

  /// No description provided for @walletCheckoutTrustText.
  ///
  /// In en, this message translates to:
  /// **'PetMagic does not store your card details. Payments are securely processed by Stripe.'**
  String get walletCheckoutTrustText;

  /// No description provided for @walletPaymentMethodChooseSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose how you want to top up PawSpark.'**
  String get walletPaymentMethodChooseSubtitle;

  /// No description provided for @walletPaymentTrustTitle.
  ///
  /// In en, this message translates to:
  /// **'Secure payment'**
  String get walletPaymentTrustTitle;

  /// No description provided for @walletPaymentTrustStripeProcesses.
  ///
  /// In en, this message translates to:
  /// **'Card data is securely processed by Stripe.'**
  String get walletPaymentTrustStripeProcesses;

  /// No description provided for @walletPaymentTrustNoStorage.
  ///
  /// In en, this message translates to:
  /// **'PetMagic does not store your card details.'**
  String get walletPaymentTrustNoStorage;

  /// No description provided for @walletPaymentTrustTopUpAnytime.
  ///
  /// In en, this message translates to:
  /// **'You can top up PawSpark anytime.'**
  String get walletPaymentTrustTopUpAnytime;

  /// No description provided for @walletPaymentStoreUnavailableGooglePlay.
  ///
  /// In en, this message translates to:
  /// **'Google Play purchases are temporarily unavailable on this device. Choose another available payment method.'**
  String get walletPaymentStoreUnavailableGooglePlay;

  /// No description provided for @walletPaymentStoreUnavailableAppStore.
  ///
  /// In en, this message translates to:
  /// **'App Store purchases are temporarily unavailable on this device. Choose another available payment method.'**
  String get walletPaymentStoreUnavailableAppStore;

  /// No description provided for @walletCheckoutOrderSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Your top-up'**
  String get walletCheckoutOrderSectionTitle;

  /// No description provided for @walletCheckoutSucceeded.
  ///
  /// In en, this message translates to:
  /// **'Payment confirmed. +{spark} PawSpark is already in your wallet.'**
  String walletCheckoutSucceeded(Object spark);

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

  /// No description provided for @walletSourceOther.
  ///
  /// In en, this message translates to:
  /// **'Other activity'**
  String get walletSourceOther;

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
  /// **'Unlock viral pet videos'**
  String get premiumHeroTitle;

  /// No description provided for @premiumHeroSubtitle.
  ///
  /// In en, this message translates to:
  /// **'More generations, premium templates, faster processing and no watermark.'**
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
  /// **'{count} PawSpark / week'**
  String premiumTokensPerWeek(Object count);

  /// No description provided for @premiumTokensPerMonth.
  ///
  /// In en, this message translates to:
  /// **'{count} PawSpark / month'**
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
  String premiumTokenEstimate(Object photos, Object videos);

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

  /// No description provided for @premiumPaymentChooseSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose how you want to subscribe'**
  String get premiumPaymentChooseSubtitle;

  /// No description provided for @premiumPaymentStripe.
  ///
  /// In en, this message translates to:
  /// **'Stripe'**
  String get premiumPaymentStripe;

  /// No description provided for @premiumPaymentStripeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Card, Apple Pay or Google Pay'**
  String get premiumPaymentStripeSubtitle;

  /// No description provided for @premiumPaymentGooglePlay.
  ///
  /// In en, this message translates to:
  /// **'Google Play'**
  String get premiumPaymentGooglePlay;

  /// No description provided for @premiumPaymentGooglePlaySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Payment via Google Play'**
  String get premiumPaymentGooglePlaySubtitle;

  /// No description provided for @premiumPaymentApple.
  ///
  /// In en, this message translates to:
  /// **'Apple Pay / App Store'**
  String get premiumPaymentApple;

  /// No description provided for @premiumPaymentAppleSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Payment via the App Store'**
  String get premiumPaymentAppleSubtitle;

  /// No description provided for @premiumPaymentOther.
  ///
  /// In en, this message translates to:
  /// **'Other payment method'**
  String get premiumPaymentOther;

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

  /// No description provided for @premiumPaymentTrustStripeProcesses.
  ///
  /// In en, this message translates to:
  /// **'Card data is securely processed by Stripe.'**
  String get premiumPaymentTrustStripeProcesses;

  /// No description provided for @premiumPaymentTrustNoStorage.
  ///
  /// In en, this message translates to:
  /// **'PetMagic does not store your card details.'**
  String get premiumPaymentTrustNoStorage;

  /// No description provided for @premiumPaymentTrustManageInApp.
  ///
  /// In en, this message translates to:
  /// **'Subscription renewal and cancellation are managed inside PetMagic.'**
  String get premiumPaymentTrustManageInApp;

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
  /// **'PawSpark per month'**
  String get premiumComparisonTokens;

  /// No description provided for @premiumComparisonPremiumTokens.
  ///
  /// In en, this message translates to:
  /// **'Up to {count}'**
  String premiumComparisonPremiumTokens(Object count);

  /// No description provided for @premiumComparisonPremiumTokensFallback.
  ///
  /// In en, this message translates to:
  /// **'40 PawSpark / week'**
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
  /// **'20 PawSpark per month'**
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
  /// **'Unlock Premium'**
  String get premiumContinueAction;

  /// No description provided for @paymentContinueViaProviderAction.
  ///
  /// In en, this message translates to:
  /// **'Continue via {provider}'**
  String paymentContinueViaProviderAction(Object provider);

  /// No description provided for @paymentChooseAnotherMethodAction.
  ///
  /// In en, this message translates to:
  /// **'Choose another method'**
  String get paymentChooseAnotherMethodAction;

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
  /// **'Payment is not confirmed yet. We will update Premium or your wallet as soon as Stripe confirms the payment.'**
  String get externalCheckoutPendingVerificationMessage;

  /// No description provided for @premiumContinueWithPlan.
  ///
  /// In en, this message translates to:
  /// **'Continue with {plan} — {price} {period}'**
  String premiumContinueWithPlan(Object period, Object plan, Object price);

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
  /// **'App Store / Google Play subscriptions are temporarily unavailable right now. Try again later or use another available payment method.'**
  String get premiumStoreUnavailable;

  /// No description provided for @premiumStoreProductUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This subscription product is not available in the store on this device.'**
  String get premiumStoreProductUnavailable;

  /// No description provided for @premiumStoreVerificationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Store verification is temporarily unavailable.'**
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
  /// **'Billing management is currently unavailable for this account.'**
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
  /// **'Add sign-in methods so you do not lose access to your account.'**
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

  /// No description provided for @profileSettingsStorageTitle.
  ///
  /// In en, this message translates to:
  /// **'Storage management'**
  String get profileSettingsStorageTitle;

  /// No description provided for @profileSettingsStorageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Review and clear temporary files stored on this device.'**
  String get profileSettingsStorageSubtitle;

  /// No description provided for @profileStorageUsageSection.
  ///
  /// In en, this message translates to:
  /// **'Storage usage'**
  String get profileStorageUsageSection;

  /// No description provided for @profileStorageDownloadedTitle.
  ///
  /// In en, this message translates to:
  /// **'Downloaded creations'**
  String get profileStorageDownloadedTitle;

  /// No description provided for @profileStorageDownloadedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{size} stored on this device'**
  String profileStorageDownloadedSubtitle(Object size);

  /// No description provided for @profileStorageDownloadedItems.
  ///
  /// In en, this message translates to:
  /// **'{count} downloads available offline'**
  String profileStorageDownloadedItems(Object count);

  /// No description provided for @profileStorageCleanupSection.
  ///
  /// In en, this message translates to:
  /// **'Clear storage'**
  String get profileStorageCleanupSection;

  /// No description provided for @profileStorageMediaCacheTitle.
  ///
  /// In en, this message translates to:
  /// **'Temporary media cache'**
  String get profileStorageMediaCacheTitle;

  /// No description provided for @profileStorageMediaCacheSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Images and previews will download again when needed.'**
  String get profileStorageMediaCacheSubtitle;

  /// No description provided for @profileStorageDownloadedClearSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Removes downloaded copies; your creations stay in your account.'**
  String get profileStorageDownloadedClearSubtitle;

  /// No description provided for @profileStorageClearAction.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get profileStorageClearAction;

  /// No description provided for @profileStorageClearMediaConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear temporary media cache?'**
  String get profileStorageClearMediaConfirmTitle;

  /// No description provided for @profileStorageClearMediaConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Cached images and previews will be removed from this device.'**
  String get profileStorageClearMediaConfirmBody;

  /// No description provided for @profileStorageClearDownloadsConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear downloaded creations?'**
  String get profileStorageClearDownloadsConfirmTitle;

  /// No description provided for @profileStorageClearDownloadsConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Only local copies will be removed. Your creations and pending changes remain in your account.'**
  String get profileStorageClearDownloadsConfirmBody;

  /// No description provided for @profileStorageClearSuccess.
  ///
  /// In en, this message translates to:
  /// **'Local storage cleared.'**
  String get profileStorageClearSuccess;

  /// No description provided for @profileStorageSafetyNote.
  ///
  /// In en, this message translates to:
  /// **'Account data, settings and server-side creations are not removed.'**
  String get profileStorageSafetyNote;

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

  /// No description provided for @profileAccountRoleUser.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get profileAccountRoleUser;

  /// No description provided for @profileAccountRoleModerator.
  ///
  /// In en, this message translates to:
  /// **'Moderator'**
  String get profileAccountRoleModerator;

  /// No description provided for @profileAccountRoleAdmin.
  ///
  /// In en, this message translates to:
  /// **'Administrator'**
  String get profileAccountRoleAdmin;

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
  /// **'Connect Google to keep access to your generations, purchases, and PawSpark on any device.'**
  String get profileDetailsLinkedAccountsBody;

  /// No description provided for @profileDetailsLinkedAccountsBodyIos.
  ///
  /// In en, this message translates to:
  /// **'Connect Google or Apple to keep access to your generations, purchases, and PawSpark on any device.'**
  String get profileDetailsLinkedAccountsBodyIos;

  /// No description provided for @profileDetailsLinkedAccountsStatus.
  ///
  /// In en, this message translates to:
  /// **'Choose and connect convenient sign-in methods for your account.'**
  String get profileDetailsLinkedAccountsStatus;

  /// No description provided for @profileDetailsLinkedAccountsNext.
  ///
  /// In en, this message translates to:
  /// **'Linked accounts help you:\n✓ recover access\n✓ sign in on a new device\n✓ keep purchases and PawSpark\n✓ protect your account'**
  String get profileDetailsLinkedAccountsNext;

  /// No description provided for @profileLinkedAccountsLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading linked sign-in providers...'**
  String get profileLinkedAccountsLoading;

  /// No description provided for @profileLinkedAccountsConnectedStatus.
  ///
  /// In en, this message translates to:
  /// **'Connected and ready to sign in.'**
  String get profileLinkedAccountsConnectedStatus;

  /// No description provided for @profileLinkedAccountsNotConnectedStatus.
  ///
  /// In en, this message translates to:
  /// **'Not connected.'**
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
  /// **'This sign-in method cannot be removed until another method is connected.'**
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
  /// **'Choose which notifications you want to receive in PetMagic.'**
  String get profileDetailsNotificationsBody;

  /// No description provided for @profileDetailsNotificationsStatusEnabled.
  ///
  /// In en, this message translates to:
  /// **'Notifications are enabled for this profile.'**
  String get profileDetailsNotificationsStatusEnabled;

  /// No description provided for @profileDetailsNotificationsStatusDisabled.
  ///
  /// In en, this message translates to:
  /// **'Notifications are disabled for this profile.'**
  String get profileDetailsNotificationsStatusDisabled;

  /// No description provided for @profileDetailsNotificationsNext.
  ///
  /// In en, this message translates to:
  /// **'You can change push and email preferences at any time.'**
  String get profileDetailsNotificationsNext;

  /// No description provided for @profileNotificationsLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading notification settings...'**
  String get profileNotificationsLoading;

  /// No description provided for @profileNotificationsPushSection.
  ///
  /// In en, this message translates to:
  /// **'Push notifications'**
  String get profileNotificationsPushSection;

  /// No description provided for @profileNotificationsPushPhotoReady.
  ///
  /// In en, this message translates to:
  /// **'Photo is ready'**
  String get profileNotificationsPushPhotoReady;

  /// No description provided for @profileNotificationsPushVideoReady.
  ///
  /// In en, this message translates to:
  /// **'Video is ready'**
  String get profileNotificationsPushVideoReady;

  /// No description provided for @profileNotificationsPushGenerationErrors.
  ///
  /// In en, this message translates to:
  /// **'Generation errors'**
  String get profileNotificationsPushGenerationErrors;

  /// No description provided for @profileNotificationsPushReminders.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get profileNotificationsPushReminders;

  /// No description provided for @profileNotificationsPushNewTemplates.
  ///
  /// In en, this message translates to:
  /// **'New templates'**
  String get profileNotificationsPushNewTemplates;

  /// No description provided for @profileNotificationsPushPurchasesAndSubscriptions.
  ///
  /// In en, this message translates to:
  /// **'Purchases and subscriptions'**
  String get profileNotificationsPushPurchasesAndSubscriptions;

  /// No description provided for @profileNotificationsEmailSection.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get profileNotificationsEmailSection;

  /// No description provided for @profileNotificationsEmailOffers.
  ///
  /// In en, this message translates to:
  /// **'Offers and discounts'**
  String get profileNotificationsEmailOffers;

  /// No description provided for @profileNotificationsEmailNews.
  ///
  /// In en, this message translates to:
  /// **'PetMagic news'**
  String get profileNotificationsEmailNews;

  /// No description provided for @profileNotificationsEmailAccountAlerts.
  ///
  /// In en, this message translates to:
  /// **'Important account alerts'**
  String get profileNotificationsEmailAccountAlerts;

  /// No description provided for @profileNotificationsDeviceSection.
  ///
  /// In en, this message translates to:
  /// **'Device status'**
  String get profileNotificationsDeviceSection;

  /// No description provided for @profileNotificationsPushPermissionLabel.
  ///
  /// In en, this message translates to:
  /// **'Push permissions'**
  String get profileNotificationsPushPermissionLabel;

  /// No description provided for @profileNotificationsPushPermissionAllowed.
  ///
  /// In en, this message translates to:
  /// **'Allowed'**
  String get profileNotificationsPushPermissionAllowed;

  /// No description provided for @profileNotificationsPushPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Disabled in device settings'**
  String get profileNotificationsPushPermissionDenied;

  /// No description provided for @profileNotificationsPushPermissionNotDetermined.
  ///
  /// In en, this message translates to:
  /// **'Not requested yet'**
  String get profileNotificationsPushPermissionNotDetermined;

  /// No description provided for @profileNotificationsPushPermissionProvisional.
  ///
  /// In en, this message translates to:
  /// **'Allowed quietly'**
  String get profileNotificationsPushPermissionProvisional;

  /// No description provided for @profileNotificationsPushPermissionUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get profileNotificationsPushPermissionUnknown;

  /// No description provided for @profileNotificationsRefreshStatus.
  ///
  /// In en, this message translates to:
  /// **'Refresh status'**
  String get profileNotificationsRefreshStatus;

  /// No description provided for @profileNotificationsRequestPermission.
  ///
  /// In en, this message translates to:
  /// **'Allow push notifications'**
  String get profileNotificationsRequestPermission;

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
  /// **'Review the current Terms of Use below and accept the latest version if this account still requires it.'**
  String get profileDetailsTermsNext;

  /// No description provided for @profileDetailsPrivacyBody.
  ///
  /// In en, this message translates to:
  /// **'Review how PetMagic stores, protects and uses account data.'**
  String get profileDetailsPrivacyBody;

  /// No description provided for @profileDetailsPrivacyStatus.
  ///
  /// In en, this message translates to:
  /// **'This screen shows the current Privacy Policy, published version, and this account\'s acceptance status.'**
  String get profileDetailsPrivacyStatus;

  /// No description provided for @profileDetailsPrivacyNext.
  ///
  /// In en, this message translates to:
  /// **'Review the current Privacy Policy below and accept the latest version if this account still requires it.'**
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

  /// No description provided for @profileLegalDocumentInfoSection.
  ///
  /// In en, this message translates to:
  /// **'Document info'**
  String get profileLegalDocumentInfoSection;

  /// No description provided for @profileLegalOpenFullAction.
  ///
  /// In en, this message translates to:
  /// **'Open full policy'**
  String get profileLegalOpenFullAction;

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

  /// No description provided for @profilePrivacyQuickDataTitle.
  ///
  /// In en, this message translates to:
  /// **'What we collect'**
  String get profilePrivacyQuickDataTitle;

  /// No description provided for @profilePrivacyQuickDataBody.
  ///
  /// In en, this message translates to:
  /// **'• Email\n• Profile name\n• Generation history\n• Uploaded pet photos\n• Purchase history\n• Support requests'**
  String get profilePrivacyQuickDataBody;

  /// No description provided for @profilePrivacyQuickUsageTitle.
  ///
  /// In en, this message translates to:
  /// **'Why we use it'**
  String get profilePrivacyQuickUsageTitle;

  /// No description provided for @profilePrivacyQuickUsageBody.
  ///
  /// In en, this message translates to:
  /// **'• Run app features\n• Generate content\n• Respond in support\n• Protect account and payments'**
  String get profilePrivacyQuickUsageBody;

  /// No description provided for @profilePrivacyQuickSharingTitle.
  ///
  /// In en, this message translates to:
  /// **'Do we share data?'**
  String get profilePrivacyQuickSharingTitle;

  /// No description provided for @profilePrivacyQuickSharingBody.
  ///
  /// In en, this message translates to:
  /// **'We do not sell personal data. Data may be shared only with processors needed to operate the service (for example payments, cloud hosting, and analytics).'**
  String get profilePrivacyQuickSharingBody;

  /// No description provided for @profilePrivacyQuickRightsTitle.
  ///
  /// In en, this message translates to:
  /// **'Your rights'**
  String get profilePrivacyQuickRightsTitle;

  /// No description provided for @profilePrivacyQuickRightsBody.
  ///
  /// In en, this message translates to:
  /// **'• Request a copy of your data\n• Request account and data deletion\n• Withdraw consent where applicable'**
  String get profilePrivacyQuickRightsBody;

  /// No description provided for @profileDetailsDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Deleting your account starts permanent account removal after you confirm this action.'**
  String get profileDetailsDeleteBody;

  /// No description provided for @profileDetailsDeleteStatus.
  ///
  /// In en, this message translates to:
  /// **'Deletion is available from this screen and cannot be undone. Continue only if you are ready to remove your account.'**
  String get profileDetailsDeleteStatus;

  /// No description provided for @profileDetailsDeleteNext.
  ///
  /// In en, this message translates to:
  /// **'Open the confirmation sheet, review the warning, and confirm deletion only after you have saved everything you still need.'**
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
  /// **'Your conversation is protected. We use it only for support.'**
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
  /// **'We usually reply within 24 hours'**
  String get supportChatTeamStatus;

  /// No description provided for @supportChatTodayLabel.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get supportChatTodayLabel;

  /// No description provided for @supportChatInputHint.
  ///
  /// In en, this message translates to:
  /// **'Describe the issue...'**
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
  /// **'Hello! Describe your issue and we will help.'**
  String get supportChatWelcomeTitle;

  /// No description provided for @supportChatWelcomeBody.
  ///
  /// In en, this message translates to:
  /// **'You can also choose one of the common topics below.'**
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

  /// No description provided for @supportChatQuickActionSubscription.
  ///
  /// In en, this message translates to:
  /// **'Subscription issue'**
  String get supportChatQuickActionSubscription;

  /// No description provided for @supportChatQuickActionVideo.
  ///
  /// In en, this message translates to:
  /// **'Video generation issue'**
  String get supportChatQuickActionVideo;

  /// No description provided for @supportChatQuickActionTokens.
  ///
  /// In en, this message translates to:
  /// **'PawSpark were not credited'**
  String get supportChatQuickActionTokens;

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
  /// **'The support team will reply in this chat. We usually respond within 24 hours.'**
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

  /// No description provided for @supportChatWaitingForSupportStatus.
  ///
  /// In en, this message translates to:
  /// **'Waiting for support'**
  String get supportChatWaitingForSupportStatus;

  /// No description provided for @supportChatWaitingForSupportStatusHint.
  ///
  /// In en, this message translates to:
  /// **'The request is open. Support will see the new message.'**
  String get supportChatWaitingForSupportStatusHint;

  /// No description provided for @supportChatInProgressStatusHint.
  ///
  /// In en, this message translates to:
  /// **'Support is reviewing your issue.'**
  String get supportChatInProgressStatusHint;

  /// No description provided for @supportChatAwaitingYourReplyStatus.
  ///
  /// In en, this message translates to:
  /// **'Awaiting your reply'**
  String get supportChatAwaitingYourReplyStatus;

  /// No description provided for @supportChatSupportRepliedStatusHint.
  ///
  /// In en, this message translates to:
  /// **'Support replied. Did this help?'**
  String get supportChatSupportRepliedStatusHint;

  /// No description provided for @supportChatResolvedStatusHint.
  ///
  /// In en, this message translates to:
  /// **'This request was marked as resolved. You can reopen it for 7 days.'**
  String get supportChatResolvedStatusHint;

  /// No description provided for @supportChatClosedStatusHint.
  ///
  /// In en, this message translates to:
  /// **'Conversation is closed. Send a new message to reopen it.'**
  String get supportChatClosedStatusHint;

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

  /// No description provided for @supportChatAttachmentTooLargeError.
  ///
  /// In en, this message translates to:
  /// **'File is too large'**
  String get supportChatAttachmentTooLargeError;

  /// No description provided for @supportChatImageLabel.
  ///
  /// In en, this message translates to:
  /// **'Support image'**
  String get supportChatImageLabel;

  /// No description provided for @supportChatSaveImageAction.
  ///
  /// In en, this message translates to:
  /// **'Save image'**
  String get supportChatSaveImageAction;

  /// No description provided for @supportChatShareAction.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get supportChatShareAction;

  /// No description provided for @supportChatOpenOriginalAction.
  ///
  /// In en, this message translates to:
  /// **'Open original'**
  String get supportChatOpenOriginalAction;

  /// No description provided for @supportChatCloseAction.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get supportChatCloseAction;

  /// No description provided for @supportChatImageSavedMessage.
  ///
  /// In en, this message translates to:
  /// **'Image saved'**
  String get supportChatImageSavedMessage;

  /// No description provided for @supportChatSaveImageFailedError.
  ///
  /// In en, this message translates to:
  /// **'Failed to save image'**
  String get supportChatSaveImageFailedError;

  /// No description provided for @supportChatShareImageFailedError.
  ///
  /// In en, this message translates to:
  /// **'Failed to share image'**
  String get supportChatShareImageFailedError;

  /// No description provided for @supportChatAttachmentStatusUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading'**
  String get supportChatAttachmentStatusUploading;

  /// No description provided for @supportChatAttachmentStatusUploaded.
  ///
  /// In en, this message translates to:
  /// **'Uploaded'**
  String get supportChatAttachmentStatusUploaded;

  /// No description provided for @supportChatAttachmentStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get supportChatAttachmentStatusFailed;

  /// No description provided for @supportChatAttachmentStatusRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get supportChatAttachmentStatusRetry;

  /// No description provided for @supportChatAttachmentUploadingWithCount.
  ///
  /// In en, this message translates to:
  /// **'Uploading photo {current} of {total}'**
  String supportChatAttachmentUploadingWithCount(Object current, Object total);

  /// No description provided for @supportChatImageUploadFailedLabel.
  ///
  /// In en, this message translates to:
  /// **'Image upload failed'**
  String get supportChatImageUploadFailedLabel;

  /// No description provided for @supportChatFileFallbackLabel.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get supportChatFileFallbackLabel;

  /// No description provided for @supportChatSystemNoticeTitle.
  ///
  /// In en, this message translates to:
  /// **'Request sent'**
  String get supportChatSystemNoticeTitle;

  /// No description provided for @supportChatSystemNoticeBody.
  ///
  /// In en, this message translates to:
  /// **'Thanks, we received your message. Support will reply in this chat.'**
  String get supportChatSystemNoticeBody;

  /// No description provided for @supportChatComposerAttachmentChip.
  ///
  /// In en, this message translates to:
  /// **'Up to 5 photos: JPG/PNG/WebP, 10 MB each'**
  String get supportChatComposerAttachmentChip;

  /// No description provided for @supportChatComposerResponseChip.
  ///
  /// In en, this message translates to:
  /// **'Typical reply in a few hours'**
  String get supportChatComposerResponseChip;

  /// No description provided for @supportChatAddPhotoTitle.
  ///
  /// In en, this message translates to:
  /// **'Add photo'**
  String get supportChatAddPhotoTitle;

  /// No description provided for @supportChatAddAttachmentTitle.
  ///
  /// In en, this message translates to:
  /// **'Add attachment'**
  String get supportChatAddAttachmentTitle;

  /// No description provided for @supportChatTakePhotoAction.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get supportChatTakePhotoAction;

  /// No description provided for @supportChatChooseGalleryAction.
  ///
  /// In en, this message translates to:
  /// **'Choose from gallery'**
  String get supportChatChooseGalleryAction;

  /// No description provided for @supportChatChoosePhotosAction.
  ///
  /// In en, this message translates to:
  /// **'Choose photos'**
  String get supportChatChoosePhotosAction;

  /// No description provided for @supportChatRecordVideoAction.
  ///
  /// In en, this message translates to:
  /// **'Record video'**
  String get supportChatRecordVideoAction;

  /// No description provided for @supportChatChooseVideoAction.
  ///
  /// In en, this message translates to:
  /// **'Choose video'**
  String get supportChatChooseVideoAction;

  /// No description provided for @supportChatAttachFileAction.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get supportChatAttachFileAction;

  /// No description provided for @supportChatRecentMediaTitle.
  ///
  /// In en, this message translates to:
  /// **'Recent media'**
  String get supportChatRecentMediaTitle;

  /// No description provided for @supportChatAttachmentNoRecentMedia.
  ///
  /// In en, this message translates to:
  /// **'No recent photos or videos'**
  String get supportChatAttachmentNoRecentMedia;

  /// No description provided for @supportChatAttachmentLimitedAccessHint.
  ///
  /// In en, this message translates to:
  /// **'Not all photos are available. Allow full gallery access in device settings.'**
  String get supportChatAttachmentLimitedAccessHint;

  /// No description provided for @supportChatOpenSettingsAction.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get supportChatOpenSettingsAction;

  /// No description provided for @supportChatAttachmentNoGalleryAccessError.
  ///
  /// In en, this message translates to:
  /// **'Gallery access is denied. Allow access in device settings.'**
  String get supportChatAttachmentNoGalleryAccessError;

  /// No description provided for @supportChatCameraPermissionPhotoError.
  ///
  /// In en, this message translates to:
  /// **'Camera permission is required to take a photo.'**
  String get supportChatCameraPermissionPhotoError;

  /// No description provided for @supportChatCameraPermissionVideoError.
  ///
  /// In en, this message translates to:
  /// **'Camera permission is required to record a video.'**
  String get supportChatCameraPermissionVideoError;

  /// No description provided for @supportChatFilesPermissionError.
  ///
  /// In en, this message translates to:
  /// **'Files permission is required to attach files.'**
  String get supportChatFilesPermissionError;

  /// No description provided for @permissionsAccessNeededTitle.
  ///
  /// In en, this message translates to:
  /// **'Access needed'**
  String get permissionsAccessNeededTitle;

  /// No description provided for @permissionsOpenSettingsAction.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get permissionsOpenSettingsAction;

  /// No description provided for @permissionsGalleryAccessDeniedMessage.
  ///
  /// In en, this message translates to:
  /// **'Allow access to your gallery to choose a photo.'**
  String get permissionsGalleryAccessDeniedMessage;

  /// No description provided for @permissionsGalleryAccessBlockedMessage.
  ///
  /// In en, this message translates to:
  /// **'Gallery access is off. Open device settings to allow it.'**
  String get permissionsGalleryAccessBlockedMessage;

  /// No description provided for @permissionsMediaAccessDeniedMessage.
  ///
  /// In en, this message translates to:
  /// **'Allow access to your photos and videos to add attachments.'**
  String get permissionsMediaAccessDeniedMessage;

  /// No description provided for @permissionsMediaAccessBlockedMessage.
  ///
  /// In en, this message translates to:
  /// **'Photos and videos access is off. Open device settings to allow it.'**
  String get permissionsMediaAccessBlockedMessage;

  /// No description provided for @permissionsCameraAccessDeniedMessage.
  ///
  /// In en, this message translates to:
  /// **'Allow camera access to take a photo.'**
  String get permissionsCameraAccessDeniedMessage;

  /// No description provided for @permissionsCameraAccessBlockedMessage.
  ///
  /// In en, this message translates to:
  /// **'Camera access is off. Open device settings to allow it.'**
  String get permissionsCameraAccessBlockedMessage;

  /// No description provided for @permissionsCameraVideoAccessDeniedMessage.
  ///
  /// In en, this message translates to:
  /// **'Allow camera access to record a video.'**
  String get permissionsCameraVideoAccessDeniedMessage;

  /// No description provided for @permissionsCameraVideoAccessBlockedMessage.
  ///
  /// In en, this message translates to:
  /// **'Camera access is off. Open device settings to allow video recording.'**
  String get permissionsCameraVideoAccessBlockedMessage;

  /// No description provided for @permissionsMicrophoneAccessDeniedMessage.
  ///
  /// In en, this message translates to:
  /// **'Allow microphone access to record a video with sound.'**
  String get permissionsMicrophoneAccessDeniedMessage;

  /// No description provided for @permissionsMicrophoneAccessBlockedMessage.
  ///
  /// In en, this message translates to:
  /// **'Microphone access is off. Open device settings to allow video recording with sound.'**
  String get permissionsMicrophoneAccessBlockedMessage;

  /// No description provided for @supportChatAttachmentExpiredPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Attachment was deleted after 30 days'**
  String get supportChatAttachmentExpiredPlaceholder;

  /// No description provided for @supportChatReplyLabel.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get supportChatReplyLabel;

  /// No description provided for @supportChatReplyToPrefix.
  ///
  /// In en, this message translates to:
  /// **'Reply to message'**
  String get supportChatReplyToPrefix;

  /// No description provided for @supportChatReplyOriginalUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Original message is unavailable'**
  String get supportChatReplyOriginalUnavailable;

  /// No description provided for @supportChatPhotoAttachedLabel.
  ///
  /// In en, this message translates to:
  /// **'Photo attached'**
  String get supportChatPhotoAttachedLabel;

  /// No description provided for @supportChatVideoAttachedLabel.
  ///
  /// In en, this message translates to:
  /// **'Video attached'**
  String get supportChatVideoAttachedLabel;

  /// No description provided for @supportChatVideoLabel.
  ///
  /// In en, this message translates to:
  /// **'Support video'**
  String get supportChatVideoLabel;

  /// No description provided for @supportChatAssistantBadge.
  ///
  /// In en, this message translates to:
  /// **'Assistant'**
  String get supportChatAssistantBadge;

  /// No description provided for @supportChatTooManyAttachmentsError.
  ///
  /// In en, this message translates to:
  /// **'You can add up to 5 files'**
  String get supportChatTooManyAttachmentsError;

  /// No description provided for @supportChatAttachmentUnsupportedFormatError.
  ///
  /// In en, this message translates to:
  /// **'This format is not supported'**
  String get supportChatAttachmentUnsupportedFormatError;

  /// No description provided for @supportChatAttachmentVideoTooLongError.
  ///
  /// In en, this message translates to:
  /// **'Video must be 60 seconds or shorter.'**
  String get supportChatAttachmentVideoTooLongError;

  /// No description provided for @supportChatMarkResolvedAction.
  ///
  /// In en, this message translates to:
  /// **'Yes, close request'**
  String get supportChatMarkResolvedAction;

  /// No description provided for @supportChatKeepOpenAction.
  ///
  /// In en, this message translates to:
  /// **'No, write more'**
  String get supportChatKeepOpenAction;

  /// No description provided for @supportChatCloseRequestDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Close request?'**
  String get supportChatCloseRequestDialogTitle;

  /// No description provided for @supportChatCloseRequestDialogBody.
  ///
  /// In en, this message translates to:
  /// **'If the problem is resolved, we will close this conversation. You can create a new request later.'**
  String get supportChatCloseRequestDialogBody;

  /// No description provided for @supportChatCloseConfirmAction.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get supportChatCloseConfirmAction;

  /// No description provided for @supportChatCancelAction.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get supportChatCancelAction;

  /// No description provided for @supportChatConversationClosedLabel.
  ///
  /// In en, this message translates to:
  /// **'Request closed'**
  String get supportChatConversationClosedLabel;

  /// No description provided for @supportChatReopenAction.
  ///
  /// In en, this message translates to:
  /// **'Write again'**
  String get supportChatReopenAction;

  /// No description provided for @supportChatArchiveAction.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get supportChatArchiveAction;

  /// No description provided for @supportChatRateTitle.
  ///
  /// In en, this message translates to:
  /// **'Rate the support reply'**
  String get supportChatRateTitle;

  /// No description provided for @supportChatRatedLabel.
  ///
  /// In en, this message translates to:
  /// **'Your rating: {rating}/5'**
  String supportChatRatedLabel(Object rating);

  /// No description provided for @supportChatReadOnlyHint.
  ///
  /// In en, this message translates to:
  /// **'This conversation is read-only'**
  String get supportChatReadOnlyHint;

  /// No description provided for @supportHomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Help & Support'**
  String get supportHomeTitle;

  /// No description provided for @supportHomeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'What can we help you with?'**
  String get supportHomeSubtitle;

  /// No description provided for @supportHomeOpenChatAction.
  ///
  /// In en, this message translates to:
  /// **'Open chat'**
  String get supportHomeOpenChatAction;

  /// No description provided for @supportHomeTopicGenerationIssue.
  ///
  /// In en, this message translates to:
  /// **'Issue with image generation'**
  String get supportHomeTopicGenerationIssue;

  /// No description provided for @supportHomeTopicGenerationTooLong.
  ///
  /// In en, this message translates to:
  /// **'Generation takes too long'**
  String get supportHomeTopicGenerationTooLong;

  /// No description provided for @supportHomeTopicTokensNotArrived.
  ///
  /// In en, this message translates to:
  /// **'PawSpark did not arrive'**
  String get supportHomeTopicTokensNotArrived;

  /// No description provided for @supportHomeTopicPremiumIssue.
  ///
  /// In en, this message translates to:
  /// **'Premium issue'**
  String get supportHomeTopicPremiumIssue;

  /// No description provided for @supportHomeTopicPaymentRefund.
  ///
  /// In en, this message translates to:
  /// **'Payment / Refund'**
  String get supportHomeTopicPaymentRefund;

  /// No description provided for @supportHomeTopicOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get supportHomeTopicOther;

  /// No description provided for @supportAssistantTitle.
  ///
  /// In en, this message translates to:
  /// **'Support Assistant'**
  String get supportAssistantTitle;

  /// No description provided for @supportAssistantThisHelpedAction.
  ///
  /// In en, this message translates to:
  /// **'This helped'**
  String get supportAssistantThisHelpedAction;

  /// No description provided for @supportAssistantCreateTicketAction.
  ///
  /// In en, this message translates to:
  /// **'Create support ticket'**
  String get supportAssistantCreateTicketAction;

  /// No description provided for @supportAssistantCheckLaterAction.
  ///
  /// In en, this message translates to:
  /// **'Check later'**
  String get supportAssistantCheckLaterAction;

  /// No description provided for @supportAssistantRecommendationGeneration.
  ///
  /// In en, this message translates to:
  /// **'For better results, please use a photo where the pet is clearly visible, not cropped, not blurry, and well lit.'**
  String get supportAssistantRecommendationGeneration;

  /// No description provided for @supportAssistantRecommendationGenerationTooLong.
  ///
  /// In en, this message translates to:
  /// **'Video generation may take several minutes. It usually takes around 2–10 minutes. If it has taken too long, we can send this issue to support.'**
  String get supportAssistantRecommendationGenerationTooLong;

  /// No description provided for @supportAssistantRecommendationTokensNotArrived.
  ///
  /// In en, this message translates to:
  /// **'Sometimes PawSpark delivery after payment may take a few minutes. If PawSpark still do not appear, create a support ticket and we will check the purchase.'**
  String get supportAssistantRecommendationTokensNotArrived;

  /// No description provided for @supportAssistantRecommendationPremiumIssue.
  ///
  /// In en, this message translates to:
  /// **'If Premium has already been paid for but is not visible in the app, please try restarting the app. If the problem remains, we will check your subscription status.'**
  String get supportAssistantRecommendationPremiumIssue;

  /// No description provided for @supportAssistantRecommendationPaymentRefund.
  ///
  /// In en, this message translates to:
  /// **'We can check your payment or forward your refund request to support. Create a support ticket and we will attach the relevant purchase information if available.'**
  String get supportAssistantRecommendationPaymentRefund;

  /// No description provided for @supportAssistantRecommendationOther.
  ///
  /// In en, this message translates to:
  /// **'Please describe what happened. You can also attach a screenshot to help support understand the situation faster.'**
  String get supportAssistantRecommendationOther;

  /// No description provided for @supportTicketFormTitle.
  ///
  /// In en, this message translates to:
  /// **'Create support ticket'**
  String get supportTicketFormTitle;

  /// No description provided for @supportTicketFormTopicLabel.
  ///
  /// In en, this message translates to:
  /// **'Topic'**
  String get supportTicketFormTopicLabel;

  /// No description provided for @supportTicketFormDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Problem description'**
  String get supportTicketFormDescriptionLabel;

  /// No description provided for @supportTicketFormDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Describe what happened...'**
  String get supportTicketFormDescriptionHint;

  /// No description provided for @supportTicketFormRelatedGenerationLabel.
  ///
  /// In en, this message translates to:
  /// **'Related generation'**
  String get supportTicketFormRelatedGenerationLabel;

  /// No description provided for @supportTicketFormRelatedPaymentLabel.
  ///
  /// In en, this message translates to:
  /// **'Related payment'**
  String get supportTicketFormRelatedPaymentLabel;

  /// No description provided for @supportTicketFormRelatedSubscriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Related subscription'**
  String get supportTicketFormRelatedSubscriptionLabel;

  /// No description provided for @supportTicketFormAttachmentsLabel.
  ///
  /// In en, this message translates to:
  /// **'Attachments'**
  String get supportTicketFormAttachmentsLabel;

  /// No description provided for @supportTicketFormAddScreenshotAction.
  ///
  /// In en, this message translates to:
  /// **'Add screenshot'**
  String get supportTicketFormAddScreenshotAction;

  /// No description provided for @supportTicketFormSubmitAction.
  ///
  /// In en, this message translates to:
  /// **'Send to support'**
  String get supportTicketFormSubmitAction;

  /// No description provided for @supportTicketFormSubmittingLabel.
  ///
  /// In en, this message translates to:
  /// **'Creating ticket...'**
  String get supportTicketFormSubmittingLabel;

  /// No description provided for @supportTicketFormSuccessMessage.
  ///
  /// In en, this message translates to:
  /// **'Your ticket has been created. We will reply in this chat.'**
  String get supportTicketFormSuccessMessage;

  /// No description provided for @supportTicketFormErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'Failed to create ticket. Please try again.'**
  String get supportTicketFormErrorMessage;

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

  /// No description provided for @closeAction.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get closeAction;

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
  /// **'Collect PawSpark and premium perks later'**
  String get startupOnboardingPageThreeTitle;

  /// No description provided for @startupOnboardingPageThreeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Keep the first impression fun. PawSpark, rewards and premium actions wait behind a clean auth step.'**
  String get startupOnboardingPageThreeSubtitle;

  /// No description provided for @startupOnboardingPageThreeHighlightOne.
  ///
  /// In en, this message translates to:
  /// **'Premium unlocks'**
  String get startupOnboardingPageThreeHighlightOne;

  /// No description provided for @startupOnboardingPageThreeHighlightTwo.
  ///
  /// In en, this message translates to:
  /// **'PawSpark balance'**
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
  /// **'Create magical videos with your pet'**
  String get startupWelcomeTitle;

  /// No description provided for @startupWelcomeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pick a template, add your pet photo, and get an AI video ready in minutes.'**
  String get startupWelcomeSubtitle;

  /// No description provided for @startupWelcomeContinueGuest.
  ///
  /// In en, this message translates to:
  /// **'Continue as guest'**
  String get startupWelcomeContinueGuest;

  /// No description provided for @startupWelcomeTemplatesTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a template'**
  String get startupWelcomeTemplatesTitle;

  /// No description provided for @startupWelcomeTemplatesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Trends, memes, and seasonal scenes for every mood.'**
  String get startupWelcomeTemplatesSubtitle;

  /// No description provided for @startupWelcomeAiTitle.
  ///
  /// In en, this message translates to:
  /// **'Add your pet photo'**
  String get startupWelcomeAiTitle;

  /// No description provided for @startupWelcomeAiSubtitle.
  ///
  /// In en, this message translates to:
  /// **'One photo is enough for AI to build style and motion.'**
  String get startupWelcomeAiSubtitle;

  /// No description provided for @startupWelcomeShareTitle.
  ///
  /// In en, this message translates to:
  /// **'Get a ready video'**
  String get startupWelcomeShareTitle;

  /// No description provided for @startupWelcomeShareSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your clip is ready to share or save in one tap.'**
  String get startupWelcomeShareSubtitle;

  /// No description provided for @startupWelcomeGuestHint.
  ///
  /// In en, this message translates to:
  /// **'You can start without an account. Sign up is only needed to save history and access purchases.'**
  String get startupWelcomeGuestHint;

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
  /// **'Join PetMagic and unlock templates, PawSpark and premium features.'**
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
  /// **'Use at least 8 characters with uppercase, lowercase and a number.'**
  String get authPasswordRulesHint;

  /// No description provided for @authPasswordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters long.'**
  String get authPasswordTooShort;

  /// No description provided for @authPasswordPolicyInvalid.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters and include uppercase, lowercase and a number.'**
  String get authPasswordPolicyInvalid;

  /// No description provided for @authForgotPasswordAction.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get authForgotPasswordAction;

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

  /// No description provided for @authTermsLinkText.
  ///
  /// In en, this message translates to:
  /// **'Terms of Use'**
  String get authTermsLinkText;

  /// No description provided for @authPrivacyLinkText.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get authPrivacyLinkText;

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
  /// **'Legal documents are temporarily unavailable.'**
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

  /// No description provided for @authEmailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address.'**
  String get authEmailInvalid;

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
  /// **'We do not sell personal data. We share it only with processors needed to run PetMagic.'**
  String get authPrivacySubtitle;

  /// No description provided for @authRequiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to unlock this action'**
  String get authRequiredTitle;

  /// No description provided for @authRequiredMessage.
  ///
  /// In en, this message translates to:
  /// **'Guests can explore the app, but template actions, rewards and PawSpark features require a PetMagic account.'**
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

  /// No description provided for @templateUnlockPremiumAction.
  ///
  /// In en, this message translates to:
  /// **'Unlock Premium'**
  String get templateUnlockPremiumAction;

  /// No description provided for @templateGuestPreview.
  ///
  /// In en, this message translates to:
  /// **'Guest preview'**
  String get templateGuestPreview;

  /// No description provided for @templateFlowPhotoSourceGallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get templateFlowPhotoSourceGallery;

  /// No description provided for @templateFlowPhotoSourceCamera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get templateFlowPhotoSourceCamera;

  /// No description provided for @petsActionSheetGallerySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a photo or video from your gallery'**
  String get petsActionSheetGallerySubtitle;

  /// No description provided for @petsActionSheetCameraSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Take a photo or video right now'**
  String get petsActionSheetCameraSubtitle;

  /// No description provided for @petsActionSheetGallerySemantic.
  ///
  /// In en, this message translates to:
  /// **'Choose a photo or video from your gallery'**
  String get petsActionSheetGallerySemantic;

  /// No description provided for @petsActionSheetCameraSemantic.
  ///
  /// In en, this message translates to:
  /// **'Take a photo or video with your camera'**
  String get petsActionSheetCameraSemantic;

  /// No description provided for @templateFlowReadyTitle.
  ///
  /// In en, this message translates to:
  /// **'Ready to create!'**
  String get templateFlowReadyTitle;

  /// No description provided for @templateFlowCheckDetailsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Check the details before creating'**
  String get templateFlowCheckDetailsSubtitle;

  /// No description provided for @templateFlowTemplateLabel.
  ///
  /// In en, this message translates to:
  /// **'Template'**
  String get templateFlowTemplateLabel;

  /// No description provided for @templateFlowCostLabel.
  ///
  /// In en, this message translates to:
  /// **'Cost'**
  String get templateFlowCostLabel;

  /// No description provided for @templateFlowBalanceLabel.
  ///
  /// In en, this message translates to:
  /// **'Your balance'**
  String get templateFlowBalanceLabel;

  /// No description provided for @templateFlowDurationHint.
  ///
  /// In en, this message translates to:
  /// **'Creation can take from 10 seconds to 1 minute.'**
  String get templateFlowDurationHint;

  /// No description provided for @templateFlowCreateMagicAction.
  ///
  /// In en, this message translates to:
  /// **'Create magic'**
  String get templateFlowCreateMagicAction;

  /// No description provided for @templateFlowChangePhotoAction.
  ///
  /// In en, this message translates to:
  /// **'Change photo'**
  String get templateFlowChangePhotoAction;

  /// No description provided for @templateFlowPremiumTemplateTitle.
  ///
  /// In en, this message translates to:
  /// **'Premium template'**
  String get templateFlowPremiumTemplateTitle;

  /// No description provided for @templateFlowPremiumTemplateMessage.
  ///
  /// In en, this message translates to:
  /// **'This template is available only with Premium.'**
  String get templateFlowPremiumTemplateMessage;

  /// No description provided for @templateFlowPremiumLockedTitle.
  ///
  /// In en, this message translates to:
  /// **'This template is available in Premium'**
  String get templateFlowPremiumLockedTitle;

  /// No description provided for @templateFlowPremiumLockedMessage.
  ///
  /// In en, this message translates to:
  /// **'Subscribe to unlock exclusive styles, effects, and Premium templates.'**
  String get templateFlowPremiumLockedMessage;

  /// No description provided for @templateFlowInsufficientBalanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Not enough PawSpark'**
  String get templateFlowInsufficientBalanceTitle;

  /// No description provided for @templateFlowInsufficientBalanceMessage.
  ///
  /// In en, this message translates to:
  /// **'This template costs {tokenCost} PawSpark. Your balance: {balance} PawSpark.'**
  String templateFlowInsufficientBalanceMessage(
    Object balance,
    Object tokenCost,
  );

  /// No description provided for @templateFlowInsufficientBalanceUpsellMessage.
  ///
  /// In en, this message translates to:
  /// **'Buy PawSpark once or get Premium with 40 PawSpark every week.'**
  String get templateFlowInsufficientBalanceUpsellMessage;

  /// No description provided for @templateFlowChooseAnotherTemplateAction.
  ///
  /// In en, this message translates to:
  /// **'Choose another template'**
  String get templateFlowChooseAnotherTemplateAction;

  /// No description provided for @templateFlowCreateFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not create magic'**
  String get templateFlowCreateFailedTitle;

  /// No description provided for @templateFlowCreateFailedBalanceHint.
  ///
  /// In en, this message translates to:
  /// **'Top up your balance and try creating again.'**
  String get templateFlowCreateFailedBalanceHint;

  /// No description provided for @templateFlowCreateFailedRetryHint.
  ///
  /// In en, this message translates to:
  /// **'Try another photo or retry later.'**
  String get templateFlowCreateFailedRetryHint;

  /// No description provided for @templateFlowCreateHint.
  ///
  /// In en, this message translates to:
  /// **'This may take a little time'**
  String get templateFlowCreateHint;

  /// No description provided for @templateFlowStepProcessPhoto.
  ///
  /// In en, this message translates to:
  /// **'Processing photo'**
  String get templateFlowStepProcessPhoto;

  /// No description provided for @templateFlowStepAnalyzePet.
  ///
  /// In en, this message translates to:
  /// **'Analyzing pet'**
  String get templateFlowStepAnalyzePet;

  /// No description provided for @templateFlowStepCreateMagic.
  ///
  /// In en, this message translates to:
  /// **'Creating magic'**
  String get templateFlowStepCreateMagic;

  /// No description provided for @templateFlowStepFinalTouches.
  ///
  /// In en, this message translates to:
  /// **'Final touches'**
  String get templateFlowStepFinalTouches;

  /// No description provided for @templateFlowTopUpBalanceAction.
  ///
  /// In en, this message translates to:
  /// **'Top up balance'**
  String get templateFlowTopUpBalanceAction;

  /// No description provided for @templateFlowResultReadyTitle.
  ///
  /// In en, this message translates to:
  /// **'Done!'**
  String get templateFlowResultReadyTitle;

  /// No description provided for @templateFlowResultReadySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your magic is ready'**
  String get templateFlowResultReadySubtitle;

  /// No description provided for @templateFlowResultUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Result is currently unavailable'**
  String get templateFlowResultUnavailable;

  /// No description provided for @templateFlowLoadingResult.
  ///
  /// In en, this message translates to:
  /// **'Loading result...'**
  String get templateFlowLoadingResult;

  /// No description provided for @templateFlowResultLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load result'**
  String get templateFlowResultLoadFailed;

  /// No description provided for @templateFlowCreateMoreAction.
  ///
  /// In en, this message translates to:
  /// **'Create more'**
  String get templateFlowCreateMoreAction;

  /// No description provided for @templateFlowPreviewFallback.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get templateFlowPreviewFallback;

  /// No description provided for @templateFlowLoadingPreview.
  ///
  /// In en, this message translates to:
  /// **'Loading preview...'**
  String get templateFlowLoadingPreview;

  /// No description provided for @templateFlowPreviewUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Preview unavailable'**
  String get templateFlowPreviewUnavailable;

  /// No description provided for @templateFlowLoadingVideo.
  ///
  /// In en, this message translates to:
  /// **'Loading video...'**
  String get templateFlowLoadingVideo;

  /// No description provided for @generationResultInputTitle.
  ///
  /// In en, this message translates to:
  /// **'Use result'**
  String get generationResultInputTitle;

  /// No description provided for @generationResultInputParentTitle.
  ///
  /// In en, this message translates to:
  /// **'Completed result'**
  String get generationResultInputParentTitle;

  /// No description provided for @generationResultInputParentHint.
  ///
  /// In en, this message translates to:
  /// **'This result will be used as the base'**
  String get generationResultInputParentHint;

  /// No description provided for @generationResultInputMediaUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Media unavailable'**
  String get generationResultInputMediaUnavailable;

  /// No description provided for @generationResultInputRecommendedBadge.
  ///
  /// In en, this message translates to:
  /// **'Recommended'**
  String get generationResultInputRecommendedBadge;

  /// No description provided for @generationResultInputEmpty.
  ///
  /// In en, this message translates to:
  /// **'No compatible templates.'**
  String get generationResultInputEmpty;

  /// No description provided for @generationResultInputError.
  ///
  /// In en, this message translates to:
  /// **'Could not use this result. Please try again.'**
  String get generationResultInputError;

  /// No description provided for @generationResultInputNoCredits.
  ///
  /// In en, this message translates to:
  /// **'Not enough PawSpark for the new generation.'**
  String get generationResultInputNoCredits;

  /// No description provided for @generationResultInputStartAction.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get generationResultInputStartAction;

  /// No description provided for @generationResultInputCostEstimate.
  ///
  /// In en, this message translates to:
  /// **'Generation will cost {credits} PawSpark.'**
  String generationResultInputCostEstimate(Object credits);

  /// No description provided for @petGenerationLaunchTitle.
  ///
  /// In en, this message translates to:
  /// **'Magic generation launch'**
  String get petGenerationLaunchTitle;

  /// No description provided for @petGenerationLaunchTitleWithName.
  ///
  /// In en, this message translates to:
  /// **'Magic launch for {name}'**
  String petGenerationLaunchTitleWithName(Object name);

  /// No description provided for @petGenerationLaunchSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm the template, PawSpark cost, and exact pet photo before creating.'**
  String get petGenerationLaunchSubtitle;

  /// No description provided for @petGenerationLaunchPhotoSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Photo for generation'**
  String get petGenerationLaunchPhotoSectionTitle;

  /// No description provided for @petGenerationLaunchSelectedPhotoLabel.
  ///
  /// In en, this message translates to:
  /// **'This photo will be sent to generation'**
  String get petGenerationLaunchSelectedPhotoLabel;

  /// No description provided for @petGenerationLaunchUploadPhotoAction.
  ///
  /// In en, this message translates to:
  /// **'Upload new'**
  String get petGenerationLaunchUploadPhotoAction;

  /// No description provided for @petGenerationLaunchChoosePhotoTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a pet photo'**
  String get petGenerationLaunchChoosePhotoTitle;

  /// No description provided for @petGenerationLaunchLoadingPhotos.
  ///
  /// In en, this message translates to:
  /// **'Loading photos...'**
  String get petGenerationLaunchLoadingPhotos;

  /// No description provided for @petGenerationLaunchPhotoLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load pet photos. Please try again.'**
  String get petGenerationLaunchPhotoLoadError;

  /// No description provided for @petGenerationLaunchSelectedPhotoMissing.
  ///
  /// In en, this message translates to:
  /// **'Choose an available pet photo before starting. No PawSpark was charged.'**
  String get petGenerationLaunchSelectedPhotoMissing;

  /// No description provided for @petGenerationLaunchPhotoTypeError.
  ///
  /// In en, this message translates to:
  /// **'Choose a JPG, PNG, or WebP photo. No PawSpark was charged.'**
  String get petGenerationLaunchPhotoTypeError;

  /// No description provided for @petGenerationLaunchUploadError.
  ///
  /// In en, this message translates to:
  /// **'Could not upload the photo. No PawSpark was charged.'**
  String get petGenerationLaunchUploadError;

  /// No description provided for @petGenerationLaunchStartError.
  ///
  /// In en, this message translates to:
  /// **'Could not start generation. No PawSpark was charged. Please try again.'**
  String get petGenerationLaunchStartError;

  /// No description provided for @galleryPremiumUpsellTitle.
  ///
  /// In en, this message translates to:
  /// **'Watermark-free export'**
  String get galleryPremiumUpsellTitle;

  /// No description provided for @galleryPremiumUpsellSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Premium removes the PetMagic logo'**
  String get galleryPremiumUpsellSubtitle;

  /// No description provided for @templateFlowCompletedPremiumHeadline.
  ///
  /// In en, this message translates to:
  /// **'Want to create more?'**
  String get templateFlowCompletedPremiumHeadline;

  /// No description provided for @templateFlowCompletedPremiumMessage.
  ///
  /// In en, this message translates to:
  /// **'Premium gives you 40 PawSpark every week, premium templates, and watermark-free export.'**
  String get templateFlowCompletedPremiumMessage;

  /// No description provided for @templateDetailHeroImageTitle.
  ///
  /// In en, this message translates to:
  /// **'Create an image with your pet'**
  String get templateDetailHeroImageTitle;

  /// No description provided for @templateDetailHeroVideoTitle.
  ///
  /// In en, this message translates to:
  /// **'Create a video with your pet'**
  String get templateDetailHeroVideoTitle;

  /// No description provided for @templateDetailFallbackTitle.
  ///
  /// In en, this message translates to:
  /// **'PetMagic template'**
  String get templateDetailFallbackTitle;

  /// No description provided for @templateDetailFallbackDescriptionImage.
  ///
  /// In en, this message translates to:
  /// **'Upload a clear pet photo and PetMagic will create a polished image result.'**
  String get templateDetailFallbackDescriptionImage;

  /// No description provided for @templateDetailFallbackDescriptionVideo.
  ///
  /// In en, this message translates to:
  /// **'Upload a clear pet photo and PetMagic will turn it into a ready-to-share video.'**
  String get templateDetailFallbackDescriptionVideo;

  /// No description provided for @templateDetailCategoryTemplate.
  ///
  /// In en, this message translates to:
  /// **'Template'**
  String get templateDetailCategoryTemplate;

  /// No description provided for @templateDetailCategoryPortrait.
  ///
  /// In en, this message translates to:
  /// **'Portrait'**
  String get templateDetailCategoryPortrait;

  /// No description provided for @templateDetailCategoryVideo.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get templateDetailCategoryVideo;

  /// No description provided for @templateDetailRequirementOnePet.
  ///
  /// In en, this message translates to:
  /// **'One pet in the photo'**
  String get templateDetailRequirementOnePet;

  /// No description provided for @templateDetailRequirementClearFace.
  ///
  /// In en, this message translates to:
  /// **'Clear face'**
  String get templateDetailRequirementClearFace;

  /// No description provided for @templateDetailRequirementGoodLighting.
  ///
  /// In en, this message translates to:
  /// **'Good lighting'**
  String get templateDetailRequirementGoodLighting;

  /// No description provided for @templateDetailRequirementFullBodyVisible.
  ///
  /// In en, this message translates to:
  /// **'Full body visible'**
  String get templateDetailRequirementFullBodyVisible;

  /// No description provided for @templateDetailRequirementFacingCamera.
  ///
  /// In en, this message translates to:
  /// **'Pet facing camera'**
  String get templateDetailRequirementFacingCamera;

  /// No description provided for @templateDetailRequirementNoCroppedHeadOrLegs.
  ///
  /// In en, this message translates to:
  /// **'No cropped head or legs'**
  String get templateDetailRequirementNoCroppedHeadOrLegs;

  /// No description provided for @templateDetailQualityWarning.
  ///
  /// In en, this message translates to:
  /// **'Use a bright, sharp photo for the best result.'**
  String get templateDetailQualityWarning;

  /// No description provided for @templateDetailUploadPhotoForVideoAction.
  ///
  /// In en, this message translates to:
  /// **'Upload photo for video'**
  String get templateDetailUploadPhotoForVideoAction;

  /// No description provided for @templateDetailPreviewMissingTitle.
  ///
  /// In en, this message translates to:
  /// **'Preview is unavailable'**
  String get templateDetailPreviewMissingTitle;

  /// No description provided for @templateDetailPreviewMissingSubtitleImage.
  ///
  /// In en, this message translates to:
  /// **'You can still upload a pet photo and create this image.'**
  String get templateDetailPreviewMissingSubtitleImage;

  /// No description provided for @templateDetailPreviewMissingSubtitleVideo.
  ///
  /// In en, this message translates to:
  /// **'You can still upload a pet photo and create this video.'**
  String get templateDetailPreviewMissingSubtitleVideo;

  /// No description provided for @templateDetailTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get templateDetailTimeLabel;

  /// No description provided for @templateDetailFormatLabel.
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get templateDetailFormatLabel;

  /// No description provided for @templateDetailVideoEta.
  ///
  /// In en, this message translates to:
  /// **'2-4 min'**
  String get templateDetailVideoEta;

  /// No description provided for @templateDetailImageEta.
  ///
  /// In en, this message translates to:
  /// **'1-2 min'**
  String get templateDetailImageEta;

  /// No description provided for @templateDetailScrollHint.
  ///
  /// In en, this message translates to:
  /// **'Scroll for details'**
  String get templateDetailScrollHint;

  /// No description provided for @templateFlowBestPhotoTitle.
  ///
  /// In en, this message translates to:
  /// **'Best photo for this template:'**
  String get templateFlowBestPhotoTitle;

  /// No description provided for @templateFlowUploadPetPhotoAction.
  ///
  /// In en, this message translates to:
  /// **'Upload a pet photo'**
  String get templateFlowUploadPetPhotoAction;

  /// No description provided for @templateFlowUploadPetPhotoLockedAction.
  ///
  /// In en, this message translates to:
  /// **'Photo upload is available in Premium'**
  String get templateFlowUploadPetPhotoLockedAction;

  /// No description provided for @templateFlowPremiumRequiredError.
  ///
  /// In en, this message translates to:
  /// **'This template is available only with Premium.'**
  String get templateFlowPremiumRequiredError;

  /// No description provided for @templateFlowInsufficientBalanceError.
  ///
  /// In en, this message translates to:
  /// **'Not enough PawSpark to start generation.'**
  String get templateFlowInsufficientBalanceError;

  /// No description provided for @templateFlowTemplateUnavailableError.
  ///
  /// In en, this message translates to:
  /// **'This template is no longer available. Choose another template from the feed.'**
  String get templateFlowTemplateUnavailableError;

  /// No description provided for @templateFlowTemplateChangedError.
  ///
  /// In en, this message translates to:
  /// **'This template was updated. Reopen it from the feed and try again.'**
  String get templateFlowTemplateChangedError;

  /// No description provided for @templateFlowNetworkError.
  ///
  /// In en, this message translates to:
  /// **'No connection. Check your network and try again.'**
  String get templateFlowNetworkError;

  /// No description provided for @templateFlowServerError.
  ///
  /// In en, this message translates to:
  /// **'Service is temporarily unavailable. Please try again later.'**
  String get templateFlowServerError;

  /// No description provided for @templateFlowActiveGenerationLimitError.
  ///
  /// In en, this message translates to:
  /// **'You already have a generation in progress. Wait for it to finish, then start a new one.'**
  String get templateFlowActiveGenerationLimitError;

  /// No description provided for @templateFlowStartFailedError.
  ///
  /// In en, this message translates to:
  /// **'Could not start generation. Please try again.'**
  String get templateFlowStartFailedError;

  /// No description provided for @generationStatusTitle.
  ///
  /// In en, this message translates to:
  /// **'Generation status'**
  String get generationStatusTitle;

  /// No description provided for @generationStatusCreatedLabel.
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get generationStatusCreatedLabel;

  /// No description provided for @generationStatusStartedLabel.
  ///
  /// In en, this message translates to:
  /// **'Started'**
  String get generationStatusStartedLabel;

  /// No description provided for @generationStatusTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get generationStatusTypeLabel;

  /// No description provided for @generationStatusAttemptLabel.
  ///
  /// In en, this message translates to:
  /// **'Attempt'**
  String get generationStatusAttemptLabel;

  /// No description provided for @generationStatusUntitledFallback.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get generationStatusUntitledFallback;

  /// No description provided for @generationStatusDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get generationStatusDetailsTitle;

  /// No description provided for @generationStatusFeedbackTitle.
  ///
  /// In en, this message translates to:
  /// **'How is the result?'**
  String get generationStatusFeedbackTitle;

  /// No description provided for @generationStatusFeedbackExcellent.
  ///
  /// In en, this message translates to:
  /// **'Excellent'**
  String get generationStatusFeedbackExcellent;

  /// No description provided for @generationStatusFeedbackOkay.
  ///
  /// In en, this message translates to:
  /// **'Okay'**
  String get generationStatusFeedbackOkay;

  /// No description provided for @generationStatusFeedbackBad.
  ///
  /// In en, this message translates to:
  /// **'Not great'**
  String get generationStatusFeedbackBad;

  /// No description provided for @generationStatusSaveAction.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get generationStatusSaveAction;

  /// No description provided for @generationStatusDeleteAction.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get generationStatusDeleteAction;

  /// No description provided for @generationStatusReportProblemAction.
  ///
  /// In en, this message translates to:
  /// **'Report a problem'**
  String get generationStatusReportProblemAction;

  /// No description provided for @generationStatusPickAnotherPhotoAction.
  ///
  /// In en, this message translates to:
  /// **'Choose another photo'**
  String get generationStatusPickAnotherPhotoAction;

  /// No description provided for @generationStatusRetryAction.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get generationStatusRetryAction;

  /// No description provided for @generationStatusContactSupportAction.
  ///
  /// In en, this message translates to:
  /// **'Contact support'**
  String get generationStatusContactSupportAction;

  /// No description provided for @generationStatusOpenGalleryAction.
  ///
  /// In en, this message translates to:
  /// **'Open gallery'**
  String get generationStatusOpenGalleryAction;

  /// No description provided for @generationStatusOpenStatusAction.
  ///
  /// In en, this message translates to:
  /// **'Open status'**
  String get generationStatusOpenStatusAction;

  /// No description provided for @generationStatusResultUnavailableForSave.
  ///
  /// In en, this message translates to:
  /// **'Result is currently unavailable for saving.'**
  String get generationStatusResultUnavailableForSave;

  /// No description provided for @generationStatusResultUnavailableForShare.
  ///
  /// In en, this message translates to:
  /// **'Result is currently unavailable for sharing.'**
  String get generationStatusResultUnavailableForShare;

  /// No description provided for @generationStatusSaveFileDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Save file'**
  String get generationStatusSaveFileDialogTitle;

  /// No description provided for @generationStatusFileSavedMessage.
  ///
  /// In en, this message translates to:
  /// **'File saved to device.'**
  String get generationStatusFileSavedMessage;

  /// No description provided for @generationStatusFileSaveFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Could not save file. Please try again.'**
  String get generationStatusFileSaveFailedMessage;

  /// No description provided for @generationStatusSavedToGalleryMessage.
  ///
  /// In en, this message translates to:
  /// **'Saved to Gallery'**
  String get generationStatusSavedToGalleryMessage;

  /// No description provided for @generationStatusLinkCopiedMessage.
  ///
  /// In en, this message translates to:
  /// **'Link copied'**
  String get generationStatusLinkCopiedMessage;

  /// No description provided for @generationStatusDeletedMessage.
  ///
  /// In en, this message translates to:
  /// **'Deleted'**
  String get generationStatusDeletedMessage;

  /// No description provided for @generationStatusFullscreenControlsHint.
  ///
  /// In en, this message translates to:
  /// **'Tap to hide/show controls'**
  String get generationStatusFullscreenControlsHint;

  /// No description provided for @generationStatusDeleteSoonMessage.
  ///
  /// In en, this message translates to:
  /// **'Could not delete this result. Please try again.'**
  String get generationStatusDeleteSoonMessage;

  /// No description provided for @generationStatusRetrySoonMessage.
  ///
  /// In en, this message translates to:
  /// **'Choose another photo and start generation again.'**
  String get generationStatusRetrySoonMessage;

  /// No description provided for @generationStatusFeedbackThanksMessage.
  ///
  /// In en, this message translates to:
  /// **'Thanks! Your feedback helps improve PetMagic.'**
  String get generationStatusFeedbackThanksMessage;

  /// No description provided for @generationStatusResultTitle.
  ///
  /// In en, this message translates to:
  /// **'PetMagic result'**
  String get generationStatusResultTitle;

  /// No description provided for @generationStatusNonTerminalHint.
  ///
  /// In en, this message translates to:
  /// **'This usually takes a few minutes. You can keep using the app.'**
  String get generationStatusNonTerminalHint;

  /// No description provided for @generationStatusStageQueued.
  ///
  /// In en, this message translates to:
  /// **'In queue'**
  String get generationStatusStageQueued;

  /// No description provided for @generationStatusStageDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get generationStatusStageDone;

  /// No description provided for @generationStatusVideoReady.
  ///
  /// In en, this message translates to:
  /// **'Video is ready'**
  String get generationStatusVideoReady;

  /// No description provided for @generationStatusShareVideoAction.
  ///
  /// In en, this message translates to:
  /// **'Share video'**
  String get generationStatusShareVideoAction;

  /// No description provided for @generationStatusFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not create result'**
  String get generationStatusFailedTitle;

  /// No description provided for @generationStatusTokensRefundedHint.
  ///
  /// In en, this message translates to:
  /// **'PawSpark were returned to your balance.'**
  String get generationStatusTokensRefundedHint;

  /// No description provided for @generationStatusTokensRefundedShort.
  ///
  /// In en, this message translates to:
  /// **'PawSpark refunded'**
  String get generationStatusTokensRefundedShort;

  /// No description provided for @generationStatusSupportHint.
  ///
  /// In en, this message translates to:
  /// **'If this repeats, contact support.'**
  String get generationStatusSupportHint;

  /// No description provided for @generationStatusBackgroundHint.
  ///
  /// In en, this message translates to:
  /// **'Generation continues on the server. We will show the result in Gallery when it is ready.'**
  String get generationStatusBackgroundHint;

  /// No description provided for @generationStatusDownloadAction.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get generationStatusDownloadAction;

  /// No description provided for @generationStatusContinueInAppAction.
  ///
  /// In en, this message translates to:
  /// **'Continue in app'**
  String get generationStatusContinueInAppAction;

  /// No description provided for @generationStatusFeedbackImproveTitle.
  ///
  /// In en, this message translates to:
  /// **'What can we improve?'**
  String get generationStatusFeedbackImproveTitle;

  /// No description provided for @generationStatusFeedbackCommentLabel.
  ///
  /// In en, this message translates to:
  /// **'Comment'**
  String get generationStatusFeedbackCommentLabel;

  /// No description provided for @generationStatusFeedbackCommentHint.
  ///
  /// In en, this message translates to:
  /// **'Briefly tell us what was wrong'**
  String get generationStatusFeedbackCommentHint;

  /// No description provided for @generationStatusFeedbackSubmitAction.
  ///
  /// In en, this message translates to:
  /// **'Submit feedback'**
  String get generationStatusFeedbackSubmitAction;

  /// No description provided for @generationStatusFeedbackReasonPetNotSimilar.
  ///
  /// In en, this message translates to:
  /// **'Pet does not look like itself'**
  String get generationStatusFeedbackReasonPetNotSimilar;

  /// No description provided for @generationStatusFeedbackReasonFaceDistorted.
  ///
  /// In en, this message translates to:
  /// **'Face or muzzle is distorted'**
  String get generationStatusFeedbackReasonFaceDistorted;

  /// No description provided for @generationStatusFeedbackReasonStrangeMotion.
  ///
  /// In en, this message translates to:
  /// **'Motion looks strange'**
  String get generationStatusFeedbackReasonStrangeMotion;

  /// No description provided for @generationStatusFeedbackReasonPreviewMismatch.
  ///
  /// In en, this message translates to:
  /// **'Result differs from preview'**
  String get generationStatusFeedbackReasonPreviewMismatch;

  /// No description provided for @generationStatusFeedbackReasonLowQuality.
  ///
  /// In en, this message translates to:
  /// **'Quality is too low'**
  String get generationStatusFeedbackReasonLowQuality;

  /// No description provided for @generationStatusFeedbackReasonStyleDisliked.
  ///
  /// In en, this message translates to:
  /// **'Did not like the style'**
  String get generationStatusFeedbackReasonStyleDisliked;

  /// No description provided for @generationStatusFeedbackReasonOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get generationStatusFeedbackReasonOther;

  /// No description provided for @generationStatusEtaEstimated.
  ///
  /// In en, this message translates to:
  /// **'About {value} left'**
  String generationStatusEtaEstimated(Object value);

  /// No description provided for @generationStatusEtaQueued.
  ///
  /// In en, this message translates to:
  /// **'Waiting in queue'**
  String get generationStatusEtaQueued;

  /// No description provided for @generationStatusEtaFinalizing.
  ///
  /// In en, this message translates to:
  /// **'Almost ready'**
  String get generationStatusEtaFinalizing;

  /// No description provided for @generationStatusEtaDefault.
  ///
  /// In en, this message translates to:
  /// **'About 1-2 min left'**
  String get generationStatusEtaDefault;

  /// No description provided for @generationStatusEtaStartsSoon.
  ///
  /// In en, this message translates to:
  /// **'Will start in a few minutes'**
  String get generationStatusEtaStartsSoon;

  /// No description provided for @generationStatusEtaNotifyHint.
  ///
  /// In en, this message translates to:
  /// **'We will notify you when the result is ready.'**
  String get generationStatusEtaNotifyHint;

  /// No description provided for @generationStatusCancelledTitle.
  ///
  /// In en, this message translates to:
  /// **'Generation cancelled'**
  String get generationStatusCancelledTitle;

  /// No description provided for @generationStatusCancelledMessage.
  ///
  /// In en, this message translates to:
  /// **'This generation was stopped before processing started.'**
  String get generationStatusCancelledMessage;

  /// No description provided for @generationStatusCancelQueuedHint.
  ///
  /// In en, this message translates to:
  /// **'You can cancel while this generation is still waiting in queue.'**
  String get generationStatusCancelQueuedHint;

  /// No description provided for @generationStatusCancelQueuedAction.
  ///
  /// In en, this message translates to:
  /// **'Cancel generation'**
  String get generationStatusCancelQueuedAction;

  /// No description provided for @generationStatusCancelQueuedTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel generation?'**
  String get generationStatusCancelQueuedTitle;

  /// No description provided for @generationStatusCancelQueuedMessage.
  ///
  /// In en, this message translates to:
  /// **'This only works while generation is still queued. If PawSpark were reserved, they will return to your balance automatically.'**
  String get generationStatusCancelQueuedMessage;

  /// No description provided for @generationStatusCancelQueuedKeepAction.
  ///
  /// In en, this message translates to:
  /// **'Keep waiting'**
  String get generationStatusCancelQueuedKeepAction;

  /// No description provided for @generationStatusCancelQueuedConfirmAction.
  ///
  /// In en, this message translates to:
  /// **'Confirm cancellation'**
  String get generationStatusCancelQueuedConfirmAction;

  /// No description provided for @generationStatusCancelQueuedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Generation cancelled.'**
  String get generationStatusCancelQueuedSuccess;

  /// No description provided for @generationStatusCancelQueuedAlreadyStarted.
  ///
  /// In en, this message translates to:
  /// **'Generation already started and cannot be cancelled.'**
  String get generationStatusCancelQueuedAlreadyStarted;

  /// No description provided for @generationStatusCancelQueuedFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not cancel generation. Please try again.'**
  String get generationStatusCancelQueuedFailed;

  /// No description provided for @generationStatusQueuedVideoHint.
  ///
  /// In en, this message translates to:
  /// **'Video usually takes longer than photos and can take a few minutes.'**
  String get generationStatusQueuedVideoHint;

  /// No description provided for @generationStatusFailurePhotoHint.
  ///
  /// In en, this message translates to:
  /// **'The photo is not suitable for this template. Try a photo where the pet is clearly visible.'**
  String get generationStatusFailurePhotoHint;

  /// No description provided for @generationStatusFailureTechnicalHint.
  ///
  /// In en, this message translates to:
  /// **'Could not create the result due to a technical issue. PawSpark were returned to your balance.'**
  String get generationStatusFailureTechnicalHint;

  /// No description provided for @generationStatusStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Your result is ready'**
  String get generationStatusStatusCompleted;

  /// No description provided for @generationStatusStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not create result'**
  String get generationStatusStatusFailed;

  /// No description provided for @generationStatusStatusCreatingMagic.
  ///
  /// In en, this message translates to:
  /// **'Creating magic...'**
  String get generationStatusStatusCreatingMagic;

  /// No description provided for @generationStatusTerminalRefundedHint.
  ///
  /// In en, this message translates to:
  /// **'PawSpark were refunded automatically.'**
  String get generationStatusTerminalRefundedHint;

  /// No description provided for @generationStatusTerminalFailureHint.
  ///
  /// In en, this message translates to:
  /// **'A technical issue has been recorded.'**
  String get generationStatusTerminalFailureHint;

  /// No description provided for @generationStatusTerminalSuccessHint.
  ///
  /// In en, this message translates to:
  /// **'Open result, share it, or leave feedback.'**
  String get generationStatusTerminalSuccessHint;

  /// No description provided for @generationStatusSectionActive.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get generationStatusSectionActive;

  /// No description provided for @generationStatusSectionReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get generationStatusSectionReady;

  /// No description provided for @generationStatusSectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get generationStatusSectionFailed;

  /// No description provided for @generationStatusFilterActive.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get generationStatusFilterActive;

  /// No description provided for @generationStatusFilterReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get generationStatusFilterReady;

  /// No description provided for @generationStatusFilterFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get generationStatusFilterFailed;

  /// No description provided for @generationStatusShowMoreAction.
  ///
  /// In en, this message translates to:
  /// **'Show more ({hiddenCount}) ▾'**
  String generationStatusShowMoreAction(Object hiddenCount);

  /// No description provided for @generationStatusLoadMoreAction.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get generationStatusLoadMoreAction;

  /// No description provided for @generationStatusLoadMoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load more results.'**
  String get generationStatusLoadMoreFailed;

  /// No description provided for @generationStatusMediaPreparingMessage.
  ///
  /// In en, this message translates to:
  /// **'Preparing media...'**
  String get generationStatusMediaPreparingMessage;

  /// No description provided for @generationStatusMediaPreviewOnlyMessage.
  ///
  /// In en, this message translates to:
  /// **'Preview is available while the final file is being prepared.'**
  String get generationStatusMediaPreviewOnlyMessage;

  /// No description provided for @generationStatusMediaWatermarkPreparingMessage.
  ///
  /// In en, this message translates to:
  /// **'Preparing the clean version...'**
  String get generationStatusMediaWatermarkPreparingMessage;

  /// No description provided for @generationStatusMediaExpiredMessage.
  ///
  /// In en, this message translates to:
  /// **'This media has expired.'**
  String get generationStatusMediaExpiredMessage;

  /// No description provided for @generationStatusMediaUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'Media is unavailable.'**
  String get generationStatusMediaUnavailableMessage;

  /// No description provided for @generationStatusMediaFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Media processing failed.'**
  String get generationStatusMediaFailedMessage;

  /// No description provided for @generationStatusMediaHiddenMessage.
  ///
  /// In en, this message translates to:
  /// **'Media is hidden.'**
  String get generationStatusMediaHiddenMessage;

  /// No description provided for @generationStatusCollapseAction.
  ///
  /// In en, this message translates to:
  /// **'Collapse ▲'**
  String get generationStatusCollapseAction;

  /// No description provided for @generationStatusActiveInfoHint.
  ///
  /// In en, this message translates to:
  /// **'Generation continues on the server. We will show the result in Gallery when it is ready.'**
  String get generationStatusActiveInfoHint;

  /// No description provided for @generationStatusUnreadCount.
  ///
  /// In en, this message translates to:
  /// **'{count} new'**
  String generationStatusUnreadCount(Object count);

  /// No description provided for @generationStatusEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Your results will appear here'**
  String get generationStatusEmptyTitle;

  /// No description provided for @generationStatusEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Choose a template, upload your pet photo and create your first magic art.'**
  String get generationStatusEmptyMessage;

  /// No description provided for @generationStatusSubtitleAll.
  ///
  /// In en, this message translates to:
  /// **'Your magical creations'**
  String get generationStatusSubtitleAll;

  /// No description provided for @generationStatusSubtitleActive.
  ///
  /// In en, this message translates to:
  /// **'Active generations'**
  String get generationStatusSubtitleActive;

  /// No description provided for @generationStatusSubtitleReady.
  ///
  /// In en, this message translates to:
  /// **'Your ready results'**
  String get generationStatusSubtitleReady;

  /// No description provided for @generationStatusSubtitleFailed.
  ///
  /// In en, this message translates to:
  /// **'Generation issues'**
  String get generationStatusSubtitleFailed;

  /// No description provided for @generationStatusOfflineBannerTitle.
  ///
  /// In en, this message translates to:
  /// **'You are offline'**
  String get generationStatusOfflineBannerTitle;

  /// No description provided for @generationStatusOfflineBannerMessage.
  ///
  /// In en, this message translates to:
  /// **'Showing previously saved creations from this device.'**
  String get generationStatusOfflineBannerMessage;

  /// No description provided for @generationStatusOfflineBannerSyncedAt.
  ///
  /// In en, this message translates to:
  /// **'Last sync: {value}'**
  String generationStatusOfflineBannerSyncedAt(Object value);

  /// No description provided for @generationStatusOnlineBannerTitle.
  ///
  /// In en, this message translates to:
  /// **'Connection restored'**
  String get generationStatusOnlineBannerTitle;

  /// No description provided for @generationStatusOnlineBannerMessage.
  ///
  /// In en, this message translates to:
  /// **'Fresh data has been loaded.'**
  String get generationStatusOnlineBannerMessage;

  /// No description provided for @generationStatusOnlineBannerSyncedAt.
  ///
  /// In en, this message translates to:
  /// **'Updated: {value}'**
  String generationStatusOnlineBannerSyncedAt(Object value);

  /// No description provided for @generationStatusDateToday.
  ///
  /// In en, this message translates to:
  /// **'Today, {time}'**
  String generationStatusDateToday(Object time);

  /// No description provided for @generationStatusDateYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday, {time}'**
  String generationStatusDateYesterday(Object time);

  /// No description provided for @shellActiveGenerationLabel.
  ///
  /// In en, this message translates to:
  /// **'✨ Creating {templateTitle}'**
  String shellActiveGenerationLabel(Object templateTitle);

  /// No description provided for @shellActiveGenerationFallback.
  ///
  /// In en, this message translates to:
  /// **'result'**
  String get shellActiveGenerationFallback;

  /// No description provided for @walletStripeCardBrandsLabel.
  ///
  /// In en, this message translates to:
  /// **'Visa • Mastercard'**
  String get walletStripeCardBrandsLabel;

  /// No description provided for @walletStripeWalletsLabel.
  ///
  /// In en, this message translates to:
  /// **'Apple Pay • Google Pay'**
  String get walletStripeWalletsLabel;

  /// No description provided for @walletPackUsageNote.
  ///
  /// In en, this message translates to:
  /// **'Used for photo and video generations'**
  String get walletPackUsageNote;

  /// No description provided for @walletCheckoutTaxLabel.
  ///
  /// In en, this message translates to:
  /// **'Tax'**
  String get walletCheckoutTaxLabel;

  /// No description provided for @walletCheckoutTaxIncludedValue.
  ///
  /// In en, this message translates to:
  /// **'Included'**
  String get walletCheckoutTaxIncludedValue;

  /// No description provided for @walletCheckoutTotalLabel.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get walletCheckoutTotalLabel;

  /// No description provided for @walletCheckoutPayAction.
  ///
  /// In en, this message translates to:
  /// **'Pay {price}'**
  String walletCheckoutPayAction(Object price);

  /// No description provided for @emailVerificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify email'**
  String get emailVerificationTitle;

  /// No description provided for @emailVerificationCodeSentMessage.
  ///
  /// In en, this message translates to:
  /// **'We sent a 6-digit code to {email}.'**
  String emailVerificationCodeSentMessage(Object email);

  /// No description provided for @emailVerificationCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get emailVerificationCodeLabel;

  /// No description provided for @emailVerificationWorkingLabel.
  ///
  /// In en, this message translates to:
  /// **'Working...'**
  String get emailVerificationWorkingLabel;

  /// No description provided for @emailVerificationVerifyAction.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get emailVerificationVerifyAction;

  /// No description provided for @emailVerificationResendAction.
  ///
  /// In en, this message translates to:
  /// **'Send code again'**
  String get emailVerificationResendAction;

  /// No description provided for @emailVerificationChangeEmailAction.
  ///
  /// In en, this message translates to:
  /// **'Change email'**
  String get emailVerificationChangeEmailAction;

  /// No description provided for @emailVerificationConfirmedMessage.
  ///
  /// In en, this message translates to:
  /// **'Email confirmed. Please sign in.'**
  String get emailVerificationConfirmedMessage;

  /// No description provided for @emailVerificationResentFallbackMessage.
  ///
  /// In en, this message translates to:
  /// **'If the account exists, a new code has been sent.'**
  String get emailVerificationResentFallbackMessage;

  /// No description provided for @profileNotificationsDeviceAllowed.
  ///
  /// In en, this message translates to:
  /// **'Allowed'**
  String get profileNotificationsDeviceAllowed;

  /// No description provided for @profileNotificationsDeviceLimited.
  ///
  /// In en, this message translates to:
  /// **'Limited'**
  String get profileNotificationsDeviceLimited;

  /// No description provided for @profileNotificationsDeviceDenied.
  ///
  /// In en, this message translates to:
  /// **'Denied'**
  String get profileNotificationsDeviceDenied;

  /// No description provided for @profileNotificationsDevicePermanentlyDenied.
  ///
  /// In en, this message translates to:
  /// **'Permanently denied'**
  String get profileNotificationsDevicePermanentlyDenied;

  /// No description provided for @profileNotificationsDeviceRestricted.
  ///
  /// In en, this message translates to:
  /// **'Restricted'**
  String get profileNotificationsDeviceRestricted;

  /// No description provided for @profileNotificationsDeviceUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get profileNotificationsDeviceUnknown;

  /// No description provided for @profileNotificationsDeviceNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get profileNotificationsDeviceNotifications;

  /// No description provided for @profileNotificationsDeviceCamera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get profileNotificationsDeviceCamera;

  /// No description provided for @profileNotificationsDeviceMicrophone.
  ///
  /// In en, this message translates to:
  /// **'Microphone'**
  String get profileNotificationsDeviceMicrophone;

  /// No description provided for @profileNotificationsDevicePhotos.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get profileNotificationsDevicePhotos;

  /// No description provided for @profileNotificationsDeviceFiles.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get profileNotificationsDeviceFiles;

  /// No description provided for @supportChatLoadPreviousMessagesAction.
  ///
  /// In en, this message translates to:
  /// **'Load previous messages'**
  String get supportChatLoadPreviousMessagesAction;

  /// No description provided for @generationStatusCopyLinkAction.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get generationStatusCopyLinkAction;

  /// No description provided for @generationStatusShareFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Failed to share result. Please try again.'**
  String get generationStatusShareFailedMessage;

  /// No description provided for @generationStatusDeleteFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete result. Please try again.'**
  String get generationStatusDeleteFailedMessage;

  /// No description provided for @premiumSelectedBadge.
  ///
  /// In en, this message translates to:
  /// **'SELECTED'**
  String get premiumSelectedBadge;

  /// No description provided for @premiumBestValueBadge.
  ///
  /// In en, this message translates to:
  /// **'BEST VALUE'**
  String get premiumBestValueBadge;

  /// No description provided for @premiumStorePaymentDisclaimerTitle.
  ///
  /// In en, this message translates to:
  /// **'Secure payment via App Store / Google Play'**
  String get premiumStorePaymentDisclaimerTitle;

  /// No description provided for @premiumStorePaymentDisclaimerBody.
  ///
  /// In en, this message translates to:
  /// **'Payment will be charged to your App Store / Google Play account. Subscription renews automatically unless cancelled before the renewal date.'**
  String get premiumStorePaymentDisclaimerBody;

  /// No description provided for @premiumCardPaymentDisclaimerTitle.
  ///
  /// In en, this message translates to:
  /// **'Secure card payment'**
  String get premiumCardPaymentDisclaimerTitle;

  /// No description provided for @premiumCardPaymentDisclaimerBody.
  ///
  /// In en, this message translates to:
  /// **'Payment will be charged to your bank card. Subscription renews automatically unless cancelled before the renewal date.'**
  String get premiumCardPaymentDisclaimerBody;

  /// No description provided for @premiumCheckoutPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to Premium'**
  String get premiumCheckoutPageTitle;

  /// No description provided for @premiumCheckoutHeroBadge.
  ///
  /// In en, this message translates to:
  /// **'Premium subscription'**
  String get premiumCheckoutHeroBadge;

  /// No description provided for @premiumCheckoutHeroSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Recurring Premium access for unlimited templates and faster generation in PetMagic.'**
  String get premiumCheckoutHeroSubtitle;

  /// No description provided for @premiumCheckoutTokensPerPeriod.
  ///
  /// In en, this message translates to:
  /// **'{count} PawSpark every 7 days'**
  String premiumCheckoutTokensPerPeriod(Object count);

  /// No description provided for @premiumCheckoutIncludesTitle.
  ///
  /// In en, this message translates to:
  /// **'What you get'**
  String get premiumCheckoutIncludesTitle;

  /// No description provided for @premiumCheckoutIncludedTemplates.
  ///
  /// In en, this message translates to:
  /// **'Access to Premium templates'**
  String get premiumCheckoutIncludedTemplates;

  /// No description provided for @premiumCheckoutIncludedPriority.
  ///
  /// In en, this message translates to:
  /// **'Priority generation queue'**
  String get premiumCheckoutIncludedPriority;

  /// No description provided for @premiumCheckoutIncludedNoWatermark.
  ///
  /// In en, this message translates to:
  /// **'No watermark on exports'**
  String get premiumCheckoutIncludedNoWatermark;

  /// No description provided for @premiumCheckoutPaymentMethodSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Cards and available payment methods'**
  String get premiumCheckoutPaymentMethodSubtitle;

  /// No description provided for @premiumCheckoutTrustText.
  ///
  /// In en, this message translates to:
  /// **'Card data is securely processed by Stripe. PetMagic does not store your card details.'**
  String get premiumCheckoutTrustText;

  /// No description provided for @premiumCheckoutSummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Your subscription'**
  String get premiumCheckoutSummaryTitle;

  /// No description provided for @premiumCheckoutSummaryPlanLabel.
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get premiumCheckoutSummaryPlanLabel;

  /// No description provided for @premiumCheckoutSummaryPeriodLabel.
  ///
  /// In en, this message translates to:
  /// **'Billing period'**
  String get premiumCheckoutSummaryPeriodLabel;

  /// No description provided for @premiumCheckoutPeriodMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get premiumCheckoutPeriodMonthly;

  /// No description provided for @premiumCheckoutPeriodYearly.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get premiumCheckoutPeriodYearly;

  /// No description provided for @premiumCheckoutContinueAction.
  ///
  /// In en, this message translates to:
  /// **'Continue via {provider}'**
  String premiumCheckoutContinueAction(Object provider);

  /// No description provided for @premiumCheckoutPayAction.
  ///
  /// In en, this message translates to:
  /// **'Pay {price}'**
  String premiumCheckoutPayAction(Object price);

  /// No description provided for @premiumCheckoutTotalLabel.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get premiumCheckoutTotalLabel;

  /// No description provided for @premiumPaywallFeedbackTitle.
  ///
  /// In en, this message translates to:
  /// **'What stopped you from subscribing?'**
  String get premiumPaywallFeedbackTitle;

  /// No description provided for @premiumPaywallFeedbackCommentLabel.
  ///
  /// In en, this message translates to:
  /// **'Comment'**
  String get premiumPaywallFeedbackCommentLabel;

  /// No description provided for @premiumPaywallFeedbackCommentHint.
  ///
  /// In en, this message translates to:
  /// **'Tell us what would make Premium better for you'**
  String get premiumPaywallFeedbackCommentHint;

  /// No description provided for @premiumPaywallFeedbackSubmitAction.
  ///
  /// In en, this message translates to:
  /// **'Send feedback'**
  String get premiumPaywallFeedbackSubmitAction;

  /// No description provided for @premiumPaywallFeedbackThanksMessage.
  ///
  /// In en, this message translates to:
  /// **'Thanks! Your feedback helps improve Premium.'**
  String get premiumPaywallFeedbackThanksMessage;

  /// No description provided for @premiumPaywallFeedbackOptionExpensive.
  ///
  /// In en, this message translates to:
  /// **'Too expensive'**
  String get premiumPaywallFeedbackOptionExpensive;

  /// No description provided for @premiumPaywallFeedbackOptionLowValue.
  ///
  /// In en, this message translates to:
  /// **'Not enough value'**
  String get premiumPaywallFeedbackOptionLowValue;

  /// No description provided for @premiumPaywallFeedbackOptionPaymentProblem.
  ///
  /// In en, this message translates to:
  /// **'Payment problem'**
  String get premiumPaywallFeedbackOptionPaymentProblem;

  /// No description provided for @premiumPaywallFeedbackOptionJustBrowsing.
  ///
  /// In en, this message translates to:
  /// **'Just browsing'**
  String get premiumPaywallFeedbackOptionJustBrowsing;

  /// No description provided for @premiumPaywallFeedbackOptionOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get premiumPaywallFeedbackOptionOther;

  /// No description provided for @premiumBenefitAiGenerationsTitle.
  ///
  /// In en, this message translates to:
  /// **'40 PawSpark'**
  String get premiumBenefitAiGenerationsTitle;

  /// No description provided for @premiumBenefitAiGenerationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'every 7 days while Premium is active'**
  String get premiumBenefitAiGenerationsSubtitle;

  /// No description provided for @premiumBenefitPremiumTemplatesTitle.
  ///
  /// In en, this message translates to:
  /// **'Premium templates'**
  String get premiumBenefitPremiumTemplatesTitle;

  /// No description provided for @premiumBenefitPremiumTemplatesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'exclusive'**
  String get premiumBenefitPremiumTemplatesSubtitle;

  /// No description provided for @premiumBenefitPriorityVideoQueueTitle.
  ///
  /// In en, this message translates to:
  /// **'Priority video queue'**
  String get premiumBenefitPriorityVideoQueueTitle;

  /// No description provided for @premiumBenefitPriorityVideoQueueSubtitle.
  ///
  /// In en, this message translates to:
  /// **'faster results'**
  String get premiumBenefitPriorityVideoQueueSubtitle;

  /// No description provided for @premiumBenefitNoWatermarkTitle.
  ///
  /// In en, this message translates to:
  /// **'No watermark'**
  String get premiumBenefitNoWatermarkTitle;

  /// No description provided for @premiumBenefitNoWatermarkSubtitle.
  ///
  /// In en, this message translates to:
  /// **'clean exports'**
  String get premiumBenefitNoWatermarkSubtitle;

  /// No description provided for @premiumBenefitBiggerRewardsTitle.
  ///
  /// In en, this message translates to:
  /// **'Bigger rewards'**
  String get premiumBenefitBiggerRewardsTitle;

  /// No description provided for @premiumBenefitBiggerRewardsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'daily bonuses'**
  String get premiumBenefitBiggerRewardsSubtitle;

  /// No description provided for @subscriptionDangerZoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Danger zone'**
  String get subscriptionDangerZoneTitle;

  /// No description provided for @subscriptionCancelConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel subscription?'**
  String get subscriptionCancelConfirmTitle;

  /// No description provided for @subscriptionCancelConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Premium will stay active until {date}. New charges will be disabled.'**
  String subscriptionCancelConfirmBody(Object date);

  /// No description provided for @subscriptionCancelConfirmAction.
  ///
  /// In en, this message translates to:
  /// **'Confirm cancellation'**
  String get subscriptionCancelConfirmAction;

  /// No description provided for @subscriptionCancelConfirmKeep.
  ///
  /// In en, this message translates to:
  /// **'Keep Premium'**
  String get subscriptionCancelConfirmKeep;

  /// No description provided for @subscriptionRestoreSuccessMessage.
  ///
  /// In en, this message translates to:
  /// **'Purchases restored'**
  String get subscriptionRestoreSuccessMessage;

  /// No description provided for @subscriptionRestoreNoneFoundMessage.
  ///
  /// In en, this message translates to:
  /// **'No active subscription found'**
  String get subscriptionRestoreNoneFoundMessage;

  /// No description provided for @subscriptionPaymentTrustText.
  ///
  /// In en, this message translates to:
  /// **'Card data is securely processed by Stripe. PetMagic does not store your card data.'**
  String get subscriptionPaymentTrustText;

  /// No description provided for @subscriptionBillingPeriodLabel.
  ///
  /// In en, this message translates to:
  /// **'Billing period'**
  String get subscriptionBillingPeriodLabel;

  /// No description provided for @subscriptionBillingPeriodMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get subscriptionBillingPeriodMonthly;

  /// No description provided for @subscriptionBillingPeriodYearly.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get subscriptionBillingPeriodYearly;

  /// No description provided for @generationStatusWatermarkRemoved.
  ///
  /// In en, this message translates to:
  /// **'Watermark removed'**
  String get generationStatusWatermarkRemoved;

  /// No description provided for @generationStatusWatermarkAddedFreePlan.
  ///
  /// In en, this message translates to:
  /// **'Watermark added on the free plan'**
  String get generationStatusWatermarkAddedFreePlan;

  /// No description provided for @generationStatusShareWithWatermark.
  ///
  /// In en, this message translates to:
  /// **'Share with watermark'**
  String get generationStatusShareWithWatermark;

  /// No description provided for @generationStatusDownloadWithoutWatermark.
  ///
  /// In en, this message translates to:
  /// **'Download without watermark'**
  String get generationStatusDownloadWithoutWatermark;

  /// No description provided for @generationStatusSaveWithWatermark.
  ///
  /// In en, this message translates to:
  /// **'Save with watermark'**
  String get generationStatusSaveWithWatermark;

  /// No description provided for @generationStatusRemoveWatermark.
  ///
  /// In en, this message translates to:
  /// **'Remove watermark'**
  String get generationStatusRemoveWatermark;

  /// No description provided for @generationStatusRemovingWatermark.
  ///
  /// In en, this message translates to:
  /// **'Removing...'**
  String get generationStatusRemovingWatermark;

  /// No description provided for @generationStatusUpgradePremium.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to Premium'**
  String get generationStatusUpgradePremium;

  /// No description provided for @generationStatusRemoveWatermarkSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove watermark'**
  String get generationStatusRemoveWatermarkSheetTitle;

  /// No description provided for @generationStatusRemoveWatermarkSheetBody.
  ///
  /// In en, this message translates to:
  /// **'Use {cost} PawSpark for this result, or upgrade to Premium for clean downloads.'**
  String generationStatusRemoveWatermarkSheetBody(Object cost);

  /// No description provided for @generationStatusRemoveWatermarkUseCredit.
  ///
  /// In en, this message translates to:
  /// **'Use {cost} PawSpark'**
  String generationStatusRemoveWatermarkUseCredit(Object cost);

  /// No description provided for @generationStatusRemoveWatermarkFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not remove watermark. Please try again.'**
  String get generationStatusRemoveWatermarkFailed;

  /// No description provided for @generationStatusRemoveWatermarkNoCredits.
  ///
  /// In en, this message translates to:
  /// **'Not enough PawSpark. Top up PawSpark or upgrade to Premium.'**
  String get generationStatusRemoveWatermarkNoCredits;

  /// No description provided for @globalOfflineBannerTitle.
  ///
  /// In en, this message translates to:
  /// **'No internet connection'**
  String get globalOfflineBannerTitle;

  /// No description provided for @globalOfflineBannerMessage.
  ///
  /// In en, this message translates to:
  /// **'Some features are unavailable until your connection is restored.'**
  String get globalOfflineBannerMessage;

  /// No description provided for @globalOnlineRestoredBannerTitle.
  ///
  /// In en, this message translates to:
  /// **'Connection restored'**
  String get globalOnlineRestoredBannerTitle;

  /// No description provided for @globalOnlineRestoredBannerMessage.
  ///
  /// In en, this message translates to:
  /// **'You\'re back online.'**
  String get globalOnlineRestoredBannerMessage;

  /// No description provided for @appUnavailableOfflineTitle.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline'**
  String get appUnavailableOfflineTitle;

  /// No description provided for @appUnavailableOfflineMessage.
  ///
  /// In en, this message translates to:
  /// **'Check your connection and try again. We\'ll retry automatically when you\'re back online.'**
  String get appUnavailableOfflineMessage;

  /// No description provided for @appUnavailableServerTitle.
  ///
  /// In en, this message translates to:
  /// **'Server is unavailable'**
  String get appUnavailableServerTitle;

  /// No description provided for @appUnavailableServerMessage.
  ///
  /// In en, this message translates to:
  /// **'PetMagic is temporarily unavailable. Please try again in a moment.'**
  String get appUnavailableServerMessage;

  /// No description provided for @localBackendAndroidHintTitle.
  ///
  /// In en, this message translates to:
  /// **'Local backend on Android'**
  String get localBackendAndroidHintTitle;

  /// No description provided for @localBackendAndroidHintMessage.
  ///
  /// In en, this message translates to:
  /// **'This debug build points to {baseUrl}. On a real Android phone, localhost and 127.0.0.1 point to the phone itself. Run adb reverse tcp:{port} tcp:{port} or set API_BASE_URL to your computer\'s LAN IP.'**
  String localBackendAndroidHintMessage(Object baseUrl, Object port);

  /// No description provided for @generationStatusCompareAction.
  ///
  /// In en, this message translates to:
  /// **'Compare'**
  String get generationStatusCompareAction;

  /// No description provided for @generationStatusCompareBeforeLabel.
  ///
  /// In en, this message translates to:
  /// **'Before'**
  String get generationStatusCompareBeforeLabel;

  /// No description provided for @generationStatusCompareAfterLabel.
  ///
  /// In en, this message translates to:
  /// **'After'**
  String get generationStatusCompareAfterLabel;

  /// No description provided for @generationStatusCompareBeforeUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Original photo is no longer available.'**
  String get generationStatusCompareBeforeUnavailable;

  /// No description provided for @generationStatusCompareResultUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Result is unavailable.'**
  String get generationStatusCompareResultUnavailable;

  /// No description provided for @generationStatusCompareOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open comparison.'**
  String get generationStatusCompareOpenFailed;

  /// No description provided for @gamificationLevel.
  ///
  /// In en, this message translates to:
  /// **'Level {level}'**
  String gamificationLevel(Object level);

  /// No description provided for @gamificationXpProgress.
  ///
  /// In en, this message translates to:
  /// **'{current} / {total} XP'**
  String gamificationXpProgress(Object current, Object total);

  /// No description provided for @gamificationEvolutionEgg.
  ///
  /// In en, this message translates to:
  /// **'Egg'**
  String get gamificationEvolutionEgg;

  /// No description provided for @gamificationEvolutionBaby.
  ///
  /// In en, this message translates to:
  /// **'Baby'**
  String get gamificationEvolutionBaby;

  /// No description provided for @gamificationEvolutionTeen.
  ///
  /// In en, this message translates to:
  /// **'Teen'**
  String get gamificationEvolutionTeen;

  /// No description provided for @gamificationEvolutionAdult.
  ///
  /// In en, this message translates to:
  /// **'Adult'**
  String get gamificationEvolutionAdult;

  /// No description provided for @gamificationEvolutionLegendary.
  ///
  /// In en, this message translates to:
  /// **'Legendary'**
  String get gamificationEvolutionLegendary;

  /// No description provided for @gamificationLevelUp.
  ///
  /// In en, this message translates to:
  /// **'Level Up!'**
  String get gamificationLevelUp;

  /// No description provided for @gamificationStreakTitle.
  ///
  /// In en, this message translates to:
  /// **'Daily Streak'**
  String get gamificationStreakTitle;

  /// No description provided for @gamificationStreakDays.
  ///
  /// In en, this message translates to:
  /// **'{count} days'**
  String gamificationStreakDays(Object count);

  /// No description provided for @gamificationStreakAtRisk.
  ///
  /// In en, this message translates to:
  /// **'Your streak is at risk!'**
  String get gamificationStreakAtRisk;

  /// No description provided for @gamificationStreakFreeze.
  ///
  /// In en, this message translates to:
  /// **'Use Freeze'**
  String get gamificationStreakFreeze;

  /// No description provided for @gamificationStreakFreezeUsed.
  ///
  /// In en, this message translates to:
  /// **'Streak saved!'**
  String get gamificationStreakFreezeUsed;

  /// No description provided for @gamificationStreakFreezeRemaining.
  ///
  /// In en, this message translates to:
  /// **'{count} freezes remaining'**
  String gamificationStreakFreezeRemaining(Object count);

  /// No description provided for @gamificationAchievementsTitle.
  ///
  /// In en, this message translates to:
  /// **'Achievements'**
  String get gamificationAchievementsTitle;

  /// No description provided for @gamificationAchievementUnlocked.
  ///
  /// In en, this message translates to:
  /// **'Achievement Unlocked!'**
  String get gamificationAchievementUnlocked;

  /// No description provided for @gamificationAchievementSecret.
  ///
  /// In en, this message translates to:
  /// **'???'**
  String get gamificationAchievementSecret;

  /// No description provided for @gamificationAchievementProgress.
  ///
  /// In en, this message translates to:
  /// **'{current} / {target}'**
  String gamificationAchievementProgress(Object current, Object target);

  /// No description provided for @gamificationChallengeTitle.
  ///
  /// In en, this message translates to:
  /// **'Weekly Challenges'**
  String get gamificationChallengeTitle;

  /// No description provided for @gamificationChallengeComplete.
  ///
  /// In en, this message translates to:
  /// **'Complete!'**
  String get gamificationChallengeComplete;

  /// No description provided for @gamificationChallengeClaim.
  ///
  /// In en, this message translates to:
  /// **'Claim Reward'**
  String get gamificationChallengeClaim;

  /// No description provided for @gamificationChallengeGenerateImages.
  ///
  /// In en, this message translates to:
  /// **'Generate Images'**
  String get gamificationChallengeGenerateImages;

  /// No description provided for @gamificationChallengeGenerateImagesDesc.
  ///
  /// In en, this message translates to:
  /// **'Generate images using any template'**
  String get gamificationChallengeGenerateImagesDesc;

  /// No description provided for @gamificationChallengeTryTemplates.
  ///
  /// In en, this message translates to:
  /// **'Try Different Templates'**
  String get gamificationChallengeTryTemplates;

  /// No description provided for @gamificationChallengeTryTemplatesDesc.
  ///
  /// In en, this message translates to:
  /// **'Use different templates this week'**
  String get gamificationChallengeTryTemplatesDesc;

  /// No description provided for @gamificationChallengeShareCreations.
  ///
  /// In en, this message translates to:
  /// **'Share Creations'**
  String get gamificationChallengeShareCreations;

  /// No description provided for @gamificationChallengeShareCreationsDesc.
  ///
  /// In en, this message translates to:
  /// **'Share your creations with friends'**
  String get gamificationChallengeShareCreationsDesc;

  /// No description provided for @gamificationStatsGenerations.
  ///
  /// In en, this message translates to:
  /// **'Generations'**
  String get gamificationStatsGenerations;

  /// No description provided for @gamificationStatsDaysActive.
  ///
  /// In en, this message translates to:
  /// **'Days Active'**
  String get gamificationStatsDaysActive;

  /// No description provided for @gamificationStatsFavoriteTemplate.
  ///
  /// In en, this message translates to:
  /// **'Favorite Template'**
  String get gamificationStatsFavoriteTemplate;

  /// No description provided for @gamificationMilestone3.
  ///
  /// In en, this message translates to:
  /// **'3-day streak bonus: +{spark} Spark!'**
  String gamificationMilestone3(Object spark);

  /// No description provided for @gamificationMilestone7.
  ///
  /// In en, this message translates to:
  /// **'7-day streak bonus: +{spark} Spark!'**
  String gamificationMilestone7(Object spark);

  /// No description provided for @gamificationMilestone14.
  ///
  /// In en, this message translates to:
  /// **'14-day streak bonus: +{spark} Spark!'**
  String gamificationMilestone14(Object spark);

  /// No description provided for @gamificationMilestone30.
  ///
  /// In en, this message translates to:
  /// **'30-day streak bonus: +{spark} Spark!'**
  String gamificationMilestone30(Object spark);

  /// No description provided for @gamificationPetStats.
  ///
  /// In en, this message translates to:
  /// **'Pet Stats'**
  String get gamificationPetStats;

  /// No description provided for @gamificationTopPet.
  ///
  /// In en, this message translates to:
  /// **'Top Pet'**
  String get gamificationTopPet;

  /// No description provided for @gamificationYourProgress.
  ///
  /// In en, this message translates to:
  /// **'Your Progress'**
  String get gamificationYourProgress;

  /// No description provided for @gamificationBest.
  ///
  /// In en, this message translates to:
  /// **'Best'**
  String get gamificationBest;

  /// No description provided for @gamificationFreezeAvailable.
  ///
  /// In en, this message translates to:
  /// **'{count} freeze available'**
  String gamificationFreezeAvailable(Object count);

  /// No description provided for @gamificationFreezesAvailable.
  ///
  /// In en, this message translates to:
  /// **'{count} freezes available'**
  String gamificationFreezesAvailable(Object count);

  /// No description provided for @gamificationKeepGenerating.
  ///
  /// In en, this message translates to:
  /// **'Keep generating to unlock more!'**
  String get gamificationKeepGenerating;

  /// No description provided for @gamificationUnlocked.
  ///
  /// In en, this message translates to:
  /// **'{unlocked} / {total} Unlocked'**
  String gamificationUnlocked(Object total, Object unlocked);

  /// No description provided for @gamificationLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load achievements'**
  String get gamificationLoadFailed;

  /// No description provided for @gamificationDayStreak.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{0-day streak} one{{count}-day streak} other{{count}-day streak}}'**
  String gamificationDayStreak(int count);

  /// No description provided for @gamificationHubSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Track your streak, challenges and milestones in one place.'**
  String get gamificationHubSubtitle;

  /// No description provided for @gamificationHubEntrySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Streak, weekly goals and achievement milestones.'**
  String get gamificationHubEntrySubtitle;

  /// No description provided for @gamificationWeekFocusTitle.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get gamificationWeekFocusTitle;

  /// No description provided for @gamificationWeekFocusSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Keep momentum, finish challenges and protect your streak.'**
  String get gamificationWeekFocusSubtitle;

  /// No description provided for @gamificationNextMilestoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Next milestone'**
  String get gamificationNextMilestoneTitle;

  /// No description provided for @gamificationFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get gamificationFilterAll;

  /// No description provided for @gamificationFilterUnlocked.
  ///
  /// In en, this message translates to:
  /// **'Unlocked'**
  String get gamificationFilterUnlocked;

  /// No description provided for @gamificationFilterInProgress.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get gamificationFilterInProgress;

  /// No description provided for @gamificationFilterSecret.
  ///
  /// In en, this message translates to:
  /// **'Secret'**
  String get gamificationFilterSecret;

  /// No description provided for @gamificationNoAchievementsInFilter.
  ///
  /// In en, this message translates to:
  /// **'Nothing matches this filter yet.'**
  String get gamificationNoAchievementsInFilter;

  /// No description provided for @gamificationStatusUnlocked.
  ///
  /// In en, this message translates to:
  /// **'Unlocked'**
  String get gamificationStatusUnlocked;

  /// No description provided for @gamificationStatusInProgress.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get gamificationStatusInProgress;

  /// No description provided for @achievementFirstMagic.
  ///
  /// In en, this message translates to:
  /// **'First Magic'**
  String get achievementFirstMagic;

  /// No description provided for @achievementFirstMagicDesc.
  ///
  /// In en, this message translates to:
  /// **'Create your first AI generation'**
  String get achievementFirstMagicDesc;

  /// No description provided for @achievementApprentice10.
  ///
  /// In en, this message translates to:
  /// **'Apprentice'**
  String get achievementApprentice10;

  /// No description provided for @achievementApprentice10Desc.
  ///
  /// In en, this message translates to:
  /// **'Complete 10 generations'**
  String get achievementApprentice10Desc;

  /// No description provided for @achievementMagician100.
  ///
  /// In en, this message translates to:
  /// **'Magician'**
  String get achievementMagician100;

  /// No description provided for @achievementMagician100Desc.
  ///
  /// In en, this message translates to:
  /// **'Complete 100 generations'**
  String get achievementMagician100Desc;

  /// No description provided for @achievementArchmage500.
  ///
  /// In en, this message translates to:
  /// **'Archmage'**
  String get achievementArchmage500;

  /// No description provided for @achievementArchmage500Desc.
  ///
  /// In en, this message translates to:
  /// **'Complete 500 generations'**
  String get achievementArchmage500Desc;

  /// No description provided for @achievementStreak3.
  ///
  /// In en, this message translates to:
  /// **'Getting Warmed Up'**
  String get achievementStreak3;

  /// No description provided for @achievementStreak3Desc.
  ///
  /// In en, this message translates to:
  /// **'Maintain a 3-day streak'**
  String get achievementStreak3Desc;

  /// No description provided for @achievementStreak7.
  ///
  /// In en, this message translates to:
  /// **'Week Warrior'**
  String get achievementStreak7;

  /// No description provided for @achievementStreak7Desc.
  ///
  /// In en, this message translates to:
  /// **'Maintain a 7-day streak'**
  String get achievementStreak7Desc;

  /// No description provided for @achievementStreak14.
  ///
  /// In en, this message translates to:
  /// **'Two Week Champion'**
  String get achievementStreak14;

  /// No description provided for @achievementStreak14Desc.
  ///
  /// In en, this message translates to:
  /// **'Maintain a 14-day streak'**
  String get achievementStreak14Desc;

  /// No description provided for @achievementStreak30.
  ///
  /// In en, this message translates to:
  /// **'Monthly Master'**
  String get achievementStreak30;

  /// No description provided for @achievementStreak30Desc.
  ///
  /// In en, this message translates to:
  /// **'Maintain a 30-day streak'**
  String get achievementStreak30Desc;

  /// No description provided for @achievementPackLeader.
  ///
  /// In en, this message translates to:
  /// **'Pack Leader'**
  String get achievementPackLeader;

  /// No description provided for @achievementPackLeaderDesc.
  ///
  /// In en, this message translates to:
  /// **'Have 5 pets'**
  String get achievementPackLeaderDesc;

  /// No description provided for @achievementEvolutionBaby.
  ///
  /// In en, this message translates to:
  /// **'First Steps'**
  String get achievementEvolutionBaby;

  /// No description provided for @achievementEvolutionBabyDesc.
  ///
  /// In en, this message translates to:
  /// **'Evolve a pet to Baby stage'**
  String get achievementEvolutionBabyDesc;

  /// No description provided for @achievementEvolutionLegendary.
  ///
  /// In en, this message translates to:
  /// **'Legendary Guardian'**
  String get achievementEvolutionLegendary;

  /// No description provided for @achievementEvolutionLegendaryDesc.
  ///
  /// In en, this message translates to:
  /// **'Evolve a pet to Legendary stage'**
  String get achievementEvolutionLegendaryDesc;

  /// No description provided for @achievementTrendsetter.
  ///
  /// In en, this message translates to:
  /// **'Trendsetter'**
  String get achievementTrendsetter;

  /// No description provided for @achievementTrendsetterDesc.
  ///
  /// In en, this message translates to:
  /// **'Use Template of the Day'**
  String get achievementTrendsetterDesc;

  /// No description provided for @achievementDailyRitual.
  ///
  /// In en, this message translates to:
  /// **'Daily Ritual'**
  String get achievementDailyRitual;

  /// No description provided for @achievementDailyRitualDesc.
  ///
  /// In en, this message translates to:
  /// **'Generate 5 times in one day'**
  String get achievementDailyRitualDesc;

  /// No description provided for @achievementTemplateCollector.
  ///
  /// In en, this message translates to:
  /// **'Template Collector'**
  String get achievementTemplateCollector;

  /// No description provided for @achievementTemplateCollectorDesc.
  ///
  /// In en, this message translates to:
  /// **'Use 20 different templates'**
  String get achievementTemplateCollectorDesc;

  /// No description provided for @achievementNightOwl.
  ///
  /// In en, this message translates to:
  /// **'Night Owl'**
  String get achievementNightOwl;

  /// No description provided for @achievementNightOwlDesc.
  ///
  /// In en, this message translates to:
  /// **'Generate between 2 AM and 5 AM'**
  String get achievementNightOwlDesc;

  /// No description provided for @generationStatusGenerateSimilarCost.
  ///
  /// In en, this message translates to:
  /// **'Cost: {cost} PawSpark'**
  String generationStatusGenerateSimilarCost(Object cost);

  /// No description provided for @generationStatusGenerateSimilarConfirmAction.
  ///
  /// In en, this message translates to:
  /// **'Generate'**
  String get generationStatusGenerateSimilarConfirmAction;

  /// No description provided for @generationStatusGenerateSimilarCancelAction.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get generationStatusGenerateSimilarCancelAction;

  /// No description provided for @generationStatusGenerateSimilarSourceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Source file is unavailable.'**
  String get generationStatusGenerateSimilarSourceUnavailable;

  /// No description provided for @generationStatusGenerateSimilarInsufficientBalance.
  ///
  /// In en, this message translates to:
  /// **'Not enough PawSpark.'**
  String get generationStatusGenerateSimilarInsufficientBalance;

  /// No description provided for @generationStatusGenerateSimilarFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not generate. Please try again.'**
  String get generationStatusGenerateSimilarFailed;

  /// No description provided for @generationStatusFailedFeedbackTitle.
  ///
  /// In en, this message translates to:
  /// **'What happened?'**
  String get generationStatusFailedFeedbackTitle;

  /// No description provided for @generationStatusFailedFeedbackNotCompleted.
  ///
  /// In en, this message translates to:
  /// **'Did not finish'**
  String get generationStatusFailedFeedbackNotCompleted;

  /// No description provided for @generationStatusFailedFeedbackTooLong.
  ///
  /// In en, this message translates to:
  /// **'Too long'**
  String get generationStatusFailedFeedbackTooLong;

  /// No description provided for @generationStatusFailedFeedbackPawSparkCharged.
  ///
  /// In en, this message translates to:
  /// **'PawSpark were charged'**
  String get generationStatusFailedFeedbackPawSparkCharged;

  /// No description provided for @generationStatusFailedFeedbackStuck.
  ///
  /// In en, this message translates to:
  /// **'Stuck'**
  String get generationStatusFailedFeedbackStuck;

  /// No description provided for @generationStatusFailedFeedbackOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get generationStatusFailedFeedbackOther;

  /// No description provided for @generationStatusReportFeedbackTitle.
  ///
  /// In en, this message translates to:
  /// **'What is wrong with the result?'**
  String get generationStatusReportFeedbackTitle;

  /// No description provided for @generationStatusReportFeedbackLowQuality.
  ///
  /// In en, this message translates to:
  /// **'Low quality'**
  String get generationStatusReportFeedbackLowQuality;

  /// No description provided for @generationStatusReportFeedbackWrongPet.
  ///
  /// In en, this message translates to:
  /// **'Wrong pet'**
  String get generationStatusReportFeedbackWrongPet;

  /// No description provided for @generationStatusReportFeedbackDistortion.
  ///
  /// In en, this message translates to:
  /// **'Distortion'**
  String get generationStatusReportFeedbackDistortion;

  /// No description provided for @generationStatusReportFeedbackInappropriate.
  ///
  /// In en, this message translates to:
  /// **'Inappropriate'**
  String get generationStatusReportFeedbackInappropriate;

  /// No description provided for @generationStatusReportFeedbackWrongTemplate.
  ///
  /// In en, this message translates to:
  /// **'Wrong template'**
  String get generationStatusReportFeedbackWrongTemplate;

  /// No description provided for @generationStatusReportFeedbackWatermark.
  ///
  /// In en, this message translates to:
  /// **'Watermark'**
  String get generationStatusReportFeedbackWatermark;

  /// No description provided for @generationStatusReportFeedbackPayment.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get generationStatusReportFeedbackPayment;

  /// No description provided for @generationStatusReportFeedbackOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get generationStatusReportFeedbackOther;

  /// No description provided for @generationStatusCreateVideoFromResultAction.
  ///
  /// In en, this message translates to:
  /// **'Create video from this'**
  String get generationStatusCreateVideoFromResultAction;

  /// No description provided for @generationStatusGenerateSimilarAction.
  ///
  /// In en, this message translates to:
  /// **'Generate similar'**
  String get generationStatusGenerateSimilarAction;

  /// No description provided for @generationStatusGenerateSimilarLoading.
  ///
  /// In en, this message translates to:
  /// **'Creating a similar version...'**
  String get generationStatusGenerateSimilarLoading;

  /// No description provided for @generationStatusUseAsInputAction.
  ///
  /// In en, this message translates to:
  /// **'Use as input'**
  String get generationStatusUseAsInputAction;

  /// No description provided for @profileSettingsFeedbackTitle.
  ///
  /// In en, this message translates to:
  /// **'Send feedback'**
  String get profileSettingsFeedbackTitle;

  /// No description provided for @profileSettingsFeedbackSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Idea, bug, payment, or general comment'**
  String get profileSettingsFeedbackSubtitle;

  /// No description provided for @profileSettingsFeedbackSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Send feedback'**
  String get profileSettingsFeedbackSheetTitle;

  /// No description provided for @profileSettingsFeedbackMessageLabel.
  ///
  /// In en, this message translates to:
  /// **'Comment'**
  String get profileSettingsFeedbackMessageLabel;

  /// No description provided for @profileSettingsFeedbackMessageHint.
  ///
  /// In en, this message translates to:
  /// **'Add details if you want'**
  String get profileSettingsFeedbackMessageHint;

  /// No description provided for @profileSettingsFeedbackSubmitAction.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get profileSettingsFeedbackSubmitAction;

  /// No description provided for @profileSettingsFeedbackThanksMessage.
  ///
  /// In en, this message translates to:
  /// **'Thanks! Your feedback helps improve PetMagic.'**
  String get profileSettingsFeedbackThanksMessage;

  /// No description provided for @profileSettingsFeedbackOptionGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get profileSettingsFeedbackOptionGeneral;

  /// No description provided for @profileSettingsFeedbackOptionFeatureRequest.
  ///
  /// In en, this message translates to:
  /// **'Feature request'**
  String get profileSettingsFeedbackOptionFeatureRequest;

  /// No description provided for @profileSettingsFeedbackOptionBug.
  ///
  /// In en, this message translates to:
  /// **'Bug'**
  String get profileSettingsFeedbackOptionBug;

  /// No description provided for @profileSettingsFeedbackOptionPayment.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get profileSettingsFeedbackOptionPayment;

  /// No description provided for @profileNotificationsPushPhotoReadySubtitle.
  ///
  /// In en, this message translates to:
  /// **'When an AI photo is ready to view'**
  String get profileNotificationsPushPhotoReadySubtitle;

  /// No description provided for @profileNotificationsPushVideoReadySubtitle.
  ///
  /// In en, this message translates to:
  /// **'When an AI video finishes processing'**
  String get profileNotificationsPushVideoReadySubtitle;

  /// No description provided for @profileNotificationsPushGenerationErrorsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'If a generation finishes with an error'**
  String get profileNotificationsPushGenerationErrorsSubtitle;

  /// No description provided for @profileNotificationsPushRemindersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Reminders to use the app'**
  String get profileNotificationsPushRemindersSubtitle;

  /// No description provided for @profileNotificationsPushNewTemplatesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'New generation styles and templates'**
  String get profileNotificationsPushNewTemplatesSubtitle;

  /// No description provided for @profileNotificationsPushPurchasesAndSubscriptionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Payment confirmations and subscription status'**
  String get profileNotificationsPushPurchasesAndSubscriptionsSubtitle;

  /// No description provided for @profileNotificationsEmailOffersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Discounts, promotions, and special offers'**
  String get profileNotificationsEmailOffersSubtitle;

  /// No description provided for @profileNotificationsEmailNewsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'App updates and new features'**
  String get profileNotificationsEmailNewsSubtitle;

  /// No description provided for @profileNotificationsEmailAccountAlertsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Security alerts and account changes'**
  String get profileNotificationsEmailAccountAlertsSubtitle;

  /// No description provided for @passwordChangeStepRequestCode.
  ///
  /// In en, this message translates to:
  /// **'Request code'**
  String get passwordChangeStepRequestCode;

  /// No description provided for @passwordChangeStepNewPassword.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get passwordChangeStepNewPassword;

  /// No description provided for @subscriptionTokensWeeklyGrantPeriodSuffix.
  ///
  /// In en, this message translates to:
  /// **' / 7d'**
  String get subscriptionTokensWeeklyGrantPeriodSuffix;

  /// No description provided for @subscriptionGrantCountdownDaysHoursMinutes.
  ///
  /// In en, this message translates to:
  /// **'{days}d {hours}h {minutes}m'**
  String subscriptionGrantCountdownDaysHoursMinutes(
    int days,
    int hours,
    int minutes,
  );

  /// No description provided for @subscriptionGrantCountdownHoursMinutesSeconds.
  ///
  /// In en, this message translates to:
  /// **'{hours}h {minutes}m {seconds}s'**
  String subscriptionGrantCountdownHoursMinutesSeconds(
    int hours,
    int minutes,
    int seconds,
  );

  /// No description provided for @subscriptionGrantCountdownMinutesSeconds.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m {seconds}s'**
  String subscriptionGrantCountdownMinutesSeconds(int minutes, int seconds);

  /// No description provided for @subscriptionGrantReadyLabel.
  ///
  /// In en, this message translates to:
  /// **'Ready to grant!'**
  String get subscriptionGrantReadyLabel;

  /// No description provided for @subscriptionGrantNextLabel.
  ///
  /// In en, this message translates to:
  /// **'Next grant: {countdown}'**
  String subscriptionGrantNextLabel(String countdown);

  /// No description provided for @subscriptionBenefitTokensDescription.
  ///
  /// In en, this message translates to:
  /// **'Automatically every 7 days'**
  String get subscriptionBenefitTokensDescription;

  /// No description provided for @subscriptionBenefitFirstBonusDescription.
  ///
  /// In en, this message translates to:
  /// **'Instantly after purchase'**
  String get subscriptionBenefitFirstBonusDescription;

  /// No description provided for @subscriptionBenefitTemplatesDescription.
  ///
  /// In en, this message translates to:
  /// **'All scenarios unlocked'**
  String get subscriptionBenefitTemplatesDescription;

  /// No description provided for @subscriptionBenefitPriorityGenerationDescription.
  ///
  /// In en, this message translates to:
  /// **'Your jobs get priority'**
  String get subscriptionBenefitPriorityGenerationDescription;

  /// No description provided for @subscriptionBenefitNoWatermarkDescription.
  ///
  /// In en, this message translates to:
  /// **'Clean result'**
  String get subscriptionBenefitNoWatermarkDescription;

  /// No description provided for @generationStatusQueuePositionWithWait.
  ///
  /// In en, this message translates to:
  /// **'Queue position #{position} • {wait}'**
  String generationStatusQueuePositionWithWait(int position, String wait);

  /// No description provided for @generationStatusQueuePosition.
  ///
  /// In en, this message translates to:
  /// **'Queue position #{position}'**
  String generationStatusQueuePosition(int position);

  /// No description provided for @generationStatusWaitMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String generationStatusWaitMinutes(int minutes);

  /// No description provided for @generationStatusStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Generation cancelled'**
  String get generationStatusStatusCancelled;

  /// No description provided for @generationStatusTerminalCancelledHint.
  ///
  /// In en, this message translates to:
  /// **'Generation was cancelled before completion.'**
  String get generationStatusTerminalCancelledHint;

  /// No description provided for @templateFlowGenerationWaitTooLongTitle.
  ///
  /// In en, this message translates to:
  /// **'High load right now'**
  String get templateFlowGenerationWaitTooLongTitle;

  /// No description provided for @templateFlowGenerationWaitTooLongMessage.
  ///
  /// In en, this message translates to:
  /// **'The estimated wait for this generation is too long. Try again later or choose a photo generation, which is usually faster.'**
  String get templateFlowGenerationWaitTooLongMessage;

  /// No description provided for @templateFlowGenerationWaitTooLongRetryAfter.
  ///
  /// In en, this message translates to:
  /// **'Try again in about {value}.'**
  String templateFlowGenerationWaitTooLongRetryAfter(String value);

  /// No description provided for @templateFlowGenerationWaitTooLongPremiumHint.
  ///
  /// In en, this message translates to:
  /// **'Premium requests get priority when the service is busy and may wait less.'**
  String get templateFlowGenerationWaitTooLongPremiumHint;

  /// No description provided for @mediaPlayAction.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get mediaPlayAction;

  /// No description provided for @mediaPauseAction.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get mediaPauseAction;

  /// No description provided for @mediaMuteAction.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get mediaMuteAction;

  /// No description provided for @mediaUnmuteAction.
  ///
  /// In en, this message translates to:
  /// **'Unmute'**
  String get mediaUnmuteAction;
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
