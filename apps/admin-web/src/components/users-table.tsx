"use client";

import Link from "next/link";
import { useState } from "react";

import {
    CancelCircleIcon,
    DollarIcon,
    RefreshIcon,
    UsersIcon,
} from "@/components/admin/admin-icons";
import { AdminBadge, AdminCard, AdminPage, AdminPageHero, AdminStateCard, AdminStatusBadge, adminTableStyles, type AdminTone } from "@/components/admin/admin-primitives";
import { Button } from "@/components/ui/button";
import { Toast } from "@/components/ui/toast";
import { useUsersAdmin } from "@/components/users/use-users-admin";
import { UserAvatarView } from "@/components/users/user-avatar";
import { UserInlineAnalytics } from "@/components/users/user-inline-analytics";
import styles from "@/components/users-table.module.css";
import {
    assignRole,
    revokeRole,
    setActive,
    setPremium,
} from "@/lib/api-client";
import { getDictionary, type Dictionary, type Locale } from "@/lib/i18n";

type UsersTableProps = {
  locale: Locale;
};

type UserRoleText = Pick<Dictionary, "userRoleAdmin" | "userRoleModerator" | "userRoleUser">;

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

export function UsersTable({ locale }: UsersTableProps) {
  const text = getDictionary(locale);
  const { busyUserId, canManageRoles, error, isLoading, runAction, toast, users } = useUsersAdmin(locale);
  const [selectedUserId, setSelectedUserId] = useState<string | null>(null);
  const effectiveSelectedUserId = !users.length
    ? null
    : selectedUserId && users.some((user) => user.userId === selectedUserId)
      ? selectedUserId
      : users[0].userId;
  const hero = (
    <AdminPageHero
      eyebrow={text.usersHeroEyebrow}
      title={text.usersTitle}
      description={text.usersHeroDescription}
      badge={text.usersHeroBadge}
      metaItems={[
        `${text.usersMetaCountLabel}: ${users.length}`,
        canManageRoles ? text.usersMetaAdminEnabled : text.usersMetaViewOnly,
        text.usersMetaLiveControls,
      ]}
    />
  );

  if (isLoading) {
    return (
      <AdminPage className={styles.page}>
        {hero}
        <AdminStateCard tone="info" title={text.usersTitle} description={text.usersLoadingDescription}>
          <div className={styles.skeletonStack} aria-busy="true" aria-live="polite">
            {Array.from({ length: 6 }).map((_, index) => (
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
      <AdminCard
        title={text.usersTitle}
        description={text.usersCardDescription}
      >
        {error ? <AdminStateCard tone="danger" className={styles.message} title={error} /> : null}

        {!users.length ? (
          <AdminStateCard tone="info" className={styles.emptyState} title={text.noUsers} description={text.usersEmptyDescription} />
        ) : null}

        {!!users.length && (
          <div className={adminTableStyles.tableWrap}>
            <table className={adminTableStyles.table}>
            <thead>
              <tr>
                <th>{text.avatarLabel}</th>
                <th>{text.emailLabel}</th>
                <th>{text.roleLabel}</th>
                <th>{text.premiumLabel}</th>
                <th>{text.activeLabel}</th>
                <th>{text.actionsLabel}</th>
              </tr>
            </thead>
            <tbody>
              {users.map((user) => {
                const isBusy = busyUserId === user.userId;
                const isModerator = user.roles.includes("Moderator");
                const isAdmin = user.roles.includes("Admin");

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
                      <button type="button" className={`${styles.userAnchor} ${effectiveSelectedUserId === user.userId ? styles.userAnchorActive : ""}`} onClick={() => setSelectedUserId(user.userId)}>
                        <span>{user.email}</span>
                      </button>
                    </td>
                    <td data-label={text.roleLabel}>
                      <div className={styles.roleList}>
                        {user.roles.map((role) => (
                          <AdminBadge key={role} tone={getUserRoleTone(role)} className={styles.rolePill}>{getUserRoleLabel(role, text)}</AdminBadge>
                        ))}
                      </div>
                    </td>
                    <td data-label={text.premiumLabel}>
                      <AdminStatusBadge color={user.isPremium ? "#22c55e" : "#8da1ba"}>
                        {user.isPremium ? text.yesLabel : text.noLabel}
                      </AdminStatusBadge>
                    </td>
                    <td data-label={text.activeLabel}>
                      <AdminStatusBadge color={user.isActive ? "#2dd4bf" : "#f87171"}>
                        {user.isActive ? text.yesLabel : text.noLabel}
                      </AdminStatusBadge>
                    </td>
                    <td data-label={text.actionsLabel} className={styles.actionsCell}>
                      <div className={styles.actions}>
                        <Button
                          variant="secondary"
                          size="sm"
                          className={styles.adminButtonPrimary}
                          disabled={isBusy}
                          onClick={() => runAction(user.userId, () => setPremium(user.userId, !user.isPremium))}
                        >
                          <DollarIcon className={styles.buttonIcon} />
                          <span>{user.isPremium ? text.removePremium : text.makePremium}</span>
                        </Button>
                        <Button
                          variant="secondary"
                          size="sm"
                          className={styles.adminButton}
                          disabled={isBusy}
                          onClick={() => runAction(user.userId, () => setActive(user.userId, !user.isActive))}
                        >
                          {user.isActive ? <CancelCircleIcon className={styles.buttonIcon} /> : <RefreshIcon className={styles.buttonIcon} />}
                          <span>{user.isActive ? text.deactivate : text.activate}</span>
                        </Button>
                        {canManageRoles && (
                          <>
                            <Button
                              variant="ghost"
                              size="sm"
                              className={styles.adminButton}
                              disabled={isBusy}
                              onClick={() =>
                                runAction(user.userId, () =>
                                  isModerator ? revokeRole(user.userId, "Moderator") : assignRole(user.userId, "Moderator")
                                )
                              }
                            >
                              <UsersIcon className={styles.buttonIcon} />
                              <span>{isModerator ? text.revokeModerator : text.assignModerator}</span>
                            </Button>
                            <Button
                              variant="ghost"
                              size="sm"
                              className={styles.adminButton}
                              disabled={isBusy}
                              onClick={() =>
                                runAction(user.userId, () =>
                                  isAdmin ? revokeRole(user.userId, "Admin") : assignRole(user.userId, "Admin")
                                )
                              }
                            >
                              <UsersIcon className={styles.buttonIcon} />
                              <span>{isAdmin ? text.revokeAdmin : text.assignAdmin}</span>
                            </Button>
                          </>
                        )}
                        <Link href={`/${locale}/users/${user.userId}`} className={styles.inlineLink}>
                          <span>{text.openLabel}</span>
                        </Link>
                        <button type="button" className={`${styles.inlineLink} ${styles.analyticsButton}`} onClick={() => setSelectedUserId(user.userId)}>
                          <span>{text.userDetailOpen}</span>
                        </button>
                      </div>
                    </td>
                  </tr>
                );
              })}
            </tbody>
            </table>
          </div>
        )}
      </AdminCard>

      <UserInlineAnalytics locale={locale} userId={effectiveSelectedUserId} />

      {toast ? <Toast message={toast.message} type={toast.type} /> : null}
    </AdminPage>
  );
}
