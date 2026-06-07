import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import {
  adjustAdminUserWallet,
  assignRole,
  fetchAdminUser,
  fetchAdminUserDashboardMetrics,
  normalizeFetchUsersQuery,
  revokeRole,
  USER_SEARCH_MAX_LENGTH,
  USER_WALLET_REASON_MAX_LENGTH,
} from "@/lib/api-client.admin-users";
import { clearAdminListCaches } from "@/lib/api-client.core";

describe("admin users api client query and role guards", () => {
  const originalPublicApiBaseUrl = process.env.NEXT_PUBLIC_API_BASE_URL;
  const originalInternalApiBaseUrl = process.env.INTERNAL_API_BASE_URL;

  beforeEach(() => {
    process.env.NEXT_PUBLIC_API_BASE_URL = "https://api.example.com";
    process.env.INTERNAL_API_BASE_URL = "https://api.example.com";
    clearAdminListCaches();
    vi.stubGlobal("window", {
      sessionStorage: {
        getItem: () => null,
        removeItem: vi.fn(),
        setItem: vi.fn(),
      },
      addEventListener: vi.fn(),
      removeEventListener: vi.fn(),
      dispatchEvent: vi.fn(),
    });
    vi.stubGlobal("fetch", vi.fn());
  });

  afterEach(() => {
    clearAdminListCaches();
    vi.unstubAllGlobals();
    process.env.NEXT_PUBLIC_API_BASE_URL = originalPublicApiBaseUrl;
    process.env.INTERNAL_API_BASE_URL = originalInternalApiBaseUrl;
  });

  it("normalizes users list query params before cache keys and request paths", () => {
    expect(
      normalizeFetchUsersQuery({
        skip: -20,
        take: 1000,
        search: ` ${"x".repeat(USER_SEARCH_MAX_LENGTH + 20)} `,
        role: "Owner",
        status: "deleted",
        isPremium: true,
      })
    ).toEqual({
      skip: 0,
      take: 100,
      search: "x".repeat(USER_SEARCH_MAX_LENGTH),
      role: undefined,
      status: undefined,
      isPremium: true,
    });

    expect(
      normalizeFetchUsersQuery({
        skip: 10.5,
        take: 25.8,
        search: " alice@example.com ",
        role: "Moderator",
        status: "blocked",
      })
    ).toEqual({
      skip: 10,
      take: 25,
      search: "alice@example.com",
      role: "Moderator",
      status: "blocked",
      isPremium: undefined,
    });
  });

  it("rejects non-admin-panel roles before sending role mutation requests", async () => {
    await expect(assignRole("user-1", "Premium")).rejects.toThrow("Invalid admin role.");
    await expect(revokeRole("user-1", "User")).rejects.toThrow("Invalid admin role.");

    expect(fetch).not.toHaveBeenCalled();
  });

  it("encodes user ids before placing them in API path segments", async () => {
    const fetchMock = vi.fn(async () =>
      Response.json({
        userId: "user/one two?x",
        email: "admin@example.com",
        name: "Admin",
        roles: ["Admin"],
      })
    );
    vi.stubGlobal("fetch", fetchMock);

    await fetchAdminUser("user/one two?x");
    await assignRole("user/one two?x", "Moderator");

    expect(fetchMock.mock.calls.map((call) => String(call[0]))).toEqual([
      "https://api.example.com/api/admin/users/user%2Fone%20two%3Fx",
      "https://api.example.com/api/admin/users/user%2Fone%20two%3Fx/role",
    ]);
  });

  it("requests backend user dashboard metrics with abort support", async () => {
    const fetchMock = vi.fn(async () =>
      Response.json({
        totalUsers: 10,
        premiumUsers: 3,
        activeUsers: 8,
        blockedUsers: 2,
        adminUsers: 1,
        moderatorUsers: 2,
        regularUsers: 7,
        usersThisWeek: 4,
        usersPreviousWeek: 2,
        newUsersLast7Days: 4,
        newUsersLast30Days: 6,
        newUsersLast90Days: 9,
      })
    );
    const controller = new AbortController();
    vi.stubGlobal("fetch", fetchMock);

    await fetchAdminUserDashboardMetrics(controller.signal);

    const [url, init] = fetchMock.mock.calls[0] ?? [];
    expect(String(url)).toBe("https://api.example.com/api/admin/users/dashboard/metrics");
    expect(init?.method).toBe("GET");
    expect(init?.signal).toBeInstanceOf(AbortSignal);
  });

  it("bounds wallet adjustment reasons before sending audit payloads", async () => {
    const fetchMock = vi.fn(async () =>
      Response.json({
        operationId: "wallet-operation-1",
        userId: "user-1",
        operation: "credit",
        amount: 10,
        reason: "ok",
        createdAtUtc: "2026-06-07T00:00:00Z",
      })
    );
    const overlongReason = "r".repeat(USER_WALLET_REASON_MAX_LENGTH + 20);
    vi.stubGlobal("fetch", fetchMock);

    await adjustAdminUserWallet("user-1", "credit", 10, ` ${overlongReason} `);

    const [, init] = fetchMock.mock.calls[0] ?? [];
    expect(String(fetchMock.mock.calls[0]?.[0])).toBe(
      "https://api.example.com/api/admin/users/user-1/wallet"
    );
    expect(JSON.parse(String(init?.body))).toEqual({
      operation: "credit",
      amount: 10,
      reason: "r".repeat(USER_WALLET_REASON_MAX_LENGTH),
    });
  });
});
