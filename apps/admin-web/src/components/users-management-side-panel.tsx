"use client";

import Link from "next/link";
import { createPortal } from "react-dom";

import { AdminBadge, AdminStateCard } from "@/components/admin/admin-primitives";
import { formatSupportMessagePreview } from "@/components/support/support-message-preview";
import { Button } from "@/components/ui/button";
import { UserAvatarView } from "@/components/users/user-avatar";
import { formatLabeledMetric } from "@/components/users/user-monetization-format";
import {
  getUserAvatarLabel,
  getUserRoleLabel,
  getUserRoleTone,
} from "@/components/users-management-page.helpers";
import styles from "@/components/users-management-page.module.css";
import type { UsersManagementSidePanelProps } from "@/components/users-management-page.types";
import { getAdminErrorMessage } from "@/lib/admin-error-message";
import { formatDateTime } from "@/lib/format-date-time";
import {
  getAdminUserDisplayName,
  maskEmail,
  sanitizeSensitiveText,
  shortIdentifier,
} from "@/lib/sensitive-display";

export function UsersManagementSidePanel({
  busyUserId,
  canManageRoles,
  closePanel,
  isUserActionLocked,
  locale,
  requestActiveChange,
  requestDeleteUser,
  requestSelectedUserProfileRetry,
  selectedSubscription,
  selectedUser,
  selectedUserAnalytics,
  selectedUserId,
  selectedUserProfile,
  selectedUserSupportTickets,
  text,
  ui,
}: UsersManagementSidePanelProps) {
  if (!selectedUserId || typeof window === "undefined") {
    return null;
  }

  return createPortal(
    <div className={styles.sidePanelBackdrop} onClick={closePanel}>
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
          <button type="button" className={styles.closeBtn} onClick={closePanel}>
            {ui.closePanel}
          </button>
        </header>

        {selectedUserProfile.hasError && !selectedUser ? (
          <AdminStateCard
            tone="danger"
            title={getAdminErrorMessage(selectedUserProfile.error, text.errorLoadingUsers)}
            action={
              <Button
                variant="secondary"
                size="sm"
                disabled={selectedUserProfile.isFetching}
                onClick={requestSelectedUserProfileRetry}
              >
                {text.supportRetryAction}
              </Button>
            }
          />
        ) : !selectedUser ? (
          <AdminStateCard tone="info" title={text.loading} />
        ) : (
          <div className={styles.sidePanelContent}>
            {selectedUserProfile.hasError ? (
              <AdminStateCard
                tone="warning"
                title={getAdminErrorMessage(selectedUserProfile.error, text.errorLoadingUsers)}
                action={
                  <Button
                    variant="secondary"
                    size="sm"
                    disabled={selectedUserProfile.isFetching}
                    onClick={requestSelectedUserProfileRetry}
                  >
                    {text.supportRetryAction}
                  </Button>
                }
              />
            ) : null}

            <section className={styles.panelSection}>
              <h4>{ui.sectionProfile}</h4>
              <div className={styles.profileRow}>
                <UserAvatarView
                  avatar={selectedUser.avatar}
                  label={`${text.avatarLabel}: ${getUserAvatarLabel(selectedUser)}`}
                  fallbackLabel={getUserAvatarLabel(selectedUser)}
                  size="lg"
                />
                <div>
                  <p className={styles.profileTitle}>
                    {sanitizeSensitiveText(getAdminUserDisplayName(selectedUser), 96)}
                  </p>
                  <p className={styles.profileSub}>{maskEmail(selectedUser.email)}</p>
                  <p className={styles.profileSub}>{shortIdentifier(selectedUser.userId)}</p>
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
                  {selectedUser.emailConfirmed ? text.emailConfirmedLabel : ui.unconfirmedBadge}
                </AdminBadge>
              </div>
            </section>

            <section className={styles.panelSection}>
              <h4>{ui.sectionPremium}</h4>
              <p>
                {selectedSubscription
                  ? `${sanitizeSensitiveText(selectedSubscription.status, 48)} • ${formatDateTime(
                      selectedSubscription.currentPeriodEndUtc,
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
                      <strong>{sanitizeSensitiveText(ticket.status, 48)}</strong>
                      <span>{formatDateTime(ticket.updatedAtUtc, locale)}</span>
                      <span>{formatSupportMessagePreview(ticket.lastMessagePreview, "—")}</span>
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
                      <strong>
                        {formatLabeledMetric(ui.purchasedSparkLabel, purchase.sparkToGrant)}
                      </strong>
                      <span>
                        {purchase.priceAmount} {sanitizeSensitiveText(purchase.currencyCode, 12)}
                      </span>
                      <span>
                        {formatDateTime(purchase.confirmedAtUtc ?? purchase.createdAtUtc, locale)}
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
                      <strong>{sanitizeSensitiveText(generation.templateTitle, 120)}</strong>
                      <span>{sanitizeSensitiveText(generation.status, 48)}</span>
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
                      <strong>{sanitizeSensitiveText(event.action, 120)}</strong>
                      <span>{formatDateTime(event.occurredAtUtc, locale)}</span>
                      <span>{sanitizeSensitiveText(event.details, 180)}</span>
                    </article>
                  ))}
                </div>
              ) : (
                <p>{ui.noData}</p>
              )}
            </section>

            {canManageRoles ? (
              <section className={`${styles.panelSection} ${styles.dangerZone}`}>
                <h4>{ui.sectionDanger}</h4>
                <div className={styles.dangerActions}>
                  <button
                    type="button"
                    className={styles.dangerBtn}
                    disabled={isUserActionLocked || busyUserId === selectedUser.userId}
                    onClick={() => requestActiveChange(selectedUser)}
                  >
                    {selectedUser.isActive ? text.deactivate : text.activate}
                  </button>
                  <button
                    type="button"
                    className={styles.dangerBtn}
                    disabled={isUserActionLocked || busyUserId === selectedUser.userId}
                    onClick={() => requestDeleteUser(selectedUser, closePanel)}
                  >
                    {text.usersDeleteAction}
                  </button>
                  <Link
                    href={`/${locale}/users/${encodeURIComponent(selectedUser.userId)}`}
                    className={styles.profileLinkBtn}
                  >
                    {ui.sideOpenFullProfile}
                  </Link>
                </div>
              </section>
            ) : null}
          </div>
        )}
      </aside>
    </div>,
    document.body
  );
}
