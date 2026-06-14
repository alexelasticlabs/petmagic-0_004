"use client";

import { useQuery } from "@tanstack/react-query";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, type ReactNode } from "react";

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
import styles from "@/components/dashboard-view.module.css";
import { Button } from "@/components/ui/button";
import { adminQueryKeys } from "@/lib/admin-query-keys";
import {
  fetchAdminEconomyDashboardMetrics,
  fetchAdminEconomyPurchases,
  fetchAdminModerationQueue,
  fetchAdminTemplateGenerationMetrics,
  fetchAdminUserDashboardMetrics,
  fetchSupportInbox,
  fetchUsers,
  useAuthSession,
  type AdminEconomyDashboardMetrics,
  type AdminEconomyPurchase,
  type AdminTemplateGenerationDashboardMetrics,
  type AdminSupportConversationSummary,
  type AdminUserDashboardMetrics,
  type UserListItem,
} from "@/lib/api-client";
import { type Locale } from "@/lib/i18n";
import { getAdminUserDisplayName, sanitizeSensitiveText } from "@/lib/sensitive-display";

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
  isPositiveTrend?: boolean;
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
  tone: "success" | "brand" | "neutral";
  label: string;
  pct: string;
  count: string;
};

type DashboardUserRoleCounts = {
  admins: number;
  moderators: number;
  users: number;
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
  const configs: Record<DashboardActivityType, { className: string; icon: ReactNode }> = {
    new: { className: styles.activityIconSuccess, icon: <CartIcon /> },
    update: { className: styles.activityIconInfo, icon: <RefreshIcon /> },
    register: { className: styles.activityIconBrand, icon: <UserRegisterIcon /> },
    cancel: { className: styles.activityIconDanger, icon: <CancelCircleIcon /> },
  };
  const config = configs[type];

  return (
    <div className={`${styles.activityIcon} ${config.className}`}>
      {config.icon}
    </div>
  );
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
  const statusColors = {
    new: "var(--success)",
    processing: "var(--info)",
    delivered: "var(--brand)",
    cancelled: "var(--danger)",
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
          action={
            dashboardQuery.isError ? (
              <Button
                variant="primary"
                onClick={() => {
                  if (!canViewDashboard) {
                    return;
                  }

                  void dashboardQuery.refetch().catch(() => undefined);
                }}
                disabled={!canViewDashboard || dashboardQuery.isFetching}
              >
                {locale === "ru" ? "Повторить" : "Retry"}
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
          {viewModel.orders.length > 0 ? (
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
          ) : (
            <AdminStateCard
              tone="info"
              title={locale === "ru" ? "Платежей пока нет" : "No payments yet"}
              description={
                locale === "ru"
                  ? "Последние платежи появятся здесь после первой успешной покупки."
                  : "Recent payments will appear here after the first successful purchase."
              }
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
                    <span className={`${styles.legendDot} ${styles[`legendDot${capitalizeTone(item.tone)}`]}`} />
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
          ) : (
            <AdminStateCard
              tone="info"
              title={locale === "ru" ? "Активности пока нет" : "No recent activity"}
              description={
                locale === "ru"
                  ? "События появятся после регистрации пользователей, платежей или обновлений поддержки."
                  : "Events will appear after users register, payments update, or support tickets change."
              }
            />
          )}
        </AdminCard>
      </div>
    </AdminPage>
  );
}

async function loadDashboardViewModel(locale: Locale, signal?: AbortSignal): Promise<DashboardViewModel> {
  const [
    usersResult,
    purchases,
    supportConversations,
    moderationQueueCount,
    generationMetrics,
    economyMetrics,
  ] = await Promise.all([
    fetchDashboardUsers(signal),
    fetchDashboardPurchases(signal),
    fetchDashboardSupportConversations(signal),
    fetchPendingModerationQueueCount(signal),
    fetchAdminTemplateGenerationMetrics(signal),
    fetchAdminEconomyDashboardMetrics(signal),
  ]);

  throwIfAborted(signal);

  const users = usersResult.items;
  const userMetrics = usersResult.metrics;

  return buildDashboardFromData(
    locale,
    users,
    userMetrics,
    generationMetrics,
    economyMetrics,
    purchases,
    supportConversations,
    moderationQueueCount
  );
}

function throwIfAborted(signal?: AbortSignal): void {
  if (!signal?.aborted) {
    return;
  }

  throw new DOMException("Dashboard request was aborted.", "AbortError");
}

async function fetchDashboardUsers(signal?: AbortSignal): Promise<{
  items: UserListItem[];
  metrics: AdminUserDashboardMetrics;
}> {
  const [metrics, recentUsersPage] = await Promise.all([
    fetchAdminUserDashboardMetrics(signal),
    fetchUsers({ skip: 0, take: 100 }, signal),
  ]);

  return {
    items: recentUsersPage.items,
    metrics,
  };
}

async function fetchDashboardPurchases(signal?: AbortSignal): Promise<AdminEconomyPurchase[]> {
  const response = await fetchAdminEconomyPurchases({ skip: 0, take: 50 }, signal);
  return response.items;
}

async function fetchDashboardSupportConversations(
  signal?: AbortSignal
): Promise<AdminSupportConversationSummary[]> {
  const response = await fetchSupportInbox(undefined, "all", { page: 1, pageSize: 50, signal });
  return response.items;
}

async function fetchPendingModerationQueueCount(signal?: AbortSignal): Promise<number> {
  const response = await fetchAdminModerationQueue(
    {
      status: "pending",
      take: 1,
    },
    signal
  );
  return Math.max(0, response.totalCount);
}

function buildDashboardFromData(
  locale: Locale,
  users: UserListItem[],
  userMetrics: AdminUserDashboardMetrics,
  generationMetrics: AdminTemplateGenerationDashboardMetrics,
  economyMetrics: AdminEconomyDashboardMetrics,
  purchases: AdminEconomyPurchase[],
  supportConversations: AdminSupportConversationSummary[],
  moderationQueueCount: number
): DashboardViewModel {
  const copy = getDashboardCopy(locale);
  const purchasesSorted = [...purchases].sort((left, right) => {
    const leftTs = parseTimestamp(left.confirmedAtUtc ?? left.createdAtUtc) ?? 0;
    const rightTs = parseTimestamp(right.confirmedAtUtc ?? right.createdAtUtc) ?? 0;
    return rightTs - leftTs;
  });

  const userMap = new Map(users.map((item) => [item.userId, item]));
  const totalUserCount = Math.max(0, userMetrics.totalUsers);
  const premiumUserCount = Math.max(0, userMetrics.premiumUsers);
  const currentUsers = Math.max(0, userMetrics.usersThisWeek);
  const previousUsers = Math.max(0, userMetrics.usersPreviousWeek);
  const roleCounts: DashboardUserRoleCounts = {
    admins: Math.max(0, userMetrics.adminUsers),
    moderators: Math.max(0, userMetrics.moderatorUsers),
    users: Math.max(0, userMetrics.regularUsers),
  };

  const currentPurchasesCount = Math.max(0, economyMetrics.purchasesThisWeek);
  const previousPurchasesCount = Math.max(0, economyMetrics.purchasesPreviousWeek);
  const currentSucceededCount = Math.max(0, economyMetrics.successfulPaymentsThisWeek);
  const previousSucceededCount = Math.max(0, economyMetrics.successfulPaymentsPreviousWeek);
  const currentFailedPayments = Math.max(0, economyMetrics.failedPaymentsThisWeek);
  const activeSubscriptionCount = Math.max(0, economyMetrics.activeSubscriptions);
  const revenueCurrency = normalizeCurrencyCode(economyMetrics.currencyCode);
  const currentRevenue = safeNumber(economyMetrics.revenueThisWeek);
  const previousRevenue = safeNumber(economyMetrics.revenuePreviousWeek);

  const currentConversion = currentPurchasesCount
    ? (currentSucceededCount / currentPurchasesCount) * 100
    : 0;
  const previousConversion = previousPurchasesCount
    ? (previousSucceededCount / previousPurchasesCount) * 100
    : 0;
  const revenueSeries = buildDashboardRevenueSeries(economyMetrics.revenueSeries);

  const stats: DashboardStatItem[] = [
    {
      label: copy.stats.users,
      value: formatNumber(totalUserCount, locale),
      delta: formatSignedPercentDelta(currentUsers, previousUsers, locale),
      subtext: copy.stats.usersSubtext,
      icon: "people",
      accentColor: "var(--brand)",
      isPositiveTrend: currentUsers >= previousUsers,
    },
    {
      label: copy.stats.orders,
      value: formatNumber(currentPurchasesCount, locale),
      delta: formatSignedPercentDelta(currentPurchasesCount, previousPurchasesCount, locale),
      subtext: copy.stats.ordersSubtext,
      icon: "cart",
      accentColor: "var(--success)",
      isPositiveTrend: currentPurchasesCount >= previousPurchasesCount,
    },
    {
      label: copy.stats.revenue,
      value: formatCurrency(currentRevenue, locale, revenueCurrency),
      delta: formatSignedPercentDelta(currentRevenue, previousRevenue, locale),
      subtext: copy.stats.revenueSubtext,
      icon: "dollar",
      accentColor: "var(--warning)",
      isPositiveTrend: currentRevenue >= previousRevenue,
    },
    {
      label: copy.stats.conversion,
      value: `${formatNumber(currentConversion, locale, 1)}%`,
      delta: formatSignedNumber(currentConversion - previousConversion, locale, 1, copy.stats.pp),
      subtext: copy.stats.conversionSubtext,
      icon: "trendUp",
      accentColor: "var(--magenta)",
      isPositiveTrend: currentConversion >= previousConversion,
    },
    {
      label: copy.stats.premiumUsers,
      value: formatNumber(premiumUserCount, locale),
      delta: copy.stats.live,
      subtext: copy.stats.premiumUsersSubtext,
      icon: "people",
      accentColor: "var(--accent)",
    },
    {
      label: copy.stats.activeSubscriptions,
      value: formatNumber(activeSubscriptionCount, locale),
      delta: copy.stats.live,
      subtext: copy.stats.activeSubscriptionsSubtext,
      icon: "dollar",
      accentColor: "var(--success)",
    },
    {
      label: copy.stats.generationsToday,
      value: formatNumber(generationMetrics.generationsToday, locale),
      delta: `${formatNumber(generationMetrics.generationsThisWeek, locale)} ${copy.stats.weekShort}`,
      subtext: `${formatNumber(generationMetrics.generationsThisMonth, locale)} ${copy.stats.monthShort}`,
      icon: "trendUp",
      accentColor: "var(--info)",
    },
    {
      label: copy.stats.failedGenerations,
      value: formatNumber(generationMetrics.failedGenerationsThisWeek, locale),
      delta: `${formatNumber(generationMetrics.failedGenerationsToday, locale)} ${copy.stats.todayShort}`,
      subtext: `${formatNumber(generationMetrics.failedGenerationsThisMonth, locale)} ${copy.stats.monthShort}`,
      icon: "trendUp",
      accentColor: "var(--danger)",
    },
    {
      label: copy.stats.pendingJobs,
      value: formatNumber(generationMetrics.pendingJobs, locale),
      delta: `${formatNumber(generationMetrics.runningJobs, locale)} ${copy.stats.runningShort}`,
      subtext: copy.stats.pendingJobsSubtext,
      icon: "cart",
      accentColor: "var(--warning)",
    },
    {
      label: copy.stats.paymentSuccessFailure,
      value: `${formatNumber(currentSucceededCount, locale)} / ${formatNumber(currentFailedPayments, locale)}`,
      delta: copy.stats.currentWeek,
      subtext: copy.stats.paymentSuccessFailureSubtext,
      icon: "dollar",
      accentColor: "var(--danger)",
    },
    {
      label: copy.stats.moderationQueue,
      value: formatNumber(moderationQueueCount, locale),
      delta: copy.stats.live,
      subtext: copy.stats.moderationQueueSubtext,
      icon: "people",
      accentColor: "var(--magenta)",
    },
  ];

  const orders = purchasesSorted.slice(0, 5).map((item) => {
    const user = userMap.get(item.userId);
    const statusType = mapPurchaseStatus(item.status);
    return {
      id: shortOrderId(item.orderId),
      user: user ? formatDashboardUserLabel(user) : shortUserId(item.userId),
      amount: formatCurrency(item.priceAmount, locale, normalizeCurrencyCode(item.currencyCode)),
      status: getOrderStatusLabel(statusType, locale),
      statusType,
    } satisfies DashboardOrderItem;
  });

  const activities = buildActivities(locale, users, purchasesSorted, supportConversations, userMap);
  const userDistribution = buildUserDistribution(locale, totalUserCount, roleCounts);

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
      totalValue: formatNumber(totalUserCount, locale),
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
              ? `${formatDashboardUserLabel(item)} зарегистрировался в системе`
              : `${formatDashboardUserLabel(item)} registered in the system`,
          time: formatRelativeTime(item.createdAtUtc, locale),
        },
    }))
    .filter((event) => event.at !== null);

  const purchaseEvents = purchases
    .slice(0, 12)
    .map((item) => {
      const timestamp = item.confirmedAtUtc ?? item.createdAtUtc;
      const user = userMap.get(item.userId);
      const userLabel = user ? formatDashboardUserLabel(user) : shortUserId(item.userId);
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
            ? `Обновлён тикет ${shortConversationId(item.conversationId)}: ${formatDashboardLabel(item.status, 48)}`
            : `Updated ticket ${shortConversationId(item.conversationId)}: ${formatDashboardLabel(item.status, 48)}`,
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
  totalUserCount: number,
  roleCounts: DashboardUserRoleCounts
): DashboardUserDistributionItem[] {
  const admins = Math.max(0, roleCounts.admins);
  const moderators = Math.max(0, roleCounts.moderators);
  const regular = Math.max(0, roleCounts.users);
  const roleTotal = admins + moderators + regular;
  const total = Math.max(1, roleTotal || totalUserCount);

  const toPercent = (value: number) => `${Math.round((value / total) * 100)}%`;

  return [
    {
      color: "var(--success)",
      tone: "success",
      label: locale === "ru" ? "Администраторы" : "Administrators",
      pct: toPercent(admins),
      count: formatNumber(admins, locale),
    },
    {
      color: "var(--brand)",
      tone: "brand",
      label: locale === "ru" ? "Модераторы" : "Moderators",
      pct: toPercent(moderators),
      count: formatNumber(moderators, locale),
    },
    {
      color: "var(--neutral)",
      tone: "neutral",
      label: locale === "ru" ? "Пользователи" : "Users",
      pct: toPercent(regular),
      count: formatNumber(regular, locale),
    },
  ];
}

function capitalizeTone(value: DashboardUserDistributionItem["tone"]): Capitalize<DashboardUserDistributionItem["tone"]> {
  return (value.charAt(0).toUpperCase() + value.slice(1)) as Capitalize<
    DashboardUserDistributionItem["tone"]
  >;
}

function buildDashboardRevenueSeries(
  points: AdminEconomyDashboardMetrics["revenueSeries"]
): number[] {
  const values = points.slice(-7).map((point) => safeNumber(point.amount));
  while (values.length < 7) {
    values.unshift(0);
  }

  return values;
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
  if (!normalized || !/^[A-Z]{3}$/.test(normalized)) {
    return "USD";
  }

  return isSupportedCurrencyCode(normalized) ? normalized : "USD";
}

function isSupportedCurrencyCode(currencyCode: string): boolean {
  try {
    new Intl.NumberFormat("en-US", { style: "currency", currency: currencyCode }).format(0);
    return true;
  } catch {
    return false;
  }
}

function safeNumber(value: number): number {
  return Number.isFinite(value) ? value : 0;
}

function formatNumber(value: number, locale: Locale, maximumFractionDigits = 0): string {
  return new Intl.NumberFormat(locale === "ru" ? "ru-RU" : "en-US", {
    maximumFractionDigits,
  }).format(value);
}

function formatCurrency(value: number, locale: Locale, currencyCode: string): string {
  const amount = Number.isFinite(value) ? value : 0;
  const safeCurrencyCode = normalizeCurrencyCode(currencyCode);
  try {
    return new Intl.NumberFormat(locale === "ru" ? "ru-RU" : "en-US", {
      style: "currency",
      currency: safeCurrencyCode,
      maximumFractionDigits: 2,
    }).format(amount);
  } catch {
    return `${formatNumber(amount, locale, 2)} ${sanitizeSensitiveText(safeCurrencyCode, 12)}`;
  }
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

function formatDashboardUserLabel(user: Pick<UserListItem, "displayName" | "email" | "userId">): string {
  return formatDashboardLabel(getAdminUserDisplayName(user), 96);
}

function formatDashboardLabel(value: string | null | undefined, maxLength = 80): string {
  return sanitizeSensitiveText(value, maxLength);
}

function shortOrderId(orderId: string): string {
  const compact = formatDashboardLabel(orderId, 64).replace(/-/g, "");
  return `#${compact.slice(0, 8).toUpperCase()}`;
}

function shortUserId(userId: string): string {
  return formatDashboardLabel(userId, 32).slice(0, 8);
}

function shortConversationId(conversationId: string): string {
  return `#${formatDashboardLabel(conversationId, 32).slice(0, 6).toUpperCase()}`;
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
      premiumUsers: isRu ? "Premium пользователи" : "Premium users",
      activeSubscriptions: isRu ? "Активные подписки" : "Active subscriptions",
      generationsToday: isRu ? "Генерации сегодня" : "Generations today",
      failedGenerations: isRu ? "Ошибки генераций" : "Failed generations",
      pendingJobs: isRu ? "Очередь генераций" : "Pending jobs",
      paymentSuccessFailure: isRu ? "Платежи успех/ошибка" : "Payments success/fail",
      moderationQueue: isRu ? "Очередь модерации" : "Moderation queue",
      orders: isRu ? "Заказы" : "Orders",
      revenue: isRu ? "Выручка" : "Revenue",
      conversion: isRu ? "Конверсия" : "Conversion",
      usersSubtext: isRu ? "новые за 7 дней к предыдущим 7" : "new in 7d vs previous 7d",
      premiumUsersSubtext: isRu ? "по статусу Premium" : "by Premium status",
      activeSubscriptionsSubtext: isRu ? "статус Active" : "status Active",
      pendingJobsSubtext: isRu ? "ожидают обработки" : "waiting for processing",
      paymentSuccessFailureSubtext: isRu ? "за текущие 7 дней" : "current 7-day window",
      moderationQueueSubtext: isRu ? "pending элементы модерации" : "pending moderation items",
      ordersSubtext: isRu ? "заказы за 7 дней к предыдущим 7" : "orders in 7d vs previous 7d",
      revenueSubtext: isRu ? "выручка за 7 дней к предыдущим 7" : "revenue in 7d vs previous 7d",
      conversionSubtext: isRu
        ? "доля успешных заказов за 7 дней"
        : "successful orders ratio in last 7d",
      live: isRu ? "live" : "live",
      todayShort: isRu ? "сегодня" : "today",
      weekShort: isRu ? "за неделю" : "week",
      monthShort: isRu ? "за 30 дней" : "30d",
      runningShort: isRu ? "в работе" : "running",
      currentWeek: isRu ? "текущая неделя" : "current week",
      pp: isRu ? " п.п." : "pp",
    },
  };
}
