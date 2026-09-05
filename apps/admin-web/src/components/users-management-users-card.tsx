"use client";

import { useRouter } from "next/navigation";
import { useEffect, useMemo, useState } from "react";

import { MailIcon } from "@/components/admin/admin-icons";
import { AdminCard, AdminStateCard } from "@/components/admin/admin-primitives";
import { AdminSelectionTray } from "@/components/admin/admin-selection-tray";
import {
  maximumPersistedSelectionCount,
  readPersistedSelection,
  selectionStoragePrefix,
  toSelectedUserEntity,
  type SelectedUserEntity,
} from "@/components/email-recipient-selection";
import { Button } from "@/components/ui/button";
import type { UsersManagementPageText } from "@/components/users-management-page.content";
import styles from "@/components/users-management-page.module.css";
import type {
  PremiumFilter,
  RoleFilter,
  StatusFilter,
  UserSortMode,
} from "@/components/users-management-page.types";
import { UsersManagementUsersFilters } from "@/components/users-management-users-card.filters";
import { UsersManagementUsersTable } from "@/components/users-management-users-card.table";
import { useAuthSession, type UserListItem } from "@/lib/api-client";
import type { Dictionary, Locale } from "@/lib/i18n";

type UsersManagementUsersCardProps = {
  currentPage: number;
  error: string | null;
  isUsersFetching: boolean;
  isUsersRefreshing: boolean;
  locale: Locale;
  premiumFilter: PremiumFilter;
  refreshUsers: () => Promise<void>;
  resetAllFilters: () => void;
  resetUsersPage: (nextPage?: number) => void;
  roleFilter: RoleFilter;
  search: string;
  setPremiumFilter: (value: PremiumFilter) => void;
  setRoleFilter: (value: RoleFilter) => void;
  setSearch: (value: string) => void;
  setSortMode: (value: UserSortMode) => void;
  setStatusFilter: (value: StatusFilter) => void;
  sortMode: UserSortMode;
  statusFilter: StatusFilter;
  text: Dictionary;
  totalPages: number;
  ui: UsersManagementPageText;
  users: UserListItem[];
  usersPageTotalCount: number;
};

export function UsersManagementUsersCard({
  currentPage,
  error,
  isUsersFetching,
  isUsersRefreshing,
  locale,
  premiumFilter,
  refreshUsers,
  resetAllFilters,
  resetUsersPage,
  roleFilter,
  search,
  setPremiumFilter,
  setRoleFilter,
  setSearch,
  setSortMode,
  setStatusFilter,
  sortMode,
  statusFilter,
  text,
  totalPages,
  ui,
  users,
  usersPageTotalCount,
}: UsersManagementUsersCardProps) {
  const router = useRouter();
  const session = useAuthSession();
  const hasUsers = users.length > 0;
  const isInitialRefresh = isUsersRefreshing && !hasUsers && !error;
  const hasRecoverablePagination = usersPageTotalCount > 0 && (totalPages > 1 || currentPage > 1);
  const selectionStorageKey = session?.user.userId
    ? `${selectionStoragePrefix}:${session.user.userId}`
    : null;
  const [selectedUsers, setSelectedUsers] = useState<ReadonlyMap<string, SelectedUserEntity>>(() =>
    selectionStorageKey ? readPersistedSelection(selectionStorageKey) : new Map()
  );
  const selectedUserIds = useMemo(() => new Set(selectedUsers.keys()), [selectedUsers]);
  const selectedUserList = useMemo(() => {
    const currentPageUsers = new Map(users.map((user) => [user.userId, user]));
    return [...selectedUsers.values()].map((item) => {
      const currentUser = currentPageUsers.get(item.id);
      return currentUser ? toSelectedUserEntity(currentUser) : item;
    });
  }, [selectedUsers, users]);
  const selectedUserIdList = useMemo(
    () => selectedUserList.filter((item) => item.eligible).map((item) => item.id),
    [selectedUserList]
  );

  useEffect(() => {
    if (!selectionStorageKey) return;
    try {
      window.localStorage.setItem(
        selectionStorageKey,
        JSON.stringify(selectedUserList.slice(0, maximumPersistedSelectionCount))
      );
    } catch {
      // Selection persistence is an enhancement; browser storage failures must not block admin work.
    }
  }, [selectedUserList, selectionStorageKey]);

  function toggleUserSelection(userId: string, selected: boolean) {
    setSelectedUsers((current) => {
      const next = new Map(current);
      if (selected) {
        const user = users.find((candidate) => candidate.userId === userId);
        if (user) next.set(userId, toSelectedUserEntity(user));
      } else {
        next.delete(userId);
      }
      return next;
    });
  }

  function togglePageSelection(userIds: readonly string[], selected: boolean) {
    setSelectedUsers((current) => {
      const next = new Map(current);
      for (const userId of userIds) {
        if (selected) {
          const user = users.find((candidate) => candidate.userId === userId);
          if (user) next.set(userId, toSelectedUserEntity(user));
        } else {
          next.delete(userId);
        }
      }
      return next;
    });
  }

  return (
    <AdminCard
      title={ui.registryTitle}
      description={text.usersCardDescription}
      action={
        <div className={styles.registryActions}>
          {selectedUsers.size > 0 ? (
            <span className={styles.selectedCount} role="status">
              {ui.bulkEmail.selectedCount(selectedUsers.size)}
            </span>
          ) : null}
          <Button
            type="button"
            variant="secondary"
            size="sm"
            onClick={() => router.push(`/${locale}/email-broadcasts?compose=1`)}
          >
            <MailIcon className={styles.bulkEmailIcon} />
            {ui.bulkEmail.openLabel}
          </Button>
          <span
            className={styles.registryCount}
            aria-label={`${ui.usersCount}: ${usersPageTotalCount}`}
          >
            <strong>{usersPageTotalCount}</strong>
            <span>{ui.usersCount}</span>
          </span>
        </div>
      }
    >
      <UsersManagementUsersFilters
        premiumFilter={premiumFilter}
        resetAllFilters={resetAllFilters}
        resetUsersPage={resetUsersPage}
        roleFilter={roleFilter}
        search={search}
        setPremiumFilter={setPremiumFilter}
        setRoleFilter={setRoleFilter}
        setSearch={setSearch}
        setSortMode={setSortMode}
        setStatusFilter={setStatusFilter}
        sortMode={sortMode}
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

      {isUsersRefreshing && hasUsers ? (
        <p className={styles.refreshHint} role="status">
          {text.loading}
        </p>
      ) : null}

      {isInitialRefresh ? (
        <AdminStateCard tone="info" className={styles.emptyState} title={text.loading} />
      ) : null}

      {!error && !isUsersRefreshing && !hasUsers ? (
        <AdminStateCard
          tone="info"
          className={styles.emptyState}
          title={text.noUsers}
          description={ui.noSearchResults}
        />
      ) : null}

      {hasUsers || hasRecoverablePagination ? (
        <UsersManagementUsersTable
          currentPage={currentPage}
          isUsersFetching={isUsersFetching}
          locale={locale}
          pagedUsers={users}
          resetUsersPage={resetUsersPage}
          selectedUserIds={selectedUserIds}
          text={text}
          totalPages={totalPages}
          ui={ui}
          onTogglePageSelection={togglePageSelection}
          onToggleUserSelection={toggleUserSelection}
        />
      ) : null}

      <AdminSelectionTray
        selectedCount={selectedUsers.size}
        selectedLabel={ui.bulkEmail.selectedCount(selectedUsers.size)}
        trayLabel={ui.bulkEmail.selectionTrayLabel}
        clearLabel={ui.bulkEmail.selectionClear}
        description={ui.bulkEmail.selectionDescription(
          selectedUserIdList.length,
          selectedUsers.size
        )}
        items={selectedUserList.map((item) => ({
          id: item.id,
          label: item.label,
          eligible: item.eligible,
          eligibilityLabel: item.eligible
            ? ui.bulkEmail.selectionEligible
            : ui.bulkEmail.selectionIneligible,
          removeLabel: ui.bulkEmail.selectionRemove,
        }))}
        onRemove={(userId) =>
          setSelectedUsers((current) => {
            const next = new Map(current);
            next.delete(userId);
            return next;
          })
        }
        onClear={() => setSelectedUsers(new Map())}
      >
        <Button
          type="button"
          variant="primary"
          size="sm"
          disabled={selectedUserIdList.length === 0}
          onClick={() => router.push(`/${locale}/email-broadcasts?compose=1`)}
        >
          <MailIcon className={styles.bulkEmailIcon} />
          {ui.bulkEmail.openLabel}
        </Button>
      </AdminSelectionTray>
    </AdminCard>
  );
}
