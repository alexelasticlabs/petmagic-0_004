import type {
  AdminGenerationStatus,
  FeedbackPriority,
  FeedbackStatus,
  FeedbackType,
} from "@/lib/api-client";
import { type Locale } from "@/lib/i18n";

type GenerationStatusOption = AdminGenerationStatus | "All";

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
  retrying: string;
  allJobsScope: string;
  filtersTitle: string;
  filtersDescription: string;
  searchLabel: string;
  searchPlaceholder: string;
  statusLabel: string;
  providerLabel: string;
  providerPlaceholder: string;
  userLabel: string;
  userPlaceholder: string;
  tableTitle: string;
  showDetails: string;
  hideDetails: string;
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
  previewMissing: string;
  debugTitle: string;
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
  grantClean: string;
  grantingClean: string;
  grantCleanError: string;
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
    adminOnly: "Только Admin",
    total: "Всего заданий",
    pending: "Ожидает",
    running: "В работе",
    completed: "Завершена",
    failed: "Ошибка",
    cancelled: "Отменена",
    retrying: "Повторяется",
    allJobsScope: "Все задания",
    filtersTitle: "Фильтры",
    filtersDescription: "Сузьте список по job id, статусу, провайдеру или user id.",
    searchLabel: "Job id",
    searchPlaceholder: "Поиск по generation id",
    statusLabel: "Статус",
    providerLabel: "Провайдер",
    providerPlaceholder: "fal, openai...",
    userLabel: "User id",
    userPlaceholder: "Фильтр по user id",
    tableTitle: "История генераций",
    showDetails: "Показать",
    hideDetails: "Скрыть",
    before: "До",
    after: "После",
    compareReady: "Доступно",
    compareUnavailable: "Недоступно",
    compareState: "Сравнение",
    sourceType: "Источник",
    inputAsset: "Входной asset",
    resultAsset: "Результат asset",
    pet: "Питомец",
    petPhoto: "Фото питомца",
    previewMissing: "Превью недоступно",
    debugTitle: "Отладка",
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
    watermark: "Watermark",
    watermarkApplied: "С watermark",
    watermarkNotRequired: "Не требуется",
    watermarkRemoved: "Снят",
    watermarkPending: "Подготовка",
    watermarkUnlockedBy: "Разблокировал",
    grantClean: "Выдать clean",
    grantingClean: "Выдаём...",
    grantCleanError: "Не удалось выдать clean download.",
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
    seedLabel: "seed",
    generationStatusOptions: {
      All: "Все",
      Pending: "Ожидает",
      Running: "В работе",
      Completed: "Завершена",
      Failed: "Ошибка",
      Cancelled: "Отменена",
      Retrying: "Повторяется",
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
    retrying: "Retrying",
    allJobsScope: "All jobs",
    filtersTitle: "Filters",
    filtersDescription: "Narrow the list by job id, status, provider, or user id.",
    searchLabel: "Job id",
    searchPlaceholder: "Search by generation id",
    statusLabel: "Status",
    providerLabel: "Provider",
    providerPlaceholder: "fal, openai...",
    userLabel: "User id",
    userPlaceholder: "Filter by user id",
    tableTitle: "Generation history",
    showDetails: "Show",
    hideDetails: "Hide",
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
    previewMissing: "Preview unavailable",
    debugTitle: "Debug",
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
    grantClean: "Grant clean",
    grantingClean: "Granting...",
    grantCleanError: "Failed to grant clean download.",
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
      Retrying: "Retrying",
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
