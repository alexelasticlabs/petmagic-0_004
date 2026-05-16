"use client";

import { AdminCard, AdminPageHero, AdminStatusBadge, adminTableStyles } from "@/components/admin/admin-primitives";
import { Button } from "@/components/ui/button";
import { Toast } from "@/components/ui/toast";
import styles from "@/components/users-table.module.css";
import { useUsersAdmin } from "@/components/users/use-users-admin";
import {
    assignRole,
    revokeRole,
    setActive,
    setPremium,
} from "@/lib/api-client";
import { getDictionary, type Locale } from "@/lib/i18n";

type UsersTableProps = {
  locale: Locale;
};

export function UsersTable({ locale }: UsersTableProps) {
  const text = getDictionary(locale);
  const { busyUserId, canManageRoles, error, isLoading, runAction, toast, users } = useUsersAdmin(locale);
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
      <div className={styles.page}>
        {hero}
        <AdminCard title={text.usersTitle} description={text.usersLoadingDescription}>
          <div className={styles.skeletonStack} aria-busy="true" aria-live="polite">
            {Array.from({ length: 6 }).map((_, index) => (
              <div key={index} className={styles.skeletonLine} />
            ))}
          </div>
        </AdminCard>
      </div>
    );
  }

  return (
    <div className={styles.page}>
      {hero}
      <AdminCard
        title={text.usersTitle}
        description={text.usersCardDescription}
      >
        {error ? <p className={styles.message}>{error}</p> : null}

        {!users.length ? (
          <div className={styles.emptyState}>
            <p className={styles.emptyTitle}>{text.noUsers}</p>
            <p className={styles.emptyDescription}>{text.usersEmptyDescription}</p>
          </div>
        ) : null}

        {!!users.length && (
          <div className={adminTableStyles.tableWrap}>
            <table className={adminTableStyles.table}>
            <thead>
              <tr>
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
                    <td data-label={text.emailLabel}>{user.email}</td>
                    <td data-label={text.roleLabel}>
                      <div className={styles.roleList}>
                        {user.roles.map((role) => (
                          <span key={role} className={styles.rolePill}>{role}</span>
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
                          {user.isPremium ? text.removePremium : text.makePremium}
                        </Button>
                        <Button
                          variant="secondary"
                          size="sm"
                          className={styles.adminButton}
                          disabled={isBusy}
                          onClick={() => runAction(user.userId, () => setActive(user.userId, !user.isActive))}
                        >
                          {user.isActive ? text.deactivate : text.activate}
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
                              {isModerator ? text.revokeModerator : text.assignModerator}
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
                              {isAdmin ? text.revokeAdmin : text.assignAdmin}
                            </Button>
                          </>
                        )}
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

      {toast ? <Toast message={toast.message} type={toast.type} /> : null}
    </div>
  );
}
