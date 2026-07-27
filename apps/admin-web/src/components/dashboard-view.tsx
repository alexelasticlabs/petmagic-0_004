"use client";

import { useQuery } from "@tanstack/react-query";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useMemo, useState, type ReactNode } from "react";

import {
  ArrowUpSmallIcon,
  CalendarIcon,
  CancelCircleIcon,
  CartIcon,
  ChartIcon,
  CheckIcon,
  DashboardIcon,
  DollarIcon,
  PeopleIcon,
  RefreshIcon,
  TableIcon,
  TrendUpIcon,
  UserRegisterIcon,
  UsersIcon,
} from "@/components/admin/admin-icons";
import {
  AdminBadge,
  AdminCard,
  AdminPage,
  AdminPageGrid,
  AdminPageHero,
  AdminStatCard,
  AdminSectionHeader,
  AdminStateCard,
  AdminStatusBadge,
  adminTableStyles,
} from "@/components/admin/admin-primitives";
import { ensureAdminSession } from "@/components/admin/admin-session";
import { DonutChart, RevenueChart } from "@/components/dashboard/dashboard-charts";
import { DashboardOperationsHealth } from "@/components/dashboard-operations-health";
import {
  DASHBOARD_COMMERCE_PERIOD_DAYS,
  getDashboardCopy,
  getDashboardIntlLocale,
  type DashboardCommercePeriodDays,
  type DashboardStatSection,
} from "@/components/dashboard-view.content";
import {
  capitalizeTone,
  DASHBOARD_ORDER_STATUS_COLORS,
  getAdminSystemStatusExpiresAt,
  isAdminSystemStatusExpired,
  loadDashboardViewModel,
  type DashboardActivityType,
  type DashboardDataSource,
  type DashboardStatIcon,
  type DashboardViewModel,
} from "@/components/dashboard-view.model";
import styles from "@/components/dashboard-view.module.css";
import { Button } from "@/components/ui/button";
import { adminQueryKeys } from "@/lib/admin-query-keys";
import { useAuthSession } from "@/lib/api-client";
import { type Locale } from "@/lib/i18n";

type DashboardViewProps = { locale: Locale };

const STAT_ICONS: Record<DashboardStatIcon, ReactNode> = {
  people: <PeopleIcon />,
  cart: <CartIcon />,
  dollar: <DollarIcon />,
  trendUp: <TrendUpIcon />,
};

const DASHBOARD_STAT_SECTIONS: DashboardStatSection[] = ["overview", "commerce", "operations"];

const DASHBOARD_STAT_SECTION_SOURCES: Record<DashboardStatSection, readonly DashboardDataSource[]> =
  {
    overview: ["userMetrics", "economyMetrics"],
    commerce: ["userMetrics", "economyMetrics"],
    operations: ["generationMetrics", "moderationQueue"],
  };

const DASHBOARD_ACTIVITY_SOURCES = [
  "recentUsers",
  "purchases",
  "supportConversations",
] as const satisfies readonly DashboardDataSource[];

type DashboardSectionNoticeProps = {
  title: string;
  description: string;
  tone?: "info" | "warning" | "success";
  action?: ReactNode;
  icon?: ReactNode;
};

function DashboardSectionNotice({
  title,
  description,
  tone = "info",
  action,
  icon,
}: DashboardSectionNoticeProps) {
  const toneClass = {
    info: styles.sectionNoticeInfo,
    warning: styles.sectionNoticeWarning,
    success: styles.sectionNoticeSuccess,
  }[tone];

  return (
    <div className={`${styles.sectionNotice} ${toneClass}`} role="status">
      {icon ? <span className={styles.sectionNoticeIcon}>{icon}</span> : null}
      <div className={styles.sectionNoticeCopy}>
        <strong className={styles.sectionNoticeTitle}>{title}</strong>
        <p className={styles.sectionNoticeDescription}>{description}</p>
      </div>
      {action ? <div className={styles.sectionNoticeAction}>{action}</div> : null}
    </div>
  );
}

function hasDashboardSourceError(
  viewModel: DashboardViewModel,
  sources: readonly DashboardDataSource[]
): boolean {
  return sources.some((source) => viewModel.sourceErrors[source]);
}

function ActivityIcon({ type }: { type: DashboardActivityType }) {
  const configs: Record<DashboardActivityType, { className: string; icon: ReactNode }> = {
    new: { className: styles.activityIconSuccess, icon: <CartIcon /> },
    update: { className: styles.activityIconInfo, icon: <RefreshIcon /> },
    register: { className: styles.activityIconBrand, icon: <UserRegisterIcon /> },
    cancel: { className: styles.activityIconDanger, icon: <CancelCircleIcon /> },
  };
  const config = configs[type];

  return <div className={`${styles.activityIcon} ${config.className}`}>{config.icon}</div>;
}

function systemStatusTone(status: "healthy" | "degraded" | "unhealthy") {
  if (status === "healthy") return "success" as const;
  if (status === "degraded") return "warning" as const;
  return "danger" as const;
}

export function DashboardView({ locale }: DashboardViewProps) {
  const router = useRouter();
  const session = useAuthSession();
  const canViewDashboard = session?.user.roles.includes("Admin") ?? false;
  const [commercePeriodDays, setCommercePeriodDays] = useState<DashboardCommercePeriodDays>(7);
  const [systemStatusExpiryRevision, setSystemStatusExpiryRevision] = useState(0);
  const dashboardQuery = useQuery<DashboardViewModel>({
    queryKey: adminQueryKeys.dashboard(locale, commercePeriodDays),
    queryFn: ({ signal }) => loadDashboardViewModel(locale, commercePeriodDays, signal),
    enabled: canViewDashboard,
    staleTime: 60_000,
    refetchInterval: 60_000,
    refetchIntervalInBackground: false,
  });

  useEffect(() => {
    ensureAdminSession(locale, router, { requiredRole: "Admin" });
  }, [locale, router, session]);

  const viewModel = dashboardQuery.data;
  const copy = useMemo(() => getDashboardCopy(locale), [locale]);
  const systemStatus = viewModel?.systemStatus ?? null;
  const systemStatusExpired = systemStatus ? isAdminSystemStatusExpired(systemStatus) : false;

  useEffect(() => {
    if (!systemStatus) {
      return;
    }

    const expiresAt = getAdminSystemStatusExpiresAt(systemStatus);
    if (expiresAt === null) {
      return;
    }

    const delayMs = expiresAt - Date.now();
    if (delayMs <= 0) {
      return;
    }

    const timeoutId = window.setTimeout(
      () => setSystemStatusExpiryRevision((revision) => revision + 1),
      Math.min(delayMs + 25, 2_147_483_647)
    );
    return () => window.clearTimeout(timeoutId);
  }, [systemStatus, systemStatusExpiryRevision]);

  const isShowingStaleDashboard = Boolean(viewModel && dashboardQuery.isError);
  const retryLabel = dashboardQuery.isFetching ? copy.states.refreshing : copy.states.retry;
  const refreshLabel = dashboardQuery.isFetching ? copy.states.refreshing : copy.states.refresh;
  const lastUpdatedLabel = dashboardQuery.dataUpdatedAt
    ? copy.states.lastUpdated(
        new Intl.DateTimeFormat(getDashboardIntlLocale(locale), {
          hour: "2-digit",
          minute: "2-digit",
        }).format(new Date(dashboardQuery.dataUpdatedAt))
      )
    : null;

  function requestDashboardRetry() {
    if (!canViewDashboard || dashboardQuery.isFetching) {
      return;
    }

    void dashboardQuery.refetch().catch(() => undefined);
  }

  if (!viewModel) {
    return (
      <AdminPage className={styles.dashboard}>
        <AdminPageHero
          eyebrow={copy.hero.eyebrow}
          title={copy.hero.title}
          description={copy.hero.description}
        />
        <AdminStateCard
          title={
            dashboardQuery.isError
              ? copy.states.dashboardLoadErrorTitle
              : copy.states.dashboardLoadingTitle
          }
          description={
            dashboardQuery.isError
              ? copy.states.dashboardLoadErrorDescription
              : copy.states.dashboardLoadingDescription
          }
          tone={dashboardQuery.isError ? "danger" : "info"}
          action={
            dashboardQuery.isError ? (
              <Button
                variant="primary"
                onClick={requestDashboardRetry}
                disabled={!canViewDashboard || dashboardQuery.isFetching}
              >
                {retryLabel}
              </Button>
            ) : undefined
          }
        />
      </AdminPage>
    );
  }

  return (
    <AdminPage className={styles.dashboard}>
      <AdminPageHero
        eyebrow={viewModel.hero.eyebrow}
        title={viewModel.hero.title}
        description={viewModel.hero.description}
        actions={
          <Button
            variant="secondary"
            size="sm"
            onClick={requestDashboardRetry}
            disabled={!canViewDashboard || dashboardQuery.isFetching}
            aria-busy={dashboardQuery.isFetching}
          >
            <RefreshIcon className={styles.refreshActionIcon} />
            {refreshLabel}
          </Button>
        }
        metaItems={lastUpdatedLabel ? [lastUpdatedLabel] : undefined}
      />

      {isShowingStaleDashboard ? (
        <AdminStateCard
          tone="warning"
          title={copy.states.staleTitle}
          description={copy.states.staleDescription}
          action={
            <Button
              variant="secondary"
              onClick={requestDashboardRetry}
              disabled={!canViewDashboard || dashboardQuery.isFetching}
            >
              {retryLabel}
            </Button>
          }
        />
      ) : null}

      <section className={styles.attentionSection} aria-label={viewModel.attentionSection.title}>
        <AdminSectionHeader
          title={viewModel.attentionSection.title}
          description={viewModel.attentionSection.description}
        />
        {systemStatusExpired ||
        viewModel.attentionSection.state === "partial" ||
        viewModel.attentionSection.state === "issuesPartial" ? (
          <DashboardSectionNotice
            tone="warning"
            title={copy.attentionSection.partialTitle}
            description={copy.attentionSection.partialDescription}
            action={
              <Button
                variant="secondary"
                size="sm"
                onClick={requestDashboardRetry}
                disabled={!canViewDashboard || dashboardQuery.isFetching}
              >
                {retryLabel}
              </Button>
            }
          />
        ) : null}
        {viewModel.attentionSection.items.length > 0 ? (
          <ul className={styles.attentionList}>
            {viewModel.attentionSection.items.map((item) => (
              <li key={item.key} className={styles.attentionItem}>
                <span
                  className={`${styles.attentionIndicator} ${
                    item.tone === "danger"
                      ? styles.attentionIndicatorDanger
                      : styles.attentionIndicatorWarning
                  }`}
                  aria-hidden="true"
                />
                <div className={styles.attentionItemCopy}>
                  <strong className={styles.attentionItemTitle}>{item.label}</strong>
                  <span className={styles.attentionItemDescription}>{item.description}</span>
                </div>
                <strong className={styles.attentionValue}>{item.value}</strong>
                <Link
                  href={item.href}
                  className={styles.attentionLink}
                  aria-label={`${viewModel.attentionSection.openLabel}: ${item.label}`}
                >
                  {viewModel.attentionSection.openLabel}
                </Link>
              </li>
            ))}
          </ul>
        ) : viewModel.attentionSection.state === "allClear" && !systemStatusExpired ? (
          <DashboardSectionNotice
            tone="success"
            icon={<CheckIcon />}
            title={copy.attentionSection.allClearTitle}
            description={copy.attentionSection.allClearDescription}
          />
        ) : null}
      </section>

      <section id="system-status" className={styles.systemStatusSection}>
        <AdminSectionHeader
          title={copy.systemStatusSection.title}
          description={copy.systemStatusSection.description}
        />
        {viewModel.systemStatus && !systemStatusExpired ? (
          <AdminCard
            className={styles.systemStatusCard}
            title={copy.systemStatusSection.overallLabel}
            description={copy.systemStatusSection.updatedAt(
              new Intl.DateTimeFormat(getDashboardIntlLocale(locale), {
                dateStyle: "medium",
                timeStyle: "short",
              }).format(new Date(viewModel.systemStatus.generatedAtUtc))
            )}
            action={
              <AdminBadge tone={systemStatusTone(viewModel.systemStatus.overallStatus)}>
                {copy.systemStatusSection.statusLabels[viewModel.systemStatus.overallStatus]}
              </AdminBadge>
            }
          >
            <ul className={styles.systemStatusGrid}>
              {viewModel.systemStatus.checks.map((check) => (
                <li key={check.key} className={styles.systemStatusCheck}>
                  <div className={styles.systemStatusCheckHeader}>
                    <strong>
                      {copy.systemStatusSection.checkLabels[check.key] ??
                        copy.systemStatusSection.unknownCheck}
                    </strong>
                    <AdminBadge tone={systemStatusTone(check.status)}>
                      {copy.systemStatusSection.statusLabels[check.status]}
                    </AdminBadge>
                  </div>
                  <p>{copy.systemStatusSection.statusDescriptions[check.status]}</p>
                </li>
              ))}
            </ul>
          </AdminCard>
        ) : (
          <DashboardSectionNotice
            tone="warning"
            title={
              systemStatusExpired
                ? copy.systemStatusSection.staleTitle
                : copy.systemStatusSection.unavailableTitle
            }
            description={
              systemStatusExpired
                ? copy.systemStatusSection.staleDescription
                : copy.systemStatusSection.unavailableDescription
            }
            action={
              <Button
                variant="secondary"
                size="sm"
                onClick={requestDashboardRetry}
                disabled={!canViewDashboard || dashboardQuery.isFetching}
              >
                {retryLabel}
              </Button>
            }
          />
        )}
      </section>

      <DashboardOperationsHealth locale={locale} enabled={canViewDashboard} />

      {DASHBOARD_STAT_SECTIONS.map((section) => {
        const stats = viewModel.stats.filter((stat) => stat.section === section);
        const sectionCopy = copy.statSections[section];
        const hasUnavailableStats = hasDashboardSourceError(
          viewModel,
          DASHBOARD_STAT_SECTION_SOURCES[section]
        );

        return (
          <section key={section} className={styles.statsSection} aria-label={sectionCopy.title}>
            <AdminSectionHeader title={sectionCopy.title} description={sectionCopy.description} />
            {hasUnavailableStats ? (
              <DashboardSectionNotice
                tone="warning"
                title={copy.states.sectionUnavailableTitle}
                description={copy.states.sectionUnavailableDescription}
                action={
                  <Button
                    variant="secondary"
                    size="sm"
                    onClick={requestDashboardRetry}
                    disabled={!canViewDashboard || dashboardQuery.isFetching}
                  >
                    {retryLabel}
                  </Button>
                }
              />
            ) : null}
            {stats.length > 0 ? (
              <AdminPageGrid columns="four" className={styles.statsGrid}>
                {stats.map((stat) => (
                  <AdminStatCard
                    key={stat.label}
                    label={stat.label}
                    value={stat.value}
                    delta={
                      <>
                        {stat.isPositiveTrend ? <ArrowUpSmallIcon /> : null} {stat.delta}
                      </>
                    }
                    subtext={stat.subtext}
                    icon={STAT_ICONS[stat.icon]}
                    accentColor={stat.accentColor}
                    href={stat.href}
                    ariaLabel={copy.stats.openSection(stat.label)}
                  />
                ))}
              </AdminPageGrid>
            ) : null}
          </section>
        );
      })}

      <div className={styles.contentGrid}>
        <AdminCard
          className={styles.wideCard}
          title={
            <span className={styles.cardTitleWithIcon}>
              <ChartIcon className={styles.cardTitleIcon} />
              <span>{viewModel.revenueChart?.title ?? copy.revenueChart.title}</span>
            </span>
          }
          description={
            viewModel.revenueChart?.description ??
            copy.revenueChart.description(copy.commercePeriod.options[commercePeriodDays])
          }
          action={
            <div className={styles.chartToolbar}>
              <span className={styles.periodLabel}>{copy.commercePeriod.label}</span>
              <div
                className={styles.periodSelector}
                role="group"
                aria-label={copy.commercePeriod.label}
              >
                {DASHBOARD_COMMERCE_PERIOD_DAYS.map((periodDays) => {
                  const isActive = commercePeriodDays === periodDays;

                  return (
                    <button
                      key={periodDays}
                      type="button"
                      className={isActive ? styles.periodButtonActive : styles.periodButton}
                      disabled={isActive || dashboardQuery.isFetching}
                      aria-pressed={isActive}
                      onClick={() => setCommercePeriodDays(periodDays)}
                    >
                      {copy.commercePeriod.options[periodDays]}
                    </button>
                  );
                })}
              </div>
              <AdminBadge tone="info" className={styles.periodBadge}>
                <CalendarIcon className={styles.toolbarIcon} />
                {viewModel.revenueChart?.rangeLabel ??
                  copy.commercePeriod.options[commercePeriodDays]}
              </AdminBadge>
            </div>
          }
        >
          {viewModel.revenueChart ? (
            <RevenueChart
              xLabels={viewModel.revenueChart.xLabels}
              values={viewModel.revenueChart.values}
              currencyCode={viewModel.revenueChart.currencyCode}
              locale={locale}
              ariaLabel={viewModel.revenueChart.ariaLabel}
              dateHeader={copy.revenueChart.dateHeader}
              revenueHeader={copy.revenueChart.revenueHeader}
            />
          ) : (
            <DashboardSectionNotice
              tone="warning"
              title={copy.states.revenueUnavailableTitle}
              description={copy.states.revenueUnavailableDescription}
              action={
                <Button
                  variant="secondary"
                  size="sm"
                  onClick={requestDashboardRetry}
                  disabled={!canViewDashboard || dashboardQuery.isFetching}
                >
                  {retryLabel}
                </Button>
              }
            />
          )}
        </AdminCard>

        <AdminCard
          title={
            <span className={styles.cardTitleWithIcon}>
              <TableIcon className={styles.cardTitleIcon} />
              <span>{viewModel.ordersSection.title}</span>
            </span>
          }
          description={viewModel.ordersSection.description}
          action={
            <Link href={`/${locale}/economy`} className={styles.cardActionLink}>
              <UsersIcon className={styles.cardActionIcon} />
              <span>{viewModel.ordersSection.viewAllLabel}</span>
            </Link>
          }
        >
          {viewModel.sourceErrors.purchases ? (
            <DashboardSectionNotice
              tone="warning"
              title={copy.states.ordersUnavailableTitle}
              description={copy.states.ordersUnavailableDescription}
              action={
                <Button
                  variant="secondary"
                  size="sm"
                  onClick={requestDashboardRetry}
                  disabled={!canViewDashboard || dashboardQuery.isFetching}
                >
                  {retryLabel}
                </Button>
              }
            />
          ) : viewModel.orders.length > 0 ? (
            <div className={adminTableStyles.tableWrap}>
              <table className={adminTableStyles.table}>
                <thead>
                  <tr>
                    <th>{viewModel.ordersSection.headers.order}</th>
                    <th>{viewModel.ordersSection.headers.user}</th>
                    <th>{viewModel.ordersSection.headers.amount}</th>
                    <th>{viewModel.ordersSection.headers.status}</th>
                  </tr>
                </thead>
                <tbody>
                  {viewModel.orders.map((order) => (
                    <tr key={order.id}>
                      <td className={adminTableStyles.mono}>
                        <Link href={order.orderHref} className={styles.entityLink}>
                          {order.id}
                        </Link>
                      </td>
                      <td>
                        <Link href={order.userHref} className={styles.entityLink}>
                          {order.user}
                        </Link>
                      </td>
                      <td className={adminTableStyles.numeric}>{order.amount}</td>
                      <td>
                        <AdminStatusBadge color={DASHBOARD_ORDER_STATUS_COLORS[order.statusType]}>
                          {order.status}
                        </AdminStatusBadge>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          ) : (
            <DashboardSectionNotice
              tone="info"
              title={copy.states.noPaymentsTitle}
              description={copy.states.noPaymentsDescription}
            />
          )}
        </AdminCard>
      </div>

      <div className={styles.contentGrid}>
        <AdminCard
          title={
            <span className={styles.cardTitleWithIcon}>
              <DashboardIcon className={styles.cardTitleIcon} />
              <span>{viewModel.distributionSection.title}</span>
            </span>
          }
        >
          {viewModel.sourceErrors.userMetrics ? (
            <DashboardSectionNotice
              tone="warning"
              title={copy.states.distributionUnavailableTitle}
              description={copy.states.distributionUnavailableDescription}
              action={
                <Button
                  variant="secondary"
                  size="sm"
                  onClick={requestDashboardRetry}
                  disabled={!canViewDashboard || dashboardQuery.isFetching}
                >
                  {retryLabel}
                </Button>
              }
            />
          ) : (
            <div className={styles.donutLayout}>
              <DonutChart
                label={viewModel.distributionSection.totalLabel}
                total={viewModel.distributionSection.totalValue}
                items={viewModel.userDistribution}
              />
              <div className={styles.legend}>
                {viewModel.userDistribution.map((item) => {
                  return (
                    <div key={item.label} className={styles.legendItem}>
                      <span
                        className={`${styles.legendDot} ${styles[`legendDot${capitalizeTone(item.tone)}`]}`}
                      />
                      <span className={styles.legendLabel}>{item.label}</span>
                      <span className={styles.legendPercent}>{item.pct}</span>
                      <span className={styles.legendCount}>({item.count})</span>
                    </div>
                  );
                })}
              </div>
            </div>
          )}
        </AdminCard>

        <AdminCard
          title={
            <span className={styles.cardTitleWithIcon}>
              <RefreshIcon className={styles.cardTitleIcon} />
              <span>{viewModel.activitySection.title}</span>
            </span>
          }
          description={viewModel.activitySection.description}
        >
          {hasDashboardSourceError(viewModel, DASHBOARD_ACTIVITY_SOURCES) ? (
            <DashboardSectionNotice
              tone="warning"
              title={copy.states.activityUnavailableTitle}
              description={copy.states.activityUnavailableDescription}
              action={
                <Button
                  variant="secondary"
                  size="sm"
                  onClick={requestDashboardRetry}
                  disabled={!canViewDashboard || dashboardQuery.isFetching}
                >
                  {retryLabel}
                </Button>
              }
            />
          ) : null}
          {viewModel.activities.length > 0 ? (
            <ul className={styles.activityList}>
              {viewModel.activities.map((activity) => (
                <li key={activity.id} className={styles.activityItem}>
                  <ActivityIcon type={activity.type} />
                  <Link href={activity.href} className={styles.activityBody}>
                    <p className={styles.activityText}>{activity.text}</p>
                    <p className={styles.activityTime}>{activity.time}</p>
                  </Link>
                </li>
              ))}
            </ul>
          ) : hasDashboardSourceError(viewModel, DASHBOARD_ACTIVITY_SOURCES) ? null : (
            <DashboardSectionNotice
              tone="info"
              title={copy.states.noActivityTitle}
              description={copy.states.noActivityDescription}
            />
          )}
        </AdminCard>
      </div>
    </AdminPage>
  );
}
