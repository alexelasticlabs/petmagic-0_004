import type { Locale } from "@/lib/i18n";

export type UsersEmailBroadcastsText = {
  history: string;
  newCampaign: string;
  campaigns: string;
  campaign: string;
  sending: string;
  filteredEmptyDescription: string;
  create: string;
  refresh: string;
  emptyTitle: string;
  emptyDescription: string;
  resetFilter: string;
  pageTotals: string;
  queued: (count: number) => string;
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
    history: "История",
    newCampaign: "Новая рассылка",
    campaigns: "Рассылок",
    campaign: "Рассылка",
    sending: "Отправка",
    filteredEmptyDescription: "Попробуйте выбрать другой статус или сбросить фильтр.",
    create: "Создать рассылку",
    refresh: "Обновить",
    emptyTitle: "Первое письмо начинается здесь",
    emptyDescription:
      "Подготовьте сообщение и выберите получателей. После отправки здесь появятся результаты.",
    resetFilter: "Сбросить фильтр",
    pageTotals: "Показатели на текущей странице",
    queued: (count) =>
      count > 0
        ? `Рассылка создана. Получателей: ${count}. Статус отправки обновляется автоматически.`
        : "Рассылка создана без отправок: в выбранной аудитории нет подходящих получателей.",
    title: "История отправок",
    description: "Результаты отправки и повтор неуспешных писем.",
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
    sent: "Отправлено",
    pending: "Ожидает",
    failed: "Ошибок",
    retryable: "Можно повторить",
    created: "Создана",
    updated: "Обновлена",
    completed: "Завершена",
    progress: "Прогресс отправки",
    safeDataTitle: "Выберите рассылку",
    safeDataDescription:
      "В деталях доступны аудитория, прогресс, время отправки и повтор неуспешных писем.",
    selectionHint: "Отправка выполняется только активным пользователям с подтверждённым email.",
    retryFailed: "Повторить ошибки",
    retryTitle: "Повторить неуспешные отправки?",
    retryDescription: (count) =>
      `Повторно будет поставлено в очередь только ${count} неуспешных отправок. Успешные доставки не будут затронуты.`,
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
    history: "History",
    newCampaign: "New campaign",
    campaigns: "Campaigns",
    campaign: "Campaign",
    sending: "Sending",
    filteredEmptyDescription: "Choose another status or clear the filter.",
    create: "Create campaign",
    refresh: "Refresh",
    emptyTitle: "Your first message starts here",
    emptyDescription:
      "Compose a message, choose an audience, and review it before sending. History and results will appear here.",
    resetFilter: "Clear filter",
    pageTotals: "On this page",
    queued: (count) =>
      count > 0
        ? `Campaign created for ${count} recipients. Sending progress refreshes automatically.`
        : "No messages queued: no eligible recipients were found in this audience.",
    title: "Sending history",
    description: "Sending results and retries for failed messages.",
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
    sent: "Sent",
    pending: "Pending",
    failed: "Failed",
    retryable: "Retryable",
    created: "Created",
    updated: "Updated",
    completed: "Completed",
    progress: "Sending progress",
    safeDataTitle: "Select a campaign",
    safeDataDescription:
      "View the audience, progress, timestamps, and retry options for failed messages.",
    selectionHint: "Messages are sent only to active users with confirmed email.",
    retryFailed: "Retry failures",
    retryTitle: "Retry failed dispatches?",
    retryDescription: (count) =>
      `Only ${count} failed dispatches will be requeued. Successful deliveries are not affected.`,
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
