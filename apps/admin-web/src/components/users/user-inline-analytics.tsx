"use client";

import Link from "next/link";

import {
  AdminBadge,
  AdminCard,
  AdminKpiCard,
  AdminMetricStrip,
  AdminStateCard,
} from "@/components/admin/admin-primitives";
import { Button } from "@/components/ui/button";
import { useAdminUserProfile } from "@/components/users/use-admin-user-profile";
import { UserAvatarView } from "@/components/users/user-avatar";
import styles from "@/components/users/user-inline-analytics.module.css";
import { formatLabeledMetric } from "@/components/users/user-monetization-format";
import { UserWalletPanel } from "@/components/users/user-wallet-panel";
import { useAuthSession } from "@/lib/api-client";
import { formatDateTime } from "@/lib/format-date-time";
import { getDictionary, type Locale } from "@/lib/i18n";
import { getAdminUserDisplayName, maskEmail, sanitizeSensitiveText } from "@/lib/sensitive-display";

type UserInlineAnalyticsProps = {
  locale: Locale;
  userId: string | null;
};

export function UserInlineAnalytics({ locale, userId }: UserInlineAnalyticsProps) {
  const text = getDictionary(locale);
  const session = useAuthSession();
  const canViewUserProfile = session?.user.roles.includes("Admin") ?? false;
  const { analytics, hasError, isFetching, isLoading, refresh, user } = useAdminUserProfile({
    enabled: canViewUserProfile,
    userId,
  });

  function requestUserProfileRetry() {
    if (!canViewUserProfile || isFetching) {
      return;
    }

    void refresh().catch(() => undefined);
  }

  if (!userId) {
    return (
      <AdminStateCard
        tone="info"
        title={text.userInlineAnalyticsTitle}
        description={text.userSelectForAnalytics}
      />
    );
  }

  if (!canViewUserProfile || isLoading) {
    return (
      <AdminStateCard
        tone="info"
        title={text.userInlineAnalyticsTitle}
        description={text.loading}
      />
    );
  }

  if (hasError || !user || !analytics) {
    return (
      <AdminStateCard
        tone="danger"
        title={text.userAnalyticsLoadError}
        action={
          <Button
            variant="secondary"
            size="sm"
            onClick={requestUserProfileRetry}
            disabled={!canViewUserProfile || isFetching}
          >
            {text.supportRetryAction}
          </Button>
        }
      />
    );
  }

  const safeUserName = sanitizeSensitiveText(getAdminUserDisplayName(user), 96);

  return (
    <AdminCard
      title={text.userInlineAnalyticsTitle}
      description={text.userInlineAnalyticsDescription}
      action={
        <Link
          href={`/${locale}/users/${encodeURIComponent(user.userId)}`}
          className={styles.profileLink}
        >
          {text.userOpenFullProfile}
        </Link>
      }
    >
      <div className={styles.header}>
        <UserAvatarView
          avatar={user.avatar}
          label={`${text.avatarLabel}: ${safeUserName}`}
          fallbackLabel={safeUserName}
          size="lg"
        />
        <div className={styles.identity}>
          <h3>{safeUserName}</h3>
          <p>{maskEmail(user.email)}</p>
          <div className={styles.badges}>
            <AdminBadge tone={user.isActive ? "success" : "danger"}>
              {user.isActive ? text.activeLabel : text.blockedLabel}
            </AdminBadge>
            <AdminBadge tone={user.isPremium ? "warning" : "neutral"}>
              {user.isPremium ? text.premiumLabel : text.freeLabel}
            </AdminBadge>
            <AdminBadge tone={user.emailConfirmed ? "info" : "neutral"}>
              {user.emailConfirmed ? text.emailConfirmedLabel : text.noLabel}
            </AdminBadge>
          </div>
        </div>
      </div>

      <div className={styles.kpiGrid}>
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
      </div>

      <div className={styles.section}>
        <h4>{text.userActivityTitle}</h4>
        {analytics.recentActivity.length ? (
          <div className={styles.timeline}>
            {analytics.recentActivity.slice(0, 6).map((item) => (
              <article
                key={`${item.kind}:${item.occurredAtUtc}:${item.title}`}
                className={styles.timelineItem}
              >
                <div className={styles.timelineHeader}>
                  <strong>{sanitizeSensitiveText(item.title, 120)}</strong>
                  <span>{formatDateTime(item.occurredAtUtc, locale)}</span>
                </div>
                {item.details ? <p>{sanitizeSensitiveText(item.details, 180)}</p> : null}
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
                  <strong>
                    {formatLabeledMetric(text.purchasedSparkLabel, purchase.sparkToGrant)}
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
            <AdminStateCard tone="info" title={text.userNoPurchases} />
          )}
        </section>

        <section className={styles.section}>
          <h4>{text.userGenerationsTitle}</h4>
          {analytics.recentGenerations.length ? (
            <div className={styles.list}>
              {analytics.recentGenerations.slice(0, 4).map((generation) => (
                <article key={generation.generationId} className={styles.compactCard}>
                  <strong>{sanitizeSensitiveText(generation.templateTitle, 120)}</strong>
                  <span>
                    {sanitizeSensitiveText(generation.status, 48)} •{" "}
                    {formatLabeledMetric(text.tokenCostLabel, generation.tokenCost)}
                  </span>
                  <span>
                    {formatDateTime(generation.completedAtUtc ?? generation.createdAtUtc, locale)}
                  </span>
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
              label: sanitizeSensitiveText(item.failureCode, 120),
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
        canAdjustWallet={canViewUserProfile}
        onUpdated={async () => {
          await refresh();
        }}
      />
    </AdminCard>
  );
}
