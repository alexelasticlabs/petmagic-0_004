"use client";

import { useQuery } from "@tanstack/react-query";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useMemo, type ReactNode } from "react";

import {
  ArrowUpSmallIcon,
  CalendarIcon,
  CancelCircleIcon,
  CaretDownIcon,
  CartIcon,
  ChartIcon,
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
  AdminStateCard,
  AdminStatusBadge,
  adminTableStyles,
} from "@/components/admin/admin-primitives";
import { ensureAdminSession } from "@/components/admin/admin-session";
import { DonutChart, RevenueChart } from "@/components/dashboard/dashboard-charts";
import { getDashboardCopy } from "@/components/dashboard-view.content";
import {
  capitalizeTone,
  DASHBOARD_ORDER_STATUS_COLORS,
  loadDashboardViewModel,
  type DashboardActivityType,
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

export function DashboardView({ locale }: DashboardViewProps) {
  const router = useRouter();
  const session = useAuthSession();
  const canViewDashboard = session?.user.roles.includes("Admin") ?? false;
  const dashboardQuery = useQuery<DashboardViewModel>({
    queryKey: adminQueryKeys.dashboard(locale),
    queryFn: ({ signal }) => loadDashboardViewModel(locale, signal),
    enabled: canViewDashboard,
    staleTime: 60_000,
  });

  useEffect(() => {
    ensureAdminSession(locale, router, { requiredRole: "Admin" });
  }, [locale, router, session]);

  const viewModel = dashboardQuery.data;
  const copy = useMemo(() => getDashboardCopy(locale), [locale]);
  const isShowingStaleDashboard = Boolean(viewModel && dashboardQuery.isError);
  const retryLabel = dashboardQuery.isFetching ? copy.states.refreshing : copy.states.retry;

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

      <AdminPageGrid columns="four" className={styles.statsGrid}>
        {viewModel.stats.map((stat) => (
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
          />
        ))}
      </AdminPageGrid>

      <div className={styles.contentGrid}>
        <AdminCard
          className={styles.wideCard}
          title={
            <span className={styles.cardTitleWithIcon}>
              <ChartIcon className={styles.cardTitleIcon} />
              <span>{viewModel.revenueChart.title}</span>
            </span>
          }
          description={viewModel.revenueChart.description}
          action={
            <AdminBadge tone="info" className={styles.chartToolbar}>
              <CalendarIcon className={styles.toolbarIcon} />
              {viewModel.revenueChart.rangeLabel}
              <CaretDownIcon className={styles.toolbarChevron} />
            </AdminBadge>
          }
        >
          <RevenueChart
            xLabels={viewModel.revenueChart.xLabels}
            values={viewModel.revenueChart.values}
            currencyCode={viewModel.revenueChart.currencyCode}
            ariaLabel={viewModel.revenueChart.ariaLabel}
          />
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
          {viewModel.feedErrors.purchases ? (
            <AdminStateCard
              tone="warning"
              title={copy.states.ordersUnavailableTitle}
              description={copy.states.ordersUnavailableDescription}
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
                      <td className={adminTableStyles.mono}>{order.id}</td>
                      <td>{order.user}</td>
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
            <AdminStateCard
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
          {viewModel.feedErrors.purchases || viewModel.feedErrors.supportConversations ? (
            <AdminStateCard
              tone="warning"
              className={styles.feedWarning}
              title={copy.states.activityUnavailableTitle}
              description={copy.states.activityUnavailableDescription}
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
          {viewModel.activities.length > 0 ? (
            <ul className={styles.activityList}>
              {viewModel.activities.map((activity) => (
                <li key={activity.id} className={styles.activityItem}>
                  <ActivityIcon type={activity.type} />
                  <div className={styles.activityBody}>
                    <p className={styles.activityText}>{activity.text}</p>
                    <p className={styles.activityTime}>{activity.time}</p>
                  </div>
                </li>
              ))}
            </ul>
          ) : viewModel.feedErrors.purchases || viewModel.feedErrors.supportConversations ? null : (
            <AdminStateCard
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
