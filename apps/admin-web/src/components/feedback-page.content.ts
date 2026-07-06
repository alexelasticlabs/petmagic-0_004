import type { FeedbackPriority, FeedbackStatus, FeedbackType } from "@/lib/api-client";
import { type Locale } from "@/lib/i18n";

type FeedbackOption<T extends string> = Record<T | "All", string>;

export type FeedbackPageText = {
  eyebrow: string;
  title: string;
  description: string;
  filters: string;
  table: string;
  details: string;
  status: string;
  priority: string;
  type: string;
  category: string;
  platform: string;
  templateId: string;
  userId: string;
  from: string;
  to: string;
  user: string;
  date: string;
  rating: string;
  template: string;
  message: string;
  preview: string;
  show: string;
  empty: string;
  loading: string;
  error: string;
  detailsLoading: string;
  detailsError: string;
  userContextErrorTitle: string;
  userContextErrorDescription: string;
  retry: string;
  save: string;
  saveError: string;
  refund: string;
  refunded: string;
  refundError: string;
  note: string;
  generation: string;
  input: string;
  result: string;
  technical: string;
  planCredits: string;
  source: string;
  app: string;
  device: string;
  provider: string;
  errorCode: string;
  credits: string;
  previous: string;
  next: string;
  previousPageLabel: string;
  nextPageLabel: string;
  userContextLoading: string;
  userPlanPremium: string;
  userPlanFree: string;
  statusOptions: FeedbackOption<FeedbackStatus>;
  priorityOptions: FeedbackOption<FeedbackPriority>;
  typeOptions: FeedbackOption<FeedbackType>;
  ratingLabels: {
    positive: string;
    neutral: string;
    negative: string;
  };
};

const feedbackPageText: Record<Locale, FeedbackPageText> = {
  ru: {
    eyebrow: "Качество",
    title: "Отзывы",
    description: "Отзывы по генерациям, ошибкам, оплате и предложениям с управлением статусами.",
    filters: "Фильтры",
    table: "Заявки",
    details: "Детали",
    status: "Статус",
    priority: "Приоритет",
    type: "Тип",
    category: "Категория",
    platform: "Платформа",
    templateId: "ID шаблона",
    userId: "ID пользователя",
    from: "С даты",
    to: "По дату",
    user: "Пользователь",
    date: "Дата",
    rating: "Рейтинг",
    template: "Шаблон",
    message: "Сообщение",
    preview: "Превью",
    show: "Открыть",
    empty: "Отзывы не найдены",
    loading: "Загрузка отзывов",
    error: "Не удалось загрузить отзывы",
    detailsLoading: "Загрузка деталей отзыва",
    detailsError: "Не удалось загрузить детали отзыва",
    userContextErrorTitle: "Контекст пользователя временно недоступен",
    userContextErrorDescription:
      "Детали отзыва загружены, но профиль или аналитика пользователя не ответили.",
    retry: "Повторить",
    save: "Сохранить",
    saveError: "Не удалось сохранить изменения отзыва.",
    refund: "Вернуть кредиты",
    refunded: "Кредиты возвращены",
    refundError: "Не удалось вернуть кредиты.",
    note: "Заметка администратора",
    generation: "Генерация",
    input: "Входные данные",
    result: "Результат",
    technical: "Технический контекст",
    planCredits: "План / кредиты",
    source: "Источник",
    app: "Версия приложения",
    device: "Устройство",
    provider: "Провайдер",
    errorCode: "Код ошибки",
    credits: "кредитов",
    previous: "Назад",
    next: "Вперёд",
    previousPageLabel: "Предыдущая страница отзывов",
    nextPageLabel: "Следующая страница отзывов",
    userContextLoading: "Загрузка...",
    userPlanPremium: "Премиум",
    userPlanFree: "Бесплатный",
    statusOptions: {
      All: "Все",
      New: "Новый",
      InReview: "На проверке",
      Resolved: "Решён",
      Dismissed: "Отклонён",
    },
    priorityOptions: {
      All: "Все",
      Low: "Низкий",
      Medium: "Средний",
      High: "Высокий",
      Critical: "Критический",
    },
    typeOptions: {
      All: "Все",
      GenerationResult: "Результат генерации",
      GenerationFailure: "Сбой генерации",
      BugReport: "Ошибка",
      FeatureRequest: "Запрос фичи",
      PaymentIssue: "Проблема с оплатой",
      General: "Общее",
    },
    ratingLabels: {
      positive: "Хорошо",
      neutral: "Нормально",
      negative: "Плохо",
    },
  },
  en: {
    eyebrow: "Quality",
    title: "Feedback",
    description: "Generation, failure, payment, and general feedback with status management.",
    filters: "Filters",
    table: "Feedback items",
    details: "Details",
    status: "Status",
    priority: "Priority",
    type: "Type",
    category: "Category",
    platform: "Platform",
    templateId: "Template id",
    userId: "User id",
    from: "From",
    to: "To",
    user: "User",
    date: "Date",
    rating: "Rating",
    template: "Template",
    message: "Message",
    preview: "Preview",
    show: "Open",
    empty: "No feedback found",
    loading: "Loading feedback",
    error: "Failed to load feedback",
    detailsLoading: "Loading feedback details",
    detailsError: "Failed to load feedback details",
    userContextErrorTitle: "User context temporarily unavailable",
    userContextErrorDescription:
      "Feedback details loaded, but the user profile or analytics did not respond.",
    retry: "Retry",
    save: "Save",
    saveError: "Failed to save feedback changes.",
    refund: "Refund credits",
    refunded: "Refund issued",
    refundError: "Failed to refund credits.",
    note: "Admin note",
    generation: "Generation",
    input: "Input",
    result: "Result",
    technical: "Technical context",
    planCredits: "Plan / credits",
    source: "Source",
    app: "App",
    device: "Device",
    provider: "Provider",
    errorCode: "Error",
    credits: "credits",
    previous: "Previous",
    next: "Next",
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
      All: "All",
      Low: "Low",
      Medium: "Medium",
      High: "High",
      Critical: "Critical",
    },
    typeOptions: {
      All: "All",
      GenerationResult: "Generation result",
      GenerationFailure: "Generation failure",
      BugReport: "Bug report",
      FeatureRequest: "Feature request",
      PaymentIssue: "Payment issue",
      General: "General",
    },
    ratingLabels: {
      positive: "Good",
      neutral: "Okay",
      negative: "Bad",
    },
  },
};

export function getFeedbackPageText(locale: Locale): FeedbackPageText {
  return feedbackPageText[locale];
}
