import { type Locale } from "@/lib/i18n";

export type ModerationPageText = {
  eyebrow: string;
  title: string;
  description: string;
  filtersTitle: string;
  status: string;
  search: string;
  searchPlaceholder: string;
  queueTitle: string;
  loading: string;
  error: string;
  empty: string;
  template: string;
  event: string;
  message: string;
  source: string;
  created: string;
  actions: string;
  approve: string;
  reject: string;
  reason: string;
  reasonPlaceholder: string;
  cancel: string;
  confirmApprove: string;
  confirmReject: string;
  saved: string;
  failed: string;
  moderationActionsForbidden: string;
  decisionMissing: string;
  reasonRequired: string;
  previous: string;
  next: string;
  pageLabel: string;
  previousPageLabel: string;
  nextPageLabel: string;
  retry: string;
  statusPending: string;
  statusApproved: string;
  statusRejected: string;
  statusAll: string;
  eventComplaint: string;
  eventFeedback: string;
  templateImage: string;
  templateVideo: string;
  userPrefix: string;
  workspaceBadge: string;
  approveItemLabel: string;
  rejectItemLabel: string;
};

const moderationPageText: Record<Locale, ModerationPageText> = {
  ru: {
    eyebrow: "Безопасность контента",
    title: "Модерация",
    description: "Очередь жалоб и обратной связи по шаблонам. Решения пишутся в audit log.",
    filtersTitle: "Фильтры",
    status: "Статус",
    search: "Поиск",
    searchPlaceholder: "шаблон, сообщение, user/generation id",
    queueTitle: "Очередь",
    loading: "Загрузка очереди",
    error: "Не удалось загрузить очередь",
    empty: "В очереди ничего нет",
    template: "Шаблон",
    event: "Событие",
    message: "Сообщение",
    source: "Источник",
    created: "Создано",
    actions: "Действия",
    approve: "Одобрить",
    reject: "Отклонить",
    reason: "Причина/комментарий",
    reasonPlaceholder: "Коротко укажите причину решения",
    cancel: "Отмена",
    confirmApprove: "Одобрить элемент?",
    confirmReject: "Отклонить элемент?",
    saved: "Решение сохранено",
    failed: "Не удалось сохранить решение",
    moderationActionsForbidden: "Действия модерации доступны только Admin или Moderator.",
    decisionMissing: "Выберите элемент модерации.",
    reasonRequired: "Укажите причину решения: минимум 3 символа.",
    previous: "Назад",
    next: "Вперёд",
    pageLabel: "Страница",
    previousPageLabel: "Предыдущая страница очереди",
    nextPageLabel: "Следующая страница очереди",
    retry: "Повторить",
    statusPending: "Ожидает",
    statusApproved: "Одобрено",
    statusRejected: "Отклонено",
    statusAll: "Все",
    eventComplaint: "Жалоба",
    eventFeedback: "Отзыв",
    templateImage: "Изображение",
    templateVideo: "Видео",
    userPrefix: "пользователь",
    workspaceBadge: "Модератор",
    approveItemLabel: "Одобрить элемент",
    rejectItemLabel: "Отклонить элемент",
  },
  en: {
    eyebrow: "Content safety",
    title: "Moderation",
    description: "Complaint and feedback queue for templates. Decisions are written to the audit log.",
    filtersTitle: "Filters",
    status: "Status",
    search: "Search",
    searchPlaceholder: "template, message, user/generation id",
    queueTitle: "Queue",
    loading: "Loading queue",
    error: "Failed to load queue",
    empty: "No moderation items",
    template: "Template",
    event: "Event",
    message: "Message",
    source: "Source",
    created: "Created",
    actions: "Actions",
    approve: "Approve",
    reject: "Reject",
    reason: "Reason/comment",
    reasonPlaceholder: "Briefly explain the decision",
    cancel: "Cancel",
    confirmApprove: "Approve item?",
    confirmReject: "Reject item?",
    saved: "Decision saved",
    failed: "Failed to save decision",
    moderationActionsForbidden: "Moderation actions are available only to Admin or Moderator.",
    decisionMissing: "Select a moderation item.",
    reasonRequired: "Enter a decision reason: at least 3 characters.",
    previous: "Previous",
    next: "Next",
    pageLabel: "Page",
    previousPageLabel: "Previous queue page",
    nextPageLabel: "Next queue page",
    retry: "Retry",
    statusPending: "Pending",
    statusApproved: "Approved",
    statusRejected: "Rejected",
    statusAll: "All",
    eventComplaint: "Complaint",
    eventFeedback: "Feedback",
    templateImage: "Image",
    templateVideo: "Video",
    userPrefix: "user",
    workspaceBadge: "Moderator",
    approveItemLabel: "Approve item",
    rejectItemLabel: "Reject item",
  },
};

export function getModerationPageText(locale: Locale): ModerationPageText {
  return moderationPageText[locale];
}

