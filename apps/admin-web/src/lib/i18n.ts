export const locales = ["ru", "en"] as const;

export type Locale = (typeof locales)[number];

export const defaultLocale: Locale = "ru";

export type Dictionary = {
  loginTitle: string;
  loginHint: string;
  emailLabel: string;
  passwordLabel: string;
  signIn: string;
  usersTitle: string;
  usersHeroEyebrow: string;
  usersHeroDescription: string;
  usersHeroBadge: string;
  usersMetaCountLabel: string;
  usersMetaAdminEnabled: string;
  usersMetaViewOnly: string;
  usersMetaLiveControls: string;
  usersLoadingDescription: string;
  usersCardDescription: string;
  usersEmptyDescription: string;
  usersChangesSaved: string;
  avatarLabel: string;
  openLabel: string;
  emailConfirmedLabel: string;
  createdAtLabel: string;
  userDetailOpen: string;
  userInlineAnalyticsTitle: string;
  userInlineAnalyticsDescription: string;
  userOpenFullProfile: string;
  userSelectForAnalytics: string;
  userDetailsTitle: string;
  userDetailsEyebrow: string;
  userDetailsDescription: string;
  userAnalyticsTitle: string;
  userActivityTitle: string;
  userPurchasesTitle: string;
  userGenerationsTitle: string;
  userEventsTitle: string;
  userFailureBreakdownTitle: string;
  userWalletTitle: string;
  userWalletDescription: string;
  userNoWalletActivity: string;
  tokenBalanceLabel: string;
  tokensGrantedLabel: string;
  tokensSpentLabel: string;
  manualGrantLabel: string;
  manualDebitLabel: string;
  viewsLabel: string;
  videoViewsLabel: string;
  loginsLabel: string;
  failedLoginsLabel: string;
  lastLoginLabel: string;
  walletAdjustmentTitle: string;
  walletAdjustmentHint: string;
  walletOperationCredit: string;
  walletOperationDebit: string;
  walletOperationLabel: string;
  walletAmountLabel: string;
  walletReasonLabel: string;
  walletReasonPlaceholder: string;
  walletApplyAction: string;
  walletSaving: string;
  walletOperationSaved: string;
  walletOperationError: string;
  userNoAvatar: string;
  userNoActivity: string;
  userNoPurchases: string;
  userNoGenerations: string;
  userNoEvents: string;
  userNoFailures: string;
  userAnalyticsLoadError: string;
  walletBalanceLabel: string;
  totalPurchasesLabel: string;
  successfulPurchasesLabel: string;
  purchasedSparkLabel: string;
  totalGenerationsLabel: string;
  completedGenerationsLabel: string;
  failedGenerationsLabel: string;
  templateEventsLabel: string;
  auditEventsLabel: string;
  lastActivityLabel: string;
  lastPurchaseLabel: string;
  lastGenerationLabel: string;
  yesLabel: string;
  noLabel: string;
  roleLabel: string;
  userRoleAdmin: string;
  userRoleModerator: string;
  userRoleUser: string;
  premiumLabel: string;
  activeLabel: string;
  statusLabel: string;
  navDashboard: string;
  navEconomy: string;
  navSupport: string;
  navUsers: string;
  navTemplates: string;
  navImageTemplates: string;
  navVideoTemplates: string;
  navTemplateAnalytics: string;
  navTemplateCategories: string;
  navLogout: string;
  loading: string;
  errorLoadingUsers: string;
  errorLoadingTemplates: string;
  errorSavingTemplate: string;
  errorActivatingTemplate: string;
  activationRequirementsMissing: string;
  errorDeletingTemplate: string;
  templateStatusUpdated: string;
  templateDeleted: string;
  templateFileUploaded: string;
  noUsers: string;
  noTemplates: string;
  activate: string;
  deactivate: string;
  archive: string;
  moveToDraft: string;
  makePremium: string;
  removePremium: string;
  assignModerator: string;
  revokeModerator: string;
  assignAdmin: string;
  revokeAdmin: string;
  loginFailed: string;
  imageTemplatesTitle: string;
  videoTemplatesTitle: string;
  templatesHint: string;
  createTemplate: string;
  createNewTemplate: string;
  updateTemplate: string;
  editTemplate: string;
  deleteTemplate: string;
  confirmDeleteTemplate: string;
  actionsLabel: string;
  titleLabel: string;
  shortDescriptionLabel: string;
  categoryLabel: string;
  promoBadgeLabel: string;
  promoBadgeAutoLabel: string;
  promoBadgeAutoHint: string;
  promoBadgeNewHint: string;
  promoBadgeTrendingHint: string;
  promoBadgePopularHint: string;
  promoBadgeFunnyHint: string;
  tagsLabel: string;
  tokenCostLabel: string;
  previewAssetTitle: string;
  previewUrlLabel: string;
  fileNameLabel: string;
  contentTypeLabel: string;
  fileSizeLabel: string;
  templateKindVideoBadge: string;
  templateKindImageBadge: string;
  musicDescriptionLabel: string;
  referenceMotionTitle: string;
  referenceUrlLabel: string;
  referenceDurationLabel: string;
  characterOrientationLabel: string;
  preprocessingModelLabel: string;
  preprocessingPromptLabel: string;
  imageModelLabel: string;
  imagePromptLabel: string;
  klingModelLabel: string;
  klingPromptLabel: string;
  keepOriginalSoundLabel: string;
  computedValueHint: string;
  saveTemplate: string;
  resetForm: string;
  uploadPreview: string;
  uploadReference: string;
  uploadAction: string;
  uploadingMedia: string;
  mediaUploadHint: string;
  referenceMotionUploadHint: string;
  mediaDropzoneHint: string;
  selectedFileLabel: string;
  chooseFile: string;
  noFileSelected: string;
  accessLabel: string;
  freeLabel: string;
  clearAsset: string;
  videoTemplateCreatePageTitle: string;
  videoTemplateCreatePageHint: string;
  videoTemplateEditPageTitle: string;
  videoTemplateEditPageHint: string;
  editorStepBasics: string;
  editorStepMedia: string;
  editorStepAi: string;
  editorStepReview: string;
  editorBasicsHint: string;
  editorMediaHint: string;
  editorAiHint: string;
  editorReviewHint: string;
  editorPreviewInApp: string;
  editorPreviewRailHint: string;
  editorChecklistTitle: string;
  editorTipsTitle: string;
  editorTipOrientation: string;
  editorTipDuration: string;
  editorTipKling: string;
  editorCancel: string;
  editorSaveAndContinue: string;
  editorReady: string;
  editorMissing: string;
  editorDraft: string;
  editorActive: string;
  editorOpenPreview: string;
  editorVisibilityTitle: string;
  editorVisibleToUsersHint: string;
  editorHiddenFromUsersHint: string;
  editorSaveDraft: string;
  editorSaveAndActivate: string;
  templateSavedAsDraft: string;
  templateActivated: string;
  editorAccessFreeHint: string;
  editorAccessPremiumHint: string;
  editorReviewReadyHint: string;
  editorReviewIncompleteHint: string;
  editorMediaRequirements: string;
  supportTitle: string;
  supportDescription: string;
  supportInboxTitle: string;
  supportInboxDescription: string;
  supportConversationTitle: string;
  supportConversationDescription: string;
  supportEmpty: string;
  supportLoadError: string;
  supportRefresh: string;
  supportStatusAll: string;
  supportAssignmentAll: string;
  supportAssignmentMine: string;
  supportAssignmentUnassigned: string;
  supportStatusOpen: string;
  supportStatusInProgress: string;
  supportStatusResolved: string;
  supportStatusClosed: string;
  supportBackToInbox: string;
  supportOpenConversation: string;
  supportAssignedTo: string;
  supportUnassigned: string;
  supportLastMessage: string;
  supportNoMessages: string;
  supportReplyPlaceholder: string;
  supportReplyAction: string;
  supportReplySending: string;
  supportSaveStatusAction: string;
  supportStatusSaved: string;
  supportReplySent: string;
  supportInternalNoteAction: string;
  supportInternalNotePlaceholder: string;
  supportInternalNoteSaved: string;
  supportInternalNoteBadge: string;
  supportAssignToMe: string;
  supportUnassign: string;
  supportAssignmentSaved: string;
  supportQuickRepliesLabel: string;
  supportInternalNoteTemplatesLabel: string;
  supportTemplatesManagerTitle: string;
  supportTemplatesManagerDescription: string;
  supportTemplateNoTemplates: string;
  supportTemplateTitleLabel: string;
  supportTemplateBodyLabel: string;
  supportTemplateKindLabel: string;
  supportTemplateKindReply: string;
  supportTemplateKindInternalNote: string;
  supportTemplateEnabledLabel: string;
  supportTemplateDisabledBadge: string;
  supportTemplateSortOrderLabel: string;
  supportTemplateSearchPlaceholder: string;
  supportTemplateFilterAll: string;
  supportTemplateUseAction: string;
  supportTemplateEditAction: string;
  supportTemplateDeleteAction: string;
  supportTemplateCreateAction: string;
  supportTemplateUpdateAction: string;
  supportTemplateResetAction: string;
  supportTemplateCancelEditAction: string;
  supportTemplateSaved: string;
  supportTemplateDeleted: string;
  supportUserLabel: string;
  supportUnreadAdmin: string;
  supportUnreadUser: string;
  supportSearchPlaceholder: string;
  supportUserInformationTitle: string;
  supportConversationDetailsTitle: string;
  supportActionsTitle: string;
  supportMessagesCount: string;
  supportUpdatedLabel: string;
  supportPriorityLabel: string;
  supportPriorityLow: string;
  supportPriorityNormal: string;
  supportPriorityHigh: string;
  supportWaitingLabel: string;
  supportMarkInProgressAction: string;
  supportCloseConversationAction: string;
  supportTodayLabel: string;
  supportViewUserTab: string;
  supportViewTemplatesTab: string;
  supportViewHistoryTab: string;
  supportOpenPanelAction: string;
  supportClosePanelAction: string;
  supportTimelineTitle: string;
  supportTimelineConversationCreated: string;
  supportTimelineUserMessage: string;
  supportTimelineAdminReply: string;
  supportTimelineInternalNote: string;
  supportHistoryEmpty: string;
  supportPlanLabel: string;
  supportLastGenerationLabel: string;
  supportLastPaymentLabel: string;
  supportCountryLabel: string;
  supportLastSeenLabel: string;
  supportAiContextTitle: string;
};

const dictionaries: Record<Locale, Dictionary> = {
  ru: {
    loginTitle: "Вход в систему",
    loginHint: "Используйте свои учетные данные для входа",
    emailLabel: "Email",
    passwordLabel: "Пароль",
    signIn: "Войти",
    usersTitle: "Пользователи",
    usersHeroEyebrow: "Управление доступом",
    usersHeroDescription: "Управление ролями, премиум-статусом и активностью пользователей в едином стиле админ-панели.",
    usersHeroBadge: "Роли и доступ",
    usersMetaCountLabel: "Пользователей",
    usersMetaAdminEnabled: "Админ-функции включены",
    usersMetaViewOnly: "Режим только просмотра",
    usersMetaLiveControls: "Живое управление статусами",
    usersLoadingDescription: "Загрузка списка пользователей",
    usersCardDescription: "Роли, премиум-статус и активность пользователей",
    usersEmptyDescription: "Когда пользователи появятся, здесь будут доступны их роли и переключатели доступа.",
    usersChangesSaved: "Изменения сохранены",
    avatarLabel: "Аватар",
    openLabel: "Открыть",
    emailConfirmedLabel: "Email подтвержден",
    createdAtLabel: "Создан",
    userDetailOpen: "Открыть карточку",
    userInlineAnalyticsTitle: "Аналитика выбранного пользователя",
    userInlineAnalyticsDescription: "Живая сводка по покупкам, генерациям, активности и событиям прямо на странице пользователей.",
    userOpenFullProfile: "Полный профиль",
    userSelectForAnalytics: "Выберите пользователя, чтобы справа появилась аналитика и история активности.",
    userDetailsTitle: "Карточка пользователя",
    userDetailsEyebrow: "Профиль и аналитика",
    userDetailsDescription: "Подробная сводка по профилю, покупкам, генерациям и действиям пользователя.",
    userAnalyticsTitle: "Аналитика пользователя",
    userActivityTitle: "Лента активности",
    userPurchasesTitle: "Покупки",
    userGenerationsTitle: "Генерации",
    userEventsTitle: "Template events",
    userFailureBreakdownTitle: "Сбои генераций",
    userWalletTitle: "Токены и кошелек",
    userWalletDescription: "Текущий баланс, история движений токенов и ручная выдача или списание прямо из админки.",
    userNoWalletActivity: "Движений токенов пока нет.",
    tokenBalanceLabel: "Токены на балансе",
    tokensGrantedLabel: "Всего начислено",
    tokensSpentLabel: "Всего списано",
    manualGrantLabel: "Выдано вручную",
    manualDebitLabel: "Списано вручную",
    viewsLabel: "Просмотры",
    videoViewsLabel: "Видео просмотры",
    loginsLabel: "Успешные входы",
    failedLoginsLabel: "Неуспешные входы",
    lastLoginLabel: "Последний вход",
    walletAdjustmentTitle: "Управление токенами",
    walletAdjustmentHint: "Используйте ручную выдачу и списание только для поддержки, компенсаций и корректировок баланса.",
    walletOperationCredit: "Начислить",
    walletOperationDebit: "Списать",
    walletOperationLabel: "Операция",
    walletAmountLabel: "Количество токенов",
    walletReasonLabel: "Причина",
    walletReasonPlaceholder: "Например: бонус за проблему, ручная корректировка",
    walletApplyAction: "Применить",
    walletSaving: "Сохранение...",
    walletOperationSaved: "Баланс пользователя обновлен.",
    walletOperationError: "Не удалось изменить баланс пользователя.",
    userNoAvatar: "Аватар не установлен",
    userNoActivity: "История активности пока пуста.",
    userNoPurchases: "Покупок пока нет.",
    userNoGenerations: "Генераций пока нет.",
    userNoEvents: "Пользовательские template events пока не записаны.",
    userNoFailures: "Сбоев генераций не найдено.",
    userAnalyticsLoadError: "Не удалось загрузить аналитику пользователя.",
    walletBalanceLabel: "Баланс",
    totalPurchasesLabel: "Покупки",
    successfulPurchasesLabel: "Успешные покупки",
    purchasedSparkLabel: "Куплено spark",
    totalGenerationsLabel: "Генерации",
    completedGenerationsLabel: "Успешные генерации",
    failedGenerationsLabel: "Сбои генераций",
    templateEventsLabel: "Template events",
    auditEventsLabel: "Audit events",
    lastActivityLabel: "Последняя активность",
    lastPurchaseLabel: "Последняя покупка",
    lastGenerationLabel: "Последняя генерация",
    yesLabel: "Да",
    noLabel: "Нет",
    roleLabel: "Роль",
    userRoleAdmin: "Администратор",
    userRoleModerator: "Модератор",
    userRoleUser: "Пользователь",
    premiumLabel: "Premium",
    activeLabel: "Активен",
    statusLabel: "Статус",
    navDashboard: "Дашборд",
    navEconomy: "Экономика",
    navSupport: "Поддержка",
    navUsers: "Пользователи",
    navTemplates: "Шаблоны",
    navImageTemplates: "Шаблоны изображений",
    navVideoTemplates: "Видео шаблоны",
    navTemplateAnalytics: "Аналитика шаблонов",
    navTemplateCategories: "Категории",
    navLogout: "Выйти",
    loading: "Загрузка...",
    errorLoadingUsers: "Не удалось загрузить пользователей.",
    errorLoadingTemplates: "Не удалось загрузить шаблоны.",
    errorSavingTemplate: "Не удалось сохранить шаблон.",
    errorActivatingTemplate: "Не удалось активировать шаблон.",
    activationRequirementsMissing: "Чтобы активировать шаблон, сначала заполните обязательные поля:",
    errorDeletingTemplate: "Не удалось удалить шаблон.",
    templateStatusUpdated: "Статус обновлен.",
    templateDeleted: "Шаблон удален.",
    templateFileUploaded: "Файл загружен.",
    noUsers: "Пользователи не найдены.",
    noTemplates: "Шаблоны не найдены.",
    activate: "Активировать",
    deactivate: "Деактивировать",
    archive: "В архив",
    moveToDraft: "В черновик",
    makePremium: "Выдать Premium",
    removePremium: "Снять Premium",
    assignModerator: "Сделать модератором",
    revokeModerator: "Снять модератора",
    assignAdmin: "Сделать админом",
    revokeAdmin: "Снять админа",
    loginFailed: "Ошибка входа. Проверьте email и пароль.",
    imageTemplatesTitle: "Шаблоны изображений",
    videoTemplatesTitle: "Видео шаблоны",
    templatesHint: "Черновики, активация и вычисляемые метаданные каталога.",
    createTemplate: "Создать шаблон",
    createNewTemplate: "Новый шаблон",
    updateTemplate: "Обновить шаблон",
    editTemplate: "Редактировать",
    deleteTemplate: "Удалить",
    confirmDeleteTemplate: "Удалить шаблон и связанные загруженные media-файлы?",
    actionsLabel: "Действия",
    titleLabel: "Название",
    shortDescriptionLabel: "Краткое описание",
    categoryLabel: "Категория",
    promoBadgeLabel: "Промо-бейдж",
    promoBadgeAutoLabel: "Автоматически",
    promoBadgeAutoHint: "NEW только первый месяц, дальше бейдж меняется по условиям шаблона.",
    promoBadgeNewHint: "Принудительно показывать NEW независимо от даты создания.",
    promoBadgeTrendingHint: "Сигнал для свежих и активно продвигаемых шаблонов.",
    promoBadgePopularHint: "Подходит для сильных evergreen-шаблонов и premium-хитов.",
    promoBadgeFunnyHint: "Для мемных, легких и развлекательных сценариев.",
    tagsLabel: "Tags через запятую",
    tokenCostLabel: "Стоимость в токенах",
    previewAssetTitle: "Превью",
    previewUrlLabel: "URL превью",
    fileNameLabel: "Имя файла",
    contentTypeLabel: "Тип контента",
    fileSizeLabel: "Размер файла, байты",
    templateKindVideoBadge: "Видео",
    templateKindImageBadge: "Изображение",
    musicDescriptionLabel: "Описание музыки / звука",
    referenceMotionTitle: "Референсное видео движения",
    referenceUrlLabel: "URL референсного видео",
    referenceDurationLabel: "Длительность референсного видео, сек.",
    characterOrientationLabel: "Ориентация персонажа",
    preprocessingModelLabel: "Модель препроцессинга",
    preprocessingPromptLabel: "Промпт препроцессинга",
    imageModelLabel: "Image model",
    imagePromptLabel: "Промпт изображения",
    klingModelLabel: "Модель Kling",
    klingPromptLabel: "Промпт Kling",
    keepOriginalSoundLabel: "Сохранять оригинальный звук",
    computedValueHint: "Рассчитывается сервером и не редактируется вручную.",
    saveTemplate: "Сохранить",
    resetForm: "Сбросить",
    uploadPreview: "Загрузить preview",
    uploadReference: "Загрузить референсное видео",
    uploadAction: "Загрузить",
    uploadingMedia: "Загрузка файла...",
    mediaUploadHint: "После загрузки сервер сам определяет URL, имя файла, тип, размер и длительность медиа.",
    referenceMotionUploadHint: "Для референсного движения поддерживается только MP4: сервер использует этот формат для расчета длительности и ориентации персонажа.",
    mediaDropzoneHint: "Кликните по области или перетащите файл сюда.",
    selectedFileLabel: "Выбранный файл",
    chooseFile: "Выбрать файл",
    noFileSelected: "Файл не выбран",
    accessLabel: "Доступ",
    freeLabel: "Free",
    clearAsset: "Очистить",
    videoTemplateCreatePageTitle: "Создать новый шаблон",
    videoTemplateCreatePageHint: "Создайте шаблон для генерации видео в формате TikTok (9:16).",
    videoTemplateEditPageTitle: "Редактировать шаблон",
    videoTemplateEditPageHint: "Обновите медиа, AI-настройки и готовность к публикации без выхода из editor flow.",
    editorStepBasics: "Основная информация",
    editorStepMedia: "Медиа и превью",
    editorStepAi: "AI настройки",
    editorStepReview: "Проверка и публикация",
    editorBasicsHint: "Название, описание, категория, теги и правила доступа к шаблону.",
    editorMediaHint: "Загрузите preview video и reference motion video, затем проверьте вычисленные metadata.",
    editorAiHint: "Настройте preprocessing и motion control до публикации шаблона.",
    editorReviewHint: "Проверьте итоговую карточку и readiness сигнал перед сохранением.",
    editorPreviewInApp: "Предпросмотр в приложении",
    editorPreviewRailHint: "Так карточка шаблона будет смотреться в мобильной ленте до запуска генерации.",
    editorChecklistTitle: "Проверка шаблона",
    editorTipsTitle: "Подсказка",
    editorTipOrientation: "Короткий reference лучше работает как быстрый визуальный ориентир, длинный даёт более выраженное motion-направление.",
    editorTipDuration: "Самые чистые результаты обычно получаются на коротких вертикальных клипах без лишнего фона и резких скачков камеры.",
    editorTipKling: "В motion prompt лучше описывать ритм, жест и настроение сцены, а не повторять базовое описание питомца.",
    editorCancel: "Отмена",
    editorSaveAndContinue: "Сохранить и продолжить",
    editorReady: "Готово",
    editorMissing: "Не заполнено",
    editorDraft: "Черновик",
    editorActive: "Активен",
    editorOpenPreview: "Посмотреть превью",
    editorVisibilityTitle: "Видимость для пользователей",
    editorVisibleToUsersHint: "Активный шаблон виден пользователям в каталоге.",
    editorHiddenFromUsersHint: "Черновик скрыт от пользователей и доступен только в админке.",
    editorSaveDraft: "Сохранить как черновик",
    editorSaveAndActivate: "Сохранить и активировать",
    templateSavedAsDraft: "Шаблон сохранен как черновик.",
    templateActivated: "Шаблон сохранен и активирован.",
    editorAccessFreeHint: "Доступно всем пользователям.",
    editorAccessPremiumHint: "Только для Premium пользователей.",
    editorReviewReadyHint: "Шаблон выглядит цельным и готовым к следующему шагу публикации.",
    editorReviewIncompleteHint: "Перед публикацией лучше закрыть незаполненные медиа или AI-блоки, чтобы карточка выглядела завершённой.",
    editorMediaRequirements: "Все видео должны быть вертикальными 9:16. Для reference motion поддерживается только MP4, потому что его длительность влияет на auto-detected character orientation.",
    supportTitle: "Поддержка",
    supportDescription: "Управляйте диалогами поддержки и отвечайте пользователям из одной очереди.",
    supportInboxTitle: "Очередь чатов",
    supportInboxDescription: "Открытые, активные и завершенные диалоги с пользователями.",
    supportConversationTitle: "Диалог поддержки",
    supportConversationDescription: "История сообщений, статус обращения и быстрый ответ оператора.",
    supportEmpty: "Диалогов поддержки пока нет.",
    supportLoadError: "Не удалось загрузить диалоги поддержки.",
    supportRefresh: "Обновить",
    supportStatusAll: "Все статусы",
    supportAssignmentAll: "Все диалоги",
    supportAssignmentMine: "Только мои",
    supportAssignmentUnassigned: "Без ответственного",
    supportStatusOpen: "Открыт",
    supportStatusInProgress: "В работе",
    supportStatusResolved: "Решен",
    supportStatusClosed: "Закрыт",
    supportBackToInbox: "К очереди",
    supportOpenConversation: "Открыть диалог",
    supportAssignedTo: "Ответственный",
    supportUnassigned: "Пока не назначен",
    supportLastMessage: "Последнее сообщение",
    supportNoMessages: "Сообщений пока нет.",
    supportReplyPlaceholder: "Напишите ответ пользователю...",
    supportReplyAction: "Ответить",
    supportReplySending: "Отправка...",
    supportSaveStatusAction: "Сохранить статус",
    supportStatusSaved: "Статус обновлен",
    supportReplySent: "Ответ отправлен",
    supportInternalNoteAction: "Внутренняя заметка",
    supportInternalNotePlaceholder: "Оставьте заметку только для команды поддержки...",
    supportInternalNoteSaved: "Заметка сохранена",
    supportInternalNoteBadge: "Internal note",
    supportAssignToMe: "Взять в работу",
    supportUnassign: "Снять назначение",
    supportAssignmentSaved: "Назначение обновлено",
    supportQuickRepliesLabel: "Быстрые ответы",
    supportInternalNoteTemplatesLabel: "Шаблоны внутренних заметок",
    supportTemplatesManagerTitle: "Каталог шаблонов",
    supportTemplatesManagerDescription: "Редактируйте быстрые ответы и внутренние заметки без нового деплоя.",
    supportTemplateNoTemplates: "Шаблонов пока нет.",
    supportTemplateTitleLabel: "Название шаблона",
    supportTemplateBodyLabel: "Текст шаблона",
    supportTemplateKindLabel: "Тип шаблона",
    supportTemplateKindReply: "Ответ пользователю",
    supportTemplateKindInternalNote: "Внутренняя заметка",
    supportTemplateEnabledLabel: "Шаблон активен",
    supportTemplateDisabledBadge: "Выключен",
    supportTemplateSortOrderLabel: "Порядок",
    supportTemplateSearchPlaceholder: "Поиск шаблонов...",
    supportTemplateFilterAll: "Все шаблоны",
    supportTemplateUseAction: "Вставить",
    supportTemplateEditAction: "Изменить",
    supportTemplateDeleteAction: "Удалить",
    supportTemplateCreateAction: "Создать шаблон",
    supportTemplateUpdateAction: "Сохранить шаблон",
    supportTemplateResetAction: "Сбросить форму",
    supportTemplateCancelEditAction: "Скрыть редактор",
    supportTemplateSaved: "Шаблон сохранен",
    supportTemplateDeleted: "Шаблон удален",
    supportUserLabel: "Пользователь",
    supportUnreadAdmin: "Непрочитано для поддержки",
    supportUnreadUser: "Непрочитано для пользователя",
    supportSearchPlaceholder: "Поиск диалогов...",
    supportUserInformationTitle: "Информация о пользователе",
    supportConversationDetailsTitle: "Детали диалога",
    supportActionsTitle: "Действия",
    supportMessagesCount: "Сообщений",
    supportUpdatedLabel: "Обновлен",
    supportPriorityLabel: "Приоритет",
    supportPriorityLow: "Низкий",
    supportPriorityNormal: "Нормальный",
    supportPriorityHigh: "Высокий",
    supportWaitingLabel: "Ожидает",
    supportMarkInProgressAction: "Взять в работу",
    supportCloseConversationAction: "Закрыть диалог",
    supportTodayLabel: "Сегодня",
    supportViewUserTab: "Пользователь",
    supportViewTemplatesTab: "Шаблоны",
    supportViewHistoryTab: "История",
    supportOpenPanelAction: "Открыть панель",
    supportClosePanelAction: "Скрыть панель",
    supportTimelineTitle: "Хронология диалога",
    supportTimelineConversationCreated: "Обращение создано",
    supportTimelineUserMessage: "Сообщение пользователя",
    supportTimelineAdminReply: "Ответ поддержки",
    supportTimelineInternalNote: "Внутренняя заметка",
    supportHistoryEmpty: "История пока пуста.",
    supportPlanLabel: "План",
    supportLastGenerationLabel: "Последняя генерация",
    supportLastPaymentLabel: "Последний платеж",
    supportCountryLabel: "Страна",
    supportLastSeenLabel: "Последняя активность",
    supportAiContextTitle: "PetMagic AI context"
  },
  en: {
    loginTitle: "Sign in",
    loginHint: "Use your credentials to sign in",
    emailLabel: "Email",
    passwordLabel: "Password",
    signIn: "Sign in",
    usersTitle: "Users",
    usersHeroEyebrow: "Access control",
    usersHeroDescription: "Manage roles, premium status, and activity with the same visual rhythm as the catalog, editor, and dashboard.",
    usersHeroBadge: "Roles & access",
    usersMetaCountLabel: "Users",
    usersMetaAdminEnabled: "Admin controls enabled",
    usersMetaViewOnly: "View only",
    usersMetaLiveControls: "Live status controls",
    usersLoadingDescription: "Loading users list",
    usersCardDescription: "Roles, premium status, and user access controls",
    usersEmptyDescription: "User roles and access toggles will appear here once the list is populated.",
    usersChangesSaved: "Changes saved",
    avatarLabel: "Avatar",
    openLabel: "Open",
    emailConfirmedLabel: "Email confirmed",
    createdAtLabel: "Created",
    userDetailOpen: "Open profile",
    userInlineAnalyticsTitle: "Selected user analytics",
    userInlineAnalyticsDescription: "Live summary of purchases, generations, activity, and events directly on the users page.",
    userOpenFullProfile: "Full profile",
    userSelectForAnalytics: "Select a user to load analytics and recent activity on this page.",
    userDetailsTitle: "User detail",
    userDetailsEyebrow: "Profile and analytics",
    userDetailsDescription: "Detailed summary of profile, purchases, generations, and user activity.",
    userAnalyticsTitle: "User analytics",
    userActivityTitle: "Activity timeline",
    userPurchasesTitle: "Purchases",
    userGenerationsTitle: "Generations",
    userEventsTitle: "Template events",
    userFailureBreakdownTitle: "Generation failures",
    userWalletTitle: "Tokens and wallet",
    userWalletDescription: "Current balance, token movement history, and manual grant or debit controls directly from admin.",
    userNoWalletActivity: "No token movements yet.",
    tokenBalanceLabel: "Balance tokens",
    tokensGrantedLabel: "Total credited",
    tokensSpentLabel: "Total spent",
    manualGrantLabel: "Manual grants",
    manualDebitLabel: "Manual debits",
    viewsLabel: "Views",
    videoViewsLabel: "Video views",
    loginsLabel: "Successful logins",
    failedLoginsLabel: "Failed logins",
    lastLoginLabel: "Last login",
    walletAdjustmentTitle: "Token controls",
    walletAdjustmentHint: "Use manual grant and debit only for support cases, compensation, and balance corrections.",
    walletOperationCredit: "Grant",
    walletOperationDebit: "Debit",
    walletOperationLabel: "Operation",
    walletAmountLabel: "Token amount",
    walletReasonLabel: "Reason",
    walletReasonPlaceholder: "For example: support bonus, manual correction",
    walletApplyAction: "Apply",
    walletSaving: "Saving...",
    walletOperationSaved: "User balance updated.",
    walletOperationError: "Failed to update user balance.",
    userNoAvatar: "No avatar yet",
    userNoActivity: "No activity has been recorded yet.",
    userNoPurchases: "No purchases yet.",
    userNoGenerations: "No generations yet.",
    userNoEvents: "No template events recorded for this user.",
    userNoFailures: "No generation failures found.",
    userAnalyticsLoadError: "Failed to load user analytics.",
    walletBalanceLabel: "Balance",
    totalPurchasesLabel: "Purchases",
    successfulPurchasesLabel: "Successful purchases",
    purchasedSparkLabel: "Purchased spark",
    totalGenerationsLabel: "Generations",
    completedGenerationsLabel: "Completed generations",
    failedGenerationsLabel: "Failed generations",
    templateEventsLabel: "Template events",
    auditEventsLabel: "Audit events",
    lastActivityLabel: "Last activity",
    lastPurchaseLabel: "Last purchase",
    lastGenerationLabel: "Last generation",
    yesLabel: "Yes",
    noLabel: "No",
    roleLabel: "Role",
    userRoleAdmin: "Admin",
    userRoleModerator: "Moderator",
    userRoleUser: "User",
    premiumLabel: "Premium",
    activeLabel: "Active",
    statusLabel: "Status",
    navDashboard: "Dashboard",
    navEconomy: "Economy",
    navSupport: "Support",
    navUsers: "Users",
    navTemplates: "Templates",
    navImageTemplates: "Image Templates",
    navVideoTemplates: "Video Templates",
    navTemplateAnalytics: "Template Analytics",
    navTemplateCategories: "Categories",
    navLogout: "Logout",
    loading: "Loading...",
    errorLoadingUsers: "Failed to load users.",
    errorLoadingTemplates: "Failed to load templates.",
    errorSavingTemplate: "Failed to save template.",
    errorActivatingTemplate: "Failed to activate template.",
    activationRequirementsMissing: "To activate the template, fill in the required fields first:",
    errorDeletingTemplate: "Failed to delete template.",
    templateStatusUpdated: "Status updated.",
    templateDeleted: "Template deleted.",
    templateFileUploaded: "File uploaded.",
    noUsers: "No users found.",
    noTemplates: "No templates found.",
    activate: "Activate",
    deactivate: "Deactivate",
    archive: "Archive",
    moveToDraft: "Move to Draft",
    makePremium: "Set Premium",
    removePremium: "Remove Premium",
    assignModerator: "Assign Moderator",
    revokeModerator: "Revoke Moderator",
    assignAdmin: "Assign Admin",
    revokeAdmin: "Revoke Admin",
    loginFailed: "Login failed. Please check your credentials.",
    imageTemplatesTitle: "Image Templates",
    videoTemplatesTitle: "Video Templates",
    templatesHint: "Drafts, activation rules, and computed metadata for catalog templates.",
    createTemplate: "Create template",
    createNewTemplate: "New template",
    updateTemplate: "Update template",
    editTemplate: "Edit",
    deleteTemplate: "Delete",
    confirmDeleteTemplate: "Delete this template and its related uploaded media files?",
    actionsLabel: "Actions",
    titleLabel: "Title",
    shortDescriptionLabel: "Short description",
    categoryLabel: "Category",
    promoBadgeLabel: "Promo badge",
    promoBadgeAutoLabel: "Automatic",
    promoBadgeAutoHint: "NEW only for the first month, then the badge switches by template conditions.",
    promoBadgeNewHint: "Force NEW regardless of creation date.",
    promoBadgeTrendingHint: "Use for fresh templates you are actively pushing.",
    promoBadgePopularHint: "Fits evergreen winners and premium hits.",
    promoBadgeFunnyHint: "For meme-like, playful, and entertaining scenarios.",
    tagsLabel: "Tags comma separated",
    tokenCostLabel: "Token cost",
    previewAssetTitle: "Preview asset",
    previewUrlLabel: "Preview URL",
    fileNameLabel: "File name",
    contentTypeLabel: "Content type",
    fileSizeLabel: "File size bytes",
    templateKindVideoBadge: "Video",
    templateKindImageBadge: "Image",
    musicDescriptionLabel: "Music / sound description",
    referenceMotionTitle: "Reference motion video",
    referenceUrlLabel: "Reference video URL",
    referenceDurationLabel: "Reference video duration, sec",
    characterOrientationLabel: "Character orientation",
    preprocessingModelLabel: "Preprocessing model",
    preprocessingPromptLabel: "Preprocessing prompt",
    imageModelLabel: "Image model",
    imagePromptLabel: "Image prompt",
    klingModelLabel: "Kling model",
    klingPromptLabel: "Kling prompt",
    keepOriginalSoundLabel: "Keep original sound",
    computedValueHint: "Calculated by backend and not editable manually.",
    saveTemplate: "Save",
    resetForm: "Reset",
    uploadPreview: "Upload preview",
    uploadReference: "Upload reference video",
    uploadAction: "Upload",
    uploadingMedia: "Uploading file...",
    mediaUploadHint: "After upload, the backend fills the media URL, file name, type, size, and duration automatically.",
    referenceMotionUploadHint: "Reference motion supports MP4 only because the backend relies on that format to calculate duration and character orientation.",
    mediaDropzoneHint: "Click the area or drag a file here.",
    selectedFileLabel: "Selected file",
    chooseFile: "Choose file",
    noFileSelected: "No file selected",
    accessLabel: "Access",
    freeLabel: "Free",
    clearAsset: "Clear",
    videoTemplateCreatePageTitle: "Create new template",
    videoTemplateCreatePageHint: "Create a template for TikTok-style vertical video generation (9:16).",
    videoTemplateEditPageTitle: "Edit template",
    videoTemplateEditPageHint: "Update media, AI settings, and publishing readiness without leaving the editor flow.",
    editorStepBasics: "Basic info",
    editorStepMedia: "Media and preview",
    editorStepAi: "AI settings",
    editorStepReview: "Review and publish",
    editorBasicsHint: "Name, description, category, tags, and access rules for the template.",
    editorMediaHint: "Upload the preview video and reference motion video, then verify the computed metadata.",
    editorAiHint: "Configure preprocessing and motion control before publishing the template.",
    editorReviewHint: "Review the final card and readiness signal before saving.",
    editorPreviewInApp: "Preview in app",
    editorPreviewRailHint: "This is how the template card will feel in the mobile feed before generation starts.",
    editorChecklistTitle: "Template checklist",
    editorTipsTitle: "Tips",
    editorTipOrientation: "Short references work best as fast visual anchors, while longer clips give the motion pass a stronger direction.",
    editorTipDuration: "The cleanest outputs usually come from short vertical clips with minimal background noise and steady framing.",
    editorTipKling: "Use the motion prompt to shape rhythm, gesture, and scene energy instead of restating the pet description.",
    editorCancel: "Cancel",
    editorSaveAndContinue: "Save and continue",
    editorReady: "Ready",
    editorMissing: "Missing",
    editorDraft: "Draft",
    editorActive: "Active",
    editorOpenPreview: "Open preview",
    editorVisibilityTitle: "User visibility",
    editorVisibleToUsersHint: "Active templates are visible to users in the catalog.",
    editorHiddenFromUsersHint: "Draft templates stay hidden from users and remain admin-only.",
    editorSaveDraft: "Save as draft",
    editorSaveAndActivate: "Save and activate",
    templateSavedAsDraft: "Template saved as draft.",
    templateActivated: "Template saved and activated.",
    editorAccessFreeHint: "Available to all users.",
    editorAccessPremiumHint: "Only for Premium users.",
    editorReviewReadyHint: "The template feels cohesive and ready for the next publishing step.",
    editorReviewIncompleteHint: "Before publishing, close the remaining media or AI gaps so the card reads as complete.",
    editorMediaRequirements: "All videos should stay vertical 9:16. Reference motion supports MP4 only because its duration drives the auto-detected character orientation.",
    supportTitle: "Support",
    supportDescription: "Manage support conversations and reply to users from a single inbox.",
    supportInboxTitle: "Support inbox",
    supportInboxDescription: "Open, active, and completed user support conversations.",
    supportConversationTitle: "Support conversation",
    supportConversationDescription: "Message history, conversation status, and a fast operator reply flow.",
    supportEmpty: "No support conversations yet.",
    supportLoadError: "Failed to load support conversations.",
    supportRefresh: "Refresh",
    supportStatusAll: "All statuses",
    supportAssignmentAll: "All conversations",
    supportAssignmentMine: "Assigned to me",
    supportAssignmentUnassigned: "Unassigned only",
    supportStatusOpen: "Open",
    supportStatusInProgress: "In progress",
    supportStatusResolved: "Resolved",
    supportStatusClosed: "Closed",
    supportBackToInbox: "Back to inbox",
    supportOpenConversation: "Open conversation",
    supportAssignedTo: "Assigned to",
    supportUnassigned: "Unassigned",
    supportLastMessage: "Last message",
    supportNoMessages: "No messages yet.",
    supportReplyPlaceholder: "Write a reply to the user...",
    supportReplyAction: "Reply",
    supportReplySending: "Sending...",
    supportSaveStatusAction: "Save status",
    supportStatusSaved: "Status updated",
    supportReplySent: "Reply sent",
    supportInternalNoteAction: "Internal note",
    supportInternalNotePlaceholder: "Leave a note visible only to the support team...",
    supportInternalNoteSaved: "Internal note saved",
    supportInternalNoteBadge: "Internal note",
    supportAssignToMe: "Assign to me",
    supportUnassign: "Unassign",
    supportAssignmentSaved: "Assignment updated",
    supportQuickRepliesLabel: "Quick replies",
    supportInternalNoteTemplatesLabel: "Internal note templates",
    supportTemplatesManagerTitle: "Template catalog",
    supportTemplatesManagerDescription: "Edit quick replies and internal notes without another deploy.",
    supportTemplateNoTemplates: "No templates yet.",
    supportTemplateTitleLabel: "Template title",
    supportTemplateBodyLabel: "Template body",
    supportTemplateKindLabel: "Template kind",
    supportTemplateKindReply: "User reply",
    supportTemplateKindInternalNote: "Internal note",
    supportTemplateEnabledLabel: "Template enabled",
    supportTemplateDisabledBadge: "Disabled",
    supportTemplateSortOrderLabel: "Sort order",
    supportTemplateSearchPlaceholder: "Search templates...",
    supportTemplateFilterAll: "All templates",
    supportTemplateUseAction: "Insert",
    supportTemplateEditAction: "Edit",
    supportTemplateDeleteAction: "Delete",
    supportTemplateCreateAction: "Create template",
    supportTemplateUpdateAction: "Save template",
    supportTemplateResetAction: "Reset form",
    supportTemplateCancelEditAction: "Hide editor",
    supportTemplateSaved: "Template saved",
    supportTemplateDeleted: "Template deleted",
    supportUserLabel: "User",
    supportUnreadAdmin: "Unread for support",
    supportUnreadUser: "Unread for user",
    supportSearchPlaceholder: "Search conversations...",
    supportUserInformationTitle: "User information",
    supportConversationDetailsTitle: "Conversation details",
    supportActionsTitle: "Actions",
    supportMessagesCount: "Messages",
    supportUpdatedLabel: "Updated",
    supportPriorityLabel: "Priority",
    supportPriorityLow: "Low",
    supportPriorityNormal: "Normal",
    supportPriorityHigh: "High",
    supportWaitingLabel: "Waiting",
    supportMarkInProgressAction: "Mark as in progress",
    supportCloseConversationAction: "Close conversation",
    supportTodayLabel: "Today",
    supportViewUserTab: "User",
    supportViewTemplatesTab: "Templates",
    supportViewHistoryTab: "History",
    supportOpenPanelAction: "Open panel",
    supportClosePanelAction: "Hide panel",
    supportTimelineTitle: "Conversation timeline",
    supportTimelineConversationCreated: "Conversation created",
    supportTimelineUserMessage: "User message",
    supportTimelineAdminReply: "Support reply",
    supportTimelineInternalNote: "Internal note",
    supportHistoryEmpty: "No history yet.",
    supportPlanLabel: "Plan",
    supportLastGenerationLabel: "Last generation",
    supportLastPaymentLabel: "Last payment",
    supportCountryLabel: "Country",
    supportLastSeenLabel: "Last activity",
    supportAiContextTitle: "PetMagic AI context"
  }
};

export function isLocale(value: string): value is Locale {
  return locales.includes(value as Locale);
}

export function getDictionary(locale: Locale): Dictionary {
  return dictionaries[locale];
}
