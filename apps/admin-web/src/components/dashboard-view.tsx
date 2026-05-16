"use client";

import {
    ArrowUpSmallIcon,
    CancelCircleIcon,
    CartIcon,
    DollarIcon,
    PeopleIcon,
    RefreshIcon,
    TrendUpIcon,
    UserRegisterIcon,
} from "@/components/admin/admin-icons";
import { AdminCard, AdminPageHero, AdminStatCard, AdminStatusBadge, adminTableStyles } from "@/components/admin/admin-primitives";
import styles from "@/components/dashboard-view.module.css";
import { DonutChart, RevenueChart } from "@/components/dashboard/dashboard-charts";
import { buildDashboardViewModel, type DashboardActivityType, type DashboardStatIcon } from "@/components/dashboard/dashboard-view-model";
import { type Locale } from "@/lib/i18n";
import Link from "next/link";
import { type CSSProperties, type ReactNode } from "react";

type DashboardViewProps = { locale: Locale };
const STAT_ICONS: Record<DashboardStatIcon, ReactNode> = {
  people: <PeopleIcon />,
  cart: <CartIcon />,
  dollar: <DollarIcon />,
  trendUp: <TrendUpIcon />,
};

function ActivityIcon({ type }: { type: DashboardActivityType }) {
  const configs: Record<DashboardActivityType, { color: string; path: ReactNode }> = {
    new: { color: "#22c55e", path: <CartIcon /> },
    update: { color: "#60a5fa", path: <RefreshIcon /> },
    register: { color: "#2dd4bf", path: <UserRegisterIcon /> },
    cancel: { color: "#f87171", path: <CancelCircleIcon /> },
  };
  const config = configs[type];
  const style = { "--activity-color": config.color } as CSSProperties;

  return (
    <div className={styles.activityIcon} style={style}>
      <svg viewBox="0 0 24 24" fill="none" aria-hidden="true">{config.path}</svg>
    </div>
  );
}

export function DashboardView({ locale }: DashboardViewProps) {
  const viewModel = buildDashboardViewModel(locale);
  const statusColors = {
    new: "#22c55e",
    processing: "#60a5fa",
    delivered: "#2dd4bf",
    cancelled: "#f87171",
  };

  return (
    <div className={styles.dashboard}>
      <AdminPageHero
        eyebrow={viewModel.hero.eyebrow}
        title={viewModel.hero.title}
        description={viewModel.hero.description}
        badge={viewModel.hero.badge}
        metaItems={viewModel.hero.metaItems}
      />

      <div className={styles.statsGrid}>
        {viewModel.stats.map((stat) => (
          <AdminStatCard
            key={stat.label}
            label={stat.label}
            value={stat.value}
            delta={<><ArrowUpSmallIcon /> {stat.delta}</>}
            subtext={stat.subtext}
            icon={STAT_ICONS[stat.icon]}
            accentColor={stat.accentColor}
          />
        ))}
      </div>

      <div className={styles.contentGrid}>
        <AdminCard
          className={styles.wideCard}
          title={viewModel.revenueChart.title}
          description={viewModel.revenueChart.description}
          action={<span className={styles.chartToolbar}>{viewModel.revenueChart.rangeLabel}<svg viewBox="0 0 12 8" fill="none" aria-hidden="true"><path d="M1 1L6 7L11 1" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" /></svg></span>}
        >
          <RevenueChart xLabels={viewModel.revenueChart.xLabels} ariaLabel={viewModel.revenueChart.ariaLabel} />
        </AdminCard>

        <AdminCard
          title={viewModel.ordersSection.title}
          description={viewModel.ordersSection.description}
          action={<Link href={`/${locale}/users`}>{viewModel.ordersSection.viewAllLabel}</Link>}
        >
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
                    <td><AdminStatusBadge color={statusColors[order.statusType]}>{order.status}</AdminStatusBadge></td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </AdminCard>
      </div>

      <div className={styles.contentGrid}>
        <AdminCard title={viewModel.distributionSection.title}>
          <div className={styles.donutLayout}>
            <DonutChart label={viewModel.distributionSection.totalLabel} />
            <div className={styles.legend}>
              {viewModel.userDistribution.map((item) => {
                const style = { "--legend-color": item.color } as CSSProperties;
                return (
                  <div key={item.label} className={styles.legendItem}>
                    <span className={styles.legendDot} style={style} />
                    <span className={styles.legendLabel}>{item.label}</span>
                    <span className={styles.legendPercent}>{item.pct}</span>
                    <span className={styles.legendCount}>({item.count})</span>
                  </div>
                );
              })}
            </div>
          </div>
        </AdminCard>

        <AdminCard title={viewModel.activitySection.title} description={viewModel.activitySection.description}>
          <ul className={styles.activityList}>
            {viewModel.activities.map((activity) => (
              <li key={`${activity.type}-${activity.time}`} className={styles.activityItem}>
                <ActivityIcon type={activity.type} />
                <div className={styles.activityBody}>
                  <p className={styles.activityText}>{activity.text}</p>
                  <p className={styles.activityTime}>{activity.time}</p>
                </div>
              </li>
            ))}
          </ul>
        </AdminCard>
      </div>
    </div>
  );
}
