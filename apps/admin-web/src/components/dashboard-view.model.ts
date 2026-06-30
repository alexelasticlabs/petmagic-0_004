import { getDashboardCopy, getDashboardIntlLocale } from "@/components/dashboard-view.content";
import {
  fetchAdminEconomyDashboardMetrics,
  fetchAdminEconomyPurchases,
  fetchAdminModerationQueue,
  fetchAdminTemplateGenerationMetrics,
  fetchAdminUserDashboardMetrics,
  fetchSupportInbox,
  fetchUsers,
  type AdminEconomyDashboardMetrics,
  type AdminEconomyPurchase,
  type AdminTemplateGenerationDashboardMetrics,
  type AdminSupportConversationSummary,
  type AdminUserDashboardMetrics,
  type UserListItem,
} from "@/lib/api-client";
import { type Locale } from "@/lib/i18n";
import { getAdminUserDisplayName, sanitizeSensitiveText } from "@/lib/sensitive-display";

export type DashboardActivityType = "new" | "update" | "register" | "cancel";
export type DashboardStatIcon = "people" | "cart" | "dollar" | "trendUp";
export type DashboardOrderStatusType = "new" | "processing" | "delivered" | "cancelled";

export const DASHBOARD_ORDER_STATUS_COLORS: Record<DashboardOrderStatusType, string> = {
  new: "var(--success)",
  processing: "var(--info)",
  delivered: "var(--brand)",
  cancelled: "var(--danger)",
};

export type DashboardStatItem = {
  label: string;
  value: string;
  delta: string;
  subtext: string;
  accentColor: string;
  icon: DashboardStatIcon;
  isPositiveTrend?: boolean;
};

export type DashboardOrderItem = {
  id: string;
  user: string;
  amount: string;
  status: string;
  statusType: DashboardOrderStatusType;
};

export type DashboardActivityItem = {
  id: string;
  type: DashboardActivityType;
  text: string;
  time: string;
};

export type DashboardUserDistributionItem = {
  color: string;
  tone: "success" | "brand" | "neutral";
  label: string;
  pct: string;
  count: string;
};

export type DashboardUserRoleCounts = {
  admins: number;
  moderators: number;
  users: number;
};

export type DashboardViewModel = {
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
  feedErrors: {
    purchases: boolean;
    supportConversations: boolean;
  };
};

export async function loadDashboardViewModel(
  locale: Locale,
  signal?: AbortSignal
): Promise<DashboardViewModel> {
  const requiredDataPromise = Promise.all([
    fetchDashboardUsers(signal),
    fetchPendingModerationQueueCount(signal),
    fetchAdminTemplateGenerationMetrics(signal),
    fetchAdminEconomyDashboardMetrics(signal),
  ]);
  const optionalFeedPromise = Promise.allSettled([
    fetchDashboardPurchases(signal),
    fetchDashboardSupportConversations(signal),
  ] as const);

  const [
    [usersResult, moderationQueueCount, generationMetrics, economyMetrics],
    [purchasesResult, supportConversationsResult],
  ] = await Promise.all([requiredDataPromise, optionalFeedPromise]);

  throwIfAborted(signal);

  const users = usersResult.items;
  const userMetrics = usersResult.metrics;
  const purchasesUnavailable = purchasesResult.status === "rejected";
  const supportConversationsUnavailable = supportConversationsResult.status === "rejected";
  const purchases = purchasesResult.status === "fulfilled" ? purchasesResult.value : [];
  const supportConversations =
    supportConversationsResult.status === "fulfilled" ? supportConversationsResult.value : [];

  return buildDashboardFromData(
    locale,
    users,
    userMetrics,
    generationMetrics,
    economyMetrics,
    purchases,
    supportConversations,
    moderationQueueCount,
    {
      purchases: purchasesUnavailable,
      supportConversations: supportConversationsUnavailable,
    }
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
  moderationQueueCount: number,
  feedErrors: DashboardViewModel["feedErrors"]
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
    feedErrors,
  };
}

function buildActivities(
  locale: Locale,
  users: UserListItem[],
  purchases: AdminEconomyPurchase[],
  supportConversations: AdminSupportConversationSummary[],
  userMap: Map<string, UserListItem>
): DashboardActivityItem[] {
  const copy = getDashboardCopy(locale);
  const userEvents = users
    .map((item) => ({
      id: `user:${item.userId}`,
      at: parseTimestamp(item.createdAtUtc),
      item: {
        id: `user:${item.userId}`,
        type: "register" as const,
        text: copy.activityMessages.registered(formatDashboardUserLabel(item)),
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
            statusType === "cancelled"
              ? copy.activityMessages.orderFailed(userLabel, shortOrderId(item.orderId))
              : copy.activityMessages.orderUpdated(userLabel, shortOrderId(item.orderId)),
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
        text: copy.activityMessages.ticketUpdated(
          shortConversationId(item.conversationId),
          formatDashboardLabel(item.status, 48)
        ),
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
  const copy = getDashboardCopy(locale);
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
      label: copy.roleLabels.administrators,
      pct: toPercent(admins),
      count: formatNumber(admins, locale),
    },
    {
      color: "var(--brand)",
      tone: "brand",
      label: copy.roleLabels.moderators,
      pct: toPercent(moderators),
      count: formatNumber(moderators, locale),
    },
    {
      color: "var(--neutral)",
      tone: "neutral",
      label: copy.roleLabels.users,
      pct: toPercent(regular),
      count: formatNumber(regular, locale),
    },
  ];
}

export function capitalizeTone(
  value: DashboardUserDistributionItem["tone"]
): Capitalize<DashboardUserDistributionItem["tone"]> {
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
  return new Intl.NumberFormat(getDashboardIntlLocale(locale), {
    maximumFractionDigits,
  }).format(value);
}

function formatCurrency(value: number, locale: Locale, currencyCode: string): string {
  const amount = Number.isFinite(value) ? value : 0;
  const safeCurrencyCode = normalizeCurrencyCode(currencyCode);
  try {
    return new Intl.NumberFormat(getDashboardIntlLocale(locale), {
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
  return getDashboardCopy(locale).orderStatusLabels[status];
}

function formatDashboardUserLabel(
  user: Pick<UserListItem, "displayName" | "email" | "userId">
): string {
  return formatDashboardLabel(getAdminUserDisplayName(user), 96);
}

function formatDashboardLabel(value: string | null | undefined, maxLength = 80): string {
  return sanitizeSensitiveText(value, maxLength);
}

function shortOrderId(orderId: string): string {
  const compact = formatDashboardLabel(orderId, 64).replace(/-/g, "");
  return compact ? `#${compact.slice(0, 8).toUpperCase()}` : "#UNKNOWN";
}

function shortUserId(userId: string): string {
  return formatDashboardLabel(userId, 32).slice(0, 8) || "unknown";
}

function shortConversationId(conversationId: string): string {
  const compact = formatDashboardLabel(conversationId, 32).slice(0, 6).toUpperCase();
  return compact ? `#${compact}` : "#UNKNOWN";
}

function formatRelativeTime(value: string | null | undefined, locale: Locale): string {
  const timestamp = parseTimestamp(value);
  if (timestamp === null) {
    return "—";
  }

  const relativeTimeCopy = getDashboardCopy(locale).relativeTime;
  const diffMinutes = Math.max(0, Math.round((Date.now() - timestamp) / 60_000));
  if (diffMinutes < 1) {
    return relativeTimeCopy.justNow;
  }

  if (diffMinutes < 60) {
    return relativeTimeCopy.minutesAgo(diffMinutes);
  }

  const diffHours = Math.round(diffMinutes / 60);
  if (diffHours < 24) {
    return relativeTimeCopy.hoursAgo(diffHours);
  }

  const diffDays = Math.round(diffHours / 24);
  return relativeTimeCopy.daysAgo(diffDays);
}

function buildLast7DayLabels(locale: Locale): string[] {
  const formatter = new Intl.DateTimeFormat(getDashboardIntlLocale(locale), {
    month: "short",
    day: "numeric",
  });
  const labels: string[] = [];

  for (let offset = 6; offset >= 0; offset -= 1) {
    labels.push(formatter.format(new Date(Date.now() - offset * 24 * 60 * 60 * 1000)));
  }

  return labels;
}
