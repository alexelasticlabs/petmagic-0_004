import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import {
  apiRequest,
  cachedGet,
  clearSession,
  getSession,
  invalidateCachedGetNamespaces,
  login,
  logout,
} from "@/lib/api-client.core";

const AUTH_KEY = "petmagic_admin_auth";
const apiClientCorePath = fileURLToPath(new URL("./api-client.core.ts", import.meta.url));

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

class RemoveFailureStorage extends MemoryStorage {
  override removeItem(): void {
    throw new Error("sessionStorage unavailable");
  }
}

class GetFailureStorage extends MemoryStorage {
  override getItem(): string | null {
    throw new Error("sessionStorage unavailable token=raw-secret");
  }
}

class SetFailureStorage extends MemoryStorage {
  override setItem(): void {
    throw new Error("sessionStorage quota exceeded token=raw-secret");
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
    refreshToken: undefined,
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

async function seedLoggedInSession(session: StoredSession = createSession()) {
  const fetchMock = vi.fn(async () => Response.json(session));
  vi.stubGlobal("fetch", fetchMock);
  await login("admin@example.com", "password");
  return fetchMock;
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

  it("clears persisted token sessions instead of reviving them", () => {
    const warnSpy = vi.spyOn(console, "warn").mockImplementation(() => {});
    const legacySession = createSession();
    window.sessionStorage.setItem(AUTH_KEY, JSON.stringify(legacySession));

    expect(getSession()).toBeNull();
    expect(window.sessionStorage.getItem(AUTH_KEY)).toBeNull();
    const serializedLogs = JSON.stringify(warnSpy.mock.calls);
    expect(serializedLogs).toContain("auth.persisted_token_session_cleared");
    expect(serializedLogs).not.toContain("access-secret");
    expect(serializedLogs).not.toContain("refresh-secret");
  });

  it("does not reuse volatile tokens for a different sanitized session user", async () => {
    const session = {
      ...createSession(),
      accessToken: "access-one-secret",
      refreshToken: "refresh-one-secret",
      user: {
        ...createSession().user,
        userId: "admin-one",
        email: "admin-one@example.com",
      },
    };
    await seedLoggedInSession(session);
    expect(getSession()?.accessToken).toBe("access-one-secret");

    window.sessionStorage.setItem(
      AUTH_KEY,
      JSON.stringify(createStoredSessionForUser("admin-two"))
    );

    const resolvedSession = getSession();
    expect(resolvedSession?.user.userId).toBe("admin-two");
    expect(resolvedSession?.accessToken).toBeUndefined();
  });

  it("clears corrupted stored sessions after parse failures", () => {
    const warnSpy = vi.spyOn(console, "warn").mockImplementation(() => {});
    window.sessionStorage.setItem(AUTH_KEY, "{bad-json token=raw-secret");

    expect(getSession()).toBeNull();

    expect(window.sessionStorage.getItem(AUTH_KEY)).toBeNull();
    expect(JSON.stringify(warnSpy.mock.calls)).not.toContain("raw-secret");
  });

  it("keeps admin signed out when sessionStorage reads fail", () => {
    const warnSpy = vi.spyOn(console, "warn").mockImplementation(() => {});
    stubBrowser(new GetFailureStorage());

    expect(getSession()).toBeNull();

    const serializedLogs = JSON.stringify(warnSpy.mock.calls);
    expect(serializedLogs).toContain("auth.session_read_failed");
    expect(serializedLogs).not.toContain("raw-secret");
  });

  it("clears malformed admin-shaped sessions before they can crash the shell", () => {
    const warnSpy = vi.spyOn(console, "warn").mockImplementation(() => {});
    window.sessionStorage.setItem(
      AUTH_KEY,
      JSON.stringify({
        accessToken: "legacy-access-secret",
        refreshToken: "legacy-refresh-secret",
        expiresAt: Date.now() + 60_000,
        admin: {
          id: "admin-user-id",
          email: "admin@example.com",
          roles: ["Admin"],
        },
      })
    );

    expect(getSession()).toBeNull();

    expect(window.sessionStorage.getItem(AUTH_KEY)).toBeNull();
    const serializedLogs = JSON.stringify(warnSpy.mock.calls);
    expect(serializedLogs).toContain("auth.session_parse_failed");
    expect(serializedLogs).not.toContain("legacy-access-secret");
    expect(serializedLogs).not.toContain("legacy-refresh-secret");
  });

  it("logs auth storage failures without retaining raw Error objects", () => {
    const source = readFileSync(apiClientCorePath, "utf8");

    expect(source).toContain("function getAuthStorageErrorDetails(error: unknown)");
    expect(source).toContain("function readStoredAuthSessionRaw(storageFailureEvent: string)");
    expect(source).toContain("function getApiClientErrorDetails(error: unknown)");
    expect(source).toContain("function getApiPayloadParseErrorDetails(error: unknown)");
    expect(source).toContain("function suppressPersistedAuthSession(raw: string | null): void");
    expect(source).toContain("return getApiClientErrorDetails(error);");
    expect(source).toContain('errorName: error instanceof Error ? error.name : "UnknownError"');
    expect(source).toContain(
      'clientLogger.warn("auth.session_parse_failed", getAuthStorageErrorDetails(error));'
    );
    expect(source).toContain(
      'clientLogger.warn("auth.logout_failed", getAuthStorageErrorDetails(error));'
    );
    expect(source).toContain("auth.persisted_token_session_cleanup_failed");
    expect(source).toContain("auth.session_read_failed");
    expect(source).toContain("auth.session_clear_read_failed");
    expect(source).toContain("auth.session_clear_failed");
    expect(source).toContain("auth.session_save_failed");
    expect(source).not.toContain("auth.session_token_migration_failed");
    expect(source).not.toContain('clientLogger.warn("auth.session_parse_failed", { error });');
    expect(source).not.toContain(
      'clientLogger.warn("auth.session_parse_cleanup_failed", { error: storageError });'
    );
    expect(source).not.toContain('clientLogger.warn("auth.logout_failed", { error });');
    expect(source).not.toContain("error: parseError");
    expect(source).not.toContain("error,\n    });\n\n    const networkError");
    expect(source).not.toContain('correlationId: headers.get("X-Correlation-ID"),\n      error,');
    expect(source).not.toContain("hasRefreshToken: Boolean(refreshToken),\n      error,");
  });

  it("rejects malformed login sessions without storing partial auth state", async () => {
    const warnSpy = vi.spyOn(console, "warn").mockImplementation(() => {});
    const fetchMock = vi.fn(async () =>
      Response.json({
        accessToken: "backend-access-secret",
        refreshToken: "backend-refresh-secret",
        expiresAtUtc: new Date(Date.now() + 60_000).toISOString(),
        user: {
          userId: "admin-user-id",
          email: "admin@example.com",
          isPremium: false,
          emailConfirmed: true,
          roles: "Admin",
        },
      })
    );
    vi.stubGlobal("fetch", fetchMock);

    await expect(login("admin@example.com", "password")).rejects.toThrow(
      "Backend auth session is missing required user fields."
    );

    expect(window.sessionStorage.getItem(AUTH_KEY)).toBeNull();
    expect(getSession()).toBeNull();
    const serializedLogs = JSON.stringify(warnSpy.mock.calls);
    expect(serializedLogs).not.toContain("backend-access-secret");
    expect(serializedLogs).not.toContain("backend-refresh-secret");
  });

  it("rejects backend login sessions without an access token", async () => {
    const fetchMock = vi.fn(async () =>
      Response.json({
        refreshToken: "backend-refresh-secret",
        expiresAtUtc: new Date(Date.now() + 60_000).toISOString(),
        user: createSession().user,
      })
    );
    vi.stubGlobal("fetch", fetchMock);

    await expect(login("admin@example.com", "password")).rejects.toThrow(
      "Backend auth session is missing accessToken."
    );

    expect(window.sessionStorage.getItem(AUTH_KEY)).toBeNull();
    expect(getSession()).toBeNull();
  });

  it("clears volatile tokens when sanitized session persistence fails", async () => {
    const warnSpy = vi.spyOn(console, "warn").mockImplementation(() => {});
    stubBrowser(new SetFailureStorage());
    const fetchMock = vi.fn(async () => Response.json(createSession()));
    vi.stubGlobal("fetch", fetchMock);

    await expect(login("admin@example.com", "password")).rejects.toThrow(
      "Unable to persist admin session."
    );

    expect(getSession()).toBeNull();
    const serializedLogs = JSON.stringify(warnSpy.mock.calls);
    expect(serializedLogs).toContain("auth.session_save_failed");
    expect(serializedLogs).not.toContain("access-secret");
    expect(serializedLogs).not.toContain("refresh-secret");
    expect(serializedLogs).not.toContain("raw-secret");
  });

  it("keeps the runtime signed out when sessionStorage removal fails during clearSession", async () => {
    const warnSpy = vi.spyOn(console, "warn").mockImplementation(() => {});
    const storage = stubBrowser(new RemoveFailureStorage());
    const dispatchEventSpy = vi.spyOn(window, "dispatchEvent");

    await seedLoggedInSession();
    expect(getSession()?.accessToken).toBe("access-secret");
    dispatchEventSpy.mockClear();

    clearSession();

    expect(getSession()).toBeNull();
    expect(storage.getItem(AUTH_KEY)).not.toBeNull();
    expect(dispatchEventSpy).toHaveBeenCalledTimes(1);
    const serializedLogs = JSON.stringify(warnSpy.mock.calls);
    expect(serializedLogs).toContain("auth.session_clear_failed");
    expect(serializedLogs).not.toContain("access-secret");
    expect(serializedLogs).not.toContain("refresh-secret");
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

  it("redacts API log path query values before writing client logs", async () => {
    const warnSpy = vi.spyOn(console, "warn").mockImplementation(() => {});
    const fetchMock = vi.fn(async () =>
      Response.json({ detail: "Server error. Try again later." }, { status: 500 })
    );
    vi.stubGlobal("fetch", fetchMock);

    await expect(
      apiRequest(
        "/api/admin/users?search=alice%40example.com&token=raw-secret&take=20",
        { method: "GET" },
        { requireAuth: false }
      )
    ).rejects.toThrow("Server error. Try again later.");

    expect(warnSpy).toHaveBeenCalledWith(
      "[client:api.request_non_success]",
      expect.objectContaining({
        context: expect.objectContaining({
          path: "/api/admin/users?query=[redacted]",
          method: "GET",
          status: 500,
          correlationId: expect.any(String),
        }),
      })
    );
    const serializedLogs = JSON.stringify(warnSpy.mock.calls);
    expect(serializedLogs).not.toContain("alice%40example.com");
    expect(serializedLogs).not.toContain("alice@example.com");
    expect(serializedLogs).not.toContain("raw-secret");
  });

  it("uses fallback messages for non-JSON error responses without noisy parse logs", async () => {
    const warnSpy = vi.spyOn(console, "warn").mockImplementation(() => {});
    const fetchMock = vi.fn(
      async () =>
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

  it("preserves a bounded Retry-After delay from throttled API responses", async () => {
    vi.spyOn(console, "warn").mockImplementation(() => {});
    vi.stubGlobal(
      "fetch",
      vi.fn(async () =>
        Response.json({ title: "rate_limited" }, { status: 429, headers: { "retry-after": "12" } })
      )
    );

    let caughtError: unknown;
    try {
      await apiRequest("/api/admin/users", { method: "GET" }, { requireAuth: false });
    } catch (error) {
      caughtError = error;
    }

    expect(caughtError).toBeInstanceOf(Error);
    const apiError = caughtError as Error & { retryAfterSeconds?: number };
    expect(apiError.message).toBe("Too many requests. Try again shortly.");
    expect(apiError.retryAfterSeconds).toBe(12);
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
    expect(apiError.message).toContain("https://cdn.example.com/***");
    expect(serialized).toContain("token=[redacted]");
    expect(serialized).toContain("receipt=[redacted]");
    expect(serialized).toContain("card_number=[redacted]");
    expect(serialized).not.toContain("alice@example.com");
    expect(serialized).not.toContain("X-Amz-Signature=secret");
    expect(serialized).not.toContain("raw-secret");
    expect(serialized).not.toContain("ios-secret");
    expect(serialized).not.toContain("4242424242424242");
  });

  it("uses fallback messages instead of raw JSON or stack-like problem details", async () => {
    vi.spyOn(console, "warn").mockImplementation(() => {});
    const fetchMock = vi.fn(async () =>
      Response.json(
        {
          title: "errors.validation_failed",
          detail: '{"token":"raw-secret","message":"upstream failed"}',
          errors: {
            payload: ['{"receipt":"ios-secret"}', "TypeError: Cannot read properties of undefined"],
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
    const apiError = caughtError as Error & { validationErrors?: string[] };
    const serialized = JSON.stringify({
      message: apiError.message,
      validationErrors: apiError.validationErrors,
    });

    expect(apiError.message).toBe("Request validation failed.");
    expect(apiError.validationErrors).toBeUndefined();
    expect(serialized).not.toContain("raw-secret");
    expect(serialized).not.toContain("ios-secret");
    expect(serialized).not.toContain("TypeError");
    expect(serialized).not.toContain("upstream failed");
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
    await seedLoggedInSession();
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
    expect(headers.get("X-PetMagic-Logout-Intent")).toBe("logout");
    expect(headers.get("Authorization")).toBe("Bearer access-secret");
    expect(String(init?.body)).toContain("refresh-secret");
  });

  it("sends a cookie-backed logout when no volatile tokens remain after reload", async () => {
    const fetchMock = vi.fn(async () => new Response(null, { status: 204 }));
    vi.stubGlobal("fetch", fetchMock);

    await logout();
    await new Promise<void>((resolve) => setTimeout(resolve, 0));

    const calls = fetchMock.mock.calls as unknown as Array<[RequestInfo | URL, RequestInit?]>;
    const [url, init] = calls[0] ?? [];
    const headers = init?.headers as Headers;

    expect(String(url)).toBe("https://api.example.com/api/auth/logout");
    expect(init?.method).toBe("POST");
    expect(init?.body).toBeUndefined();
    expect(init?.credentials).toBe("include");
    expect(headers.get("X-PetMagic-Logout-Intent")).toBe("logout");
    expect(headers.get("Authorization")).toBeNull();
  });

  it("replays authenticated GET requests once after a successful token refresh", async () => {
    await seedLoggedInSession();
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
    await seedLoggedInSession();
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
    await seedLoggedInSession();
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
    await seedLoggedInSession();
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

  it("does not repopulate an invalidated cache namespace from a prior signal-scoped read", async () => {
    const cache = new Map<string, { value: string; expiresAt: number }>();
    const staleResponse = createDeferred<string>();
    const request = vi
      .fn<() => Promise<string>>()
      .mockImplementationOnce(() => staleResponse.promise)
      .mockResolvedValueOnce("fresh-response");

    const staleRequest = cachedGet(
      "support-templates",
      cache,
      request,
      new AbortController().signal
    );
    invalidateCachedGetNamespaces(["support-templates"]);
    staleResponse.resolve("stale-response");

    await expect(staleRequest).resolves.toBe("stale-response");
    await expect(
      cachedGet("support-templates", cache, request, new AbortController().signal)
    ).resolves.toBe("fresh-response");
    expect(request).toHaveBeenCalledTimes(2);
    expect(cache.get("support-templates")?.value).toBe("fresh-response");
  });
});
