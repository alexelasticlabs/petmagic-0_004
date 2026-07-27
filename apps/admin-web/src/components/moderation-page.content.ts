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
  summaryPending: string;
  summaryApproved: string;
  summaryRejected: string;
  summaryOldest: string;
  summaryScope: string;
  pendingComposition: string;
  updatedAt: string;
  noPending: string;
  queueRegionLabel: string;
  mobileQueueLabel: string;
  review: string;
  reviewItemLabel: string;
  reviewTitle: string;
  reviewDescription: string;
  saveDecision: string;
  contextTitle: string;
  templateId: string;
  device: string;
  country: string;
  userId: string;
  generationId: string;
  noMessage: string;
  decisionTitle: string;
  decisionHelp: string;
  approveHelp: string;
  rejectHelp: string;
  reasonHint: string;
  characterCountLabel: string;
  previousDecision: string;
  decisionConflict: string;
  queueShowing: string;
  complaintsShort: string;
  feedbackShort: string;
  workspaceTitle: string;
  workspaceDescription: string;
  closeInspector: string;
  claimBeforeDecision: string;
  leaseConflict: string;
};

const moderationPageText: Record<Locale, ModerationPageText> = {
  ru: {
    eyebrow: "Безопасность контента",
    title: "Модерация",
    description:
      "Очередь жалоб и обратной связи по шаблонам. Решения записываются в журнал аудита.",
    filtersTitle: "Фильтры",
    status: "Статус",
    search: "Поиск",
    searchPlaceholder: "шаблон, сообщение, ID пользователя или генерации",
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
    approve: "Оставить без изменений",
    reject: "Подтвердить нарушение",
    reason: "Причина/комментарий",
    reasonPlaceholder: "Коротко укажите причину решения",
    cancel: "Отмена",
    confirmApprove: "Оставить без изменений?",
    confirmReject: "Подтвердить нарушение?",
    saved: "Решение сохранено",
    failed: "Не удалось сохранить решение",
    moderationActionsForbidden:
      "Действия модерации доступны только администраторам или модераторам.",
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
    approveItemLabel: "Оставить элемент без изменений",
    rejectItemLabel: "Подтвердить нарушение",
    summaryPending: "Ожидают решения",
    summaryApproved: "Одобрено",
    summaryRejected: "Отклонено",
    summaryOldest: "Самая старая",
    summaryScope: "По всей очереди, без учёта фильтров",
    pendingComposition: "Состав ожидающей очереди",
    updatedAt: "Обновлено",
    noPending: "Ожидающих решений нет",
    queueRegionLabel: "Таблица очереди модерации. Для прокрутки используйте стрелки.",
    mobileQueueLabel: "Очередь модерации",
    review: "Рассмотреть",
    reviewItemLabel: "Рассмотреть элемент",
    reviewTitle: "Проверка обращения",
    reviewDescription:
      "Сначала изучите контекст обращения, затем выберите решение и оставьте причину для журнала аудита.",
    saveDecision: "Выберите решение",
    contextTitle: "Контекст",
    templateId: "ID шаблона",
    device: "Устройство",
    country: "Страна",
    userId: "ID пользователя",
    generationId: "ID генерации",
    noMessage: "Текст обращения не указан",
    decisionTitle: "Решение",
    decisionHelp: "Действие применится только к элементу, который всё ещё ожидает модерации.",
    approveHelp: "Сигнал проверен: нарушение не подтверждено, контент остаётся без изменений.",
    rejectHelp: "Нарушение подтверждено: контент получит статус rejected.",
    reasonHint: "От 3 до 500 символов. Причина попадёт в журнал аудита.",
    characterCountLabel: "Количество символов",
    previousDecision: "Предыдущее решение",
    decisionConflict:
      "Элемент уже обработан другим модератором. Очередь обновлена — проверьте актуальный статус.",
    queueShowing: "Показано",
    complaintsShort: "жалоб",
    feedbackShort: "отзывов",
    workspaceTitle: "Контекст обращения",
    workspaceDescription:
      "Выберите элемент очереди, возьмите его в работу и только затем зафиксируйте решение.",
    closeInspector: "Закрыть инспектор модерации",
    claimBeforeDecision:
      "Сначала возьмите элемент в работу. Решение доступно только владельцу активной блокировки.",
    leaseConflict:
      "Элемент уже изменён или занят другим модератором. Очередь обновлена — проверьте актуальное состояние.",
  },
  en: {
    eyebrow: "Content safety",
    title: "Moderation",
    description:
      "Complaint and feedback queue for templates. Decisions are written to the audit log.",
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
    approve: "Leave unchanged",
    reject: "Confirm violation",
    reason: "Reason/comment",
    reasonPlaceholder: "Briefly explain the decision",
    cancel: "Cancel",
    confirmApprove: "Leave this item unchanged?",
    confirmReject: "Confirm this violation?",
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
    approveItemLabel: "Leave item unchanged",
    rejectItemLabel: "Confirm violation",
    summaryPending: "Awaiting decision",
    summaryApproved: "Approved",
    summaryRejected: "Rejected",
    summaryOldest: "Oldest pending",
    summaryScope: "Across the full queue, regardless of active filters",
    pendingComposition: "Pending queue composition",
    updatedAt: "Updated",
    noPending: "No pending decisions",
    queueRegionLabel: "Moderation queue table. Use arrow keys to scroll.",
    mobileQueueLabel: "Moderation queue",
    review: "Review",
    reviewItemLabel: "Review item",
    reviewTitle: "Review report",
    reviewDescription:
      "Review the report context first, then select a decision and record an audit reason.",
    saveDecision: "Select a decision",
    contextTitle: "Context",
    templateId: "Template ID",
    device: "Device",
    country: "Country",
    userId: "User ID",
    generationId: "Generation ID",
    noMessage: "No report message was provided",
    decisionTitle: "Decision",
    decisionHelp: "The action is applied only while this item is still pending moderation.",
    approveHelp: "The report was reviewed; no violation was confirmed and content stays unchanged.",
    rejectHelp: "A violation was confirmed and the content will receive the rejected status.",
    reasonHint: "3 to 500 characters. The reason is written to the audit log.",
    characterCountLabel: "Character count",
    previousDecision: "Previous decision",
    decisionConflict:
      "Another moderator already processed this item. The queue was refreshed; review its current status.",
    queueShowing: "Showing",
    complaintsShort: "complaints",
    feedbackShort: "feedback",
    workspaceTitle: "Report context",
    workspaceDescription:
      "Select a queue item, claim it, and only then record the moderation decision.",
    closeInspector: "Close moderation inspector",
    claimBeforeDecision:
      "Claim the item first. Decisions are available only to the owner of an active processing lease.",
    leaseConflict:
      "The item changed or another moderator owns it. The queue was refreshed; review the current state.",
  },
};

export function getModerationPageText(locale: Locale): ModerationPageText {
  return moderationPageText[locale];
}
