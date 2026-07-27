import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import {
  ADMIN_BULK_EMAIL_BODY_MAX_LENGTH,
  ADMIN_BULK_EMAIL_SUBJECT_MAX_LENGTH,
  adjustAdminUserWallet,
  assignRole,
  fetchAdminEmailBroadcast,
  fetchAdminEmailBroadcasts,
  fetchAdminUser,
  fetchAdminUserDashboardMetrics,
  fetchUsers,
  normalizeAdminBulkEmailRequest,
  normalizeAdminEmailBroadcastsQuery,
  normalizeFetchUsersQuery,
  queueAdminBulkEmail,
  retryFailedAdminEmailBroadcast,
  revokeRole,
  setActive,
  USER_SEARCH_MAX_LENGTH,
  USER_WALLET_REASON_MAX_LENGTH,
} from "@/lib/api-client.admin-users";
import { clearAdminListCaches, login } from "@/lib/api-client.core";

const adminUsersClientPath = fileURLToPath(new URL("./api-client.admin-users.ts", import.meta.url));

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

  function businessRequestUrls(fetchMock: ReturnType<typeof vi.fn<typeof fetch>>): string[] {
    return fetchMock.mock.calls
      .map((call) => String(call[0]))
      .filter((url) => !url.endsWith("/api/auth/refresh"));
  }

  function createDeferred<TValue>() {
    let resolve!: (value: TValue) => void;
    let reject!: (reason?: unknown) => void;
    const promise = new Promise<TValue>((promiseResolve, promiseReject) => {
      resolve = promiseResolve;
      reject = promiseReject;
    });
    return { promise, reject, resolve };
  }

  it("normalizes users list query params before cache keys and request paths", () => {
    expect(
      normalizeFetchUsersQuery({
        skip: -20,
        take: 1000,
        search: ` ${"x".repeat(USER_SEARCH_MAX_LENGTH + 20)} `,
        role: "Owner",
        status: "deleted",
        isPremium: true,
        sort: "random",
      })
    ).toEqual({
      skip: 0,
      take: 100,
      search: "x".repeat(USER_SEARCH_MAX_LENGTH),
      role: undefined,
      status: undefined,
      isPremium: true,
      sort: undefined,
    });

    expect(
      normalizeFetchUsersQuery({
        skip: 10.5,
        take: 25.8,
        search: " alice@example.com ",
        role: " moderator ",
        status: " BLOCKED ",
        sort: " LAST_ACTIVITY_ASC ",
      })
    ).toEqual({
      skip: 10,
      take: 25,
      search: "alice@example.com",
      role: "Moderator",
      status: "blocked",
      isPremium: undefined,
      sort: "last_activity_asc",
    });
  });

  it("normalizes and validates bulk email requests before queueing", () => {
    expect(
      normalizeAdminBulkEmailRequest({
        audience: "selected",
        subject: "  Service update  ",
        body: "  Scheduled maintenance details  ",
        userIds: [" user-1 ", "user-1", "", "user-2"],
      })
    ).toEqual({
      audience: "selected",
      subject: "Service update",
      body: "Scheduled maintenance details",
      userIds: ["user-1", "user-2"],
    });

    expect(() =>
      normalizeAdminBulkEmailRequest({
        audience: "selected",
        subject: "Subject",
        body: "Body",
        userIds: [],
      })
    ).toThrow("Selected bulk email audience requires at least one user.");
    expect(() =>
      normalizeAdminBulkEmailRequest({
        audience: "premium",
        subject: "x".repeat(ADMIN_BULK_EMAIL_SUBJECT_MAX_LENGTH + 1),
        body: "Body",
      })
    ).toThrow("Invalid bulk email subject.");
    expect(() =>
      normalizeAdminBulkEmailRequest({
        audience: "premium",
        subject: "Subject",
        body: "x".repeat(ADMIN_BULK_EMAIL_BODY_MAX_LENGTH + 1),
      })
    ).toThrow("Invalid bulk email body.");
  });

  it("queues a bounded bulk email payload through the canonical admin route", async () => {
    const fetchMock = vi.fn<typeof fetch>(async () =>
      Response.json(
        {
          broadcastId: "d31c5839-5889-4d85-88f8-f6ea9c87fe84",
          recipientCount: 12,
          status: "queued",
          createdAtUtc: "2026-07-27T00:00:00Z",
        },
        { status: 202 }
      )
    );
    const idempotencyKey = "bulk-email:campaign-1";
    vi.stubGlobal("fetch", fetchMock);

    const accepted = await queueAdminBulkEmail(
      {
        audience: "premium",
        subject: "  Premium service update  ",
        body: "  Important account information  ",
        userIds: ["ignored-for-non-selected-audience"],
      },
      idempotencyKey
    );

    const businessCalls = fetchMock.mock.calls.filter(
      (call) => !String(call[0]).endsWith("/api/auth/refresh")
    );
    const [url, init] = businessCalls[0] ?? [];
    expect(String(url)).toBe("https://api.example.com/api/admin/users/emails");
    expect(init?.method).toBe("POST");
    expect(new Headers(init?.headers).get("Idempotency-Key")).toBe(idempotencyKey);
    expect(JSON.parse(String(init?.body))).toEqual({
      audience: "premium",
      subject: "Premium service update",
      body: "Important account information",
      userIds: [],
    });
    expect(accepted).toMatchObject({ recipientCount: 12, status: "queued" });
  });

  it("normalizes broadcast history filters and uses safe aggregate routes", async () => {
    expect(
      normalizeAdminEmailBroadcastsQuery({
        skip: -5.4,
        take: 500.8,
        status: "unknown" as never,
      })
    ).toEqual({ skip: 0, take: 100, status: undefined });

    const broadcastId = "d31c5839-5889-4d85-88f8-f6ea9c87fe84";
    const fetchMock = vi.fn<typeof fetch>(async (input) => {
      const url = String(input);
      if (url.endsWith("/retry-failed")) {
        return Response.json({ broadcastId, retriedCount: 2, status: "queued" });
      }
      if (url.endsWith(`/${broadcastId}`)) {
        return Response.json({
          broadcastId,
          audience: "premium",
          subject: "Service update",
          status: "partially-failed",
          recipientCount: 10,
          pendingCount: 0,
          sentCount: 8,
          failedCount: 2,
          retryableFailedCount: 2,
          createdAtUtc: "2026-07-27T00:00:00Z",
          updatedAtUtc: "2026-07-27T00:02:00Z",
        });
      }
      return Response.json({ items: [], skip: 20, take: 10, totalCount: 0, hasMore: false });
    });
    vi.stubGlobal("fetch", fetchMock);

    await fetchAdminEmailBroadcasts({ skip: 20, take: 10, status: "partially-failed" });
    const detail = await fetchAdminEmailBroadcast(broadcastId);
    await retryFailedAdminEmailBroadcast(broadcastId);

    expect(detail).not.toHaveProperty("body");
    expect(detail).not.toHaveProperty("recipients");
    expect(businessRequestUrls(fetchMock)).toEqual([
      "https://api.example.com/api/admin/users/email-broadcasts?skip=20&take=10&status=partially-failed",
      `https://api.example.com/api/admin/users/email-broadcasts/${broadcastId}`,
      `https://api.example.com/api/admin/users/email-broadcasts/${broadcastId}/retry-failed`,
    ]);
    expect(fetchMock.mock.calls[2]?.[1]?.method).toBe("POST");
  });

  it("uses the canonical admin users list route without a trailing slash", async () => {
    const fetchMock = vi.fn<typeof fetch>(async () =>
      Response.json({
        items: [],
        totalCount: 0,
        skip: 0,
        take: 25,
        hasMore: false,
      })
    );
    vi.stubGlobal("fetch", fetchMock);

    await fetchUsers({ skip: 0, take: 25, search: " alice@example.com ", sort: "created_asc" });

    expect(businessRequestUrls(fetchMock)[0]).toBe(
      "https://api.example.com/api/admin/users?skip=0&take=25&search=alice%40example.com&sort=created_asc"
    );
  });

  it("serializes authoritative last-activity users sorting through backend params", async () => {
    const fetchMock = vi.fn<typeof fetch>(async () =>
      Response.json({
        items: [],
        totalCount: 0,
        skip: 0,
        take: 25,
        hasMore: false,
      })
    );
    vi.stubGlobal("fetch", fetchMock);

    await fetchUsers({ skip: 0, take: 25, sort: "last_activity_desc" });

    expect(businessRequestUrls(fetchMock)[0]).toBe(
      "https://api.example.com/api/admin/users?skip=0&take=25&sort=last_activity_desc"
    );
  });

  it("rejects non-admin-panel roles before sending role mutation requests", async () => {
    await expect(assignRole("user-1", "Premium")).rejects.toThrow("Invalid admin role.");
    await expect(revokeRole("user-1", "User")).rejects.toThrow("Invalid admin role.");

    expect(fetch).not.toHaveBeenCalled();
  });

  it("canonicalizes admin role mutations before sending requests", async () => {
    const fetchMock = vi.fn<typeof fetch>(async () => new Response(null, { status: 204 }));
    vi.stubGlobal("fetch", fetchMock);

    await assignRole("user-1", " moderator ");
    await revokeRole("user-1", " ADMIN ");

    expect(businessRequestUrls(fetchMock)).toEqual([
      "https://api.example.com/api/admin/users/user-1/role",
      "https://api.example.com/api/admin/users/user-1/role",
    ]);
    expect(
      fetchMock.mock.calls
        .filter((call) => !String(call[0]).endsWith("/api/auth/refresh"))
        .map((call) => JSON.parse(String(call[1]?.body)))
    ).toEqual([{ role: "Moderator" }, { role: "Admin" }]);
  });

  it("encodes user ids before placing them in API path segments", async () => {
    const fetchMock = vi.fn<typeof fetch>(async () =>
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

    expect(businessRequestUrls(fetchMock)).toEqual([
      "https://api.example.com/api/admin/users/user%2Fone%20two%3Fx",
      "https://api.example.com/api/admin/users/user%2Fone%20two%3Fx/role",
    ]);
  });

  it("requests backend user dashboard metrics with abort support", async () => {
    const fetchMock = vi.fn<typeof fetch>(async () =>
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

    const businessCalls = fetchMock.mock.calls.filter(
      (call) => !String(call[0]).endsWith("/api/auth/refresh")
    );
    const [url, init] = businessCalls[0] ?? [];
    expect(String(url)).toBe("https://api.example.com/api/admin/users/dashboard/metrics");
    expect(init?.method).toBe("GET");
    expect(init?.signal).toBeInstanceOf(AbortSignal);
  });

  it("bounds wallet adjustment reasons before sending audit payloads", async () => {
    const fetchMock = vi.fn<typeof fetch>(async () =>
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
    const idempotencyKey = "wallet-adjustment:retry-safe-1";
    vi.stubGlobal("fetch", fetchMock);

    await adjustAdminUserWallet("user-1", "credit", 10, ` ${overlongReason} `, idempotencyKey);

    const businessCalls = fetchMock.mock.calls.filter(
      (call) => !String(call[0]).endsWith("/api/auth/refresh")
    );
    const [, init] = businessCalls[0] ?? [];
    expect(String(businessCalls[0]?.[0])).toBe(
      "https://api.example.com/api/admin/users/user-1/wallet"
    );
    expect(JSON.parse(String(init?.body))).toEqual({
      operation: "credit",
      amount: 10,
      reason: "r".repeat(USER_WALLET_REASON_MAX_LENGTH),
    });
    expect(new Headers(init?.headers).get("Idempotency-Key")).toBe(idempotencyKey);
  });

  it("centralizes admin user cache invalidation for user mutations", () => {
    const source = readFileSync(adminUsersClientPath, "utf8");

    expect(source).toContain("function clearAdminUserCaches(userId: string): void");
    expect(source).toContain("cachedUsersLists.clear();");
    expect(source).toContain("cachedAdminUserDetails.delete(`admin-user:${userId}`);");
    expect(source).toContain("cachedAdminUserAnalytics.delete(`admin-user-analytics:${userId}`);");
    expect(source).toContain(
      'invalidateCachedGetNamespaces(["users", "admin-user", "admin-user-analytics"]);'
    );
    expect(source.match(/clearAdminUserCaches\(userId\);/g)).toHaveLength(6);
  });

  it("does not restore a stale user profile cache when a mutation wins the race", async () => {
    const staleProfileResponse = createDeferred<Response>();
    let profileRequestCount = 0;
    const session = {
      accessToken: "access-token",
      refreshToken: "refresh-token",
      expiresAtUtc: new Date(Date.now() + 60_000).toISOString(),
      user: {
        userId: "admin-user-id",
        email: "admin@example.com",
        isPremium: false,
        emailConfirmed: true,
        roles: ["Admin"],
      },
    };
    const fetchMock = vi.fn<typeof fetch>((input) => {
      const url = String(input);
      if (url.endsWith("/api/auth/login")) {
        return Promise.resolve(Response.json(session));
      }

      if (url.endsWith("/api/admin/users/user-1")) {
        profileRequestCount += 1;
        return profileRequestCount === 1
          ? staleProfileResponse.promise
          : Promise.resolve(Response.json({ userId: "user-1", email: "fresh@example.com" }));
      }

      if (url.endsWith("/api/admin/users/user-1/active")) {
        return Promise.resolve(new Response(null, { status: 204 }));
      }

      throw new Error(`Unexpected request: ${url}`);
    });
    vi.stubGlobal("fetch", fetchMock);

    await login("admin@example.com", "password");
    fetchMock.mockClear();

    const staleRequest = fetchAdminUser("user-1", new AbortController().signal);
    await setActive("user-1", false);
    staleProfileResponse.resolve(Response.json({ userId: "user-1", email: "stale@example.com" }));
    await staleRequest;

    await expect(fetchAdminUser("user-1", new AbortController().signal)).resolves.toMatchObject({
      userId: "user-1",
      email: "fresh@example.com",
    });
    expect(profileRequestCount).toBe(2);
  });
});
