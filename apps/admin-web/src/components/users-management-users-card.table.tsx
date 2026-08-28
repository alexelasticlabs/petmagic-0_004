"use client";

import Link from "next/link";
import { useEffect, useMemo, useRef } from "react";

import {
  CaretDownIcon,
  DollarIcon,
  SupportIcon,
  UserRegisterIcon,
} from "@/components/admin/admin-icons";
import {
  AdminBadge,
  AdminStatusBadge,
  adminTableStyles,
} from "@/components/admin/admin-primitives";
import { Button } from "@/components/ui/button";
import { UserAvatarView } from "@/components/users/user-avatar";
import type { UsersManagementPageText } from "@/components/users-management-page.content";
import {
  accountStatusColors,
  getAccountStatus,
  getUserAvatarLabel,
  getUserRoleLabel,
  getUserRoleTone,
  premiumStatusColors,
} from "@/components/users-management-page.helpers";
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
              <th>
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
                  <span>{ui.userColumn}</span>
                </div>
              </th>
              <th>{ui.accountAndAccess}</th>
              <th>{ui.plan}</th>
              <th>{ui.lastActivity}</th>
              <th>{ui.registeredAt}</th>
              <th>{ui.quickActions}</th>
            </tr>
          </thead>
          <tbody>
            {pagedUsers.map((user) => {
              const status = getAccountStatus(user);
              const userName = sanitizeSensitiveText(user.displayName, 96);
              const userLabel = userName || maskEmail(user.email);
              const canReceiveBulkEmail = user.isActive && user.emailConfirmed;

              return (
                <tr key={user.userId}>
                  <td data-label={ui.userColumn}>
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
                      <Link
                        href={`/${locale}/users/${encodeURIComponent(user.userId)}`}
                        className={styles.identityCell}
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
                        <CaretDownIcon className={styles.identityArrow} aria-hidden="true" />
                      </Link>
                    </div>
                  </td>
                  <td data-label={ui.accountAndAccess}>
                    <div className={styles.statusCell}>
                      <AdminStatusBadge color={accountStatusColors[status]}>
                        {status === "blocked"
                          ? ui.blockedBadge
                          : status === "unconfirmed"
                            ? ui.unconfirmedBadge
                            : ui.activeBadge}
                      </AdminStatusBadge>
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
                    </div>
                  </td>
                  <td data-label={ui.plan}>
                    <AdminStatusBadge
                      color={
                        user.isPremium ? premiumStatusColors.premium : premiumStatusColors.free
                      }
                    >
                      {user.isPremium ? text.premiumLabel : text.freeLabel}
                    </AdminStatusBadge>
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
                  <td data-label={ui.registeredAt}>
                    <time dateTime={user.createdAtUtc} className={styles.registrationCell}>
                      {formatDateTime(user.createdAtUtc, locale)}
                    </time>
                  </td>
                  <td data-label={ui.quickActions} className={styles.actionsCell}>
                    <div
                      className={styles.quickActions}
                      role="group"
                      aria-label={`${ui.quickActions}: ${userName || maskEmail(user.email)}`}
                    >
                      <Link
                        href={`/${locale}/users/${encodeURIComponent(user.userId)}`}
                        className={`ui-button ui-button--primary ui-button--sm ${styles.quickActionLink} ${styles.quickActionPrimary}`}
                        aria-label={`${ui.quickProfile}: ${userName || maskEmail(user.email)}`}
                        title={`${ui.quickProfile}: ${userName || maskEmail(user.email)}`}
                      >
                        <UserRegisterIcon className={styles.quickActionIcon} />
                        <span className={styles.quickActionText}>{ui.quickProfile}</span>
                      </Link>
                      <Link
                        href={`/${locale}/users/${encodeURIComponent(user.userId)}?tab=wallet`}
                        className={`ui-button ui-button--secondary ui-button--sm ${styles.quickActionLink}`}
                        aria-label={`${ui.quickWallet}: ${userName || maskEmail(user.email)}`}
                        title={`${ui.quickWallet}: ${userName || maskEmail(user.email)}`}
                      >
                        <DollarIcon className={styles.quickActionIcon} />
                        <span className={styles.quickActionText}>{ui.quickWallet}</span>
                      </Link>
                      <Link
                        href={`/${locale}/users/${encodeURIComponent(user.userId)}?tab=support`}
                        className={`ui-button ui-button--ghost ui-button--sm ${styles.quickActionLink}`}
                        aria-label={`${ui.quickSupport}: ${userName || maskEmail(user.email)}`}
                        title={`${ui.quickSupport}: ${userName || maskEmail(user.email)}`}
                      >
                        <SupportIcon className={styles.quickActionIcon} />
                        <span className={styles.quickActionText}>{ui.quickSupport}</span>
                      </Link>
                    </div>
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
