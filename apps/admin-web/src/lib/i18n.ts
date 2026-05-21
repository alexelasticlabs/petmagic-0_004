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
  navPromoCodes: string;
  navSectionOverview: string;
  navSectionGrowth: string;
  navSectionContent: string;
  navSectionUsers: string;
  navLogout: string;
  promoCodesHeroEyebrow: string;
  promoCodesHeroDescription: string;
  promoCodesTokenOnlyBadge: string;
  promoCodesLoadingDescription: string;
  promoCodesErrorDescription: string;
  promoCodesCreateAction: string;
  promoCodesExportAction: string;
  promoCodesRefreshAction: string;
  promoCodesTableDescription: string;
  promoCodesSearchPlaceholder: string;
  promoCodesStatusFilterLabel: string;
  promoCodesSortLabel: string;
  promoCodesStatusAll: string;
  promoCodesStatusDraft: string;
  promoCodesStatusPaused: string;
  promoCodesStatusLimitReached: string;
  promoCodesStatusArchived: string;
  promoCodesStatusExhausted: string;
  promoCodesStatusScheduled: string;
  promoCodesStatusExpired: string;
  promoCodesSortUpdated: string;
  promoCodesSortUsage: string;
  promoCodesSortReward: string;
  promoCodesSortCode: string;
  promoCodesSortExpiry: string;
  promoCodesTotalLabel: string;
  promoCodesActiveLabel: string;
  promoCodesUsesLabel: string;
  promoCodesGrantedLabel: string;
  promoCodesEmptyDescription: string;
  promoCodesNoResults: string;
  promoCodesCodeLabel: string;
  promoCodesDescriptionLabel: string;
  promoCodesRewardLabel: string;
  promoCodesUsageLabel: string;
  promoCodesWindowLabel: string;
  promoCodesUpdatedColumn: string;
  promoCodesCopyAction: string;
  promoCodesDuplicateAction: string;
  promoCodesCreatePanelTitle: string;
  promoCodesEditPanelTitle: string;
  promoCodesDuplicatePanelTitle: string;
  promoCodesRewardFixedLabel: string;
  promoCodesFormCardDescription: string;
  promoCodesSectionMainTitle: string;
  promoCodesSectionCampaignTitle: string;
  promoCodesSectionRewardTitle: string;
  promoCodesSectionLimitsTitle: string;
  promoCodesNewDraftAction: string;
  promoCodesGenerateCodeAction: string;
  promoCodesCodeHelp: string;
  promoCodesCampaignNameLabel: string;
  promoCodesCampaignChannelLabel: string;
  promoCodesCampaignCreatedByLabel: string;
  promoCodesMinimumPurchasesLabel: string;
  promoCodesMinimumPurchasesHint: string;
  promoCodesStatusFieldLabel: string;
  promoCodesStatusActiveOption: string;
  promoCodesStatusPausedOption: string;
  promoCodesRewardTypeLabel: string;
  promoCodesRewardTypeSparkOption: string;
  promoCodesRewardTypePremiumOption: string;
  promoCodesRewardTypeHint: string;
  promoCodesRewardValueLabel: string;
  promoCodesLimitLabel: string;
  promoCodesPerUserLimitLabel: string;
  promoCodesStartsLabel: string;
  promoCodesExpiresLabel: string;
  promoCodesSaveUpdateAction: string;
  promoCodesSaveCreateAction: string;
  promoCodesRecentUsageTitle: string;
  promoCodesNoCodeSelectedTitle: string;
  promoCodesNoCodeSelectedDescription: string;
  promoCodesSelectForUsage: string;
  promoCodesRecentUsageEmpty: string;
  promoCodesActivationsLoading: string;
  promoCodesActivationsError: string;
  promoCodesActivationUserColumn: string;
  promoCodesActivationDateColumn: string;
  promoCodesActivationRewardColumn: string;
  promoCodesActivationStatusColumn: string;
  promoCodesActivationStatusSuccess: string;
  promoCodesViewAllActivationsAction: string;
  promoCodesShowLatestActivationsAction: string;
  promoCodesViewActivationsAction: string;
  promoCodesPauseAction: string;
  promoCodesResumeAction: string;
  promoCodesActionsMenuLabel: string;
  promoCodesUpdatedLabel: string;
  promoCodesLastUsedLabel: string;
  promoCodesUpdatingLabel: string;
  promoCodesLast7DaysLabel: string;
  promoCodesKpiTotalHint: string;
  promoCodesKpiActiveHint: string;
  promoCodesKpiUsesHint: string;
  promoCodesKpiGrantedHint: string;
  promoCodesWindowAlways: string;
  promoCodesRewardUnsupported: string;
  promoCodesInvalidCode: string;
  promoCodesInvalidNumbers: string;
  promoCodesLimitTooLow: string;
  promoCodesPerUserLimitTooLow: string;
  promoCodesInvalidWindow: string;
  promoCodesCopied: string;
  promoCodesExported: string;
  promoCodesArchiveConfirm: string;
  promoCodesCreateSuccess: string;
  promoCodesCreateError: string;
  promoCodesUpdateSuccess: string;
  promoCodesUpdateError: string;
  promoCodesPauseSuccess: string;
  promoCodesPauseError: string;
  promoCodesResumeSuccess: string;
  promoCodesResumeError: string;
  promoCodesArchiveSuccess: string;
  promoCodesArchiveError: string;
  promoCodesPreviousAction: string;
  promoCodesNextAction: string;
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
  supportStatusOpenHint: string;
  supportStatusInProgressHint: string;
  supportStatusResolvedHint: string;
  supportStatusClosedHint: string;
  supportStatusAutomationHint: string;
  supportBackToInbox: string;
  supportOpenConversation: string;
  supportAssignedTo: string;
  supportUnassigned: string;
  supportLastMessage: string;
  supportNoMessages: string;
  supportReplyPlaceholder: string;
  supportReplyAction: string;
  supportReplySending: string;
  supportAttachmentHint: string;
  supportAttachmentOpenAction: string;
  supportAttachmentRemoveAction: string;
  supportSaveStatusAction: string;
  supportStatusSaved: string;
  supportReplySent: string;
  supportAssignToMe: string;
  supportUnassign: string;
  supportAssignmentSaved: string;
  supportQuickRepliesLabel: string;
  supportTemplatesManagerTitle: string;
  supportTemplatesManagerDescription: string;
  supportTemplateNoTemplates: string;
  supportTemplateTitleLabel: string;
  supportTemplateBodyLabel: string;
  supportTemplateKindReply: string;
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
  supportResolveConversationAction: string;
  supportReopenConversationAction: string;
  supportCloseConversationAction: string;
  supportTodayLabel: string;
  supportViewProfileTab: string;
  supportViewPurchasesTab: string;
  supportViewGenerationsTab: string;
  supportViewErrorsTab: string;
  supportViewUserTab: string;
  supportViewTemplatesTab: string;
  supportViewHistoryTab: string;
  supportOpenPanelAction: string;
  supportClosePanelAction: string;
  supportTimelineTitle: string;
  supportTimelineConversationCreated: string;
  supportTimelineUserMessage: string;
  supportTimelineAdminReply: string;
  supportHistoryEmpty: string;
  supportStatusWorkflowTitle: string;
  supportConversationMetaTitle: string;
  supportPlanLabel: string;
  supportAccountAgeLabel: string;
  supportPurchasesLabel: string;
  supportRecentPurchasesTitle: string;
  supportRecentGenerationsTitle: string;
  supportGenerationErrorsTitle: string;
  supportNoPurchases: string;
  supportNoGenerationErrors: string;
  supportOccurrencesLabel: string;
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
    navPromoCodes: "Промокоды",
    navSectionOverview: "Overview",
    navSectionGrowth: "Growth",
    navSectionContent: "Content",
    navSectionUsers: "Users",
    navLogout: "Выйти",
    promoCodesHeroEyebrow: "Токены и активации",
    promoCodesHeroDescription: "Отдельная рабочая зона для token-only промокодов: создание, лимиты, окно действия и контроль последних активаций.",
    promoCodesTokenOnlyBadge: "Только PawSpark",
    promoCodesLoadingDescription: "Подтягиваем активные и архивные промокоды из economy backend.",
    promoCodesErrorDescription: "Не удалось загрузить список промокодов. Проверьте backend и повторите запрос.",
    promoCodesCreateAction: "Создать промокод",
    promoCodesExportAction: "Экспорт CSV",
    promoCodesRefreshAction: "Обновить",
    promoCodesTableDescription: "Быстрый поиск по коду, фильтрация по статусу и ручные действия без перехода в другие разделы.",
    promoCodesSearchPlaceholder: "Поиск по коду или описанию",
    promoCodesStatusFilterLabel: "Фильтр статуса",
    promoCodesSortLabel: "Сортировка",
    promoCodesStatusAll: "Все статусы",
    promoCodesStatusDraft: "Черновик",
    promoCodesStatusPaused: "Приостановлен",
    promoCodesStatusLimitReached: "Лимит достигнут",
    promoCodesStatusArchived: "Архив",
    promoCodesStatusExhausted: "Лимит достигнут",
    promoCodesStatusScheduled: "Запланирован",
    promoCodesStatusExpired: "Истек",
    promoCodesSortUpdated: "Сначала свежие",
    promoCodesSortUsage: "По использованиям",
    promoCodesSortReward: "По награде",
    promoCodesSortCode: "По коду",
    promoCodesSortExpiry: "По окончанию",
    promoCodesTotalLabel: "Всего кодов",
    promoCodesActiveLabel: "Активно сейчас",
    promoCodesUsesLabel: "Активаций",
    promoCodesGrantedLabel: "Выдано токенов",
    promoCodesEmptyDescription: "Промокодов пока нет. Создайте первый token-only код в панели справа.",
    promoCodesNoResults: "Фильтры не дали результатов. Ослабьте поиск или сбросьте статус.",
    promoCodesCodeLabel: "Код",
    promoCodesDescriptionLabel: "Описание",
    promoCodesRewardLabel: "Награда",
    promoCodesUsageLabel: "Использование",
    promoCodesWindowLabel: "Окно действия",
    promoCodesUpdatedColumn: "Обновлен",
    promoCodesCopyAction: "Скопировать",
    promoCodesDuplicateAction: "Дублировать",
    promoCodesCreatePanelTitle: "Новый промокод",
    promoCodesEditPanelTitle: "Редактирование промокода",
    promoCodesDuplicatePanelTitle: "Дубликат промокода",
    promoCodesRewardFixedLabel: "Тип награды: PawSpark-токены",
    promoCodesFormCardDescription: "Соберите правила промокода, проверьте лимиты и запустите кампанию без перехода в другие разделы.",
    promoCodesSectionMainTitle: "1. Основное",
    promoCodesSectionCampaignTitle: "2. Кампания",
    promoCodesSectionRewardTitle: "3. Награда",
    promoCodesSectionLimitsTitle: "4. Ограничения",
    promoCodesNewDraftAction: "Новый драфт",
    promoCodesGenerateCodeAction: "Сгенерировать",
    promoCodesCodeHelp: "Код можно задавать вручную или сгенерировать. После создания он становится read-only.",
    promoCodesCampaignNameLabel: "Название кампании",
    promoCodesCampaignChannelLabel: "Канал",
    promoCodesCampaignCreatedByLabel: "Создано кем",
    promoCodesMinimumPurchasesLabel: "Мин. успешных покупок",
    promoCodesMinimumPurchasesHint: "0 — без ограничений. Значение проверяется при активации промокода.",
    promoCodesStatusFieldLabel: "Статус публикации",
    promoCodesStatusActiveOption: "Активен",
    promoCodesStatusPausedOption: "Приостановлен",
    promoCodesRewardTypeLabel: "Тип награды",
    promoCodesRewardTypeSparkOption: "PawSpark-токены",
    promoCodesRewardTypePremiumOption: "Premium unlock (скоро)",
    promoCodesRewardTypeHint: "Сейчас backend поддерживает только PawSpark-токены.",
    promoCodesRewardValueLabel: "Количество",
    promoCodesLimitLabel: "Общий лимит",
    promoCodesPerUserLimitLabel: "Лимит на пользователя",
    promoCodesStartsLabel: "Старт",
    promoCodesExpiresLabel: "Окончание",
    promoCodesSaveUpdateAction: "Сохранить изменения",
    promoCodesSaveCreateAction: "Создать и сохранить",
    promoCodesRecentUsageTitle: "Последние активации",
    promoCodesNoCodeSelectedTitle: "Промокод не выбран",
    promoCodesNoCodeSelectedDescription: "Выберите строку в таблице, чтобы увидеть активации и быстрые действия.",
    promoCodesSelectForUsage: "Выберите строку в таблице, чтобы увидеть последних пользователей и время активации.",
    promoCodesRecentUsageEmpty: "У выбранного промокода еще нет активаций.",
    promoCodesActivationsLoading: "Загружаем активации выбранного промокода...",
    promoCodesActivationsError: "Не удалось загрузить активации. Попробуйте обновить список.",
    promoCodesActivationUserColumn: "Пользователь",
    promoCodesActivationDateColumn: "Дата",
    promoCodesActivationRewardColumn: "Награда",
    promoCodesActivationStatusColumn: "Статус",
    promoCodesActivationStatusSuccess: "Успешно",
    promoCodesViewAllActivationsAction: "Показать все активации",
    promoCodesShowLatestActivationsAction: "Вернуть последние",
    promoCodesViewActivationsAction: "Посмотреть активации",
    promoCodesPauseAction: "Приостановить",
    promoCodesResumeAction: "Возобновить",
    promoCodesActionsMenuLabel: "Меню действий",
    promoCodesUpdatedLabel: "Обновлен",
    promoCodesLastUsedLabel: "Последнее использование",
    promoCodesUpdatingLabel: "Обновляем...",
    promoCodesLast7DaysLabel: "за 7 дней",
    promoCodesKpiTotalHint: "Новые коды за неделю",
    promoCodesKpiActiveHint: "Активные кампании с изменениями",
    promoCodesKpiUsesHint: "Новые активации за неделю",
    promoCodesKpiGrantedHint: "Выдано через промокоды",
    promoCodesWindowAlways: "Без ограничения по времени",
    promoCodesRewardUnsupported: "Этот тип награды пока не поддерживается backend.",
    promoCodesInvalidCode: "Код должен содержать от 4 до 48 символов.",
    promoCodesInvalidNumbers: "Укажите положительные значения для награды и лимитов.",
    promoCodesLimitTooLow: "Общий лимит не может быть меньше уже использованных активаций.",
    promoCodesPerUserLimitTooLow: "Лимит на пользователя не может быть меньше уже достигнутого значения.",
    promoCodesInvalidWindow: "Дата начала не может быть позже даты окончания.",
    promoCodesCopied: "Код скопирован в буфер обмена.",
    promoCodesExported: "CSV выгружен локально.",
    promoCodesArchiveConfirm: "Архивировать этот промокод? Новые активации будут остановлены.",
    promoCodesCreateSuccess: "Промокод создан.",
    promoCodesCreateError: "Не удалось создать промокод.",
    promoCodesUpdateSuccess: "Промокод обновлен.",
    promoCodesUpdateError: "Не удалось обновить промокод.",
    promoCodesPauseSuccess: "Промокод приостановлен.",
    promoCodesPauseError: "Не удалось приостановить промокод.",
    promoCodesResumeSuccess: "Промокод снова активен.",
    promoCodesResumeError: "Не удалось возобновить промокод.",
    promoCodesArchiveSuccess: "Промокод архивирован.",
    promoCodesArchiveError: "Не удалось архивировать промокод.",
    promoCodesPreviousAction: "Назад",
    promoCodesNextAction: "Вперед",
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
    supportStatusOpenHint: "Диалог ждёт первой реакции поддержки или нового действия со стороны пользователя.",
    supportStatusInProgressHint: "Диалог взят в работу, оператор ведёт переписку и собирает детали решения.",
    supportStatusResolvedHint: "Решение уже предложено. Если пользователь ответит снова, диалог автоматически вернётся в статус «Открыт».",
    supportStatusClosedHint: "Диалог завершён вручную и исключён из активной очереди, пока пользователь не напишет заново.",
    supportStatusAutomationHint: "Ответ поддержки автоматически переводит диалог в «В работе» и назначает текущего администратора, если диалог ещё не закреплён. Сообщение пользователя после «Решен» или «Закрыт» автоматически снова открывает диалог.",
    supportBackToInbox: "К очереди",
    supportOpenConversation: "Открыть диалог",
    supportAssignedTo: "Ответственный",
    supportUnassigned: "Пока не назначен",
    supportLastMessage: "Последнее сообщение",
    supportNoMessages: "Сообщений пока нет.",
    supportReplyPlaceholder: "Напишите ответ пользователю...",
    supportReplyAction: "Ответить",
    supportReplySending: "Отправка...",
    supportAttachmentHint: "Добавьте скриншот, фото или файл до 8 MB.",
    supportAttachmentOpenAction: "Открыть файл",
    supportAttachmentRemoveAction: "Убрать вложение",
    supportSaveStatusAction: "Сохранить статус",
    supportStatusSaved: "Статус обновлен",
    supportReplySent: "Ответ отправлен",
    supportAssignToMe: "Взять в работу",
    supportUnassign: "Снять назначение",
    supportAssignmentSaved: "Назначение обновлено",
    supportQuickRepliesLabel: "Быстрые ответы",
    supportTemplatesManagerTitle: "Каталог шаблонов",
    supportTemplatesManagerDescription: "Редактируйте быстрые ответы без нового деплоя.",
    supportTemplateNoTemplates: "Шаблонов пока нет.",
    supportTemplateTitleLabel: "Название шаблона",
    supportTemplateBodyLabel: "Текст шаблона",
    supportTemplateKindReply: "Ответ пользователю",
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
    supportResolveConversationAction: "Отметить решенным",
    supportReopenConversationAction: "Переоткрыть",
    supportCloseConversationAction: "Закрыть диалог",
    supportTodayLabel: "Сегодня",
    supportViewProfileTab: "Профиль",
    supportViewPurchasesTab: "Покупки",
    supportViewGenerationsTab: "Генерации",
    supportViewErrorsTab: "Ошибки",
    supportViewUserTab: "Пользователь",
    supportViewTemplatesTab: "Шаблоны",
    supportViewHistoryTab: "История",
    supportOpenPanelAction: "Открыть панель",
    supportClosePanelAction: "Скрыть панель",
    supportTimelineTitle: "Хронология диалога",
    supportTimelineConversationCreated: "Обращение создано",
    supportTimelineUserMessage: "Сообщение пользователя",
    supportTimelineAdminReply: "Ответ поддержки",
    supportHistoryEmpty: "История пока пуста.",
    supportStatusWorkflowTitle: "Статус и workflow",
    supportConversationMetaTitle: "Состояние диалога",
    supportPlanLabel: "План",
    supportAccountAgeLabel: "Аккаунт",
    supportPurchasesLabel: "Покупки",
    supportRecentPurchasesTitle: "Последние покупки",
    supportRecentGenerationsTitle: "Последние генерации",
    supportGenerationErrorsTitle: "Ошибки генераций",
    supportNoPurchases: "Покупок пока нет.",
    supportNoGenerationErrors: "Ошибок генераций нет.",
    supportOccurrencesLabel: "Случаев",
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
    navPromoCodes: "Promo Codes",
    navSectionOverview: "Overview",
    navSectionGrowth: "Growth",
    navSectionContent: "Content",
    navSectionUsers: "Users",
    navLogout: "Logout",
    promoCodesHeroEyebrow: "Tokens and redemption flow",
    promoCodesHeroDescription: "Dedicated token-only workspace for promo code creation, limits, availability windows, and recent redemptions.",
    promoCodesTokenOnlyBadge: "PawSpark only",
    promoCodesLoadingDescription: "Loading active and archived promo codes from the economy backend.",
    promoCodesErrorDescription: "Failed to load promo codes. Check backend availability and try again.",
    promoCodesCreateAction: "Create promo code",
    promoCodesExportAction: "Export CSV",
    promoCodesRefreshAction: "Refresh",
    promoCodesTableDescription: "Search by code, filter by status, and run manual actions without leaving this page.",
    promoCodesSearchPlaceholder: "Search by code or description",
    promoCodesStatusFilterLabel: "Status filter",
    promoCodesSortLabel: "Sort by",
    promoCodesStatusAll: "All statuses",
    promoCodesStatusDraft: "Draft",
    promoCodesStatusPaused: "Paused",
    promoCodesStatusLimitReached: "Limit reached",
    promoCodesStatusArchived: "Archived",
    promoCodesStatusExhausted: "Limit reached",
    promoCodesStatusScheduled: "Scheduled",
    promoCodesStatusExpired: "Expired",
    promoCodesSortUpdated: "Recently updated",
    promoCodesSortUsage: "Most used",
    promoCodesSortReward: "Highest reward",
    promoCodesSortCode: "Code",
    promoCodesSortExpiry: "Expiry",
    promoCodesTotalLabel: "Total codes",
    promoCodesActiveLabel: "Live now",
    promoCodesUsesLabel: "Redemptions",
    promoCodesGrantedLabel: "Tokens granted",
    promoCodesEmptyDescription: "No promo codes yet. Create the first token-only code from the panel on the right.",
    promoCodesNoResults: "No promo codes match the current filters. Clear the search or change status.",
    promoCodesCodeLabel: "Code",
    promoCodesDescriptionLabel: "Description",
    promoCodesRewardLabel: "Reward",
    promoCodesUsageLabel: "Usage",
    promoCodesWindowLabel: "Availability",
    promoCodesUpdatedColumn: "Updated",
    promoCodesCopyAction: "Copy",
    promoCodesDuplicateAction: "Duplicate",
    promoCodesCreatePanelTitle: "New promo code",
    promoCodesEditPanelTitle: "Edit promo code",
    promoCodesDuplicatePanelTitle: "Duplicate promo code",
    promoCodesRewardFixedLabel: "Reward type: PawSpark tokens",
    promoCodesFormCardDescription: "Configure promo code rules, verify limits, and launch campaign-ready entries from one panel.",
    promoCodesSectionMainTitle: "1. Basics",
    promoCodesSectionCampaignTitle: "2. Campaign",
    promoCodesSectionRewardTitle: "3. Reward",
    promoCodesSectionLimitsTitle: "4. Limits",
    promoCodesNewDraftAction: "New draft",
    promoCodesGenerateCodeAction: "Generate",
    promoCodesCodeHelp: "Set a custom code or generate one automatically. After creation it becomes read-only.",
    promoCodesCampaignNameLabel: "Campaign name",
    promoCodesCampaignChannelLabel: "Channel",
    promoCodesCampaignCreatedByLabel: "Created by",
    promoCodesMinimumPurchasesLabel: "Min successful purchases",
    promoCodesMinimumPurchasesHint: "0 means no purchase gate. Value is validated during redemption.",
    promoCodesStatusFieldLabel: "Publishing status",
    promoCodesStatusActiveOption: "Active",
    promoCodesStatusPausedOption: "Paused",
    promoCodesRewardTypeLabel: "Reward type",
    promoCodesRewardTypeSparkOption: "PawSpark tokens",
    promoCodesRewardTypePremiumOption: "Premium unlock (soon)",
    promoCodesRewardTypeHint: "Backend currently supports PawSpark token rewards only.",
    promoCodesRewardValueLabel: "Amount",
    promoCodesLimitLabel: "Total limit",
    promoCodesPerUserLimitLabel: "Per-user limit",
    promoCodesStartsLabel: "Starts",
    promoCodesExpiresLabel: "Expires",
    promoCodesSaveUpdateAction: "Save changes",
    promoCodesSaveCreateAction: "Create and save",
    promoCodesRecentUsageTitle: "Recent redemptions",
    promoCodesNoCodeSelectedTitle: "No promo code selected",
    promoCodesNoCodeSelectedDescription: "Select a table row to inspect activations and quick actions.",
    promoCodesSelectForUsage: "Pick a row in the table to inspect the latest users and redemption timestamps.",
    promoCodesRecentUsageEmpty: "The selected promo code has no redemptions yet.",
    promoCodesActivationsLoading: "Loading activations for the selected promo code...",
    promoCodesActivationsError: "Failed to load activations. Try refreshing the list.",
    promoCodesActivationUserColumn: "User",
    promoCodesActivationDateColumn: "Date",
    promoCodesActivationRewardColumn: "Reward",
    promoCodesActivationStatusColumn: "Status",
    promoCodesActivationStatusSuccess: "Success",
    promoCodesViewAllActivationsAction: "View all activations",
    promoCodesShowLatestActivationsAction: "Show latest only",
    promoCodesViewActivationsAction: "View activations",
    promoCodesPauseAction: "Pause",
    promoCodesResumeAction: "Resume",
    promoCodesActionsMenuLabel: "Actions menu",
    promoCodesUpdatedLabel: "Updated",
    promoCodesLastUsedLabel: "Last used",
    promoCodesUpdatingLabel: "Refreshing...",
    promoCodesLast7DaysLabel: "in last 7 days",
    promoCodesKpiTotalHint: "New codes in the last week",
    promoCodesKpiActiveHint: "Active campaigns with recent changes",
    promoCodesKpiUsesHint: "New redemptions in the last week",
    promoCodesKpiGrantedHint: "Granted through promo codes",
    promoCodesWindowAlways: "Always available",
    promoCodesRewardUnsupported: "This reward type is not supported by backend yet.",
    promoCodesInvalidCode: "Code must be between 4 and 48 characters.",
    promoCodesInvalidNumbers: "Enter positive values for reward and limits.",
    promoCodesLimitTooLow: "Total limit cannot be lower than existing redemptions.",
    promoCodesPerUserLimitTooLow: "Per-user limit cannot be lower than the highest existing user usage.",
    promoCodesInvalidWindow: "Start date cannot be later than the expiry date.",
    promoCodesCopied: "Promo code copied to clipboard.",
    promoCodesExported: "CSV exported locally.",
    promoCodesArchiveConfirm: "Archive this promo code? New redemptions will stop immediately.",
    promoCodesCreateSuccess: "Promo code created.",
    promoCodesCreateError: "Failed to create promo code.",
    promoCodesUpdateSuccess: "Promo code updated.",
    promoCodesUpdateError: "Failed to update promo code.",
    promoCodesPauseSuccess: "Promo code paused.",
    promoCodesPauseError: "Failed to pause promo code.",
    promoCodesResumeSuccess: "Promo code resumed.",
    promoCodesResumeError: "Failed to resume promo code.",
    promoCodesArchiveSuccess: "Promo code archived.",
    promoCodesArchiveError: "Failed to archive promo code.",
    promoCodesPreviousAction: "Previous",
    promoCodesNextAction: "Next",
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
    supportStatusOpenHint: "The conversation is waiting for the first support action or for a new user update.",
    supportStatusInProgressHint: "An operator is actively handling the case and working through the resolution.",
    supportStatusResolvedHint: "A solution has been given. If the user replies again, the conversation automatically returns to Open.",
    supportStatusClosedHint: "The conversation was manually finished and removed from the active queue until the user writes again.",
    supportStatusAutomationHint: "A support reply automatically moves the conversation to In progress and assigns the current admin when the chat is still unassigned. A user reply after Resolved or Closed automatically reopens the conversation.",
    supportBackToInbox: "Back to inbox",
    supportOpenConversation: "Open conversation",
    supportAssignedTo: "Assigned to",
    supportUnassigned: "Unassigned",
    supportLastMessage: "Last message",
    supportNoMessages: "No messages yet.",
    supportReplyPlaceholder: "Write a reply to the user...",
    supportReplyAction: "Reply",
    supportReplySending: "Sending...",
    supportAttachmentHint: "Add a screenshot, image, or file up to 8 MB.",
    supportAttachmentOpenAction: "Open file",
    supportAttachmentRemoveAction: "Remove attachment",
    supportSaveStatusAction: "Save status",
    supportStatusSaved: "Status updated",
    supportReplySent: "Reply sent",
    supportAssignToMe: "Assign to me",
    supportUnassign: "Unassign",
    supportAssignmentSaved: "Assignment updated",
    supportQuickRepliesLabel: "Quick replies",
    supportTemplatesManagerTitle: "Template catalog",
    supportTemplatesManagerDescription: "Edit quick replies without another deploy.",
    supportTemplateNoTemplates: "No templates yet.",
    supportTemplateTitleLabel: "Template title",
    supportTemplateBodyLabel: "Template body",
    supportTemplateKindReply: "User reply",
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
    supportResolveConversationAction: "Mark resolved",
    supportReopenConversationAction: "Reopen",
    supportCloseConversationAction: "Close conversation",
    supportTodayLabel: "Today",
    supportViewProfileTab: "Profile",
    supportViewPurchasesTab: "Purchases",
    supportViewGenerationsTab: "Generations",
    supportViewErrorsTab: "Errors",
    supportViewUserTab: "User",
    supportViewTemplatesTab: "Templates",
    supportViewHistoryTab: "History",
    supportOpenPanelAction: "Open panel",
    supportClosePanelAction: "Hide panel",
    supportTimelineTitle: "Conversation timeline",
    supportTimelineConversationCreated: "Conversation created",
    supportTimelineUserMessage: "User message",
    supportTimelineAdminReply: "Support reply",
    supportHistoryEmpty: "No history yet.",
    supportStatusWorkflowTitle: "Status and workflow",
    supportConversationMetaTitle: "Conversation state",
    supportPlanLabel: "Plan",
    supportAccountAgeLabel: "Account",
    supportPurchasesLabel: "Purchases",
    supportRecentPurchasesTitle: "Recent purchases",
    supportRecentGenerationsTitle: "Recent generations",
    supportGenerationErrorsTitle: "Generation errors",
    supportNoPurchases: "No purchases yet.",
    supportNoGenerationErrors: "No generation errors.",
    supportOccurrencesLabel: "Occurrences",
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
