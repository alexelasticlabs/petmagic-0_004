// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get navDiscover => 'Обзор';

  @override
  String get navCreate => 'Создать';

  @override
  String get createHubTitle => 'Создайте магию с питомцем';

  @override
  String get createHubSubtitle =>
      'Начните с шаблона или питомца — дальше мы проведём вас по шагам.';

  @override
  String get createHubBrowseAction => 'Выбрать шаблон';

  @override
  String get createHubPetsAction => 'Выбрать питомца';

  @override
  String get createHubGuestHint =>
      'Сначала можно всё посмотреть. Если потребуется вход, выбранный сценарий сохранится.';

  @override
  String get navTemplates => 'Шаблоны';

  @override
  String get navCreations => 'Галерея';

  @override
  String get navRewards => 'Бонусы';

  @override
  String get navProfile => 'Профиль';

  @override
  String get notificationOpenAction => 'Открыть';

  @override
  String get notificationDefaultTitle => 'Обновление PetMagic';

  @override
  String get notificationSupportTitle => 'Поддержка PetMagic ответила';

  @override
  String get notificationGenerationTitle => 'Обновление генерации PetMagic';

  @override
  String get notificationWalletTitle => 'Обновление кошелька PetMagic';

  @override
  String get notificationPremiumTitle => 'Обновление Premium PetMagic';

  @override
  String get notificationSupportBody =>
      'Откройте чат поддержки, чтобы увидеть новый ответ.';

  @override
  String get notificationGenerationBody => 'Статус вашей генерации изменился.';

  @override
  String get notificationWalletBody =>
      'Откройте кошелёк, чтобы проверить последнее изменение баланса.';

  @override
  String get notificationPremiumBody =>
      'Откройте профиль, чтобы проверить последнее изменение Premium.';

  @override
  String get appUnexpectedErrorFallback =>
      'Что-то пошло не так. Попробуйте еще раз.';

  @override
  String get createMagicTitle => 'Создай магию';

  @override
  String get pickTemplateSubtitle => 'Выберите шаблон для питомца';

  @override
  String get searchTemplates => 'Поиск шаблонов';

  @override
  String get randomTemplateAction => 'Случайный шаблон';

  @override
  String get randomTemplateAny => 'Любой шаблон';

  @override
  String get randomTemplateImage => 'Шаблон изображения';

  @override
  String get randomTemplateVideo => 'Видео-шаблон';

  @override
  String get randomTemplateNoTemplates => 'Нет доступных шаблонов.';

  @override
  String get randomTemplateNoAvailableForType =>
      'Нет доступных шаблонов этого типа.';

  @override
  String get randomTemplateNoImageTemplates =>
      'Нет доступных шаблонов изображений.';

  @override
  String get randomTemplateNoVideoTemplates => 'Нет доступных видео-шаблонов.';

  @override
  String get randomTemplateLoadFailed =>
      'Не удалось загрузить шаблоны. Попробуйте ещё раз.';

  @override
  String get randomTemplateSheetDescription =>
      'Выберите, среди каких шаблонов искать случайный вариант.';

  @override
  String get randomTemplateTypeLabel => 'Тип шаблона';

  @override
  String get randomTemplateCategoryLabel => 'Категория';

  @override
  String get randomTemplateAccessLabel => 'Доступность';

  @override
  String get randomTemplateAccessAvailable => 'Все доступные';

  @override
  String get randomTemplateAccessFree => 'Бесплатные';

  @override
  String get randomTemplateAccessPremium => 'Премиум';

  @override
  String get randomTemplateFindAction => 'Найти случайный шаблон';

  @override
  String get randomTemplateFinding => 'Ищем случайный шаблон...';

  @override
  String get randomTemplateNoMatches => 'Нет шаблонов по выбранным параметрам.';

  @override
  String get randomTemplateNoMatchesHint =>
      'Попробуйте выбрать «Все» или другую категорию.';

  @override
  String get randomTemplateResetFilters => 'Сбросить параметры';

  @override
  String get templateOfTheDayTitle => 'Шаблон дня';

  @override
  String get templateOfTheDaySubtitle => 'Магическая идея дня';

  @override
  String get templateOfTheDayTryAction => 'Попробовать шаблон';

  @override
  String get templateOfTheDayFeedBadge => 'Выбор дня';

  @override
  String get templateOfTheDayLoadFailed => 'Не удалось загрузить шаблон дня.';

  @override
  String get allFilter => 'Все';

  @override
  String get templateFormatFilterLabel => 'Формат';

  @override
  String get templateCategoryFilterLabel => 'Категория';

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
  String get premiumLabel => 'Премиум';

  @override
  String get freeLabel => 'Бесплатно';

  @override
  String get profileTitle => 'Ваш профиль';

  @override
  String get profileSubtitle =>
      'Управляйте входом и публичным аватаром пользователя.';

  @override
  String get profileDashboardSubtitle =>
      'Управляйте аккаунтом и персонализируйте свой опыт в PetMagic.';

  @override
  String get profileSignInTitle => 'Войдите в аккаунт';

  @override
  String get profileSignInHint =>
      'Используйте аккаунт PetMagic, чтобы загрузить профиль и управлять аватаром, который виден в админке.';

  @override
  String get profileEmailLabel => 'Эл. почта';

  @override
  String get profilePasswordLabel => 'Пароль';

  @override
  String get authShowPassword => 'Показать пароль';

  @override
  String get authHidePassword => 'Скрыть пароль';

  @override
  String get authShowPasswordConfirmation => 'Показать подтверждение пароля';

  @override
  String get authHidePasswordConfirmation => 'Скрыть подтверждение пароля';

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
  String get profileAvatarSheetTitle => 'Фото профиля';

  @override
  String get profileAvatarPickFromGallery => 'Выбрать из галереи';

  @override
  String get profileAvatarTapToChange => 'Нажмите, чтобы изменить фото';

  @override
  String get profileAvatarCropTitle => 'Редактирование фото профиля';

  @override
  String get profileAvatarCropHint => 'Переместите и увеличьте фото';

  @override
  String get profileAvatarCropCancelAction => 'Отмена';

  @override
  String get profileAvatarCropSaveAction => 'Сохранить';

  @override
  String get profileAvatarCropResetAction => 'Сбросить';

  @override
  String get profileAvatarCropFitAction => 'Подогнать';

  @override
  String get profileAvatarCropLoading => 'Подготавливаем фото...';

  @override
  String get profileAvatarCropError =>
      'Не удалось обработать фото. Попробуйте другое изображение.';

  @override
  String get profileEmailConfirmed => 'Email подтвержден';

  @override
  String get profileEmailPending => 'Email не подтвержден';

  @override
  String get profileEmailVerifiedShort => 'Email подтвержден';

  @override
  String get profileEmailPendingShort => 'Подтвердите email';

  @override
  String get profileSignedOut => 'Вы вышли на этом устройстве.';

  @override
  String get profileAccountDeleted => 'Ваш аккаунт удален.';

  @override
  String get profileAccountCenterTitle => 'Центр аккаунта';

  @override
  String get profileAccountCenterSubtitle =>
      'Проверьте предпочтения, приватность и настройки приложения.';

  @override
  String get profileTermsStat => 'Условия приняты';

  @override
  String get profileMarketingStat => 'Новости и офферы';

  @override
  String get profileEmailStat => 'Статус email';

  @override
  String get profileStatOn => 'Вкл';

  @override
  String get profileStatOff => 'Выкл';

  @override
  String get profileStatReady => 'Готово';

  @override
  String get profileStatPending => 'Ожидает';

  @override
  String get profilePetsTitle => 'Мои питомцы';

  @override
  String get profilePetsSubtitle => 'Ваши любимцы и их профили в приложении.';

  @override
  String get petsAddTitle => 'Добавить питомца';

  @override
  String get petsEditTitle => 'Редактировать питомца';

  @override
  String get petsDetailsTitle => 'Питомец';

  @override
  String get petsCreateWithPetTitle => 'Создать с питомцем';

  @override
  String get petsManageAction => 'Управлять';

  @override
  String get petsAddAction => 'Добавить';

  @override
  String get petsSaveAction => 'Сохранить';

  @override
  String get petsNextAction => 'Далее';

  @override
  String get petsBackAction => 'Назад';

  @override
  String get petsDoneAction => 'Готово';

  @override
  String get petsCancelAction => 'Отмена';

  @override
  String get petsChangeAction => 'Сменить';

  @override
  String get petsStartAction => 'Начать';

  @override
  String get petsRetryAction => 'Повторить';

  @override
  String get petsNameLabel => 'Имя';

  @override
  String get petsNameStepTitle => 'Имя питомца';

  @override
  String get petsNameStepSubtitle => 'Дайте питомцу короткую кличку.';

  @override
  String get petsNameHint => 'Введите имя';

  @override
  String get petsNameExample => 'Например: Ричи, Мурка, Бадди';

  @override
  String get petsNameRequiredError => 'Введите имя питомца';

  @override
  String get petsTypeBreedTitle => 'Тип и порода';

  @override
  String get petsTypeBreedStepSubtitle =>
      'Выберите тип питомца и укажите породу, если знаете.';

  @override
  String get petsBreedLabel => 'Порода';

  @override
  String get petsBreedHint => 'Например: ши-тцу';

  @override
  String get petsPhotoLabel => 'Фото';

  @override
  String get petsPhotoStepTitle => 'Фото питомца';

  @override
  String get petsPhotoStepSubtitle =>
      'Загрузите чёткое фото, где хорошо видна мордочка.';

  @override
  String get petsDogType => 'Собака';

  @override
  String get petsCatType => 'Кошка';

  @override
  String get petsOtherType => 'Другое';

  @override
  String get petsChooseFirstPhotoAction => 'Выбрать первое фото';

  @override
  String get petsAddPhotoAction => 'Добавить фото';

  @override
  String get petsAddPhotoLaterHint =>
      'Фото можно добавить позже в профиле питомца.';

  @override
  String get petsPhotoFormatHint => 'JPG, PNG до 10 МБ';

  @override
  String get petsPhotoSelectedLabel => 'Фото выбрано';

  @override
  String get petsEmptyTitle => 'Добавьте первого питомца';

  @override
  String get petsEmptySubtitle =>
      'Сохраните профиль и фото, чтобы запускать генерацию в одно касание.';

  @override
  String get petsLoadErrorTitle => 'Не удалось загрузить питомцев';

  @override
  String get petsLoadPetErrorTitle => 'Не удалось загрузить питомца';

  @override
  String get petsLoadPhotosErrorTitle => 'Не удалось загрузить фото';

  @override
  String get petsLoadHistoryErrorTitle => 'Не удалось загрузить историю';

  @override
  String get petsNotFoundTitle => 'Питомец не найден';

  @override
  String get petsPhotosTitle => 'Фото';

  @override
  String get petsHistoryTitle => 'История генераций';

  @override
  String get petsNoPhotosTitle => 'Фото пока нет.';

  @override
  String get petsNoGenerationsTitle => 'Генераций пока нет.';

  @override
  String petsStatsPhotos(Object count) {
    return '$count фото';
  }

  @override
  String petsStatsGenerations(Object count) {
    return '$count генераций';
  }

  @override
  String get petsGenerateWithPet => 'Создать с питомцем';

  @override
  String petsGenerateWithName(Object name) {
    return 'Создать с $name';
  }

  @override
  String petsCreateWithName(Object name) {
    return 'Создать с $name';
  }

  @override
  String petsAddPhotoPrompt(Object name) {
    return 'Добавьте фото $name, чтобы начать';
  }

  @override
  String get petsDeleteTooltip => 'Удалить питомца';

  @override
  String get petsDeleteConfirmTitle => 'Удалить питомца?';

  @override
  String get petsDeleteConfirmMessage =>
      'Профиль питомца и сохранённые фото будут удалены.';

  @override
  String get petsDeleteConfirmAction => 'Удалить';

  @override
  String get petsAddPhotosTooltip => 'Добавить фото';

  @override
  String get petsSetAvatarTooltip => 'Сделать аватаром';

  @override
  String get petsMarkFavoriteTooltip => 'В избранное';

  @override
  String get petsUseForGenerationTooltip => 'Использовать для генерации';

  @override
  String get petsDeletePhotoTooltip => 'Удалить фото';

  @override
  String get petsAvatarBadge => 'Аватар';

  @override
  String get petsFavoriteBadge => 'Избранное';

  @override
  String get petsPhotoUpdateError => 'Не удалось обновить фото';

  @override
  String get petsUnsupportedPhotoTypeError => 'Этот тип фото не поддерживается';

  @override
  String get petsPhotoUploadError => 'Не удалось загрузить фото';

  @override
  String get petsOpenGenerationTooltip => 'Открыть';

  @override
  String get petsShareGenerationTooltip => 'Поделиться';

  @override
  String get petsUseGenerationAsInputTooltip => 'Использовать как исходник';

  @override
  String get petsTemplateFallback => 'Шаблон';

  @override
  String get petsUploadAction => 'Загрузить';

  @override
  String get petsChooseFromMyPetsAction => 'Выбрать из моих питомцев';

  @override
  String get petsActionSheetUploadSubtitle => 'Добавить фото или видео';

  @override
  String get petsActionSheetMyPetsSubtitle => 'Использовать питомца из профиля';

  @override
  String get petsActionSheetSourceTitle => 'Источник контента';

  @override
  String get petsActionSheetUploadSemantic => 'Загрузить фото или видео';

  @override
  String get petsActionSheetMyPetsSemantic => 'Выбрать питомца из профиля';

  @override
  String petsGenerationCostMessage(Object count) {
    return 'Генерация стоит $count PawSpark.';
  }

  @override
  String get petsNoPhotoStartMessage => 'Добавьте фото питомца, чтобы начать';

  @override
  String get petsFirstPetToast => 'Добавьте первого питомца';

  @override
  String get petsCouldNotLoadToast => 'Не удалось загрузить питомцев';

  @override
  String get petsAuthRequiredTitle => 'Сохраняйте и используйте питомцев';

  @override
  String get petsAuthRequiredMessage =>
      'Войдите или зарегистрируйтесь, чтобы сохранять профили питомцев и создавать с ними генерации.';

  @override
  String get profilePremiumTitle => 'Перейти на Premium';

  @override
  String get profilePremiumSubtitle =>
      'Откройте все шаблоны и premium-сценарии редактирования.';

  @override
  String get profilePremiumPlanLabel => 'Premium тариф';

  @override
  String get profileFreePlanLabel => 'Бесплатный тариф';

  @override
  String get profilePremiumBannerTitle => 'Перейти на Premium';

  @override
  String get profilePremiumBannerActiveTitle => 'Premium активен';

  @override
  String get profilePremiumBenefitUnlimitedTemplates => 'Безлимитные шаблоны';

  @override
  String get profilePremiumBenefitPriorityGeneration =>
      'Приоритетная генерация';

  @override
  String get profilePremiumBenefitNoWatermark => 'Без водяного знака';

  @override
  String get profilePremiumOpenAction => 'Открыть Premium';

  @override
  String get profileSubscriptionTitle => 'Моя подписка';

  @override
  String get profileSubscriptionStatusLabel => 'Статус';

  @override
  String get profileSubscriptionProviderLabel => 'Провайдер';

  @override
  String get profileSubscriptionNextBillingLabel => 'Следующее списание';

  @override
  String get profileSubscriptionTokensLabel => 'Доступно PawSpark';

  @override
  String get subscriptionStatusActive => 'Premium активен';

  @override
  String get subscriptionStatusCancelled => 'Отменён (до конца периода)';

  @override
  String get subscriptionStatusExpired => 'Истёк';

  @override
  String get subscriptionStatusPaymentFailed => 'Ошибка оплаты';

  @override
  String get subscriptionStatusPending => 'Платёж ожидается';

  @override
  String get subscriptionStatusInactive => 'Неактивна';

  @override
  String get subscriptionStartDateLabel => 'Начало подписки';

  @override
  String get subscriptionPeriodEndLabel => 'Оплачено до';

  @override
  String get subscriptionAutoRenewLabel => 'Автопродление';

  @override
  String get subscriptionAutoRenewOn => 'Включено';

  @override
  String get subscriptionAutoRenewOff => 'Отключено';

  @override
  String get subscriptionTokensSectionTitle => 'PawSpark в подписке';

  @override
  String get subscriptionTokensAvailableLabel => 'Доступно сейчас';

  @override
  String get subscriptionTokensPerPeriodLabel => 'Каждые 7 дней';

  @override
  String get subscriptionTokensNextGrantLabel => 'Следующее начисление';

  @override
  String subscriptionTokensCountdown(
    Object days,
    Object hours,
    Object minutes,
  ) {
    return 'Через $daysд $hoursч $minutesм';
  }

  @override
  String get subscriptionTokensExplanation =>
      'PawSpark начисляются каждые 7 дней с момента покупки подписки. Первый бонус начисляется сразу после покупки.';

  @override
  String get subscriptionBenefitsSectionTitle => 'Преимущества Premium';

  @override
  String get subscriptionBenefitTokens => '40 PawSpark каждые 7 дней';

  @override
  String get subscriptionBenefitFirstBonus =>
      'Первый бонус сразу после покупки';

  @override
  String get subscriptionBenefitTemplates => 'Доступ к Premium-шаблонам';

  @override
  String get subscriptionBenefitPriorityGeneration => 'Приоритетная генерация';

  @override
  String get subscriptionBenefitNoWatermark => 'Без водяного знака';

  @override
  String get subscriptionPaymentSectionTitle => 'Оплата';

  @override
  String get subscriptionPaymentMethodLabel => 'Способ оплаты';

  @override
  String get subscriptionPaymentCardLabel => 'Карта';

  @override
  String get subscriptionPaymentProviderStripe => 'Карта через Stripe';

  @override
  String get subscriptionPaymentProviderGooglePlay => 'Google Play';

  @override
  String get subscriptionPaymentProviderAppStore => 'App Store';

  @override
  String get subscriptionChangePaymentAction => 'Изменить способ оплаты';

  @override
  String get subscriptionCancelAction => 'Отменить подписку';

  @override
  String subscriptionCancelledHint(Object date) {
    return 'Подписка активна до $date. После этого автопродление не произойдёт.';
  }

  @override
  String get profileWalletTitle => 'Кошелек';

  @override
  String get profileWalletHistoryHint => 'Баланс, покупки и история операций.';

  @override
  String get walletPageTitle => 'PawSpark кошелек';

  @override
  String get walletPageSubtitle =>
      'Баланс, промокоды, бонус за рекламу и пополнение PawSpark.';

  @override
  String get profileWalletPreviewEyebrow => 'PawSpark';

  @override
  String get profileWalletPreviewSubtitle =>
      'Внутренняя валюта для генераций и бонусов.';

  @override
  String get profileWalletPreviewAction => 'Открыть';

  @override
  String get profileWalletPreviewLoadingStatus => 'Обновляем статус';

  @override
  String get profileWalletPreviewWeeklyReady => 'Недельная награда готова';

  @override
  String profileWalletPreviewAdCount(Object count) {
    return 'Реклама сегодня: $count';
  }

  @override
  String get profileWalletLoadingHint => 'Загружаем баланс...';

  @override
  String get profileWalletEmptyHint => 'Откройте баланс и историю';

  @override
  String get walletDataUnavailableFallback =>
      'Данные кошелька сейчас недоступны.';

  @override
  String get walletRefreshTooltip => 'Обновить кошелек';

  @override
  String get walletBalanceTitle =>
      'Доступно для создания фото, видео и premium-шаблонов.';

  @override
  String get walletBalanceEyebrow => 'Ваш баланс';

  @override
  String get walletBalanceUnit => 'PawSpark';

  @override
  String get walletBalanceExplanation =>
      'PawSpark — внутренняя валюта PetMagic. Используйте её для создания фото, видео и доступа к премиум-шаблонам.';

  @override
  String get walletPremiumStatus => 'Premium-кошелек';

  @override
  String get premiumUpsellHeadline => 'Premium выгоднее';

  @override
  String get premiumUpsellSubtitle =>
      '40 PawSpark каждую неделю\nБез водяного знака, экспорт высокого качества';

  @override
  String get premiumUpsellWeeklyCredits => '40 PawSpark каждую неделю';

  @override
  String get walletFreeStatus => 'Базовый кошелек';

  @override
  String walletAdRewardsCount(Object count) {
    return 'Наград за рекламу: $count';
  }

  @override
  String get walletQuickActionsTitle => 'Промокоды';

  @override
  String get walletRedeemAction => 'Активировать';

  @override
  String get walletRewardsTitle => 'Бонус за рекламу';

  @override
  String get walletAdRewardAction => 'Награда за рекламу';

  @override
  String get walletAdRewardCompactTitle => 'Получить PawSpark бесплатно';

  @override
  String get walletAdRewardCompactDescription =>
      'Посмотрите короткую рекламу и получите +15 PawSpark.';

  @override
  String walletAdRewardRemaining(Object count) {
    return 'Сегодня осталось: $count';
  }

  @override
  String get walletWatchAdAction => 'Смотреть рекламу +15';

  @override
  String get walletAdDailyLimitReached =>
      'Реклама сейчас недоступна. Попробуйте у нас позже.';

  @override
  String get walletBestValueBadge => 'Лучшая выгода';

  @override
  String get walletPremiumUpsellTitle => 'Создаете часто?';

  @override
  String get walletPremiumUpsellMessage =>
      'Premium дает ежемесячные PawSpark, premium-шаблоны и приоритетную очередь.';

  @override
  String get walletViewPremiumAction => 'Посмотреть Premium';

  @override
  String get walletContactSupportAction => 'Связаться с поддержкой';

  @override
  String get walletRetryAction => 'Повторить';

  @override
  String get rewardsPageTitle => 'Бонусы';

  @override
  String get rewardsPageSubtitle =>
      'Получайте PawSpark за промокоды и приглашения';

  @override
  String rewardsLastUpdatedLabel(Object value) {
    return 'Обновлено: $value';
  }

  @override
  String get rewardsLastUpdatedNow => 'только что';

  @override
  String rewardsLastUpdatedMinutes(Object count) {
    return '$count мин назад';
  }

  @override
  String rewardsLastUpdatedHours(Object count) {
    return '$count ч назад';
  }

  @override
  String get rewardsPromoTitle => 'Промокод';

  @override
  String get rewardsPromoSubtitle => 'Введите промокод и получите бонус';

  @override
  String get rewardsPromoEmptyError => 'Введите промокод.';

  @override
  String get rewardsPromoCheckingStatus => 'Проверяем код...';

  @override
  String get rewardsReferralTitle => 'Пригласи друга';

  @override
  String get rewardsReferralSubtitle =>
      'Поделитесь кодом с другом. Бонус начисляется не за регистрацию, а после его первой успешной платной покупки.';

  @override
  String get rewardsReferralInvitePrefix =>
      'Друг получит бонус перед первой покупкой, а вы получите';

  @override
  String get rewardsReferralInviteSuffix => 'после его первой успешной оплаты.';

  @override
  String get rewardsYourReferralCode => 'Ваш код';

  @override
  String get rewardsCopyReferralCodeAction => 'Скопировать';

  @override
  String get rewardsReferralCopiedMessage => 'Код скопирован.';

  @override
  String get rewardsReferralShareCodeAction => 'Поделиться кодом';

  @override
  String get rewardsReferralUseFriendCodeAction => 'Ввести код друга';

  @override
  String get rewardsReferralFriendCodePrompt => 'Есть код друга?';

  @override
  String get rewardsReferralFriendCodeHint =>
      'Введите код друга до первой покупки и получите бонус.';

  @override
  String get rewardsReferralInputLabel => 'Код друга';

  @override
  String get rewardsReferralInputHint => 'PMABC12345';

  @override
  String get rewardsReferralActivateAction => 'Активировать код';

  @override
  String get rewardsReferralEmptyError => 'Введите код друга.';

  @override
  String get rewardsReferralCheckingStatus => 'Проверяем реферальный код...';

  @override
  String get rewardsReferralActivatedMessage =>
      'Реферальный код активирован. Начисление произойдет после вашей первой успешной платной покупки.';

  @override
  String get rewardsReferralStatusLoading => 'Загружаем статус рефералки...';

  @override
  String get rewardsReferralStatusNone =>
      'Введите код друга перед первой покупкой. Бонус начисляется только после успешной оплаты.';

  @override
  String get rewardsReferralStatusPending =>
      'Рефералка подключена. Бонус начислится после вашей первой успешной платной покупки.';

  @override
  String get rewardsReferralStatusRewarded =>
      'Реферальный бонус начислен. Спасибо, что развиваете PetMagic.';

  @override
  String get rewardsReferralEarnedLabel => 'Заработано';

  @override
  String get rewardsReferralFriendsLabel => 'Друзей';

  @override
  String get rewardsReferralBonusLabel => 'Покупок друзей';

  @override
  String rewardsReferralBonusPerFriend(Object count) {
    return '+$count PawSpark за друга';
  }

  @override
  String get rewardsReferralRulesNote =>
      'Бонус начисляется после первой успешной покупки друга.';

  @override
  String get rewardsReferralHowItWorksAction => 'Как это работает?';

  @override
  String rewardsReferralShareMessage(Object bonus, Object code) {
    return 'Присоединяйся к PetMagic по моему коду $code. Бонус начисляется после первой успешной платной покупки. После твоей первой покупки я получу +$bonus PawSpark.';
  }

  @override
  String get rewardsHistoryTitle => 'История';

  @override
  String get rewardsHistorySubtitle =>
      'Последние промокоды, рефералки, реклама и еженедельные награды.';

  @override
  String get rewardsHistoryEmpty =>
      'Бонусов пока нет. Промокоды и реферальные награды появятся здесь.';

  @override
  String get rewardsSourcePromo => 'Промокод';

  @override
  String get rewardsSourceReferral => 'Реферальный бонус';

  @override
  String get rewardsSourceAd => 'Реклама';

  @override
  String get rewardsSourceWeekly => 'Еженедельная награда';

  @override
  String get rewardsSourcePremium => 'Premium начисление';

  @override
  String get rewardsSourceBonus => 'Бонус';

  @override
  String get rewardsReferralCodeNotFoundError => 'Реферальный код не найден.';

  @override
  String get rewardsReferralSelfError =>
      'Нельзя активировать собственный реферальный код.';

  @override
  String get rewardsReferralAlreadyLinkedError =>
      'Для этого аккаунта уже активирован реферальный код.';

  @override
  String get rewardsReferralPaidUserError =>
      'Реферальный код нужно активировать до первой успешной платной покупки.';

  @override
  String get walletBuySparkTitle => 'Пополнить PawSpark';

  @override
  String walletPackTotalSpark(Object count) {
    return '$count PawSpark';
  }

  @override
  String get walletPopularBadge => 'Популярно';

  @override
  String get walletBestValueLabel => 'Лучшее соотношение';

  @override
  String walletPackBonus(Object count) {
    return '+$count бонус';
  }

  @override
  String walletPackBonusPill(Object count) {
    return 'Бонус +$count';
  }

  @override
  String walletPackBaseSpark(Object count) {
    return '$count база';
  }

  @override
  String get walletPackStarterDescription => 'Для первых волшебных идей';

  @override
  String get walletPackCreatorDescription => 'Больше свободы для любимых идей';

  @override
  String get walletPackViralDescription => 'Максимум PawSpark для больших идей';

  @override
  String get walletPackStarterMotivation => 'Начните создавать уже сегодня.';

  @override
  String get walletPackCreatorMotivation =>
      'Больше поводов порадовать любимца.';

  @override
  String get walletPackViralMotivation => 'Воплощайте самые смелые задумки.';

  @override
  String walletBuyForPrice(Object price) {
    return 'Купить за $price';
  }

  @override
  String get walletPackDetailsAction => 'Подробнее';

  @override
  String get walletPackDetailSubtitle =>
      'Проверьте состав пакета перед переходом к оплате.';

  @override
  String get walletCheckoutHint =>
      'Оплата откроется в защищенном Stripe Checkout. После оплаты PawSpark сразу зачисляются на ваш баланс.';

  @override
  String get walletCheckoutProductSubtitle =>
      'Разовое пополнение вашего баланса PawSpark для создания фото и видео в PetMagic';

  @override
  String walletCheckoutTokensImmediately(Object count) {
    return '$count PawSpark сразу после оплаты';
  }

  @override
  String walletCheckoutBonusTokens(Object count) {
    return '+$count бонусных PawSpark в подарок';
  }

  @override
  String get walletCheckoutIncludesTitle => 'Что вы получите';

  @override
  String get walletCheckoutFeaturePremiumTemplates => 'Premium-шаблоны';

  @override
  String get walletCheckoutFeaturePriority => 'Приоритетная генерация';

  @override
  String get walletCheckoutFeatureMoreVideos => 'Больше возможностей для видео';

  @override
  String get walletCheckoutStripeMethodSubtitle =>
      'Карта, Apple Pay или Google Pay';

  @override
  String get walletCheckoutTrustText =>
      'PetMagic не хранит данные вашей карты. Платежи безопасно обрабатываются Stripe.';

  @override
  String get walletPaymentMethodChooseSubtitle =>
      'Выберите, как хотите пополнить PawSpark.';

  @override
  String get walletPaymentTrustTitle => 'Безопасная оплата';

  @override
  String get walletPaymentTrustStripeProcesses =>
      'Данные карты безопасно обрабатываются Stripe.';

  @override
  String get walletPaymentTrustNoStorage =>
      'PetMagic не хранит данные вашей карты.';

  @override
  String get walletPaymentTrustTopUpAnytime =>
      'Пополнить PawSpark можно в любой момент.';

  @override
  String get walletPaymentStoreUnavailableGooglePlay =>
      'Покупки через Google Play временно недоступны на этом устройстве. Выберите другой доступный способ оплаты.';

  @override
  String get walletPaymentStoreUnavailableAppStore =>
      'Покупки через App Store временно недоступны на этом устройстве. Выберите другой доступный способ оплаты.';

  @override
  String get walletCheckoutOrderSectionTitle => 'Ваше пополнение';

  @override
  String walletCheckoutSucceeded(Object spark) {
    return 'Оплата подтверждена. +$spark PawSpark уже в вашем кошельке.';
  }

  @override
  String walletPackBreakdown(Object base, Object bonus) {
    return '$base база + $bonus бонус';
  }

  @override
  String get walletRecentTransactionsTitle => 'Последние операции';

  @override
  String get walletViewAllTransactions => 'Все операции';

  @override
  String get walletNoActivity => 'Операций в кошельке пока нет.';

  @override
  String walletBalanceAfter(Object count) {
    return 'Баланс: $count';
  }

  @override
  String get walletPurchaseHistoryTitle => 'История покупок';

  @override
  String walletPurchaseSummary(Object count, Object date) {
    return '$count PawSpark • $date';
  }

  @override
  String get walletPurchaseJustConfirmed => 'Только что подтверждено';

  @override
  String get walletUnavailableTitle => 'Кошелек временно недоступен';

  @override
  String get walletTryAgainAction => 'Попробовать снова';

  @override
  String get walletPending => 'Ожидается';

  @override
  String get walletSourcePackPurchase => 'Пополнение';

  @override
  String get walletSourceGenerationSpend => 'Генерация';

  @override
  String get walletSourceGenerationRefund => 'Возврат за генерацию';

  @override
  String get walletSourceWeeklyGrant => 'Недельный бонус';

  @override
  String get walletSourceAdReward => 'Бонус за рекламу';

  @override
  String get walletSourcePromoCode => 'Промокод';

  @override
  String get walletSourceAdminGrant => 'Начисление поддержки';

  @override
  String get walletSourceAdminDebit => 'Корректировка поддержки';

  @override
  String get walletSourceOther => 'Другая операция';

  @override
  String get walletPurchaseCompleted => 'Завершено';

  @override
  String get walletPurchaseFailed => 'Ошибка';

  @override
  String get walletQueryFilterAll => 'Все';

  @override
  String get walletQueryFilterCredits => 'Зачисления';

  @override
  String get walletQueryFilterDebits => 'Списания';

  @override
  String get walletPartialActivityUnavailable =>
      'Баланс уже доступен. История и часть действий кошелька временно обновятся чуть позже.';

  @override
  String get walletPaymentGatewayUnavailableError =>
      'Платежи временно недоступны. Попробуйте позже или обновите приложение.';

  @override
  String get walletPaymentUnavailableError =>
      'Пополнение временно недоступно. Попробуйте позже.';

  @override
  String get walletPackUnavailableError =>
      'Этот набор PawSpark больше недоступен.';

  @override
  String get walletRedeemCodeNotFoundError => 'Промокод не найден.';

  @override
  String get walletRedeemCodeAlreadyUsedError =>
      'Этот промокод уже использован.';

  @override
  String get walletRedeemCodeExpiredError => 'Срок действия промокода истек.';

  @override
  String get walletRedeemCodeInactiveError =>
      'Этот промокод сейчас недоступен.';

  @override
  String get walletRedeemCodeExhaustedError =>
      'Лимит активаций этого промокода уже исчерпан.';

  @override
  String get walletRedeemCodeUserLimitError =>
      'Для этого пользователя лимит активаций промокода уже исчерпан.';

  @override
  String get walletRedeemOfflineError =>
      'Нет соединения с интернетом. Проверьте сеть и попробуйте снова.';

  @override
  String get walletRedeemServerError =>
      'Не удалось применить промокод из-за ошибки сервера. Попробуйте позже.';

  @override
  String get walletInsufficientBalanceError =>
      'Для этой операции недостаточно PawSpark.';

  @override
  String get walletUnavailableError =>
      'Данные кошелька временно недоступны. Попробуйте еще раз чуть позже.';

  @override
  String get walletRedeemSheetTitle => 'Промокод';

  @override
  String get walletRedeemSheetSubtitle =>
      'Код можно использовать один раз, если он активен и не истек.';

  @override
  String get walletRedeemInputLabel => 'Промокод';

  @override
  String get walletRedeemHint => 'Введите промокод';

  @override
  String get walletRedeemCancelAction => 'Отмена';

  @override
  String get walletApplyCode => 'Применить код';

  @override
  String get walletRedeemSuccessMessage =>
      'Промокод успешно применён. Баланс уже обновлён.';

  @override
  String get walletRedeemSuccessAction => 'Готово';

  @override
  String get profileStatsSectionTitle => 'Статистика аккаунта';

  @override
  String get profileStatBalanceLabel => 'Баланс';

  @override
  String get profileStatPlanLabel => 'Тариф';

  @override
  String get profileStatLegalLabel => 'Согласия';

  @override
  String get profileMagicMomentTitle => 'Ваш следующий звездный момент';

  @override
  String get profileMagicMomentSubtitle =>
      'Создайте что-то яркое для своих питомцев всего за пару касаний.';

  @override
  String get premiumPageTitle => 'PetMagic Premium';

  @override
  String get premiumPageSubtitle =>
      'Безлимитная магия для питомцев, быстрая генерация и premium-шаблоны в одном тарифе.';

  @override
  String get premiumHeroEyebrow => 'Premium магия';

  @override
  String get premiumHeroTitle => 'Откройте вирусные видео с питомцами';

  @override
  String get premiumHeroSubtitle =>
      'Больше генераций, premium-шаблоны, более быстрая обработка и без водяного знака.';

  @override
  String get premiumAlreadyActive => 'Premium активен';

  @override
  String get premiumBenefitUnlimitedTemplates => 'Безлимитные шаблоны';

  @override
  String get premiumBenefitFastGeneration => 'Быстрая генерация';

  @override
  String get premiumBenefitHighQuality => 'Высокое качество';

  @override
  String get premiumBenefitExclusive => 'Эксклюзивные шаблоны';

  @override
  String get premiumChoosePlanTitle => 'Выберите тариф';

  @override
  String get premiumWeeklyPlan => 'Еженедельный';

  @override
  String get premiumMonthlyPlan => 'Ежемесячный';

  @override
  String get premiumYearlyPlan => 'Годовой';

  @override
  String get premiumWeeklyPeriod => '/ неделя';

  @override
  String get premiumMonthlyPeriod => '/ месяц';

  @override
  String get premiumYearlyPeriod => '/ год';

  @override
  String get premiumPopularBadge => 'Самый популярный';

  @override
  String premiumTokensPerWeek(Object count) {
    return '$count PawSpark / неделя';
  }

  @override
  String premiumTokensPerMonth(Object count) {
    return '$count PawSpark / месяц';
  }

  @override
  String premiumDiscountLabel(Object percent) {
    return 'Экономия $percent%';
  }

  @override
  String get premiumCancelAnytime => 'Можно отменить в любой момент';

  @override
  String get premiumIncludesTitle => 'Что входит в Premium';

  @override
  String premiumTokenEstimate(Object photos, Object videos) {
    return 'Примерно $videos видео или $photos фото в месяц, в зависимости от сложности шаблона.';
  }

  @override
  String get premiumSocialProof =>
      'Самый популярный тариф для тех, кто регулярно создаёт контент в PetMagic.';

  @override
  String get premiumPaymentTitle => 'Способ оплаты';

  @override
  String get premiumPaymentChooseSubtitle =>
      'Выберите, как хотите оформить подписку';

  @override
  String get premiumPaymentStripe => 'Банковская карта';

  @override
  String get premiumPaymentStripeSubtitle =>
      'Оплата картой, Apple Pay или Google Pay';

  @override
  String get premiumPaymentGooglePlay => 'Google Play';

  @override
  String get premiumPaymentGooglePlaySubtitle => 'Оплата через Google Play';

  @override
  String get premiumPaymentApple => 'Apple Pay / App Store';

  @override
  String get premiumPaymentAppleSubtitle => 'Оплата через App Store';

  @override
  String get premiumPaymentOther => 'Другой способ оплаты';

  @override
  String get premiumPaymentRecommendedBadge => 'Рекомендуем';

  @override
  String get premiumPaymentDefaultBadge => 'По умолчанию';

  @override
  String get premiumPaymentTrustStripeProcesses =>
      'Данные карты безопасно обрабатываются Stripe.';

  @override
  String get premiumPaymentTrustNoStorage =>
      'PetMagic не хранит данные вашей карты.';

  @override
  String get premiumPaymentTrustManageInApp =>
      'Продление и отмена подписки управляются внутри PetMagic.';

  @override
  String paymentBonusPercentBadge(Object percent) {
    return '+$percent% бонус';
  }

  @override
  String get premiumComparisonTitle => 'Что меняется с Premium';

  @override
  String get premiumFreeColumn => 'Бесплатно';

  @override
  String get premiumPremiumColumn => 'Премиум';

  @override
  String get premiumComparisonFreeTemplates => 'Бесплатные шаблоны';

  @override
  String get premiumComparisonPremiumTemplates => 'Premium-шаблоны';

  @override
  String get premiumComparisonTokens => 'PawSpark в месяц';

  @override
  String premiumComparisonPremiumTokens(Object count) {
    return 'До $count';
  }

  @override
  String get premiumComparisonPremiumTokensFallback => '40 PawSpark / неделю';

  @override
  String get premiumComparisonFast => 'Быстрая генерация';

  @override
  String get premiumComparisonHighQuality => 'Экспорт высокого качества';

  @override
  String get premiumComparisonNoWatermark => 'Без водяного знака';

  @override
  String get premiumComparisonPrioritySupport => 'Приоритетная поддержка';

  @override
  String get premiumFreeSummaryTokens => '20 PawSpark в месяц';

  @override
  String get premiumFreeSummaryWatermark => 'Водяной знак';

  @override
  String get premiumFreeSummaryTemplates => 'Базовые шаблоны';

  @override
  String get premiumFreeSummaryQuality => 'Стандартное качество';

  @override
  String get premiumSecurePaymentTitle => 'Безопасная оплата';

  @override
  String get premiumSecurePaymentSubtitle =>
      'Управлять подпиской или отменить ее можно в настройках оплаты в любой момент.';

  @override
  String get premiumContinueAction => 'Разблокировать Premium';

  @override
  String paymentContinueViaProviderAction(Object provider) {
    return 'Продолжить через $provider';
  }

  @override
  String get paymentChooseAnotherMethodAction => 'Выбрать другой способ оплаты';

  @override
  String get externalCheckoutStripeTitle => 'Оплата через Stripe';

  @override
  String get externalCheckoutStripeMessage =>
      'Stripe Checkout откроется в защищенном встроенном браузере. После возврата в PetMagic мы автоматически проверим статус оплаты и только потом обновим подписку или баланс.';

  @override
  String get externalCheckoutContinueAction => 'Продолжить';

  @override
  String get externalCheckoutCheckingTitle => 'Проверяем оплату';

  @override
  String get externalCheckoutCheckingMessage =>
      'Ждем подтверждение от Stripe. Обычно это занимает несколько секунд.';

  @override
  String get externalCheckoutPendingVerificationMessage =>
      'Оплата еще не подтверждена. Мы обновим Premium или баланс сразу после подтверждения от Stripe.';

  @override
  String premiumContinueWithPlan(Object period, Object plan, Object price) {
    return 'Продолжить с тарифом $plan — $price $period';
  }

  @override
  String get premiumManageAction => 'Управлять подпиской';

  @override
  String get premiumRestoreAction => 'Восстановить покупки';

  @override
  String get premiumTermsNotice =>
      'Продолжая, вы соглашаетесь с Условиями использования и Политикой конфиденциальности.';

  @override
  String get premiumStoreUnavailable =>
      'Подписки через App Store / Google Play сейчас временно недоступны. Попробуйте позже или используйте другой доступный способ оплаты.';

  @override
  String get premiumStoreProductUnavailable =>
      'Этот тариф недоступен в магазине на текущем устройстве.';

  @override
  String get premiumStoreVerificationUnavailable =>
      'Проверка покупки через магазин временно недоступна.';

  @override
  String get premiumStorePurchaseInvalid => 'Покупку не удалось подтвердить.';

  @override
  String get premiumStorePurchaseInactive => 'Эта подписка больше не активна.';

  @override
  String get premiumPurchaseActivated => 'Premium уже активен.';

  @override
  String get premiumRecentlyActivatedBadge => 'Только что активирован';

  @override
  String get premiumRecentlyActivatedTitle => 'Premium подтвержден';

  @override
  String get premiumRecentlyActivatedMessage =>
      'Доступ Premium уже активен на этом устройстве и готов к использованию.';

  @override
  String get premiumPurchaseCancelled => 'Покупка была отменена.';

  @override
  String get premiumCheckoutFailed => 'Оформление Premium временно недоступно.';

  @override
  String get premiumManageFailed =>
      'Управление оплатой сейчас недоступно для этого аккаунта.';

  @override
  String get premiumRestoreStarted =>
      'Premium-статус обновлен на этом устройстве.';

  @override
  String get profileCommunicationsTitle => 'Обновления PetMagic';

  @override
  String get profileCommunicationsEnabled =>
      'Вы подписаны на продуктовые обновления и предложения.';

  @override
  String get profileCommunicationsDisabled =>
      'Маркетинговые обновления сейчас отключены.';

  @override
  String get profilePrivacyTitle => 'Приватность и согласия';

  @override
  String get profileTermsAccepted =>
      'Ваш аккаунт принял Условия использования и Политику конфиденциальности.';

  @override
  String get profileTermsPending => 'Проверьте согласия в настройках аккаунта.';

  @override
  String get profileLegalShortcutTitle => 'Приватность и правила';

  @override
  String get profileLegalShortcutAccepted =>
      'Условия приняты • Настройки приватности';

  @override
  String get profileLegalShortcutPending => 'Проверьте согласия';

  @override
  String get profileSupportTitle => 'Связаться с поддержкой';

  @override
  String get profileSupportSubtitle =>
      'Мы рядом, если нужна помощь с аккаунтом.';

  @override
  String get profileSupportCompactSubtitle =>
      'Помощь с оплатой и доступом к аккаунту.';

  @override
  String get profileSettingsShortcutTitle => 'Настройки';

  @override
  String get profileSettingsShortcutSubtitle =>
      'Управляйте языком, темой и разделами аккаунта.';

  @override
  String get profileSettingsCompactSubtitle =>
      'Язык, тема и настройки аккаунта.';

  @override
  String get profilePreferenceEnabled => 'Включено';

  @override
  String get profilePreferenceOff => 'Выкл';

  @override
  String get profileSettingsTitle => 'Настройки';

  @override
  String get profileSettingsSubtitle =>
      'Управляйте приложением и своим аккаунтом.';

  @override
  String get profileSettingsAccountSection => 'Аккаунт';

  @override
  String get profileSettingsNotificationsSection => 'Уведомления';

  @override
  String get profileSettingsPreferencesSection => 'Предпочтения';

  @override
  String get profileSettingsSupportSection => 'Поддержка';

  @override
  String get profileSettingsAboutSection => 'О приложении';

  @override
  String get profileSettingsDangerSection => 'Опасная зона';

  @override
  String get profileSettingsAccountInfoTitle => 'Информация об аккаунте';

  @override
  String get profileSettingsUnavailableSubtitle =>
      'Эта информация станет доступна после входа.';

  @override
  String get profileSettingsLinkedAccountsTitle => 'Связанные аккаунты';

  @override
  String get profileSettingsLinkedAccountsSubtitle =>
      'Добавьте способы входа, чтобы не потерять доступ к аккаунту.';

  @override
  String get profileSettingsPasswordTitle => 'Сменить пароль';

  @override
  String get profileSettingsPasswordSubtitle =>
      'Обновите пароль для защиты аккаунта.';

  @override
  String get profileSettingsNotificationsTitle => 'Настройки уведомлений';

  @override
  String get profileSettingsNotificationsSubtitle =>
      'Управляйте push и email-предпочтениями в приложении.';

  @override
  String get profileSettingsLanguageTitle => 'Язык приложения';

  @override
  String get profileSettingsLanguageSubtitle =>
      'Выберите язык интерфейса во всем приложении.';

  @override
  String get profileSettingsThemeTitle => 'Тема приложения';

  @override
  String get profileSettingsThemeSubtitle =>
      'Переключайтесь между системной, светлой и темной темой.';

  @override
  String get profileSettingsStorageTitle => 'Управление памятью';

  @override
  String get profileSettingsStorageSubtitle =>
      'Просматривайте и очищайте временные файлы на устройстве.';

  @override
  String get profileStorageUsageSection => 'Использование памяти';

  @override
  String get profileStorageDownloadedTitle => 'Скачанные работы';

  @override
  String profileStorageDownloadedSubtitle(Object size) {
    return 'Занято на устройстве: $size';
  }

  @override
  String profileStorageDownloadedItems(Object count) {
    return 'Доступно офлайн: $count';
  }

  @override
  String get profileStorageCleanupSection => 'Очистка памяти';

  @override
  String get profileStorageMediaCacheTitle => 'Временный медиакэш';

  @override
  String get profileStorageMediaCacheSubtitle =>
      'Изображения и превью будут загружены заново при необходимости.';

  @override
  String get profileStorageDownloadedClearSubtitle =>
      'Удаляет локальные копии; работы останутся в аккаунте.';

  @override
  String get profileStorageClearAction => 'Очистить';

  @override
  String get profileStorageClearMediaConfirmTitle =>
      'Очистить временный медиакэш?';

  @override
  String get profileStorageClearMediaConfirmBody =>
      'Кэшированные изображения и превью будут удалены с устройства.';

  @override
  String get profileStorageClearDownloadsConfirmTitle =>
      'Очистить скачанные работы?';

  @override
  String get profileStorageClearDownloadsConfirmBody =>
      'Будут удалены только локальные копии. Работы и ожидающие изменения останутся в аккаунте.';

  @override
  String get profileStorageClearSuccess => 'Локальная память очищена.';

  @override
  String get profileStorageSafetyNote =>
      'Данные аккаунта, настройки и работы на сервере не удаляются.';

  @override
  String get profileSettingsHelpCenterTitle => 'Центр помощи';

  @override
  String get profileSettingsHelpCenterSubtitle =>
      'Быстрые ответы и инструкции по частым вопросам.';

  @override
  String get profileSettingsSupportTitle => 'Связаться с поддержкой';

  @override
  String get profileSettingsSupportSubtitle =>
      'Напишите нам, если нужна помощь с оплатой или доступом.';

  @override
  String get profileSettingsTermsTitle => 'Пользовательское соглашение';

  @override
  String get profileSettingsTermsSubtitle =>
      'Изучите правила использования PetMagic.';

  @override
  String get profileSettingsPrivacyTitle => 'Политика конфиденциальности';

  @override
  String get profileSettingsPrivacySubtitle =>
      'Узнайте, как обрабатываются и защищаются ваши данные.';

  @override
  String get profileSettingsDeleteAccountTitle => 'Удалить аккаунт';

  @override
  String get profileSettingsDeleteAccountSubtitle =>
      'Это действие нельзя отменить.';

  @override
  String get profileAccountDetailsSubtitle =>
      'Проверьте данные аккаунта, которые сейчас доступны на этом устройстве.';

  @override
  String get profileAccountDetailsSection => 'Детали аккаунта';

  @override
  String get profileAccountUserIdLabel => 'ID пользователя';

  @override
  String get profileAccountDisplayNameLabel => 'Отображаемое имя';

  @override
  String get profileAccountDisplayNameMissing => 'Пока не задано';

  @override
  String get profileAccountRolesLabel => 'Роли';

  @override
  String get profileAccountRolesMissing => 'Роли не назначены';

  @override
  String get profileAccountRoleUser => 'Пользователь';

  @override
  String get profileAccountRoleModerator => 'Модератор';

  @override
  String get profileAccountRoleAdmin => 'Администратор';

  @override
  String get profileAccountMembershipLabel => 'Тариф';

  @override
  String get profileAccountConsentLabel => 'Принятие условий';

  @override
  String get profileAccountMarketingLabel => 'Новости и предложения';

  @override
  String get profileAccountAvatarLabel => 'Аватар';

  @override
  String get profileAccountAvatarMissing => 'Аватар не загружен';

  @override
  String get profileAccountAvatarUploaded => 'Аватар загружен';

  @override
  String get profileDetailsCurrentStatusSection => 'Текущий статус';

  @override
  String get profileDetailsNextStepSection => 'Что дальше';

  @override
  String get profileDetailsLinkedAccountsBody =>
      'Подключите Google или Apple, чтобы сохранить доступ к генерациям, покупкам и PawSpark на любом устройстве.';

  @override
  String get profileDetailsLinkedAccountsStatus =>
      'Выберите и подключите удобные способы входа для вашего аккаунта.';

  @override
  String get profileDetailsLinkedAccountsNext =>
      'Подключенные аккаунты помогают:\n✓ восстановить доступ\n✓ войти на новом устройстве\n✓ сохранить покупки и PawSpark\n✓ защитить аккаунт';

  @override
  String get profileLinkedAccountsLoading =>
      'Загружаем связанные способы входа...';

  @override
  String get profileLinkedAccountsConnectedStatus =>
      'Подключен и готов для входа.';

  @override
  String get profileLinkedAccountsNotConnectedStatus => 'Не подключен.';

  @override
  String get profileLinkedAccountsConnectAction => 'Подключить';

  @override
  String get profileLinkedAccountsDisconnectAction => 'Отключить';

  @override
  String get profileLinkedAccountsProtectedHint =>
      'Этот способ входа нельзя отключить, пока не подключен другой способ входа.';

  @override
  String get profileLinkedAccountsSignInRequired =>
      'Войдите снова, чтобы управлять связанными аккаунтами.';

  @override
  String get profileLinkedAccountsUnavailable =>
      'Связанные аккаунты временно недоступны.';

  @override
  String get profileDetailsNotificationsBody =>
      'Выберите, какие уведомления хотите получать в PetMagic.';

  @override
  String get profileDetailsNotificationsStatusEnabled =>
      'Уведомления включены для этого профиля.';

  @override
  String get profileDetailsNotificationsStatusDisabled =>
      'Уведомления отключены для этого профиля.';

  @override
  String get profileDetailsNotificationsNext =>
      'Вы можете менять push и email-настройки в любой момент.';

  @override
  String get profileNotificationsLoading =>
      'Загружаем настройки уведомлений...';

  @override
  String get profileNotificationsPushSection => 'Push-уведомления';

  @override
  String get profileNotificationsPushPhotoReady => 'Фото готово';

  @override
  String get profileNotificationsPushVideoReady => 'Видео готово';

  @override
  String get profileNotificationsPushGenerationErrors => 'Ошибки генерации';

  @override
  String get profileNotificationsPushReminders => 'Напоминания';

  @override
  String get profileNotificationsPushNewTemplates => 'Новые шаблоны';

  @override
  String get profileNotificationsPushPurchasesAndSubscriptions =>
      'Покупки и подписки';

  @override
  String get profileNotificationsEmailSection => 'Эл. почта';

  @override
  String get profileNotificationsEmailOffers => 'Акции и скидки';

  @override
  String get profileNotificationsEmailNews => 'Новости PetMagic';

  @override
  String get profileNotificationsEmailAccountAlerts =>
      'Важные уведомления аккаунта';

  @override
  String get profileNotificationsDeviceSection => 'Состояние устройства';

  @override
  String get profileNotificationsPushPermissionLabel => 'Push-разрешения';

  @override
  String get profileNotificationsPushPermissionAllowed => 'Разрешены';

  @override
  String get profileNotificationsPushPermissionDenied =>
      'Отключены в настройках устройства';

  @override
  String get profileNotificationsPushPermissionNotDetermined =>
      'Разрешение еще не запрашивалось';

  @override
  String get profileNotificationsPushPermissionProvisional =>
      'Разрешены в тихом режиме';

  @override
  String get profileNotificationsPushPermissionUnknown =>
      'Не удалось определить';

  @override
  String get profileNotificationsRefreshStatus => 'Обновить статус';

  @override
  String get profileNotificationsRequestPermission =>
      'Разрешить push-уведомления';

  @override
  String get profileDetailsHelpBody =>
      'Центр помощи соберет быстрые ответы, инструкции по настройке и подсказки по аккаунту в одном месте.';

  @override
  String get profileDetailsHelpStatus =>
      'Встроенная база знаний еще собирается, поэтому этот экран пока показывает текущий статус запуска.';

  @override
  String get profileDetailsHelpNext =>
      'Первые статьи помощи и инструкции по устранению проблем появятся здесь после публикации материалов для мобильной поддержки.';

  @override
  String get profileDetailsTermsBody =>
      'Проверьте, на каких правилах строится использование приложения и аккаунта PetMagic.';

  @override
  String get profileDetailsTermsStatusAccepted =>
      'Этот аккаунт уже принял Пользовательское соглашение во время регистрации.';

  @override
  String get profileDetailsTermsStatusPending =>
      'Для этого аккаунта еще не зафиксировано завершенное принятие условий.';

  @override
  String get profileDetailsTermsNext =>
      'Ниже можно просмотреть актуальное Пользовательское соглашение и принять последнюю версию, если для аккаунта это еще требуется.';

  @override
  String get profileDetailsPrivacyBody =>
      'Проверьте, как PetMagic хранит, защищает и использует данные аккаунта.';

  @override
  String get profileDetailsPrivacyStatus =>
      'На этом экране показаны актуальная Политика конфиденциальности, версия публикации и статус принятия для этого аккаунта.';

  @override
  String get profileDetailsPrivacyNext =>
      'Ниже можно просмотреть актуальную Политику конфиденциальности и принять последнюю версию, если для аккаунта это еще требуется.';

  @override
  String get profileLegalAcceptanceCurrent =>
      'Для этого аккаунта зафиксировано принятие актуальных юридических документов.';

  @override
  String get profileLegalAcceptanceRequired =>
      'Этому аккаунту нужно принять актуальные версии юридических документов.';

  @override
  String get profileLegalVersionLabel => 'Текущая версия';

  @override
  String get profileLegalPublishedLabel => 'Опубликовано';

  @override
  String get profileLegalAcceptedVersionLabel => 'Принятая версия';

  @override
  String get profileLegalAcceptedAtLabel => 'Дата принятия';

  @override
  String get profileLegalLoading =>
      'Загружаем актуальный юридический документ...';

  @override
  String get profileLegalUnavailable =>
      'Сейчас не удалось загрузить актуальный юридический документ.';

  @override
  String get profileLegalAcceptAction =>
      'Принять актуальные юридические документы';

  @override
  String get profileLegalAcceptanceGuestHint =>
      'Во время регистрации вы примете актуальные версии Пользовательского соглашения и Политики конфиденциальности.';

  @override
  String get profileLegalDocumentSection => 'Документ';

  @override
  String get profileLegalDocumentInfoSection => 'Информация о документе';

  @override
  String get profileLegalOpenFullAction => 'Открыть полную политику';

  @override
  String get profileLegalCompactHint =>
      'Сверху остается краткое резюме, а детали раскрываются только по нажатию.';

  @override
  String get profileLegalCurrentAcceptedHint =>
      'Для этого аккаунта сейчас не требуется дополнительное подтверждение.';

  @override
  String get profileLegalCompactSectionLabel => 'Нажмите, чтобы раскрыть';

  @override
  String get profilePrivacyQuickDataTitle => 'Что мы собираем';

  @override
  String get profilePrivacyQuickDataBody =>
      '• Email\n• Имя профиля\n• Историю генераций\n• Загруженные фото питомцев\n• Историю покупок\n• Обращения в поддержку';

  @override
  String get profilePrivacyQuickUsageTitle => 'Для чего используем';

  @override
  String get profilePrivacyQuickUsageBody =>
      '• Работа приложения\n• Генерация контента\n• Поддержка\n• Безопасность аккаунта и платежей';

  @override
  String get profilePrivacyQuickSharingTitle => 'Передаём ли данные?';

  @override
  String get profilePrivacyQuickSharingBody =>
      'Мы не продаём персональные данные. Передача возможна только сервисам-обработчикам, которые нужны для работы приложения (например, платежи, облачная инфраструктура, аналитика).';

  @override
  String get profilePrivacyQuickRightsTitle => 'Ваши права';

  @override
  String get profilePrivacyQuickRightsBody =>
      '• Запросить копию данных\n• Запросить удаление аккаунта и данных\n• Отозвать согласие, где это применимо';

  @override
  String get profileDetailsDeleteBody =>
      'Удаление аккаунта запускает необратимое удаление после подтверждения этого действия.';

  @override
  String get profileDetailsDeleteStatus =>
      'Удаление доступно с этого экрана и не может быть отменено. Продолжайте только если действительно готовы удалить аккаунт.';

  @override
  String get profileDetailsDeleteNext =>
      'Откройте окно подтверждения, прочитайте предупреждение и подтверждайте удаление только после того, как сохранили все нужные данные.';

  @override
  String get supportChatTitle => 'Чат поддержки';

  @override
  String get supportChatSubtitle =>
      'Пишите команде PetMagic напрямую из своего профиля.';

  @override
  String get supportChatSecureTitle =>
      'Ваш диалог защищен. Мы используем его только для поддержки.';

  @override
  String get supportChatSecureSubtitle =>
      'Мы бережно храним ваши данные и защищаем личную информацию.';

  @override
  String get supportChatTeamTitle => 'Поддержка PetMagic';

  @override
  String get supportChatTeamStatus => 'Обычно отвечаем в течение 24 часов';

  @override
  String get supportChatTodayLabel => 'Сегодня';

  @override
  String get supportChatInputHint => 'Опишите проблему...';

  @override
  String get supportChatSendAction => 'Отправить';

  @override
  String get supportChatEmptyTitle => 'Начните диалог';

  @override
  String get supportChatEmptyMessage =>
      'Чат поддержки уже готов. Отправьте первое сообщение, и команда ответит здесь.';

  @override
  String get supportChatWelcomeTitle =>
      'Здравствуйте! Опишите проблему, и мы поможем.';

  @override
  String get supportChatWelcomeBody =>
      'Вы также можете выбрать одну из частых тем ниже.';

  @override
  String get supportChatQuickActionGeneration =>
      'Проблема с генерацией изображения';

  @override
  String get supportChatQuickActionPayment => 'Проблема с оплатой';

  @override
  String get supportChatQuickActionRefund => 'Возврат средств';

  @override
  String get supportChatQuickActionHuman => 'Связаться с оператором';

  @override
  String get supportChatQuickActionSubscription => 'Проблема с подпиской';

  @override
  String get supportChatQuickActionVideo => 'Видео не создается';

  @override
  String get supportChatQuickActionTokens => 'Не пришли PawSpark';

  @override
  String get supportChatFaqTitle => 'FAQ';

  @override
  String get supportChatFaqGenerationTitle => 'Почему генерация не сработала?';

  @override
  String get supportChatFaqGenerationBody =>
      'Отправьте название шаблона, тип питомца и по возможности скриншот. Обычно этого хватает, чтобы поддержка сразу начала разбор.';

  @override
  String get supportChatFaqResponseTitle => 'Когда ответит поддержка?';

  @override
  String get supportChatFaqResponseBody =>
      'Команда поддержки ответит в этом же чате. Обычно мы возвращаемся с ответом в течение 24 часов.';

  @override
  String get supportChatFaqRefundTitle => 'Как работает возврат?';

  @override
  String get supportChatFaqRefundBody =>
      'Напишите дату заказа и причину обращения. Платежные вопросы разбираются прямо в этом диалоге без перехода в другой канал.';

  @override
  String get supportChatStatusOpen => 'Открыт';

  @override
  String get supportChatStatusInProgress => 'В работе';

  @override
  String get supportChatStatusResolved => 'Решен';

  @override
  String get supportChatStatusClosed => 'Закрыт';

  @override
  String get supportChatWaitingForSupportStatus => 'Ожидает поддержку';

  @override
  String get supportChatWaitingForSupportStatusHint =>
      'Запрос открыт. Команда поддержки увидит новое сообщение.';

  @override
  String get supportChatInProgressStatusHint => 'Поддержка изучает ваш вопрос.';

  @override
  String get supportChatAwaitingYourReplyStatus => 'Ожидает ваш ответ';

  @override
  String get supportChatSupportRepliedStatusHint =>
      'Поддержка ответила. Помогло ли это?';

  @override
  String get supportChatResolvedStatusHint =>
      'Обращение отмечено решенным. Его можно переоткрыть в течение 7 дней.';

  @override
  String get supportChatClosedStatusHint =>
      'Обращение закрыто. Если вопрос остался, напишите сообщение — мы откроем его снова.';

  @override
  String get supportChatMessageDelivered => 'Доставлено';

  @override
  String get supportChatMessageRead => 'Прочитано';

  @override
  String get supportChatUnavailableError =>
      'Сейчас не удается связаться с поддержкой. Попробуйте снова через минуту.';

  @override
  String get supportChatAttachmentUnavailableError =>
      'Сейчас не удается отправить вложение. Попробуйте снова через минуту.';

  @override
  String get supportChatAttachmentTooLargeError => 'Файл слишком большой';

  @override
  String get supportChatImageLabel => 'Изображение';

  @override
  String get supportChatSaveImageAction => 'Сохранить изображение';

  @override
  String get supportChatShareAction => 'Поделиться';

  @override
  String get supportChatOpenOriginalAction => 'Открыть оригинал';

  @override
  String get supportChatCloseAction => 'Закрыть';

  @override
  String get supportChatImageSavedMessage => 'Изображение сохранено';

  @override
  String get supportChatSaveImageFailedError =>
      'Не удалось сохранить изображение';

  @override
  String get supportChatShareImageFailedError =>
      'Не удалось поделиться изображением';

  @override
  String get supportChatAttachmentStatusUploading => 'Загрузка';

  @override
  String get supportChatAttachmentStatusUploaded => 'Загружено';

  @override
  String get supportChatAttachmentStatusFailed => 'Ошибка';

  @override
  String get supportChatAttachmentStatusRetry => 'Повтор';

  @override
  String supportChatAttachmentUploadingWithCount(Object current, Object total) {
    return 'Загружаем фото $current из $total';
  }

  @override
  String get supportChatImageUploadFailedLabel =>
      'Не удалось загрузить изображение';

  @override
  String get supportChatFileFallbackLabel => 'Файл';

  @override
  String get supportChatSystemNoticeTitle => 'Запрос отправлен';

  @override
  String get supportChatSystemNoticeBody =>
      'Спасибо, мы получили ваше сообщение. Поддержка ответит в этом чате.';

  @override
  String get supportChatComposerAttachmentChip =>
      'До 5 фото: JPG/PNG/WebP, до 10 МБ каждое';

  @override
  String get supportChatComposerResponseChip =>
      'Обычно отвечаем в течение нескольких часов';

  @override
  String get supportChatAddPhotoTitle => 'Добавить фото';

  @override
  String get supportChatAddAttachmentTitle => 'Добавить вложение';

  @override
  String get supportChatTakePhotoAction => 'Сделать фото';

  @override
  String get supportChatChooseGalleryAction => 'Выбрать из галереи';

  @override
  String get supportChatChoosePhotosAction => 'Выбрать фото';

  @override
  String get supportChatRecordVideoAction => 'Записать видео';

  @override
  String get supportChatChooseVideoAction => 'Выбрать видео';

  @override
  String get supportChatAttachFileAction => 'Файлы';

  @override
  String get supportChatRecentMediaTitle => 'Недавние медиа';

  @override
  String get supportChatAttachmentNoRecentMedia =>
      'Нет недавних фото или видео';

  @override
  String get supportChatAttachmentLimitedAccessHint =>
      'Доступны не все фото. Разрешите полный доступ к галерее в настройках устройства.';

  @override
  String get supportChatOpenSettingsAction => 'Открыть настройки';

  @override
  String get supportChatAttachmentNoGalleryAccessError =>
      'Нет доступа к галерее. Разрешите доступ в настройках устройства.';

  @override
  String get supportChatCameraPermissionPhotoError =>
      'Для съемки фото нужен доступ к камере.';

  @override
  String get supportChatCameraPermissionVideoError =>
      'Для записи видео нужен доступ к камере.';

  @override
  String get supportChatFilesPermissionError =>
      'Для добавления файлов нужен доступ к файлам.';

  @override
  String get permissionsAccessNeededTitle => 'Нужен доступ';

  @override
  String get permissionsOpenSettingsAction => 'Открыть настройки';

  @override
  String get permissionsGalleryAccessDeniedMessage =>
      'Разрешите доступ к галерее, чтобы выбрать фото.';

  @override
  String get permissionsGalleryAccessBlockedMessage =>
      'Доступ к галерее отключен. Откройте настройки устройства и разрешите его.';

  @override
  String get permissionsMediaAccessDeniedMessage =>
      'Разрешите доступ к фото и видео, чтобы добавить вложения.';

  @override
  String get permissionsMediaAccessBlockedMessage =>
      'Доступ к фото и видео отключен. Откройте настройки устройства и разрешите его.';

  @override
  String get permissionsCameraAccessDeniedMessage =>
      'Разрешите доступ к камере, чтобы сделать фото.';

  @override
  String get permissionsCameraAccessBlockedMessage =>
      'Доступ к камере отключен. Откройте настройки устройства и разрешите его.';

  @override
  String get permissionsCameraVideoAccessDeniedMessage =>
      'Разрешите доступ к камере, чтобы записать видео.';

  @override
  String get permissionsCameraVideoAccessBlockedMessage =>
      'Доступ к камере отключен. Откройте настройки устройства и разрешите запись видео.';

  @override
  String get permissionsMicrophoneAccessDeniedMessage =>
      'Разрешите доступ к микрофону, чтобы записать видео со звуком.';

  @override
  String get permissionsMicrophoneAccessBlockedMessage =>
      'Доступ к микрофону отключен. Откройте настройки устройства и разрешите запись видео со звуком.';

  @override
  String get supportChatAttachmentExpiredPlaceholder =>
      'Файл был удалён через 30 дней';

  @override
  String get supportChatReplyLabel => 'Ответ';

  @override
  String get supportChatReplyToPrefix => 'Ответ на сообщение';

  @override
  String get supportChatReplyOriginalUnavailable =>
      'Исходное сообщение недоступно';

  @override
  String get supportChatPhotoAttachedLabel => 'Фото прикреплено';

  @override
  String get supportChatVideoAttachedLabel => 'Видео прикреплено';

  @override
  String get supportChatVideoLabel => 'Видео';

  @override
  String get supportChatAssistantBadge => 'Ассистент';

  @override
  String get supportChatTooManyAttachmentsError =>
      'Можно добавить не более 5 файлов';

  @override
  String get supportChatAttachmentUnsupportedFormatError =>
      'Этот формат не поддерживается';

  @override
  String get supportChatAttachmentVideoTooLongError =>
      'Длительность видео должна быть не более 60 секунд.';

  @override
  String get supportChatMarkResolvedAction => 'Да, закрыть обращение';

  @override
  String get supportChatKeepOpenAction => 'Нет, написать ещё';

  @override
  String get supportChatCloseRequestDialogTitle => 'Закрыть обращение?';

  @override
  String get supportChatCloseRequestDialogBody =>
      'Если проблема решена, мы закроем этот диалог. Вы сможете создать новое обращение позже.';

  @override
  String get supportChatCloseConfirmAction => 'Закрыть';

  @override
  String get supportChatCancelAction => 'Отмена';

  @override
  String get supportChatConversationClosedLabel => 'Обращение закрыто';

  @override
  String get supportChatReopenAction => 'Написать снова';

  @override
  String get supportChatArchiveAction => 'В архив';

  @override
  String get supportChatRateTitle => 'Оцените ответ поддержки';

  @override
  String supportChatRatedLabel(Object rating) {
    return 'Ваша оценка: $rating/5';
  }

  @override
  String get supportChatReadOnlyHint => 'Диалог доступен только для просмотра';

  @override
  String get supportHomeTitle => 'Помощь и поддержка';

  @override
  String get supportHomeSubtitle => 'Чем мы можем помочь?';

  @override
  String get supportHomeOpenChatAction => 'Открыть чат';

  @override
  String get supportHomeTopicGenerationIssue =>
      'Проблема с генерацией изображения';

  @override
  String get supportHomeTopicGenerationTooLong =>
      'Генерация занимает слишком долго';

  @override
  String get supportHomeTopicTokensNotArrived => 'PawSpark не пришли';

  @override
  String get supportHomeTopicPremiumIssue => 'Проблема с Premium';

  @override
  String get supportHomeTopicPaymentRefund => 'Оплата / Возврат';

  @override
  String get supportHomeTopicOther => 'Другое';

  @override
  String get supportAssistantTitle => 'Ассистент поддержки';

  @override
  String get supportAssistantThisHelpedAction => 'Это помогло';

  @override
  String get supportAssistantCreateTicketAction => 'Создать обращение';

  @override
  String get supportAssistantCheckLaterAction => 'Проверить позже';

  @override
  String get supportAssistantRecommendationGeneration =>
      'Для лучшего результата используйте фото, где питомец хорошо виден, не обрезан, не размыт и при хорошем освещении.';

  @override
  String get supportAssistantRecommendationGenerationTooLong =>
      'Генерация видео может занять несколько минут — обычно от 2 до 10 минут. Если прошло слишком много времени, мы можем передать этот вопрос в поддержку.';

  @override
  String get supportAssistantRecommendationTokensNotArrived =>
      'Иногда PawSpark после оплаты поступают с задержкой в несколько минут. Если PawSpark так и не появились, создайте обращение, и мы проверим платёж.';

  @override
  String get supportAssistantRecommendationPremiumIssue =>
      'Если Premium уже оплачен, но не отображается в приложении, попробуйте перезапустить приложение. Если проблема сохраняется, мы проверим статус подписки.';

  @override
  String get supportAssistantRecommendationPaymentRefund =>
      'Мы можем проверить ваш платёж или передать запрос на возврат в поддержку. Создайте обращение, и мы прикрепим информацию о покупке, если она доступна.';

  @override
  String get supportAssistantRecommendationOther =>
      'Опишите, что произошло. Вы также можете приложить скриншот, чтобы поддержка быстрее разобралась в ситуации.';

  @override
  String get supportTicketFormTitle => 'Создать обращение';

  @override
  String get supportTicketFormTopicLabel => 'Тема';

  @override
  String get supportTicketFormDescriptionLabel => 'Описание проблемы';

  @override
  String get supportTicketFormDescriptionHint => 'Опишите, что произошло...';

  @override
  String get supportTicketFormRelatedGenerationLabel => 'Связанная генерация';

  @override
  String get supportTicketFormRelatedPaymentLabel => 'Связанный платёж';

  @override
  String get supportTicketFormRelatedSubscriptionLabel => 'Связанная подписка';

  @override
  String get supportTicketFormAttachmentsLabel => 'Вложения';

  @override
  String get supportTicketFormAddScreenshotAction => 'Добавить скриншот';

  @override
  String get supportTicketFormSubmitAction => 'Отправить в поддержку';

  @override
  String get supportTicketFormSubmittingLabel => 'Создание обращения...';

  @override
  String get supportTicketFormSuccessMessage =>
      'Ваше обращение создано. Мы ответим в этом чате.';

  @override
  String get supportTicketFormErrorMessage =>
      'Не удалось создать обращение. Попробуйте ещё раз.';

  @override
  String get profileSettingsThemeSystem => 'Системная';

  @override
  String get profileSettingsThemeLight => 'Светлая';

  @override
  String get profileSettingsThemeDark => 'Темная';

  @override
  String get profileSettingsLanguageRussian => 'Русский';

  @override
  String get profileSettingsLanguageEnglish => 'Английский';

  @override
  String get profileSettingsLanguageGerman => 'Немецкий';

  @override
  String get profileSettingsLanguageSpanish => 'Испанский';

  @override
  String get profileSettingsLanguageFrench => 'Французский';

  @override
  String get profileSettingsLanguageItalian => 'Итальянский';

  @override
  String get profileSettingsLanguagePolish => 'Польский';

  @override
  String profileSettingsVersionLabel(Object version) {
    return 'Версия приложения $version';
  }

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
  String get closeAction => 'Закрыть';

  @override
  String get emptyTemplatesTitle => 'Шаблонов пока нет';

  @override
  String get emptyTemplatesMessage =>
      'Попробуйте другой фильтр или обновите каталог.';

  @override
  String get templatesFeedEmptyError => 'Шаблоны временно недоступны.';

  @override
  String get templatesConnectionTimeoutError =>
      'Нет подключения. Проверьте сеть и попробуйте снова.';

  @override
  String get templatesServerTimeoutError =>
      'Сервер отвечает слишком долго. Попробуйте снова.';

  @override
  String get templatesRequestFailedError =>
      'Сейчас не удалось загрузить шаблоны. Попробуйте снова.';

  @override
  String get startupOnboardingActionContinueGuest => 'Продолжить как гость';

  @override
  String get startupOnboardingActionNext => 'Далее';

  @override
  String get startupOnboardingActionStart => 'Начать';

  @override
  String get startupOnboardingPageOneTitle =>
      'Создавайте магические моменты с питомцем';

  @override
  String get startupOnboardingPageOneSubtitle =>
      'Превращайте обычные кадры в яркие вирусные истории с шаблонами, созданными для питомцев.';

  @override
  String get startupOnboardingPageOneHighlightOne => 'Трендовые шаблоны';

  @override
  String get startupOnboardingPageOneHighlightTwo => 'Быстрый старт';

  @override
  String get startupOnboardingPageOneHighlightThree => 'Тёплый pet-style';

  @override
  String get startupOnboardingPageTwoTitle =>
      'Сначала смотрите, потом открывайте больше';

  @override
  String get startupOnboardingPageTwoSubtitle =>
      'Листайте каталог как гость, а вход выполните тогда, когда захотите рендерить, сохранять и открывать premium.';

  @override
  String get startupOnboardingPageTwoHighlightOne => 'Гостевой просмотр';

  @override
  String get startupOnboardingPageTwoHighlightTwo => 'Вход в один тап';

  @override
  String get startupOnboardingPageTwoHighlightThree => 'Плавный переход';

  @override
  String get startupOnboardingPageThreeTitle => 'PawSpark и premium ждут позже';

  @override
  String get startupOnboardingPageThreeSubtitle =>
      'Первое знакомство должно быть лёгким. PawSpark, награды и premium-действия откроются после аккуратной авторизации.';

  @override
  String get startupOnboardingPageThreeHighlightOne => 'Premium-фишки';

  @override
  String get startupOnboardingPageThreeHighlightTwo => 'Баланс PawSpark';

  @override
  String get startupOnboardingPageThreeHighlightThree => 'Бонусы автора';

  @override
  String get startupMiniFeatureFastStart => 'Быстрый старт';

  @override
  String get startupMiniFeaturePetFirst => 'Сначала питомец';

  @override
  String get startupMiniFeatureUpgradeLater => 'Апгрейд позже';

  @override
  String get startupWelcomeViewOnboarding => 'Показать onboarding';

  @override
  String get startupWelcomeTitle =>
      'Создавайте магические видео с вашим питомцем';

  @override
  String get startupWelcomeSubtitle =>
      'Выберите шаблон, добавьте фото питомца и получите готовое AI-видео за пару минут.';

  @override
  String get startupWelcomeContinueGuest => 'Продолжить как гость';

  @override
  String get startupWelcomeTemplatesTitle => 'Выберите шаблон';

  @override
  String get startupWelcomeTemplatesSubtitle =>
      'Тренды, мемы и сезонные сцены для любого настроения.';

  @override
  String get startupWelcomeAiTitle => 'Добавьте фото питомца';

  @override
  String get startupWelcomeAiSubtitle =>
      'Одного фото достаточно, чтобы AI собрал стиль и движение.';

  @override
  String get startupWelcomeShareTitle => 'Получите готовое видео';

  @override
  String get startupWelcomeShareSubtitle =>
      'Ролик будет готов для публикации и сохранения в один тап.';

  @override
  String get startupWelcomeGuestHint =>
      'Можно начать без аккаунта. Регистрация понадобится для сохранения истории и доступа к покупкам.';

  @override
  String get authEntryTitle => 'С возвращением!';

  @override
  String get authEntrySubtitle =>
      'Войдите, чтобы продолжить магию для вашего питомца.';

  @override
  String get authRegisterTitle => 'Создайте аккаунт';

  @override
  String get authRegisterSubtitle =>
      'Присоединяйтесь к PetMagic и откройте шаблоны, PawSpark и premium-возможности.';

  @override
  String get authRegisterAction => 'Зарегистрироваться';

  @override
  String get authDisplayNameLabel => 'Имя профиля (необязательно)';

  @override
  String get authConfirmPasswordLabel => 'Подтвердите пароль';

  @override
  String get authPasswordRulesHint =>
      'Используйте минимум 8 символов, заглавную и строчную буквы и цифру.';

  @override
  String get authPasswordTooShort =>
      'Пароль должен содержать минимум 8 символов.';

  @override
  String get authPasswordPolicyInvalid =>
      'Пароль должен содержать минимум 8 символов, заглавную и строчную буквы и цифру.';

  @override
  String get authForgotPasswordAction => 'Забыли пароль?';

  @override
  String get authPasswordResetTitle => 'Восстановление пароля';

  @override
  String get authPasswordResetSubtitle =>
      'Введите email, и мы отправим код для сброса пароля.';

  @override
  String get authPasswordResetCodeTitle => 'Введите код из письма';

  @override
  String get authPasswordResetCodeSubtitle =>
      'Укажите код и задайте новый пароль для входа.';

  @override
  String get authPasswordResetCodeLabel => 'Код из письма';

  @override
  String get authPasswordResetRequestAction => 'Отправить код';

  @override
  String get authPasswordResetConfirmAction => 'Сохранить новый пароль';

  @override
  String get authPasswordResetResendAction => 'Отправить код повторно';

  @override
  String get authPasswordResetCodeSent =>
      'Код для восстановления отправлен на вашу почту.';

  @override
  String get authPasswordResetSuccess =>
      'Пароль обновлен. Теперь можно войти с новым паролем.';

  @override
  String get authPasswordResetCodeInvalid =>
      'Код восстановления недействителен или уже истек.';

  @override
  String get authOrContinueWith => 'или продолжить через';

  @override
  String get authAcceptTermsLabel =>
      'Я принимаю Условия использования и Политику конфиденциальности';

  @override
  String get authTermsLinkText => 'Условия использования';

  @override
  String get authPrivacyLinkText => 'Политику конфиденциальности';

  @override
  String get authReceiveUpdatesLabel =>
      'Я хочу получать новости и предложения от PetMagic';

  @override
  String get authAcceptTermsRequired =>
      'Чтобы создать аккаунт, нужно принять Условия использования и Политику конфиденциальности.';

  @override
  String get authReviewTermsAction => 'Открыть соглашение';

  @override
  String get authReviewPrivacyAction => 'Открыть политику';

  @override
  String get authLegalLoading =>
      'Загружаем актуальные документы соглашения и приватности...';

  @override
  String get authLegalReady =>
      'Актуальные юридические документы готовы к просмотру и принятию.';

  @override
  String get authLegalUnavailable =>
      'Актуальные юридические документы временно недоступны. Попробуйте еще раз чуть позже.';

  @override
  String get authGoogleShortLabel => 'Google';

  @override
  String get authAppleShortLabel => 'Apple';

  @override
  String get authContinueWithGoogle => 'Продолжить с Google';

  @override
  String get authContinueWithApple => 'Продолжить с Apple';

  @override
  String get authNoAccountPrompt => 'Еще нет аккаунта?';

  @override
  String get authHaveAccountPrompt => 'Уже есть аккаунт?';

  @override
  String get authSignUpAction => 'Регистрация';

  @override
  String get authPasswordMismatch => 'Пароли не совпадают.';

  @override
  String get authExternalCancelled => 'Вход был отменен.';

  @override
  String get authExternalFailed =>
      'Не удалось выполнить вход через внешний сервис. Попробуйте еще раз.';

  @override
  String get authExternalTimedOut =>
      'Вход занял слишком много времени. Попробуйте еще раз.';

  @override
  String get authExternalLaunchFailed => 'Не удалось открыть страницу входа.';

  @override
  String get authExternalCallbackFailed =>
      'Не удалось завершить вход обратно в приложении.';

  @override
  String get authExternalSessionExpired =>
      'Сессия внешнего входа истекла. Попробуйте еще раз.';

  @override
  String get authSignInRequired => 'Требуется вход в аккаунт.';

  @override
  String get authSessionExpired => 'Сессия истекла.';

  @override
  String get authLoginFailed => 'Не удалось войти. Попробуйте снова.';

  @override
  String get authEmailInvalid => 'Введите корректный email.';

  @override
  String get authRegistrationFailed =>
      'Не удалось зарегистрироваться. Попробуйте снова.';

  @override
  String get authPasswordResetRequestFailed =>
      'Не удалось отправить запрос на сброс пароля. Попробуйте снова.';

  @override
  String get authPasswordResetFailed =>
      'Не удалось сбросить пароль. Попробуйте снова.';

  @override
  String get authRequestFailed => 'Запрос не выполнен. Попробуйте снова.';

  @override
  String get profileActionFailed =>
      'Не удалось завершить действие. Попробуйте еще раз.';

  @override
  String get authSecurePrivateTitle => 'Безопасно';

  @override
  String get authSecurePrivateSubtitle => 'Ваши данные надежно защищены.';

  @override
  String get authFastEasyTitle => 'Быстро';

  @override
  String get authFastEasySubtitle => 'Начните создавать магию в пару тапов.';

  @override
  String get authLovedByPetsTitle => 'Для любимцев';

  @override
  String get authLovedByPetsSubtitle => 'Сделано для заботливых pet-родителей.';

  @override
  String get authPrivacyTitle => 'Ваша приватность важна';

  @override
  String get authPrivacySubtitle =>
      'Мы не продаем персональные данные. Передаем их только обработчикам, нужным для работы PetMagic.';

  @override
  String get authRequiredTitle => 'Войдите, чтобы открыть это действие';

  @override
  String get authRequiredMessage =>
      'Гость может изучать приложение, но действия с шаблонами, наградами и PawSpark требуют аккаунт PetMagic.';

  @override
  String get authRequiredContinueBrowsing => 'Продолжить просмотр';

  @override
  String get templateTryAction => 'Попробовать шаблон';

  @override
  String get templateUnlockPremiumAction => 'Разблокировать Premium';

  @override
  String get templateGuestPreview => 'Гостевой просмотр';

  @override
  String get templateFlowPhotoSourceGallery => 'Галерея';

  @override
  String get templateFlowPhotoSourceCamera => 'Камера';

  @override
  String get petsActionSheetGallerySubtitle =>
      'Выбрать фото или видео из галереи';

  @override
  String get petsActionSheetCameraSubtitle =>
      'Сделать фото или видео прямо сейчас';

  @override
  String get petsActionSheetGallerySemantic =>
      'Выбрать фото или видео из галереи';

  @override
  String get petsActionSheetCameraSemantic => 'Сделать фото или видео с камеры';

  @override
  String get templateFlowReadyTitle => 'Готово к созданию!';

  @override
  String get templateFlowCheckDetailsSubtitle =>
      'Проверьте детали перед созданием';

  @override
  String get templateFlowTemplateLabel => 'Шаблон';

  @override
  String get templateFlowCostLabel => 'Стоимость';

  @override
  String get templateFlowBalanceLabel => 'Ваш баланс';

  @override
  String get templateFlowDurationHint =>
      'Создание может занять от 10 секунд до 1 минуты.';

  @override
  String get templateFlowCreateMagicAction => 'Создать магию';

  @override
  String get templateFlowChangePhotoAction => 'Изменить фото';

  @override
  String get templateFlowPremiumTemplateTitle => 'Premium-шаблон';

  @override
  String get templateFlowPremiumTemplateMessage =>
      'Этот шаблон доступен только с Premium.';

  @override
  String get templateFlowPremiumLockedTitle => 'Этот шаблон доступен в Premium';

  @override
  String get templateFlowPremiumLockedMessage =>
      'Оформите подписку, чтобы использовать эксклюзивные стили, эффекты и Premium-шаблоны.';

  @override
  String get templateFlowInsufficientBalanceTitle => 'Недостаточно PawSpark';

  @override
  String templateFlowInsufficientBalanceMessage(
    Object balance,
    Object tokenCost,
  ) {
    return 'Шаблон стоит $tokenCost PawSpark. Ваш баланс: $balance PawSpark.';
  }

  @override
  String get templateFlowInsufficientBalanceUpsellMessage =>
      'Купите PawSpark разово или оформите Premium с 40 PawSpark каждую неделю.';

  @override
  String get templateFlowChooseAnotherTemplateAction => 'Выбрать другой шаблон';

  @override
  String get templateFlowCreateFailedTitle => 'Не получилось создать магию';

  @override
  String get templateFlowCreateFailedBalanceHint =>
      'Пополните баланс и запустите создание еще раз.';

  @override
  String get templateFlowCreateFailedRetryHint =>
      'Попробуйте другое фото или повторите позже.';

  @override
  String get templateFlowCreateHint => 'Это может занять немного времени';

  @override
  String get templateFlowStepProcessPhoto => 'Обработка фото';

  @override
  String get templateFlowStepAnalyzePet => 'Анализ питомца';

  @override
  String get templateFlowStepCreateMagic => 'Создание волшебства';

  @override
  String get templateFlowStepFinalTouches => 'Финальные штрихи';

  @override
  String get templateFlowTopUpBalanceAction => 'Пополнить баланс';

  @override
  String get templateFlowResultReadyTitle => 'Готово!';

  @override
  String get templateFlowResultReadySubtitle => 'Ваша магия готова';

  @override
  String get templateFlowResultUnavailable => 'Результат временно недоступен';

  @override
  String get templateFlowLoadingResult => 'Загружаем результат...';

  @override
  String get templateFlowResultLoadFailed => 'Не удалось загрузить результат';

  @override
  String get templateFlowCreateMoreAction => 'Создать еще';

  @override
  String get templateFlowPreviewFallback => 'Превью';

  @override
  String get templateFlowLoadingPreview => 'Загружаем превью...';

  @override
  String get templateFlowPreviewUnavailable => 'Превью недоступно';

  @override
  String get templateFlowLoadingVideo => 'Загружаем видео...';

  @override
  String get generationResultInputTitle => 'Использовать результат';

  @override
  String get generationResultInputParentTitle => 'Готовый результат';

  @override
  String get generationResultInputParentHint =>
      'Этот результат будет использован как основа';

  @override
  String get generationResultInputMediaUnavailable => 'Медиа недоступно';

  @override
  String get generationResultInputRecommendedBadge => 'Рекомендуем';

  @override
  String get generationResultInputEmpty => 'Нет совместимых шаблонов.';

  @override
  String get generationResultInputError =>
      'Не удалось использовать этот результат. Попробуйте ещё раз.';

  @override
  String get generationResultInputNoCredits =>
      'Недостаточно PawSpark для новой генерации.';

  @override
  String get generationResultInputStartAction => 'Запустить';

  @override
  String generationResultInputCostEstimate(Object credits) {
    return 'Генерация будет стоить $credits PawSpark.';
  }

  @override
  String get petGenerationLaunchTitle => 'Запуск магии';

  @override
  String petGenerationLaunchTitleWithName(Object name) {
    return 'Магия для $name';
  }

  @override
  String get petGenerationLaunchSubtitle =>
      'Проверьте шаблон, стоимость PawSpark и точное фото питомца перед созданием.';

  @override
  String get petGenerationLaunchPhotoSectionTitle => 'Фото для генерации';

  @override
  String get petGenerationLaunchSelectedPhotoLabel =>
      'Это фото будет отправлено в генерацию';

  @override
  String get petGenerationLaunchUploadPhotoAction => 'Загрузить новое';

  @override
  String get petGenerationLaunchChoosePhotoTitle => 'Выберите фото питомца';

  @override
  String get petGenerationLaunchLoadingPhotos => 'Загружаем фото...';

  @override
  String get petGenerationLaunchPhotoLoadError =>
      'Не удалось загрузить фото питомца. Попробуйте ещё раз.';

  @override
  String get petGenerationLaunchSelectedPhotoMissing =>
      'Выберите доступное фото питомца перед стартом. PawSpark не списаны.';

  @override
  String get petGenerationLaunchPhotoTypeError =>
      'Выберите фото в формате JPG, PNG или WebP. PawSpark не списаны.';

  @override
  String get petGenerationLaunchUploadError =>
      'Не удалось загрузить фото. PawSpark не списаны.';

  @override
  String get petGenerationLaunchStartError =>
      'Не удалось запустить генерацию. PawSpark не списаны, попробуйте ещё раз.';

  @override
  String get galleryPremiumUpsellTitle => 'Экспорт без водяного знака';

  @override
  String get galleryPremiumUpsellSubtitle => 'Premium уберет логотип PetMagic';

  @override
  String get templateFlowCompletedPremiumHeadline => 'Хотите создавать больше?';

  @override
  String get templateFlowCompletedPremiumMessage =>
      'Premium дает 40 PawSpark каждую неделю, premium-шаблоны и экспорт без водяного знака.';

  @override
  String get templateDetailHeroImageTitle => 'Создайте изображение с питомцем';

  @override
  String get templateDetailHeroVideoTitle => 'Создайте видео с питомцем';

  @override
  String get templateDetailFallbackTitle => 'Шаблон PetMagic';

  @override
  String get templateDetailFallbackDescriptionImage =>
      'Загрузите чёткое фото питомца, и PetMagic создаст аккуратный результат.';

  @override
  String get templateDetailFallbackDescriptionVideo =>
      'Загрузите чёткое фото питомца, и PetMagic превратит его в готовое видео.';

  @override
  String get templateDetailCategoryTemplate => 'Шаблон';

  @override
  String get templateDetailCategoryPortrait => 'Портрет';

  @override
  String get templateDetailCategoryVideo => 'Видео';

  @override
  String get templateDetailRequirementOnePet => 'Один питомец на фото';

  @override
  String get templateDetailRequirementClearFace => 'Морда хорошо видна';

  @override
  String get templateDetailRequirementGoodLighting => 'Хорошее освещение';

  @override
  String get templateDetailRequirementFullBodyVisible =>
      'Питомец виден целиком';

  @override
  String get templateDetailRequirementFacingCamera =>
      'Питомец смотрит в камеру';

  @override
  String get templateDetailRequirementNoCroppedHeadOrLegs =>
      'Голова и лапы не обрезаны';

  @override
  String get templateDetailQualityWarning =>
      'Для лучшего результата используйте яркое и чёткое фото.';

  @override
  String get templateDetailUploadPhotoForVideoAction =>
      'Загрузить фото для видео';

  @override
  String get templateDetailPreviewMissingTitle => 'Превью недоступно';

  @override
  String get templateDetailPreviewMissingSubtitleImage =>
      'Вы всё равно можете загрузить фото питомца и создать это изображение.';

  @override
  String get templateDetailPreviewMissingSubtitleVideo =>
      'Вы всё равно можете загрузить фото питомца и создать это видео.';

  @override
  String get templateDetailTimeLabel => 'Время';

  @override
  String get templateDetailFormatLabel => 'Формат';

  @override
  String get templateDetailVideoEta => '2-4 мин';

  @override
  String get templateDetailImageEta => '1-2 мин';

  @override
  String get templateDetailScrollHint => 'Прокрутите для деталей';

  @override
  String get templateFlowBestPhotoTitle => 'Лучшее фото для этого шаблона:';

  @override
  String get templateFlowUploadPetPhotoAction => 'Загрузить фото питомца';

  @override
  String get templateFlowUploadPetPhotoLockedAction =>
      'Загрузка фото доступна в Premium';

  @override
  String get templateFlowPremiumRequiredError =>
      'Этот шаблон доступен только с Premium.';

  @override
  String get templateFlowInsufficientBalanceError =>
      'Недостаточно PawSpark для запуска генерации.';

  @override
  String get templateFlowTemplateUnavailableError =>
      'Этот шаблон больше недоступен. Выберите другой шаблон в ленте.';

  @override
  String get templateFlowTemplateChangedError =>
      'Шаблон был обновлен. Откройте его из ленты заново и попробуйте еще раз.';

  @override
  String get templateFlowNetworkError =>
      'Нет соединения. Проверьте интернет и попробуйте снова.';

  @override
  String get templateFlowServerError =>
      'Сервис временно недоступен. Попробуйте чуть позже.';

  @override
  String get templateFlowActiveGenerationLimitError =>
      'У вас уже есть активная генерация. Дождитесь её завершения и запустите новую.';

  @override
  String get templateFlowStartFailedError =>
      'Не удалось запустить генерацию. Попробуйте еще раз.';

  @override
  String get generationStatusTitle => 'Статус генерации';

  @override
  String get generationStatusCreatedLabel => 'Создано';

  @override
  String get generationStatusStartedLabel => 'Начато';

  @override
  String get generationStatusTypeLabel => 'Тип';

  @override
  String get generationStatusAttemptLabel => 'Попытка';

  @override
  String get generationStatusUntitledFallback => 'Без названия';

  @override
  String get generationStatusDetailsTitle => 'Детали';

  @override
  String get generationStatusFeedbackTitle => 'Как вам результат?';

  @override
  String get generationStatusFeedbackExcellent => 'Отлично';

  @override
  String get generationStatusFeedbackOkay => 'Нормально';

  @override
  String get generationStatusFeedbackBad => 'Не очень';

  @override
  String get generationStatusSaveAction => 'Сохранить';

  @override
  String get generationStatusDeleteAction => 'Удалить';

  @override
  String get generationStatusReportProblemAction => 'Сообщить о проблеме';

  @override
  String get generationStatusPickAnotherPhotoAction => 'Выбрать другое фото';

  @override
  String get generationStatusRetryAction => 'Попробовать снова';

  @override
  String get generationStatusContactSupportAction => 'Сообщить в поддержку';

  @override
  String get generationStatusOpenGalleryAction => 'Открыть галерею';

  @override
  String get generationStatusOpenStatusAction => 'Открыть статус';

  @override
  String get generationStatusResultUnavailableForSave =>
      'Результат временно недоступен для сохранения.';

  @override
  String get generationStatusResultUnavailableForShare =>
      'Результат временно недоступен для отправки.';

  @override
  String get generationStatusSaveFileDialogTitle => 'Сохранить файл';

  @override
  String get generationStatusFileSavedMessage => 'Файл сохранен на устройство.';

  @override
  String get generationStatusFileSaveFailedMessage =>
      'Не удалось сохранить файл. Попробуйте снова.';

  @override
  String get generationStatusSavedToGalleryMessage => 'Сохранено в галерею';

  @override
  String get generationStatusLinkCopiedMessage => 'Ссылка скопирована';

  @override
  String get generationStatusDeletedMessage => 'Удалено';

  @override
  String get generationStatusFullscreenControlsHint =>
      'Нажмите, чтобы скрыть/показать элементы управления';

  @override
  String get generationStatusDeleteSoonMessage =>
      'Не удалось удалить результат. Попробуйте снова.';

  @override
  String get generationStatusRetrySoonMessage =>
      'Попробуйте выбрать фото и запустить генерацию снова.';

  @override
  String get generationStatusFeedbackThanksMessage =>
      'Спасибо! Ваш отзыв поможет улучшить PetMagic.';

  @override
  String get generationStatusResultTitle => 'Результат PetMagic';

  @override
  String get generationStatusNonTerminalHint =>
      'Обычно это занимает несколько минут. Вы можете продолжить пользоваться приложением.';

  @override
  String get generationStatusStageQueued => 'В очереди';

  @override
  String get generationStatusStageDone => 'Готово';

  @override
  String get generationStatusVideoReady => 'Видео готово';

  @override
  String get generationStatusShareVideoAction => 'Поделиться видео';

  @override
  String get generationStatusFailedTitle => 'Не удалось создать результат';

  @override
  String get generationStatusTokensRefundedHint =>
      'PawSpark возвращены на ваш баланс.';

  @override
  String get generationStatusTokensRefundedShort => 'PawSpark возвращены';

  @override
  String get generationStatusSupportHint =>
      'Если ошибка повторится, напишите в поддержку.';

  @override
  String get generationStatusBackgroundHint =>
      'Генерация продолжается на сервере. Мы покажем результат в Галерее, когда все будет готово.';

  @override
  String get generationStatusDownloadAction => 'Скачать';

  @override
  String get generationStatusContinueInAppAction => 'Продолжить в приложении';

  @override
  String get generationStatusFeedbackImproveTitle => 'Что можно улучшить?';

  @override
  String get generationStatusFeedbackCommentLabel => 'Комментарий';

  @override
  String get generationStatusFeedbackCommentHint =>
      'Расскажите коротко, что не так';

  @override
  String get generationStatusFeedbackSubmitAction => 'Отправить отзыв';

  @override
  String get generationStatusFeedbackReasonPetNotSimilar =>
      'Питомец плохо похож на себя';

  @override
  String get generationStatusFeedbackReasonFaceDistorted =>
      'Морда или лицо искажены';

  @override
  String get generationStatusFeedbackReasonStrangeMotion =>
      'Движение выглядит странно';

  @override
  String get generationStatusFeedbackReasonPreviewMismatch =>
      'Результат отличается от превью';

  @override
  String get generationStatusFeedbackReasonLowQuality =>
      'Качество получилось низким';

  @override
  String get generationStatusFeedbackReasonStyleDisliked =>
      'Не понравился стиль';

  @override
  String get generationStatusFeedbackReasonOther => 'Другое';

  @override
  String generationStatusEtaEstimated(Object value) {
    return 'Примерно $value осталось';
  }

  @override
  String get generationStatusEtaQueued => 'Ожидание в очереди';

  @override
  String get generationStatusEtaFinalizing => 'Почти готово';

  @override
  String get generationStatusEtaDefault => 'Примерно 1-2 мин осталось';

  @override
  String get generationStatusEtaStartsSoon => 'Начнем через несколько минут';

  @override
  String get generationStatusEtaNotifyHint =>
      'Мы сообщим, когда результат будет готов.';

  @override
  String get generationStatusCancelledTitle => 'Генерация отменена';

  @override
  String get generationStatusCancelledMessage =>
      'Генерация остановлена до начала обработки.';

  @override
  String get generationStatusCancelQueuedHint =>
      'Отменить можно, пока генерация ещё ждёт в очереди.';

  @override
  String get generationStatusCancelQueuedAction => 'Отменить генерацию';

  @override
  String get generationStatusCancelQueuedTitle => 'Отменить генерацию?';

  @override
  String get generationStatusCancelQueuedMessage =>
      'Это сработает только пока генерация в очереди. Если PawSpark были зарезервированы, они автоматически вернутся на ваш баланс.';

  @override
  String get generationStatusCancelQueuedKeepAction => 'Продолжить ждать';

  @override
  String get generationStatusCancelQueuedConfirmAction => 'Подтвердить отмену';

  @override
  String get generationStatusCancelQueuedSuccess => 'Генерация отменена.';

  @override
  String get generationStatusCancelQueuedAlreadyStarted =>
      'Генерация уже началась, её нельзя отменить.';

  @override
  String get generationStatusCancelQueuedFailed =>
      'Не удалось отменить генерацию. Попробуйте снова.';

  @override
  String get generationStatusQueuedVideoHint =>
      'Видео обычно занимает дольше фото и может готовиться несколько минут.';

  @override
  String get generationStatusFailurePhotoHint =>
      'Фото не подошло для этого шаблона. Попробуйте выбрать фото, где питомец хорошо виден.';

  @override
  String get generationStatusFailureTechnicalHint =>
      'Не удалось создать результат из-за технической ошибки. Мы вернули PawSpark на ваш баланс.';

  @override
  String get generationStatusStatusCompleted => 'Ваш результат готов';

  @override
  String get generationStatusStatusFailed => 'Не удалось создать результат';

  @override
  String get generationStatusStatusCreatingMagic => 'Создаем магию...';

  @override
  String get generationStatusTerminalRefundedHint =>
      'PawSpark возвращены автоматически.';

  @override
  String get generationStatusTerminalFailureHint =>
      'Техническая ошибка уже зафиксирована.';

  @override
  String get generationStatusTerminalSuccessHint =>
      'Откройте результат, поделитесь им или оставьте отзыв.';

  @override
  String get generationStatusSectionActive => 'В процессе';

  @override
  String get generationStatusSectionReady => 'Готово';

  @override
  String get generationStatusSectionFailed => 'Ошибка';

  @override
  String get generationStatusFilterActive => 'В процессе';

  @override
  String get generationStatusFilterReady => 'Готово';

  @override
  String get generationStatusFilterFailed => 'Ошибка';

  @override
  String generationStatusShowMoreAction(Object hiddenCount) {
    return 'Показать еще ($hiddenCount) ▾';
  }

  @override
  String get generationStatusLoadMoreAction => 'Загрузить ещё';

  @override
  String get generationStatusLoadMoreFailed =>
      'Не удалось загрузить ещё результаты.';

  @override
  String get generationStatusMediaPreparingMessage => 'Готовим медиа...';

  @override
  String get generationStatusMediaPreviewOnlyMessage =>
      'Превью доступно, финальный файл ещё готовится.';

  @override
  String get generationStatusMediaWatermarkPreparingMessage =>
      'Готовим версию без водяного знака...';

  @override
  String get generationStatusMediaExpiredMessage =>
      'Это медиа больше недоступно.';

  @override
  String get generationStatusMediaUnavailableMessage => 'Медиа недоступно.';

  @override
  String get generationStatusMediaFailedMessage =>
      'Не удалось обработать медиа.';

  @override
  String get generationStatusMediaHiddenMessage => 'Медиа скрыто.';

  @override
  String get generationStatusCollapseAction => 'Свернуть ▲';

  @override
  String get generationStatusActiveInfoHint =>
      'Генерация продолжается на сервере. Мы покажем результат в Галерее, когда все будет готово.';

  @override
  String generationStatusUnreadCount(Object count) {
    return '$count новых';
  }

  @override
  String get generationStatusEmptyTitle => 'Здесь появятся ваши результаты';

  @override
  String get generationStatusEmptyMessage =>
      'Выберите шаблон, загрузите фото питомца и создайте первый магический арт.';

  @override
  String get generationStatusSubtitleAll => 'Ваши магические создания';

  @override
  String get generationStatusSubtitleActive => 'Активные генерации';

  @override
  String get generationStatusSubtitleReady => 'Ваши готовые результаты';

  @override
  String get generationStatusSubtitleFailed => 'Проблемы с генерацией';

  @override
  String get generationStatusOfflineBannerTitle => 'Вы офлайн';

  @override
  String get generationStatusOfflineBannerMessage =>
      'Показываем ранее сохраненные результаты на этом устройстве.';

  @override
  String generationStatusOfflineBannerSyncedAt(Object value) {
    return 'Последняя синхронизация: $value';
  }

  @override
  String get generationStatusOnlineBannerTitle => 'Сеть восстановлена';

  @override
  String get generationStatusOnlineBannerMessage =>
      'Загружены актуальные данные.';

  @override
  String generationStatusOnlineBannerSyncedAt(Object value) {
    return 'Обновлено: $value';
  }

  @override
  String generationStatusDateToday(Object time) {
    return 'Сегодня, $time';
  }

  @override
  String generationStatusDateYesterday(Object time) {
    return 'Вчера, $time';
  }

  @override
  String shellActiveGenerationLabel(Object templateTitle) {
    return '✨ Создаем $templateTitle';
  }

  @override
  String get shellActiveGenerationFallback => 'результат';

  @override
  String get walletStripeCardBrandsLabel => 'Visa • Mastercard';

  @override
  String get walletStripeWalletsLabel => 'Apple Pay • Google Pay';

  @override
  String get walletPackUsageNote => 'Используется для генерации фото и видео.';

  @override
  String get walletCheckoutTaxLabel => 'Налог';

  @override
  String get walletCheckoutTaxIncludedValue => 'Включено';

  @override
  String get walletCheckoutTotalLabel => 'Итого';

  @override
  String walletCheckoutPayAction(Object price) {
    return 'Оплатить $price';
  }

  @override
  String get emailVerificationTitle => 'Подтверждение email';

  @override
  String emailVerificationCodeSentMessage(Object email) {
    return 'Мы отправили 6-значный код на $email.';
  }

  @override
  String get emailVerificationCodeLabel => 'Код';

  @override
  String get emailVerificationWorkingLabel => 'Выполняем...';

  @override
  String get emailVerificationVerifyAction => 'Подтвердить';

  @override
  String get emailVerificationResendAction => 'Отправить код еще раз';

  @override
  String get emailVerificationChangeEmailAction => 'Изменить email';

  @override
  String get emailVerificationConfirmedMessage =>
      'Email подтвержден. Пожалуйста, войдите в аккаунт.';

  @override
  String get emailVerificationResentFallbackMessage =>
      'Если аккаунт существует, новый код был отправлен.';

  @override
  String get profileNotificationsDeviceAllowed => 'Разрешено';

  @override
  String get profileNotificationsDeviceLimited => 'Ограничено';

  @override
  String get profileNotificationsDeviceDenied => 'Запрещено';

  @override
  String get profileNotificationsDevicePermanentlyDenied =>
      'Запрещено навсегда';

  @override
  String get profileNotificationsDeviceRestricted => 'Ограничено';

  @override
  String get profileNotificationsDeviceUnknown => 'Неизвестно';

  @override
  String get profileNotificationsDeviceNotifications => 'Уведомления';

  @override
  String get profileNotificationsDeviceCamera => 'Камера';

  @override
  String get profileNotificationsDeviceMicrophone => 'Микрофон';

  @override
  String get profileNotificationsDevicePhotos => 'Фото';

  @override
  String get profileNotificationsDeviceFiles => 'Файлы';

  @override
  String get supportChatLoadPreviousMessagesAction =>
      'Загрузить предыдущие сообщения';

  @override
  String get generationStatusCopyLinkAction => 'Скопировать ссылку';

  @override
  String get generationStatusShareFailedMessage =>
      'Не удалось поделиться результатом. Попробуйте еще раз.';

  @override
  String get generationStatusDeleteFailedMessage =>
      'Не удалось удалить результат. Попробуйте еще раз.';

  @override
  String get premiumSelectedBadge => 'ВЫБРАНО';

  @override
  String get premiumBestValueBadge => 'ЛУЧШАЯ ВЫГОДА';

  @override
  String get premiumStorePaymentDisclaimerTitle =>
      'Безопасная оплата через App Store / Google Play';

  @override
  String get premiumStorePaymentDisclaimerBody =>
      'Оплата будет списана с вашего аккаунта App Store / Google Play. Подписка продлевается автоматически, если ее не отменить до даты продления.';

  @override
  String get premiumCardPaymentDisclaimerTitle =>
      'Безопасная оплата банковской картой';

  @override
  String get premiumCardPaymentDisclaimerBody =>
      'Оплата будет списана с вашей банковской карты. Подписка продлевается автоматически, если ее не отменить до даты продления.';

  @override
  String get premiumCheckoutPageTitle => 'Оформить Premium';

  @override
  String get premiumCheckoutHeroBadge => 'Подписка Premium';

  @override
  String get premiumCheckoutHeroSubtitle =>
      'Регулярный доступ к Premium с безлимитными шаблонами и более быстрой генерацией в PetMagic.';

  @override
  String premiumCheckoutTokensPerPeriod(Object count) {
    return '$count PawSpark каждые 7 дней';
  }

  @override
  String get premiumCheckoutIncludesTitle => 'Что вы получите';

  @override
  String get premiumCheckoutIncludedTemplates => 'Доступ к Premium-шаблонам';

  @override
  String get premiumCheckoutIncludedPriority =>
      'Приоритетная очередь генерации';

  @override
  String get premiumCheckoutIncludedNoWatermark =>
      'Без водяного знака на экспорте';

  @override
  String get premiumCheckoutPaymentMethodSubtitle =>
      'Карты и доступные способы оплаты';

  @override
  String get premiumCheckoutTrustText =>
      'Данные карты безопасно обрабатываются Stripe. PetMagic не хранит данные вашей карты.';

  @override
  String get premiumCheckoutSummaryTitle => 'Ваша подписка';

  @override
  String get premiumCheckoutSummaryPlanLabel => 'Тариф';

  @override
  String get premiumCheckoutSummaryPeriodLabel => 'Период оплаты';

  @override
  String get premiumCheckoutPeriodMonthly => 'Ежемесячно';

  @override
  String get premiumCheckoutPeriodYearly => 'Ежегодно';

  @override
  String premiumCheckoutContinueAction(Object provider) {
    return 'Продолжить через $provider';
  }

  @override
  String premiumCheckoutPayAction(Object price) {
    return 'Оплатить $price';
  }

  @override
  String get premiumCheckoutTotalLabel => 'Итого';

  @override
  String get premiumPaywallFeedbackTitle => 'Что остановило вас от подписки?';

  @override
  String get premiumPaywallFeedbackCommentLabel => 'Комментарий';

  @override
  String get premiumPaywallFeedbackCommentHint =>
      'Расскажите, что сделало бы Premium полезнее для вас';

  @override
  String get premiumPaywallFeedbackSubmitAction => 'Отправить отзыв';

  @override
  String get premiumPaywallFeedbackThanksMessage =>
      'Спасибо! Ваш отзыв поможет улучшить Premium.';

  @override
  String get premiumPaywallFeedbackOptionExpensive => 'Слишком дорого';

  @override
  String get premiumPaywallFeedbackOptionLowValue => 'Недостаточно пользы';

  @override
  String get premiumPaywallFeedbackOptionPaymentProblem => 'Проблема с оплатой';

  @override
  String get premiumPaywallFeedbackOptionJustBrowsing => 'Просто смотрю';

  @override
  String get premiumPaywallFeedbackOptionOther => 'Другое';

  @override
  String get premiumBenefitAiGenerationsTitle => '40 PawSpark';

  @override
  String get premiumBenefitAiGenerationsSubtitle =>
      'каждые 7 дней, пока активен Premium';

  @override
  String get premiumBenefitPremiumTemplatesTitle => 'Premium-шаблоны';

  @override
  String get premiumBenefitPremiumTemplatesSubtitle => 'эксклюзивные';

  @override
  String get premiumBenefitPriorityVideoQueueTitle =>
      'Приоритетная очередь видео';

  @override
  String get premiumBenefitPriorityVideoQueueSubtitle => 'быстрее результаты';

  @override
  String get premiumBenefitNoWatermarkTitle => 'Без водяного знака';

  @override
  String get premiumBenefitNoWatermarkSubtitle => 'чистый экспорт';

  @override
  String get premiumBenefitBiggerRewardsTitle => 'Больше наград';

  @override
  String get premiumBenefitBiggerRewardsSubtitle => 'ежедневные бонусы';

  @override
  String get subscriptionDangerZoneTitle => 'Опасная зона';

  @override
  String get subscriptionCancelConfirmTitle => 'Отменить подписку?';

  @override
  String subscriptionCancelConfirmBody(Object date) {
    return 'Premium останется активным до $date. Новые списания будут отключены.';
  }

  @override
  String get subscriptionCancelConfirmAction => 'Подтвердить';

  @override
  String get subscriptionCancelConfirmKeep => 'Сохранить Premium';

  @override
  String get subscriptionRestoreSuccessMessage => 'Покупки восстановлены';

  @override
  String get subscriptionRestoreNoneFoundMessage =>
      'Активная подписка не найдена';

  @override
  String get subscriptionPaymentTrustText =>
      'Данные карты безопасно обрабатываются Stripe. PetMagic не хранит данные вашей карты.';

  @override
  String get subscriptionBillingPeriodLabel => 'Период подписки';

  @override
  String get subscriptionBillingPeriodMonthly => 'Ежемесячный';

  @override
  String get subscriptionBillingPeriodYearly => 'Годовой';

  @override
  String get generationStatusWatermarkRemoved => 'Водяной знак убран';

  @override
  String get generationStatusWatermarkAddedFreePlan =>
      'Водяной знак добавлен на бесплатном плане';

  @override
  String get generationStatusShareWithWatermark =>
      'Поделиться с водяным знаком';

  @override
  String get generationStatusDownloadWithoutWatermark =>
      'Скачать без водяного знака';

  @override
  String get generationStatusSaveWithWatermark => 'Сохранить с водяным знаком';

  @override
  String get generationStatusRemoveWatermark => 'Убрать водяной знак';

  @override
  String get generationStatusRemovingWatermark => 'Убираем...';

  @override
  String get generationStatusUpgradePremium => 'Перейти на Premium';

  @override
  String get generationStatusRemoveWatermarkSheetTitle => 'Убрать водяной знак';

  @override
  String generationStatusRemoveWatermarkSheetBody(Object cost) {
    return 'Используйте $cost PawSpark для этого результата или перейдите на Premium для чистых скачиваний.';
  }

  @override
  String generationStatusRemoveWatermarkUseCredit(Object cost) {
    return 'Использовать $cost PawSpark';
  }

  @override
  String get generationStatusRemoveWatermarkFailed =>
      'Не удалось убрать водяной знак. Попробуйте ещё раз.';

  @override
  String get generationStatusRemoveWatermarkNoCredits =>
      'Недостаточно PawSpark. Купите PawSpark или Premium.';

  @override
  String get globalOfflineBannerTitle => 'Нет подключения к интернету';

  @override
  String get globalOfflineBannerMessage =>
      'Часть функций недоступна, пока соединение не восстановится.';

  @override
  String get globalOnlineRestoredBannerTitle => 'Соединение восстановлено';

  @override
  String get globalOnlineRestoredBannerMessage => 'Вы снова в сети.';

  @override
  String get appUnavailableOfflineTitle => 'Нет подключения';

  @override
  String get appUnavailableOfflineMessage =>
      'Проверьте интернет и попробуйте снова. Мы автоматически повторим загрузку, когда соединение восстановится.';

  @override
  String get appUnavailableServerTitle => 'Сервер недоступен';

  @override
  String get appUnavailableServerMessage =>
      'PetMagic временно недоступен. Попробуйте ещё раз через минуту.';

  @override
  String get localBackendAndroidHintTitle => 'Локальный бекенд на Android';

  @override
  String localBackendAndroidHintMessage(Object baseUrl, Object port) {
    return 'Эта debug-сборка использует $baseUrl. На реальном Android адреса localhost и 127.0.0.1 указывают на сам телефон. Выполните adb reverse tcp:$port tcp:$port или укажите LAN IP компьютера в API_BASE_URL.';
  }

  @override
  String get generationStatusCompareAction => 'Сравнить';

  @override
  String get generationStatusCompareBeforeLabel => 'До';

  @override
  String get generationStatusCompareAfterLabel => 'После';

  @override
  String get generationStatusCompareBeforeUnavailable =>
      'Исходное фото больше недоступно.';

  @override
  String get generationStatusCompareResultUnavailable =>
      'Результат недоступен.';

  @override
  String get generationStatusCompareOpenFailed =>
      'Не удалось открыть сравнение.';

  @override
  String gamificationLevel(Object level) {
    return 'Уровень $level';
  }

  @override
  String gamificationXpProgress(Object current, Object total) {
    return '$current / $total XP';
  }

  @override
  String get gamificationEvolutionEgg => 'Яйцо';

  @override
  String get gamificationEvolutionBaby => 'Малыш';

  @override
  String get gamificationEvolutionTeen => 'Подросток';

  @override
  String get gamificationEvolutionAdult => 'Взрослый';

  @override
  String get gamificationEvolutionLegendary => 'Легендарный';

  @override
  String get gamificationLevelUp => 'Новый уровень!';

  @override
  String get gamificationStreakTitle => 'Ежедневная серия';

  @override
  String gamificationStreakDays(Object count) {
    return '$count дней';
  }

  @override
  String get gamificationStreakAtRisk => 'Ваша серия под угрозой!';

  @override
  String get gamificationStreakFreeze => 'Использовать заморозку';

  @override
  String get gamificationStreakFreezeUsed => 'Серия спасена!';

  @override
  String gamificationStreakFreezeRemaining(Object count) {
    return 'Осталось заморозок: $count';
  }

  @override
  String get gamificationAchievementsTitle => 'Достижения';

  @override
  String get gamificationAchievementUnlocked => 'Достижение разблокировано!';

  @override
  String get gamificationAchievementSecret => 'Секретное достижение';

  @override
  String gamificationAchievementProgress(Object current, Object target) {
    return 'Прогресс: $current/$target';
  }

  @override
  String get gamificationChallengeTitle => 'Еженедельные задания';

  @override
  String get gamificationChallengeComplete => 'Выполнено!';

  @override
  String get gamificationChallengeClaim => 'Забрать награду';

  @override
  String get gamificationChallengeGenerateImages => 'Генерация изображений';

  @override
  String get gamificationChallengeGenerateImagesDesc =>
      'Сгенерируйте изображения с любым шаблоном';

  @override
  String get gamificationChallengeTryTemplates => 'Попробуйте разные шаблоны';

  @override
  String get gamificationChallengeTryTemplatesDesc =>
      'Используйте разные шаблоны на этой неделе';

  @override
  String get gamificationChallengeShareCreations => 'Поделитесь работами';

  @override
  String get gamificationChallengeShareCreationsDesc =>
      'Поделитесь своими работами с друзьями';

  @override
  String get gamificationStatsGenerations => 'Генерации';

  @override
  String get gamificationStatsDaysActive => 'Дней активности';

  @override
  String get gamificationStatsFavoriteTemplate => 'Любимый шаблон';

  @override
  String gamificationMilestone3(Object spark) {
    return 'Бонус за 3 дня: +$spark Spark!';
  }

  @override
  String gamificationMilestone7(Object spark) {
    return 'Бонус за 7 дней: +$spark Spark!';
  }

  @override
  String gamificationMilestone14(Object spark) {
    return 'Бонус за 14 дней: +$spark Spark!';
  }

  @override
  String gamificationMilestone30(Object spark) {
    return 'Бонус за 30 дней: +$spark Spark!';
  }

  @override
  String get gamificationPetStats => 'Статистика питомца';

  @override
  String get gamificationTopPet => 'Лучший питомец';

  @override
  String get gamificationYourProgress => 'Ваш прогресс';

  @override
  String get gamificationBest => 'Рекорд';

  @override
  String gamificationFreezeAvailable(Object count) {
    return '$count заморозка доступна';
  }

  @override
  String gamificationFreezesAvailable(Object count) {
    return 'Заморозок доступно: $count';
  }

  @override
  String get gamificationKeepGenerating =>
      'Продолжайте генерировать, чтобы разблокировать больше!';

  @override
  String gamificationUnlocked(Object total, Object unlocked) {
    return '$unlocked / $total разблокировано';
  }

  @override
  String get gamificationLoadFailed => 'Не удалось загрузить достижения';

  @override
  String gamificationDayStreak(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count дня подряд',
      many: '$count дней подряд',
      few: '$count дня подряд',
      one: '$count день подряд',
      zero: '0 дней подряд',
    );
    return '$_temp0';
  }

  @override
  String get gamificationHubSubtitle =>
      'Следите за серией, заданиями и этапами прогресса в одном месте.';

  @override
  String get gamificationHubEntrySubtitle =>
      'Серия, недельные цели и ключевые достижения.';

  @override
  String get gamificationWeekFocusTitle => 'На этой неделе';

  @override
  String get gamificationWeekFocusSubtitle =>
      'Держите темп, закрывайте задания и берегите серию.';

  @override
  String get gamificationNextMilestoneTitle => 'Следующая цель';

  @override
  String get gamificationFilterAll => 'Все';

  @override
  String get gamificationFilterUnlocked => 'Открытые';

  @override
  String get gamificationFilterInProgress => 'В процессе';

  @override
  String get gamificationFilterSecret => 'Секретные';

  @override
  String get gamificationNoAchievementsInFilter =>
      'Для этого фильтра пока ничего нет.';

  @override
  String get gamificationStatusUnlocked => 'Открыто';

  @override
  String get gamificationStatusInProgress => 'В процессе';

  @override
  String get achievementFirstMagic => 'Первая магия';

  @override
  String get achievementFirstMagicDesc => 'Создайте свою первую AI-генерацию';

  @override
  String get achievementApprentice10 => 'Ученик';

  @override
  String get achievementApprentice10Desc => 'Выполните 10 генераций';

  @override
  String get achievementMagician100 => 'Волшебник';

  @override
  String get achievementMagician100Desc => 'Выполните 100 генераций';

  @override
  String get achievementArchmage500 => 'Архимаг';

  @override
  String get achievementArchmage500Desc => 'Выполните 500 генераций';

  @override
  String get achievementStreak3 => 'Разогрев';

  @override
  String get achievementStreak3Desc => 'Поддерживайте серию 3 дня';

  @override
  String get achievementStreak7 => 'Воин недели';

  @override
  String get achievementStreak7Desc => 'Поддерживайте серию 7 дней';

  @override
  String get achievementStreak14 => 'Чемпион двух недель';

  @override
  String get achievementStreak14Desc => 'Поддерживайте серию 14 дней';

  @override
  String get achievementStreak30 => 'Мастер месяца';

  @override
  String get achievementStreak30Desc => 'Поддерживайте серию 30 дней';

  @override
  String get achievementPackLeader => 'Вожак стаи';

  @override
  String get achievementPackLeaderDesc => 'Имейте 5 питомцев';

  @override
  String get achievementEvolutionBaby => 'Первые шаги';

  @override
  String get achievementEvolutionBabyDesc =>
      'Эволюционируйте питомца до стадии Малыш';

  @override
  String get achievementEvolutionLegendary => 'Легендарный страж';

  @override
  String get achievementEvolutionLegendaryDesc =>
      'Эволюционируйте питомца до Легендарной стадии';

  @override
  String get achievementTrendsetter => 'Первопроходец';

  @override
  String get achievementTrendsetterDesc => 'Используйте Шаблон дня';

  @override
  String get achievementDailyRitual => 'Ежедневный ритуал';

  @override
  String get achievementDailyRitualDesc => 'Сгенерируйте 5 раз за один день';

  @override
  String get achievementTemplateCollector => 'Коллекционер шаблонов';

  @override
  String get achievementTemplateCollectorDesc =>
      'Используйте 20 разных шаблонов';

  @override
  String get achievementNightOwl => 'Сова';

  @override
  String get achievementNightOwlDesc => 'Генерируйте между 2 и 5 часами ночи';

  @override
  String generationStatusGenerateSimilarCost(Object cost) {
    return 'Стоимость: $cost PawSpark';
  }

  @override
  String get generationStatusGenerateSimilarConfirmAction => 'Генерировать';

  @override
  String get generationStatusGenerateSimilarCancelAction => 'Отмена';

  @override
  String get generationStatusGenerateSimilarSourceUnavailable =>
      'Исходный файл недоступен.';

  @override
  String get generationStatusGenerateSimilarInsufficientBalance =>
      'Недостаточно PawSpark.';

  @override
  String get generationStatusGenerateSimilarFailed =>
      'Не удалось сгенерировать. Попробуйте ещё раз.';

  @override
  String get generationStatusFailedFeedbackTitle => 'Что произошло?';

  @override
  String get generationStatusFailedFeedbackNotCompleted => 'Не завершилась';

  @override
  String get generationStatusFailedFeedbackTooLong => 'Слишком долго';

  @override
  String get generationStatusFailedFeedbackPawSparkCharged =>
      'Списались PawSpark';

  @override
  String get generationStatusFailedFeedbackStuck => 'Зависло';

  @override
  String get generationStatusFailedFeedbackOther => 'Другое';

  @override
  String get generationStatusReportFeedbackTitle => 'Что не так с результатом?';

  @override
  String get generationStatusReportFeedbackLowQuality => 'Плохое качество';

  @override
  String get generationStatusReportFeedbackWrongPet => 'Не тот питомец';

  @override
  String get generationStatusReportFeedbackDistortion => 'Искажение';

  @override
  String get generationStatusReportFeedbackInappropriate =>
      'Неподходящий результат';

  @override
  String get generationStatusReportFeedbackWrongTemplate => 'Не тот шаблон';

  @override
  String get generationStatusReportFeedbackWatermark => 'Водяной знак';

  @override
  String get generationStatusReportFeedbackPayment => 'Оплата';

  @override
  String get generationStatusReportFeedbackOther => 'Другое';

  @override
  String get generationStatusCreateVideoFromResultAction =>
      'Создать видео из этого';

  @override
  String get generationStatusGenerateSimilarAction => 'Похожий вариант';

  @override
  String get generationStatusGenerateSimilarLoading =>
      'Создаём похожий вариант...';

  @override
  String get generationStatusUseAsInputAction => 'Взять за основу';

  @override
  String get profileSettingsFeedbackTitle => 'Отправить отзыв';

  @override
  String get profileSettingsFeedbackSubtitle =>
      'Идея, ошибка, оплата или общий комментарий';

  @override
  String get profileSettingsFeedbackSheetTitle => 'Отправить отзыв';

  @override
  String get profileSettingsFeedbackMessageLabel => 'Комментарий';

  @override
  String get profileSettingsFeedbackMessageHint =>
      'Добавьте детали, если хотите';

  @override
  String get profileSettingsFeedbackSubmitAction => 'Отправить';

  @override
  String get profileSettingsFeedbackThanksMessage =>
      'Спасибо! Ваш отзыв поможет улучшить PetMagic.';

  @override
  String get profileSettingsFeedbackOptionGeneral => 'Общее';

  @override
  String get profileSettingsFeedbackOptionFeatureRequest => 'Пожелание';

  @override
  String get profileSettingsFeedbackOptionBug => 'Ошибка';

  @override
  String get profileSettingsFeedbackOptionPayment => 'Оплата';

  @override
  String get profileNotificationsPushPhotoReadySubtitle =>
      'Когда AI-фото готово к просмотру';

  @override
  String get profileNotificationsPushVideoReadySubtitle =>
      'Когда AI-видео завершило обработку';

  @override
  String get profileNotificationsPushGenerationErrorsSubtitle =>
      'Если генерация завершилась с ошибкой';

  @override
  String get profileNotificationsPushRemindersSubtitle =>
      'Напоминания об использовании приложения';

  @override
  String get profileNotificationsPushNewTemplatesSubtitle =>
      'Новые стили и шаблоны генерации';

  @override
  String get profileNotificationsPushPurchasesAndSubscriptionsSubtitle =>
      'Подтверждения оплат и статус подписки';

  @override
  String get profileNotificationsEmailOffersSubtitle =>
      'Скидки, акции и промо-предложения';

  @override
  String get profileNotificationsEmailNewsSubtitle =>
      'Обновления приложения и новые функции';

  @override
  String get profileNotificationsEmailAccountAlertsSubtitle =>
      'Уведомления безопасности и о смене данных';

  @override
  String get passwordChangeStepRequestCode => 'Запрос кода';

  @override
  String get passwordChangeStepNewPassword => 'Новый пароль';

  @override
  String get subscriptionTokensWeeklyGrantPeriodSuffix => ' / 7д';

  @override
  String subscriptionGrantCountdownDaysHoursMinutes(
    int days,
    int hours,
    int minutes,
  ) {
    return '$daysд $hoursч $minutesм';
  }

  @override
  String subscriptionGrantCountdownHoursMinutesSeconds(
    int hours,
    int minutes,
    int seconds,
  ) {
    return '$hoursч $minutesм $secondsс';
  }

  @override
  String subscriptionGrantCountdownMinutesSeconds(int minutes, int seconds) {
    return '$minutesм $secondsс';
  }

  @override
  String get subscriptionGrantReadyLabel => '✦ Готово к начислению!';

  @override
  String subscriptionGrantNextLabel(String countdown) {
    return 'Следующее начисление: $countdown';
  }

  @override
  String get subscriptionBenefitTokensDescription =>
      'Автоматически каждые 7 дней';

  @override
  String get subscriptionBenefitFirstBonusDescription =>
      'Мгновенно при покупке';

  @override
  String get subscriptionBenefitTemplatesDescription =>
      'Все сценарии разблокированы';

  @override
  String get subscriptionBenefitPriorityGenerationDescription =>
      'Ваши задачи в приоритете';

  @override
  String get subscriptionBenefitNoWatermarkDescription => 'Чистый результат';

  @override
  String generationStatusQueuePositionWithWait(int position, String wait) {
    return 'Позиция в очереди: №$position • $wait';
  }

  @override
  String generationStatusQueuePosition(int position) {
    return 'Позиция в очереди: №$position';
  }

  @override
  String generationStatusWaitMinutes(int minutes) {
    return '$minutes мин';
  }

  @override
  String get generationStatusStatusCancelled => 'Генерация отменена';

  @override
  String get generationStatusTerminalCancelledHint =>
      'Генерация была отменена до завершения.';

  @override
  String get templateFlowGenerationWaitTooLongTitle =>
      'Сейчас высокая нагрузка';

  @override
  String get templateFlowGenerationWaitTooLongMessage =>
      'Примерное ожидание для этой генерации слишком большое. Попробуйте позже или выберите фото-генерацию, которая обычно готовится быстрее.';

  @override
  String templateFlowGenerationWaitTooLongRetryAfter(String value) {
    return 'Попробуйте снова примерно через $value.';
  }

  @override
  String get templateFlowGenerationWaitTooLongPremiumHint =>
      'Premium-запросы получают приоритет при высокой нагрузке и могут ждать меньше.';

  @override
  String get mediaPlayAction => 'Воспроизвести';

  @override
  String get mediaPauseAction => 'Пауза';

  @override
  String get mediaMuteAction => 'Выключить звук';

  @override
  String get mediaUnmuteAction => 'Включить звук';
}
