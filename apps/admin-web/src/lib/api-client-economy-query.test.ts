import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import {
  fetchAdminEconomyLedger,
  fetchAdminRedeemCodeActivations,
  fetchAdminSubscriptionEvents,
  normalizeAdminEconomyPurchasesQuery,
  normalizeAdminEconomySubscriptionsQuery,
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
    expect(
      normalizeAdminEconomyPurchasesQuery({
        skip: -10.9,
        take: 500.2,
        status: " succeeded ",
        provider: " stripe ",
        search: " user@example.com ",
        userId: "  ",
      })
    ).toEqual({
      skip: 0,
      take: 200,
      status: "succeeded",
      provider: "stripe",
      search: "user@example.com",
      userId: undefined,
    });
  });

  it("normalizes subscription filters without lowering dashboard page size", () => {
    expect(
      normalizeAdminEconomySubscriptionsQuery({
        skip: 200.8,
        take: 200.4,
        status: " Active ",
        provider: "  ",
        search: " sub_123 ",
      })
    ).toEqual({
      skip: 200,
      take: 200,
      status: "Active",
      provider: undefined,
      search: "sub_123",
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
    const fetchMock = vi.fn(async () =>
      Response.json({ items: [], skip: 0, take: 0, hasMore: false, totalCount: 0 })
    );
    vi.stubGlobal("fetch", fetchMock);

    await fetchAdminEconomyLedger({
      skip: 4.8,
      take: 20.9,
      source: " pack_purchase ",
      userId: " user-1 ",
    });
    await fetchAdminSubscriptionEvents({
      skip: Number.NaN,
      take: Number.POSITIVE_INFINITY,
      provider: " stripe ",
      status: " processed ",
    });
    await fetchAdminRedeemCodeActivations("redeem-1", {
      skip: 10.7,
      take: 500.2,
      userId: " user-2 ",
    });

    expect(fetchMock.mock.calls.map((call) => String(call[0]))).toEqual([
      "https://api.example.com/api/admin/economy/ledger?skip=4&take=20&source=pack_purchase&userId=user-1",
      "https://api.example.com/api/admin/economy/subscription-events?provider=stripe&status=processed",
      "https://api.example.com/api/admin/economy/redeem-codes/redeem-1/activations?skip=10&take=200&userId=user-2",
    ]);
  });

  it("propagates AbortSignal through economy GET helpers", () => {
    const source = readFileSync(economyClientPath, "utf8");

    expect(source).toContain("fetchAdminEconomyLedger(");
    expect(source).toContain("signal?: AbortSignal");
    expect(source).toContain("{ method: \"GET\", signal }");
    expect(source).toContain("fetchAdminSubscriptionPlans(\n  signal?: AbortSignal");
    expect(source).toContain("fetchAdminPaymentProviderConfigs(\n  signal?: AbortSignal");
    expect(source).toContain("fetchAdminSubscriptionEvents(");
    expect(source).toContain("fetchAdminCurrencyPacks(signal?: AbortSignal)");
  });

  it("uses React Query AbortSignal in the economy page controller", () => {
    const source = readFileSync(economyControllerPath, "utf8");

    expect(source).toContain("queryFn: ({ signal }) =>");
    expect(source).toContain("fetchAdminEconomyLedger({ take: 20, source: ledgerSource || undefined }, signal)");
    expect(source).toContain("fetchAdminSubscriptionPlans(signal)");
    expect(source).toContain("fetchAdminPaymentProviderConfigs(signal)");
    expect(source).toContain("fetchAdminSubscriptionEvents({");
    expect(source).toContain("}, signal)");
    expect(source).toContain("fetchAdminCurrencyPacks(signal)");
    expect(source).not.toContain("queryFn: () => fetchAdminEconomyLedger");
    expect(source).not.toContain("queryFn: fetchAdminSubscriptionPlans");
    expect(source).not.toContain("queryFn: fetchAdminPaymentProviderConfigs");
    expect(source).not.toContain("queryFn: fetchAdminCurrencyPacks");
  });
});
