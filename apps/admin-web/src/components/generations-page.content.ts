import type {
  AdminGenerationRefundState,
  AdminGenerationStatus,
  FeedbackPriority,
  FeedbackStatus,
  FeedbackType,
} from "@/lib/api-client";
import { type Locale } from "@/lib/i18n";

type GenerationStatusOption = AdminGenerationStatus | "All";
type GenerationRefundStateOption = AdminGenerationRefundState | "all";

type OptionLabels<T extends string> = Record<T, string>;

export type GenerationsPageText = {
  eyebrow: string;
  title: string;
  description: string;
  adminOnly: string;
  total: string;
  pending: string;
  running: string;
  completed: string;
  failed: string;
  cancelled: string;
  cancelling: string;
  retrying: string;
  pendingRefunds: string;
  exhaustedRefunds: string;
  allJobsScope: string;
  filtersTitle: string;
  filtersDescription: string;
  searchLabel: string;
  searchPlaceholder: string;
  statusLabel: string;
  refundStateLabel: string;
  providerLabel: string;
  providerPlaceholder: string;
  userLabel: string;
  userPlaceholder: string;
  tableTitle: string;
  showDetails: string;
  hideDetails: string;
  copyId: string;
  copiedId: string;
  copyIdFailed: string;
  before: string;
  after: string;
  compareReady: string;
  compareUnavailable: string;
  compareState: string;
  sourceType: string;
  inputAsset: string;
  resultAsset: string;
  pet: string;
  petPhoto: string;
  diagnosticsTitle: string;
  emptyTitle: string;
  emptyDescription: string;
  loadingTitle: string;
  errorTitle: string;
  metricsErrorTitle: string;
  metricsErrorDescription: string;
  retry: string;
  job: string;
  user: string;
  template: string;
  status: string;
  provider: string;
  cost: string;
  attempts: string;
  failure: string;
  watermark: string;
  watermarkApplied: string;
  watermarkNotRequired: string;
  watermarkRemoved: string;
  watermarkPending: string;
  watermarkUnlockedBy: string;
  cancelGeneration: string;
  cancellingGeneration: string;
  cancelGenerationError: string;
  cancelGenerationConfirmTitle: string;
  cancelGenerationConfirmDescription: (generationId: string) => string;
  cancelGenerationConfirmCancel: string;
  cancelGenerationConfirmSubmit: string;
  retryGeneration: string;
  retryingGeneration: string;
  retryGenerationError: string;
  retryGenerationConfirmTitle: string;
  retryGenerationConfirmDescription: (generationId: string) => string;
  retryGenerationConfirmCancel: string;
  retryGenerationConfirmSubmit: string;
  retryRefund: string;
  retryingRefund: string;
  retryRefundError: string;
  retryRefundConflict: string;
  retryRefundConfirmTitle: string;
  retryRefundConfirmDescription: (generationId: string) => string;
  retryRefundReasonLabel: string;
  retryRefundReasonPlaceholder: string;
  retryRefundReasonRequired: string;
  retryRefundConfirmCancel: string;
  retryRefundConfirmSubmit: string;
  refundState: string;
  refundAttempts: string;
  refundLastAttempt: string;
  refundLastError: string;
  grantClean: string;
  grantingClean: string;
  grantCleanError: string;
  gamificationLegacyReview: string;
  gamificationLegacyReviewDescription: (generationId: string) => string;
  gamificationLegacyReviewActionLabel: string;
  gamificationLegacyReviewMarkDelivered: string;
  gamificationLegacyReviewReplay: string;
  gamificationLegacyReviewReasonLabel: string;
  gamificationLegacyReviewReasonPlaceholder: string;
  gamificationLegacyReviewReasonRequired: string;
  gamificationLegacyReviewError: string;
  gamificationLegacyReviewCancel: string;
  gamificationLegacyReviewSubmit: string;
  created: string;
  completedAt: string;
  noFailure: string;
  previousPageLabel: string;
  nextPageLabel: string;
  page: string;
  of: string;
  tableTotalLabel: string;
  usdLabel: string;
  creditsLabel: string;
  feedbackTab: string;
  feedbackEmpty: string;
  feedbackError: string;
  lineageSimilarPrefix: string;
  lineageChildSingular: string;
  lineageChildPlural: string;
  variationLabel: string;
  seedLabel: string;
  generationStatusOptions: OptionLabels<GenerationStatusOption>;
  refundStateOptions: OptionLabels<GenerationRefundStateOption>;
  templateTypeLabels: OptionLabels<"Image" | "Video">;
  inputSourceTypeLabels: OptionLabels<"generation_result" | "pet_photo" | "user_upload">;
  feedbackTypeOptions: OptionLabels<FeedbackType>;
  feedbackStatusOptions: OptionLabels<FeedbackStatus>;
  feedbackPriorityOptions: OptionLabels<FeedbackPriority>;
  ratingLabels: {
    positive: string;
    neutral: string;
    negative: string;
  };
};

const generationsPageText: Record<Locale, GenerationsPageText> = {
  ru: {
    eyebrow: "Операции",
    title: "Генерации",
    description:
      "Операционный список заданий генерации, статусов, провайдеров, попыток и кодов ошибок.",
    adminOnly: "Только администратор",
    total: "Всего заданий",
    pending: "Ожидает",
    running: "В работе",
    completed: "Завершена",
    failed: "Ошибка",
    cancelled: "Отменена",
    cancelling: "Отменяется",
    retrying: "Повторяется",
    pendingRefunds: "Возврат в очереди",
    exhaustedRefunds: "Возврат исчерпан",
    allJobsScope: "Все задания",
    filtersTitle: "Фильтры",
    filtersDescription: "Сузьте список по ID задания, статусу, провайдеру или ID пользователя.",
    searchLabel: "ID задания",
    searchPlaceholder: "Поиск по ID генерации",
    statusLabel: "Статус",
    refundStateLabel: "Возврат списания",
    providerLabel: "Провайдер",
    providerPlaceholder: "fal, openai...",
    userLabel: "ID пользователя",
    userPlaceholder: "Фильтр по ID пользователя",
    tableTitle: "История генераций",
    showDetails: "Показать",
    hideDetails: "Скрыть",
    copyId: "Копировать полный ID",
    copiedId: "ID скопирован",
    copyIdFailed: "Не удалось скопировать ID",
    before: "До",
    after: "После",
    compareReady: "Доступно",
    compareUnavailable: "Недоступно",
    compareState: "Сравнение",
    sourceType: "Источник",
    inputAsset: "Входной медиафайл",
    resultAsset: "Результирующий медиафайл",
    pet: "Питомец",
    petPhoto: "Фото питомца",
    diagnosticsTitle: "Диагностика",
    emptyTitle: "Генераций не найдено",
    emptyDescription: "Измените фильтры или дождитесь новых заданий генерации.",
    loadingTitle: "Загрузка генераций",
    errorTitle: "Не удалось загрузить генерации",
    metricsErrorTitle: "Сводка генераций временно недоступна",
    metricsErrorDescription:
      "История генераций загружается отдельно; повторите запрос, чтобы обновить верхние счётчики.",
    retry: "Повторить",
    job: "Задание",
    user: "Пользователь",
    template: "Шаблон",
    status: "Статус",
    provider: "Провайдер",
    cost: "Стоимость",
    attempts: "Попытки",
    failure: "Ошибка",
    watermark: "Водяной знак",
    watermarkApplied: "С водяным знаком",
    watermarkNotRequired: "Не требуется",
    watermarkRemoved: "Снят",
    watermarkPending: "Подготовка",
    watermarkUnlockedBy: "Разблокировал",
    cancelGeneration: "Отменить",
    cancellingGeneration: "Отменяем...",
    cancelGenerationError: "Не удалось отменить генерацию.",
    cancelGenerationConfirmTitle: "Отменить генерацию?",
    cancelGenerationConfirmDescription: (generationId: string) =>
      `Будет отправлен запрос на отмену задания ${generationId}. Для уже запущенного FAL job отмена завершится только после подтверждения провайдера.`,
    cancelGenerationConfirmCancel: "Назад",
    cancelGenerationConfirmSubmit: "Отменить",
    retryGeneration: "Запустить снова",
    retryingGeneration: "Запускаем...",
    retryGenerationError: "Не удалось повторно запустить генерацию.",
    retryGenerationConfirmTitle: "Запустить генерацию снова?",
    retryGenerationConfirmDescription: (generationId: string) =>
      `Задание ${generationId} будет возвращено в очередь с новым бюджетом попыток. Действие доступно только если списание ещё не было возвращено пользователю.`,
    retryGenerationConfirmCancel: "Назад",
    retryGenerationConfirmSubmit: "Запустить снова",
    retryRefund: "Повторить возврат",
    retryingRefund: "Повторяем возврат…",
    retryRefundError: "Не удалось повторно поставить возврат в очередь.",
    retryRefundConflict:
      "Этот ключ операции уже использован с другой причиной. Закройте окно и создайте новый запрос.",
    retryRefundConfirmTitle: "Повторить возврат списания?",
    retryRefundConfirmDescription: (generationId: string) =>
      `Для задания ${generationId} будет восстановлена только очередь возврата. Баланс напрямую не изменяется: фактический возврат выполнит идемпотентный worker.`,
    retryRefundReasonLabel: "Причина восстановления",
    retryRefundReasonPlaceholder:
      "Например: лимит автоматических попыток исчерпан, провайдер снова доступен",
    retryRefundReasonRequired: "Укажите проверенную причину восстановления возврата.",
    retryRefundConfirmCancel: "Назад",
    retryRefundConfirmSubmit: "Поставить возврат в очередь",
    refundState: "Состояние возврата",
    refundAttempts: "Попытки возврата",
    refundLastAttempt: "Последняя попытка возврата",
    refundLastError: "Последняя ошибка возврата",
    grantClean: "Выдать чистый файл",
    grantingClean: "Выдаём...",
    grantCleanError: "Не удалось выдать файл без водяного знака.",
    gamificationLegacyReview: "Проверить Gamification",
    gamificationLegacyReviewDescription: (generationId: string) =>
      `По задаче ${generationId} нет достоверного статуса исторической доставки Gamification. Сверьте журнал событий и выберите действие; автоматический повтор не выполняется.`,
    gamificationLegacyReviewActionLabel: "Подтверждённое действие",
    gamificationLegacyReviewMarkDelivered: "Доставка уже выполнена — не повторять",
    gamificationLegacyReviewReplay:
      "Доставка отсутствует — поставить идемпотентный повтор в очередь",
    gamificationLegacyReviewReasonLabel: "Причина и источник проверки",
    gamificationLegacyReviewReasonPlaceholder:
      "Например: запись подтверждена в audit log / delivery отсутствует в ledger",
    gamificationLegacyReviewReasonRequired: "Укажите причину и источник проверки.",
    gamificationLegacyReviewError: "Не удалось разрешить историческую доставку Gamification.",
    gamificationLegacyReviewCancel: "Назад",
    gamificationLegacyReviewSubmit: "Подтвердить решение",
    created: "Создана",
    completedAt: "Завершена",
    noFailure: "Нет",
    previousPageLabel: "Предыдущая страница генераций",
    nextPageLabel: "Следующая страница генераций",
    page: "Страница",
    of: "из",
    tableTotalLabel: "всего",
    usdLabel: "USD",
    creditsLabel: "кредитов",
    feedbackTab: "Отзывы",
    feedbackEmpty: "Отзывов по генерации пока нет",
    feedbackError: "Не удалось загрузить отзывы по этой генерации",
    lineageSimilarPrefix: "Похожая вариация",
    lineageChildSingular: "дочерняя генерация",
    lineageChildPlural: "дочерних генераций",
    variationLabel: "вариация",
    seedLabel: "Сид",
    generationStatusOptions: {
      All: "Все",
      Pending: "Ожидает",
      Running: "В работе",
      Completed: "Завершена",
      Failed: "Ошибка",
      Cancelled: "Отменена",
      Cancelling: "Отменяется",
      Retrying: "Повторяется",
    },
    refundStateOptions: {
      all: "Все состояния",
      not_applicable: "Возврат не требуется",
      pending: "В очереди",
      exhausted: "Попытки исчерпаны",
      refunded: "Возвращено",
    },
    templateTypeLabels: {
      Image: "Изображение",
      Video: "Видео",
    },
    inputSourceTypeLabels: {
      generation_result: "Результат генерации",
      pet_photo: "Фото питомца",
      user_upload: "Загрузка пользователя",
    },
    feedbackTypeOptions: {
      GenerationResult: "Результат генерации",
      GenerationFailure: "Сбой генерации",
      BugReport: "Ошибка",
      FeatureRequest: "Запрос фичи",
      PaymentIssue: "Проблема с оплатой",
      General: "Общее",
    },
    feedbackStatusOptions: {
      New: "Новый",
      InReview: "На проверке",
      Resolved: "Решён",
      Dismissed: "Отклонён",
    },
    feedbackPriorityOptions: {
      Low: "Низкий",
      Medium: "Средний",
      High: "Высокий",
      Critical: "Критический",
    },
    ratingLabels: {
      positive: "Хорошо",
      neutral: "Нормально",
      negative: "Плохо",
    },
  },
  en: {
    eyebrow: "Operations",
    title: "Generations",
    description:
      "Operational list of generation jobs, statuses, providers, attempts, and failure codes.",
    adminOnly: "Admin only",
    total: "Total jobs",
    pending: "Pending",
    running: "Running",
    completed: "Completed",
    failed: "Failed",
    cancelled: "Cancelled",
    cancelling: "Cancelling",
    retrying: "Retrying",
    pendingRefunds: "Refund pending",
    exhaustedRefunds: "Refund exhausted",
    allJobsScope: "All jobs",
    filtersTitle: "Filters",
    filtersDescription: "Narrow the list by job id, status, provider, or user id.",
    searchLabel: "Job id",
    searchPlaceholder: "Search by generation id",
    statusLabel: "Status",
    refundStateLabel: "Charge refund",
    providerLabel: "Provider",
    providerPlaceholder: "fal, openai...",
    userLabel: "User id",
    userPlaceholder: "Filter by user id",
    tableTitle: "Generation history",
    showDetails: "Show",
    hideDetails: "Hide",
    copyId: "Copy full ID",
    copiedId: "ID copied",
    copyIdFailed: "Failed to copy ID",
    before: "Before",
    after: "After",
    compareReady: "Available",
    compareUnavailable: "Unavailable",
    compareState: "Compare",
    sourceType: "Source type",
    inputAsset: "Input asset",
    resultAsset: "Result asset",
    pet: "Pet",
    petPhoto: "Pet photo",
    diagnosticsTitle: "Diagnostics",
    emptyTitle: "No generations found",
    emptyDescription: "Adjust filters or wait for new generation jobs.",
    loadingTitle: "Loading generations",
    errorTitle: "Failed to load generations",
    metricsErrorTitle: "Generation summary temporarily unavailable",
    metricsErrorDescription:
      "Generation history loads separately; retry to refresh the top counters.",
    retry: "Retry",
    job: "Job",
    user: "User",
    template: "Template",
    status: "Status",
    provider: "Provider",
    cost: "Cost",
    attempts: "Attempts",
    failure: "Failure",
    watermark: "Watermark",
    watermarkApplied: "Watermarked",
    watermarkNotRequired: "Not required",
    watermarkRemoved: "Removed",
    watermarkPending: "Preparing",
    watermarkUnlockedBy: "Unlocked by",
    cancelGeneration: "Cancel",
    cancellingGeneration: "Cancelling...",
    cancelGenerationError: "Failed to cancel generation.",
    cancelGenerationConfirmTitle: "Cancel generation?",
    cancelGenerationConfirmDescription: (generationId: string) =>
      `A cancellation request will be sent for generation ${generationId}. A running FAL job is cancelled only after the provider accepts it.`,
    cancelGenerationConfirmCancel: "Back",
    cancelGenerationConfirmSubmit: "Cancel generation",
    retryGeneration: "Retry job",
    retryingGeneration: "Retrying...",
    retryGenerationError: "Failed to retry generation.",
    retryGenerationConfirmTitle: "Retry generation?",
    retryGenerationConfirmDescription: (generationId: string) =>
      `Generation ${generationId} will be returned to the queue with a fresh attempt budget. This is only available when the original charge has not been refunded.`,
    retryGenerationConfirmCancel: "Back",
    retryGenerationConfirmSubmit: "Retry job",
    retryRefund: "Retry refund",
    retryingRefund: "Retrying refund…",
    retryRefundError: "Failed to queue another refund attempt.",
    retryRefundConflict:
      "This operation key was already used with a different reason. Close the dialog and create a new request.",
    retryRefundConfirmTitle: "Retry the charge refund?",
    retryRefundConfirmDescription: (generationId: string) =>
      `Only the refund queue for generation ${generationId} will be restored. The balance is not changed directly; the idempotent worker performs the actual refund.`,
    retryRefundReasonLabel: "Recovery reason",
    retryRefundReasonPlaceholder:
      "For example: automatic attempts exhausted and the provider is available again",
    retryRefundReasonRequired: "Provide a verified reason for restoring the refund.",
    retryRefundConfirmCancel: "Back",
    retryRefundConfirmSubmit: "Queue refund",
    refundState: "Refund state",
    refundAttempts: "Refund attempts",
    refundLastAttempt: "Last refund attempt",
    refundLastError: "Last refund error",
    grantClean: "Grant clean",
    grantingClean: "Granting...",
    grantCleanError: "Failed to grant clean download.",
    gamificationLegacyReview: "Review Gamification",
    gamificationLegacyReviewDescription: (generationId: string) =>
      `Generation ${generationId} has no reliable historical Gamification delivery status. Check the event ledger and choose an action; no automatic replay is performed.`,
    gamificationLegacyReviewActionLabel: "Verified action",
    gamificationLegacyReviewMarkDelivered: "Delivery already completed — do not replay",
    gamificationLegacyReviewReplay: "Delivery missing — queue idempotent replay",
    gamificationLegacyReviewReasonLabel: "Review reason and evidence source",
    gamificationLegacyReviewReasonPlaceholder:
      "For example: audit log confirms delivery / ledger contains no delivery",
    gamificationLegacyReviewReasonRequired: "Provide the review reason and evidence source.",
    gamificationLegacyReviewError: "Failed to resolve historical Gamification delivery.",
    gamificationLegacyReviewCancel: "Back",
    gamificationLegacyReviewSubmit: "Confirm decision",
    created: "Created",
    completedAt: "Completed",
    noFailure: "None",
    previousPageLabel: "Previous generations page",
    nextPageLabel: "Next generations page",
    page: "Page",
    of: "of",
    tableTotalLabel: "total",
    usdLabel: "USD",
    creditsLabel: "credits",
    feedbackTab: "Feedback",
    feedbackEmpty: "No feedback for this generation yet",
    feedbackError: "Failed to load feedback for this generation",
    lineageSimilarPrefix: "Similar variation",
    lineageChildSingular: "child generation",
    lineageChildPlural: "child generations",
    variationLabel: "variation",
    seedLabel: "seed",
    generationStatusOptions: {
      All: "All",
      Pending: "Pending",
      Running: "Running",
      Completed: "Completed",
      Failed: "Failed",
      Cancelled: "Cancelled",
      Cancelling: "Cancelling",
      Retrying: "Retrying",
    },
    refundStateOptions: {
      all: "All states",
      not_applicable: "Not required",
      pending: "Pending",
      exhausted: "Attempts exhausted",
      refunded: "Refunded",
    },
    templateTypeLabels: {
      Image: "Image",
      Video: "Video",
    },
    inputSourceTypeLabels: {
      generation_result: "Generation result",
      pet_photo: "Pet photo",
      user_upload: "User upload",
    },
    feedbackTypeOptions: {
      GenerationResult: "Generation result",
      GenerationFailure: "Generation failure",
      BugReport: "Bug report",
      FeatureRequest: "Feature request",
      PaymentIssue: "Payment issue",
      General: "General",
    },
    feedbackStatusOptions: {
      New: "New",
      InReview: "In review",
      Resolved: "Resolved",
      Dismissed: "Dismissed",
    },
    feedbackPriorityOptions: {
      Low: "Low",
      Medium: "Medium",
      High: "High",
      Critical: "Critical",
    },
    ratingLabels: {
      positive: "Good",
      neutral: "Okay",
      negative: "Bad",
    },
  },
};

const generationsPageIntlLocales: Record<Locale, string> = {
  ru: "ru-RU",
  en: "en-US",
};

export function getGenerationsPageText(locale: Locale): GenerationsPageText {
  return generationsPageText[locale];
}

export function getGenerationsPageIntlLocale(locale: Locale): string {
  return generationsPageIntlLocales[locale];
}
