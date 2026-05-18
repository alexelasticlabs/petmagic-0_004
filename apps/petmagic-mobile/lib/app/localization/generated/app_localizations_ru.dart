// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get navTemplates => 'Шаблоны';

  @override
  String get navCreations => 'Создания';

  @override
  String get navProfile => 'Профиль';

  @override
  String get comingSoonMessage =>
      'Раздел подготовлен для следующей продуктовой волны.';

  @override
  String get createMagicTitle => 'Создай магию';

  @override
  String get pickTemplateSubtitle => 'Выберите шаблон для питомца';

  @override
  String get searchTemplates => 'Поиск шаблонов';

  @override
  String get allFilter => 'Все';

  @override
  String get videosFilter => 'Видео';

  @override
  String get imagesFilter => 'Изображения';

  @override
  String get trendingFilter => '🔥 Тренды';

  @override
  String get funnyFilter => '😂 Смешные';

  @override
  String get danceFilter => '🕺 Танцы';

  @override
  String get magicFilter => '✣ Магия';

  @override
  String get adventureFilter => '🌄 Приключения';

  @override
  String get filtersTooltip => 'Фильтры';

  @override
  String get giftTooltip => 'Награды';

  @override
  String get addTokensTooltip => 'Добавить PawSpark';

  @override
  String get premiumLabel => 'Premium';

  @override
  String get freeLabel => 'Free';

  @override
  String get profileTitle => 'Ваш профиль';

  @override
  String get profileSubtitle =>
      'Управляйте входом и публичным аватаром пользователя.';

  @override
  String get profileSignInTitle => 'Войдите в аккаунт';

  @override
  String get profileSignInHint =>
      'Используйте аккаунт PetMagic, чтобы загрузить профиль и управлять аватаром, который виден в админке.';

  @override
  String get profileEmailLabel => 'Email';

  @override
  String get profilePasswordLabel => 'Пароль';

  @override
  String get profileSignInAction => 'Войти';

  @override
  String get profileSignOutAction => 'Выйти';

  @override
  String get profileLoadingAction => 'Сохранение...';

  @override
  String get profileAvatarUpload => 'Загрузить аватар';

  @override
  String get profileAvatarRemove => 'Удалить аватар';

  @override
  String get profileEmailConfirmed => 'Email подтвержден';

  @override
  String get profileEmailPending => 'Email не подтвержден';

  @override
  String get profileSignedOut => 'Вы вышли на этом устройстве.';

  @override
  String get magicLoadingPreparing => 'Готовим магию...';

  @override
  String get magicLoadingCutestAngle => 'Ищем самый милый ракурс...';

  @override
  String get magicLoadingAiPaws => 'Запускаем AI-лапки...';

  @override
  String get magicLoadingCreatingAdorable => 'Создаём что-то красивое...';

  @override
  String get magicLoadingAlmostReady => 'Почти готово...';

  @override
  String get videoLabel => 'Видео';

  @override
  String get imageLabel => 'Изображение';

  @override
  String get templatesErrorTitle => 'Шаблоны не загрузились';

  @override
  String get retryAction => 'Повторить';

  @override
  String get emptyTemplatesTitle => 'Шаблонов пока нет';

  @override
  String get emptyTemplatesMessage =>
      'Попробуйте другой фильтр или обновите каталог.';
}
