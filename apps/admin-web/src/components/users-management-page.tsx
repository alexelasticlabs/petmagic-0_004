"use client";

import { keepPreviousData, useQuery } from "@tanstack/react-query";
import { useCallback, useEffect, useMemo, useState } from "react";

import { AdminPage } from "@/components/admin/admin-primitives";
import { useUsersAdmin } from "@/components/users/use-users-admin";
import { UsersManagementPageWorkspace } from "@/components/users-management-page-workspace";
import {
  UsersManagementAccessState,
  UsersManagementLoadingState,
} from "@/components/users-management-page.chrome";
import { getUsersManagementPageText } from "@/components/users-management-page.content";
import {
  formatMetricCount,
  getNewUsersCountForRange,
} from "@/components/users-management-page.helpers";
import styles from "@/components/users-management-page.module.css";
import type {
  PremiumFilter,
  RangeDays,
  RoleFilter,
  StatusFilter,
  UserSortMode,
  UsersManagementPageProps,
} from "@/components/users-management-page.types";
import { adminQueryKeys } from "@/lib/admin-query-keys";
import { fetchAdminUserDashboardMetrics } from "@/lib/api-client";
import { getDictionary } from "@/lib/i18n";

const PAGE_SIZE = 24;

export function UsersManagementPage({ locale }: UsersManagementPageProps) {
  const text = useMemo(() => getDictionary(locale), [locale]);
  const ui = useMemo(() => getUsersManagementPageText(locale), [locale]);

  const [search, setSearch] = useState("");
  const [debouncedSearch, setDebouncedSearch] = useState("");
  const [roleFilter, setRoleFilter] = useState<RoleFilter>("all");
  const [premiumFilter, setPremiumFilter] = useState<PremiumFilter>("all");
  const [statusFilter, setStatusFilter] = useState<StatusFilter>("all");
  const [sortMode, setSortMode] = useState<UserSortMode>("created_desc");
  const [rangeDays, setRangeDays] = useState<RangeDays>(30);
  const [page, setPage] = useState(1);

  useEffect(() => {
    const timer = window.setTimeout(() => {
      setDebouncedSearch(search.trim());
    }, 350);

    return () => {
      window.clearTimeout(timer);
    };
  }, [search]);

  const usersQueryParams = useMemo(
    () => ({
      skip: (page - 1) * PAGE_SIZE,
      take: PAGE_SIZE,
      search: debouncedSearch || undefined,
      role: roleFilter === "all" ? undefined : roleFilter,
      status: statusFilter === "all" ? undefined : statusFilter,
      isPremium: premiumFilter === "premium" ? true : premiumFilter === "free" ? false : undefined,
      sort: sortMode,
    }),
    [debouncedSearch, page, premiumFilter, roleFilter, sortMode, statusFilter]
  );

  const {
    canManageRoles,
    error,
    hasSession,
    isFetching: isUsersFetching,
    isRefreshing: isUsersRefreshing,
    isLoading,
    refreshUsers,
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

  const resetUsersPage = useCallback((nextPage = 1) => {
    setPage(nextPage);
  }, []);

  const userMetrics = userMetricsQuery.data ?? null;
  const currentPage = Math.max(1, Math.floor(usersPage.skip / PAGE_SIZE) + 1);
  const totalPages = Math.max(1, Math.ceil(usersPage.totalCount / PAGE_SIZE));
  const totalUsersValue = formatMetricCount(userMetrics?.totalUsers);
  const activeUsersValue = formatMetricCount(userMetrics?.activeUsers);
  const premiumUsersValue = formatMetricCount(userMetrics?.premiumUsers);
  const blockedUsersValue = formatMetricCount(userMetrics?.blockedUsers);
  const newUsersValue = formatMetricCount(getNewUsersCountForRange(userMetrics, rangeDays));

  if (!canManageRoles) {
    return (
      <AdminPage className={styles.page}>
        <UsersManagementAccessState ui={ui} />
      </AdminPage>
    );
  }

  if (isLoading) {
    return (
      <AdminPage className={styles.page}>
        <UsersManagementLoadingState ui={ui} />
      </AdminPage>
    );
  }

  return (
    <AdminPage className={styles.page}>
      <UsersManagementPageWorkspace
        activeUsersValue={activeUsersValue}
        blockedUsersValue={blockedUsersValue}
        currentPage={currentPage}
        error={error}
        isMetricsError={userMetricsQuery.isError}
        isMetricsFetching={userMetricsQuery.isFetching}
        isUsersFetching={isUsersFetching}
        isUsersRefreshing={isUsersRefreshing}
        locale={locale}
        newUsersValue={newUsersValue}
        premiumFilter={premiumFilter}
        premiumUsersValue={premiumUsersValue}
        refreshMetrics={async () => {
          const refreshedMetrics = await userMetricsQuery.refetch();
          if (refreshedMetrics.isError) {
            throw refreshedMetrics.error;
          }
        }}
        rangeDays={rangeDays}
        refreshUsers={() => refreshUsers().then(() => undefined)}
        resetAllFilters={() => {
          setSearch("");
          setRoleFilter("all");
          setPremiumFilter("all");
          setStatusFilter("all");
          setSortMode("created_desc");
          resetUsersPage();
        }}
        resetUsersPage={resetUsersPage}
        roleFilter={roleFilter}
        search={search}
        setPremiumFilter={setPremiumFilter}
        setRangeDays={setRangeDays}
        setRoleFilter={setRoleFilter}
        setSearch={setSearch}
        setSortMode={setSortMode}
        setStatusFilter={setStatusFilter}
        sortMode={sortMode}
        statusFilter={statusFilter}
        text={text}
        totalPages={totalPages}
        totalUsersValue={totalUsersValue}
        ui={ui}
        users={users}
        usersPageTotalCount={usersPage.totalCount}
      />
    </AdminPage>
  );
}
