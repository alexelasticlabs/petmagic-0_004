import {
  getDashboardCopy,
  getDashboardIntlLocale,
  type DashboardCommercePeriodDays,
  type DashboardStatSection,
} from "@/components/dashboard-view.content";
import {
  fetchAdminEconomyDashboardMetrics,
  fetchAdminEconomyPurchases,
  fetchAdminModerationQueue,
  fetchAdminSystemStatus,
  fetchAdminTemplateGenerationMetrics,
  fetchAdminUserDashboardMetrics,
  fetchSupportInbox,
  fetchSupportInboxMetrics,
  fetchUsers,
  type AdminEconomyDashboardMetrics,
  type AdminEconomyDashboardPeriodDays,
  type AdminEconomyPurchase,
  type AdminSupportInboxMetrics,
  type AdminSystemStatusResponse,
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
export type DashboardAttentionTone = "warning" | "danger";

export function getAdminSystemStatusExpiresAt(
  status: Pick<AdminSystemStatusResponse, "generatedAtUtc" | "staleAfterSeconds">
): number | null {
  const generatedAt = Date.parse(status.generatedAtUtc);
  const staleAfterSeconds = status.staleAfterSeconds;
  if (
    !Number.isFinite(generatedAt) ||
    !Number.isFinite(staleAfterSeconds) ||
    staleAfterSeconds <= 0
  ) {
    return null;
  }

  return generatedAt + staleAfterSeconds * 1_000;
}

export function isAdminSystemStatusExpired(
  status: Pick<AdminSystemStatusResponse, "generatedAtUtc" | "staleAfterSeconds">,
  nowMs = Date.now()
): boolean {
  const expiresAt = getAdminSystemStatusExpiresAt(status);
  return expiresAt === null || nowMs >= expiresAt;
}

export const DASHBOARD_DATA_SOURCES = [
  "userMetrics",
  "recentUsers",
  "economyMetrics",
  "purchases",
  "generationMetrics",
  "moderationQueue",
  "supportMetrics",
  "supportConversations",
  "systemStatus",
] as const;

export type DashboardDataSource = (typeof DASHBOARD_DATA_SOURCES)[number];
export type DashboardSourceAvailability = Record<DashboardDataSource, boolean>;
export type DashboardSourceErrors = Record<DashboardDataSource, boolean>;

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
  href: string;
  section: DashboardStatSection;
  isPositiveTrend?: boolean;
};

export type DashboardOrderItem = {
  id: string;
  orderHref: string;
  user: string;
  userHref: string;
  amount: string;
  status: string;
  statusType: DashboardOrderStatusType;
};

export type DashboardActivityItem = {
  id: string;
  type: DashboardActivityType;
  text: string;
  time: string;
  href: string;
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

export type DashboardAttentionItem = {
  key:
    | "supportUnread"
    | "supportUnassigned"
    | "failedPayments"
    | "failedGenerations"
    | "exhaustedRefunds"
    | "moderation"
    | "systemStatus";
  label: string;
  description: string;
  value: string;
  href: string;
  tone: DashboardAttentionTone;
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
  } | null;
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
  attentionSection: {
    title: string;
    description: string;
    openLabel: string;
    state: "issues" | "issuesPartial" | "allClear" | "partial";
    items: DashboardAttentionItem[];
  };
  stats: DashboardStatItem[];
  orders: DashboardOrderItem[];
  activities: DashboardActivityItem[];
  userDistribution: DashboardUserDistributionItem[];
  systemStatus: AdminSystemStatusResponse | null;
  sourceAvailability: DashboardSourceAvailability;
  sourceErrors: DashboardSourceErrors;
};

export async function loadDashboardViewModel(
  locale: Locale,
  commercePeriodDays: DashboardCommercePeriodDays,
  signal?: AbortSignal
): Promise<DashboardViewModel> {
  const [
    userMetricsResult,
    recentUsersResult,
    moderationQueueResult,
    generationMetricsResult,
    economyMetricsResult,
    purchasesResult,
    supportConversationsResult,
    supportMetricsResult,
    systemStatusResult,
  ] = await Promise.allSettled([
    fetchAdminUserDashboardMetrics(signal),
    fetchUsers({ skip: 0, take: 100 }, signal),
    fetchPendingModerationQueueCount(signal),
    fetchAdminTemplateGenerationMetrics(signal),
    fetchAdminEconomyDashboardMetrics({
      periodDays: commercePeriodDays as AdminEconomyDashboardPeriodDays,
      signal,
    }),
    fetchDashboardPurchases(signal),
    fetchDashboardSupportConversations(signal),
    fetchSupportInboxMetrics(signal),
    fetchAdminSystemStatus(signal),
  ] as const);

  preserveAbortError([
    userMetricsResult,
    recentUsersResult,
    moderationQueueResult,
    generationMetricsResult,
    economyMetricsResult,
    purchasesResult,
    supportConversationsResult,
    supportMetricsResult,
    systemStatusResult,
  ]);
  throwIfAborted(signal);

  const sourceAvailability: DashboardSourceAvailability = {
    userMetrics: userMetricsResult.status === "fulfilled",
    recentUsers: recentUsersResult.status === "fulfilled",
    economyMetrics: economyMetricsResult.status === "fulfilled",
    purchases: purchasesResult.status === "fulfilled",
    generationMetrics: generationMetricsResult.status === "fulfilled",
    moderationQueue: moderationQueueResult.status === "fulfilled",
    supportMetrics: supportMetricsResult.status === "fulfilled",
    supportConversations: supportConversationsResult.status === "fulfilled",
    systemStatus: systemStatusResult.status === "fulfilled",
  };
  const sourceErrors: DashboardSourceErrors = {
    userMetrics: !sourceAvailability.userMetrics,
    recentUsers: !sourceAvailability.recentUsers,
    economyMetrics: !sourceAvailability.economyMetrics,
    purchases: !sourceAvailability.purchases,
    generationMetrics: !sourceAvailability.generationMetrics,
    moderationQueue: !sourceAvailability.moderationQueue,
    supportMetrics: !sourceAvailability.supportMetrics,
    supportConversations: !sourceAvailability.supportConversations,
    systemStatus: !sourceAvailability.systemStatus,
  };

  return buildDashboardFromData({
    locale,
    commercePeriodDays,
    users: settledValue(recentUsersResult)?.items,
    userMetrics: settledValue(userMetricsResult),
    generationMetrics: settledValue(generationMetricsResult),
    economyMetrics: settledValue(economyMetricsResult),
    purchases: settledValue(purchasesResult),
    supportConversations: settledValue(supportConversationsResult),
    supportMetrics: settledValue(supportMetricsResult),
    systemStatus: settledValue(systemStatusResult),
    moderationQueueCount: settledValue(moderationQueueResult),
    sourceAvailability,
    sourceErrors,
  });
}

function preserveAbortError(results: readonly PromiseSettledResult<unknown>[]): void {
  for (const result of results) {
    if (result.status === "rejected" && isAbortError(result.reason)) {
      throw result.reason;
    }
  }
}

function isAbortError(reason: unknown): boolean {
  return (
    typeof reason === "object" &&
    reason !== null &&
    "name" in reason &&
    reason.name === "AbortError"
  );
}

function settledValue<T>(result: PromiseSettledResult<T>): T | undefined {
  return result.status === "fulfilled" ? result.value : undefined;
}

function throwIfAborted(signal?: AbortSignal): void {
  if (!signal?.aborted) {
    return;
  }

  throw new DOMException("Dashboard request was aborted.", "AbortError");
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

type DashboardBuildData = {
  locale: Locale;
  commercePeriodDays: DashboardCommercePeriodDays;
  users?: UserListItem[];
  userMetrics?: AdminUserDashboardMetrics;
  generationMetrics?: AdminTemplateGenerationDashboardMetrics;
  economyMetrics?: AdminEconomyDashboardMetrics;
  purchases?: AdminEconomyPurchase[];
  supportConversations?: AdminSupportConversationSummary[];
  supportMetrics?: AdminSupportInboxMetrics;
  systemStatus?: AdminSystemStatusResponse;
  moderationQueueCount?: number;
  sourceAvailability: DashboardSourceAvailability;
  sourceErrors: DashboardSourceErrors;
};

function buildDashboardFromData(data: DashboardBuildData): DashboardViewModel {
  const {
    locale,
    commercePeriodDays,
    userMetrics,
    generationMetrics,
    economyMetrics,
    supportMetrics,
    systemStatus,
    moderationQueueCount,
    sourceAvailability,
    sourceErrors,
  } = data;
  const copy = getDashboardCopy(locale);
  const users = data.users ?? [];
  const purchases = data.purchases ?? [];
  const supportConversations = data.supportConversations ?? [];
  const activeCommercePeriodDays =
    economyMetrics && isDashboardCommercePeriodDays(economyMetrics.periodDays)
      ? economyMetrics.periodDays
      : commercePeriodDays;
  const commercePeriodLabel = copy.commercePeriod.options[activeCommercePeriodDays];
  const purchasesSorted = [...purchases].sort((left, right) => {
    const leftTs = parseTimestamp(left.confirmedAtUtc ?? left.createdAtUtc) ?? 0;
    const rightTs = parseTimestamp(right.confirmedAtUtc ?? right.createdAtUtc) ?? 0;
    return rightTs - leftTs;
  });
  const userMap = new Map(users.map((item) => [item.userId, item]));
  const stats: DashboardStatItem[] = [];
  let totalUserCount: number | undefined;

  if (userMetrics) {
    totalUserCount = Math.max(0, userMetrics.totalUsers);
    const premiumUserCount = Math.max(0, userMetrics.premiumUsers);
    const currentUsers = Math.max(0, userMetrics.usersThisWeek);
    const previousUsers = Math.max(0, userMetrics.usersPreviousWeek);

    stats.push(
      {
        label: copy.stats.users,
        value: formatNumber(totalUserCount, locale),
        delta: formatSignedPercentDelta(
          currentUsers,
          previousUsers,
          locale,
          copy.stats.noComparison
        ),
        subtext: copy.stats.usersSubtext,
        icon: "people",
        accentColor: "var(--brand)",
        href: `/${locale}/users`,
        section: "overview",
        isPositiveTrend: hasPositiveTrend(currentUsers, previousUsers),
      },
      {
        label: copy.stats.premiumUsers,
        value: formatNumber(premiumUserCount, locale),
        delta: `${formatNumber(calculatePercentage(premiumUserCount, totalUserCount), locale, 1)}%`,
        subtext: copy.stats.premiumUsersSubtext,
        icon: "people",
        accentColor: "var(--accent)",
        href: `/${locale}/users`,
        section: "commerce",
      }
    );
  }

  if (economyMetrics) {
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
    const activeSubscriptionShare =
      totalUserCount === undefined
        ? undefined
        : calculatePercentage(activeSubscriptionCount, totalUserCount);

    stats.push(
      {
        label: copy.stats.orders,
        value: formatNumber(currentPurchasesCount, locale),
        delta: formatSignedPercentDelta(
          currentPurchasesCount,
          previousPurchasesCount,
          locale,
          copy.stats.noComparison
        ),
        subtext: copy.stats.ordersSubtext(commercePeriodLabel),
        icon: "cart",
        accentColor: "var(--success)",
        href: `/${locale}/economy`,
        section: "overview",
        isPositiveTrend: hasPositiveTrend(currentPurchasesCount, previousPurchasesCount),
      },
      {
        label: copy.stats.revenue,
        value: formatCurrency(currentRevenue, locale, revenueCurrency),
        delta: formatSignedPercentDelta(
          currentRevenue,
          previousRevenue,
          locale,
          copy.stats.noComparison
        ),
        subtext: copy.stats.revenueSubtext(commercePeriodLabel),
        icon: "dollar",
        accentColor: "var(--warning)",
        href: `/${locale}/economy`,
        section: "overview",
        isPositiveTrend: hasPositiveTrend(currentRevenue, previousRevenue),
      },
      {
        label: copy.stats.conversion,
        value: `${formatNumber(currentConversion, locale, 1)}%`,
        delta: formatSignedNumber(currentConversion - previousConversion, locale, 1, copy.stats.pp),
        subtext: copy.stats.conversionSubtext(commercePeriodLabel),
        icon: "trendUp",
        accentColor: "var(--magenta)",
        href: `/${locale}/economy`,
        section: "overview",
        isPositiveTrend: hasPositiveTrend(currentConversion, previousConversion),
      },
      {
        label: copy.stats.activeSubscriptions,
        value: formatNumber(activeSubscriptionCount, locale),
        delta:
          activeSubscriptionShare === undefined
            ? copy.stats.loadedValue
            : `${formatNumber(activeSubscriptionShare, locale, 1)}%`,
        subtext:
          activeSubscriptionShare === undefined
            ? copy.stats.activeSubscriptionsCountSubtext
            : copy.stats.activeSubscriptionsSubtext,
        icon: "dollar",
        accentColor: "var(--success)",
        href: `/${locale}/economy`,
        section: "commerce",
      },
      {
        label: copy.stats.paymentSuccessFailure,
        value: `${formatNumber(currentSucceededCount, locale)} / ${formatNumber(currentFailedPayments, locale)}`,
        delta: copy.stats.currentPeriod(commercePeriodLabel),
        subtext: copy.stats.paymentSuccessFailureSubtext(commercePeriodLabel),
        icon: "dollar",
        accentColor: currentFailedPayments > 0 ? "var(--danger)" : "var(--success)",
        href: `/${locale}/economy`,
        section: "commerce",
      }
    );
  }

  if (generationMetrics) {
    const pendingRefunds = safeNumber(generationMetrics.pendingRefunds);
    const exhaustedRefunds = safeNumber(generationMetrics.exhaustedRefunds);
    stats.push(
      {
        label: copy.stats.generationsToday,
        value: formatNumber(generationMetrics.generationsToday, locale),
        delta: `${formatNumber(generationMetrics.generationsThisWeek, locale)} ${copy.stats.weekShort}`,
        subtext: `${formatNumber(generationMetrics.generationsThisMonth, locale)} ${copy.stats.monthShort}`,
        icon: "trendUp",
        accentColor: "var(--info)",
        href: `/${locale}/generations`,
        section: "operations",
      },
      {
        label: copy.stats.failedGenerations,
        value: formatNumber(generationMetrics.failedGenerationsThisWeek, locale),
        delta:
          generationMetrics.failedGenerationsToday > 0
            ? `${formatNumber(generationMetrics.failedGenerationsToday, locale)} ${copy.stats.todayShort}`
            : copy.stats.noErrorsToday,
        subtext: `${formatNumber(generationMetrics.failedGenerationsThisMonth, locale)} ${copy.stats.monthShort}`,
        icon: "trendUp",
        accentColor:
          generationMetrics.failedGenerationsThisWeek > 0 ? "var(--danger)" : "var(--success)",
        href: `/${locale}/generations`,
        section: "operations",
      },
      {
        label: copy.stats.pendingJobs,
        value: formatNumber(generationMetrics.pendingJobs, locale),
        delta: `${formatNumber(generationMetrics.runningJobs, locale)} ${copy.stats.runningShort}`,
        subtext: copy.stats.pendingJobsSubtext,
        icon: "cart",
        accentColor: generationMetrics.pendingJobs > 0 ? "var(--warning)" : "var(--success)",
        href: `/${locale}/generations`,
        section: "operations",
      },
      {
        label: copy.stats.refundRecovery,
        value: formatNumber(pendingRefunds, locale),
        delta: `${formatNumber(exhaustedRefunds, locale)} ${copy.stats.exhaustedShort}`,
        subtext: copy.stats.refundRecoverySubtext,
        icon: "cart",
        accentColor: exhaustedRefunds > 0 ? "var(--danger)" : "var(--success)",
        href: `/${locale}/generations?refundState=${
          exhaustedRefunds > 0 ? "exhausted" : "pending"
        }`,
        section: "operations",
      }
    );
  }

  if (moderationQueueCount !== undefined) {
    stats.push({
      label: copy.stats.moderationQueue,
      value: formatNumber(moderationQueueCount, locale),
      delta: moderationQueueCount > 0 ? copy.stats.requiresReview : copy.stats.allClear,
      subtext: copy.stats.moderationQueueSubtext,
      icon: "people",
      accentColor: moderationQueueCount > 0 ? "var(--warning)" : "var(--success)",
      href: `/${locale}/moderation`,
      section: "operations",
    });
  }

  const attentionItems = buildDashboardAttentionItems({
    locale,
    commercePeriodLabel,
    economyMetrics,
    generationMetrics,
    supportMetrics,
    systemStatus,
    moderationQueueCount,
  });
  const attentionSourcesAvailable = (
    [
      "supportMetrics",
      "economyMetrics",
      "generationMetrics",
      "moderationQueue",
      "systemStatus",
    ] as const
  ).every((source) => sourceAvailability[source]);
  const attentionState = attentionItems.length
    ? attentionSourcesAvailable
      ? "issues"
      : "issuesPartial"
    : attentionSourcesAvailable
      ? "allClear"
      : "partial";
  const orders = purchasesSorted.slice(0, 5).map((item) => {
    const user = userMap.get(item.userId);
    const statusType = mapPurchaseStatus(item.status);
    return {
      id: shortOrderId(item.orderId),
      orderHref: `/${locale}/economy?workspace=overview&purchaseSearch=${encodeURIComponent(
        item.orderId
      )}`,
      user: user ? formatDashboardUserLabel(user) : shortUserId(item.userId),
      userHref: `/${locale}/users/${encodeURIComponent(item.userId)}`,
      amount: formatCurrency(item.priceAmount, locale, normalizeCurrencyCode(item.currencyCode)),
      status: getOrderStatusLabel(statusType, locale),
      statusType,
    } satisfies DashboardOrderItem;
  });
  const activities = buildActivities(locale, users, purchasesSorted, supportConversations, userMap);
  const roleCounts: DashboardUserRoleCounts | undefined = userMetrics
    ? {
        admins: Math.max(0, userMetrics.adminUsers),
        moderators: Math.max(0, userMetrics.moderatorUsers),
        users: Math.max(0, userMetrics.regularUsers),
      }
    : undefined;
  const userDistribution =
    totalUserCount !== undefined && roleCounts
      ? buildUserDistribution(locale, totalUserCount, roleCounts)
      : [];
  const revenueSeries = economyMetrics
    ? buildDashboardRevenueSeries(economyMetrics.revenueSeries, locale)
    : [];

  return {
    hero: copy.hero,
    revenueChart: economyMetrics
      ? {
          title: copy.revenueChart.title,
          description: copy.revenueChart.description(commercePeriodLabel),
          rangeLabel: commercePeriodLabel,
          ariaLabel: copy.revenueChart.ariaLabel,
          xLabels: revenueSeries.map((point) => point.label),
          values: revenueSeries.map((point) => point.value),
          currencyCode: normalizeCurrencyCode(economyMetrics.currencyCode),
        }
      : null,
    ordersSection: copy.ordersSection,
    distributionSection: {
      ...copy.distributionSection,
      totalValue: totalUserCount === undefined ? "—" : formatNumber(totalUserCount, locale),
    },
    activitySection: copy.activitySection,
    attentionSection: {
      title: copy.attentionSection.title,
      description: copy.attentionSection.description,
      openLabel: copy.attentionSection.openLabel,
      state: attentionState,
      items: attentionItems,
    },
    stats,
    orders,
    activities,
    userDistribution,
    systemStatus: systemStatus ?? null,
    sourceAvailability,
    sourceErrors,
  };
}

function buildDashboardAttentionItems({
  locale,
  commercePeriodLabel,
  economyMetrics,
  generationMetrics,
  supportMetrics,
  systemStatus,
  moderationQueueCount,
}: {
  locale: Locale;
  commercePeriodLabel: string;
  economyMetrics?: AdminEconomyDashboardMetrics;
  generationMetrics?: AdminTemplateGenerationDashboardMetrics;
  supportMetrics?: AdminSupportInboxMetrics;
  systemStatus?: AdminSystemStatusResponse;
  moderationQueueCount?: number;
}): DashboardAttentionItem[] {
  const copy = getDashboardCopy(locale).attentionSection.items;
  const items: DashboardAttentionItem[] = [];

  if (systemStatus && systemStatus.overallStatus !== "healthy") {
    items.push({
      key: "systemStatus",
      label: copy.systemStatus.label,
      description:
        systemStatus.overallStatus === "unhealthy"
          ? copy.systemStatus.unhealthyDescription
          : copy.systemStatus.degradedDescription,
      value: "!",
      href: `/${locale}/dashboard#system-status`,
      tone: systemStatus.overallStatus === "unhealthy" ? "danger" : "warning",
    });
  }

  if (supportMetrics) {
    const unreadCount = Math.max(0, supportMetrics.unreadForAdminConversations);
    const unassignedCount = Math.max(0, supportMetrics.unassignedConversations);
    if (unreadCount > 0) {
      items.push({
        key: "supportUnread",
        label: copy.supportUnread.label,
        description: copy.supportUnread.description,
        value: formatNumber(unreadCount, locale),
        href: `/${locale}/support?queue=unread`,
        tone: "warning",
      });
    }
    if (unassignedCount > 0) {
      items.push({
        key: "supportUnassigned",
        label: copy.supportUnassigned.label,
        description: copy.supportUnassigned.description,
        value: formatNumber(unassignedCount, locale),
        href: `/${locale}/support?queue=unassigned`,
        tone: "warning",
      });
    }
  }

  const failedPayments = economyMetrics
    ? Math.max(0, economyMetrics.failedPaymentsThisWeek)
    : undefined;
  if (failedPayments && failedPayments > 0) {
    items.push({
      key: "failedPayments",
      label: copy.failedPayments.label,
      description: copy.failedPayments.description(commercePeriodLabel),
      value: formatNumber(failedPayments, locale),
      href: `/${locale}/economy?workspace=overview&purchaseStatus=failed`,
      tone: "danger",
    });
  }

  const failedGenerations = generationMetrics
    ? Math.max(0, generationMetrics.failedGenerationsThisWeek)
    : undefined;
  if (failedGenerations && failedGenerations > 0) {
    items.push({
      key: "failedGenerations",
      label: copy.failedGenerations.label,
      description: copy.failedGenerations.description,
      value: formatNumber(failedGenerations, locale),
      href: `/${locale}/generations?status=Failed`,
      tone: "danger",
    });
  }

  const exhaustedRefunds = generationMetrics
    ? Math.max(0, safeNumber(generationMetrics.exhaustedRefunds))
    : undefined;
  if (exhaustedRefunds && exhaustedRefunds > 0) {
    items.push({
      key: "exhaustedRefunds",
      label: copy.exhaustedRefunds.label,
      description: copy.exhaustedRefunds.description,
      value: formatNumber(exhaustedRefunds, locale),
      href: `/${locale}/generations?refundState=exhausted`,
      tone: "danger",
    });
  }

  if (moderationQueueCount && moderationQueueCount > 0) {
    items.push({
      key: "moderation",
      label: copy.moderation.label,
      description: copy.moderation.description,
      value: formatNumber(moderationQueueCount, locale),
      href: `/${locale}/moderation?status=pending`,
      tone: "warning",
    });
  }

  return items;
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
        href: `/${locale}/users/${encodeURIComponent(item.userId)}`,
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
          href: `/${locale}/economy?workspace=overview&purchaseSearch=${encodeURIComponent(
            item.orderId
          )}`,
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
        href: `/${locale}/support/${encodeURIComponent(item.conversationId)}`,
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
  points: AdminEconomyDashboardMetrics["revenueSeries"],
  locale: Locale
): Array<{ label: string; value: number }> {
  return points.map((point) => ({
    label: formatRevenuePointDate(point.date, locale),
    value: safeNumber(point.amount),
  }));
}

function formatRevenuePointDate(value: string, locale: Locale): string {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(value);
  if (!match) {
    return formatDashboardLabel(value, 32) || "—";
  }

  const [, year, month, day] = match;
  const timestamp = Date.UTC(Number(year), Number(month) - 1, Number(day));
  if (Number.isNaN(timestamp)) {
    return formatDashboardLabel(value, 32) || "—";
  }

  return new Intl.DateTimeFormat(getDashboardIntlLocale(locale), {
    month: "short",
    day: "numeric",
    timeZone: "UTC",
  }).format(new Date(timestamp));
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

function safeNumber(value: unknown): number {
  return typeof value === "number" && Number.isFinite(value) ? value : 0;
}

function calculatePercentage(value: number, total: number): number {
  if (total <= 0) {
    return 0;
  }

  return Math.min(100, Math.max(0, (value / total) * 100));
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

function formatSignedPercentDelta(
  current: number,
  previous: number,
  locale: Locale,
  noComparisonLabel: string
): string {
  if (current === 0 && previous === 0) {
    return "0%";
  }

  if (previous === 0) {
    return noComparisonLabel;
  }

  const raw = ((current - previous) / Math.abs(previous)) * 100;
  return formatSignedNumber(raw, locale, Math.abs(raw) < 10 ? 1 : 0, "%");
}

function hasPositiveTrend(current: number, previous: number): boolean {
  return previous > 0 && current > previous;
}

function isDashboardCommercePeriodDays(value: number): value is DashboardCommercePeriodDays {
  return value === 7 || value === 30 || value === 90;
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
