"use client";


import { AdminCard, AdminStateCard } from "@/components/admin/admin-primitives";
import { Button } from "@/components/ui/button";
import type { UsersManagementPageText } from "@/components/users-management-page.content";
import styles from "@/components/users-management-page.module.css";
import type {
  ActivityFilter,
  PremiumFilter,
  RangeDays,
  RoleFilter,
  StatusFilter,
} from "@/components/users-management-page.types";
import { UsersManagementUsersFilters } from "@/components/users-management-users-card.filters";
import { UsersManagementUsersTable } from "@/components/users-management-users-card.table";
import {
  type AdminEconomyUserSubscriptionSummary,
  type AdminUserAnalytics,
  type UserListItem,
} from "@/lib/api-client";
import type { Dictionary, Locale } from "@/lib/i18n";

import type { MutableRefObject } from "react";

type UsersManagementUsersCardProps = {
  analyticsByUserId: Map<string, AdminUserAnalytics>;
  busyUserId: string | null;
  canManageRoles: boolean;
  closeActionsMenu: () => void;
  currentPage: number;
  error: string | null;
  handleToggleActionsMenu: (userId: string) => void;
  isUserActionLocked: boolean;
  isUsersFetching: boolean;
  isUsersRefreshing: boolean;
  locale: Locale;
  openActionsUserId: string | null;
  openWalletDialog: (userId: string, operation: "credit" | "debit") => void;
  pageSubscriptionsByUserId: Map<string, AdminEconomyUserSubscriptionSummary>;
  pageUsers: UserListItem[];
  pagedUsers: UserListItem[];
  premiumFilter: PremiumFilter;
  rangeDays: RangeDays;
  refreshUsers: () => Promise<void>;
  requestActiveChange: (user: UserListItem) => void;
  requestPremiumChange: (user: UserListItem) => void;
  resetAllFilters: () => void;
  resetUsersSelection: (nextPage?: number) => void;
  roleFilter: RoleFilter;
  search: string;
  setActivityFilter: (value: ActivityFilter) => void;
  setPremiumFilter: (value: PremiumFilter) => void;
  setRangeDays: (value: RangeDays) => void;
  setRoleFilter: (value: RoleFilter) => void;
  setSearch: (value: string) => void;
  setSelectedUserId: (userId: string) => void;
  setStatusFilter: (value: StatusFilter) => void;
  statusFilter: StatusFilter;
  text: Dictionary;
  totalPages: number;
  triggerRefs: MutableRefObject<Record<string, HTMLButtonElement | null>>;
  ui: UsersManagementPageText;
  usersPageTotalCount: number;
  activityFilter: ActivityFilter;
};

export function UsersManagementUsersCard({
  activityFilter,
  analyticsByUserId,
  busyUserId,
  canManageRoles,
  closeActionsMenu,
  currentPage,
  error,
  handleToggleActionsMenu,
  isUserActionLocked,
  isUsersFetching,
  isUsersRefreshing,
  locale,
  openActionsUserId,
  openWalletDialog,
  pageSubscriptionsByUserId,
  pageUsers,
  pagedUsers,
  premiumFilter,
  rangeDays,
  refreshUsers,
  requestActiveChange,
  requestPremiumChange,
  resetAllFilters,
  resetUsersSelection,
  roleFilter,
  search,
  setActivityFilter,
  setPremiumFilter,
  setRangeDays,
  setRoleFilter,
  setSearch,
  setSelectedUserId,
  setStatusFilter,
  statusFilter,
  text,
  totalPages,
  triggerRefs,
  ui,
  usersPageTotalCount,
}: UsersManagementUsersCardProps) {
  return (
    <AdminCard title={text.usersTitle} description={text.usersCardDescription}>
      <UsersManagementUsersFilters
        activityFilter={activityFilter}
        premiumFilter={premiumFilter}
        rangeDays={rangeDays}
        resetAllFilters={resetAllFilters}
        resetUsersSelection={resetUsersSelection}
        roleFilter={roleFilter}
        search={search}
        setActivityFilter={setActivityFilter}
        setPremiumFilter={setPremiumFilter}
        setRangeDays={setRangeDays}
        setRoleFilter={setRoleFilter}
        setSearch={setSearch}
        setStatusFilter={setStatusFilter}
        statusFilter={statusFilter}
        text={text}
        ui={ui}
      />

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

      {isUsersRefreshing ? (
        <AdminStateCard tone="info" className={styles.emptyState} title={text.loading} />
      ) : null}

      {!isUsersRefreshing && !pageUsers.length ? (
        <AdminStateCard
          tone="info"
          className={styles.emptyState}
          title={text.noUsers}
          description={ui.noSearchResults}
        />
      ) : null}

      {!isUsersRefreshing && !!pageUsers.length && (
        <UsersManagementUsersTable
          analyticsByUserId={analyticsByUserId}
          busyUserId={busyUserId}
          canManageRoles={canManageRoles}
          closeActionsMenu={closeActionsMenu}
          currentPage={currentPage}
          handleToggleActionsMenu={handleToggleActionsMenu}
          isUserActionLocked={isUserActionLocked}
          isUsersFetching={isUsersFetching}
          locale={locale}
          openActionsUserId={openActionsUserId}
          openWalletDialog={openWalletDialog}
          pageSubscriptionsByUserId={pageSubscriptionsByUserId}
          pagedUsers={pagedUsers}
          requestActiveChange={requestActiveChange}
          requestPremiumChange={requestPremiumChange}
          resetUsersSelection={resetUsersSelection}
          setSelectedUserId={setSelectedUserId}
          text={text}
          totalPages={totalPages}
          triggerRefs={triggerRefs}
          ui={ui}
          usersPageTotalCount={usersPageTotalCount}
        />
      )}
    </AdminCard>
  );
}
