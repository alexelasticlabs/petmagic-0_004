import type { AdminAuditCategory } from "@/lib/api-client";
import type { Locale } from "@/lib/i18n";

export type AuditPeriod = "24h" | "7d" | "30d";
export type AuditCategoryFilter = "all" | AdminAuditCategory;

type AuditEventsPageText = {
  title: string;
  description: string;
  refresh: string;
  refreshing: string;
  accessBadge: string;
  lastUpdated: (value: string) => string;
  metrics: {
    total: string;
    operators: string;
    access: string;
    system: string;
  };
  filtersTitle: string;
  filtersDescription: string;
  searchLabel: string;
  searchPlaceholder: string;
  actorLabel: string;
  actorPlaceholder: string;
  actorInvalid: string;
  periodLabel: string;
  categoryLabel: string;
  applySearch: string;
  resetFilters: string;
  periods: Record<AuditPeriod, string>;
  categories: Record<AuditCategoryFilter, string>;
  loadingTitle: string;
  loadingDescription: string;
  errorTitle: string;
  errorDescription: string;
  staleTitle: string;
  staleDescription: string;
  retry: string;
  emptyTitle: string;
  emptyDescription: string;
  eventsTitle: string;
  eventsDescription: string;
  resultCount: (count: number) => string;
  eventColumns: {
    time: string;
    event: string;
    actor: string;
    target: string;
    category: string;
  };
  page: (current: number, total: number) => string;
  previousPage: string;
  nextPage: string;
  detailsTitle: string;
  detailsDescription: string;
  detailsLoading: string;
  detailsError: string;
  detailsEmptyTitle: string;
  detailsEmptyDescription: string;
  closeDetails: string;
  whoAndWhen: string;
  object: string;
  subjectUser: string;
  change: string;
  reason: string;
  correlationId: string;
  technicalContext: string;
  ipAddress: string;
  userAgent: string;
  createdAt: string;
  occurredAt: string;
  actorRole: string;
  before: string;
  after: string;
  systemActor: string;
  unknownActor: string;
  noTarget: string;
  noValue: string;
  openUser: string;
  openSupport: string;
  openEconomy: string;
  openPromoCodes: string;
  copyCorrelationId: string;
  copied: string;
  copyFailed: string;
  actionCode: string;
  actions: Record<string, string>;
  fallbackAction: string;
};

const sharedActionKeys = {
  "user.role.assigned": ["Роль пользователя назначена", "User role assigned"],
  "user.role.revoked": ["Роль пользователя снята", "User role revoked"],
  "user.blocked": ["Доступ пользователя заблокирован", "User access blocked"],
  "user.unblocked": ["Доступ пользователя восстановлен", "User access restored"],
  "user.premium.updated": ["Premium-статус изменён", "Premium status changed"],
  "admin.user.wallet.credited": ["PawSpark начислены вручную", "PawSpark granted manually"],
  "admin.user.wallet.debited": ["PawSpark списаны вручную", "PawSpark debited manually"],
  "admin.user.deleted": ["Пользователь удалён", "User deleted"],
  "admin.bulk_email.queued": ["Рассылка поставлена в очередь", "Bulk email queued"],
  "admin.payment.refunded": ["Возврат платежа выполнен", "Payment refunded"],
  "admin.payment.refund_provider_failed": [
    "Возврат у провайдера завершился ошибкой",
    "Provider refund failed",
  ],
  "admin.payment.refund_manual_review_required": [
    "Возврат требует ручной проверки",
    "Refund requires manual review",
  ],
  "admin.subscription.revoke_requested": ["Отзыв Premium запрошен", "Premium revocation requested"],
  "admin.subscription.canceled": ["Подписка отменена", "Subscription canceled"],
  "admin.economy.payment_provider_configuration.created": [
    "Маршрут оплаты создан",
    "Payment route created",
  ],
  "admin.economy.payment_provider_configuration.cloned": [
    "Маршрут оплаты скопирован",
    "Payment route cloned",
  ],
  "admin.economy.payment_provider_configuration.updated": [
    "Маршрут оплаты обновлён",
    "Payment route updated",
  ],
  "admin.economy.payment_provider_configuration.deleted": [
    "Маршрут оплаты удалён",
    "Payment route deleted",
  ],
  "admin.economy.currency_pack.updated": ["Пакет PawSpark обновлён", "PawSpark pack updated"],
  "admin.economy.subscription_plan.updated": [
    "Тариф подписки обновлён",
    "Subscription plan updated",
  ],
  "admin.economy.redeem_code.created": ["Промокод создан", "Promo code created"],
  "admin.economy.redeem_code.updated": ["Промокод обновлён", "Promo code updated"],
  "admin.economy.incident.resolved": ["Инцидент экономики закрыт", "Economy incident resolved"],
  "admin.economy.incident.reopened": ["Инцидент экономики переоткрыт", "Economy incident reopened"],
  "admin.economy.incident.retry_webhook_processing": [
    "Обработка webhook запущена повторно",
    "Webhook processing retried",
  ],
  "admin.economy.incident.retry_settlement": ["Settlement запущен повторно", "Settlement retried"],
  "admin.economy.incident.manual_settle": [
    "Платёж подтверждён вручную",
    "Payment settled manually",
  ],
  "admin.economy.incident.manual_revoke": ["Начисление отозвано вручную", "Grant revoked manually"],
  "admin.economy.incident.manual_refund_mark": [
    "Возврат отмечен вручную",
    "Refund marked manually",
  ],
  "admin.economy.incident.manual_bonus_grant": [
    "Компенсационный бонус выдан",
    "Compensation bonus granted",
  ],
  "admin.economy.incident.manual_wallet_correction": [
    "Баланс скорректирован вручную",
    "Wallet corrected manually",
  ],
  "admin.economy.incident.restore_generation_charge_marker": [
    "Маркер списания генерации восстановлен",
    "Generation charge marker restored",
  ],
  "admin.economy.incident.refund_generation_spend": [
    "Списание за генерацию возвращено",
    "Generation spend refunded",
  ],
  "admin.content.approved": ["Шаблон одобрен", "Template approved"],
  "admin.content.rejected": ["Шаблон отклонён", "Template rejected"],
  "admin.content.deleted": ["Шаблон удалён", "Template deleted"],
  "admin.content.status_changed": ["Статус шаблона изменён", "Template status changed"],
  "admin.feedback.updated": ["Статус фидбека изменён", "Feedback status changed"],
  "admin.feedback.refunded": ["Компенсация по фидбеку выдана", "Feedback compensation granted"],
  "admin.templates.generation.retry": ["Генерация запущена повторно", "Generation retried"],
  "admin.template_generation.cancelled": ["Генерация отменена", "Generation canceled"],
  "admin.template_generation.cancellation_requested": [
    "Отмена генерации запрошена",
    "Generation cancellation requested",
  ],
  "admin.template_generation.cancellation_exhausted": [
    "Попытки отмены генерации исчерпаны",
    "Generation cancellation retries exhausted",
  ],
  "admin.template_of_the_day.settings_updated": [
    "Настройки шаблона дня обновлены",
    "Daily featured settings updated",
  ],
  "admin.template_of_the_day.created": [
    "Шаблон дня запланирован",
    "Daily featured template scheduled",
  ],
  "admin.template_of_the_day.updated": [
    "Расписание шаблона дня обновлено",
    "Daily featured schedule updated",
  ],
  "admin.template_of_the_day.deleted": [
    "Шаблон дня удалён из расписания",
    "Daily featured schedule removed",
  ],
  "admin.template_of_the_day.auto_picked": [
    "Шаблон дня выбран автоматически",
    "Daily featured template auto-selected",
  ],
  "admin.support.ticket.assigned": ["Диалог поддержки назначен", "Support conversation assigned"],
  "admin.support.ticket.unassigned": [
    "Назначение диалога снято",
    "Support conversation unassigned",
  ],
  "admin.gamification.streak.reset": ["Серия активности сброшена", "Activity streak reset"],
} as const;

function buildActionMap(locale: Locale): Record<string, string> {
  const index = locale === "ru" ? 0 : 1;
  return Object.fromEntries(
    Object.entries(sharedActionKeys).map(([key, labels]) => [key, labels[index]])
  );
}

const copy: Record<Locale, Omit<AuditEventsPageText, "actions">> = {
  ru: {
    title: "Журнал действий",
    description: "История административных и системных изменений для расследований и контроля.",
    refresh: "Обновить",
    refreshing: "Обновляем…",
    accessBadge: "Только Admin",
    lastUpdated: (value) => `Обновлено ${value}`,
    metrics: {
      total: "События в выборке",
      operators: "Операторы",
      access: "Изменения доступа",
      system: "Системные события",
    },
    filtersTitle: "Поиск и фильтры",
    filtersDescription:
      "Сужайте выборку на сервере по периоду, категории, оператору, объекту или correlation ID.",
    searchLabel: "Поиск",
    searchPlaceholder: "Действие, объект, ID или correlation ID",
    actorLabel: "ID оператора",
    actorPlaceholder: "UUID администратора",
    actorInvalid: "Укажите корректный UUID оператора.",
    periodLabel: "Период",
    categoryLabel: "Категория",
    applySearch: "Найти",
    resetFilters: "Сбросить",
    periods: { "24h": "24 часа", "7d": "7 дней", "30d": "30 дней" },
    categories: {
      all: "Все категории",
      identity: "Доступ и аккаунты",
      economy: "Экономика",
      content: "Контент",
      support: "Поддержка",
      gamification: "Геймификация",
      system: "Система",
    },
    loadingTitle: "Загружаем журнал",
    loadingDescription: "Получаем актуальную выборку событий с сервера.",
    errorTitle: "Журнал недоступен",
    errorDescription: "Не удалось загрузить события. Проверьте API и повторите запрос.",
    staleTitle: "Показана предыдущая выборка",
    staleDescription: "Свежие данные не загрузились. Сохранённые события остаются доступны.",
    retry: "Повторить",
    emptyTitle: "События не найдены",
    emptyDescription: "Измените фильтры или расширьте период поиска.",
    eventsTitle: "Хронология событий",
    eventsDescription: "Выберите строку, чтобы открыть полный контекст без перегрузки списка.",
    resultCount: (count) => `${count.toLocaleString("ru-RU")} событий`,
    eventColumns: {
      time: "Время",
      event: "Событие",
      actor: "Оператор",
      target: "Объект",
      category: "Категория",
    },
    page: (current, total) => `Страница ${current} из ${total}`,
    previousPage: "Предыдущая страница",
    nextPage: "Следующая страница",
    detailsTitle: "Детали события",
    detailsDescription: "Полный контекст загружается только для выбранной записи.",
    detailsLoading: "Загружаем детали события…",
    detailsError: "Не удалось загрузить детали события.",
    detailsEmptyTitle: "Выберите событие",
    detailsEmptyDescription: "Здесь появятся исполнитель, объект, изменение и correlation ID.",
    closeDetails: "Закрыть детали события",
    whoAndWhen: "Кто и когда",
    object: "Объект",
    subjectUser: "Пользователь",
    change: "Изменение",
    reason: "Причина и контекст",
    correlationId: "Correlation ID",
    technicalContext: "Технический контекст",
    ipAddress: "IP-адрес",
    userAgent: "User-Agent",
    createdAt: "Записано",
    occurredAt: "Произошло",
    actorRole: "Роль",
    before: "Было",
    after: "Стало",
    systemActor: "Системный процесс",
    unknownActor: "Оператор не определён",
    noTarget: "Объект не указан",
    noValue: "Нет данных",
    openUser: "Открыть пользователя",
    openSupport: "Открыть диалог поддержки",
    openEconomy: "Открыть управление экономикой",
    openPromoCodes: "Открыть промокоды",
    copyCorrelationId: "Скопировать correlation ID",
    copied: "Скопировано",
    copyFailed: "Не удалось скопировать",
    actionCode: "Код действия",
    fallbackAction: "Системное событие",
  },
  en: {
    title: "Audit trail",
    description: "Administrative and system changes for investigations and operational control.",
    refresh: "Refresh",
    refreshing: "Refreshing…",
    accessBadge: "Admin only",
    lastUpdated: (value) => `Updated ${value}`,
    metrics: {
      total: "Events in scope",
      operators: "Operators",
      access: "Access changes",
      system: "System events",
    },
    filtersTitle: "Search and filters",
    filtersDescription:
      "Narrow server results by period, category, operator, target, or correlation ID.",
    searchLabel: "Search",
    searchPlaceholder: "Action, target, ID, or correlation ID",
    actorLabel: "Operator ID",
    actorPlaceholder: "Administrator UUID",
    actorInvalid: "Enter a valid operator UUID.",
    periodLabel: "Period",
    categoryLabel: "Category",
    applySearch: "Search",
    resetFilters: "Reset",
    periods: { "24h": "24 hours", "7d": "7 days", "30d": "30 days" },
    categories: {
      all: "All categories",
      identity: "Access and accounts",
      economy: "Economy",
      content: "Content",
      support: "Support",
      gamification: "Gamification",
      system: "System",
    },
    loadingTitle: "Loading audit trail",
    loadingDescription: "Retrieving the latest server-side event set.",
    errorTitle: "Audit trail unavailable",
    errorDescription: "Events could not be loaded. Check the API and retry.",
    staleTitle: "Showing the previous result set",
    staleDescription: "Fresh data could not be loaded. Saved events remain available.",
    retry: "Retry",
    emptyTitle: "No events found",
    emptyDescription: "Change the filters or expand the time range.",
    eventsTitle: "Event timeline",
    eventsDescription: "Select a row to load full context without overloading the list.",
    resultCount: (count) => `${count.toLocaleString("en-US")} events`,
    eventColumns: {
      time: "Time",
      event: "Event",
      actor: "Operator",
      target: "Target",
      category: "Category",
    },
    page: (current, total) => `Page ${current} of ${total}`,
    previousPage: "Previous page",
    nextPage: "Next page",
    detailsTitle: "Event details",
    detailsDescription: "Full context is loaded only for the selected record.",
    detailsLoading: "Loading event details…",
    detailsError: "Event details could not be loaded.",
    detailsEmptyTitle: "Select an event",
    detailsEmptyDescription: "Actor, target, change, and correlation ID will appear here.",
    closeDetails: "Close event details",
    whoAndWhen: "Who and when",
    object: "Target",
    subjectUser: "User",
    change: "Change",
    reason: "Reason and context",
    correlationId: "Correlation ID",
    technicalContext: "Technical context",
    ipAddress: "IP address",
    userAgent: "User-Agent",
    createdAt: "Recorded",
    occurredAt: "Occurred",
    actorRole: "Role",
    before: "Before",
    after: "After",
    systemActor: "System process",
    unknownActor: "Unknown operator",
    noTarget: "No target",
    noValue: "No data",
    openUser: "Open user",
    openSupport: "Open support conversation",
    openEconomy: "Open economy management",
    openPromoCodes: "Open promo codes",
    copyCorrelationId: "Copy correlation ID",
    copied: "Copied",
    copyFailed: "Copy failed",
    actionCode: "Action code",
    fallbackAction: "System event",
  },
};

export function getAuditEventsPageText(locale: Locale): AuditEventsPageText {
  return { ...copy[locale], actions: buildActionMap(locale) };
}

export function getAuditActionTitle(locale: Locale, action: string): string {
  const text = getAuditEventsPageText(locale);
  const normalizedAction = action.trim().toLowerCase();
  if (normalizedAction.startsWith("admin.templates.gamification_legacy.")) {
    return locale === "ru"
      ? "Legacy-прогресс геймификации согласован"
      : "Legacy gamification progress reconciled";
  }

  return text.actions[normalizedAction] ?? text.fallbackAction;
}
