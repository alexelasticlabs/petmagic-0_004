import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import {
  fetchAdminUserSessions,
  revokeAdminUserSession,
  revokeAllAdminUserSessions,
  USER_SESSION_REVOKE_REASON_MAX_LENGTH,
} from "@/lib/api-client.admin-users";

const sessionsPanelPath = fileURLToPath(
  new URL("../components/users/user-sessions-panel.tsx", import.meta.url)
);
const userDetailPagePath = fileURLToPath(
  new URL("../components/users/user-detail-page.tsx", import.meta.url)
);

describe("admin user sessions api client", () => {
  const originalPublicApiBaseUrl = process.env.NEXT_PUBLIC_API_BASE_URL;
  const originalInternalApiBaseUrl = process.env.INTERNAL_API_BASE_URL;

  beforeEach(() => {
    process.env.NEXT_PUBLIC_API_BASE_URL = "https://api.example.com";
    process.env.INTERNAL_API_BASE_URL = "https://api.example.com";
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
    vi.unstubAllGlobals();
    process.env.NEXT_PUBLIC_API_BASE_URL = originalPublicApiBaseUrl;
    process.env.INTERNAL_API_BASE_URL = originalInternalApiBaseUrl;
  });

  function businessCalls(fetchMock: ReturnType<typeof vi.fn<typeof fetch>>) {
    return fetchMock.mock.calls.filter((call) => !String(call[0]).endsWith("/api/auth/refresh"));
  }

  it("loads safe session metadata from the canonical user route", async () => {
    const fetchMock = vi.fn<typeof fetch>(async () =>
      Response.json({
        items: [],
        totalCount: 0,
        activeCount: 0,
        hasMore: false,
      })
    );
    vi.stubGlobal("fetch", fetchMock);
    const controller = new AbortController();

    await fetchAdminUserSessions("user/id", controller.signal);

    const [url, init] = businessCalls(fetchMock)[0] ?? [];
    expect(String(url)).toBe("https://api.example.com/api/admin/users/user%2Fid/sessions");
    expect(init?.method).toBe("GET");
    expect(init?.signal).toBeInstanceOf(AbortSignal);
  });

  it("revokes one session with bounded reason and actor-scoped idempotency header", async () => {
    const fetchMock = vi.fn<typeof fetch>(async () =>
      Response.json({
        userId: "user-1",
        sessionId: "session-1",
        revokedCount: 1,
        occurredAtUtc: "2026-07-27T00:00:00Z",
        replayed: false,
      })
    );
    vi.stubGlobal("fetch", fetchMock);
    const reason = ` ${"r".repeat(USER_SESSION_REVOKE_REASON_MAX_LENGTH + 20)} `;

    await revokeAdminUserSession("user-1", "session/1", reason, " revoke-intent-1 ");

    const [url, init] = businessCalls(fetchMock)[0] ?? [];
    expect(String(url)).toBe(
      "https://api.example.com/api/admin/users/user-1/sessions/session%2F1/revoke"
    );
    expect(init?.method).toBe("POST");
    expect(new Headers(init?.headers).get("Idempotency-Key")).toBe("revoke-intent-1");
    expect(JSON.parse(String(init?.body))).toEqual({
      reason: "r".repeat(USER_SESSION_REVOKE_REASON_MAX_LENGTH),
    });
  });

  it("revokes all sessions through the explicit safe action route", async () => {
    const fetchMock = vi.fn<typeof fetch>(async () =>
      Response.json({
        userId: "user-1",
        sessionId: null,
        revokedCount: 2,
        occurredAtUtc: "2026-07-27T00:00:00Z",
        replayed: false,
      })
    );
    vi.stubGlobal("fetch", fetchMock);

    await revokeAllAdminUserSessions(
      "user-1",
      "Security incident containment",
      "revoke-all-intent-1"
    );

    const [url, init] = businessCalls(fetchMock)[0] ?? [];
    expect(String(url)).toBe("https://api.example.com/api/admin/users/user-1/sessions/revoke-all");
    expect(init?.method).toBe("POST");
    expect(new Headers(init?.headers).get("Idempotency-Key")).toBe("revoke-all-intent-1");
    expect(JSON.parse(String(init?.body))).toEqual({
      reason: "Security incident containment",
    });
  });

  it("rejects unsafe mutations before network I/O", async () => {
    const fetchMock = vi.fn<typeof fetch>();
    vi.stubGlobal("fetch", fetchMock);

    await expect(revokeAdminUserSession("user-1", "session-1", "  ", "intent-1")).rejects.toThrow(
      "Session revocation reason is required."
    );
    await expect(revokeAllAdminUserSessions("user-1", "Operational reason", "  ")).rejects.toThrow(
      "Session revocation idempotency key is required."
    );
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it("keeps token material out of the User 360 session UI", () => {
    const panelSource = readFileSync(sessionsPanelPath, "utf8");
    const userDetailSource = readFileSync(userDetailPagePath, "utf8");

    expect(panelSource).not.toContain("TokenHash");
    expect(panelSource).not.toContain("refreshToken");
    expect(panelSource).not.toContain("accessToken");
    expect(panelSource).toContain("<ConfirmationDialog");
    expect(panelSource).toContain("USER_SESSION_REVOKE_REASON_MAX_LENGTH");
    expect(userDetailSource).toContain(
      "<UserSessionsPanel locale={locale} userId={user.userId} />"
    );
  });
});
