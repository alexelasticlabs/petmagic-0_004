import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

import { readDashboardViewLibrarySource } from "./dashboard-view.test-source";

const dashboardContentPath = fileURLToPath(new URL("./dashboard-view.content.ts", import.meta.url));
const dashboardChartsPath = fileURLToPath(
  new URL("./dashboard/dashboard-charts.tsx", import.meta.url)
);
const dashboardStylesPath = fileURLToPath(new URL("./dashboard-view.module.css", import.meta.url));

describe("dashboard production data handling", () => {
  it("fails required KPI data instead of silently substituting zero metrics", () => {
    const source = readDashboardViewLibrarySource();

    expect(source).toContain("const requiredDataPromise = Promise.all([");
    expect(source).toContain("fetchDashboardUsers(signal)");
    expect(source).toContain("fetchPendingModerationQueueCount(signal)");
    expect(source).toContain("fetchAdminTemplateGenerationMetrics(signal)");
    expect(source).toContain("fetchAdminEconomyDashboardMetrics(signal)");
    expect(source).not.toContain("getEmptyGenerationMetrics");
    expect(source).not.toContain("generatedAtUtc: new Date(0).toISOString()");
  });

  it("keeps optional dashboard feeds partial and locally retryable", () => {
    const source = readDashboardViewLibrarySource();
    const contentSource = readFileSync(dashboardContentPath, "utf8");
    const stylesSource = readFileSync(dashboardStylesPath, "utf8");

    expect(source).toContain("const optionalFeedPromise = Promise.allSettled([");
    expect(source).toContain("fetchDashboardPurchases(signal)");
    expect(source).toContain("fetchDashboardSupportConversations(signal)");
    expect(source).toContain("feedErrors: {");
    expect(source).toContain("purchases: purchasesUnavailable");
    expect(source).toContain("supportConversations: supportConversationsUnavailable");
    expect(source).toContain("viewModel.feedErrors.purchases ? (");
    expect(source).toContain("copy.states.ordersUnavailableTitle");
    expect(source).toContain("copy.states.activityUnavailableTitle");
    expect(contentSource).toContain('ordersUnavailableTitle: "Orders temporarily unavailable"');
    expect(contentSource).toContain('activityUnavailableTitle: "Some activity is unavailable"');
    expect(source).toContain("dashboardQuery.refetch().catch(() => undefined)");
    expect(stylesSource).toContain(".feedWarning");
  });

  it("exposes retry, busy, and empty states for dashboard failures and empty live sections", () => {
    const source = readDashboardViewLibrarySource();
    const contentSource = readFileSync(dashboardContentPath, "utf8");

    expect(source).toContain(
      'const canViewDashboard = session?.user.roles.includes("Admin") ?? false;'
    );
    expect(source).toContain("enabled: canViewDashboard");
    expect(source).toContain('ensureAdminSession(locale, router, { requiredRole: "Admin" });');
    expect(source).toContain('import { adminQueryKeys } from "@/lib/admin-query-keys";');
    expect(source).toContain("queryKey: adminQueryKeys.dashboard(locale)");
    expect(source).toContain(
      "function requestDashboardRetry() {\n    if (!canViewDashboard || dashboardQuery.isFetching) {\n      return;\n    }\n\n    void dashboardQuery.refetch().catch(() => undefined);"
    );
    expect(source).toContain("onClick={requestDashboardRetry}");
    expect(source).toContain("disabled={!canViewDashboard || dashboardQuery.isFetching}");
    expect(source).toContain("const retryLabel = dashboardQuery.isFetching");
    expect(source).toContain(
      "const isShowingStaleDashboard = Boolean(viewModel && dashboardQuery.isError);"
    );
    expect(source).toContain("const copy = useMemo(() => getDashboardCopy(locale), [locale]);");
    expect(source).toContain("{isShowingStaleDashboard ? (");
    expect(source).toContain("copy.states.staleTitle");
    expect(source).toContain("copy.states.staleDescription");
    expect(source).toContain("copy.states.refreshing");
    expect(source).toContain("copy.states.retry");
    expect(source).toContain("{retryLabel}");
    expect(source).toContain("copy.states.noPaymentsTitle");
    expect(source).toContain("copy.states.noActivityTitle");
    expect(source).toContain("copy.states.noPaymentsDescription");
    expect(contentSource).toContain('staleTitle: "Data may be stale"');
    expect(contentSource).toContain(
      'staleDescription: "Showing the last loaded dashboard because the KPI refresh failed."'
    );
    expect(contentSource).toContain('refreshing: "Refreshing..."');
    expect(contentSource).toContain('retry: "Retry"');
    expect(contentSource).toContain('noPaymentsTitle: "No payments yet"');
    expect(contentSource).toContain('noActivityTitle: "No recent activity"');
    expect(contentSource).toContain(
      'noPaymentsDescription: "Recent payments will appear here after the first successful purchase."'
    );
    expect(source).not.toContain("when the backend returns purchases");
    expect(source).not.toContain("Когда backend вернет покупки");
  });

  it("sources economy dashboard KPI values from backend aggregate metrics", () => {
    const source = readDashboardViewLibrarySource();

    expect(source).toContain("fetchAdminEconomyDashboardMetrics(signal)");
    expect(source).toContain("economyMetrics: AdminEconomyDashboardMetrics");
    expect(source).toContain("economyMetrics.purchasesThisWeek");
    expect(source).toContain("economyMetrics.successfulPaymentsThisWeek");
    expect(source).toContain("economyMetrics.failedPaymentsThisWeek");
    expect(source).toContain("economyMetrics.revenueThisWeek");
    expect(source).toContain("economyMetrics.activeSubscriptions");
    expect(source).toContain("buildDashboardRevenueSeries(economyMetrics.revenueSeries)");
    expect(source).not.toContain("const currentSucceeded = currentPurchases.filter");
    expect(source).not.toContain("buildRevenueSeries(purchases");
    expect(source).not.toContain("fetchActiveSubscriptionCount");
    expect(source).not.toContain("fetchAdminEconomySubscriptions");
  });

  it("sources moderation queue KPI from the moderation backend, not support tickets", () => {
    const source = readDashboardViewLibrarySource();
    const contentSource = readFileSync(dashboardContentPath, "utf8");

    expect(source).toContain("fetchAdminModerationQueue");
    expect(source).toContain("async function fetchPendingModerationQueueCount");
    expect(source).toContain('status: "pending"');
    expect(source).toContain("take: 1");
    expect(source).toContain("return Math.max(0, response.totalCount);");
    expect(source).toContain("moderationQueueCount");
    expect(contentSource).toContain('moderationQueueSubtext: "pending moderation items"');
    expect(source).not.toContain("const maxPages = 20");
    expect(source).not.toContain("count += response.items.length");
    expect(source).not.toContain(
      'const moderationQueue = supportConversations.filter((item) => item.status !== "Closed").length;'
    );
    expect(source).not.toContain("open support tickets");
  });

  it("uses backend total counts for dashboard KPI-only queries", () => {
    const source = readDashboardViewLibrarySource();

    expect(source).toContain("fetchAdminUserDashboardMetrics(signal)");
    expect(source).toContain("metrics: AdminUserDashboardMetrics");
    expect(source).toContain("userMetrics.totalUsers");
    expect(source).toContain("userMetrics.premiumUsers");
    expect(source).toContain("userMetrics.usersThisWeek");
    expect(source).toContain("userMetrics.usersPreviousWeek");
    expect(source).toContain("fetchUsers({ skip: 0, take: 100 }, signal)");
    expect(source).toContain("return Math.max(0, response.totalCount);");
    expect(source).not.toContain("fetchUsers({ skip: 0, take: 1, isPremium: true }, signal)");
    expect(source).not.toContain('fetchUsers({ role: "Admin", skip: 0, take: 1 }, signal)');
    expect(source).not.toContain('fetchUsers({ role: "Moderator", skip: 0, take: 1 }, signal)');
    expect(source).not.toContain('fetchUsers({ role: "User", skip: 0, take: 1 }, signal)');
    expect(source).not.toContain("startOfDayTimestamp");
    expect(source).not.toContain("const currentUsers = users.filter");
    expect(source).not.toContain("const previousUsers = users.filter");
    expect(source).not.toContain("adminRolePage.totalCount");
    expect(source).not.toContain("moderatorRolePage.totalCount");
    expect(source).not.toContain("userRolePage.totalCount");
    expect(source).toContain("const roleCounts: DashboardUserRoleCounts = {");
    expect(source).toContain('status: "pending"');
    expect(source).not.toContain("function getOptionalTotalCount(response: unknown)");
  });

  it("builds dashboard role distribution from backend role totals, not sampled users", () => {
    const source = readDashboardViewLibrarySource();
    const contentSource = readFileSync(dashboardContentPath, "utf8");

    expect(source).toContain("type DashboardUserRoleCounts = {");
    expect(source).toContain(
      "const userDistribution = buildUserDistribution(locale, totalUserCount, roleCounts)"
    );
    expect(source).toContain("const admins = Math.max(0, roleCounts.admins)");
    expect(source).toContain("const moderators = Math.max(0, roleCounts.moderators)");
    expect(source).toContain("const regular = Math.max(0, roleCounts.users)");
    expect(source).toContain("const roleTotal = admins + moderators + regular");
    expect(source).toContain("const copy = getDashboardCopy(locale);");
    expect(source).toContain("copy.roleLabels.moderators");
    expect(contentSource).toContain('moderators: "Модераторы"');
    expect(contentSource).toContain('moderators: "Moderators"');
    expect(source).not.toContain("const userDistribution = buildUserDistribution(locale, users)");
    expect(source).not.toContain("const normalizedRoles = item.roles.map");
    expect(source).not.toContain("users.length - admins - managers");
  });

  it("keeps dashboard currency formatting non-throwing for backend currency codes", () => {
    const source = readDashboardViewLibrarySource();
    const chartSource = readFileSync(dashboardChartsPath, "utf8");
    const contentSource = readFileSync(dashboardContentPath, "utf8");

    expect(source).toContain("function isSupportedCurrencyCode(currencyCode: string)");
    expect(source).toContain('return isSupportedCurrencyCode(normalized) ? normalized : "USD"');
    expect(source).toContain("const safeCurrencyCode = normalizeCurrencyCode(currencyCode)");
    expect(source).toContain("sanitizeSensitiveText(safeCurrencyCode, 12)");
    expect(source).toContain("getDashboardIntlLocale(locale)");
    expect(source).not.toContain('locale === "ru" ? "ru-RU" : "en-US"');
    expect(contentSource).toContain(
      "export function getDashboardIntlLocale(locale: Locale): string"
    );
    expect(chartSource).toContain("function normalizeChartCurrencyCode(value: string)");
    expect(chartSource).toContain("function formatChartCurrencyAmount(");
    expect(chartSource).toContain("className={styles.chartDataTable}");
    expect(chartSource).toContain('<th scope="col">Date</th>');
    expect(chartSource).toContain('<th scope="col">Revenue</th>');
    expect(chartSource).toContain(
      'formatChartCurrencyAmount(value, normalizeChartCurrencyCode(currencyCode), "standard", 2)'
    );
    expect(source).not.toContain("currency: currencyCode,");
    expect(chartSource).not.toContain("currency: currencyCode,");
  });

  it("keeps dashboard chart and status colors theme-token based", () => {
    const source = readDashboardViewLibrarySource();
    const chartSource = readFileSync(dashboardChartsPath, "utf8");
    const stylesSource = readFileSync(dashboardStylesPath, "utf8");
    const visualSource = [source, chartSource, stylesSource].join("\n");
    const nonZeroLetterSpacingRules = [...stylesSource.matchAll(/letter-spacing:\s*([^;]+);/g)]
      .map((match) => match[1]?.trim())
      .filter((value) => value !== "0");

    expect(source).toContain('accentColor: "var(--success)"');
    expect(source).toContain('color: "var(--brand)"');
    expect(source).toContain('cancelled: "var(--danger)"');
    expect(chartSource).toContain('stopColor="var(--success)"');
    expect(chartSource).toContain('stroke="var(--border-soft)"');
    expect(chartSource).toContain('fill="var(--text-muted)"');
    expect(stylesSource).toContain("color: var(--accent-strong);");
    expect(stylesSource).toContain(".chartDataTable");
    expect(stylesSource).toContain("clip-path: inset(50%);");
    expect(stylesSource).toContain(
      "color: color-mix(in srgb, var(--success) 82%, var(--text-strong));"
    );
    expect(stylesSource).toContain(
      "color: color-mix(in srgb, var(--danger) 86%, var(--text-strong));"
    );
    expect(stylesSource).toContain("border-bottom: 1px solid var(--border-soft);");
    expect(stylesSource).toContain("letter-spacing: 0;");
    expect(visualSource).not.toMatch(/#[0-9a-fA-F]{3,8}/);
    expect(visualSource).not.toContain("rgba(");
    expect(nonZeroLetterSpacingRules).toEqual([]);
  });

  it("keeps dashboard icons and tone colors in shared components and CSS module classes", () => {
    const source = readDashboardViewLibrarySource();
    const stylesSource = readFileSync(dashboardStylesPath, "utf8");

    expect(source).toContain("CaretDownIcon");
    expect(source).toContain("styles.toolbarChevron");
    expect(source).toContain("styles.activityIconSuccess");
    expect(source).toContain("styles.activityIconInfo");
    expect(source).toContain("styles.activityIconBrand");
    expect(source).toContain("styles.activityIconDanger");
    expect(source).toContain("styles[`legendDot${capitalizeTone(item.tone)}`]");
    expect(stylesSource).toContain(".toolbarChevron");
    expect(stylesSource).toContain(".legendDotSuccess");
    expect(stylesSource).toContain(".legendDotBrand");
    expect(stylesSource).toContain(".legendDotNeutral");
    expect(stylesSource).toContain(".activityIconSuccess");
    expect(stylesSource).toContain(".activityIconInfo");
    expect(stylesSource).toContain(".activityIconBrand");
    expect(stylesSource).toContain(".activityIconDanger");
    expect([source, stylesSource].join("\n")).not.toContain("--activity-color");
    expect([source, stylesSource].join("\n")).not.toContain("--legend-color");
    expect(source).not.toContain("<svg");
    expect(source).not.toContain("CSSProperties");
  });

  it("keeps dashboard legend labels readable on narrow screens", () => {
    const stylesSource = readFileSync(dashboardStylesPath, "utf8");

    expect(stylesSource).toContain("@media (max-width: 640px)");
    expect(stylesSource).toContain(
      ".legendItem {\n    grid-template-columns: auto minmax(0, 1fr);"
    );
    expect(stylesSource).toContain(".legendLabel {\n    overflow: visible;");
    expect(stylesSource).toContain("text-overflow: clip;");
    expect(stylesSource).toContain("white-space: normal;");
    expect(stylesSource).toContain("overflow-wrap: anywhere;");
    expect(stylesSource).toContain(".legendPercent,\n  .legendCount {\n    grid-column: 2;");
  });

  it("keeps dashboard card titles and actions from overflowing narrow headers", () => {
    const stylesSource = readFileSync(dashboardStylesPath, "utf8");

    expect(stylesSource).toContain(".cardTitleWithIcon,\n.cardActionLink {\n  min-width: 0;");
    expect(stylesSource).toContain(
      ".cardTitleWithIcon span,\n.cardActionLink span {\n  min-width: 0;"
    );
    expect(stylesSource).toContain("overflow-wrap: anywhere;");
    expect(stylesSource).toContain("text-align: right;");
    expect(stylesSource).toContain("@media (max-width: 640px)");
    expect(stylesSource).toContain(".cardActionLink {\n    text-align: left;");
  });

  it("sanitizes dashboard user, support, and identifier labels before rendering", () => {
    const source = readDashboardViewLibrarySource();
    const contentSource = readFileSync(dashboardContentPath, "utf8");

    expect(source).toContain("function formatDashboardUserLabel(");
    expect(source).toContain("return formatDashboardLabel(getAdminUserDisplayName(user), 96);");
    expect(source).toContain("function formatDashboardLabel(");
    expect(source).toContain("return sanitizeSensitiveText(value, maxLength);");
    expect(source).toContain("user ? formatDashboardUserLabel(user) : shortUserId(item.userId)");
    expect(source).toContain("activityMessages.registered(formatDashboardUserLabel(item))");
    expect(source).toContain("formatDashboardLabel(item.status, 48)");
    expect(source).toContain("formatDashboardLabel(orderId, 64).replace");
    expect(source).toContain(
      'return compact ? `#${compact.slice(0, 8).toUpperCase()}` : "#UNKNOWN";'
    );
    expect(source).toContain('return formatDashboardLabel(userId, 32).slice(0, 8) || "unknown";');
    expect(source).toContain('return compact ? `#${compact}` : "#UNKNOWN";');
    expect(contentSource).toContain(
      "registered: (userLabel) => `${userLabel} registered in the system`"
    );
    expect(contentSource).toContain(
      "ticketUpdated: (ticketId, status) => `Updated ticket ${ticketId}: ${status}`"
    );
    expect(source).not.toContain("user ? getAdminUserDisplayName(user) : shortUserId(item.userId)");
    expect(source).not.toContain("${getAdminUserDisplayName(item)} registered in the system");
    expect(source).not.toContain(": ${item.status}`");
  });
});
