"use client";

import { keepPreviousData, useQueries, useQuery } from "@tanstack/react-query";
import Link from "next/link";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { createPortal } from "react-dom";

import {
  CancelCircleIcon,
  DollarIcon,
  MoreHorizontalIcon,
  UsersIcon,
} from "@/components/admin/admin-icons";
import {
  AdminBadge,
  AdminCard,
  AdminKpiCard,
  AdminPage,
  AdminPageGrid,
  AdminPageHero,
  AdminStateCard,
  AdminStatusBadge,
  adminTableStyles,
  type AdminTone,
} from "@/components/admin/admin-primitives";
import { ConfirmationDialog } from "@/components/admin/confirmation-dialog";
import { formatSupportMessagePreview } from "@/components/support/support-message-preview";
import { Button } from "@/components/ui/button";
import { Toast } from "@/components/ui/toast";
import { useAdminUserProfile } from "@/components/users/use-admin-user-profile";
import { useUsersAdmin } from "@/components/users/use-users-admin";
import { UserAvatarView } from "@/components/users/user-avatar";
import styles from "@/components/users-management-page.module.css";
import { adminQueryKeys } from "@/lib/admin-query-keys";
import {
  adjustAdminUserWallet,
  assignRole,
  deleteAdminUser,
  fetchAdminEconomyUserSubscriptionSummary,
  fetchAdminUserAnalytics,
  fetchAdminUserDashboardMetrics,
  fetchSupportInbox,
  revokePremium,
  revokeRole,
  setActive,
  setPremium,
  USER_SEARCH_MAX_LENGTH,
  USER_WALLET_REASON_MAX_LENGTH,
  type AdminUserDashboardMetrics,
  type UserListItem,
} from "@/lib/api-client";
import { formatDateTime } from "@/lib/format-date-time";
import { getDictionary, type Dictionary, type Locale } from "@/lib/i18n";
import {
  getAdminUserDisplayName,
  maskEmail,
  sanitizeSensitiveText,
  shortIdentifier,
} from "@/lib/sensitive-display";

type UsersManagementPageProps = {
  locale: Locale;
};

type ActionsMenuPosition = {
  top: number;
  left: number;
  minWidth: number;
  openUpward: boolean;
};

type WalletDialogState = {
  userId: string;
  operation: "credit" | "debit";
  amount: string;
  reason: string;
  error: string | null;
};

type ConfirmationDialogState = {
  userId: string;
  title: string;
  description: string;
  confirmLabel: string;
  successMessage?: string;
  errorMessage?: string;
  tone?: "danger" | "primary";
  action: () => Promise<void>;
  afterSuccess?: () => void;
};

type RangeDays = 7 | 30 | 90;

type RoleFilter = "all" | "Admin" | "Moderator" | "User";
type PremiumFilter = "all" | "premium" | "free";
type ActivityFilter = "all" | "active" | "blocked";
type StatusFilter = "all" | "active" | "blocked" | "unconfirmed";

type UserRoleText = Pick<Dictionary, "userRoleAdmin" | "userRoleModerator" | "userRoleUser">;

const PAGE_SIZE = 12;

function getUserRoleLabel(role: string, text: UserRoleText) {
  return role === "Admin"
    ? text.userRoleAdmin
    : role === "Moderator"
      ? text.userRoleModerator
      : role === "User"
        ? text.userRoleUser
        : sanitizeSensitiveText(role, 32);
}

function getUserRoleTone(role: string): AdminTone {
  if (role === "Admin") {
    return "danger";
  }

  if (role === "Moderator") {
    return "info";
  }

  return "neutral";
}

function getUserAvatarLabel(user: Pick<UserListItem, "displayName" | "email" | "userId">): string {
  return sanitizeSensitiveText(getAdminUserDisplayName(user), 96);
}

function getAccountStatus(user: UserListItem): "active" | "blocked" | "unconfirmed" {
  if (!user.isActive) {
    return "blocked";
  }

  if (!user.emailConfirmed) {
    return "unconfirmed";
  }

  return "active";
}

function formatMetricCount(value: number | null | undefined): string {
  return typeof value === "number" && Number.isFinite(value) ? String(Math.max(0, value)) : "—";
}

function getNewUsersCountForRange(
  metrics: AdminUserDashboardMetrics | null,
  rangeDays: RangeDays
): number | null {
  if (!metrics) {
    return null;
  }

  if (rangeDays === 7) {
    return metrics.newUsersLast7Days;
  }

  if (rangeDays === 30) {
    return metrics.newUsersLast30Days;
  }

  return metrics.newUsersLast90Days;
}

export function UsersManagementPage({ locale }: UsersManagementPageProps) {
  const text = getDictionary(locale);
  const ui = useMemo(
    () =>
      locale === "ru"
        ? {
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
          }
        : {
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
          },
    [locale]
  );

  const [search, setSearch] = useState("");
  const [debouncedSearch, setDebouncedSearch] = useState("");
  const [roleFilter, setRoleFilter] = useState<RoleFilter>("all");
  const [premiumFilter, setPremiumFilter] = useState<PremiumFilter>("all");
  const [activityFilter, setActivityFilter] = useState<ActivityFilter>("all");
  const [statusFilter, setStatusFilter] = useState<StatusFilter>("all");
  const [rangeDays, setRangeDays] = useState<RangeDays>(30);
  const [page, setPage] = useState(1);

  const [openActionsUserId, setOpenActionsUserId] = useState<string | null>(null);
  const [actionsMenuPosition, setActionsMenuPosition] = useState<ActionsMenuPosition | null>(null);
  const [selectedUserId, setSelectedUserId] = useState<string | null>(null);
  const [walletDialog, setWalletDialog] = useState<WalletDialogState | null>(null);
  const [walletDialogSubmitting, setWalletDialogSubmitting] = useState(false);
  const [confirmationDialog, setConfirmationDialog] = useState<ConfirmationDialogState | null>(
    null
  );
  const [confirmationSubmitting, setConfirmationSubmitting] = useState(false);

  const menuRootRef = useRef<HTMLDivElement | null>(null);
  const triggerRefs = useRef<Record<string, HTMLButtonElement | null>>({});

  useEffect(() => {
    const timer = window.setTimeout(() => {
      setDebouncedSearch(search.trim());
    }, 350);

    return () => {
      window.clearTimeout(timer);
    };
  }, [search]);

  const usersStatusFilter = statusFilter !== "all" ? statusFilter : activityFilter;
  const usersQueryParams = useMemo(
    () => ({
      skip: (page - 1) * PAGE_SIZE,
      take: PAGE_SIZE,
      search: debouncedSearch || undefined,
      role: roleFilter === "all" ? undefined : roleFilter,
      status: usersStatusFilter === "all" ? undefined : usersStatusFilter,
      isPremium:
        premiumFilter === "premium" ? true : premiumFilter === "free" ? false : undefined,
    }),
    [debouncedSearch, page, premiumFilter, roleFilter, usersStatusFilter]
  );

  const {
    busyUserId,
    canManageRoles,
    error,
    hasSession,
    isFetching: isUsersFetching,
    isLoading,
    refreshUsers,
    runAction,
    toast,
    users,
    usersPage,
  } = useUsersAdmin(locale, usersQueryParams);

  const userMetricsQuery = useQuery({
    queryKey: adminQueryKeys.userDashboardMetrics,
    queryFn: ({ signal }) => fetchAdminUserDashboardMetrics(signal),
    enabled: hasSession,
    placeholderData: keepPreviousData,
    staleTime: 60_000,
  });
  const userMetrics = userMetricsQuery.data ?? null;
  const totalAdminCount = userMetrics?.adminUsers ?? null;
  const isUserActionLocked = confirmationSubmitting || walletDialogSubmitting;

  const closeActionsMenu = useCallback(() => {
    setOpenActionsUserId(null);
    setActionsMenuPosition(null);
  }, []);

  const supportInboxQuery = useQuery({
    queryKey: adminQueryKeys.supportInbox("all", "all", { page: 1, pageSize: 50 }),
    queryFn: ({ signal }) => fetchSupportInbox(undefined, "all", { page: 1, pageSize: 50, signal }),
    enabled: hasSession && users.length > 0,
  });

  const selectedUserProfile = useAdminUserProfile({ enabled: hasSession, userId: selectedUserId });

  const selectedSubscriptionQuery = useQuery({
    queryKey: selectedUserId
      ? adminQueryKeys.economyUserSubscriptionSummary(selectedUserId)
      : adminQueryKeys.economyUserSubscriptionSummaryDisabled,
    queryFn: ({ signal }) => fetchAdminEconomyUserSubscriptionSummary(selectedUserId!, signal),
    enabled: hasSession && Boolean(selectedUserId),
  });

  const openWalletDialog = useCallback(
    (userId: string, operation: "credit" | "debit") => {
      if (!canManageRoles || isUserActionLocked) {
        return;
      }

      setOpenActionsUserId(null);
      setActionsMenuPosition(null);
      setWalletDialog({
        userId,
        operation,
        amount: "100",
        reason: text.usersBalanceReasonDefault,
        error: null,
      });
    },
    [canManageRoles, isUserActionLocked, text.usersBalanceReasonDefault]
  );

  const closeWalletDialog = useCallback(() => {
    if (walletDialogSubmitting) {
      return;
    }

    setWalletDialog(null);
  }, [walletDialogSubmitting]);

  const runUserAction = useCallback(
    async (
      userId: string,
      action: () => Promise<void>,
      options?: { successMessage?: string; errorMessage?: string }
    ) => {
      const succeeded = await runAction(userId, action, options);
      if (succeeded && selectedUserId === userId) {
        await selectedUserProfile.refresh();
      }
      return succeeded;
    },
    [runAction, selectedUserId, selectedUserProfile]
  );

  const closeConfirmationDialog = useCallback(() => {
    if (confirmationSubmitting) {
      return;
    }

    setConfirmationDialog(null);
  }, [confirmationSubmitting]);

  const submitConfirmationDialog = useCallback(async () => {
    if (!confirmationDialog || confirmationSubmitting) {
      return;
    }

    setConfirmationSubmitting(true);
    try {
      const succeeded = await runUserAction(confirmationDialog.userId, confirmationDialog.action, {
        successMessage: confirmationDialog.successMessage,
        errorMessage: confirmationDialog.errorMessage,
      });
      if (succeeded) {
        confirmationDialog.afterSuccess?.();
        setConfirmationDialog(null);
      }
    } finally {
      setConfirmationSubmitting(false);
    }
  }, [confirmationDialog, confirmationSubmitting, runUserAction]);

  const requestUserConfirmation = useCallback(
    (next: ConfirmationDialogState) => {
      if (isUserActionLocked) {
        return;
      }

      closeActionsMenu();
      setConfirmationDialog(next);
    },
    [closeActionsMenu, isUserActionLocked]
  );

  const getUserLabel = useCallback((user: UserListItem) => {
    return sanitizeSensitiveText(getAdminUserDisplayName(user), 96);
  }, []);

  const requestActiveChange = useCallback(
    (user: UserListItem) => {
      if (!canManageRoles) {
        return;
      }

      const nextIsActive = !user.isActive;
      const userLabel = getUserLabel(user);
      requestUserConfirmation({
        userId: user.userId,
        title: nextIsActive ? ui.confirmUnblockTitle : ui.confirmBlockTitle,
        description:
          locale === "ru"
            ? `${userLabel}: действие будет записано в audit log и немедленно изменит доступ пользователя.`
            : `${userLabel}: this will be written to the audit log and immediately change user access.`,
        confirmLabel: nextIsActive ? text.activate : text.deactivate,
        errorMessage: text.errorLoadingUsers,
        action: () => setActive(user.userId, nextIsActive),
      });
    },
    [
      getUserLabel,
      locale,
      requestUserConfirmation,
      text.activate,
      text.deactivate,
      text.errorLoadingUsers,
      ui.confirmBlockTitle,
      ui.confirmUnblockTitle,
      canManageRoles,
    ]
  );

  const requestDeleteUser = useCallback(
    (user: UserListItem, afterSuccess?: () => void) => {
      if (!canManageRoles) {
        return;
      }

      const userLabel = getUserLabel(user);
      requestUserConfirmation({
        userId: user.userId,
        title: ui.confirmDeleteTitle,
        description:
          locale === "ru"
            ? `${userLabel}: ${text.usersDeleteConfirm}`
            : `${userLabel}: ${text.usersDeleteConfirm}`,
        confirmLabel: text.usersDeleteAction,
        successMessage: text.usersDeletedSuccess,
        errorMessage: text.errorLoadingUsers,
        action: () => deleteAdminUser(user.userId),
        afterSuccess,
      });
    },
    [
      getUserLabel,
      locale,
      requestUserConfirmation,
      text.errorLoadingUsers,
      text.usersDeleteAction,
      text.usersDeleteConfirm,
      text.usersDeletedSuccess,
      ui.confirmDeleteTitle,
      canManageRoles,
    ]
  );

  const requestPremiumChange = useCallback(
    (user: UserListItem) => {
      if (!canManageRoles) {
        return;
      }

      const userLabel = getUserLabel(user);
      requestUserConfirmation({
        userId: user.userId,
        title: ui.confirmPremiumTitle,
        description:
          locale === "ru"
            ? `${userLabel}: Premium-статус изменится через admin endpoint и будет записан в audit log.`
            : `${userLabel}: Premium status will be changed through the admin endpoint and written to the audit log.`,
        confirmLabel: user.isPremium ? text.removePremium : text.makePremium,
        errorMessage: text.errorLoadingUsers,
        action: () => (user.isPremium ? revokePremium(user.userId) : setPremium(user.userId, true)),
      });
    },
    [
      getUserLabel,
      locale,
      requestUserConfirmation,
      text.errorLoadingUsers,
      text.makePremium,
      text.removePremium,
      ui.confirmPremiumTitle,
      canManageRoles,
    ]
  );

  const requestRoleChange = useCallback(
    (user: UserListItem, role: "Admin" | "Moderator") => {
      if (!canManageRoles) {
        return;
      }

      const hasRole = user.roles.includes(role);
      if (role === "Admin" && hasRole && (totalAdminCount === null || totalAdminCount <= 1)) {
        return;
      }

      const userLabel = getUserLabel(user);
      requestUserConfirmation({
        userId: user.userId,
        title: ui.confirmRoleTitle,
        description:
          locale === "ru"
            ? `${userLabel}: ${hasRole ? "роль будет снята" : "роль будет назначена"} (${role}).`
            : `${userLabel}: the ${role} role will be ${hasRole ? "revoked" : "assigned"}.`,
        confirmLabel:
          role === "Admin"
            ? hasRole
              ? text.revokeAdmin
              : text.assignAdmin
            : hasRole
              ? text.revokeModerator
              : text.assignModerator,
        errorMessage: text.errorLoadingUsers,
        action: () =>
          hasRole ? revokeRole(user.userId, role) : assignRole(user.userId, role),
      });
    },
    [
      getUserLabel,
      locale,
      requestUserConfirmation,
      text.assignAdmin,
      text.assignModerator,
      text.errorLoadingUsers,
      text.revokeAdmin,
      text.revokeModerator,
      totalAdminCount,
      ui.confirmRoleTitle,
      canManageRoles,
    ]
  );

  const submitWalletDialog = useCallback(async () => {
    if (!canManageRoles || !walletDialog || walletDialogSubmitting) {
      return;
    }

    const amount = Number.parseInt(walletDialog.amount.trim(), 10);
    if (!Number.isFinite(amount) || amount <= 0) {
      setWalletDialog((current) =>
        current ? { ...current, error: text.usersBalanceInvalidAmount } : current
      );
      return;
    }

    const reason = walletDialog.reason.trim().slice(0, USER_WALLET_REASON_MAX_LENGTH);
    if (!reason) {
      setWalletDialog((current) =>
        current ? { ...current, error: ui.walletReasonRequired } : current
      );
      return;
    }

    setWalletDialogSubmitting(true);
    try {
      const succeeded = await runUserAction(
        walletDialog.userId,
        async () => {
          await adjustAdminUserWallet(walletDialog.userId, walletDialog.operation, amount, reason);
        },
        {
          successMessage: text.walletOperationSaved,
          errorMessage: text.walletOperationError,
        }
      );
      if (succeeded) {
        setWalletDialog(null);
      }
    } finally {
      setWalletDialogSubmitting(false);
    }
  }, [
    runUserAction,
    text.usersBalanceInvalidAmount,
    text.walletOperationError,
    text.walletOperationSaved,
    ui.walletReasonRequired,
    canManageRoles,
    walletDialog,
    walletDialogSubmitting,
  ]);

  const pageUsers = users;

  const analyticsQueries = useQueries({
    queries: pageUsers.map((user) => ({
      queryKey: adminQueryKeys.userAnalytics(user.userId),
      queryFn: ({ signal }) => fetchAdminUserAnalytics(user.userId, signal),
      enabled: hasSession,
      staleTime: 30_000,
    })),
  });

  const analyticsByUserId = useMemo(() => {
    const map = new Map<string, Awaited<ReturnType<typeof fetchAdminUserAnalytics>>>();
    for (const [index, user] of pageUsers.entries()) {
      const analytics = analyticsQueries[index]?.data;
      if (analytics) {
        map.set(user.userId, analytics);
      }
    }
    return map;
  }, [analyticsQueries, pageUsers]);

  const currentPage = Math.max(1, Math.floor(usersPage.skip / PAGE_SIZE) + 1);
  const totalPages = Math.max(1, Math.ceil(usersPage.totalCount / PAGE_SIZE));
  const pagedUsers = pageUsers;

  const pageSubscriptionQueries = useQueries({
    queries: pagedUsers.map((user) => ({
      queryKey: adminQueryKeys.economyUserSubscriptionSummary(user.userId),
      queryFn: ({ signal }) => fetchAdminEconomyUserSubscriptionSummary(user.userId, signal),
      enabled: hasSession && user.isPremium,
      staleTime: 45_000,
    })),
  });

  const pageSubscriptionsByUserId = useMemo(() => {
    const map = new Map<
      string,
      Awaited<ReturnType<typeof fetchAdminEconomyUserSubscriptionSummary>>
    >();
    for (const [index, user] of pagedUsers.entries()) {
      const data = pageSubscriptionQueries[index]?.data;
      if (data) {
        map.set(user.userId, data);
      }
    }
    return map;
  }, [pageSubscriptionQueries, pagedUsers]);

  const supportTickets = useMemo(
    () => supportInboxQuery.data?.items ?? [],
    [supportInboxQuery.data]
  );
  const openSupportUserCount = useMemo(() => {
    const unique = new Set(
      supportTickets
        .filter((ticket) => ticket.status !== "Closed")
        .map((ticket) => ticket.initiatorUserId)
    );
    return unique.size;
  }, [supportTickets]);

  const totalUsersValue = formatMetricCount(userMetrics?.totalUsers);
  const activeUsersValue = formatMetricCount(userMetrics?.activeUsers);
  const premiumUsersValue = formatMetricCount(userMetrics?.premiumUsers);
  const blockedUsersValue = formatMetricCount(userMetrics?.blockedUsers);
  const newUsersValue = formatMetricCount(getNewUsersCountForRange(userMetrics, rangeDays));

  const selectedListUser =
    selectedUserId === null
      ? null
      : (users.find((candidate) => candidate.userId === selectedUserId) ?? null);

  const selectedUser = selectedUserProfile.user ?? selectedListUser;
  const selectedUserAnalytics = selectedUserProfile.analytics;
  const openActionsUser =
    openActionsUserId === null
      ? null
      : (users.find((candidate) => candidate.userId === openActionsUserId) ?? null);
  const cannotRevokeLastAdmin =
    Boolean(openActionsUser?.roles.includes("Admin")) &&
    (totalAdminCount === null || totalAdminCount <= 1);
  const selectedUserSupportTickets = useMemo(
    () =>
      selectedUserId
        ? supportTickets.filter((ticket) => ticket.initiatorUserId === selectedUserId)
        : [],
    [selectedUserId, supportTickets]
  );

  const updateActionsMenuPosition = useCallback(
    (userId: string) => {
      const trigger = triggerRefs.current[userId];
      if (!trigger) {
        closeActionsMenu();
        return;
      }

      const triggerRect = trigger.getBoundingClientRect();
      const gap = 6;
      const viewportPadding = 8;
      const minWidth = 250;
      const estimatedHeight = canManageRoles ? 356 : 252;
      const availableBelow = window.innerHeight - triggerRect.bottom - gap;
      const availableAbove = triggerRect.top - gap;
      const openUpward = availableBelow < estimatedHeight && availableAbove > availableBelow;
      const top = openUpward ? triggerRect.top - gap : triggerRect.bottom + gap;

      let left = triggerRect.right - minWidth;
      left = Math.max(viewportPadding, left);
      left = Math.min(left, window.innerWidth - minWidth - viewportPadding);

      setActionsMenuPosition({ top, left, minWidth, openUpward });
    },
    [canManageRoles, closeActionsMenu]
  );

  const handleToggleActionsMenu = useCallback(
    (userId: string) => {
      if (openActionsUserId === userId) {
        closeActionsMenu();
        return;
      }

      setOpenActionsUserId(userId);
      requestAnimationFrame(() => {
        updateActionsMenuPosition(userId);
      });
    },
    [closeActionsMenu, openActionsUserId, updateActionsMenuPosition]
  );

  useEffect(() => {
    if (!openActionsUserId) {
      return;
    }

    const handlePointerDown = (event: PointerEvent) => {
      const target = event.target;
      if (!(target instanceof Node)) {
        return;
      }

      if (menuRootRef.current?.contains(target)) {
        return;
      }

      if (triggerRefs.current[openActionsUserId]?.contains(target)) {
        return;
      }

      closeActionsMenu();
    };

    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === "Escape") {
        closeActionsMenu();
      }
    };

    document.addEventListener("pointerdown", handlePointerDown, true);
    document.addEventListener("keydown", handleKeyDown);

    return () => {
      document.removeEventListener("pointerdown", handlePointerDown, true);
      document.removeEventListener("keydown", handleKeyDown);
    };
  }, [closeActionsMenu, openActionsUserId]);

  useEffect(() => {
    if (!openActionsUserId) {
      return;
    }

    const handleViewportChange = () => {
      updateActionsMenuPosition(openActionsUserId);
    };

    window.addEventListener("resize", handleViewportChange);
    window.addEventListener("scroll", handleViewportChange, true);

    return () => {
      window.removeEventListener("resize", handleViewportChange);
      window.removeEventListener("scroll", handleViewportChange, true);
    };
  }, [openActionsUserId, updateActionsMenuPosition]);

  useEffect(() => {
    if (!selectedUserId) {
      return;
    }

    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === "Escape") {
        setSelectedUserId(null);
      }
    };

    document.addEventListener("keydown", handleKeyDown);
    return () => {
      document.removeEventListener("keydown", handleKeyDown);
    };
  }, [selectedUserId]);

  const hero = (
    <AdminPageHero
      eyebrow={text.usersHeroEyebrow}
      title={text.usersTitle}
      description={text.usersHeroDescription}
    />
  );

  if (isLoading) {
    return (
      <AdminPage className={styles.page}>
        {hero}
        <AdminStateCard
          tone="info"
          title={text.usersTitle}
          description={text.usersLoadingDescription}
        >
          <div className={styles.skeletonStack} aria-busy="true" aria-live="polite">
            {Array.from({ length: 8 }).map((_, index) => (
              <div key={index} className={styles.skeletonLine} />
            ))}
          </div>
        </AdminStateCard>
      </AdminPage>
    );
  }

  return (
    <AdminPage className={styles.page}>
      {hero}

      <AdminPageGrid columns="four" className={styles.summaryGrid}>
        <AdminKpiCard label={ui.summaryTotal} value={totalUsersValue} tone="primary" />
        <AdminKpiCard label={ui.summaryActive} value={activeUsersValue} tone="success" />
        <AdminKpiCard label={ui.summaryPremium} value={premiumUsersValue} tone="warning" />
        <AdminKpiCard label={ui.summaryBlocked} value={blockedUsersValue} tone="danger" />
        <AdminKpiCard
          label={ui.summaryNew}
          value={newUsersValue}
          hint={`${ui.periodLabel}: ${rangeDays}`}
          tone="info"
        />
        <AdminKpiCard
          label={ui.summaryOpenSupport}
          value={String(openSupportUserCount)}
          tone="magenta"
        />
      </AdminPageGrid>

      <AdminCard title={text.usersTitle} description={text.usersCardDescription}>
        <div className={styles.filtersBar}>
          <input
            className={styles.searchInput}
            placeholder={ui.searchPlaceholder}
            value={search}
            onChange={(event) => {
              setSearch(event.target.value.slice(0, USER_SEARCH_MAX_LENGTH));
              setPage(1);
            }}
            maxLength={USER_SEARCH_MAX_LENGTH}
          />

          <select
            className={styles.filterSelect}
            value={roleFilter}
            onChange={(event) => {
              setRoleFilter(event.target.value as RoleFilter);
              setPage(1);
            }}
            aria-label={ui.filterRole}
          >
            <option value="all">
              {ui.filterRole}: {ui.any}
            </option>
            <option value="User">{getUserRoleLabel("User", text)}</option>
            <option value="Moderator">{getUserRoleLabel("Moderator", text)}</option>
            <option value="Admin">{getUserRoleLabel("Admin", text)}</option>
          </select>

          <select
            className={styles.filterSelect}
            value={premiumFilter}
            onChange={(event) => {
              setPremiumFilter(event.target.value as PremiumFilter);
              setPage(1);
            }}
            aria-label={ui.filterPremium}
          >
            <option value="all">
              {ui.filterPremium}: {ui.any}
            </option>
            <option value="premium">{ui.premiumOnly}</option>
            <option value="free">{ui.freeOnly}</option>
          </select>

          <select
            className={styles.filterSelect}
            value={activityFilter}
            onChange={(event) => {
              setActivityFilter(event.target.value as ActivityFilter);
              setPage(1);
            }}
            aria-label={ui.filterActivity}
          >
            <option value="all">
              {ui.filterActivity}: {ui.any}
            </option>
            <option value="active">{ui.activeOnly}</option>
            <option value="blocked">{ui.blockedOnly}</option>
          </select>

          <select
            className={styles.filterSelect}
            value={statusFilter}
            onChange={(event) => {
              setStatusFilter(event.target.value as StatusFilter);
              setPage(1);
            }}
            aria-label={ui.filterStatus}
          >
            <option value="all">
              {ui.filterStatus}: {ui.any}
            </option>
            <option value="active">{ui.statusActive}</option>
            <option value="blocked">{ui.statusBlocked}</option>
            <option value="unconfirmed">{ui.statusUnconfirmed}</option>
          </select>

          <select
            className={styles.filterSelect}
            value={String(rangeDays)}
            onChange={(event) => {
              setRangeDays(Number.parseInt(event.target.value, 10) as RangeDays);
              setPage(1);
            }}
            aria-label={ui.periodLabel}
          >
            <option value="7">{ui.period7}</option>
            <option value="30">{ui.period30}</option>
            <option value="90">{ui.period90}</option>
          </select>

          <Button
            variant="ghost"
            size="sm"
            onClick={() => {
              setSearch("");
              setRoleFilter("all");
              setPremiumFilter("all");
              setActivityFilter("all");
              setStatusFilter("all");
              setPage(1);
            }}
          >
            {ui.resetFilters}
          </Button>
        </div>

        {error ? (
          <AdminStateCard
            tone="danger"
            className={styles.message}
            title={error}
            action={
              <Button
                variant="secondary"
                size="sm"
                disabled={isUsersFetching}
                onClick={() => void refreshUsers().catch(() => undefined)}
              >
                {text.supportRetryAction}
              </Button>
            }
          />
        ) : null}

        {!pageUsers.length ? (
          <AdminStateCard
            tone="info"
            className={styles.emptyState}
            title={text.noUsers}
            description={ui.noSearchResults}
          />
        ) : null}

        {!!pageUsers.length && (
          <>
            <div
              className={`${adminTableStyles.tableWrap} ${styles.tableWrap}`}
              aria-busy={isUsersFetching ? "true" : undefined}
            >
              <table className={adminTableStyles.table}>
                <thead>
                  <tr>
                    <th>{text.avatarLabel}</th>
                    <th>{text.emailLabel}</th>
                    <th>userId</th>
                    <th>{text.roleLabel}</th>
                    <th>{ui.accountStatus}</th>
                    <th>{ui.premiumAndExpiry}</th>
                    <th>{ui.balance}</th>
                    <th>{ui.registeredAt}</th>
                    <th>{ui.lastActivity}</th>
                    <th>{ui.quickActions}</th>
                  </tr>
                </thead>
                <tbody>
                  {pagedUsers.map((user) => {
                    const isBusy = busyUserId === user.userId || isUserActionLocked;
                    const status = getAccountStatus(user);
                    const rowAnalytics = analyticsByUserId.get(user.userId);
                    const rowSubscription = pageSubscriptionsByUserId.get(user.userId);

                    return (
                      <tr key={user.userId}>
                        <td data-label={text.avatarLabel}>
                          <UserAvatarView
                            avatar={user.avatar}
                            label={`${text.avatarLabel}: ${getUserAvatarLabel(user)}`}
                            fallbackLabel={getUserAvatarLabel(user)}
                          />
                        </td>
                        <td data-label={text.emailLabel}>
                          <div className={styles.emailCell}>
                            <Link
                              href={`/${locale}/users/${encodeURIComponent(user.userId)}`}
                              className={`${styles.userAnchor} ${styles.userAnchorActive}`}
                            >
                              <span>{maskEmail(user.email)}</span>
                            </Link>
                            <span className={styles.userMeta}>
                              {sanitizeSensitiveText(user.displayName, 96)}
                            </span>
                          </div>
                        </td>
                        <td data-label="userId" className={adminTableStyles.mono}>
                          {shortIdentifier(user.userId)}
                        </td>
                        <td data-label={text.roleLabel}>
                          <div className={styles.roleList}>
                            {user.roles.map((role) => (
                              <AdminBadge
                                key={role}
                                tone={getUserRoleTone(role)}
                                className={styles.rolePill}
                              >
                                {getUserRoleLabel(role, text)}
                              </AdminBadge>
                            ))}
                          </div>
                        </td>
                        <td data-label={ui.accountStatus}>
                          {status === "blocked" ? (
                            <AdminStatusBadge color="#f87171">{ui.blockedBadge}</AdminStatusBadge>
                          ) : status === "unconfirmed" ? (
                            <AdminStatusBadge color="#f59e0b">
                              {ui.unconfirmedBadge}
                            </AdminStatusBadge>
                          ) : (
                            <AdminStatusBadge color="#2dd4bf">{ui.activeBadge}</AdminStatusBadge>
                          )}
                        </td>
                        <td data-label={ui.premiumAndExpiry}>
                          <div className={styles.stackCell}>
                            <AdminStatusBadge color={user.isPremium ? "#22c55e" : "#8da1ba"}>
                              {user.isPremium ? text.yesLabel : text.noLabel}
                            </AdminStatusBadge>
                            <span className={styles.userMeta}>
                              {user.isPremium
                                ? `${ui.premiumEnd}: ${formatDateTime(
                                    rowSubscription?.currentPeriodEndUtc ?? null,
                                    locale
                                  )}`
                                : ui.premiumEndUnknown}
                            </span>
                          </div>
                        </td>
                        <td data-label={ui.balance} className={styles.numericCell}>
                          {rowAnalytics ? rowAnalytics.summary.walletBalance : "—"}
                        </td>
                        <td data-label={ui.registeredAt}>
                          {formatDateTime(user.createdAtUtc, locale)}
                        </td>
                        <td data-label={ui.lastActivity}>
                          {formatDateTime(rowAnalytics?.summary.lastActivityAtUtc ?? null, locale)}
                        </td>
                        <td data-label={ui.quickActions} className={styles.actionsCell}>
                          <div className={styles.actions}>
                            <button
                              type="button"
                              className={styles.quickActionBtn}
                              onClick={() => {
                                closeActionsMenu();
                                setSelectedUserId(user.userId);
                              }}
                            >
                              {ui.openSideCard}
                            </button>
                            {canManageRoles ? (
                              <>
                                <button
                                  type="button"
                                  className={styles.quickActionBtn}
                                  disabled={isBusy}
                                  onClick={() => requestPremiumChange(user)}
                                >
                                  {user.isPremium ? text.removePremium : text.makePremium}
                                </button>
                                <button
                                  type="button"
                                  className={styles.quickActionBtn}
                                  disabled={isBusy}
                                  onClick={() => openWalletDialog(user.userId, "credit")}
                                >
                                  {ui.quickCredit}
                                </button>
                                <button
                                  type="button"
                                  className={styles.quickActionBtn}
                                  disabled={isBusy}
                                  onClick={() => openWalletDialog(user.userId, "debit")}
                                >
                                  {ui.quickDebit}
                                </button>
                                <button
                                  type="button"
                                  className={styles.quickActionBtn}
                                  disabled={isBusy}
                                  onClick={() => requestActiveChange(user)}
                                >
                                  {user.isActive ? text.deactivate : text.activate}
                                </button>
                              </>
                            ) : null}
                            <button
                              type="button"
                              className={styles.actionMenuTrigger}
                              data-menu-open={openActionsUserId === user.userId ? "true" : "false"}
                              aria-label={ui.menuLabel}
                              aria-haspopup="menu"
                              aria-expanded={openActionsUserId === user.userId}
                              disabled={isUserActionLocked}
                              ref={(node) => {
                                triggerRefs.current[user.userId] = node;
                              }}
                              onClick={() => handleToggleActionsMenu(user.userId)}
                            >
                              <MoreHorizontalIcon className={styles.buttonIcon} />
                            </button>
                          </div>
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>

            <div className={styles.pagination}>
              <div>
                {ui.usersCount}: {usersPage.totalCount}
              </div>
              <div className={styles.paginationControls}>
                <Button
                  variant="ghost"
                  size="sm"
                  onClick={() => setPage((current) => Math.max(1, current - 1))}
                  disabled={currentPage <= 1 || isUsersFetching}
                >
                  {ui.prevPage}
                </Button>
                <span>
                  {ui.pageInfo} {currentPage} / {totalPages}
                </span>
                <Button
                  variant="ghost"
                  size="sm"
                  onClick={() => setPage((current) => Math.min(totalPages, current + 1))}
                  disabled={currentPage >= totalPages || isUsersFetching}
                >
                  {ui.nextPage}
                </Button>
              </div>
            </div>
          </>
        )}
      </AdminCard>

      {openActionsUser && actionsMenuPosition && typeof window !== "undefined"
        ? createPortal(
            <div
              ref={menuRootRef}
              className={styles.actionMenuPortal}
              style={{
                top: actionsMenuPosition.top,
                left: actionsMenuPosition.left,
                minWidth: actionsMenuPosition.minWidth,
                transform: actionsMenuPosition.openUpward ? "translateY(-100%)" : undefined,
              }}
              role="menu"
              aria-label={ui.menuLabel}
            >
              <div
                className={`${styles.actionMenuList} ${actionsMenuPosition.openUpward ? styles.actionMenuListUpward : ""}`}
              >
                <button
                  type="button"
                  className={styles.actionMenuItem}
                  disabled={isUserActionLocked || busyUserId === openActionsUser.userId}
                  onClick={() => {
                    closeActionsMenu();
                    setSelectedUserId(openActionsUser.userId);
                  }}
                >
                  <UsersIcon className={styles.buttonIcon} />
                  <span>{ui.openCard}</span>
                </button>
                {canManageRoles && (
                  <>
                    <button
                      type="button"
                      className={styles.actionMenuItem}
                      disabled={isUserActionLocked || busyUserId === openActionsUser.userId}
                      onClick={() => {
                        openWalletDialog(openActionsUser.userId, "credit");
                      }}
                    >
                      <DollarIcon className={styles.buttonIcon} />
                      <span>{text.usersBalanceCredit}</span>
                    </button>
                    <button
                      type="button"
                      className={styles.actionMenuItem}
                      disabled={isUserActionLocked || busyUserId === openActionsUser.userId}
                      onClick={() => {
                        openWalletDialog(openActionsUser.userId, "debit");
                      }}
                    >
                      <DollarIcon className={styles.buttonIcon} />
                      <span>{text.usersBalanceDebit}</span>
                    </button>
                    <button
                      type="button"
                      className={styles.actionMenuItem}
                      disabled={isUserActionLocked || busyUserId === openActionsUser.userId}
                      onClick={() => {
                        requestRoleChange(openActionsUser, "Moderator");
                      }}
                    >
                      <UsersIcon className={styles.buttonIcon} />
                      <span>
                        {openActionsUser.roles.includes("Moderator")
                          ? text.revokeModerator
                          : text.assignModerator}
                      </span>
                    </button>
                    <button
                      type="button"
                      className={styles.actionMenuItem}
                      disabled={
                        isUserActionLocked ||
                        busyUserId === openActionsUser.userId ||
                        cannotRevokeLastAdmin
                      }
                      title={cannotRevokeLastAdmin ? ui.lastAdminProtected : undefined}
                      onClick={() => {
                        requestRoleChange(openActionsUser, "Admin");
                      }}
                    >
                      <UsersIcon className={styles.buttonIcon} />
                      <span>
                        {openActionsUser.roles.includes("Admin")
                          ? text.revokeAdmin
                          : text.assignAdmin}
                      </span>
                    </button>
                    <button
                      type="button"
                      className={`${styles.actionMenuItem} ${styles.actionMenuItemDanger}`}
                      disabled={isUserActionLocked || busyUserId === openActionsUser.userId}
                      onClick={() => {
                        requestDeleteUser(openActionsUser);
                      }}
                    >
                      <CancelCircleIcon className={styles.buttonIcon} />
                      <span>{text.usersDeleteAction}</span>
                    </button>
                  </>
                )}
                <Link
                  href={`/${locale}/users/${encodeURIComponent(openActionsUser.userId)}`}
                  className={styles.actionMenuLink}
                  onClick={closeActionsMenu}
                >
                  <span>{ui.openCard}</span>
                </Link>
              </div>
            </div>,
            document.body
          )
        : null}

      <ConfirmationDialog
        open={confirmationDialog !== null}
        title={confirmationDialog?.title ?? ""}
        description={confirmationDialog?.description ?? ""}
        confirmLabel={confirmationDialog?.confirmLabel ?? ui.confirmAction}
        cancelLabel={ui.confirmCancel}
        isSubmitting={confirmationSubmitting}
        tone={confirmationDialog?.tone ?? "danger"}
        onCancel={closeConfirmationDialog}
        onConfirm={() => {
          void submitConfirmationDialog();
        }}
      />

      {walletDialog && typeof window !== "undefined"
        ? createPortal(
            <div className={styles.walletDialogBackdrop} onClick={closeWalletDialog}>
              <div
                className={styles.walletDialog}
                role="dialog"
                aria-modal="true"
                aria-label={
                  walletDialog.operation === "credit"
                    ? ui.walletDialogTitleCredit
                    : ui.walletDialogTitleDebit
                }
                onClick={(event) => event.stopPropagation()}
              >
                <h3 className={styles.walletDialogTitle}>
                  {walletDialog.operation === "credit"
                    ? ui.walletDialogTitleCredit
                    : ui.walletDialogTitleDebit}
                </h3>
                <label className={styles.walletField}>
                  <span>{ui.walletAmountLabel}</span>
                  <input
                    className={styles.walletInput}
                    inputMode="numeric"
                    value={walletDialog.amount}
                    onChange={(event) =>
                      setWalletDialog((current) =>
                        current
                          ? {
                              ...current,
                              amount: event.target.value.replace(/\D+/g, "").slice(0, 8),
                              error: null,
                            }
                          : current
                      )
                    }
                    autoFocus
                    maxLength={8}
                    disabled={walletDialogSubmitting}
                  />
                </label>
                <label className={styles.walletField}>
                  <span>{ui.walletReasonLabel}</span>
                  <textarea
                    className={styles.walletTextarea}
                    value={walletDialog.reason}
                    onChange={(event) =>
                      setWalletDialog((current) =>
                        current
                          ? {
                              ...current,
                              reason: event.target.value.slice(0, USER_WALLET_REASON_MAX_LENGTH),
                              error: null,
                            }
                          : current
                      )
                    }
                    rows={3}
                    maxLength={USER_WALLET_REASON_MAX_LENGTH}
                    disabled={walletDialogSubmitting}
                  />
                </label>
                {walletDialog.error ? (
                  <p className={styles.walletError}>{walletDialog.error}</p>
                ) : null}
                <div className={styles.walletActions}>
                  <Button
                    variant="ghost"
                    size="sm"
                    onClick={closeWalletDialog}
                    disabled={walletDialogSubmitting}
                  >
                    {ui.walletCancel}
                  </Button>
                  <Button
                    variant="secondary"
                    size="sm"
                    onClick={() => {
                      void submitWalletDialog();
                    }}
                    disabled={
                      walletDialogSubmitting ||
                      !walletDialog.amount.trim() ||
                      !walletDialog.reason.trim()
                    }
                  >
                    {ui.walletSubmit}
                  </Button>
                </div>
              </div>
            </div>,
            document.body
          )
        : null}

      {selectedUserId && typeof window !== "undefined"
        ? createPortal(
            <div className={styles.sidePanelBackdrop} onClick={() => setSelectedUserId(null)}>
              <aside
                className={styles.sidePanel}
                role="dialog"
                aria-modal="true"
                aria-label={ui.sideTitle}
                onClick={(event) => event.stopPropagation()}
              >
                <header className={styles.sidePanelHeader}>
                  <div>
                    <h3>{ui.sideTitle}</h3>
                    <p>{ui.sideDescription}</p>
                  </div>
                  <button
                    type="button"
                    className={styles.closeBtn}
                    onClick={() => setSelectedUserId(null)}
                  >
                    {ui.closePanel}
                  </button>
                </header>

                {!selectedUser ? (
                  <AdminStateCard tone="info" title={text.loading} />
                ) : (
                  <div className={styles.sidePanelContent}>
                    <section className={styles.panelSection}>
                      <h4>{ui.sectionProfile}</h4>
                      <div className={styles.profileRow}>
                        <UserAvatarView
                          avatar={selectedUser.avatar}
                          label={`${text.avatarLabel}: ${getUserAvatarLabel(selectedUser)}`}
                          fallbackLabel={getUserAvatarLabel(selectedUser)}
                          size="lg"
                        />
                        <div>
                          <p className={styles.profileTitle}>
                            {sanitizeSensitiveText(getAdminUserDisplayName(selectedUser), 96)}
                          </p>
                          <p className={styles.profileSub}>{maskEmail(selectedUser.email)}</p>
                          <p className={styles.profileSub}>{shortIdentifier(selectedUser.userId)}</p>
                        </div>
                      </div>
                      <div className={styles.badgeRow}>
                        <AdminBadge tone={selectedUser.isActive ? "success" : "danger"}>
                          {selectedUser.isActive ? ui.activeBadge : ui.blockedBadge}
                        </AdminBadge>
                        <AdminBadge tone={selectedUser.isPremium ? "warning" : "neutral"}>
                          {selectedUser.isPremium ? text.premiumLabel : text.freeLabel}
                        </AdminBadge>
                        <AdminBadge tone={selectedUser.emailConfirmed ? "info" : "neutral"}>
                          {selectedUser.emailConfirmed
                            ? text.emailConfirmedLabel
                            : ui.unconfirmedBadge}
                        </AdminBadge>
                      </div>
                    </section>

                    <section className={styles.panelSection}>
                      <h4>{ui.sectionPremium}</h4>
                      <p>
                        {selectedSubscriptionQuery.data
                          ? `${sanitizeSensitiveText(
                              selectedSubscriptionQuery.data.status,
                              48
                            )} • ${formatDateTime(
                              selectedSubscriptionQuery.data.currentPeriodEndUtc,
                              locale
                            )}`
                          : ui.noData}
                      </p>
                    </section>

                    <section className={styles.panelSection}>
                      <h4>{ui.sectionBalance}</h4>
                      <p>
                        {selectedUserAnalytics
                          ? `${selectedUserAnalytics.summary.walletBalance} • ${text.tokensGrantedLabel}: ${selectedUserAnalytics.summary.totalTokensCredited}`
                          : ui.noData}
                      </p>
                    </section>

                    <section className={styles.panelSection}>
                      <h4>{ui.sectionRoles}</h4>
                      <div className={styles.badgeRow}>
                        {selectedUser.roles.map((role) => (
                          <AdminBadge key={role} tone={getUserRoleTone(role)}>
                            {getUserRoleLabel(role, text)}
                          </AdminBadge>
                        ))}
                      </div>
                    </section>

                    <section className={styles.panelSection}>
                      <h4>{ui.sectionSupport}</h4>
                      {selectedUserSupportTickets.length ? (
                        <div className={styles.listBlock}>
                          {selectedUserSupportTickets.slice(0, 6).map((ticket) => (
                            <article key={ticket.conversationId} className={styles.listCard}>
                              <strong>{sanitizeSensitiveText(ticket.status, 48)}</strong>
                              <span>{formatDateTime(ticket.updatedAtUtc, locale)}</span>
                              <span>{formatSupportMessagePreview(ticket.lastMessagePreview, "—")}</span>
                            </article>
                          ))}
                        </div>
                      ) : (
                        <p>{ui.noData}</p>
                      )}
                    </section>

                    <section className={styles.panelSection}>
                      <h4>{ui.sectionPurchases}</h4>
                      {selectedUserAnalytics?.recentPurchases.length ? (
                        <div className={styles.listBlock}>
                          {selectedUserAnalytics.recentPurchases.slice(0, 5).map((purchase) => (
                            <article key={purchase.orderId} className={styles.listCard}>
                              <strong>{purchase.sparkToGrant} spark</strong>
                              <span>
                                {purchase.priceAmount} {sanitizeSensitiveText(purchase.currencyCode, 12)}
                              </span>
                              <span>
                                {formatDateTime(
                                  purchase.confirmedAtUtc ?? purchase.createdAtUtc,
                                  locale
                                )}
                              </span>
                            </article>
                          ))}
                        </div>
                      ) : (
                        <p>{ui.noData}</p>
                      )}
                    </section>

                    <section className={styles.panelSection}>
                      <h4>{ui.sectionGenerations}</h4>
                      {selectedUserAnalytics?.recentGenerations.length ? (
                        <div className={styles.listBlock}>
                          {selectedUserAnalytics.recentGenerations.slice(0, 5).map((generation) => (
                            <article key={generation.generationId} className={styles.listCard}>
                              <strong>{sanitizeSensitiveText(generation.templateTitle, 120)}</strong>
                              <span>{sanitizeSensitiveText(generation.status, 48)}</span>
                              <span>
                                {formatDateTime(
                                  generation.completedAtUtc ?? generation.createdAtUtc,
                                  locale
                                )}
                              </span>
                            </article>
                          ))}
                        </div>
                      ) : (
                        <p>{ui.noData}</p>
                      )}
                    </section>

                    <section className={styles.panelSection}>
                      <h4>{ui.sectionAudit}</h4>
                      {selectedUserAnalytics?.recentAuditEvents.length ? (
                        <div className={styles.listBlock}>
                          {selectedUserAnalytics.recentAuditEvents.slice(0, 6).map((event) => (
                            <article key={event.auditEventId} className={styles.listCard}>
                              <strong>{sanitizeSensitiveText(event.action, 120)}</strong>
                              <span>{formatDateTime(event.occurredAtUtc, locale)}</span>
                              <span>{sanitizeSensitiveText(event.details, 180)}</span>
                            </article>
                          ))}
                        </div>
                      ) : (
                        <p>{ui.noData}</p>
                      )}
                    </section>

                    {canManageRoles ? (
                      <section className={`${styles.panelSection} ${styles.dangerZone}`}>
                        <h4>{ui.sectionDanger}</h4>
                        <div className={styles.dangerActions}>
                          <button
                            type="button"
                            className={styles.dangerBtn}
                            disabled={isUserActionLocked || busyUserId === selectedUser.userId}
                            onClick={() => requestActiveChange(selectedUser)}
                          >
                            {selectedUser.isActive ? text.deactivate : text.activate}
                          </button>
                          <button
                            type="button"
                            className={styles.dangerBtn}
                            disabled={isUserActionLocked || busyUserId === selectedUser.userId}
                            onClick={() =>
                              requestDeleteUser(selectedUser, () => setSelectedUserId(null))
                            }
                          >
                            {text.usersDeleteAction}
                          </button>
                          <Link
                            href={`/${locale}/users/${encodeURIComponent(selectedUser.userId)}`}
                            className={styles.profileLinkBtn}
                          >
                            {ui.sideOpenFullProfile}
                          </Link>
                        </div>
                      </section>
                    ) : null}
                  </div>
                )}
              </aside>
            </div>,
            document.body
          )
        : null}

      {toast ? <Toast message={toast.message} type={toast.type} /> : null}
    </AdminPage>
  );
}
