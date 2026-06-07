import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import {
  apiRequest,
  cachedGet,
  clearSession,
  getSession,
  login,
  logout,
} from "@/lib/api-client.core";

const AUTH_KEY = "petmagic_admin_auth";

type StoredSession = {
  accessToken?: string;
  refreshToken?: string;
  expiresAtUtc: string;
  user: {
    userId: string;
    email: string;
    isPremium: boolean;
    emailConfirmed: boolean;
    roles: string[];
  };
};

class MemoryStorage {
  private readonly values = new Map<string, string>();

  getItem(key: string): string | null {
    return this.values.get(key) ?? null;
  }

  setItem(key: string, value: string): void {
    this.values.set(key, value);
  }

  removeItem(key: string): void {
    this.values.delete(key);
  }
}

function createSession(): StoredSession {
  return {
    accessToken: "access-secret",
    refreshToken: "refresh-secret",
    expiresAtUtc: new Date(Date.now() + 60_000).toISOString(),
    user: {
      userId: "admin-user-id",
      email: "admin@example.com",
      isPremium: false,
      emailConfirmed: true,
      roles: ["Admin"],
    },
  };
}

function createStoredSessionForUser(userId: string, accessToken?: string): StoredSession {
  return {
    ...createSession(),
    accessToken,
    refreshToken: accessToken ? "refresh-secret" : undefined,
    user: {
      ...createSession().user,
      userId,
      email: `${userId}@example.com`,
    },
  };
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

function stubBrowser(storage = new MemoryStorage()) {
  vi.stubGlobal("window", {
    sessionStorage: storage,
    addEventListener: vi.fn(),
    removeEventListener: vi.fn(),
    dispatchEvent: vi.fn(),
  });
  return storage;
}

describe("api-client session storage", () => {
  const originalPublicApiBaseUrl = process.env.NEXT_PUBLIC_API_BASE_URL;

  beforeEach(() => {
    process.env.NEXT_PUBLIC_API_BASE_URL = "https://api.example.com";
    stubBrowser();
    clearSession();
  });

  afterEach(() => {
    clearSession();
    vi.useRealTimers();
    vi.unstubAllGlobals();
    vi.restoreAllMocks();
    process.env.NEXT_PUBLIC_API_BASE_URL = originalPublicApiBaseUrl;
  });

  it("keeps access and refresh tokens out of sessionStorage after login", async () => {
    const session = createSession();
    const fetchMock = vi.fn(async () => Response.json(session));
    vi.stubGlobal("fetch", fetchMock);

    await login("admin@example.com", "password");

    const rawStored = window.sessionStorage.getItem(AUTH_KEY);
    expect(rawStored).not.toBeNull();
    expect(rawStored).not.toContain("access-secret");
    expect(rawStored).not.toContain("refresh-secret");

    const stored = JSON.parse(rawStored ?? "{}") as StoredSession;
    expect(stored.accessToken).toBeUndefined();
    expect(stored.refreshToken).toBeUndefined();
    expect(getSession()?.accessToken).toBe("access-secret");
  });

  it("migrates legacy stored tokens into volatile memory and rewrites sanitized storage", async () => {
    const legacySession = createSession();
    window.sessionStorage.setItem(AUTH_KEY, JSON.stringify(legacySession));

    expect(getSession()?.accessToken).toBe("access-secret");

    await new Promise<void>((resolve) => queueMicrotask(resolve));

    const rawStored = window.sessionStorage.getItem(AUTH_KEY);
    expect(rawStored).not.toBeNull();
    expect(rawStored).not.toContain("access-secret");
    expect(rawStored).not.toContain("refresh-secret");

    const stored = JSON.parse(rawStored ?? "{}") as StoredSession;
    expect(stored.accessToken).toBeUndefined();
    expect(stored.refreshToken).toBeUndefined();
  });

  it("does not reuse volatile tokens for a different sanitized session user", () => {
    window.sessionStorage.setItem(
      AUTH_KEY,
      JSON.stringify(createStoredSessionForUser("admin-one", "access-one-secret"))
    );

    expect(getSession()?.accessToken).toBe("access-one-secret");

    window.sessionStorage.setItem(
      AUTH_KEY,
      JSON.stringify(createStoredSessionForUser("admin-two", undefined))
    );

    const session = getSession();
    expect(session?.user.userId).toBe("admin-two");
    expect(session?.accessToken).toBeUndefined();
  });

  it("clears corrupted stored sessions after parse failures", () => {
    const warnSpy = vi.spyOn(console, "warn").mockImplementation(() => {});
    window.sessionStorage.setItem(AUTH_KEY, "{bad-json token=raw-secret");

    expect(getSession()).toBeNull();

    expect(window.sessionStorage.getItem(AUTH_KEY)).toBeNull();
    expect(JSON.stringify(warnSpy.mock.calls)).not.toContain("raw-secret");
  });

  it("adds canonical correlation header and logs failed API requests without response bodies", async () => {
    const warnSpy = vi.spyOn(console, "warn").mockImplementation(() => {});
    const fetchMock = vi.fn(async () =>
      Response.json({ detail: "Server error. Try again later." }, { status: 500 })
    );
    vi.stubGlobal("fetch", fetchMock);

    await expect(
      apiRequest("/api/admin/users", { method: "GET" }, { requireAuth: false })
    ).rejects.toThrow("Server error. Try again later.");

    const calls = fetchMock.mock.calls as unknown as Array<[RequestInfo | URL, RequestInit?]>;
    const [, init] = calls[0] ?? [];
    const headers = init?.headers as Headers;
    const correlationId = headers.get("X-Correlation-ID");

    expect(correlationId).toBeTruthy();
    expect(warnSpy).toHaveBeenCalledWith(
      "[client:api.request_non_success]",
      expect.objectContaining({
        context: expect.objectContaining({
          path: "/api/admin/users",
          method: "GET",
          status: 500,
          correlationId: expect.any(String),
        }),
      })
    );
    expect(JSON.stringify(warnSpy.mock.calls)).not.toContain("Server error. Try again later.");
  });

  it("uses fallback messages for non-JSON error responses without noisy parse logs", async () => {
    const warnSpy = vi.spyOn(console, "warn").mockImplementation(() => {});
    const fetchMock = vi.fn(async () =>
      new Response("<html>token=raw-secret upstream failed</html>", {
        status: 502,
        headers: { "content-type": "text/html" },
      })
    );
    vi.stubGlobal("fetch", fetchMock);

    await expect(
      apiRequest("/api/admin/users", { method: "GET" }, { requireAuth: false })
    ).rejects.toThrow("Server error. Try again later.");

    const serializedLogs = JSON.stringify(warnSpy.mock.calls);
    expect(serializedLogs).toContain("api.request_non_success");
    expect(serializedLogs).not.toContain("api.error_payload_parse_failed");
    expect(serializedLogs).not.toContain("raw-secret");
    expect(serializedLogs).not.toContain("upstream failed");
  });

  it("sanitizes backend error text before exposing ApiError messages", async () => {
    vi.spyOn(console, "warn").mockImplementation(() => {});
    const fetchMock = vi.fn(async () =>
      Response.json(
        {
          detail:
            "Upload failed for alice@example.com at https://cdn.example.com/a.png?X-Amz-Signature=secret token=raw-secret",
          errors: {
            receipt: ["receipt=ios-secret card_number=4242424242424242"],
          },
        },
        { status: 422 }
      )
    );
    vi.stubGlobal("fetch", fetchMock);

    let caughtError: unknown;
    try {
      await apiRequest("/api/admin/templates/test", { method: "POST" }, { requireAuth: false });
    } catch (error) {
      caughtError = error;
    }

    expect(caughtError).toBeInstanceOf(Error);
    const apiError = caughtError as Error & { detail?: string; validationErrors?: string[] };
    const serialized = JSON.stringify({
      message: apiError.message,
      detail: apiError.detail,
      validationErrors: apiError.validationErrors,
    });

    expect(apiError.message).toContain("al***@e***.com");
    expect(apiError.message).toContain("https://cdn.example.com/a.png?***");
    expect(serialized).toContain("token=[redacted]");
    expect(serialized).toContain("receipt=[redacted]");
    expect(serialized).toContain("card_number=[redacted]");
    expect(serialized).not.toContain("alice@example.com");
    expect(serialized).not.toContain("X-Amz-Signature=secret");
    expect(serialized).not.toContain("raw-secret");
    expect(serialized).not.toContain("ios-secret");
    expect(serialized).not.toContain("4242424242424242");
  });

  it("sanitizes backend problem titles before exposing ApiError codes", async () => {
    vi.spyOn(console, "warn").mockImplementation(() => {});
    const fetchMock = vi.fn(async () =>
      Response.json(
        {
          title: "templates.invalid_status token=raw-secret",
          detail: "templates.invalid_status",
        },
        { status: 409 }
      )
    );
    vi.stubGlobal("fetch", fetchMock);

    let caughtError: unknown;
    try {
      await apiRequest("/api/admin/templates/test", { method: "POST" }, { requireAuth: false });
    } catch (error) {
      caughtError = error;
    }

    expect(caughtError).toBeInstanceOf(Error);
    const apiError = caughtError as Error & { code?: string };
    expect(apiError.code).toContain("templates.invalid_status");
    expect(apiError.code).toContain("token=[redacted]");
    expect(apiError.code).not.toContain("raw-secret");
  });

  it("logs request timeouts without request bodies or tokens", async () => {
    vi.useFakeTimers();
    const warnSpy = vi.spyOn(console, "warn").mockImplementation(() => {});
    const fetchMock = vi.fn(
      (_url: RequestInfo | URL, init?: RequestInit) =>
        new Promise<Response>((_resolve, reject) => {
          init?.signal?.addEventListener("abort", () => {
            reject(new DOMException("Aborted", "AbortError"));
          });
        })
    );
    vi.stubGlobal("fetch", fetchMock);

    const request = apiRequest(
      "/api/admin/templates/test",
      {
        method: "POST",
        body: JSON.stringify({ token: "raw-secret", receipt: "ios-secret" }),
      },
      { requireAuth: false }
    );
    const assertion = expect(request).rejects.toThrow("Request timed out. Try again.");

    await vi.advanceTimersByTimeAsync(15_000);

    await assertion;
    expect(warnSpy).toHaveBeenCalledWith(
      "[client:api.request_timeout]",
      expect.objectContaining({
        context: expect.objectContaining({
          path: "/api/admin/templates/test",
          method: "POST",
          correlationId: expect.any(String),
        }),
      })
    );
    expect(JSON.stringify(warnSpy.mock.calls)).not.toContain("raw-secret");
    expect(JSON.stringify(warnSpy.mock.calls)).not.toContain("ios-secret");
  });

  it("clears session and sends logout with correlation id without persisting tokens", async () => {
    const legacySession = createSession();
    window.sessionStorage.setItem(AUTH_KEY, JSON.stringify(legacySession));
    expect(getSession()?.accessToken).toBe("access-secret");

    const fetchMock = vi.fn(async () => new Response(null, { status: 204 }));
    vi.stubGlobal("fetch", fetchMock);

    await logout();
    await new Promise<void>((resolve) => setTimeout(resolve, 0));

    expect(window.sessionStorage.getItem(AUTH_KEY)).toBeNull();
    expect(getSession()).toBeNull();

    const calls = fetchMock.mock.calls as unknown as Array<[RequestInfo | URL, RequestInit?]>;
    const [url, init] = calls[0] ?? [];
    const headers = init?.headers as Headers;

    expect(String(url)).toBe("https://api.example.com/api/auth/logout");
    expect(init?.method).toBe("POST");
    expect(headers.get("X-Correlation-ID")).toBeTruthy();
    expect(headers.get("Authorization")).toBe("Bearer access-secret");
    expect(String(init?.body)).toContain("refresh-secret");
  });

  it("replays authenticated GET requests once after a successful token refresh", async () => {
    window.sessionStorage.setItem(AUTH_KEY, JSON.stringify(createSession()));
    expect(getSession()?.accessToken).toBe("access-secret");

    const refreshedSession = {
      ...createSession(),
      accessToken: "new-access-secret",
      refreshToken: "new-refresh-secret",
    };
    const fetchMock = vi
      .fn()
      .mockResolvedValueOnce(Response.json({ detail: "auth.expired" }, { status: 401 }))
      .mockResolvedValueOnce(Response.json(refreshedSession))
      .mockResolvedValueOnce(Response.json({ ok: true }));
    vi.stubGlobal("fetch", fetchMock);

    await expect(apiRequest("/api/admin/users", { method: "GET" })).resolves.toEqual({
      ok: true,
    });

    expect(fetchMock).toHaveBeenCalledTimes(3);
    expect(String(fetchMock.mock.calls[0]?.[0])).toBe("https://api.example.com/api/admin/users");
    expect(String(fetchMock.mock.calls[1]?.[0])).toBe("https://api.example.com/api/auth/refresh");
    expect(String(fetchMock.mock.calls[2]?.[0])).toBe("https://api.example.com/api/admin/users");
  });

  it("does not replay non-idempotent requests after token refresh and asks for manual retry", async () => {
    vi.spyOn(console, "warn").mockImplementation(() => {});
    window.sessionStorage.setItem(AUTH_KEY, JSON.stringify(createSession()));
    expect(getSession()?.accessToken).toBe("access-secret");

    const refreshedSession = {
      ...createSession(),
      accessToken: "new-access-secret",
      refreshToken: "new-refresh-secret",
    };
    const fetchMock = vi
      .fn()
      .mockResolvedValueOnce(Response.json({ title: "auth.expired" }, { status: 401 }))
      .mockResolvedValueOnce(Response.json(refreshedSession));
    vi.stubGlobal("fetch", fetchMock);

    await expect(
      apiRequest("/api/admin/users/admin-user-id/role", {
        method: "DELETE",
        body: JSON.stringify({ role: "Moderator" }),
      })
    ).rejects.toThrow("Session was refreshed. Review and retry this action.");

    expect(fetchMock).toHaveBeenCalledTimes(2);
    expect(String(fetchMock.mock.calls[0]?.[0])).toBe(
      "https://api.example.com/api/admin/users/admin-user-id/role"
    );
    expect(String(fetchMock.mock.calls[1]?.[0])).toBe("https://api.example.com/api/auth/refresh");
    expect(getSession()?.accessToken).toBe("new-access-secret");
  });

  it("clears the session when an authenticated retry still receives 401", async () => {
    vi.spyOn(console, "warn").mockImplementation(() => {});
    window.sessionStorage.setItem(AUTH_KEY, JSON.stringify(createSession()));
    expect(getSession()?.accessToken).toBe("access-secret");

    const refreshedSession = {
      ...createSession(),
      accessToken: "new-access-secret",
      refreshToken: "new-refresh-secret",
    };
    const fetchMock = vi
      .fn()
      .mockResolvedValueOnce(Response.json({ title: "auth.expired" }, { status: 401 }))
      .mockResolvedValueOnce(Response.json(refreshedSession))
      .mockResolvedValueOnce(Response.json({ title: "auth.expired" }, { status: 401 }));
    vi.stubGlobal("fetch", fetchMock);

    await expect(apiRequest("/api/admin/users", { method: "GET" })).rejects.toThrow(
      "Session expired. Sign in again."
    );

    expect(fetchMock).toHaveBeenCalledTimes(3);
    expect(window.sessionStorage.getItem(AUTH_KEY)).toBeNull();
    expect(getSession()).toBeNull();
  });

  it("does not restore a session from a stale refresh response after logout", async () => {
    vi.spyOn(console, "warn").mockImplementation(() => {});
    window.sessionStorage.setItem(AUTH_KEY, JSON.stringify(createSession()));
    expect(getSession()?.accessToken).toBe("access-secret");

    const refreshResponse = createDeferred<Response>();
    const refreshStarted = createDeferred<void>();
    const refreshedSession = {
      ...createSession(),
      accessToken: "new-access-secret",
      refreshToken: "new-refresh-secret",
    };
    const fetchMock = vi.fn(async (url: RequestInfo | URL) => {
      const requestUrl = String(url);
      if (requestUrl.endsWith("/api/admin/users")) {
        return Response.json({ title: "auth.expired" }, { status: 401 });
      }
      if (requestUrl.endsWith("/api/auth/refresh")) {
        refreshStarted.resolve();
        return refreshResponse.promise;
      }
      if (requestUrl.endsWith("/api/auth/logout")) {
        return new Response(null, { status: 204 });
      }
      return Response.json({ title: "not_found" }, { status: 404 });
    });
    vi.stubGlobal("fetch", fetchMock);

    const request = apiRequest("/api/admin/users", { method: "GET" });
    await refreshStarted.promise;

    await logout();
    expect(window.sessionStorage.getItem(AUTH_KEY)).toBeNull();

    refreshResponse.resolve(Response.json(refreshedSession));

    await expect(request).rejects.toThrow("Session expired. Sign in again.");
    expect(window.sessionStorage.getItem(AUTH_KEY)).toBeNull();
    expect(getSession()).toBeNull();
    expect(fetchMock).toHaveBeenCalledTimes(3);
    expect(fetchMock.mock.calls.map((call) => String(call[0]))).toEqual([
      "https://api.example.com/api/admin/users",
      "https://api.example.com/api/auth/refresh",
      "https://api.example.com/api/auth/logout",
    ]);
  });

  it("treats empty successful responses as undefined", async () => {
    const fetchMock = vi.fn(async () => new Response("", { status: 200 }));
    vi.stubGlobal("fetch", fetchMock);

    await expect(
      apiRequest("/api/admin/empty-action", { method: "GET" }, { requireAuth: false })
    ).resolves.toBeUndefined();
  });

  it("does not expose malformed successful response bodies", async () => {
    const warnSpy = vi.spyOn(console, "warn").mockImplementation(() => {});
    const fetchMock = vi.fn(async () => new Response("token=raw-secret {", { status: 200 }));
    vi.stubGlobal("fetch", fetchMock);

    await expect(
      apiRequest("/api/admin/bad-json", { method: "GET" }, { requireAuth: false })
    ).rejects.toThrow("Unexpected server response. Try again.");

    expect(JSON.stringify(warnSpy.mock.calls)).not.toContain("raw-secret");
    expect(JSON.stringify(warnSpy.mock.calls)).not.toContain("token=raw-secret");
  });

  it("does not share signal-scoped cached GET in-flight requests across abort signals", async () => {
    const cache = new Map<string, { value: string; expiresAt: number }>();
    const firstController = new AbortController();
    const secondController = new AbortController();

    const request = vi
      .fn<() => Promise<string>>()
      .mockImplementationOnce(
        () =>
          new Promise<string>((_resolve, reject) => {
            firstController.signal.addEventListener(
              "abort",
              () => reject(new DOMException("Aborted", "AbortError")),
              { once: true }
            );
          })
      )
      .mockResolvedValueOnce("second-response");

    const firstRequest = cachedGet("admin-list", cache, request, firstController.signal);
    const secondRequest = cachedGet("admin-list", cache, request, secondController.signal);

    firstController.abort();

    await expect(firstRequest).rejects.toThrow("Aborted");
    await expect(secondRequest).resolves.toBe("second-response");
    expect(request).toHaveBeenCalledTimes(2);
    expect(cache.get("admin-list")?.value).toBe("second-response");
  });
});
