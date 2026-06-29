import { type Locale } from "@/lib/i18n";

type ManageableRole = "Admin" | "Moderator";

export type UsersManagementPageText = {
  notificationTitle: string;
  summaryTotal: string;
  summaryActive: string;
  summaryPremium: string;
  summaryBlocked: string;
  summaryNew: string;
  summaryOpenSupport: string;
  periodLabel: string;
  period7: string;
  period30: string;
  period90: string;
  searchPlaceholder: string;
  filterRole: string;
  filterPremium: string;
  filterActivity: string;
  filterStatus: string;
  resetFilters: string;
  any: string;
  premiumOnly: string;
  freeOnly: string;
  activeOnly: string;
  blockedOnly: string;
  statusActive: string;
  statusBlocked: string;
  statusUnconfirmed: string;
  usersCount: string;
  accountStatus: string;
  premiumAndExpiry: string;
  balance: string;
  registeredAt: string;
  lastActivity: string;
  quickActions: string;
  openCard: string;
  openSideCard: string;
  quickCredit: string;
  quickDebit: string;
  walletDialogTitleCredit: string;
  walletDialogTitleDebit: string;
  walletAmountLabel: string;
  walletReasonLabel: string;
  walletReasonRequired: string;
  walletCancel: string;
  walletSubmit: string;
  premiumEndUnknown: string;
  premiumEnd: string;
  menuLabel: string;
  noSearchResults: string;
  pageInfo: string;
  prevPage: string;
  nextPage: string;
  previousPageLabel: string;
  nextPageLabel: string;
  sideTitle: string;
  sideDescription: string;
  closePanel: string;
  sectionProfile: string;
  sectionBalance: string;
  sectionRoles: string;
  sectionPremium: string;
  sectionSupport: string;
  sectionPurchases: string;
  sectionGenerations: string;
  sectionAudit: string;
  sectionDanger: string;
  noData: string;
  blockedBadge: string;
  activeBadge: string;
  unconfirmedBadge: string;
  sideOpenFullProfile: string;
  confirmCancel: string;
  confirmDeleteTitle: string;
  confirmBlockTitle: string;
  confirmUnblockTitle: string;
  confirmPremiumTitle: string;
  confirmRoleTitle: string;
  lastAdminProtected: string;
  confirmAction: string;
  activeChangeDescription: (userLabel: string) => string;
  deleteDescription: (userLabel: string, deleteSummary: string) => string;
  premiumChangeDescription: (userLabel: string) => string;
  roleChangeDescription: (
    userLabel: string,
    role: ManageableRole,
    hasRole: boolean
  ) => string;
};

const usersManagementPageText: Record<Locale, UsersManagementPageText> = {
  ru: {
    notificationTitle: "Изменения пользователей",
    summaryTotal: "Всего пользователей",
    summaryActive: "Активные",
    summaryPremium: "Premium",
    summaryBlocked: "Заблокированные",
    summaryNew: "Новые за период",
    summaryOpenSupport: "С открытыми обращениями",
    periodLabel: "Период",
    period7: "7 дней",
    period30: "30 дней",
    period90: "90 дней",
    searchPlaceholder: "Поиск по email или userId",
    filterRole: "Роль",
    filterPremium: "Premium",
    filterActivity: "Активность",
    filterStatus: "Статус",
    resetFilters: "Сбросить",
    any: "Все",
    premiumOnly: "Только Premium",
    freeOnly: "Без Premium",
    activeOnly: "Только активные",
    blockedOnly: "Только заблокированные",
    statusActive: "Аккаунт активен",
    statusBlocked: "Заблокирован",
    statusUnconfirmed: "Почта не подтверждена",
    usersCount: "Пользователей",
    accountStatus: "Статус аккаунта",
    premiumAndExpiry: "Premium и окончание",
    balance: "Баланс",
    registeredAt: "Регистрация",
    lastActivity: "Последняя активность",
    quickActions: "Быстрые действия",
    openCard: "Открыть карточку",
    openSideCard: "Карточка",
    quickCredit: "Начислить",
    quickDebit: "Списать",
    walletDialogTitleCredit: "Начислить баланс",
    walletDialogTitleDebit: "Списать баланс",
    walletAmountLabel: "Сумма PawSpark",
    walletReasonLabel: "Причина",
    walletReasonRequired: "Укажите причину операции",
    walletCancel: "Отмена",
    walletSubmit: "Сохранить",
    premiumEndUnknown: "Срок не задан",
    premiumEnd: "До",
    menuLabel: "Доп. действия",
    noSearchResults: "По заданным фильтрам пользователей нет",
    pageInfo: "Страница",
    prevPage: "Назад",
    nextPage: "Вперед",
    previousPageLabel: "Предыдущая страница пользователей",
    nextPageLabel: "Следующая страница пользователей",
    sideTitle: "Карточка пользователя",
    sideDescription: "Ключевые данные, история действий и контроль аккаунта",
    closePanel: "Закрыть",
    sectionProfile: "Основная информация",
    sectionBalance: "Баланс",
    sectionRoles: "Роли",
    sectionPremium: "Premium",
    sectionSupport: "Обращения в поддержку",
    sectionPurchases: "История платежей",
    sectionGenerations: "История генераций",
    sectionAudit: "Audit log",
    sectionDanger: "Опасные действия",
    noData: "Нет данных",
    blockedBadge: "Заблокирован",
    activeBadge: "Активен",
    unconfirmedBadge: "Не подтвержден",
    sideOpenFullProfile: "Открыть полную страницу",
    confirmCancel: "Отмена",
    confirmDeleteTitle: "Удалить пользователя?",
    confirmBlockTitle: "Заблокировать пользователя?",
    confirmUnblockTitle: "Разблокировать пользователя?",
    confirmPremiumTitle: "Изменить Premium?",
    confirmRoleTitle: "Изменить роль?",
    lastAdminProtected: "Последнего Admin нельзя понизить",
    confirmAction: "Подтвердить",
    activeChangeDescription: (userLabel) =>
      `${userLabel}: действие будет записано в audit log и немедленно изменит доступ пользователя.`,
    deleteDescription: (userLabel, deleteSummary) => `${userLabel}: ${deleteSummary}`,
    premiumChangeDescription: (userLabel) =>
      `${userLabel}: Premium-статус изменится через admin endpoint и будет записан в audit log.`,
    roleChangeDescription: (userLabel, role, hasRole) =>
      `${userLabel}: ${hasRole ? "роль будет снята" : "роль будет назначена"} (${role}).`,
  },
  en: {
    notificationTitle: "User updates",
    summaryTotal: "Total users",
    summaryActive: "Active users",
    summaryPremium: "Premium users",
    summaryBlocked: "Blocked users",
    summaryNew: "New in period",
    summaryOpenSupport: "Users with open tickets",
    periodLabel: "Period",
    period7: "7 days",
    period30: "30 days",
    period90: "90 days",
    searchPlaceholder: "Search by email or userId",
    filterRole: "Role",
    filterPremium: "Premium",
    filterActivity: "Activity",
    filterStatus: "Status",
    resetFilters: "Reset",
    any: "All",
    premiumOnly: "Premium only",
    freeOnly: "Free only",
    activeOnly: "Active only",
    blockedOnly: "Blocked only",
    statusActive: "Account active",
    statusBlocked: "Blocked",
    statusUnconfirmed: "Email not confirmed",
    usersCount: "Users",
    accountStatus: "Account status",
    premiumAndExpiry: "Premium and expiry",
    balance: "Balance",
    registeredAt: "Registered",
    lastActivity: "Last activity",
    quickActions: "Quick actions",
    openCard: "Open profile",
    openSideCard: "Card",
    quickCredit: "Credit",
    quickDebit: "Debit",
    walletDialogTitleCredit: "Credit balance",
    walletDialogTitleDebit: "Debit balance",
    walletAmountLabel: "PawSpark amount",
    walletReasonLabel: "Reason",
    walletReasonRequired: "Reason is required",
    walletCancel: "Cancel",
    walletSubmit: "Save",
    premiumEndUnknown: "No expiry",
    premiumEnd: "Until",
    menuLabel: "More actions",
    noSearchResults: "No users match current filters",
    pageInfo: "Page",
    prevPage: "Prev",
    nextPage: "Next",
    previousPageLabel: "Previous users page",
    nextPageLabel: "Next users page",
    sideTitle: "User side panel",
    sideDescription: "Key profile context, history, and controls",
    closePanel: "Close",
    sectionProfile: "Profile",
    sectionBalance: "Balance",
    sectionRoles: "Roles",
    sectionPremium: "Premium",
    sectionSupport: "Support tickets",
    sectionPurchases: "Payment history",
    sectionGenerations: "Generation history",
    sectionAudit: "Audit log",
    sectionDanger: "Danger zone",
    noData: "No data",
    blockedBadge: "Blocked",
    activeBadge: "Active",
    unconfirmedBadge: "Unconfirmed",
    sideOpenFullProfile: "Open full profile",
    confirmCancel: "Cancel",
    confirmDeleteTitle: "Delete user?",
    confirmBlockTitle: "Block user?",
    confirmUnblockTitle: "Unblock user?",
    confirmPremiumTitle: "Change Premium?",
    confirmRoleTitle: "Change role?",
    lastAdminProtected: "The last Admin cannot be downgraded",
    confirmAction: "Confirm",
    activeChangeDescription: (userLabel) =>
      `${userLabel}: this will be written to the audit log and immediately change user access.`,
    deleteDescription: (userLabel, deleteSummary) => `${userLabel}: ${deleteSummary}`,
    premiumChangeDescription: (userLabel) =>
      `${userLabel}: Premium status will be changed through the admin endpoint and written to the audit log.`,
    roleChangeDescription: (userLabel, role, hasRole) =>
      `${userLabel}: the ${role} role will be ${hasRole ? "revoked" : "assigned"}.`,
  },
};

export function getUsersManagementPageText(locale: Locale): UsersManagementPageText {
  return usersManagementPageText[locale];
}
