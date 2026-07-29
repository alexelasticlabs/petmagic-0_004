import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import {
  acknowledgeAdminNotification,
  archiveAdminNotification,
  buildAdminNotificationsPath,
  fetchAdminNotifications,
  markAdminNotificationRead,
  markAllAdminNotificationsRead,
} from "@/lib/api-client.notifications";

describe("api-client.notifications", () => {
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

  it("builds bounded cursor filters deterministically", () => {
    expect(
      buildAdminNotificationsPath({
        cursor: " cursor/value ",
        take: 500,
        state: "unread",
        category: "generation failures",
        priority: "critical",
      })
    ).toBe(
      "/api/admin/notifications?take=100&cursor=cursor%2Fvalue&state=unread&category=generation+failures&priority=critical"
    );
  });

  it("uses the REST contract including read-all cutoff and If-Match", async () => {
    const fetchMock = vi.fn<typeof fetch>(async (input) => {
      if (String(input).includes("?take=")) {
        return Response.json({
          items: [],
          nextCursor: null,
          unreadCount: 0,
          criticalUnacknowledgedCount: 0,
          asOfUtc: "2026-07-29T10:00:00Z",
        });
      }
      return Response.json({ notificationId: "event/1", version: 2, payload: {} });
    });
    vi.stubGlobal("fetch", fetchMock);

    await fetchAdminNotifications({ take: 24 });
    await markAdminNotificationRead("event/1");
    await markAllAdminNotificationsRead("2026-07-29T10:00:00Z");
    await archiveAdminNotification("event/1");
    await acknowledgeAdminNotification("event/1", 7, "Verified provider recovery");

    expect(fetchMock).toHaveBeenCalledTimes(5);
    const calls = fetchMock.mock.calls;
    expect(String(calls[1]?.[0])).toContain("/event%2F1/read");
    expect(calls[2]?.[1]?.body).toBe(JSON.stringify({ cutoffUtc: "2026-07-29T10:00:00Z" }));
    expect(String(calls[3]?.[0])).toContain("/event%2F1/archive");
    expect(new Headers(calls[4]?.[1]?.headers).get("If-Match")).toBe('\"7\"');
    expect(calls[4]?.[1]?.body).toBe(JSON.stringify({ reason: "Verified provider recovery" }));
  });
});
