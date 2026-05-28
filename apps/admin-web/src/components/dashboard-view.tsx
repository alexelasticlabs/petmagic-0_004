"use client";

import { useQuery } from "@tanstack/react-query";
import Link from "next/link";
import { type CSSProperties, type ReactNode } from "react";

import {
  ArrowUpSmallIcon,
  CalendarIcon,
  CancelCircleIcon,
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
import { DonutChart, RevenueChart } from "@/components/dashboard/dashboard-charts";
import styles from "@/components/dashboard-view.module.css";
import {
  fetchAdminEconomyPurchases,
  fetchSupportInbox,
  fetchUsers,
  useAuthSession,
  type AdminEconomyPurchase,
  type AdminSupportConversationSummary,
  type UserListItem,
} from "@/lib/api-client";
import { type Locale } from "@/lib/i18n";

type DashboardViewProps = { locale: Locale };
type DashboardActivityType = "new" | "update" | "register" | "cancel";
type DashboardStatIcon = "people" | "cart" | "dollar" | "trendUp";
type DashboardOrderStatusType = "new" | "processing" | "delivered" | "cancelled";

type DashboardStatItem = {
  label: string;
  value: string;
  delta: string;
  subtext: string;
  accentColor: string;
  icon: DashboardStatIcon;
  isPositiveTrend: boolean;
};

type DashboardOrderItem = {
  id: string;
  user: string;
  amount: string;
  status: string;
  statusType: DashboardOrderStatusType;
};

type DashboardActivityItem = {
  id: string;
  type: DashboardActivityType;
  text: string;
  time: string;
};

type DashboardUserDistributionItem = {
  color: string;
  label: string;
  pct: string;
  count: string;
};

type DashboardViewModel = {
  hero: {
    eyebrow: string;
    title: string;
    description: string;
  };
  revenueChart: {
    title: string;
    description: string;
    rangeLabel: string;
    ariaLabel: string;
    xLabels: string[];
    values: number[];
    currencyCode: string;
  };
  ordersSection: {
    title: string;
    description: string;
    viewAllLabel: string;
    headers: {
      order: string;
      user: string;
      amount: string;
      status: string;
    };
  };
  distributionSection: {
    title: string;
    totalLabel: string;
    totalValue: string;
  };
  activitySection: {
    title: string;
    description: string;
  };
  stats: DashboardStatItem[];
  orders: DashboardOrderItem[];
  activities: DashboardActivityItem[];
  userDistribution: DashboardUserDistributionItem[];
};

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
      <svg viewBox="0 0 24 24" fill="none" aria-hidden="true">
        {config.path}
      </svg>
    </div>
  );
}

export function DashboardView({ locale }: DashboardViewProps) {
  const session = useAuthSession();
  const dashboardQuery = useQuery<DashboardViewModel>({
    queryKey: ["admin", "dashboard", locale],
    queryFn: () => loadDashboardViewModel(locale),
    enabled: Boolean(session),
    staleTime: 60_000,
  });

  const viewModel = dashboardQuery.data;
  const statusColors = {
    new: "#22c55e",
    processing: "#60a5fa",
    delivered: "#2dd4bf",
    cancelled: "#f87171",
  };

  const copy = getDashboardCopy(locale);

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
              ? locale === "ru"
                ? "Не удалось загрузить дашборд"
                : "Failed to load dashboard"
              : locale === "ru"
                ? "Загружаем данные"
                : "Loading data"
          }
          description={
            dashboardQuery.isError
              ? locale === "ru"
                ? "Проверьте доступ к API и повторите позже."
                : "Please verify API access and try again."
              : locale === "ru"
                ? "Собираем актуальные метрики из модулей пользователей, экономики и поддержки."
                : "Gathering live metrics from users, economy, and support modules."
          }
          tone={dashboardQuery.isError ? "danger" : "info"}
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
              <svg viewBox="0 0 12 8" fill="none" aria-hidden="true">
                <path
                  d="M1 1L6 7L11 1"
                  stroke="currentColor"
                  strokeWidth="1.8"
                  strokeLinecap="round"
                />
              </svg>
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
                      <AdminStatusBadge color={statusColors[order.statusType]}>
                        {order.status}
                      </AdminStatusBadge>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
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

        <AdminCard
          title={
            <span className={styles.cardTitleWithIcon}>
              <RefreshIcon className={styles.cardTitleIcon} />
              <span>{viewModel.activitySection.title}</span>
            </span>
          }
          description={viewModel.activitySection.description}
        >
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
        </AdminCard>
      </div>
    </AdminPage>
  );
}

async function loadDashboardViewModel(locale: Locale): Promise<DashboardViewModel> {
  const [usersResult, purchasesResult, supportResult] = await Promise.allSettled([
    fetchUsers(),
    fetchDashboardPurchases(),
    fetchSupportInbox(undefined, "all"),
  ]);

  const users = usersResult.status === "fulfilled" ? usersResult.value : [];
  const purchases = purchasesResult.status === "fulfilled" ? purchasesResult.value : [];
  const supportConversations = supportResult.status === "fulfilled" ? supportResult.value : [];

  return buildDashboardFromData(locale, users, purchases, supportConversations);
}

async function fetchDashboardPurchases(): Promise<AdminEconomyPurchase[]> {
  const take = 200;
  const maxPages = 3;
  const cutoff = Date.now() - 14 * 24 * 60 * 60 * 1000;
  const items: AdminEconomyPurchase[] = [];

  for (let page = 0; page < maxPages; page += 1) {
    const response = await fetchAdminEconomyPurchases({ skip: page * take, take });
    items.push(...response.items);

    if (!response.hasMore) {
      break;
    }

    const oldestItem = response.items[response.items.length - 1];
    const oldestTimestamp = parseTimestamp(oldestItem?.confirmedAtUtc ?? oldestItem?.createdAtUtc);
    if (oldestTimestamp !== null && oldestTimestamp < cutoff) {
      break;
    }
  }

  return items;
}

function buildDashboardFromData(
  locale: Locale,
  users: UserListItem[],
  purchases: AdminEconomyPurchase[],
  supportConversations: AdminSupportConversationSummary[]
): DashboardViewModel {
  const copy = getDashboardCopy(locale);
  const now = Date.now();
  const currentStart = startOfDayTimestamp(now - 6 * 24 * 60 * 60 * 1000);
  const previousStart = currentStart - 7 * 24 * 60 * 60 * 1000;

  const purchasesSorted = [...purchases].sort((left, right) => {
    const leftTs = parseTimestamp(left.confirmedAtUtc ?? left.createdAtUtc) ?? 0;
    const rightTs = parseTimestamp(right.confirmedAtUtc ?? right.createdAtUtc) ?? 0;
    return rightTs - leftTs;
  });

  const userMap = new Map(users.map((item) => [item.userId, item]));
  const currentUsers = users.filter((item) => {
    const timestamp = parseTimestamp(item.createdAtUtc);
    return timestamp !== null && timestamp >= currentStart;
  }).length;
  const previousUsers = users.filter((item) => {
    const timestamp = parseTimestamp(item.createdAtUtc);
    return timestamp !== null && timestamp >= previousStart && timestamp < currentStart;
  }).length;

  const currentPurchases = purchases.filter((item) => {
    const timestamp = parseTimestamp(item.confirmedAtUtc ?? item.createdAtUtc);
    return timestamp !== null && timestamp >= currentStart;
  });
  const previousPurchases = purchases.filter((item) => {
    const timestamp = parseTimestamp(item.confirmedAtUtc ?? item.createdAtUtc);
    return timestamp !== null && timestamp >= previousStart && timestamp < currentStart;
  });

  const currentSucceeded = currentPurchases.filter((item) => item.status === "succeeded");
  const previousSucceeded = previousPurchases.filter((item) => item.status === "succeeded");
  const revenueCurrency = detectMainCurrency(currentSucceeded, purchasesSorted);

  const currentRevenue = currentSucceeded
    .filter((item) => normalizeCurrencyCode(item.currencyCode) === revenueCurrency)
    .reduce((sum, item) => sum + item.priceAmount, 0);
  const previousRevenue = previousSucceeded
    .filter((item) => normalizeCurrencyCode(item.currencyCode) === revenueCurrency)
    .reduce((sum, item) => sum + item.priceAmount, 0);

  const currentConversion = currentPurchases.length
    ? (currentSucceeded.length / currentPurchases.length) * 100
    : 0;
  const previousConversion = previousPurchases.length
    ? (previousSucceeded.length / previousPurchases.length) * 100
    : 0;
  const revenueSeries = buildRevenueSeries(purchases, revenueCurrency);

  const stats: DashboardStatItem[] = [
    {
      label: copy.stats.users,
      value: formatNumber(users.length, locale),
      delta: formatSignedPercentDelta(currentUsers, previousUsers, locale),
      subtext: copy.stats.usersSubtext,
      icon: "people",
      accentColor: "#2dd4bf",
      isPositiveTrend: currentUsers >= previousUsers,
    },
    {
      label: copy.stats.orders,
      value: formatNumber(currentPurchases.length, locale),
      delta: formatSignedPercentDelta(currentPurchases.length, previousPurchases.length, locale),
      subtext: copy.stats.ordersSubtext,
      icon: "cart",
      accentColor: "#22c55e",
      isPositiveTrend: currentPurchases.length >= previousPurchases.length,
    },
    {
      label: copy.stats.revenue,
      value: formatCurrency(currentRevenue, locale, revenueCurrency),
      delta: formatSignedPercentDelta(currentRevenue, previousRevenue, locale),
      subtext: copy.stats.revenueSubtext,
      icon: "dollar",
      accentColor: "#facc15",
      isPositiveTrend: currentRevenue >= previousRevenue,
    },
    {
      label: copy.stats.conversion,
      value: `${formatNumber(currentConversion, locale, 1)}%`,
      delta: formatSignedNumber(currentConversion - previousConversion, locale, 1, copy.stats.pp),
      subtext: copy.stats.conversionSubtext,
      icon: "trendUp",
      accentColor: "#f472b6",
      isPositiveTrend: currentConversion >= previousConversion,
    },
  ];

  const orders = purchasesSorted.slice(0, 5).map((item) => {
    const user = userMap.get(item.userId);
    const statusType = mapPurchaseStatus(item.status);
    return {
      id: shortOrderId(item.orderId),
      user: user?.displayName || user?.email || shortUserId(item.userId),
      amount: formatCurrency(item.priceAmount, locale, normalizeCurrencyCode(item.currencyCode)),
      status: getOrderStatusLabel(statusType, locale),
      statusType,
    } satisfies DashboardOrderItem;
  });

  const activities = buildActivities(locale, users, purchasesSorted, supportConversations, userMap);
  const userDistribution = buildUserDistribution(locale, users);

  return {
    hero: copy.hero,
    revenueChart: {
      title: copy.revenueChart.title,
      description: copy.revenueChart.description,
      rangeLabel: copy.revenueChart.rangeLabel,
      ariaLabel: copy.revenueChart.ariaLabel,
      xLabels: buildLast7DayLabels(locale),
      values: revenueSeries,
      currencyCode: revenueCurrency,
    },
    ordersSection: copy.ordersSection,
    distributionSection: {
      ...copy.distributionSection,
      totalValue: formatNumber(users.length, locale),
    },
    activitySection: copy.activitySection,
    stats,
    orders,
    activities,
    userDistribution,
  };
}

function buildActivities(
  locale: Locale,
  users: UserListItem[],
  purchases: AdminEconomyPurchase[],
  supportConversations: AdminSupportConversationSummary[],
  userMap: Map<string, UserListItem>
): DashboardActivityItem[] {
  const userEvents = users
    .map((item) => ({
      id: `user:${item.userId}`,
      at: parseTimestamp(item.createdAtUtc),
      item: {
        id: `user:${item.userId}`,
        type: "register" as const,
        text:
          locale === "ru"
            ? `${item.displayName || item.email} зарегистрировался в системе`
            : `${item.displayName || item.email} registered in the system`,
        time: formatRelativeTime(item.createdAtUtc, locale),
      },
    }))
    .filter((event) => event.at !== null);

  const purchaseEvents = purchases
    .slice(0, 12)
    .map((item) => {
      const timestamp = item.confirmedAtUtc ?? item.createdAtUtc;
      const user = userMap.get(item.userId);
      const userLabel = user?.displayName || user?.email || shortUserId(item.userId);
      const statusType = mapPurchaseStatus(item.status);
      return {
        id: `purchase:${item.orderId}`,
        at: parseTimestamp(timestamp),
        item: {
          id: `purchase:${item.orderId}`,
          type: statusType === "cancelled" ? "cancel" : "new",
          text:
            locale === "ru"
              ? `${userLabel}: заказ ${shortOrderId(item.orderId)} ${statusType === "cancelled" ? "завершился ошибкой" : "обновлён"}`
              : `${userLabel}: order ${shortOrderId(item.orderId)} ${statusType === "cancelled" ? "failed" : "updated"}`,
          time: formatRelativeTime(timestamp, locale),
        } satisfies DashboardActivityItem,
      };
    })
    .filter((event) => event.at !== null);

  const supportEvents = supportConversations
    .slice(0, 8)
    .map((item) => ({
      id: `support:${item.conversationId}`,
      at: parseTimestamp(item.updatedAtUtc),
      item: {
        id: `support:${item.conversationId}`,
        type: "update" as const,
        text:
          locale === "ru"
            ? `Обновлён тикет ${shortConversationId(item.conversationId)}: ${item.status}`
            : `Updated ticket ${shortConversationId(item.conversationId)}: ${item.status}`,
        time: formatRelativeTime(item.updatedAtUtc, locale),
      },
    }))
    .filter((event) => event.at !== null);

  return [...userEvents, ...purchaseEvents, ...supportEvents]
    .sort((left, right) => (right.at ?? 0) - (left.at ?? 0))
    .slice(0, 4)
    .map((event) => event.item);
}

function buildUserDistribution(
  locale: Locale,
  users: UserListItem[]
): DashboardUserDistributionItem[] {
  const admins = users.filter((item) => {
    const normalizedRoles = item.roles.map((role) => role.toLowerCase());
    return normalizedRoles.includes("admin") || normalizedRoles.includes("superadmin");
  }).length;
  const managers = users.filter((item) => {
    const normalizedRoles = item.roles.map((role) => role.toLowerCase());
    const isAdmin = normalizedRoles.includes("admin") || normalizedRoles.includes("superadmin");
    const isManager = normalizedRoles.includes("manager") || normalizedRoles.includes("moderator");
    return !isAdmin && isManager;
  }).length;
  const regular = Math.max(0, users.length - admins - managers);
  const total = Math.max(1, users.length);

  const toPercent = (value: number) => `${Math.round((value / total) * 100)}%`;

  return [
    {
      color: "#22c55e",
      label: locale === "ru" ? "Администраторы" : "Administrators",
      pct: toPercent(admins),
      count: formatNumber(admins, locale),
    },
    {
      color: "#059669",
      label: locale === "ru" ? "Менеджеры" : "Managers",
      pct: toPercent(managers),
      count: formatNumber(managers, locale),
    },
    {
      color: "#1f5d3c",
      label: locale === "ru" ? "Пользователи" : "Users",
      pct: toPercent(regular),
      count: formatNumber(regular, locale),
    },
  ];
}

function buildRevenueSeries(purchases: AdminEconomyPurchase[], currencyCode: string): number[] {
  const todayStart = startOfDayTimestamp(Date.now());
  const buckets = new Array<number>(7).fill(0);

  for (const item of purchases) {
    if (item.status !== "succeeded") {
      continue;
    }

    if (normalizeCurrencyCode(item.currencyCode) !== currencyCode) {
      continue;
    }

    const timestamp = parseTimestamp(item.confirmedAtUtc ?? item.createdAtUtc);
    if (timestamp === null) {
      continue;
    }

    const dayStart = startOfDayTimestamp(timestamp);
    const offset = Math.round((todayStart - dayStart) / (24 * 60 * 60 * 1000));
    if (offset < 0 || offset > 6) {
      continue;
    }

    buckets[6 - offset] += item.priceAmount;
  }

  return buckets;
}

function startOfDayTimestamp(timestamp: number): number {
  const date = new Date(timestamp);
  date.setHours(0, 0, 0, 0);
  return date.getTime();
}

function parseTimestamp(value: string | null | undefined): number | null {
  if (!value) {
    return null;
  }

  const parsed = Date.parse(value);
  return Number.isNaN(parsed) ? null : parsed;
}

function normalizeCurrencyCode(value: string | null | undefined): string {
  const normalized = value?.trim().toUpperCase();
  return normalized && /^[A-Z]{3}$/.test(normalized) ? normalized : "USD";
}

function detectMainCurrency(
  preferred: AdminEconomyPurchase[],
  fallback: AdminEconomyPurchase[]
): string {
  const source = preferred.length ? preferred : fallback;
  if (!source.length) {
    return "USD";
  }

  const buckets = new Map<string, number>();
  for (const item of source) {
    const currency = normalizeCurrencyCode(item.currencyCode);
    buckets.set(currency, (buckets.get(currency) ?? 0) + 1);
  }

  let best = "USD";
  let bestCount = 0;
  for (const [currency, count] of buckets) {
    if (count > bestCount) {
      best = currency;
      bestCount = count;
    }
  }

  return best;
}

function formatNumber(value: number, locale: Locale, maximumFractionDigits = 0): string {
  return new Intl.NumberFormat(locale === "ru" ? "ru-RU" : "en-US", {
    maximumFractionDigits,
  }).format(value);
}

function formatCurrency(value: number, locale: Locale, currencyCode: string): string {
  return new Intl.NumberFormat(locale === "ru" ? "ru-RU" : "en-US", {
    style: "currency",
    currency: currencyCode,
    maximumFractionDigits: 2,
  }).format(value);
}

function formatSignedPercentDelta(current: number, previous: number, locale: Locale): string {
  if (current === 0 && previous === 0) {
    return "0%";
  }

  const raw = previous === 0 ? 100 : ((current - previous) / Math.abs(previous)) * 100;
  return formatSignedNumber(raw, locale, Math.abs(raw) < 10 ? 1 : 0, "%");
}

function formatSignedNumber(
  value: number,
  locale: Locale,
  maximumFractionDigits: number,
  suffix: string
): string {
  const sign = value > 0 ? "+" : value < 0 ? "-" : "";
  const absolute = Math.abs(value);
  return `${sign}${formatNumber(absolute, locale, maximumFractionDigits)}${suffix}`;
}

function mapPurchaseStatus(status: string): DashboardOrderStatusType {
  if (status === "succeeded") {
    return "delivered";
  }

  if (status === "pending") {
    return "processing";
  }

  if (status === "failed") {
    return "cancelled";
  }

  return "new";
}

function getOrderStatusLabel(status: DashboardOrderStatusType, locale: Locale): string {
  if (locale === "ru") {
    if (status === "new") return "Новый";
    if (status === "processing") return "В обработке";
    if (status === "delivered") return "Успешно";
    return "Ошибка";
  }

  if (status === "new") return "New";
  if (status === "processing") return "Processing";
  if (status === "delivered") return "Succeeded";
  return "Failed";
}

function shortOrderId(orderId: string): string {
  const compact = orderId.replace(/-/g, "");
  return `#${compact.slice(0, 8).toUpperCase()}`;
}

function shortUserId(userId: string): string {
  return userId.slice(0, 8);
}

function shortConversationId(conversationId: string): string {
  return `#${conversationId.slice(0, 6).toUpperCase()}`;
}

function formatRelativeTime(value: string | null | undefined, locale: Locale): string {
  const timestamp = parseTimestamp(value);
  if (timestamp === null) {
    return "—";
  }

  const diffMinutes = Math.max(0, Math.round((Date.now() - timestamp) / 60_000));
  if (diffMinutes < 1) {
    return locale === "ru" ? "только что" : "just now";
  }

  if (diffMinutes < 60) {
    return locale === "ru" ? `${diffMinutes} мин назад` : `${diffMinutes} min ago`;
  }

  const diffHours = Math.round(diffMinutes / 60);
  if (diffHours < 24) {
    return locale === "ru" ? `${diffHours} ч назад` : `${diffHours}h ago`;
  }

  const diffDays = Math.round(diffHours / 24);
  return locale === "ru" ? `${diffDays} дн назад` : `${diffDays}d ago`;
}

function buildLast7DayLabels(locale: Locale): string[] {
  const formatter = new Intl.DateTimeFormat(locale === "ru" ? "ru-RU" : "en-US", {
    month: "short",
    day: "numeric",
  });
  const labels: string[] = [];

  for (let offset = 6; offset >= 0; offset -= 1) {
    labels.push(formatter.format(new Date(Date.now() - offset * 24 * 60 * 60 * 1000)));
  }

  return labels;
}

function getDashboardCopy(locale: Locale) {
  const isRu = locale === "ru";

  return {
    hero: {
      eyebrow: "Control center",
      title: isRu ? "Обзор админки" : "Admin Overview",
      description: isRu
        ? "Актуальные метрики пользователей, монетизации и поддержки в реальном времени."
        : "Live user, monetization, and support metrics in one place.",
    },
    revenueChart: {
      title: isRu ? "Динамика выручки" : "Revenue dynamics",
      description: isRu
        ? "Последние семь дней по успешным платежам"
        : "Last seven days across successful payments",
      rangeLabel: isRu ? "Неделя" : "Week",
      ariaLabel: isRu ? "График выручки" : "Revenue chart",
    },
    ordersSection: {
      title: isRu ? "Последние заказы" : "Recent orders",
      description: isRu ? "Живая лента платежей" : "Live stream of purchase events",
      viewAllLabel: isRu ? "Смотреть все" : "View all",
      headers: {
        order: isRu ? "Заказ" : "Order",
        user: isRu ? "Пользователь" : "User",
        amount: isRu ? "Сумма" : "Amount",
        status: isRu ? "Статус" : "Status",
      },
    },
    distributionSection: {
      title: isRu ? "Распределение пользователей" : "User distribution",
      totalLabel: isRu ? "Всего" : "Total",
    },
    activitySection: {
      title: isRu ? "Активность" : "Activity",
      description: isRu ? "Последние события из модулей" : "Latest events across modules",
    },
    stats: {
      users: isRu ? "Пользователи" : "Users",
      orders: isRu ? "Заказы" : "Orders",
      revenue: isRu ? "Выручка" : "Revenue",
      conversion: isRu ? "Конверсия" : "Conversion",
      usersSubtext: isRu ? "новые за 7 дней к предыдущим 7" : "new in 7d vs previous 7d",
      ordersSubtext: isRu ? "заказы за 7 дней к предыдущим 7" : "orders in 7d vs previous 7d",
      revenueSubtext: isRu ? "выручка за 7 дней к предыдущим 7" : "revenue in 7d vs previous 7d",
      conversionSubtext: isRu
        ? "доля успешных заказов за 7 дней"
        : "successful orders ratio in last 7d",
      pp: isRu ? " п.п." : "pp",
    },
  };
}
