"use client";

import { useQueries, useQuery } from "@tanstack/react-query";
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
import { Button } from "@/components/ui/button";
import { Toast } from "@/components/ui/toast";
import styles from "@/components/users-management-page.module.css";
import { useAdminUserProfile } from "@/components/users/use-admin-user-profile";
import { useUsersAdmin } from "@/components/users/use-users-admin";
import { UserAvatarView } from "@/components/users/user-avatar";
import { adminQueryKeys } from "@/lib/admin-query-keys";
import {
  adjustAdminUserWallet,
  assignRole,
  deleteAdminUser,
  fetchAdminEconomyUserSubscriptionSummary,
  fetchAdminUserAnalytics,
  fetchSupportInbox,
  revokePremium,
  revokeRole,
  setActive,
  setPremium,
  type UserListItem,
} from "@/lib/api-client";
import { formatDateTime } from "@/lib/format-date-time";
import { getDictionary, type Dictionary, type Locale } from "@/lib/i18n";

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

type RangeDays = 7 | 30 | 90;

type SortMode = "created-desc" | "created-asc" | "last-activity-desc" | "last-activity-asc";

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
        : role;
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

function normalizeText(value: string): string {
  return value.trim().toLowerCase();
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
            sortLabel: "Сортировка",
            resetFilters: "Сбросить",
            any: "Все",
            premiumOnly: "Только Premium",
            freeOnly: "Без Premium",
            activeOnly: "Только активные",
            blockedOnly: "Только заблокированные",
            statusActive: "Аккаунт активен",
            statusBlocked: "Заблокирован",
            statusUnconfirmed: "Почта не подтверждена",
            sortCreatedDesc: "Регистрация: новые",
            sortCreatedAsc: "Регистрация: старые",
            sortLastActivityDesc: "Последняя активность: свежие",
            sortLastActivityAsc: "Последняя активность: старые",
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
            sortLabel: "Sorting",
            resetFilters: "Reset",
            any: "All",
            premiumOnly: "Premium only",
            freeOnly: "Free only",
            activeOnly: "Active only",
            blockedOnly: "Blocked only",
            statusActive: "Account active",
            statusBlocked: "Blocked",
            statusUnconfirmed: "Email not confirmed",
            sortCreatedDesc: "Registration: newest",
            sortCreatedAsc: "Registration: oldest",
            sortLastActivityDesc: "Last activity: newest",
            sortLastActivityAsc: "Last activity: oldest",
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
          },
    [locale]
  );

  const { busyUserId, canManageRoles, error, isLoading, runAction, toast, users } =
    useUsersAdmin(locale);

  const [search, setSearch] = useState("");
  const [roleFilter, setRoleFilter] = useState<RoleFilter>("all");
  const [premiumFilter, setPremiumFilter] = useState<PremiumFilter>("all");
  const [activityFilter, setActivityFilter] = useState<ActivityFilter>("all");
  const [statusFilter, setStatusFilter] = useState<StatusFilter>("all");
  const [sortMode, setSortMode] = useState<SortMode>("created-desc");
  const [rangeDays, setRangeDays] = useState<RangeDays>(30);
  const [page, setPage] = useState(1);

  const [openActionsUserId, setOpenActionsUserId] = useState<string | null>(null);
  const [actionsMenuPosition, setActionsMenuPosition] = useState<ActionsMenuPosition | null>(null);
  const [selectedUserId, setSelectedUserId] = useState<string | null>(null);
  const [walletDialog, setWalletDialog] = useState<WalletDialogState | null>(null);
  const [walletDialogSubmitting, setWalletDialogSubmitting] = useState(false);

  const menuRootRef = useRef<HTMLDivElement | null>(null);
  const triggerRefs = useRef<Record<string, HTMLButtonElement | null>>({});

  const closeActionsMenu = useCallback(() => {
    setOpenActionsUserId(null);
    setActionsMenuPosition(null);
  }, []);

  const supportInboxQuery = useQuery({
    queryKey: adminQueryKeys.supportInbox("all", "all"),
    queryFn: () => fetchSupportInbox(undefined, "all"),
    enabled: users.length > 0,
  });

  const selectedUserProfile = useAdminUserProfile({ userId: selectedUserId });

  const selectedSubscriptionQuery = useQuery({
    queryKey: selectedUserId
      ? adminQueryKeys.economyUserSubscriptionSummary(selectedUserId)
      : adminQueryKeys.economyUserSubscriptionSummaryDisabled,
    queryFn: () => fetchAdminEconomyUserSubscriptionSummary(selectedUserId!),
    enabled: Boolean(selectedUserId),
  });

  const openWalletDialog = useCallback(
    (userId: string, operation: "credit" | "debit") => {
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
    [text.usersBalanceReasonDefault]
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
      await runAction(userId, action, options);
      if (selectedUserId === userId) {
        await selectedUserProfile.refresh();
      }
    },
    [runAction, selectedUserId, selectedUserProfile]
  );

  const submitWalletDialog = useCallback(async () => {
    if (!walletDialog) {
      return;
    }

    const amount = Number.parseInt(walletDialog.amount.trim(), 10);
    if (!Number.isFinite(amount) || amount <= 0) {
      setWalletDialog((current) =>
        current ? { ...current, error: text.usersBalanceInvalidAmount } : current
      );
      return;
    }

    const reason = walletDialog.reason.trim();
    if (!reason) {
      setWalletDialog((current) =>
        current ? { ...current, error: ui.walletReasonRequired } : current
      );
      return;
    }

    setWalletDialogSubmitting(true);
    await runUserAction(
      walletDialog.userId,
      async () => {
        await adjustAdminUserWallet(walletDialog.userId, walletDialog.operation, amount, reason);
      },
      {
        successMessage: text.walletOperationSaved,
        errorMessage: text.walletOperationError,
      }
    );
    setWalletDialogSubmitting(false);
    setWalletDialog(null);
  }, [
    runUserAction,
    text.usersBalanceInvalidAmount,
    text.walletOperationError,
    text.walletOperationSaved,
    ui.walletReasonRequired,
    walletDialog,
  ]);

  const filteredUsersBase = useMemo(() => {
    const normalizedSearch = normalizeText(search);

    return users.filter((user) => {
      const bySearch =
        normalizedSearch.length === 0 ||
        normalizeText(user.email).includes(normalizedSearch) ||
        normalizeText(user.userId).includes(normalizedSearch);
      if (!bySearch) {
        return false;
      }

      if (roleFilter !== "all" && !user.roles.includes(roleFilter)) {
        return false;
      }

      if (premiumFilter === "premium" && !user.isPremium) {
        return false;
      }

      if (premiumFilter === "free" && user.isPremium) {
        return false;
      }

      if (activityFilter === "active" && !user.isActive) {
        return false;
      }

      if (activityFilter === "blocked" && user.isActive) {
        return false;
      }

      const userStatus = getAccountStatus(user);
      if (statusFilter !== "all" && statusFilter !== userStatus) {
        return false;
      }

      return true;
    });
  }, [activityFilter, premiumFilter, roleFilter, search, statusFilter, users]);

  const preSortedUsers = useMemo(() => {
    if (sortMode === "created-asc") {
      return [...filteredUsersBase].sort(
        (a, b) => new Date(a.createdAtUtc).getTime() - new Date(b.createdAtUtc).getTime()
      );
    }

    if (sortMode === "created-desc") {
      return [...filteredUsersBase].sort(
        (a, b) => new Date(b.createdAtUtc).getTime() - new Date(a.createdAtUtc).getTime()
      );
    }

    return filteredUsersBase;
  }, [filteredUsersBase, sortMode]);

  const sortByLastActivity = sortMode === "last-activity-asc" || sortMode === "last-activity-desc";

  const analyticsTargetUsers = sortByLastActivity
    ? filteredUsersBase
    : preSortedUsers.slice((page - 1) * PAGE_SIZE, page * PAGE_SIZE);

  const analyticsQueries = useQueries({
    queries: analyticsTargetUsers.map((user) => ({
      queryKey: adminQueryKeys.userAnalytics(user.userId),
      queryFn: () => fetchAdminUserAnalytics(user.userId),
      enabled: true,
      staleTime: 30_000,
    })),
  });

  const analyticsByUserId = useMemo(() => {
    const map = new Map<string, Awaited<ReturnType<typeof fetchAdminUserAnalytics>>>();
    for (const [index, user] of analyticsTargetUsers.entries()) {
      const analytics = analyticsQueries[index]?.data;
      if (analytics) {
        map.set(user.userId, analytics);
      }
    }
    return map;
  }, [analyticsQueries, analyticsTargetUsers]);

  const sortedUsers = useMemo(() => {
    if (!sortByLastActivity) {
      return preSortedUsers;
    }

    const direction = sortMode === "last-activity-asc" ? 1 : -1;
    return [...filteredUsersBase].sort((a, b) => {
      const aTime = new Date(
        analyticsByUserId.get(a.userId)?.summary.lastActivityAtUtc ?? 0
      ).getTime();
      const bTime = new Date(
        analyticsByUserId.get(b.userId)?.summary.lastActivityAtUtc ?? 0
      ).getTime();
      return (aTime - bTime) * direction;
    });
  }, [analyticsByUserId, filteredUsersBase, preSortedUsers, sortByLastActivity, sortMode]);

  const totalPages = Math.max(1, Math.ceil(sortedUsers.length / PAGE_SIZE));

  useEffect(() => {
    if (page > totalPages) {
      setPage(totalPages);
    }
  }, [page, totalPages]);

  useEffect(() => {
    setPage(1);
  }, [search, roleFilter, premiumFilter, activityFilter, statusFilter, sortMode]);

  const pagedUsers = useMemo(
    () => sortedUsers.slice((page - 1) * PAGE_SIZE, page * PAGE_SIZE),
    [page, sortedUsers]
  );

  const pageSubscriptionQueries = useQueries({
    queries: pagedUsers.map((user) => ({
      queryKey: adminQueryKeys.economyUserSubscriptionSummary(user.userId),
      queryFn: () => fetchAdminEconomyUserSubscriptionSummary(user.userId),
      enabled: user.isPremium,
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

  const supportTickets = supportInboxQuery.data ?? [];
  const openSupportUserCount = useMemo(() => {
    const unique = new Set(
      supportTickets
        .filter((ticket) => ticket.status !== "Closed")
        .map((ticket) => ticket.initiatorUserId)
    );
    return unique.size;
  }, [supportTickets]);

  const nowTs = Date.now();
  const rangeMs = rangeDays * 24 * 60 * 60 * 1000;
  const newUsersCount = users.filter((user) => {
    const createdTs = new Date(user.createdAtUtc).getTime();
    return Number.isFinite(createdTs) && nowTs - createdTs <= rangeMs;
  }).length;

  const activeCount = users.filter((user) => user.isActive).length;
  const premiumCount = users.filter((user) => user.isPremium).length;
  const blockedCount = users.filter((user) => !user.isActive).length;

  const selectedListUser =
    selectedUserId === null
      ? null
      : (users.find((candidate) => candidate.userId === selectedUserId) ?? null);

  const selectedUser = selectedUserProfile.user ?? selectedListUser;
  const selectedUserAnalytics = selectedUserProfile.analytics;
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

  const openActionsUser =
    openActionsUserId === null
      ? null
      : (users.find((candidate) => candidate.userId === openActionsUserId) ?? null);

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
        <AdminKpiCard label={ui.summaryTotal} value={String(users.length)} tone="primary" />
        <AdminKpiCard label={ui.summaryActive} value={String(activeCount)} tone="success" />
        <AdminKpiCard label={ui.summaryPremium} value={String(premiumCount)} tone="warning" />
        <AdminKpiCard label={ui.summaryBlocked} value={String(blockedCount)} tone="danger" />
        <AdminKpiCard
          label={ui.summaryNew}
          value={String(newUsersCount)}
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
            onChange={(event) => setSearch(event.target.value)}
          />

          <select
            className={styles.filterSelect}
            value={roleFilter}
            onChange={(event) => setRoleFilter(event.target.value as RoleFilter)}
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
            onChange={(event) => setPremiumFilter(event.target.value as PremiumFilter)}
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
            onChange={(event) => setActivityFilter(event.target.value as ActivityFilter)}
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
            onChange={(event) => setStatusFilter(event.target.value as StatusFilter)}
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
            value={sortMode}
            onChange={(event) => setSortMode(event.target.value as SortMode)}
            aria-label={ui.sortLabel}
          >
            <option value="created-desc">{ui.sortCreatedDesc}</option>
            <option value="created-asc">{ui.sortCreatedAsc}</option>
            <option value="last-activity-desc">{ui.sortLastActivityDesc}</option>
            <option value="last-activity-asc">{ui.sortLastActivityAsc}</option>
          </select>

          <select
            className={styles.filterSelect}
            value={String(rangeDays)}
            onChange={(event) => setRangeDays(Number.parseInt(event.target.value, 10) as RangeDays)}
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
              setSortMode("created-desc");
            }}
          >
            {ui.resetFilters}
          </Button>
        </div>

        {error ? <AdminStateCard tone="danger" className={styles.message} title={error} /> : null}

        {!sortedUsers.length ? (
          <AdminStateCard
            tone="info"
            className={styles.emptyState}
            title={text.noUsers}
            description={ui.noSearchResults}
          />
        ) : null}

        {!!sortedUsers.length && (
          <>
            <div className={`${adminTableStyles.tableWrap} ${styles.tableWrap}`}>
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
                    const isBusy = busyUserId === user.userId;
                    const isModerator = user.roles.includes("Moderator");
                    const isAdmin = user.roles.includes("Admin");
                    const status = getAccountStatus(user);
                    const rowAnalytics = analyticsByUserId.get(user.userId);
                    const rowSubscription = pageSubscriptionsByUserId.get(user.userId);

                    return (
                      <tr key={user.userId}>
                        <td data-label={text.avatarLabel}>
                          <UserAvatarView
                            avatar={user.avatar}
                            label={`${text.avatarLabel}: ${user.displayName ?? user.email}`}
                            fallbackLabel={user.displayName ?? user.email}
                          />
                        </td>
                        <td data-label={text.emailLabel}>
                          <div className={styles.emailCell}>
                            <Link
                              href={`/${locale}/users/${user.userId}`}
                              className={`${styles.userAnchor} ${styles.userAnchorActive}`}
                            >
                              <span>{user.email}</span>
                            </Link>
                            <span className={styles.userMeta}>{user.displayName ?? "—"}</span>
                          </div>
                        </td>
                        <td data-label="userId" className={adminTableStyles.mono}>
                          {user.userId}
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
                            <button
                              type="button"
                              className={styles.quickActionBtn}
                              disabled={isBusy}
                              onClick={() =>
                                void runUserAction(user.userId, () =>
                                  user.isPremium
                                    ? revokePremium(user.userId)
                                    : setPremium(user.userId, true)
                                )
                              }
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
                              onClick={() =>
                                void runUserAction(user.userId, () =>
                                  setActive(user.userId, !user.isActive)
                                )
                              }
                            >
                              {user.isActive ? text.deactivate : text.activate}
                            </button>
                            <button
                              type="button"
                              className={styles.actionMenuTrigger}
                              data-menu-open={openActionsUserId === user.userId ? "true" : "false"}
                              aria-label={ui.menuLabel}
                              aria-haspopup="menu"
                              aria-expanded={openActionsUserId === user.userId}
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
                {ui.usersCount}: {sortedUsers.length}
              </div>
              <div className={styles.paginationControls}>
                <Button
                  variant="ghost"
                  size="sm"
                  onClick={() => setPage((current) => Math.max(1, current - 1))}
                  disabled={page <= 1}
                >
                  {ui.prevPage}
                </Button>
                <span>
                  {ui.pageInfo} {page} / {totalPages}
                </span>
                <Button
                  variant="ghost"
                  size="sm"
                  onClick={() => setPage((current) => Math.min(totalPages, current + 1))}
                  disabled={page >= totalPages}
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
                  disabled={busyUserId === openActionsUser.userId}
                  onClick={() => {
                    closeActionsMenu();
                    setSelectedUserId(openActionsUser.userId);
                  }}
                >
                  <UsersIcon className={styles.buttonIcon} />
                  <span>{ui.openCard}</span>
                </button>
                <button
                  type="button"
                  className={styles.actionMenuItem}
                  disabled={busyUserId === openActionsUser.userId}
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
                  disabled={busyUserId === openActionsUser.userId}
                  onClick={() => {
                    openWalletDialog(openActionsUser.userId, "debit");
                  }}
                >
                  <DollarIcon className={styles.buttonIcon} />
                  <span>{text.usersBalanceDebit}</span>
                </button>
                {canManageRoles && (
                  <>
                    <button
                      type="button"
                      className={styles.actionMenuItem}
                      disabled={busyUserId === openActionsUser.userId}
                      onClick={() => {
                        closeActionsMenu();
                        void runUserAction(openActionsUser.userId, () =>
                          openActionsUser.roles.includes("Moderator")
                            ? revokeRole(openActionsUser.userId, "Moderator")
                            : assignRole(openActionsUser.userId, "Moderator")
                        );
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
                      disabled={busyUserId === openActionsUser.userId}
                      onClick={() => {
                        closeActionsMenu();
                        void runUserAction(openActionsUser.userId, () =>
                          openActionsUser.roles.includes("Admin")
                            ? revokeRole(openActionsUser.userId, "Admin")
                            : assignRole(openActionsUser.userId, "Admin")
                        );
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
                      disabled={busyUserId === openActionsUser.userId}
                      onClick={() => {
                        closeActionsMenu();
                        if (!window.confirm(text.usersDeleteConfirm)) {
                          return;
                        }

                        void runUserAction(
                          openActionsUser.userId,
                          () => deleteAdminUser(openActionsUser.userId),
                          {
                            successMessage: text.usersDeletedSuccess,
                            errorMessage: text.errorLoadingUsers,
                          }
                        );
                      }}
                    >
                      <CancelCircleIcon className={styles.buttonIcon} />
                      <span>{text.usersDeleteAction}</span>
                    </button>
                  </>
                )}
                <Link
                  href={`/${locale}/users/${openActionsUser.userId}`}
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
                              amount: event.target.value,
                              error: null,
                            }
                          : current
                      )
                    }
                    autoFocus
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
                              reason: event.target.value,
                              error: null,
                            }
                          : current
                      )
                    }
                    rows={3}
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
                    disabled={walletDialogSubmitting}
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
                          label={`${text.avatarLabel}: ${selectedUser.displayName ?? selectedUser.email}`}
                          fallbackLabel={selectedUser.displayName ?? selectedUser.email}
                          size="lg"
                        />
                        <div>
                          <p className={styles.profileTitle}>
                            {selectedUser.displayName ?? selectedUser.email}
                          </p>
                          <p className={styles.profileSub}>{selectedUser.email}</p>
                          <p className={styles.profileSub}>{selectedUser.userId}</p>
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
                          ? `${selectedSubscriptionQuery.data.status} • ${formatDateTime(
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
                              <strong>{ticket.status}</strong>
                              <span>{formatDateTime(ticket.updatedAtUtc, locale)}</span>
                              <span>{ticket.lastMessagePreview ?? "—"}</span>
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
                                {purchase.priceAmount} {purchase.currencyCode}
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
                              <strong>{generation.templateTitle}</strong>
                              <span>{generation.status}</span>
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
                              <strong>{event.action}</strong>
                              <span>{formatDateTime(event.occurredAtUtc, locale)}</span>
                              <span>{event.details}</span>
                            </article>
                          ))}
                        </div>
                      ) : (
                        <p>{ui.noData}</p>
                      )}
                    </section>

                    <section className={`${styles.panelSection} ${styles.dangerZone}`}>
                      <h4>{ui.sectionDanger}</h4>
                      <div className={styles.dangerActions}>
                        <button
                          type="button"
                          className={styles.dangerBtn}
                          onClick={() =>
                            void runUserAction(selectedUser.userId, () =>
                              setActive(selectedUser.userId, !selectedUser.isActive)
                            )
                          }
                        >
                          {selectedUser.isActive ? text.deactivate : text.activate}
                        </button>
                        <button
                          type="button"
                          className={styles.dangerBtn}
                          onClick={() => {
                            if (!window.confirm(text.usersDeleteConfirm)) {
                              return;
                            }

                            void runUserAction(
                              selectedUser.userId,
                              () => deleteAdminUser(selectedUser.userId),
                              {
                                successMessage: text.usersDeletedSuccess,
                                errorMessage: text.errorLoadingUsers,
                              }
                            );
                            setSelectedUserId(null);
                          }}
                        >
                          {text.usersDeleteAction}
                        </button>
                        <Link
                          href={`/${locale}/users/${selectedUser.userId}`}
                          className={styles.profileLinkBtn}
                        >
                          {ui.sideOpenFullProfile}
                        </Link>
                      </div>
                    </section>
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
