import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import {
  ECONOMY_REFUND_REASON_MAX_LENGTH,
  ECONOMY_QUERY_FILTER_MAX_LENGTH,
  fetchAdminEconomyDashboardMetrics,
  fetchAdminEconomyLedger,
  fetchAdminRedeemCodeMetrics,
  fetchAdminRedeemCodes,
  fetchAdminRedeemCodeActivations,
  fetchAdminSubscriptionEvents,
  normalizeAdminEconomyPurchasesQuery,
  normalizeAdminRedeemCodesQuery,
  normalizeAdminEconomySubscriptionsQuery,
  refundAdminEconomyPurchase,
} from "@/lib/api-client.economy";

const economyClientPath = fileURLToPath(new URL("./api-client.economy.ts", import.meta.url));
const economyControllerPath = fileURLToPath(
  new URL("../components/use-economy-page-controller.ts", import.meta.url)
);

describe("api-client.economy query normalization", () => {
  const originalPublicApiBaseUrl = process.env.NEXT_PUBLIC_API_BASE_URL;
  const originalInternalApiBaseUrl = process.env.INTERNAL_API_BASE_URL;

  beforeEach(() => {
    process.env.NEXT_PUBLIC_API_BASE_URL = "https://api.example.com";
    process.env.INTERNAL_API_BASE_URL = "https://api.example.com";
  });

  afterEach(() => {
    vi.unstubAllGlobals();
    process.env.NEXT_PUBLIC_API_BASE_URL = originalPublicApiBaseUrl;
    process.env.INTERNAL_API_BASE_URL = originalInternalApiBaseUrl;
  });

  it("normalizes purchase filters for stable cache keys and requests", () => {
    const overlongSearch = "x".repeat(ECONOMY_QUERY_FILTER_MAX_LENGTH + 20);

    expect(
      normalizeAdminEconomyPurchasesQuery({
        skip: -10.9,
        take: 500.2,
        status: " succeeded ",
        provider: " stripe ",
        search: ` ${overlongSearch} `,
        userId: "  ",
      })
    ).toEqual({
      skip: 0,
      take: 200,
      status: "succeeded",
      provider: "stripe",
      search: "x".repeat(ECONOMY_QUERY_FILTER_MAX_LENGTH),
      userId: undefined,
    });
  });

  it("normalizes subscription filters without lowering dashboard page size", () => {
    expect(
      normalizeAdminEconomySubscriptionsQuery({
        skip: 200.8,
        take: 200.4,
        status: " Active ",
        provider: " STRIPE ",
        search: " sub_123 ",
      })
    ).toEqual({
      skip: 200,
      take: 200,
      status: "active",
      provider: "stripe",
      search: "sub_123",
    });
  });

  it("drops unsupported economy filters before backend requests", () => {
    expect(
      normalizeAdminEconomyPurchasesQuery({
        status: "chargeback",
        provider: "paypal",
        search: " order ",
        skip: 1.8,
        take: 25.2,
      })
    ).toEqual({
      skip: 1,
      take: 25,
      status: undefined,
      provider: undefined,
      search: "order",
      userId: undefined,
    });

    expect(
      normalizeAdminEconomySubscriptionsQuery({
        status: "paused",
        provider: "apple",
        search: " subscription ",
      })
    ).toEqual({
      skip: undefined,
      take: undefined,
      status: undefined,
      provider: undefined,
      search: "subscription",
    });
  });

  it("normalizes redeem code list filters for backend pagination", () => {
    const overlongSearch = "r".repeat(ECONOMY_QUERY_FILTER_MAX_LENGTH + 20);

    expect(
      normalizeAdminRedeemCodesQuery({
        skip: 12.9,
        take: 300,
        search: ` ${overlongSearch} `,
        status: " active ",
        rewardKind: " spark ",
        sort: " usage ",
      })
    ).toEqual({
      skip: 12,
      take: 200,
      search: "r".repeat(ECONOMY_QUERY_FILTER_MAX_LENGTH),
      status: "active",
      rewardKind: "spark",
      sort: "usage",
    });
  });

  it("drops unsupported redeem code filters before list and metric requests", () => {
    expect(
      normalizeAdminRedeemCodesQuery({
        search: " promo ",
        status: "deleted",
        rewardKind: "premium_days",
        sort: "random",
      })
    ).toEqual({
      skip: undefined,
      take: undefined,
      search: "promo",
      status: undefined,
      rewardKind: undefined,
      sort: undefined,
    });
  });

  it("drops non-finite economy pagination values", () => {
    expect(
      normalizeAdminEconomyPurchasesQuery({
        skip: Number.POSITIVE_INFINITY,
        take: Number.NaN,
      })
    ).toEqual({
      skip: undefined,
      take: undefined,
      status: undefined,
      provider: undefined,
      search: undefined,
      userId: undefined,
    });
  });

  it("normalizes direct economy paged request URLs", async () => {
    const fetchMock = vi.fn<typeof fetch>(async () =>
      Response.json({ items: [], skip: 0, take: 0, hasMore: false, totalCount: 0 })
    );
    const overlongSource = "l".repeat(ECONOMY_QUERY_FILTER_MAX_LENGTH + 20);
    const overlongLedgerUserId = "u".repeat(ECONOMY_QUERY_FILTER_MAX_LENGTH + 20);
    const overlongProvider = "p".repeat(ECONOMY_QUERY_FILTER_MAX_LENGTH + 20);
    const overlongStatus = "s".repeat(ECONOMY_QUERY_FILTER_MAX_LENGTH + 20);
    const overlongActivationUserId = "a".repeat(ECONOMY_QUERY_FILTER_MAX_LENGTH + 20);
    vi.stubGlobal("fetch", fetchMock);

    await fetchAdminEconomyLedger({
      skip: 4.8,
      take: 20.9,
      source: ` ${overlongSource} `,
      userId: ` ${overlongLedgerUserId} `,
    });
    await fetchAdminSubscriptionEvents({
      skip: Number.NaN,
      take: Number.POSITIVE_INFINITY,
      provider: ` ${overlongProvider} `,
      status: ` ${overlongStatus} `,
    });
    const redeemCodes = await fetchAdminRedeemCodes({
      skip: 30.2,
      take: 10.9,
      search: " launch ",
      status: " active ",
      rewardKind: " spark ",
      sort: " usage ",
    });
    await fetchAdminRedeemCodeMetrics({
      search: " launch ",
      status: " active ",
      rewardKind: " spark ",
    });
    await fetchAdminRedeemCodeActivations("redeem-1", {
      skip: 10.7,
      take: 500.2,
      userId: ` ${overlongActivationUserId} `,
    });

    expect(fetchMock.mock.calls.map((call) => String(call[0]))).toEqual([
      `https://api.example.com/api/admin/economy/ledger?skip=4&take=20&source=${"l".repeat(ECONOMY_QUERY_FILTER_MAX_LENGTH)}&userId=${"u".repeat(ECONOMY_QUERY_FILTER_MAX_LENGTH)}`,
      "https://api.example.com/api/admin/economy/subscription-events",
      "https://api.example.com/api/admin/economy/redeem-codes?skip=30&take=10&search=launch&status=active&rewardKind=spark&sort=usage",
      "https://api.example.com/api/admin/economy/redeem-codes/metrics?search=launch&status=active&rewardKind=spark",
      `https://api.example.com/api/admin/economy/redeem-codes/redeem-1/activations?skip=10&take=200&userId=${"a".repeat(ECONOMY_QUERY_FILTER_MAX_LENGTH)}`,
    ]);
    expect(redeemCodes.totalCount).toBe(0);
  });

  it("drops unsupported subscription event filters before request URLs", async () => {
    const fetchMock = vi.fn<typeof fetch>(async () =>
      Response.json({ items: [], skip: 0, take: 20, hasMore: false, totalCount: 0 })
    );
    vi.stubGlobal("fetch", fetchMock);

    await fetchAdminSubscriptionEvents({
      provider: "paypal",
      status: "ignored",
      take: 20,
    });

    await fetchAdminSubscriptionEvents({
      provider: " APP_STORE ",
      status: " Processed ",
      take: 20,
    });

    expect(fetchMock.mock.calls.map((call) => String(call[0]))).toEqual([
      "https://api.example.com/api/admin/economy/subscription-events?take=20",
      "https://api.example.com/api/admin/economy/subscription-events?take=20&provider=app_store&status=processed",
    ]);
  });

  it("requests backend redeem code metrics with abort support", async () => {
    const fetchMock = vi.fn<typeof fetch>(async () =>
      Response.json({
        totalCodes: 12,
        activeCodes: 9,
        totalUses: 34,
        totalGranted: 3400,
        createdLast7d: 3,
        activeTouchedLast7d: 4,
        usesLast7d: 8,
        grantedLast7d: 800,
      })
    );
    const controller = new AbortController();
    vi.stubGlobal("fetch", fetchMock);

    const response = await fetchAdminRedeemCodeMetrics(
      { search: "launch", status: "active", rewardKind: "spark" },
      controller.signal
    );

    const [url, init] = fetchMock.mock.calls[0] ?? [];
    expect(response.totalCodes).toBe(12);
    expect(response.totalGranted).toBe(3400);
    expect(String(url)).toBe(
      "https://api.example.com/api/admin/economy/redeem-codes/metrics?search=launch&status=active&rewardKind=spark"
    );
    expect(init?.method).toBe("GET");
    expect(init?.signal).toBeInstanceOf(AbortSignal);
  });

  it("treats admin redeem code pages as total-count backed responses", () => {
    const source = readFileSync(economyClientPath, "utf8");

    expect(source).toContain("AdminRedeemCodesPage,");
    expect(source).toContain("): Promise<AdminRedeemCodesPage>");
    expect(source).toContain("apiRequest<AdminRedeemCodesPage>");
    expect(source).not.toContain("): Promise<OffsetPagedResponse<AdminRedeemCode>>");
  });

  it("encodes economy ids before placing them in API path segments", async () => {
    const fetchMock = vi.fn<typeof fetch>(async () =>
      Response.json({ items: [], skip: 0, take: 0, hasMore: false, totalCount: 0 })
    );
    vi.stubGlobal("fetch", fetchMock);

    await fetchAdminRedeemCodeActivations("redeem/one two?x", { take: 5 });
    await refundAdminEconomyPurchase("order/one two?x", "duplicate");

    expect(fetchMock.mock.calls.map((call) => String(call[0]))).toEqual([
      "https://api.example.com/api/admin/economy/redeem-codes/redeem%2Fone%20two%3Fx/activations?take=5",
      "https://api.example.com/api/admin/economy/purchases/order%2Fone%20two%3Fx/refund",
    ]);
  });

  it("requests backend economy dashboard metrics with abort support", async () => {
    const fetchMock = vi.fn<typeof fetch>(async () =>
      Response.json({
        purchasesThisWeek: 4,
        purchasesPreviousWeek: 2,
        successfulPaymentsThisWeek: 3,
        successfulPaymentsPreviousWeek: 1,
        failedPaymentsThisWeek: 1,
        failedPaymentsPreviousWeek: 0,
        revenueThisWeek: 25,
        revenuePreviousWeek: 10,
        totalWalletCredits: 180,
        totalWalletDebits: 60,
        activeSubscriptions: 7,
        renewalStops: 2,
        currencyCode: "USD",
        revenueSeries: [],
      })
    );
    const controller = new AbortController();
    vi.stubGlobal("fetch", fetchMock);

    const response = await fetchAdminEconomyDashboardMetrics(controller.signal);

    const [url, init] = fetchMock.mock.calls[0] ?? [];
    expect(response.totalWalletCredits).toBe(180);
    expect(response.totalWalletDebits).toBe(60);
    expect(response.renewalStops).toBe(2);
    expect(String(url)).toBe("https://api.example.com/api/admin/economy/dashboard/metrics");
    expect(init?.method).toBe("GET");
    expect(init?.signal).toBeInstanceOf(AbortSignal);
  });

  it("bounds refund reasons before sending audit payloads", async () => {
    const fetchMock = vi.fn<typeof fetch>(async () =>
      Response.json({
        orderId: "order-1",
        userId: "user-1",
        packId: "pack-1",
        packCode: "starter",
        packDisplayName: "Starter",
        paymentProvider: "stripe",
        status: "refunded",
        priceAmount: 10,
        currencyCode: "USD",
        sparkToGrant: 100,
        createdAtUtc: "2026-06-07T00:00:00Z",
      })
    );
    const overlongReason = "r".repeat(ECONOMY_REFUND_REASON_MAX_LENGTH + 20);
    vi.stubGlobal("fetch", fetchMock);

    await refundAdminEconomyPurchase("order-1", ` ${overlongReason} `);

    const [, init] = fetchMock.mock.calls[0] ?? [];
    expect(String(fetchMock.mock.calls[0]?.[0])).toBe(
      "https://api.example.com/api/admin/economy/purchases/order-1/refund"
    );
    expect(JSON.parse(String(init?.body))).toEqual({
      reason: "r".repeat(ECONOMY_REFUND_REASON_MAX_LENGTH),
    });
  });

  it("propagates AbortSignal through economy GET helpers", () => {
    const source = readFileSync(economyClientPath, "utf8");

    expect(source).toContain("fetchAdminEconomyLedger(");
    expect(source).toContain("signal?: AbortSignal");
    expect(source).toContain('{ method: "GET", signal }');
    expect(source).toContain("fetchAdminSubscriptionPlans(\n  signal?: AbortSignal");
    expect(source).toContain("fetchAdminPaymentProviderConfigs(\n  signal?: AbortSignal");
    expect(source).toContain("fetchAdminSubscriptionEvents(");
    expect(source).toContain("fetchAdminEconomyDashboardMetrics(\n  signal?: AbortSignal");
    expect(source).toContain("fetchAdminCurrencyPacks(signal?: AbortSignal)");
  });

  it("uses React Query AbortSignal in the economy page controller", () => {
    const source = readFileSync(economyControllerPath, "utf8");

    expect(source).toContain("ECONOMY_QUERY_FILTER_MAX_LENGTH,");
    expect(source).toContain("const [ledgerPage, setLedgerPage] = useState(0);");
    expect(source).toContain(
      "setLedgerSource(value.trim().slice(0, ECONOMY_QUERY_FILTER_MAX_LENGTH));"
    );
    expect(source).toContain("setLedgerPage(0);");
    expect(source).toContain("const ledgerQueryParams = useMemo(");
    expect(source).toContain("setPurchaseSearch(value.slice(0, ECONOMY_QUERY_FILTER_MAX_LENGTH));");
    expect(source).toContain(
      "setSubscriptionSearch(value.slice(0, ECONOMY_QUERY_FILTER_MAX_LENGTH));"
    );
    expect(source).toContain("queryFn: ({ signal }) =>");
    expect(source).toContain("queryKey: adminQueryKeys.economyLedger(ledgerQueryParams),");
    expect(source).toContain("fetchAdminEconomyLedger(ledgerQueryParams, signal)");
    expect(source).toContain("fetchAdminSubscriptionPlans(signal)");
    expect(source).toContain("fetchAdminPaymentProviderConfigs(signal)");
    expect(source).toMatch(/fetchAdminSubscriptionEvents\(\s*\{[\s\S]*?\},\s*signal\s*\)/);
    expect(source).toContain("fetchAdminCurrencyPacks(signal)");
    expect(source).toContain("fetchAdminEconomyDashboardMetrics(signal)");
    expect(source).toContain("adminQueryKeys.economyDashboardMetrics");
    expect(source).toContain("placeholderData: keepPreviousData,");
    expect(source).not.toContain("queryFn: () => fetchAdminEconomyLedger");
    expect(source).not.toContain("queryFn: fetchAdminSubscriptionPlans");
    expect(source).not.toContain("queryFn: fetchAdminPaymentProviderConfigs");
    expect(source).not.toContain("queryFn: fetchAdminCurrencyPacks");
  });

  it("sources economy premium KPIs from backend aggregate metrics", () => {
    const source = readFileSync(economyControllerPath, "utf8");

    expect(source).toContain(
      "const activeSubscriptions = economyDashboardMetricsQuery.data?.activeSubscriptions ?? 0;"
    );
    expect(source).toContain(
      "const renewalStops = economyDashboardMetricsQuery.data?.renewalStops ?? 0;"
    );
    expect(source).not.toContain(
      'subscriptionItems.filter((item) => item.status === "active").length'
    );
    expect(source).not.toContain(
      "subscriptionItems.filter((item) => item.cancelAtPeriodEnd).length"
    );
  });

  it("sources economy revenue KPI from backend aggregate metrics", () => {
    const controllerSource = readFileSync(economyControllerPath, "utf8");
    const pageSource = readFileSync(
      fileURLToPath(new URL("../components/economy-page.tsx", import.meta.url)),
      "utf8"
    );

    expect(controllerSource).toContain(
      "const grossRevenue = economyDashboardMetricsQuery.data?.revenueThisWeek ?? 0;"
    );
    expect(controllerSource).toContain(
      'const revenueCurrencyCode = economyDashboardMetricsQuery.data?.currencyCode ?? "USD";'
    );
    expect(pageSource).toContain(
      "formatCurrency(metrics.grossRevenue, locale, metrics.revenueCurrencyCode)"
    );
    expect(controllerSource).not.toContain(
      "purchaseItems.reduce((sum, item) => sum + item.priceAmount, 0)"
    );
    expect(pageSource).not.toContain('purchaseItems[0]?.currencyCode ?? "USD"');
  });

  it("sources economy wallet flow KPIs from backend aggregate metrics", () => {
    const source = readFileSync(economyControllerPath, "utf8");

    expect(source).toContain(
      "const credited = economyDashboardMetricsQuery.data?.totalWalletCredits ?? 0;"
    );
    expect(source).toContain(
      "const debited = economyDashboardMetricsQuery.data?.totalWalletDebits ?? 0;"
    );
    expect(source).not.toContain("ledgerItems\n      .filter((item) => item.delta > 0)");
    expect(source).not.toContain("ledgerItems\n      .filter((item) => item.delta < 0)");
    expect(source).not.toContain("reduce((sum, item) => sum + item.delta, 0)");
    expect(source).not.toContain("reduce((sum, item) => sum + Math.abs(item.delta), 0)");
  });
});
