import { beforeEach, describe, expect, it, vi } from "vitest";

const apiMocks = vi.hoisted(() => ({
  fetchAdminEconomyDashboardMetrics: vi.fn(),
  fetchAdminEconomyPurchases: vi.fn(),
  fetchAdminModerationQueue: vi.fn(),
  fetchAdminSystemStatus: vi.fn(),
  fetchAdminTemplateGenerationMetrics: vi.fn(),
  fetchAdminUserDashboardMetrics: vi.fn(),
  fetchSupportInbox: vi.fn(),
  fetchSupportInboxMetrics: vi.fn(),
  fetchUsers: vi.fn(),
}));

vi.mock("@/lib/api-client", () => apiMocks);

import { isAdminSystemStatusExpired, loadDashboardViewModel } from "./dashboard-view.model";

function arrangeAvailableDashboardSources() {
  apiMocks.fetchAdminUserDashboardMetrics.mockResolvedValue({
    totalUsers: 12,
    premiumUsers: 3,
    usersThisWeek: 4,
    usersPreviousWeek: 2,
    adminUsers: 1,
    moderatorUsers: 2,
    regularUsers: 9,
  });
  apiMocks.fetchUsers.mockResolvedValue({ items: [], totalCount: 0 });
  apiMocks.fetchAdminModerationQueue.mockResolvedValue({ items: [], totalCount: 0 });
  apiMocks.fetchAdminTemplateGenerationMetrics.mockResolvedValue({
    totalJobs: 20,
    generationsToday: 2,
    generationsThisWeek: 8,
    generationsThisMonth: 20,
    failedGenerationsToday: 0,
    failedGenerationsThisWeek: 0,
    failedGenerationsThisMonth: 0,
    pendingJobs: 0,
    runningJobs: 0,
    completedJobs: 20,
    failedJobs: 0,
    cancelledJobs: 0,
    cancellingJobs: 0,
    retryingJobs: 0,
    pendingRefunds: 0,
    exhaustedRefunds: 0,
    generatedAtUtc: "2026-07-26T12:00:00Z",
  });
  apiMocks.fetchAdminEconomyDashboardMetrics.mockResolvedValue({
    purchasesThisWeek: 4,
    purchasesPreviousWeek: 2,
    successfulPaymentsThisWeek: 4,
    successfulPaymentsPreviousWeek: 2,
    failedPaymentsThisWeek: 0,
    failedPaymentsPreviousWeek: 0,
    revenueThisWeek: 40,
    revenuePreviousWeek: 20,
    totalWalletCredits: 0,
    totalWalletDebits: 0,
    activeSubscriptions: 2,
    renewalStops: 0,
    currencyCode: "USD",
    revenueSeries: [{ date: "2026-07-26", amount: 40 }],
    periodDays: 7,
    asOfUtc: "2026-07-26T12:00:00Z",
  });
  apiMocks.fetchAdminEconomyPurchases.mockResolvedValue({ items: [], totalCount: 0 });
  apiMocks.fetchSupportInbox.mockResolvedValue({ items: [], totalCount: 0 });
  apiMocks.fetchSupportInboxMetrics.mockResolvedValue({
    totalConversations: 2,
    openConversations: 0,
    closedConversations: 2,
    unassignedConversations: 0,
    unreadForAdminConversations: 0,
  });
  apiMocks.fetchAdminSystemStatus.mockResolvedValue({
    overallStatus: "healthy",
    generatedAtUtc: "2026-07-26T12:00:00Z",
    staleAfterSeconds: 60,
    checks: [
      {
        key: "api",
        status: "healthy",
        summary: "API is operational.",
        checkedAtUtc: "2026-07-26T12:00:00Z",
      },
    ],
  });
}

describe("loadDashboardViewModel source availability", () => {
  beforeEach(() => {
    vi.resetAllMocks();
    arrangeAvailableDashboardSources();
  });

  it("returns all-clear only when every attention source loaded successfully", async () => {
    const viewModel = await loadDashboardViewModel("en", 7);

    expect(viewModel.attentionSection.state).toBe("allClear");
    expect(viewModel.attentionSection.items).toEqual([]);
    expect(Object.values(viewModel.sourceAvailability).every(Boolean)).toBe(true);
    expect(Object.values(viewModel.sourceErrors).some(Boolean)).toBe(false);
  });

  it("keeps available issues visible and marks the attention check partial", async () => {
    apiMocks.fetchAdminEconomyDashboardMetrics.mockRejectedValueOnce(
      new Error("economy unavailable")
    );
    apiMocks.fetchSupportInboxMetrics.mockResolvedValueOnce({
      totalConversations: 3,
      openConversations: 3,
      closedConversations: 0,
      unassignedConversations: 1,
      unreadForAdminConversations: 2,
    });

    const viewModel = await loadDashboardViewModel("en", 7);

    expect(viewModel.attentionSection.state).toBe("issuesPartial");
    expect(viewModel.attentionSection.items.map((item) => item.key)).toEqual([
      "supportUnread",
      "supportUnassigned",
    ]);
    expect(viewModel.attentionSection.items).toContainEqual(
      expect.objectContaining({ key: "supportUnread", href: "/en/support?queue=unread" })
    );
    expect(viewModel.sourceAvailability.economyMetrics).toBe(false);
    expect(viewModel.sourceErrors.economyMetrics).toBe(true);
    expect(viewModel.revenueChart).toBeNull();
    expect(viewModel.stats).not.toContainEqual(expect.objectContaining({ href: "/en/economy" }));
  });

  it("surfaces a degraded system check as an actionable signal", async () => {
    apiMocks.fetchAdminSystemStatus.mockResolvedValueOnce({
      overallStatus: "degraded",
      generatedAtUtc: "2026-07-26T12:00:00Z",
      staleAfterSeconds: 60,
      checks: [
        {
          key: "generationScheduler",
          status: "degraded",
          summary: "Generation scheduler configuration requires attention.",
          checkedAtUtc: "2026-07-26T12:00:00Z",
        },
      ],
    });

    const viewModel = await loadDashboardViewModel("en", 7);

    expect(viewModel.attentionSection.items).toContainEqual(
      expect.objectContaining({
        key: "systemStatus",
        href: "/en/dashboard#system-status",
        tone: "warning",
      })
    );
    expect(viewModel.systemStatus?.overallStatus).toBe("degraded");
  });

  it("links exhausted refunds directly to the recovery queue", async () => {
    apiMocks.fetchAdminTemplateGenerationMetrics.mockResolvedValueOnce({
      totalJobs: 20,
      generationsToday: 2,
      generationsThisWeek: 8,
      generationsThisMonth: 20,
      failedGenerationsToday: 0,
      failedGenerationsThisWeek: 0,
      failedGenerationsThisMonth: 0,
      pendingJobs: 0,
      runningJobs: 0,
      completedJobs: 20,
      failedJobs: 0,
      cancelledJobs: 0,
      cancellingJobs: 0,
      retryingJobs: 0,
      pendingRefunds: 1,
      exhaustedRefunds: 2,
      generatedAtUtc: "2026-07-26T12:00:00Z",
    });

    const viewModel = await loadDashboardViewModel("en", 7);

    expect(viewModel.attentionSection.items).toContainEqual(
      expect.objectContaining({
        key: "exhaustedRefunds",
        value: "2",
        href: "/en/generations?refundState=exhausted",
      })
    );
  });

  it("rethrows the original AbortError instead of converting it to partial data", async () => {
    const abortError = Object.assign(new Error("cancelled"), { name: "AbortError" });
    apiMocks.fetchSupportInboxMetrics.mockRejectedValueOnce(abortError);

    await expect(loadDashboardViewModel("en", 7)).rejects.toBe(abortError);
  });
});

describe("admin system status freshness", () => {
  it("expires at the backend-provided freshness boundary", () => {
    const status = {
      generatedAtUtc: "2026-07-27T10:00:00.000Z",
      staleAfterSeconds: 60,
    };

    expect(isAdminSystemStatusExpired(status, Date.parse("2026-07-27T10:00:59.999Z"))).toBe(false);
    expect(isAdminSystemStatusExpired(status, Date.parse("2026-07-27T10:01:00.000Z"))).toBe(true);
  });

  it("treats invalid or non-positive freshness metadata as expired", () => {
    expect(
      isAdminSystemStatusExpired({ generatedAtUtc: "invalid", staleAfterSeconds: 60 }, 0)
    ).toBe(true);
    expect(
      isAdminSystemStatusExpired(
        { generatedAtUtc: "2026-07-27T10:00:00.000Z", staleAfterSeconds: 0 },
        0
      )
    ).toBe(true);
  });
});
