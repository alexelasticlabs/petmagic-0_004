"use client";

import Link from "next/link";

import { CaretDownIcon, MoreHorizontalIcon } from "@/components/admin/admin-icons";
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
import type {
  AdminEconomyUserSubscriptionSummary,
  AdminUserAnalytics,
  UserListItem,
} from "@/lib/api-client";
import { formatDateTime } from "@/lib/format-date-time";
import type { Dictionary, Locale } from "@/lib/i18n";
import { maskEmail, sanitizeSensitiveText, shortIdentifier } from "@/lib/sensitive-display";

import type { MutableRefObject } from "react";

type UsersManagementUsersTableProps = {
  analyticsByUserId: Map<string, AdminUserAnalytics>;
  busyUserId: string | null;
  canManageRoles: boolean;
  closeActionsMenu: () => void;
  currentPage: number;
  handleToggleActionsMenu: (userId: string) => void;
  isUserActionLocked: boolean;
  isUsersFetching: boolean;
  locale: Locale;
  openActionsUserId: string | null;
  openWalletDialog: (userId: string, operation: "credit" | "debit") => void;
  pageSubscriptionsByUserId: Map<string, AdminEconomyUserSubscriptionSummary>;
  pagedUsers: UserListItem[];
  requestActiveChange: (user: UserListItem) => void;
  requestPremiumChange: (user: UserListItem) => void;
  resetUsersSelection: (nextPage?: number) => void;
  setSelectedUserId: (userId: string) => void;
  text: Dictionary;
  totalPages: number;
  triggerRefs: MutableRefObject<Record<string, HTMLButtonElement | null>>;
  ui: UsersManagementPageText;
  usersPageTotalCount: number;
};

export function UsersManagementUsersTable({
  analyticsByUserId,
  busyUserId,
  canManageRoles,
  closeActionsMenu,
  currentPage,
  handleToggleActionsMenu,
  isUserActionLocked,
  isUsersFetching,
  locale,
  openActionsUserId,
  openWalletDialog,
  pageSubscriptionsByUserId,
  pagedUsers,
  requestActiveChange,
  requestPremiumChange,
  resetUsersSelection,
  setSelectedUserId,
  text,
  totalPages,
  triggerRefs,
  ui,
  usersPageTotalCount,
}: UsersManagementUsersTableProps) {
  return (
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
              <th>{text.userIdLabel}</th>
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
                  <td data-label={text.userIdLabel} className={adminTableStyles.mono}>
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
                    <AdminStatusBadge color={accountStatusColors[status]}>
                      {status === "blocked"
                        ? ui.blockedBadge
                        : status === "unconfirmed"
                          ? ui.unconfirmedBadge
                          : ui.activeBadge}
                    </AdminStatusBadge>
                  </td>
                  <td data-label={ui.premiumAndExpiry}>
                    <div className={styles.stackCell}>
                      <AdminStatusBadge
                        color={
                          user.isPremium ? premiumStatusColors.premium : premiumStatusColors.free
                        }
                      >
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
                  <td data-label={ui.registeredAt}>{formatDateTime(user.createdAtUtc, locale)}</td>
                  <td data-label={ui.lastActivity}>
                    {formatDateTime(
                      user.lastActivityAtUtc ?? rowAnalytics?.summary.lastActivityAtUtc ?? null,
                      locale
                    )}
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
                          {user.isPremium ? (
                            <button
                              type="button"
                              className={styles.quickActionBtn}
                              disabled={isBusy}
                              onClick={() => requestPremiumChange(user)}
                            >
                              {text.removePremium}
                            </button>
                          ) : null}
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
          {ui.usersCount}: {usersPageTotalCount}
        </div>
        <div className={styles.paginationControls}>
          <Button
            variant="ghost"
            size="sm"
            onClick={() => resetUsersSelection(Math.max(1, currentPage - 1))}
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
            onClick={() => resetUsersSelection(Math.min(totalPages, currentPage + 1))}
            disabled={currentPage >= totalPages || isUsersFetching}
            aria-label={ui.nextPageLabel}
            title={ui.nextPageLabel}
          >
            <CaretDownIcon className={`${styles.pageIcon} ${styles.pageIconNext}`} />
          </Button>
        </div>
      </div>
    </>
  );
}
