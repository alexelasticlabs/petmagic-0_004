import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import { assignRole, normalizeFetchUsersQuery, revokeRole } from "@/lib/api-client.admin-users";

describe("admin users api client query and role guards", () => {
  beforeEach(() => {
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
  });

  it("normalizes users list query params before cache keys and request paths", () => {
    expect(
      normalizeFetchUsersQuery({
        skip: -20,
        take: 1000,
        search: ` ${"x".repeat(140)} `,
        role: "Owner",
        status: "deleted",
        isPremium: true,
      })
    ).toEqual({
      skip: 0,
      take: 100,
      search: "x".repeat(120),
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
});
