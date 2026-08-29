"use client";

import { CaretDownIcon, MoreHorizontalIcon, PawIcon } from "@/components/admin/admin-icons";
import { useEffect, useMemo, useRef } from "react";

import { adminTableStyles } from "@/components/admin/admin-primitives";
import { Button } from "@/components/ui/button";
import { UserAvatarView } from "@/components/users/user-avatar";
import type { UsersManagementPageText } from "@/components/users-management-page.content";
import { getAccountStatus, getUserAvatarLabel } from "@/components/users-management-page.helpers";
import styles from "@/components/users-management-page.module.css";
import type { UserListItem } from "@/lib/api-client";
import { formatDateTime } from "@/lib/format-date-time";
import type { Dictionary, Locale } from "@/lib/i18n";
import { maskEmail, sanitizeSensitiveText } from "@/lib/sensitive-display";

type UsersManagementUsersTableProps = {
  currentPage: number;
  isUsersFetching: boolean;
  locale: Locale;
  pagedUsers: UserListItem[];
  resetUsersPage: (nextPage?: number) => void;
  selectedUserIds: ReadonlySet<string>;
  text: Dictionary;
  totalPages: number;
  ui: UsersManagementPageText;
  onTogglePageSelection: (userIds: readonly string[], selected: boolean) => void;
  onToggleUserSelection: (userId: string, selected: boolean) => void;
  onOpenUser: (user: UserListItem) => void;
};

export function UsersManagementUsersTable({
  currentPage,
  isUsersFetching,
  locale,
  pagedUsers,
  resetUsersPage,
  selectedUserIds,
  text,
  totalPages,
  ui,
  onTogglePageSelection,
  onToggleUserSelection,
  onOpenUser,
}: UsersManagementUsersTableProps) {
  const shouldShowPagination = totalPages > 1 || currentPage > 1;
  const selectAllRef = useRef<HTMLInputElement>(null);
  const eligibleUserIds = useMemo(
    () =>
      pagedUsers.filter((user) => user.isActive && user.emailConfirmed).map((user) => user.userId),
    [pagedUsers]
  );
  const selectedEligibleCount = eligibleUserIds.filter((userId) =>
    selectedUserIds.has(userId)
  ).length;
  const areAllEligibleUsersSelected =
    eligibleUserIds.length > 0 && selectedEligibleCount === eligibleUserIds.length;

  useEffect(() => {
    if (selectAllRef.current) {
      selectAllRef.current.indeterminate =
        selectedEligibleCount > 0 && !areAllEligibleUsersSelected;
    }
  }, [areAllEligibleUsersSelected, selectedEligibleCount]);

  return (
    <>
      <div
        className={`${adminTableStyles.tableWrap} ${styles.tableWrap}`}
        hidden={pagedUsers.length === 0}
        aria-busy={isUsersFetching ? "true" : undefined}
      >
        <table className={adminTableStyles.table}>
          <thead>
            <tr>
              <th aria-label={ui.bulkEmail.selectAllLabel}>
                <div className={styles.tableUserHeader}>
                  <input
                    ref={selectAllRef}
                    type="checkbox"
                    className={styles.selectionCheckbox}
                    checked={areAllEligibleUsersSelected}
                    disabled={eligibleUserIds.length === 0}
                    aria-label={ui.bulkEmail.selectAllLabel}
                    title={ui.bulkEmail.selectAllLabel}
                    onChange={(event) =>
                      onTogglePageSelection(eligibleUserIds, event.target.checked)
                    }
                  />
                </div>
              </th>
              <th>{ui.userColumn}</th>
              <th>{ui.filterStatus}</th>
              <th>{ui.plan}</th>
              <th>{ui.balance}</th>
              <th>{ui.lastActivity}</th>
              <th aria-label={ui.quickActions} />
            </tr>
          </thead>
          <tbody>
            {pagedUsers.map((user) => {
              const status = getAccountStatus(user);
              const userName = sanitizeSensitiveText(user.displayName, 96);
              const userLabel = userName || maskEmail(user.email);
              const canReceiveBulkEmail = user.isActive && user.emailConfirmed;

              return (
                <tr key={user.userId} className={styles.userRow} onClick={() => onOpenUser(user)}>
                  <td
                    data-label={ui.bulkEmail.selectAllLabel}
                    onClick={(event) => event.stopPropagation()}
                  >
                    <div className={styles.selectionIdentityRow}>
                      <input
                        type="checkbox"
                        className={styles.selectionCheckbox}
                        checked={selectedUserIds.has(user.userId)}
                        disabled={!canReceiveBulkEmail}
                        aria-label={
                          canReceiveBulkEmail
                            ? ui.bulkEmail.selectUserLabel(userLabel)
                            : ui.bulkEmail.unavailableRecipientLabel
                        }
                        title={
                          canReceiveBulkEmail
                            ? ui.bulkEmail.selectUserLabel(userLabel)
                            : ui.bulkEmail.unavailableRecipientLabel
                        }
                        onChange={(event) =>
                          onToggleUserSelection(user.userId, event.target.checked)
                        }
                      />
                    </div>
                  </td>
                  <td data-label={ui.userColumn}>
                    <button
                      type="button"
                      className={styles.identityCell}
                      onClick={() => onOpenUser(user)}
                      aria-label={`${ui.openProfile}: ${userLabel}`}
                    >
                      <UserAvatarView
                        avatar={user.avatar}
                        label={`${text.avatarLabel}: ${getUserAvatarLabel(user)}`}
                        fallbackLabel={getUserAvatarLabel(user)}
                      />
                      <div className={styles.identityCopy}>
                        <span className={styles.userAnchor}>{userLabel}</span>
                        <span className={styles.userMeta}>{maskEmail(user.email)}</span>
                      </div>
                    </button>
                  </td>
                  <td data-label={ui.filterStatus}>
                    <span className={styles.compactStatus} data-status={status}>
                      {status === "blocked"
                        ? ui.blockedBadge
                        : status === "unconfirmed"
                          ? ui.unconfirmedBadge
                          : ui.activeBadge}
                    </span>
                  </td>
                  <td data-label={ui.plan}>
                    <span className={user.isPremium ? styles.premiumPlan : styles.freePlan}>
                      {user.isPremium ? text.premiumLabel : text.freeLabel}
                    </span>
                  </td>
                  <td data-label={ui.balance}>
                    <span className={styles.balanceValue}>
                      <PawIcon />
                      {ui.balanceUnavailable}
                    </span>
                  </td>
                  <td data-label={ui.lastActivity}>
                    {user.lastActivityAtUtc ? (
                      <time dateTime={user.lastActivityAtUtc} className={styles.dateValue}>
                        {formatDateTime(user.lastActivityAtUtc, locale)}
                      </time>
                    ) : (
                      <div className={styles.activityCell}>
                        <span className={styles.noActivity}>{ui.noActivity}</span>
                      </div>
                    )}
                  </td>
                  <td
                    data-label={ui.quickActions}
                    className={styles.actionsCell}
                    onClick={(event) => event.stopPropagation()}
                  >
                    <button
                      type="button"
                      className={styles.rowMenuButton}
                      aria-label={`${ui.quickActions}: ${userLabel}`}
                      onClick={() => onOpenUser(user)}
                    >
                      <MoreHorizontalIcon />
                    </button>
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>

      {shouldShowPagination ? (
        <div className={styles.pagination}>
          <div className={styles.paginationControls}>
            <Button
              variant="ghost"
              size="sm"
              onClick={() => resetUsersPage(Math.max(1, Math.min(totalPages, currentPage - 1)))}
              disabled={currentPage <= 1 || isUsersFetching}
              aria-label={ui.previousPageLabel}
              title={ui.previousPageLabel}
            >
              <CaretDownIcon className={`${styles.pageIcon} ${styles.pageIconPrevious}`} />
            </Button>
            <span className={styles.pageInfo}>
              {ui.pageInfo} {currentPage} / {totalPages}
            </span>
            <Button
              variant="ghost"
              size="sm"
              onClick={() => resetUsersPage(Math.min(totalPages, currentPage + 1))}
              disabled={currentPage >= totalPages || isUsersFetching}
              aria-label={ui.nextPageLabel}
              title={ui.nextPageLabel}
            >
              <CaretDownIcon className={`${styles.pageIcon} ${styles.pageIconNext}`} />
            </Button>
          </div>
        </div>
      ) : null}
    </>
  );
}
