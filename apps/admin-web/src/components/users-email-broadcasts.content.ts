import type { Locale } from "@/lib/i18n";

export type UsersEmailBroadcastsText = {
  title: string;
  description: string;
  queueLabel: string;
  workspaceLabel: string;
  inspectorLabel: string;
  statusFilter: string;
  statusAll: string;
  statusQueued: string;
  statusProcessing: string;
  statusCompleted: string;
  statusPartiallyFailed: string;
  statusFailed: string;
  statusLegacy: string;
  loading: string;
  loadFailed: string;
  empty: string;
  retryLoad: string;
  openBroadcast: string;
  closeInspector: string;
  audience: string;
  audienceAllActive: string;
  audiencePremium: string;
  audienceSelected: string;
  recipients: string;
  sent: string;
  pending: string;
  failed: string;
  retryable: string;
  created: string;
  updated: string;
  completed: string;
  progress: string;
  safeDataTitle: string;
  safeDataDescription: string;
  selectionHint: string;
  retryFailed: string;
  retryTitle: string;
  retryDescription: (count: number) => string;
  retryConfirm: string;
  retryCancel: string;
  retrySucceeded: (count: number) => string;
  retryError: string;
  noRetryable: string;
  previous: string;
  next: string;
  page: (page: number) => string;
  pagination: string;
  subjectUnavailable: string;
};

const content: Record<Locale, UsersEmailBroadcastsText> = {
  ru: {
    title: "История email-рассылок",
    description:
      "Статус доставки и безопасный повтор только неуспешных отправок. Адреса, текст письма и данные провайдера здесь не отображаются.",
    queueLabel: "Очередь email-рассылок",
    workspaceLabel: "Сводка email-рассылок",
    inspectorLabel: "Инспектор email-рассылки",
    statusFilter: "Статус рассылки",
    statusAll: "Все статусы",
    statusQueued: "В очереди",
    statusProcessing: "Выполняется",
    statusCompleted: "Завершена",
    statusPartiallyFailed: "Завершена с ошибками",
    statusFailed: "Не выполнена",
    statusLegacy: "Ранее созданная",
    loading: "Загрузка истории рассылок…",
    loadFailed: "Не удалось загрузить историю рассылок.",
    empty: "Рассылок с выбранным статусом нет.",
    retryLoad: "Повторить загрузку",
    openBroadcast: "Открыть рассылку",
    closeInspector: "Закрыть инспектор рассылки",
    audience: "Аудитория",
    audienceAllActive: "Все активные пользователи",
    audiencePremium: "Premium-пользователи",
    audienceSelected: "Выбранные пользователи",
    recipients: "Получателей",
    sent: "Доставлено",
    pending: "Ожидает",
    failed: "Ошибок",
    retryable: "Можно повторить",
    created: "Создана",
    updated: "Обновлена",
    completed: "Завершена",
    progress: "Прогресс доставки",
    safeDataTitle: "Безопасная операционная сводка",
    safeDataDescription:
      "Выберите рассылку в очереди. Инспектор показывает только агрегаты и не раскрывает адреса получателей, тело письма или provider payload.",
    selectionHint:
      "Выбранная рассылка сохраняется в URL — ссылку можно безопасно открыть повторно.",
    retryFailed: "Повторить ошибки",
    retryTitle: "Повторить неуспешные отправки?",
    retryDescription: (count) =>
      `Backend повторно поставит в очередь только ${count} неуспешных отправок. Успешные доставки не будут затронуты.`,
    retryConfirm: "Повторить неуспешные",
    retryCancel: "Отмена",
    retrySucceeded: (count) => `Повторно поставлено в очередь: ${count}.`,
    retryError: "Не удалось повторить неуспешные отправки. Обновите рассылку и попробуйте снова.",
    noRetryable: "Неуспешных отправок, доступных для повтора, нет.",
    previous: "Назад",
    next: "Вперёд",
    page: (page) => `Страница ${page}`,
    pagination: "Страницы истории email-рассылок",
    subjectUnavailable: "Без темы",
  },
  en: {
    title: "Email broadcast history",
    description:
      "Delivery progress and a safe retry for failed dispatches only. Recipient addresses, email body, and provider data are never shown here.",
    queueLabel: "Email broadcast queue",
    workspaceLabel: "Email broadcast overview",
    inspectorLabel: "Email broadcast inspector",
    statusFilter: "Broadcast status",
    statusAll: "All statuses",
    statusQueued: "Queued",
    statusProcessing: "Processing",
    statusCompleted: "Completed",
    statusPartiallyFailed: "Completed with errors",
    statusFailed: "Failed",
    statusLegacy: "Legacy",
    loading: "Loading broadcast history…",
    loadFailed: "Could not load broadcast history.",
    empty: "No broadcasts match this status.",
    retryLoad: "Retry loading",
    openBroadcast: "Open broadcast",
    closeInspector: "Close broadcast inspector",
    audience: "Audience",
    audienceAllActive: "All active users",
    audiencePremium: "Premium users",
    audienceSelected: "Selected users",
    recipients: "Recipients",
    sent: "Delivered",
    pending: "Pending",
    failed: "Failed",
    retryable: "Retryable",
    created: "Created",
    updated: "Updated",
    completed: "Completed",
    progress: "Delivery progress",
    safeDataTitle: "Safe operational summary",
    safeDataDescription:
      "Select a broadcast from the queue. The inspector exposes aggregates only—never recipient addresses, email body, or provider payload.",
    selectionHint: "The selected broadcast is stored in the URL so the safe view can be reopened.",
    retryFailed: "Retry failures",
    retryTitle: "Retry failed dispatches?",
    retryDescription: (count) =>
      `The backend will requeue only ${count} failed dispatches. Successful deliveries are not affected.`,
    retryConfirm: "Retry failed dispatches",
    retryCancel: "Cancel",
    retrySucceeded: (count) => `${count} dispatches were requeued.`,
    retryError: "Could not retry failed dispatches. Refresh the broadcast and try again.",
    noRetryable: "There are no failed dispatches eligible for retry.",
    previous: "Previous",
    next: "Next",
    page: (page) => `Page ${page}`,
    pagination: "Email broadcast history pages",
    subjectUnavailable: "No subject",
  },
};

export function getUsersEmailBroadcastsText(locale: Locale) {
  return content[locale];
}
