"use client";

import { AdminCard, AdminPageHero, AdminStatCard, AdminStatusBadge, adminTableStyles } from "@/components/admin/admin-primitives";
import styles from "@/components/dashboard-view.module.css";
import { type Locale } from "@/lib/i18n";
import Link from "next/link";
import { type CSSProperties, type ReactNode } from "react";

type DashboardViewProps = { locale: Locale };
type ActivityType = "new" | "update" | "register" | "cancel";

function IcPeople() {
  return <svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" /><circle cx="9" cy="7" r="4" stroke="currentColor" strokeWidth="1.8" /><path d="M23 21v-2a4 4 0 0 0-3-3.87M16 3.13a4 4 0 0 1 0 7.75" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" /></svg>;
}

function IcCart() {
  return <svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="M6 2L3 6v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V6l-3-4z" stroke="currentColor" strokeWidth="1.8" strokeLinejoin="round" /><line x1="3" y1="6" x2="21" y2="6" stroke="currentColor" strokeWidth="1.8" /><path d="M16 10a4 4 0 0 1-8 0" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" /></svg>;
}

function IcDollar() {
  return <svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><line x1="12" y1="1" x2="12" y2="23" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" /><path d="M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" /></svg>;
}

function IcTrendUp() {
  return <svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><polyline points="23,6 13.5,15.5 8.5,10.5 1,18" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" /><polyline points="17,6 23,6 23,12" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" /></svg>;
}

function IcArrowUp() {
  return <svg viewBox="0 0 12 12" fill="none" aria-hidden="true"><polyline points="2,9 6,3 10,9" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" /></svg>;
}

function RevenueChart({ isRu }: { isRu: boolean }) {
  const points = "50,142 130,126 210,138 305,102 390,66 472,42 560,18";
  const areaPoints = "50,142 130,126 210,138 305,102 390,66 472,42 560,18 560,196 50,196";
  const yLabels = [
    { y: 18, label: "$30k" },
    { y: 71, label: "$20k" },
    { y: 124, label: "$10k" },
    { y: 196, label: "$0" },
  ];
  const xLabels = isRu
    ? ["20 мая", "21 мая", "22 мая", "23 мая", "24 мая", "25 мая", "26 мая"]
    : ["May 20", "May 21", "May 22", "May 23", "May 24", "May 25", "May 26"];
  const xPositions = [50, 130, 210, 305, 390, 472, 560];

  return (
    <svg viewBox="0 0 610 240" className={styles.chartSvg} aria-label={isRu ? "График выручки" : "Revenue chart"}>
      <defs>
        <linearGradient id="dashboardRevenueGradient" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stopColor="#22c55e" stopOpacity="0.24" />
          <stop offset="100%" stopColor="#22c55e" stopOpacity="0" />
        </linearGradient>
      </defs>
      {yLabels.map(({ y }) => (
        <line key={y} x1="42" y1={y} x2="570" y2={y} stroke="#1e2d40" strokeWidth="1" strokeDasharray="4 4" />
      ))}
      {yLabels.map(({ y, label }) => (
        <text key={label} x="36" y={y + 4} textAnchor="end" fill="#5f748e" fontSize="10" fontFamily="system-ui">
          {label}
        </text>
      ))}
      <polygon points={areaPoints} fill="url(#dashboardRevenueGradient)" />
      <polyline points={points} stroke="#22c55e" strokeWidth="2.4" fill="none" strokeLinejoin="round" />
      {points.split(" ").map((point, index) => {
        const [x, y] = point.split(",").map(Number);
        return <circle key={index} cx={x} cy={y} r="3.6" fill="#22c55e" stroke="#090d16" strokeWidth="1.6" />;
      })}
      {xPositions.map((x, index) => (
        <text key={x} x={x} y={220} textAnchor="middle" fill="#5f748e" fontSize="10" fontFamily="system-ui">
          {xLabels[index]}
        </text>
      ))}
    </svg>
  );
}

function DonutChart({ label }: { label: string }) {
  return (
    <svg viewBox="0 0 180 180" className={styles.donutSvg} aria-hidden="true">
      <circle cx="90" cy="90" r="65" stroke="#162537" strokeWidth="22" fill="none" />
      <circle cx="90" cy="90" r="65" stroke="#0e2d1a" strokeWidth="22" fill="none" strokeDasharray="245 163.4" strokeDashoffset="-61.3" />
      <circle cx="90" cy="90" r="65" stroke="#059669" strokeWidth="22" fill="none" strokeDasharray="114.4 294" strokeDashoffset="53.1" />
      <circle cx="90" cy="90" r="65" stroke="#22c55e" strokeWidth="22" fill="none" strokeDasharray="49 359.4" strokeDashoffset="102.1" />
      <text x="90" y="86" textAnchor="middle" fill="#ffffff" fontSize="20" fontWeight="800" fontFamily="system-ui">1 256</text>
      <text x="90" y="104" textAnchor="middle" fill="#70859f" fontSize="10" fontFamily="system-ui">{label}</text>
    </svg>
  );
}

function ActivityIcon({ type }: { type: ActivityType }) {
  const configs: Record<ActivityType, { color: string; path: ReactNode }> = {
    new: { color: "#22c55e", path: <><path d="M6 2L3 6v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V6l-3-4z" stroke="currentColor" strokeWidth="1.6" strokeLinejoin="round" /><line x1="3" y1="6" x2="21" y2="6" stroke="currentColor" strokeWidth="1.6" /></> },
    update: { color: "#60a5fa", path: <><polyline points="23,4 23,11 16,11" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" /><polyline points="1,20 1,13 8,13" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" /><path d="M3.51 9a9 9 0 0 1 14.85-3.36L23 11M1 13l4.64 5.36A9 9 0 0 0 20.49 15" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" /></> },
    register: { color: "#2dd4bf", path: <><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" /><circle cx="12" cy="7" r="4" stroke="currentColor" strokeWidth="1.6" /></> },
    cancel: { color: "#f87171", path: <><circle cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="1.6" /><line x1="15" y1="9" x2="9" y2="15" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" /><line x1="9" y1="9" x2="15" y2="15" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" /></> },
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
  const isRu = locale === "ru";
  const statusColors = {
    new: "#22c55e",
    processing: "#60a5fa",
    delivered: "#2dd4bf",
    cancelled: "#f87171",
  };

  const stats = [
    { label: isRu ? "Пользователи" : "Users", value: "1 256", delta: "+12.5%", subtext: isRu ? "к прошлой неделе" : "compared to last week", icon: <IcPeople />, accentColor: "#60a5fa" },
    { label: isRu ? "Заказы" : "Orders", value: "3 846", delta: "+8.1%", subtext: isRu ? "к прошлой неделе" : "compared to last week", icon: <IcCart />, accentColor: "#22c55e" },
    { label: isRu ? "Выручка" : "Revenue", value: "$24 980", delta: "+15.3%", subtext: isRu ? "к прошлой неделе" : "compared to last week", icon: <IcDollar />, accentColor: "#facc15" },
    { label: isRu ? "Конверсия" : "Conversion", value: "4.74%", delta: "+6.2%", subtext: isRu ? "к прошлой неделе" : "compared to last week", icon: <IcTrendUp />, accentColor: "#c084fc" },
  ];

  const orders = [
    { id: "#10245", user: isRu ? "Иван Петров" : "Ivan Petrov", amount: "$152.00", status: isRu ? "Новый" : "New", statusType: "new" as const },
    { id: "#10244", user: isRu ? "Мария Смирнова" : "Maria Smirnova", amount: "$89.90", status: isRu ? "В обработке" : "Processing", statusType: "processing" as const },
    { id: "#10243", user: isRu ? "Алексей Иванов" : "Alexei Ivanov", amount: "$129.50", status: isRu ? "Доставлен" : "Delivered", statusType: "delivered" as const },
    { id: "#10242", user: isRu ? "Ольга Кузнецова" : "Olga Kuznetsova", amount: "$75.00", status: isRu ? "Отменён" : "Cancelled", statusType: "cancelled" as const },
    { id: "#10241", user: isRu ? "Дмитрий Соколов" : "Dmitry Sokolov", amount: "$199.99", status: isRu ? "Доставлен" : "Delivered", statusType: "delivered" as const },
  ];

  const activities = [
    { type: "new" as const, text: isRu ? "Иван Петров создал новый заказ #10245" : "Ivan Petrov created new order #10245", time: isRu ? "2 мин. назад" : "2 min ago" },
    { type: "update" as const, text: isRu ? "Мария Смирнова обновила статус заказа #10244" : "Maria Smirnova updated order #10244 status", time: isRu ? "15 мин. назад" : "15 min ago" },
    { type: "register" as const, text: isRu ? "Алексей Иванов зарегистрировался в системе" : "Alexei Ivanov registered in the system", time: isRu ? "1 час назад" : "1 hour ago" },
    { type: "cancel" as const, text: isRu ? "Ольга Кузнецова отменила заказ #10242" : "Olga Kuznetsova cancelled order #10242", time: isRu ? "2 часа назад" : "2 hours ago" },
  ];

  const userDist = [
    { color: "#22c55e", label: isRu ? "Администраторы" : "Administrators", pct: "12%", count: "151" },
    { color: "#059669", label: isRu ? "Менеджеры" : "Managers", pct: "28%", count: "352" },
    { color: "#1f5d3c", label: isRu ? "Пользователи" : "Users", pct: "60%", count: "753" },
  ];

  return (
    <div className={styles.dashboard}>
      <AdminPageHero
        eyebrow={isRu ? "Control center" : "Control center"}
        title={isRu ? "Обзор админки" : "Admin Overview"}
        description={isRu
          ? "Ключевые метрики, активность и монетизация в одном темпе и с тем же визуальным ритмом, что и остальные экраны админки."
          : "Key metrics, activity, and monetization with the same pacing and visual rhythm as the rest of the admin."}
        badge={isRu ? "Последние 7 дней" : "Last 7 days"}
        metaItems={[
          isRu ? "4 KPI-карточки" : "4 KPI cards",
          isRu ? "2 аналитических блока" : "2 analytics blocks",
          isRu ? "Живой мониторинг" : "Live monitoring",
        ]}
      />

      <div className={styles.statsGrid}>
        {stats.map((stat) => (
          <AdminStatCard
            key={stat.label}
            label={stat.label}
            value={stat.value}
            delta={<><IcArrowUp /> {stat.delta}</>}
            subtext={stat.subtext}
            icon={stat.icon}
            accentColor={stat.accentColor}
          />
        ))}
      </div>

      <div className={styles.contentGrid}>
        <AdminCard
          className={styles.wideCard}
          title={isRu ? "Динамика выручки" : "Revenue dynamics"}
          description={isRu ? "Последние семь дней по активным заказам" : "Last seven days across active orders"}
          action={<span className={styles.chartToolbar}>{isRu ? "Неделя" : "Week"}<svg viewBox="0 0 12 8" fill="none" aria-hidden="true"><path d="M1 1L6 7L11 1" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" /></svg></span>}
        >
          <RevenueChart isRu={isRu} />
        </AdminCard>

        <AdminCard
          title={isRu ? "Последние заказы" : "Recent orders"}
          description={isRu ? "Свежие события монетизации" : "Latest monetization events"}
          action={<Link href={`/${locale}/users`}>{isRu ? "Смотреть все" : "View all"}</Link>}
        >
          <div className={adminTableStyles.tableWrap}>
            <table className={adminTableStyles.table}>
              <thead>
                <tr>
                  <th>{isRu ? "Заказ" : "Order"}</th>
                  <th>{isRu ? "Пользователь" : "User"}</th>
                  <th>{isRu ? "Сумма" : "Amount"}</th>
                  <th>{isRu ? "Статус" : "Status"}</th>
                </tr>
              </thead>
              <tbody>
                {orders.map((order) => (
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
        <AdminCard title={isRu ? "Распределение пользователей" : "User distribution"}>
          <div className={styles.donutLayout}>
            <DonutChart label={isRu ? "Всего" : "Total"} />
            <div className={styles.legend}>
              {userDist.map((item) => {
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

        <AdminCard title={isRu ? "Активность" : "Activity"} description={isRu ? "Последние действия в системе" : "Recent system actions"}>
          <ul className={styles.activityList}>
            {activities.map((activity) => (
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
