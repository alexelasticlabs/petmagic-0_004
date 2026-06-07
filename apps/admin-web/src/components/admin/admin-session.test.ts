import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import { ensureAdminSession } from "@/components/admin/admin-session";
import { clearSession, type AuthSession } from "@/lib/api-client";

const AUTH_KEY = "petmagic_admin_auth";

function createStorage() {
  const values = new Map<string, string>();
  return {
    getItem: vi.fn((key: string) => values.get(key) ?? null),
    removeItem: vi.fn((key: string) => {
      values.delete(key);
    }),
    setItem: vi.fn((key: string, value: string) => {
      values.set(key, value);
    }),
  };
}

function createSession(
  roles: string[],
  overrides: Partial<Pick<AuthSession, "accessToken" | "expiresAtUtc">> = {}
): AuthSession {
  return {
    accessToken: "access-token",
    expiresAtUtc: "2099-01-01T00:00:00Z",
    ...overrides,
    user: {
      userId: "user-1",
      email: "admin@example.com",
      isPremium: roles.includes("Premium"),
      emailConfirmed: true,
      roles,
    },
  };
}

describe("ensureAdminSession", () => {
  let storage: ReturnType<typeof createStorage>;

  beforeEach(() => {
    storage = createStorage();
    vi.stubGlobal("window", {
      sessionStorage: storage,
      dispatchEvent: vi.fn(),
    });
    clearSession();
  });

  afterEach(() => {
    clearSession();
    vi.unstubAllGlobals();
  });

  it("allows Admin and Moderator sessions", () => {
    const router = { replace: vi.fn() };

    storage.setItem(AUTH_KEY, JSON.stringify(createSession(["Admin"])));
    expect(ensureAdminSession("en", router)).toBe(true);
    expect(router.replace).not.toHaveBeenCalled();

    storage.setItem(AUTH_KEY, JSON.stringify(createSession(["Moderator"])));
    expect(ensureAdminSession("ru", router)).toBe(true);
    expect(router.replace).not.toHaveBeenCalled();
  });

  it("redirects sessions without admin-panel roles", () => {
    const router = { replace: vi.fn() };

    storage.setItem(AUTH_KEY, JSON.stringify(createSession(["Premium", "User"])));

    expect(ensureAdminSession("en", router)).toBe(false);
    expect(router.replace).toHaveBeenCalledWith("/en");
  });

  it("redirects sessions without a fresh access token", () => {
    const router = { replace: vi.fn() };

    storage.setItem(AUTH_KEY, JSON.stringify(createSession(["Admin"], { accessToken: undefined })));
    expect(ensureAdminSession("en", router)).toBe(false);
    expect(router.replace).toHaveBeenCalledWith("/en");

    router.replace.mockClear();
    storage.setItem(
      AUTH_KEY,
      JSON.stringify(createSession(["Moderator"], { expiresAtUtc: "2000-01-01T00:00:00Z" }))
    );
    expect(ensureAdminSession("ru", router)).toBe(false);
    expect(router.replace).toHaveBeenCalledWith("/ru");
  });
});
