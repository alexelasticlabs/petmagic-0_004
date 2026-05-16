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
  roleLabel: string;
  premiumLabel: string;
  activeLabel: string;
  statusLabel: string;
  navDashboard: string;
  navUsers: string;
  navTemplates: string;
  navImageTemplates: string;
  navVideoTemplates: string;
  navTemplateCategories: string;
  navLogout: string;
  loading: string;
  errorLoadingUsers: string;
  errorLoadingTemplates: string;
  errorSavingTemplate: string;
  errorActivatingTemplate: string;
  errorDeletingTemplate: string;
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
  musicDescriptionLabel: string;
  referenceMotionTitle: string;
  referenceUrlLabel: string;
  referenceDurationLabel: string;
  characterOrientationLabel: string;
  preprocessingModelLabel: string;
  preprocessingPromptLabel: string;
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
};

const dictionaries: Record<Locale, Dictionary> = {
  ru: {
    loginTitle: "Вход в систему",
    loginHint: "Используйте свои учетные данные для входа",
    emailLabel: "Email",
    passwordLabel: "Пароль",
    signIn: "Войти",
    usersTitle: "Пользователи",
    roleLabel: "Роль",
    premiumLabel: "Premium",
    activeLabel: "Активен",
    statusLabel: "Статус",
    navDashboard: "Дашборд",
    navUsers: "Пользователи",
    navTemplates: "Шаблоны",
    navImageTemplates: "Шаблоны изображений",
    navVideoTemplates: "Видео шаблоны",
    navTemplateCategories: "Категории",
    navLogout: "Выйти",
    loading: "Загрузка...",
    errorLoadingUsers: "Не удалось загрузить пользователей.",
    errorLoadingTemplates: "Не удалось загрузить шаблоны.",
    errorSavingTemplate: "Не удалось сохранить шаблон.",
    errorActivatingTemplate: "Не удалось активировать шаблон.",
    errorDeletingTemplate: "Не удалось удалить шаблон.",
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
    musicDescriptionLabel: "Описание музыки / звука",
    referenceMotionTitle: "Референсное видео движения",
    referenceUrlLabel: "URL референсного видео",
    referenceDurationLabel: "Длительность референсного видео, сек.",
    characterOrientationLabel: "Ориентация персонажа",
    preprocessingModelLabel: "Модель препроцессинга",
    preprocessingPromptLabel: "Промпт препроцессинга",
    klingModelLabel: "Модель Kling",
    klingPromptLabel: "Промпт Kling",
    keepOriginalSoundLabel: "Сохранять оригинальный звук",
    computedValueHint: "Вычисляется backend и не редактируется вручную.",
    saveTemplate: "Сохранить",
    resetForm: "Сбросить",
    uploadPreview: "Загрузить preview",
    uploadReference: "Загрузить референсное видео",
    uploadAction: "Загрузить",
    uploadingMedia: "Загрузка файла...",
    mediaUploadHint: "После загрузки backend сам определяет URL, имя файла, тип, размер и длительность media.",
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
    editorMediaRequirements: "Все видео должны быть вертикальными 9:16. Длительность reference влияет на auto-detected character orientation."
  },
  en: {
    loginTitle: "Sign in",
    loginHint: "Use your credentials to sign in",
    emailLabel: "Email",
    passwordLabel: "Password",
    signIn: "Sign in",
    usersTitle: "Users",
    roleLabel: "Role",
    premiumLabel: "Premium",
    activeLabel: "Active",
    statusLabel: "Status",
    navDashboard: "Dashboard",
    navUsers: "Users",
    navTemplates: "Templates",
    navImageTemplates: "Image Templates",
    navVideoTemplates: "Video Templates",
    navTemplateCategories: "Categories",
    navLogout: "Logout",
    loading: "Loading...",
    errorLoadingUsers: "Failed to load users.",
    errorLoadingTemplates: "Failed to load templates.",
    errorSavingTemplate: "Failed to save template.",
    errorActivatingTemplate: "Failed to activate template.",
    errorDeletingTemplate: "Failed to delete template.",
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
    musicDescriptionLabel: "Music / sound description",
    referenceMotionTitle: "Reference motion video",
    referenceUrlLabel: "Reference video URL",
    referenceDurationLabel: "Reference video duration, sec",
    characterOrientationLabel: "Character orientation",
    preprocessingModelLabel: "Preprocessing model",
    preprocessingPromptLabel: "Preprocessing prompt",
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
    editorMediaRequirements: "All videos should stay vertical 9:16. Reference duration affects the auto-detected character orientation."
  }
};

export function isLocale(value: string): value is Locale {
  return locales.includes(value as Locale);
}

export function getDictionary(locale: Locale): Dictionary {
  return dictionaries[locale];
}
