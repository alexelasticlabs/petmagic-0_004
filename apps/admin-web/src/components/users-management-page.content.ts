import { type Locale } from "@/lib/i18n";

export type UsersManagementPageText = {
  notificationTitle: string;
  accessRestrictedTitle: string;
  accessRestrictedDescription: string;
  loadingTitle: string;
  loadingDescription: string;
  summaryTitle: string;
  summaryUnavailable: string;
  summaryRetry: string;
  summaryTotal: string;
  summaryActive: string;
  summaryPremium: string;
  summaryBlocked: string;
  summaryNew: string;
  summaryNewForPeriod: string;
  registryTitle: string;
  periodLabel: string;
  period7: string;
  period30: string;
  period90: string;
  searchLabel: string;
  clearSearch: string;
  searchPlaceholder: string;
  filterRole: string;
  filterPremium: string;
  filterStatus: string;
  sortLabel: string;
  sortCreatedDesc: string;
  sortCreatedAsc: string;
  sortLastActivityDesc: string;
  sortLastActivityAsc: string;
  filtersLabel: string;
  resetFilters: string;
  filtersWithCount: string;
  any: string;
  premiumOnly: string;
  freeOnly: string;
  statusActive: string;
  statusBlocked: string;
  statusUnconfirmed: string;
  usersCount: string;
  userColumn: string;
  accountAndAccess: string;
  plan: string;
  lastActivity: string;
  noActivity: string;
  registeredAt: string;
  openProfile: string;
  quickActions: string;
  quickWallet: string;
  quickSupport: string;
  identifierPrefix: string;
  noSearchResults: string;
  pageInfo: string;
  previousPageLabel: string;
  nextPageLabel: string;
  activeBadge: string;
  blockedBadge: string;
  unconfirmedBadge: string;
  bulkEmail: {
    openLabel: string;
    selectedCount: (count: number) => string;
    selectionTrayLabel: string;
    selectionDescription: (eligible: number, total: number) => string;
    selectionEligible: string;
    selectionIneligible: string;
    selectionRemove: string;
    selectionClear: string;
    selectAllLabel: string;
    selectUserLabel: (userLabel: string) => string;
    unavailableRecipientLabel: string;
    composerTitle: string;
    composerDescription: string;
    audienceLabel: string;
    audienceAllActive: string;
    audienceAllActiveHint: string;
    audiencePremium: string;
    audiencePremiumHint: string;
    audienceSelected: string;
    audienceSelectedHint: (count: number) => string;
    noSelectedUsers: string;
    subjectLabel: string;
    subjectPlaceholder: string;
    bodyLabel: string;
    bodyPlaceholder: string;
    policyConfirmation: string;
    operationalWarning: string;
    reviewAction: string;
    reviewTitle: string;
    reviewDescription: string;
    reviewAudienceLabel: string;
    reviewSubjectLabel: string;
    reviewBodyLabel: string;
    queueAction: string;
    cancel: string;
    success: string;
    error: string;
  };
};

const usersManagementPageText: Record<Locale, UsersManagementPageText> = {
  ru: {
    notificationTitle: "Изменения пользователей",
    accessRestrictedTitle: "Нет доступа к реестру пользователей",
    accessRestrictedDescription: "Для управления пользователями нужна роль администратора.",
    loadingTitle: "Загружаем пользователей",
    loadingDescription: "Обновляем реестр и данные аккаунтов.",
    summaryTitle: "Сводка",
    summaryUnavailable: "Сводка временно недоступна.",
    summaryRetry: "Повторить",
    summaryTotal: "Всего пользователей",
    summaryActive: "Активные",
    summaryPremium: "Premium",
    summaryBlocked: "Заблокированные",
    summaryNew: "Новые",
    summaryNewForPeriod: "Новые за {period}",
    registryTitle: "Реестр пользователей",
    periodLabel: "Период",
    period7: "7 дней",
    period30: "30 дней",
    period90: "90 дней",
    searchLabel: "Поиск",
    clearSearch: "Очистить поиск",
    searchPlaceholder: "Поиск по имени, email или ID",
    filterRole: "Роль",
    filterPremium: "Premium",
    filterStatus: "Состояние аккаунта",
    sortLabel: "Сортировка",
    sortCreatedDesc: "Сначала новые",
    sortCreatedAsc: "Сначала старые",
    sortLastActivityDesc: "Активные недавно",
    sortLastActivityAsc: "Давно без активности",
    filtersLabel: "Фильтры",
    resetFilters: "Сбросить",
    filtersWithCount: "Фильтры ({count})",
    any: "Все",
    premiumOnly: "Только Premium",
    freeOnly: "Без Premium",
    statusActive: "Аккаунт активен",
    statusBlocked: "Заблокирован",
    statusUnconfirmed: "Почта не подтверждена",
    usersCount: "Пользователей",
    userColumn: "Пользователь",
    accountAndAccess: "Состояние и доступ",
    plan: "План",
    lastActivity: "Последняя активность",
    noActivity: "Нет активности",
    registeredAt: "Зарегистрирован",
    openProfile: "Открыть досье",
    quickActions: "Быстрые действия",
    quickWallet: "Баланс",
    quickSupport: "Обращения",
    identifierPrefix: "ID",
    noSearchResults: "По заданным фильтрам пользователей нет",
    pageInfo: "Страница",
    previousPageLabel: "Предыдущая страница пользователей",
    nextPageLabel: "Следующая страница пользователей",
    activeBadge: "Активен",
    blockedBadge: "Заблокирован",
    unconfirmedBadge: "Не подтвержден",
    bulkEmail: {
      openLabel: "Email-рассылка",
      selectedCount: (count) => `Выбрано: ${count}`,
      selectionTrayLabel: "Выбранные получатели email-рассылки",
      selectionDescription: (eligible, total) =>
        `Доступно для отправки: ${eligible} из ${total}. Выбор сохранён для текущего администратора.`,
      selectionEligible: "Доступен для отправки",
      selectionIneligible: "Больше не соответствует условиям",
      selectionRemove: "Убрать",
      selectionClear: "Очистить выбор",
      selectAllLabel: "Выбрать доступных получателей на странице",
      selectUserLabel: (userLabel) => `Выбрать получателя: ${userLabel}`,
      unavailableRecipientLabel:
        "Рассылка доступна только активным пользователям с подтверждённой почтой",
      composerTitle: "Подготовить email-рассылку",
      composerDescription:
        "Сообщение будет поставлено в очередь backend и отправлено подходящим получателям.",
      audienceLabel: "Аудитория",
      audienceAllActive: "Все активные",
      audienceAllActiveHint: "Все активные пользователи с подтверждённой почтой.",
      audiencePremium: "Premium",
      audiencePremiumHint: "Активные Premium-пользователи с подтверждённой почтой.",
      audienceSelected: "Выбранные пользователи",
      audienceSelectedHint: (count) => `${count} выбранных получателей.`,
      noSelectedUsers: "Сначала выберите хотя бы одного доступного пользователя в таблице.",
      subjectLabel: "Тема письма",
      subjectPlaceholder: "Кратко опишите цель сообщения",
      bodyLabel: "Текст письма",
      bodyPlaceholder: "Введите текст без секретов, токенов и внутренних технических данных",
      policyConfirmation:
        "Я проверил аудиторию и подтверждаю, что содержание соответствует цели рассылки.",
      operationalWarning:
        "Массовая отправка — чувствительное действие. Не включайте секреты и соблюдайте требования к пользовательским согласиям.",
      reviewAction: "Проверить",
      reviewTitle: "Проверить рассылку",
      reviewDescription:
        "После подтверждения backend создаст отдельные задания отправки и запишет действие в audit trail.",
      reviewAudienceLabel: "Аудитория",
      reviewSubjectLabel: "Тема",
      reviewBodyLabel: "Текст",
      queueAction: "Поставить в очередь",
      cancel: "Отмена",
      success: "Рассылка поставлена в очередь.",
      error: "Не удалось поставить рассылку в очередь.",
    },
  },
  en: {
    notificationTitle: "User updates",
    accessRestrictedTitle: "You do not have access to the user directory",
    accessRestrictedDescription: "An administrator role is required to manage users.",
    loadingTitle: "Loading users",
    loadingDescription: "Refreshing the directory and account data.",
    summaryTitle: "Overview",
    summaryUnavailable: "Overview is temporarily unavailable.",
    summaryRetry: "Retry",
    summaryTotal: "Total users",
    summaryActive: "Active",
    summaryPremium: "Premium",
    summaryBlocked: "Blocked",
    summaryNew: "New",
    summaryNewForPeriod: "New in {period}",
    registryTitle: "User directory",
    periodLabel: "Period",
    period7: "7 days",
    period30: "30 days",
    period90: "90 days",
    searchLabel: "Search",
    clearSearch: "Clear search",
    searchPlaceholder: "Search by name, email, or ID",
    filterRole: "Role",
    filterPremium: "Premium",
    filterStatus: "Account state",
    sortLabel: "Sort",
    sortCreatedDesc: "Newest first",
    sortCreatedAsc: "Oldest first",
    sortLastActivityDesc: "Recently active",
    sortLastActivityAsc: "Least recently active",
    filtersLabel: "Filters",
    resetFilters: "Reset",
    filtersWithCount: "Filters ({count})",
    any: "All",
    premiumOnly: "Premium only",
    freeOnly: "Free",
    statusActive: "Account active",
    statusBlocked: "Blocked",
    statusUnconfirmed: "Email not confirmed",
    usersCount: "Users",
    userColumn: "User",
    accountAndAccess: "State and access",
    plan: "Plan",
    lastActivity: "Last activity",
    noActivity: "No activity yet",
    registeredAt: "Registered",
    openProfile: "Open dossier",
    quickActions: "Quick actions",
    quickWallet: "Balance",
    quickSupport: "Support",
    identifierPrefix: "ID",
    noSearchResults: "No users match current filters",
    pageInfo: "Page",
    previousPageLabel: "Previous users page",
    nextPageLabel: "Next users page",
    activeBadge: "Active",
    blockedBadge: "Blocked",
    unconfirmedBadge: "Unconfirmed",
    bulkEmail: {
      openLabel: "Email campaign",
      selectedCount: (count) => `Selected: ${count}`,
      selectionTrayLabel: "Selected email recipients",
      selectionDescription: (eligible, total) =>
        `${eligible} of ${total} are eligible. The selection is saved for the current administrator.`,
      selectionEligible: "Eligible for delivery",
      selectionIneligible: "No longer eligible",
      selectionRemove: "Remove",
      selectionClear: "Clear selection",
      selectAllLabel: "Select eligible recipients on this page",
      selectUserLabel: (userLabel) => `Select recipient: ${userLabel}`,
      unavailableRecipientLabel: "Only active users with confirmed email can receive this message",
      composerTitle: "Prepare email campaign",
      composerDescription:
        "The message will be queued by the backend for every eligible recipient.",
      audienceLabel: "Audience",
      audienceAllActive: "All active users",
      audienceAllActiveHint: "All active users with confirmed email.",
      audiencePremium: "Premium",
      audiencePremiumHint: "Active Premium users with confirmed email.",
      audienceSelected: "Selected users",
      audienceSelectedHint: (count) => `${count} selected recipients.`,
      noSelectedUsers: "Select at least one eligible user in the table first.",
      subjectLabel: "Email subject",
      subjectPlaceholder: "Summarize the purpose of the message",
      bodyLabel: "Email body",
      bodyPlaceholder: "Enter content without secrets, tokens, or internal technical details",
      policyConfirmation:
        "I reviewed the audience and confirm that this content matches the campaign purpose.",
      operationalWarning:
        "Bulk delivery is a sensitive action. Never include secrets and comply with user consent requirements.",
      reviewAction: "Review",
      reviewTitle: "Review email campaign",
      reviewDescription:
        "After confirmation, the backend creates individual delivery jobs and records the action in the audit trail.",
      reviewAudienceLabel: "Audience",
      reviewSubjectLabel: "Subject",
      reviewBodyLabel: "Body",
      queueAction: "Queue delivery",
      cancel: "Cancel",
      success: "Email campaign was queued.",
      error: "Failed to queue the email campaign.",
    },
  },
};

export function getUsersManagementPageText(locale: Locale): UsersManagementPageText {
  return usersManagementPageText[locale];
}
