"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { type ReactElement, useEffect, useMemo } from "react";

import {
  AdminBadge,
  AdminCard,
  AdminKpiCard,
  AdminMetricStrip,
  AdminPage,
  AdminPageGrid,
  AdminPageHero,
  AdminStateCard,
  AdminStatusBadge,
} from "@/components/admin/admin-primitives";
import { ensureAdminSession } from "@/components/admin/admin-session";
import { Button } from "@/components/ui/button";
import { useAdminUserProfile } from "@/components/users/use-admin-user-profile";
import { UserAvatarView } from "@/components/users/user-avatar";
import styles from "@/components/users/user-detail-page.module.css";
import { UserWalletPanel } from "@/components/users/user-wallet-panel";
import { useAuthSession } from "@/lib/api-client";
import { formatDateTime } from "@/lib/format-date-time";
import { getDictionary, type Locale } from "@/lib/i18n";
import { getAdminUserDisplayName, maskEmail, sanitizeSensitiveText } from "@/lib/sensitive-display";

type UserDetailPageProps = {
  locale: Locale;
  userId: string;
};

const ACTIVITY_LIMIT = 12;
const RECENT_ITEMS_LIMIT = 8;
const AUDIT_ITEMS_LIMIT = 12;

export function UserDetailPage({ locale, userId }: UserDetailPageProps) {
  const text = getDictionary(locale);
  const router = useRouter();
  const session = useAuthSession();
  const canViewUserProfile = session?.user.roles.includes("Admin") ?? false;
  const { analytics, hasError, isFetching, isLoading, refresh, user } = useAdminUserProfile({
    enabled: canViewUserProfile,
    userId,
  });

  useEffect(() => {
    ensureAdminSession(locale, router, { requiredRole: "Admin" });
  }, [locale, router, session]);

  const metaItems = useMemo(() => {
    if (!user || !analytics) {
      return [];
    }

    return [
      `${text.createdAtLabel}: ${formatDateTime(user.createdAtUtc, locale)}`,
      `${text.lastActivityLabel}: ${formatDateTime(analytics.summary.lastActivityAtUtc, locale)}`,
      `${text.tokenBalanceLabel}: ${analytics.summary.walletBalance}`,
      `${text.loginsLabel}: ${analytics.summary.successfulLogins}`,
      `${text.viewsLabel}: ${analytics.summary.totalViews}`,
    ];
  }, [
    analytics,
    locale,
    text.createdAtLabel,
    text.lastActivityLabel,
    text.loginsLabel,
    text.tokenBalanceLabel,
    text.viewsLabel,
    user,
  ]);

  if (!canViewUserProfile || isLoading) {
    return (
      <AdminPage className={styles.page}>
        <AdminPageHero
          eyebrow={text.userDetailsEyebrow}
          title={text.userDetailsTitle}
          description={text.userDetailsDescription}
        />
        <AdminStateCard tone="info" title={text.loading} description={text.userAnalyticsTitle} />
      </AdminPage>
    );
  }

  if (hasError || !user || !analytics) {
    return (
      <AdminPage className={styles.page}>
        <AdminPageHero
          eyebrow={text.userDetailsEyebrow}
          title={text.userDetailsTitle}
          description={text.userDetailsDescription}
        />
        <AdminStateCard
          tone="danger"
          title={text.userAnalyticsLoadError}
          action={
            <div className={styles.errorActions}>
              <Button
                variant="secondary"
                size="sm"
                onClick={() => {
                  if (!canViewUserProfile) {
                    return;
                  }

                  void refresh().catch(() => undefined);
                }}
                disabled={!canViewUserProfile || isFetching}
              >
                {text.supportRetryAction}
              </Button>
              <Link href={`/${locale}/users`} className={styles.backLink}>
                {text.navUsers}
              </Link>
            </div>
          }
        />
      </AdminPage>
    );
  }

  const safeUserName = sanitizeSensitiveText(getAdminUserDisplayName(user), 96);

  return (
    <AdminPage className={styles.page}>
      <AdminPageHero
        eyebrow={text.userDetailsEyebrow}
        title={safeUserName}
        description={text.userDetailsDescription}
        actions={
          <Link href={`/${locale}/users`} className={styles.backLink}>
            {text.navUsers}
          </Link>
        }
        metaItems={metaItems}
      />

      <AdminCard title={text.userDetailsTitle} description={text.userAnalyticsTitle}>
        <div className={styles.profileHeader}>
          <UserAvatarView
            avatar={user.avatar}
            label={`${text.avatarLabel}: ${safeUserName}`}
            fallbackLabel={safeUserName}
            size="lg"
          />
          <div className={styles.profileCopy}>
            <h2 className={styles.profileTitle}>{safeUserName}</h2>
            <p className={styles.profileEmail}>{maskEmail(user.email)}</p>
            <div className={styles.profileBadges}>
              <AdminBadge tone={user.isActive ? "success" : "danger"}>
                {user.isActive ? text.activeLabel : text.blockedLabel}
              </AdminBadge>
              <AdminBadge tone={user.isPremium ? "warning" : "neutral"}>
                {user.isPremium ? text.premiumLabel : text.freeLabel}
              </AdminBadge>
              <AdminBadge tone={user.emailConfirmed ? "info" : "neutral"}>
                {user.emailConfirmed ? text.emailConfirmedLabel : text.noLabel}
              </AdminBadge>
              {user.roles.map((role) => (
                <AdminBadge key={role}>{sanitizeSensitiveText(role, 32)}</AdminBadge>
              ))}
            </div>
          </div>
          <div className={styles.profileMeta}>
            <Metric label={text.createdAtLabel} value={formatDateTime(user.createdAtUtc, locale)} />
            <Metric
              label={text.lastPurchaseLabel}
              value={formatDateTime(analytics.summary.lastPurchaseAtUtc, locale)}
            />
            <Metric
              label={text.lastGenerationLabel}
              value={formatDateTime(analytics.summary.lastGenerationAtUtc, locale)}
            />
          </div>
        </div>
      </AdminCard>

      <AdminPageGrid columns="four">
        <AdminKpiCard
          label={text.tokenBalanceLabel}
          value={String(analytics.summary.walletBalance)}
          hint={`${text.tokensGrantedLabel}: ${analytics.summary.totalTokensCredited}`}
          tone="primary"
        />
        <AdminKpiCard
          label={text.loginsLabel}
          value={String(analytics.summary.successfulLogins)}
          hint={`${text.failedLoginsLabel}: ${analytics.summary.failedLogins}`}
          tone="magenta"
        />
        <AdminKpiCard
          label={text.viewsLabel}
          value={String(analytics.summary.totalViews)}
          hint={`${text.videoViewsLabel}: ${analytics.summary.totalVideoViews}`}
          tone="info"
        />
        <AdminKpiCard
          label={text.totalPurchasesLabel}
          value={String(analytics.summary.totalPurchases)}
          hint={`${text.successfulPurchasesLabel}: ${analytics.summary.successfulPurchases}`}
          tone="info"
        />
        <AdminKpiCard
          label={text.totalGenerationsLabel}
          value={String(analytics.summary.totalGenerations)}
          hint={`${text.completedGenerationsLabel}: ${analytics.summary.completedGenerations}`}
          tone="success"
        />
        <AdminKpiCard
          label={text.failedGenerationsLabel}
          value={String(analytics.summary.failedGenerations)}
          hint={`${text.templateEventsLabel}: ${analytics.summary.templateAnalyticsEvents}`}
          tone="danger"
        />
      </AdminPageGrid>

      <UserWalletPanel
        locale={locale}
        userId={user.userId}
        analytics={analytics}
        canAdjustWallet={canViewUserProfile}
        onUpdated={async () => {
          await refresh();
        }}
      />

      <AdminCard title={text.userActivityTitle}>
        {analytics.recentActivity.length ? (
          <div className={styles.timeline}>
            {analytics.recentActivity.slice(0, ACTIVITY_LIMIT).map((item) => (
              <article
                key={`${item.kind}:${item.occurredAtUtc}:${item.title}`}
                className={styles.timelineItem}
              >
                <div className={styles.timelineHeader}>
                  <strong>{sanitizeSensitiveText(item.title, 120)}</strong>
                  <span>{formatDateTime(item.occurredAtUtc, locale)}</span>
                </div>
                {item.details ? <p>{sanitizeSensitiveText(item.details, 220)}</p> : null}
              </article>
            ))}
          </div>
        ) : (
          <AdminStateCard tone="info" title={text.userNoActivity} />
        )}
      </AdminCard>

      <AdminPageGrid columns="two">
        <AdminCard title={text.userPurchasesTitle}>
          <DataList
            emptyTitle={text.userNoPurchases}
            items={analytics.recentPurchases.slice(0, RECENT_ITEMS_LIMIT).map((purchase) => (
              <article key={purchase.orderId} className={styles.dataCard}>
                <div className={styles.dataHeader}>
                  <strong>{purchase.sparkToGrant} spark</strong>
                  <AdminStatusBadge color={purchase.status === "succeeded" ? "#2dd4bf" : "#f59e0b"}>
                    {sanitizeSensitiveText(purchase.status, 48)}
                  </AdminStatusBadge>
                </div>
                <p>
                  {purchase.priceAmount} {sanitizeSensitiveText(purchase.currencyCode, 12)} •{" "}
                  {sanitizeSensitiveText(purchase.paymentProvider, 48)}
                </p>
                <span>
                  {formatDateTime(purchase.confirmedAtUtc ?? purchase.createdAtUtc, locale)}
                </span>
              </article>
            ))}
          />
        </AdminCard>

        <AdminCard title={text.userGenerationsTitle}>
          <DataList
            emptyTitle={text.userNoGenerations}
            items={analytics.recentGenerations.slice(0, RECENT_ITEMS_LIMIT).map((generation) => (
              <article key={generation.generationId} className={styles.dataCard}>
                <div className={styles.dataHeader}>
                  <strong>{sanitizeSensitiveText(generation.templateTitle, 120)}</strong>
                  <AdminStatusBadge
                    color={
                      generation.status === "Completed"
                        ? "#22c55e"
                        : generation.status === "Failed"
                          ? "#f87171"
                          : "#8da1ba"
                    }
                  >
                    {sanitizeSensitiveText(generation.status, 48)}
                  </AdminStatusBadge>
                </div>
                <p>
                  {sanitizeSensitiveText(generation.templateType, 48)} • {generation.tokenCost} PawSpark
                </p>
                <span>
                  {formatDateTime(generation.completedAtUtc ?? generation.createdAtUtc, locale)}
                </span>
              </article>
            ))}
          />
        </AdminCard>
      </AdminPageGrid>

      <AdminPageGrid columns="two">
        <AdminCard title={text.userEventsTitle}>
          <DataList
            emptyTitle={text.userNoEvents}
            items={analytics.recentTemplateEvents.slice(0, RECENT_ITEMS_LIMIT).map((event) => (
              <article key={event.eventId} className={styles.dataCard}>
                <div className={styles.dataHeader}>
                  <strong>{sanitizeSensitiveText(event.eventType, 80)}</strong>
                  <span>{sanitizeSensitiveText(event.templateTitle, 120)}</span>
                </div>
                <p>
                  {sanitizeSensitiveText(event.source, 80)} •{" "}
                  {sanitizeSensitiveText(event.deviceClass, 48)} •{" "}
                  {sanitizeSensitiveText(event.countryCode, 16)}
                </p>
                {event.feedbackMessage ? (
                  <p>{sanitizeSensitiveText(event.feedbackMessage, 220)}</p>
                ) : null}
                <span>{formatDateTime(event.createdAtUtc, locale)}</span>
              </article>
            ))}
          />
        </AdminCard>

        <AdminCard title={text.userFailureBreakdownTitle}>
          {analytics.failureBreakdown.length ? (
            <AdminMetricStrip
              items={analytics.failureBreakdown.map((item) => ({
                label: sanitizeSensitiveText(item.failureCode, 120),
                value: `${item.count} • ${formatDateTime(item.lastOccurredAtUtc, locale)}`,
              }))}
            />
          ) : (
            <AdminStateCard tone="success" title={text.userNoFailures} />
          )}
        </AdminCard>
      </AdminPageGrid>

      <AdminCard title={text.auditEventsLabel}>
        <DataList
          emptyTitle={text.userNoActivity}
          items={analytics.recentAuditEvents.slice(0, AUDIT_ITEMS_LIMIT).map((event) => (
            <article key={event.auditEventId} className={styles.dataCard}>
              <div className={styles.dataHeader}>
                <strong>{sanitizeSensitiveText(event.action, 120)}</strong>
                <span>{formatDateTime(event.occurredAtUtc, locale)}</span>
              </div>
              <p>{sanitizeSensitiveText(event.details, 220)}</p>
            </article>
          ))}
        />
      </AdminCard>
    </AdminPage>
  );
}

function DataList({ items, emptyTitle }: { items: ReactElement[]; emptyTitle: string }) {
  if (!items.length) {
    return <AdminStateCard tone="info" title={emptyTitle} />;
  }

  return <div className={styles.dataList}>{items}</div>;
}

function Metric({ label, value }: { label: string; value: string }) {
  return (
    <div className={styles.metric}>
      <span>{label}</span>
      <strong>{value}</strong>
    </div>
  );
}
