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
  String get navCreations => 'Creations';

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
  String get videosFilter => 'Videos';

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
  String get premiumLabel => 'Premium';

  @override
  String get freeLabel => 'Free';

  @override
  String get profileTitle => 'Your Profile';

  @override
  String get profileSubtitle => 'Manage sign-in and your public avatar.';

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
  String get videoLabel => 'Video';

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
}
