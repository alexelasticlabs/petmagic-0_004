"use client";

import { AdminBadge, AdminCard, AdminKpiCard, AdminMetricStrip, AdminStateCard } from "@/components/admin/admin-primitives";
import { useAdminUserProfile } from "@/components/users/use-admin-user-profile";
import { UserAvatarView } from "@/components/users/user-avatar";
import styles from "@/components/users/user-inline-analytics.module.css";
import { UserWalletPanel } from "@/components/users/user-wallet-panel";
import { getDictionary, type Locale } from "@/lib/i18n";
import Link from "next/link";

type UserInlineAnalyticsProps = {
  locale: Locale;
  userId: string | null;
};

export function UserInlineAnalytics({ locale, userId }: UserInlineAnalyticsProps) {
  const text = getDictionary(locale);
  const { analytics, hasError, isLoading, refresh, user } = useAdminUserProfile({ userId });

  if (!userId) {
    return (
      <AdminStateCard tone="info" title={text.userInlineAnalyticsTitle} description={text.userSelectForAnalytics} />
    );
  }

  if (isLoading) {
    return <AdminStateCard tone="info" title={text.userInlineAnalyticsTitle} description={text.loading} />;
  }

  if (hasError || !user || !analytics) {
    return <AdminStateCard tone="danger" title={text.userAnalyticsLoadError} />;
  }

  return (
    <AdminCard
      title={text.userInlineAnalyticsTitle}
      description={text.userInlineAnalyticsDescription}
      action={<Link href={`/${locale}/users/${user.userId}`} className={styles.profileLink}>{text.userOpenFullProfile}</Link>}
    >
      <div className={styles.header}>
        <UserAvatarView avatar={user.avatar} label={`${text.avatarLabel}: ${user.displayName ?? user.email}`} fallbackLabel={user.displayName ?? user.email} size="lg" />
        <div className={styles.identity}>
          <h3>{user.displayName?.trim() || user.email}</h3>
          <p>{user.email}</p>
          <div className={styles.badges}>
            <AdminBadge tone={user.isActive ? "success" : "danger"}>{user.isActive ? text.activeLabel : text.deactivate}</AdminBadge>
            <AdminBadge tone={user.isPremium ? "warning" : "neutral"}>{user.isPremium ? text.premiumLabel : text.freeLabel}</AdminBadge>
            <AdminBadge tone={user.emailConfirmed ? "info" : "neutral"}>{user.emailConfirmed ? text.emailConfirmedLabel : text.noLabel}</AdminBadge>
          </div>
        </div>
      </div>

      <div className={styles.kpiGrid}>
        <AdminKpiCard label={text.tokenBalanceLabel} value={String(analytics.summary.walletBalance)} hint={`${text.tokensGrantedLabel}: ${analytics.summary.totalTokensCredited}`} tone="primary" />
        <AdminKpiCard label={text.loginsLabel} value={String(analytics.summary.successfulLogins)} hint={`${text.failedLoginsLabel}: ${analytics.summary.failedLogins}`} tone="magenta" />
        <AdminKpiCard label={text.viewsLabel} value={String(analytics.summary.totalViews)} hint={`${text.videoViewsLabel}: ${analytics.summary.totalVideoViews}`} tone="info" />
        <AdminKpiCard label={text.totalPurchasesLabel} value={String(analytics.summary.totalPurchases)} hint={`${text.successfulPurchasesLabel}: ${analytics.summary.successfulPurchases}`} tone="info" />
        <AdminKpiCard label={text.totalGenerationsLabel} value={String(analytics.summary.totalGenerations)} hint={`${text.completedGenerationsLabel}: ${analytics.summary.completedGenerations}`} tone="success" />
        <AdminKpiCard label={text.failedGenerationsLabel} value={String(analytics.summary.failedGenerations)} hint={`${text.templateEventsLabel}: ${analytics.summary.templateAnalyticsEvents}`} tone="danger" />
      </div>

      <div className={styles.section}>
        <h4>{text.userActivityTitle}</h4>
        {analytics.recentActivity.length ? (
          <div className={styles.timeline}>
            {analytics.recentActivity.slice(0, 6).map((item) => (
              <article key={`${item.kind}:${item.occurredAtUtc}:${item.title}`} className={styles.timelineItem}>
                <div className={styles.timelineHeader}>
                  <strong>{item.title}</strong>
                  <span>{formatDateTime(item.occurredAtUtc, locale)}</span>
                </div>
                {item.details ? <p>{item.details}</p> : null}
              </article>
            ))}
          </div>
        ) : (
          <AdminStateCard tone="info" title={text.userNoActivity} />
        )}
      </div>

      <div className={styles.dualGrid}>
        <section className={styles.section}>
          <h4>{text.userPurchasesTitle}</h4>
          {analytics.recentPurchases.length ? (
            <div className={styles.list}>
              {analytics.recentPurchases.slice(0, 4).map((purchase) => (
                <article key={purchase.orderId} className={styles.compactCard}>
                  <strong>{purchase.sparkToGrant} spark</strong>
                  <span>{purchase.priceAmount} {purchase.currencyCode}</span>
                  <span>{formatDateTime(purchase.confirmedAtUtc ?? purchase.createdAtUtc, locale)}</span>
                </article>
              ))}
            </div>
          ) : (
            <AdminStateCard tone="info" title={text.userNoPurchases} />
          )}
        </section>

        <section className={styles.section}>
          <h4>{text.userGenerationsTitle}</h4>
          {analytics.recentGenerations.length ? (
            <div className={styles.list}>
              {analytics.recentGenerations.slice(0, 4).map((generation) => (
                <article key={generation.generationId} className={styles.compactCard}>
                  <strong>{generation.templateTitle}</strong>
                  <span>{generation.status} • {generation.tokenCost}</span>
                  <span>{formatDateTime(generation.completedAtUtc ?? generation.createdAtUtc, locale)}</span>
                </article>
              ))}
            </div>
          ) : (
            <AdminStateCard tone="info" title={text.userNoGenerations} />
          )}
        </section>
      </div>

      <div className={styles.section}>
        <h4>{text.userFailureBreakdownTitle}</h4>
        {analytics.failureBreakdown.length ? (
          <AdminMetricStrip
            items={analytics.failureBreakdown.map((item) => ({
              label: item.failureCode,
              value: `${item.count} • ${formatDateTime(item.lastOccurredAtUtc, locale)}`,
            }))}
          />
        ) : (
          <AdminStateCard tone="success" title={text.userNoFailures} />
        )}
      </div>

      <UserWalletPanel
        locale={locale}
        userId={user.userId}
        analytics={analytics}
        onUpdated={async () => {
          await refresh();
        }}
      />
    </AdminCard>
  );
}

function formatDateTime(value: string | null | undefined, locale: Locale) {
  if (!value) {
    return "—";
  }

  return new Intl.DateTimeFormat(locale === "ru" ? "ru-RU" : "en-US", {
    dateStyle: "medium",
    timeStyle: "short",
  }).format(new Date(value));
}
