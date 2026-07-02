"use client";

import { keepPreviousData, useQuery } from "@tanstack/react-query";
import { useCallback, useEffect, useId, useMemo, useState } from "react";

import { AdminPage } from "@/components/admin/admin-primitives";
import { useAdminUserProfile } from "@/components/users/use-admin-user-profile";
import { useUsersAdmin } from "@/components/users/use-users-admin";
import { useUsersManagementActionsMenu } from "@/components/users-management-actions-menu";
import { UsersManagementPageOverlays } from "@/components/users-management-page-overlays-composition";
import { UsersManagementPageWorkspace } from "@/components/users-management-page-workspace";
import {
  UsersManagementAccessState,
  UsersManagementHero,
  UsersManagementLoadingState,
} from "@/components/users-management-page.chrome";
import { getUsersManagementPageText } from "@/components/users-management-page.content";
import {
  fetchUserRowEnrichment,
  formatMetricCount,
  getNewUsersCountForRange,
  getUsersPageErrorDetails,
} from "@/components/users-management-page.helpers";
import styles from "@/components/users-management-page.module.css";
import type {
  ActivityFilter,
  ConfirmationDialogState,
  PremiumFilter,
  RangeDays,
  RoleFilter,
  StatusFilter,
  UsersManagementPageProps,
  WalletDialogState,
} from "@/components/users-management-page.types";
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
  USER_WALLET_REASON_MAX_LENGTH,
  type AdminEconomyUserSubscriptionSummary,
  type AdminUserAnalytics,
  type UserListItem,
} from "@/lib/api-client";
import { clientLogger } from "@/lib/client-logger";
import { getDictionary } from "@/lib/i18n";
import { getAdminUserDisplayName, sanitizeSensitiveText } from "@/lib/sensitive-display";

const PAGE_SIZE = 12;

export function UsersManagementPage({ locale }: UsersManagementPageProps) {
  const text = useMemo(() => getDictionary(locale), [locale]);
  const ui = useMemo(() => getUsersManagementPageText(locale), [locale]);

  const [search, setSearch] = useState("");
  const [debouncedSearch, setDebouncedSearch] = useState("");
  const [roleFilter, setRoleFilter] = useState<RoleFilter>("all");
  const [premiumFilter, setPremiumFilter] = useState<PremiumFilter>("all");
  const [activityFilter, setActivityFilter] = useState<ActivityFilter>("all");
  const [statusFilter, setStatusFilter] = useState<StatusFilter>("all");
  const [rangeDays, setRangeDays] = useState<RangeDays>(30);
  const [page, setPage] = useState(1);

  const [selectedUserId, setSelectedUserId] = useState<string | null>(null);
  const [walletDialog, setWalletDialog] = useState<WalletDialogState | null>(null);
  const [walletDialogSubmitting, setWalletDialogSubmitting] = useState(false);
  const walletDialogTitleId = useId();
  const walletDialogErrorId = useId();
  const [confirmationDialog, setConfirmationDialog] = useState<ConfirmationDialogState | null>(
    null
  );
  const [confirmationSubmitting, setConfirmationSubmitting] = useState(false);

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
      isPremium: premiumFilter === "premium" ? true : premiumFilter === "free" ? false : undefined,
    }),
    [debouncedSearch, page, premiumFilter, roleFilter, usersStatusFilter]
  );

  const {
    busyUserId,
    canManageRoles,
    error,
    hasSession,
    isFetching: isUsersFetching,
    isRefreshing: isUsersRefreshing,
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
  const {
    actionsMenuPosition,
    closeActionsMenu,
    handleToggleActionsMenu,
    menuRootRef,
    openActionsUserId,
    triggerRefs,
  } = useUsersManagementActionsMenu(canManageRoles);

  const resetUsersSelection = useCallback(
    (nextPage = 1) => {
      setSelectedUserId(null);
      closeActionsMenu();
      if (!isUserActionLocked) {
        setWalletDialog(null);
        setConfirmationDialog(null);
      }
      setPage(nextPage);
    },
    [closeActionsMenu, isUserActionLocked]
  );

  const supportInboxQuery = useQuery({
    queryKey: adminQueryKeys.supportInbox("all", "all", { page: 1, pageSize: 50 }),
    queryFn: ({ signal }) => fetchSupportInbox(undefined, "all", { page: 1, pageSize: 50, signal }),
    enabled: hasSession && users.length > 0,
  });

  const selectedUserProfile = useAdminUserProfile({ enabled: hasSession, userId: selectedUserId });

  function requestSelectedUserProfileRetry() {
    if (!selectedUserId || selectedUserProfile.isFetching) {
      return;
    }

    void selectedUserProfile.refresh().catch(() => undefined);
  }

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

      closeActionsMenu();
      setWalletDialog({
        userId,
        operation,
        amount: "100",
        reason: text.usersBalanceReasonDefault,
        error: null,
      });
    },
    [canManageRoles, closeActionsMenu, isUserActionLocked, text.usersBalanceReasonDefault]
  );

  const closeWalletDialog = useCallback(() => {
    if (walletDialogSubmitting) {
      return;
    }

    setWalletDialog(null);
  }, [walletDialogSubmitting]);

  const refreshSelectedUserProfileAfterAction = useCallback(
    async (userId: string) => {
      if (selectedUserId !== userId) {
        return;
      }

      const [refreshResult] = await Promise.allSettled([selectedUserProfile.refresh()]);
      if (refreshResult.status === "rejected") {
        clientLogger.warn("users.selected_profile_action_refresh_failed", {
          userId: sanitizeSensitiveText(userId, 80),
          ...getUsersPageErrorDetails(refreshResult.reason),
        });
      }
    },
    [selectedUserId, selectedUserProfile]
  );

  const runUserAction = useCallback(
    async (
      userId: string,
      action: () => Promise<void>,
      options?: { successMessage?: string; errorMessage?: string }
    ) => {
      const succeeded = await runAction(userId, action, options);
      if (succeeded) {
        await refreshSelectedUserProfileAfterAction(userId);
      }
      return succeeded;
    },
    [refreshSelectedUserProfileAfterAction, runAction]
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
        description: ui.activeChangeDescription(userLabel),
        confirmLabel: nextIsActive ? text.activate : text.deactivate,
        errorMessage: text.errorLoadingUsers,
        action: () => setActive(user.userId, nextIsActive),
      });
    },
    [
      getUserLabel,
      requestUserConfirmation,
      text.activate,
      text.deactivate,
      text.errorLoadingUsers,
      ui,
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
        description: ui.deleteDescription(userLabel, text.usersDeleteConfirm),
        confirmLabel: text.usersDeleteAction,
        successMessage: text.usersDeletedSuccess,
        errorMessage: text.errorLoadingUsers,
        action: () => deleteAdminUser(user.userId),
        afterSuccess,
      });
    },
    [
      getUserLabel,
      requestUserConfirmation,
      text.errorLoadingUsers,
      text.usersDeleteAction,
      text.usersDeleteConfirm,
      text.usersDeletedSuccess,
      ui,
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
        description: ui.premiumChangeDescription(userLabel),
        confirmLabel: user.isPremium ? text.removePremium : text.makePremium,
        errorMessage: text.errorLoadingUsers,
        action: () => (user.isPremium ? revokePremium(user.userId) : setPremium(user.userId, true)),
      });
    },
    [
      getUserLabel,
      requestUserConfirmation,
      text.errorLoadingUsers,
      text.makePremium,
      text.removePremium,
      ui,
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
        description: ui.roleChangeDescription(userLabel, role, hasRole),
        confirmLabel:
          role === "Admin"
            ? hasRole
              ? text.revokeAdmin
              : text.assignAdmin
            : hasRole
              ? text.revokeModerator
              : text.assignModerator,
        errorMessage: text.errorLoadingUsers,
        action: () => (hasRole ? revokeRole(user.userId, role) : assignRole(user.userId, role)),
      });
    },
    [
      getUserLabel,
      requestUserConfirmation,
      text.assignAdmin,
      text.assignModerator,
      text.errorLoadingUsers,
      text.revokeAdmin,
      text.revokeModerator,
      totalAdminCount,
      ui,
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
  const pageUserIds = useMemo(() => pageUsers.map((user) => user.userId), [pageUsers]);
  const pageUserIdSet = useMemo(() => new Set(pageUserIds), [pageUserIds]);

  const rowAnalyticsQuery = useQuery({
    queryKey: adminQueryKeys.userRowAnalytics(pageUserIds),
    queryFn: ({ signal }) =>
      fetchUserRowEnrichment<AdminUserAnalytics>(pageUserIds, signal, fetchAdminUserAnalytics),
    enabled: hasSession && pageUserIds.length > 0,
    placeholderData: keepPreviousData,
    staleTime: 30_000,
  });

  const analyticsByUserId = useMemo(() => {
    return rowAnalyticsQuery.data ?? new Map<string, AdminUserAnalytics>();
  }, [rowAnalyticsQuery.data]);

  const currentPage = Math.max(1, Math.floor(usersPage.skip / PAGE_SIZE) + 1);
  const totalPages = Math.max(1, Math.ceil(usersPage.totalCount / PAGE_SIZE));
  const pagedUsers = pageUsers;
  const premiumPageUserIds = useMemo(
    () => pagedUsers.filter((user) => user.isPremium).map((user) => user.userId),
    [pagedUsers]
  );

  const rowSubscriptionsQuery = useQuery({
    queryKey: adminQueryKeys.economyUserSubscriptionSummaries(premiumPageUserIds),
    queryFn: ({ signal }) =>
      fetchUserRowEnrichment<AdminEconomyUserSubscriptionSummary>(
        premiumPageUserIds,
        signal,
        fetchAdminEconomyUserSubscriptionSummary
      ),
    enabled: hasSession && premiumPageUserIds.length > 0,
    placeholderData: keepPreviousData,
    staleTime: 45_000,
  });

  const pageSubscriptionsByUserId = useMemo(() => {
    return rowSubscriptionsQuery.data ?? new Map<string, AdminEconomyUserSubscriptionSummary>();
  }, [rowSubscriptionsQuery.data]);

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

  useEffect(() => {
    let isActive = true;
    if (isUsersRefreshing || isUserActionLocked) {
      return;
    }

    const shouldCloseActionsMenu =
      openActionsUserId !== null && !pageUserIdSet.has(openActionsUserId);
    const shouldCloseSelectedUserPanel =
      selectedUserId !== null && !pageUserIdSet.has(selectedUserId);
    const shouldCloseWalletDialog =
      walletDialog !== null && !pageUserIdSet.has(walletDialog.userId);
    const shouldCloseConfirmationDialog =
      confirmationDialog !== null && !pageUserIdSet.has(confirmationDialog.userId);

    if (
      !shouldCloseActionsMenu &&
      !shouldCloseSelectedUserPanel &&
      !shouldCloseWalletDialog &&
      !shouldCloseConfirmationDialog
    ) {
      return;
    }

    queueMicrotask(() => {
      if (!isActive) {
        return;
      }

      if (shouldCloseActionsMenu) {
        closeActionsMenu();
      }

      if (shouldCloseSelectedUserPanel) {
        setSelectedUserId(null);
      }

      if (shouldCloseWalletDialog) {
        setWalletDialog(null);
      }

      if (shouldCloseConfirmationDialog) {
        setConfirmationDialog(null);
      }
    });

    return () => {
      isActive = false;
    };
  }, [
    closeActionsMenu,
    confirmationDialog,
    isUserActionLocked,
    isUsersRefreshing,
    openActionsUserId,
    pageUserIdSet,
    selectedUserId,
    walletDialog,
  ]);

  if (!canManageRoles) {
    return (
      <AdminPage className={styles.page}>
        <UsersManagementHero text={text} />
        <UsersManagementAccessState text={text} />
      </AdminPage>
    );
  }

  if (isLoading) {
    return (
      <AdminPage className={styles.page}>
        <UsersManagementHero text={text} />
        <UsersManagementLoadingState text={text} />
      </AdminPage>
    );
  }

  return (
    <AdminPage className={styles.page}>
      <UsersManagementHero text={text} />

      <UsersManagementPageWorkspace
        activeUsersValue={activeUsersValue}
        activityFilter={activityFilter}
        analyticsByUserId={analyticsByUserId}
        busyUserId={busyUserId}
        blockedUsersValue={blockedUsersValue}
        canManageRoles={canManageRoles}
        closeActionsMenu={closeActionsMenu}
        currentPage={currentPage}
        error={error}
        handleToggleActionsMenu={handleToggleActionsMenu}
        isUserActionLocked={isUserActionLocked}
        isUsersFetching={isUsersFetching}
        isUsersRefreshing={isUsersRefreshing}
        locale={locale}
        newUsersValue={newUsersValue}
        openSupportUserCount={openSupportUserCount}
        openActionsUserId={openActionsUserId}
        openWalletDialog={openWalletDialog}
        pageSubscriptionsByUserId={pageSubscriptionsByUserId}
        pageUsers={pageUsers}
        pagedUsers={pagedUsers}
        premiumFilter={premiumFilter}
        premiumUsersValue={premiumUsersValue}
        rangeDays={rangeDays}
        refreshUsers={() => refreshUsers().then(() => undefined)}
        requestActiveChange={requestActiveChange}
        requestPremiumChange={requestPremiumChange}
        resetAllFilters={() => {
          setSearch("");
          setRoleFilter("all");
          setPremiumFilter("all");
          setActivityFilter("all");
          setStatusFilter("all");
          resetUsersSelection();
        }}
        resetUsersSelection={resetUsersSelection}
        roleFilter={roleFilter}
        search={search}
        setActivityFilter={setActivityFilter}
        setPremiumFilter={setPremiumFilter}
        setRangeDays={setRangeDays}
        setRoleFilter={setRoleFilter}
        setSearch={setSearch}
        setSelectedUserId={setSelectedUserId}
        setStatusFilter={setStatusFilter}
        statusFilter={statusFilter}
        text={text}
        totalUsersValue={totalUsersValue}
        totalPages={totalPages}
        triggerRefs={triggerRefs}
        ui={ui}
        usersPageTotalCount={usersPage.totalCount}
      />

      <UsersManagementPageOverlays
        actionsMenuPosition={actionsMenuPosition}
        busyUserId={busyUserId}
        canManageRoles={canManageRoles}
        cannotRevokeLastAdmin={cannotRevokeLastAdmin}
        closeActionsMenu={closeActionsMenu}
        closeConfirmationDialog={closeConfirmationDialog}
        closePanel={() => setSelectedUserId(null)}
        closeWalletDialog={closeWalletDialog}
        confirmationDialog={confirmationDialog}
        confirmationSubmitting={confirmationSubmitting}
        isUserActionLocked={isUserActionLocked}
        locale={locale}
        menuRootRef={menuRootRef}
        openActionsUser={openActionsUser}
        openWalletDialog={openWalletDialog}
        requestRoleChange={requestRoleChange}
        setSelectedUserId={setSelectedUserId}
        setWalletDialog={setWalletDialog}
        requestActiveChange={requestActiveChange}
        requestDeleteUser={requestDeleteUser}
        requestSelectedUserProfileRetry={requestSelectedUserProfileRetry}
        selectedSubscription={selectedSubscriptionQuery.data ?? null}
        selectedUser={selectedUser}
        selectedUserAnalytics={selectedUserAnalytics}
        selectedUserId={selectedUserId}
        selectedUserProfile={selectedUserProfile}
        selectedUserSupportTickets={selectedUserSupportTickets}
        submitConfirmationDialog={submitConfirmationDialog}
        submitWalletDialog={submitWalletDialog}
        text={text}
        ui={ui}
        toast={toast}
        walletDialog={walletDialog}
        walletDialogErrorId={walletDialogErrorId}
        walletDialogSubmitting={walletDialogSubmitting}
        walletDialogTitleId={walletDialogTitleId}
      />
    </AdminPage>
  );
}
