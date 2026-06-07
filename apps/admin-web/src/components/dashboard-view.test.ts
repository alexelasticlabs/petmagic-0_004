import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const dashboardViewPath = fileURLToPath(new URL("./dashboard-view.tsx", import.meta.url));
const dashboardChartsPath = fileURLToPath(
  new URL("./dashboard/dashboard-charts.tsx", import.meta.url)
);

describe("dashboard production data handling", () => {
  it("fails the dashboard query instead of silently substituting zero metrics", () => {
    const source = readFileSync(dashboardViewPath, "utf8");

    expect(source).toContain("await Promise.all([");
    expect(source).not.toContain("Promise.allSettled");
    expect(source).not.toContain("getEmptyGenerationMetrics");
    expect(source).not.toContain("generatedAtUtc: new Date(0).toISOString()");
  });

  it("exposes retry and empty states for dashboard failures and empty live sections", () => {
    const source = readFileSync(dashboardViewPath, "utf8");

    expect(source).toContain("dashboardQuery.refetch().catch(() => undefined)");
    expect(source).toContain("disabled={dashboardQuery.isFetching}");
    expect(source).toContain("No payments yet");
    expect(source).toContain("No recent activity");
  });

  it("fetches dashboard purchase pages sequentially and stops when backend pagination ends", () => {
    const source = readFileSync(dashboardViewPath, "utf8");

    expect(source).toContain("for (let page = 0; page < maxPages; page += 1)");
    expect(source).toContain("if (!response.hasMore) {");
    expect(source).not.toContain("Array.from({ length: maxPages }");
  });

  it("sources moderation queue KPI from the moderation backend, not support tickets", () => {
    const source = readFileSync(dashboardViewPath, "utf8");

    expect(source).toContain("fetchAdminModerationQueue");
    expect(source).toContain("async function fetchPendingModerationQueueCount");
    expect(source).toContain('status: "pending"');
    expect(source).toContain("moderationQueueCount");
    expect(source).toContain("pending moderation items");
    expect(source).not.toContain(
      "const moderationQueue = supportConversations.filter((item) => item.status !== \"Closed\").length;"
    );
    expect(source).not.toContain("open support tickets");
  });

  it("uses backend total counts for dashboard KPI-only queries", () => {
    const source = readFileSync(dashboardViewPath, "utf8");

    expect(source).toContain("function getOptionalTotalCount(response: unknown)");
    expect(source).toContain("const totalCount = getOptionalTotalCount(response);");
    expect(source).toContain("return totalCount;");
    expect(source).toContain('status: "Active"');
    expect(source).toContain('status: "pending"');
    expect(source).toContain("count += response.items.length");
  });

  it("keeps dashboard currency formatting non-throwing for backend currency codes", () => {
    const source = readFileSync(dashboardViewPath, "utf8");
    const chartSource = readFileSync(dashboardChartsPath, "utf8");

    expect(source).toContain("function isSupportedCurrencyCode(currencyCode: string)");
    expect(source).toContain("return isSupportedCurrencyCode(normalized) ? normalized : \"USD\"");
    expect(source).toContain("const safeCurrencyCode = normalizeCurrencyCode(currencyCode)");
    expect(source).toContain("sanitizeSensitiveText(safeCurrencyCode, 12)");
    expect(chartSource).toContain("function normalizeChartCurrencyCode(value: string)");
    expect(chartSource).toContain("function formatChartCurrencyAmount(");
    expect(source).not.toContain("currency: currencyCode,");
    expect(chartSource).not.toContain("currency: currencyCode,");
  });

  it("sanitizes dashboard user, support, and identifier labels before rendering", () => {
    const source = readFileSync(dashboardViewPath, "utf8");

    expect(source).toContain("function formatDashboardUserLabel(");
    expect(source).toContain("return formatDashboardLabel(getAdminUserDisplayName(user), 96);");
    expect(source).toContain("function formatDashboardLabel(");
    expect(source).toContain("return sanitizeSensitiveText(value, maxLength);");
    expect(source).toContain("user ? formatDashboardUserLabel(user) : shortUserId(item.userId)");
    expect(source).toContain("${formatDashboardUserLabel(item)} registered in the system");
    expect(source).toContain("formatDashboardLabel(item.status, 48)");
    expect(source).toContain("formatDashboardLabel(orderId, 64).replace");
    expect(source).toContain("formatDashboardLabel(userId, 32).slice(0, 8)");
    expect(source).toContain("formatDashboardLabel(conversationId, 32).slice(0, 6)");
    expect(source).not.toContain("user ? getAdminUserDisplayName(user) : shortUserId(item.userId)");
    expect(source).not.toContain("${getAdminUserDisplayName(item)} registered in the system");
    expect(source).not.toContain(": ${item.status}`");
  });
});
