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
import { useAdminUserProfile } from "@/components/users/use-admin-user-profile";
import { UserAvatarView } from "@/components/users/user-avatar";
import styles from "@/components/users/user-detail-page.module.css";
import { UserWalletPanel } from "@/components/users/user-wallet-panel";
import { useAuthSession } from "@/lib/api-client";
import { formatDateTime } from "@/lib/format-date-time";
import { getDictionary, type Locale } from "@/lib/i18n";

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
  const { analytics, hasError, isLoading, refresh, user } = useAdminUserProfile({ userId });

  useEffect(() => {
    if (!session) {
      ensureAdminSession(locale, router);
    }
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

  if (isLoading) {
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
            <Link href={`/${locale}/users`} className={styles.backLink}>
              {text.navUsers}
            </Link>
          }
        />
      </AdminPage>
    );
  }

  return (
    <AdminPage className={styles.page}>
      <AdminPageHero
        eyebrow={text.userDetailsEyebrow}
        title={user.displayName?.trim() || user.email}
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
            label={`${text.avatarLabel}: ${user.displayName ?? user.email}`}
            fallbackLabel={user.displayName ?? user.email}
            size="lg"
          />
          <div className={styles.profileCopy}>
            <h2 className={styles.profileTitle}>{user.displayName?.trim() || user.email}</h2>
            <p className={styles.profileEmail}>{user.email}</p>
            <div className={styles.profileBadges}>
              <AdminBadge tone={user.isActive ? "success" : "danger"}>
                {user.isActive ? text.activeLabel : text.deactivate}
              </AdminBadge>
              <AdminBadge tone={user.isPremium ? "warning" : "neutral"}>
                {user.isPremium ? text.premiumLabel : text.freeLabel}
              </AdminBadge>
              <AdminBadge tone={user.emailConfirmed ? "info" : "neutral"}>
                {user.emailConfirmed ? text.emailConfirmedLabel : text.noLabel}
              </AdminBadge>
              {user.roles.map((role) => (
                <AdminBadge key={role}>{role}</AdminBadge>
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
                    {purchase.status}
                  </AdminStatusBadge>
                </div>
                <p>
                  {purchase.priceAmount} {purchase.currencyCode} • {purchase.paymentProvider}
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
                  <strong>{generation.templateTitle}</strong>
                  <AdminStatusBadge
                    color={
                      generation.status === "Completed"
                        ? "#22c55e"
                        : generation.status === "Failed"
                          ? "#f87171"
                          : "#8da1ba"
                    }
                  >
                    {generation.status}
                  </AdminStatusBadge>
                </div>
                <p>
                  {generation.templateType} • {generation.tokenCost} tokens
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
                  <strong>{event.eventType}</strong>
                  <span>{event.templateTitle}</span>
                </div>
                <p>
                  {event.source} • {event.deviceClass} • {event.countryCode}
                </p>
                {event.feedbackMessage ? <p>{event.feedbackMessage}</p> : null}
                <span>{formatDateTime(event.createdAtUtc, locale)}</span>
              </article>
            ))}
          />
        </AdminCard>

        <AdminCard title={text.userFailureBreakdownTitle}>
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
        </AdminCard>
      </AdminPageGrid>

      <AdminCard title={text.auditEventsLabel}>
        <DataList
          emptyTitle={text.userNoActivity}
          items={analytics.recentAuditEvents.slice(0, AUDIT_ITEMS_LIMIT).map((event) => (
            <article key={event.auditEventId} className={styles.dataCard}>
              <div className={styles.dataHeader}>
                <strong>{event.action}</strong>
                <span>{formatDateTime(event.occurredAtUtc, locale)}</span>
              </div>
              <p>{event.details}</p>
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
