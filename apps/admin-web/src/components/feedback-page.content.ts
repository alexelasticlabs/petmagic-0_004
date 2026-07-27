import type { FeedbackPriority, FeedbackStatus, FeedbackType } from "@/lib/api-client";
import { type Locale } from "@/lib/i18n";

type FeedbackOption<T extends string> = Record<T | "All", string>;

export type FeedbackPageText = {
  title: string;
  description: string;
  queue: string;
  queueDescription: string;
  filters: string;
  advancedFilters: string;
  advancedFiltersWithCount: (count: number) => string;
  hideAdvancedFilters: string;
  resetFilters: string;
  refresh: string;
  refreshing: string;
  applyingFilters: string;
  queueRefreshError: string;
  results: (shown: number, total: number) => string;
  pagePosition: (page: number, start: number, end: number, total: number) => string;
  removeFilter: (label: string) => string;
  updatedAt: string;
  status: string;
  priority: string;
  type: string;
  category: string;
  platform: string;
  templateId: string;
  generationId: string;
  userId: string;
  lookupValue: string;
  lookupField: string;
  lookupPlaceholder: (field: string) => string;
  from: string;
  to: string;
  invalidDateRange: string;
  invalidLookupValue: string;
  user: string;
  date: string;
  rating: string;
  template: string;
  message: string;
  preview: string;
  selectFeedback: string;
  selectedFeedback: string;
  empty: string;
  emptyFilteredDescription: string;
  emptySelection: string;
  noMessage: string;
  loading: string;
  error: string;
  detailsLoading: string;
  detailsError: string;
  userContextErrorTitle: string;
  userContextErrorDescription: string;
  retry: string;
  save: string;
  saved: string;
  saveError: string;
  unsavedChanges: string;
  discardChanges: string;
  discardChangesTitle: string;
  discardChangesDescription: string;
  closeSelection: string;
  refund: string;
  refunded: string;
  refundSuccess: (credits: number) => string;
  refundError: string;
  refundTitle: string;
  refundDescription: (credits: number) => string;
  refundReason: string;
  refundReasonPlaceholder: string;
  refundReasonRequired: string;
  refundReasonLength: (length: number, maxLength: number) => string;
  refundAmountInvalid: (maxCredits: number) => string;
  refundConfirm: string;
  refundUnavailable: string;
  refundAlreadyIssued: string;
  refundNoCredits: string;
  refundAdminOnly: string;
  cancel: string;
  note: string;
  addNote: string;
  decision: string;
  relatedFeedback: string;
  relatedUserFeedback: string;
  relatedGenerationFeedback: string;
  relatedTemplateFeedback: string;
  generation: string;
  input: string;
  result: string;
  technical: string;
  audit: string;
  reviewedAt: string;
  refundAudit: (credits: number, createdAt: string) => string;
  planCredits: string;
  source: string;
  app: string;
  device: string;
  provider: string;
  errorCode: string;
  credits: string;
  viewUser: string;
  previousPageLabel: string;
  nextPageLabel: string;
  userContextLoading: string;
  userPlanPremium: string;
  userPlanFree: string;
  statusOptions: FeedbackOption<FeedbackStatus>;
  priorityOptions: FeedbackOption<FeedbackPriority>;
  typeOptions: FeedbackOption<FeedbackType>;
  lookupOptions: Record<"userId" | "templateId" | "generationId", string>;
  categoryLabels: Record<string, string>;
  sourceLabels: Record<string, string>;
  ratingLabels: {
    positive: string;
    neutral: string;
    negative: string;
  };
};

const feedbackPageText: Record<Locale, FeedbackPageText> = {
  ru: {
    title: "Отзывы",
    description: "Рабочая очередь обратной связи по генерациям, ошибкам, оплате и предложениям.",
    queue: "Очередь обращений",
    queueDescription: "Выберите обращение, чтобы разобрать контекст и принять решение.",
    filters: "Фильтры",
    advancedFilters: "Дополнительные фильтры",
    advancedFiltersWithCount: (count) =>
      count > 0 ? `Дополнительные фильтры: ${count}` : "Дополнительные фильтры",
    hideAdvancedFilters: "Скрыть дополнительные фильтры",
    resetFilters: "Сбросить фильтры",
    refresh: "Обновить",
    refreshing: "Обновляем очередь",
    applyingFilters: "Применяем фильтры",
    queueRefreshError: "Не удалось обновить очередь. Показаны последние доступные данные.",
    results: (shown, total) => `Показано ${shown} из ${total}`,
    pagePosition: (page, start, end, total) =>
      total > 0 ? `${start}–${end} из ${total} · стр. ${page}` : "Нет обращений",
    removeFilter: (label) => `Убрать фильтр: ${label}`,
    updatedAt: "Обновлено",
    status: "Статус",
    priority: "Приоритет",
    type: "Тип",
    category: "Категория",
    platform: "Платформа",
    templateId: "ID шаблона",
    generationId: "ID генерации",
    userId: "ID пользователя",
    lookupValue: "Значение",
    lookupField: "Найти по",
    lookupPlaceholder: (field) => `Введите ${field.toLocaleLowerCase("ru")}`,
    from: "С даты",
    to: "До даты",
    invalidDateRange: "Дата начала не может быть позже даты окончания.",
    invalidLookupValue: "Введите корректный UUID для поиска.",
    user: "Пользователь",
    date: "Дата",
    rating: "Оценка",
    template: "Шаблон",
    message: "Сообщение",
    preview: "Превью",
    selectFeedback: "Выбрать обращение",
    selectedFeedback: "Выбранное обращение",
    empty: "По выбранным условиям обращений нет",
    emptyFilteredDescription:
      "Снимите один или несколько фильтров, чтобы вернуться к полной очереди обращений.",
    emptySelection:
      "Выберите обращение в очереди, чтобы увидеть сообщение, контекст и доступные действия.",
    noMessage: "Пользователь не оставил текстового комментария.",
    loading: "Загрузка обращений",
    error: "Не удалось загрузить обращения",
    detailsLoading: "Загрузка обращения",
    detailsError: "Не удалось загрузить детали обращения",
    userContextErrorTitle: "Контекст пользователя временно недоступен",
    userContextErrorDescription:
      "Детали обращения загружены, но профиль или аналитика пользователя не ответили.",
    retry: "Повторить",
    save: "Сохранить",
    saved: "Изменения сохранены",
    saveError: "Не удалось сохранить изменения обращения.",
    unsavedChanges: "Есть несохранённые изменения",
    discardChanges: "Не сохранять",
    discardChangesTitle: "Не сохранить изменения?",
    discardChangesDescription:
      "Статус, приоритет и заметка администратора будут потеряны для текущего обращения.",
    closeSelection: "Закрыть детали",
    refund: "Вернуть кредиты",
    refunded: "Кредиты возвращены",
    refundSuccess: (credits) => `Возвращено кредитов: ${credits}`,
    refundError: "Не удалось вернуть кредиты.",
    refundTitle: "Подтвердите возврат кредитов",
    refundDescription: (credits) =>
      `Пользователю будет возвращено ${credits} кредитов. Операция фиксируется в аудите и не отменяется на этой странице.`,
    refundReason: "Причина возврата",
    refundReasonPlaceholder: "Например: подтверждённый сбой генерации",
    refundReasonRequired: "Укажите причину возврата для аудита.",
    refundReasonLength: (length, maxLength) => `Символов: ${length} из ${maxLength}`,
    refundAmountInvalid: (maxCredits) =>
      `Введите целое число от 1 до ${maxCredits}, чтобы сумма возврата была точной.`,
    refundConfirm: "Подтвердить возврат",
    refundUnavailable: "Возврат кредитов для этого обращения недоступен.",
    refundAlreadyIssued: "Кредиты по этому обращению уже возвращены.",
    refundNoCredits: "У этой генерации нет списанных кредитов для возврата.",
    refundAdminOnly: "Возврат кредитов доступен только администратору.",
    cancel: "Отмена",
    note: "Заметка администратора",
    addNote: "Добавить заметку",
    decision: "Решение",
    relatedFeedback: "Связанные обращения",
    relatedUserFeedback: "Все отзывы пользователя",
    relatedGenerationFeedback: "По этой генерации",
    relatedTemplateFeedback: "По этому шаблону",
    generation: "Генерация",
    input: "Входные данные",
    result: "Результат",
    technical: "Технические данные",
    audit: "Аудит решения",
    reviewedAt: "Рассмотрено",
    refundAudit: (credits, createdAt) => `Возврат ${credits} кредитов · ${createdAt}`,
    planCredits: "План / кредиты",
    source: "Источник",
    app: "Версия приложения",
    device: "Устройство",
    provider: "Провайдер",
    errorCode: "Код ошибки",
    credits: "кредитов",
    viewUser: "Открыть пользователя",
    previousPageLabel: "Предыдущая страница обращений",
    nextPageLabel: "Следующая страница обращений",
    userContextLoading: "Загрузка...",
    userPlanPremium: "Премиум",
    userPlanFree: "Бесплатный",
    statusOptions: {
      All: "Все",
      New: "Новые",
      InReview: "На проверке",
      Resolved: "Решённые",
      Dismissed: "Отклонённые",
    },
    priorityOptions: {
      All: "Любой приоритет",
      Low: "Низкий",
      Medium: "Средний",
      High: "Высокий",
      Critical: "Критический",
    },
    typeOptions: {
      All: "Все типы",
      GenerationResult: "Результат генерации",
      GenerationFailure: "Сбой генерации",
      BugReport: "Ошибка",
      FeatureRequest: "Запрос фичи",
      PaymentIssue: "Проблема с оплатой",
      General: "Общее",
    },
    lookupOptions: {
      userId: "ID пользователя",
      templateId: "ID шаблона",
      generationId: "ID генерации",
    },
    categoryLabels: {
      general: "Общий отзыв",
      low_value: "Низкая ценность",
      payment: "Оплата",
      bug: "Ошибка",
      feature_request: "Запрос фичи",
    },
    sourceLabels: {
      paywall_close: "Закрытие paywall",
      generation_result: "Результат генерации",
      generation_error: "Ошибка генерации",
      profile: "Профиль",
    },
    ratingLabels: {
      positive: "Хорошо",
      neutral: "Нейтрально",
      negative: "Плохо",
    },
  },
  en: {
    title: "Feedback",
    description: "An operational queue for generation, bug, payment, and product feedback.",
    queue: "Feedback queue",
    queueDescription: "Select an item to review its context and make a decision.",
    filters: "Filters",
    advancedFilters: "Advanced filters",
    advancedFiltersWithCount: (count) =>
      count > 0 ? `Advanced filters: ${count}` : "Advanced filters",
    hideAdvancedFilters: "Hide advanced filters",
    resetFilters: "Reset filters",
    refresh: "Refresh",
    refreshing: "Refreshing queue",
    applyingFilters: "Applying filters",
    queueRefreshError: "The queue could not be refreshed. The latest available data is shown.",
    results: (shown, total) => `Showing ${shown} of ${total}`,
    pagePosition: (page, start, end, total) =>
      total > 0 ? `${start}–${end} of ${total} · page ${page}` : "No feedback",
    removeFilter: (label) => `Remove filter: ${label}`,
    updatedAt: "Updated",
    status: "Status",
    priority: "Priority",
    type: "Type",
    category: "Category",
    platform: "Platform",
    templateId: "Template ID",
    generationId: "Generation ID",
    userId: "User ID",
    lookupValue: "Value",
    lookupField: "Find by",
    lookupPlaceholder: (field) => `Enter ${field.toLocaleLowerCase("en")}`,
    from: "From date",
    to: "To date",
    invalidDateRange: "The start date cannot be after the end date.",
    invalidLookupValue: "Enter a valid UUID to search.",
    user: "User",
    date: "Date",
    rating: "Rating",
    template: "Template",
    message: "Message",
    preview: "Preview",
    selectFeedback: "Select feedback",
    selectedFeedback: "Selected feedback",
    empty: "No feedback matches the selected filters",
    emptyFilteredDescription: "Remove one or more filters to return to the full feedback queue.",
    emptySelection:
      "Select an item in the queue to see its message, context, and available actions.",
    noMessage: "The user did not leave a text comment.",
    loading: "Loading feedback",
    error: "Failed to load feedback",
    detailsLoading: "Loading feedback",
    detailsError: "Failed to load feedback details",
    userContextErrorTitle: "User context temporarily unavailable",
    userContextErrorDescription:
      "Feedback details loaded, but the user profile or analytics did not respond.",
    retry: "Retry",
    save: "Save",
    saved: "Changes saved",
    saveError: "Failed to save feedback changes.",
    unsavedChanges: "You have unsaved changes",
    discardChanges: "Discard changes",
    discardChangesTitle: "Discard unsaved changes?",
    discardChangesDescription:
      "The status, priority, and admin note for the current feedback will be lost.",
    closeSelection: "Close details",
    refund: "Refund credits",
    refunded: "Credits refunded",
    refundSuccess: (credits) => `Refunded credits: ${credits}`,
    refundError: "Failed to refund credits.",
    refundTitle: "Confirm credit refund",
    refundDescription: (credits) =>
      `${credits} credits will be returned to the user. This action is audited and cannot be reversed from this page.`,
    refundReason: "Refund reason",
    refundReasonPlaceholder: "For example: confirmed generation failure",
    refundReasonRequired: "Enter a refund reason for the audit trail.",
    refundReasonLength: (length, maxLength) => `${length} of ${maxLength} characters`,
    refundAmountInvalid: (maxCredits) =>
      `Enter a whole number from 1 to ${maxCredits} so the refund amount is exact.`,
    refundConfirm: "Confirm refund",
    refundUnavailable: "A credit refund is unavailable for this feedback item.",
    refundAlreadyIssued: "Credits for this feedback item have already been refunded.",
    refundNoCredits: "This generation has no charged credits to refund.",
    refundAdminOnly: "Only an administrator can refund credits.",
    cancel: "Cancel",
    note: "Admin note",
    addNote: "Add note",
    decision: "Decision",
    relatedFeedback: "Related feedback",
    relatedUserFeedback: "All feedback from this user",
    relatedGenerationFeedback: "For this generation",
    relatedTemplateFeedback: "For this template",
    generation: "Generation",
    input: "Input",
    result: "Result",
    technical: "Technical details",
    audit: "Decision audit",
    reviewedAt: "Reviewed",
    refundAudit: (credits, createdAt) => `Refunded ${credits} credits · ${createdAt}`,
    planCredits: "Plan / credits",
    source: "Source",
    app: "App version",
    device: "Device",
    provider: "Provider",
    errorCode: "Error code",
    credits: "credits",
    viewUser: "Open user",
    previousPageLabel: "Previous feedback page",
    nextPageLabel: "Next feedback page",
    userContextLoading: "Loading...",
    userPlanPremium: "Premium",
    userPlanFree: "Free",
    statusOptions: {
      All: "All",
      New: "New",
      InReview: "In review",
      Resolved: "Resolved",
      Dismissed: "Dismissed",
    },
    priorityOptions: {
      All: "Any priority",
      Low: "Low",
      Medium: "Medium",
      High: "High",
      Critical: "Critical",
    },
    typeOptions: {
      All: "All types",
      GenerationResult: "Generation result",
      GenerationFailure: "Generation failure",
      BugReport: "Bug report",
      FeatureRequest: "Feature request",
      PaymentIssue: "Payment issue",
      General: "General",
    },
    lookupOptions: {
      userId: "User ID",
      templateId: "Template ID",
      generationId: "Generation ID",
    },
    categoryLabels: {
      general: "General feedback",
      low_value: "Low value",
      payment: "Payment",
      bug: "Bug",
      feature_request: "Feature request",
    },
    sourceLabels: {
      paywall_close: "Paywall close",
      generation_result: "Generation result",
      generation_error: "Generation error",
      profile: "Profile",
    },
    ratingLabels: {
      positive: "Good",
      neutral: "Neutral",
      negative: "Poor",
    },
  },
};

export function getFeedbackPageText(locale: Locale): FeedbackPageText {
  return feedbackPageText[locale];
}
